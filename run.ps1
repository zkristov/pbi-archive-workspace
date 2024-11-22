#Requires -Modules @{ ModuleName="MicrosoftPowerBIMgmt.Profile"; ModuleVersion="1.2.1111"}
#Requires -Modules @{ ModuleName="MicrosoftPowerBIMgmt.Workspaces"; ModuleVersion="1.2.1111"}
#Requires -Modules @{ ModuleName="MicrosoftPowerBIMgmt.Data"; ModuleVersion="1.2.1111"}

$renameArchiveWorkspace = $false
$renameArchiveWorkspaceSuffix = "[Archived]"

$adminPrincpleType = "Group"
$adminIdentifier = ""
$adminTakeOverUser = ""

$ErrorActionPreference = "Stop"
$VerbosePreference = "SilentlyContinue"
$WarningPreference = "SilentlyContinue"

$workspaces = @()

# Logging function to output messages to console and run.log file
function Write-Log {
    param (
        [string]$message
    )
    $message = "$(Get-Date -Format 'MM-dd-yyyy HH:mm:ss') - $message"
    Write-Output $message
    Add-Content -Path ".\run.log" -Value $message
}

try {
    # Get the workspaces from the CSV file
    $workspacesFile = ".\workspaces.csv"
    $workspaces = Get-Content -Path $workspacesFile | ConvertFrom-Csv
}
catch {
    $errorMessage = "Failed to read workspaces.csv file: $_"
    Write-Error $errorMessage
    Write-Log $errorMessage
}

try {
    # Connect to the Power BI Service using user principal credentials
    Connect-PowerBIServiceAccount
} 
catch {
    $errorMessage = "Failed to connect to the Power BI Service: $_"
    Write-Error $errorMessage
    Write-Log $errorMessage
}

try {
    if ($workspaces.Count -eq 0) {
        $errorMessage = "No rows found in workspaces.csv"
        Write-Error $errorMessage
        Write-Log $errorMessage
        return
    }

    foreach ($workspace in $workspaces) {

        Write-Log "Archiving workspace $($workspace.WorkspaceName) with ID $($workspace.Id)"
        
        # Add (app, group, or user) as admin to the workspace
        Add-PowerBIWorkspaceUser -Scope Organization -Id $workspace.Id -Identifier $adminIdentifier -PrincipalType $adminPrincpleType -AccessRight Admin

        # Get a list of users that have access to the workspace
        $workspaceUsers = Invoke-PowerBIRestMethod -Url "groups/$($workspace.Id)/users" -Method Get | ConvertFrom-Json
        $workspaceUsers = $workspaceUsers.value

        # Remove all non-admin (apps, groups, or users) from the workspace
        Write-Log "Removing identities (apps, groups, and users) from the workspace $($workspace.WorkspaceName)"
        foreach ($workspaceUser in $workspaceUsers) {
            if ($workspaceUser.groupUserAccessRight -ne "Admin") {
                Invoke-PowerBIRestMethod -Url "groups/$($workspace.Id)/users/$($workspaceUser.identifier)" -Method Delete
            }
        }

        # Get a list of datasets in the workspace
        $datasets = Get-PowerBIDataset -WorkspaceId $workspace.Id
        foreach ($dataset in $datasets) {

            Write-Log "Revoking direct access to dataset $($dataset.Name) with ID $($dataset.Id)"

            # Get a list of users that have access to the dataset
            $users = Invoke-PowerBIRestMethod -Url "datasets/$($dataset.Id)/users" -Method Get | ConvertFrom-Json
            $users = $users.value

            # Hack to handle when an admin user permissions are removed (on error continue)
            $ErrorActionPreference = "SilentlyContinue"
            foreach ($user in $users) {
                try {
                    # Revoke access to the dataset for the user
                    Invoke-PowerBIRestMethod -Url "datasets/$($dataset.Id)/users" -Method Put -Body "{""datasetUserAccessRight"": ""None"", ""identifier"": ""$($user.identifier)"", ""principalType"": ""$($user.principalType)""}"
                }
                catch {
                    continue
                }
            }
            $ErrorActionPreference = "Stop"
        
            # Skip datasets that are not refreshable (e.g., DirectQuery datasets)
            if ($dataset.IsRefreshable -eq $false) {
                continue
            }

            # Take over the dataset (with authorized user) if not owned 
            if ($dataset.ConfiguredBy -ne $adminTakeOverUser) {
                Write-Log "Taking over dataset $($dataset.Name)"
                Invoke-PowerBIRestMethod -Url "groups/$($workspace.Id)/datasets/$($dataset.Id)/Default.TakeOver" -Method Post
            }

            # Disable the scheduled refresh for the dataset
            Write-Log "Disabling dataset refreshes for dataset $($dataset.Name)"
            Invoke-PowerBIRestMethod -Url "groups/$($workspace.Id)/datasets/$($dataset.Id)/refreshSchedule" -Method Patch -Body "{""value"": {""enabled"": false }}"
        }

        # Get a list of dataflows in the workspace 
        $dataflows = Get-PowerBIDataflow -WorkspaceId $workspace.Id
        foreach ($dataflow in $dataflows) {
            Write-Log "Disabling refreshes for dataflow $($dataflow.Name) with ID $($dataflow.Id)"
            # Disable the scheduled refresh for the dataflow
            Invoke-PowerBIRestMethod -Url "groups/$($workspace.Id)/dataflows/$($dataflow.Id)/refreshSchedule" -Method Patch -Body "{""value"": {""enabled"": false, ""times"": [""12:00""] }}"
        }

        # Remove the workspace from the Power BI premium capacity
        Write-Log "Removing workspace $($workspace.WorkspaceName) from the premium capacity (if applicable)"
        $capacityId = "00000000-0000-0000-0000-000000000000"
        Set-PowerBIWorkspace -Scope Organization -Id $workspace.Id -CapacityId $capacityId

        # Rename the workspace to indicate that it has been archived [OPTIONAL]
        if ($renameArchiveWorkspace -eq $true) {
            Set-PowerBIWorkspace -Scope Organization -Id $workspace.Id -Name "$($workspace.WorkspaceName) $($renameArchiveWorkspaceSuffix)" -Description "Workspace archived on: $(Get-Date -Format 'MM-dd-yyyy')"
        }

        Write-Log "Workspace $($workspace.WorkspaceName) has been archived!"
    }
}
catch {
    $errorMessage = "Failed to archive workspace: $_"
    Write-Error $errorMessage
    Write-Log $errorMessage
}
finally {
    Disconnect-PowerBIServiceAccount
}