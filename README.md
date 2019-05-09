[![Build status](https://ci.appveyor.com/api/projects/status/8bysqkxmaecxvq54/branch/master?svg=true)](https://ci.appveyor.com/project/PowerShell/xwindowsrestore/branch/master)

# xWindowsRestore

The **xWindowsRestore** module contains the **xSystemRestore** and **xSystemRestorePoint** for managing system restore and system checkpoints on a Windows machine.

This project has adopted the [Microsoft Open Source Code of Conduct](https://opensource.microsoft.com/codeofconduct/).
For more information see the [Code of Conduct FAQ](https://opensource.microsoft.com/codeofconduct/faq/) or contact [opencode@microsoft.com](mailto:opencode@microsoft.com) with any additional questions or comments.

## Contributing
Please check out common DSC Resources [contributing guidelines](https://github.com/PowerShell/DscResource.Kit/blob/master/CONTRIBUTING.md).


## Resources

* **xSystemRestore** enables or disables system restore on a specified system drive.
* **xSystemRestorePoint:** creates and removes system checkpoints.

### xSystemRestore

* **Drive**: Specifies the file system drives.
Enter one or more file system drive letters, each followed by a colon and a backslash and enclosed in quotation marks, such as 'C:\' or 'D:\'.
* **Ensure**: Ensures that the system is or is not configured for system restore: { **Present** | **Absent** }
* **MaxSize**: Specifies the maximum amount of space that can be used for storing shadow copies, such as '100GB', '20%' or 'UNBOUNDED'.
For byte level specification, MaxSize must be 320MB or greater and accepts the following suffixes: KB, MB, GB, TB, PB and EB.

### xSystemRestorePoint

* **Description**: Descriptive name for the restore point.
* **RestorePointType**: The type of restore point.
The default is APPLICATION_INSTALL.
* **Ensure**: Ensures that the restore point is **Present** or **Absent**.

## Versions

### Unreleased

* Update appveyor.yml to use the default template.
* Added default template files .codecov.yml, .gitattributes, and .gitignore, and
  .vscode folder.

### 1.0.0.0

* Initial release with the following resources:
    - xWindowsRestore
    - xSystemRestorePoint

## Examples

### Enable System Restore

In the Examples folder, ConfigureSystemRestore.ps1 demonstrates how to enable system restore.

### Creates a System Restore point

In the Examples folder, CreateSystemRestorePoint.ps1 demonstrates how to create a system restore point.
