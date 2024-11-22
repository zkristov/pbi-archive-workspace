# PBI-Archive-Workspace

## Description
The PowerShell script is designed to "archive" Power BI workspaces. It iterates through each workspace within the workspace.csv file, adding an admin (app, group, or user) to the workspace, removing all non-admin users from the workspace, revoking direct user access to all datasets in the workspace, and disabling all scheduled refreshes for both datasets and dataflows gen 1. It also removes the workspace from the associated premium capacity and optionally renames the workspace to indicate it has been archived. The script logs each step of the process for tracking purposes.

## Prerequisite
Power BI Powershell cmdlets:  
[MicrosoftPowerBIMgmt.Profile](https://learn.microsoft.com/en-us/powershell/module/microsoftpowerbimgmt.profile/?view=powerbi-ps)  
[MicrosoftPowerBIMgmt.Workspaces](https://learn.microsoft.com/en-us/powershell/module/microsoftpowerbimgmt.workspaces/?view=powerbi-ps)  
[MicrosoftPowerBIMgmt.Data](https://learn.microsoft.com/en-us/powershell/module/microsoftpowerbimgmt.data/?view=powerbi-ps)


## Usage
Step #1: Update the workspaces.csv file with targeted workspace ids and names. Note: Make sure to wrap values in double quotes.

Step #2: Update the following `run.ps1` variables:  
| Variable Name | Default Value | Description |
| ------------- | ------------- | ----------- |
| `$renameArchiveWorkspace ` | `false` | Flag to rename each workspace with archive suffix |
| `$renameArchiveWorkspaceSuffix` | `[Archive]` | Workspace suffix value |
| `$adminPrincpleType` | `Group` | Allowed values: [App, Group, User] |
| `$adminIdentifier` | `null` | Allowed values: App and Group [Object ID]; User [Email address] |
| `adminTakeOverUser ` | `null` | Email address of authenticate admin |

## Installation
Instructions on the install and set up

```bash
# Clone the repository
PS C:\Workspace> git clone https://github.com/yourusername/pbi-archive-workspace.git

# Navigate to the project directory
cd pbi-archive-workspace

# Run the project
PS C:\Workspace\pbi-archive-workspace> .\run.ps1
```

## Contributing
Guidelines for contributing

1. Fork the repository.
2. Create a new branch (`git checkout -b feature-branch`).
3. Make your changes.
4. Commit your changes (`git commit -m 'Add some feature'`).
5. Push to the branch (`git push origin feature-branch`).
6. Open a pull request.