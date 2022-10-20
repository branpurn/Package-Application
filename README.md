# Package-Application

Install wrapper generator for MCM applications, from PSADT templates.

## What this script does

- Download the installer for the new version of the program
- Copy the PSADT contents to the MCM Applications folder on specified server
- Create a new application in MCM
- Configures the new application
- Creates the deployment script
- Sets up the detection method based on Version Number
- Deploys the application to the specified collection

## Usage

### Command:

```powershell
USAGE:
    > Package-Application [-InstallRename] [-DownloadURL] [-ClientName] [-ConfMgrName] [-RuntimeEstimate] [-Owner] [-InstallPath] [-ExeName] [-ManualVersion] [-DeployCollection] [-SiteCode] [-AppRepo] [-DistribGroup] [-McmRoot]

  EXAMPLE:
    > Package-Application `
        -InstallRename "install.msi" `
        -DownloadURL "https://download.mozilla.org/?product=firefox-msi-latest-ssl&os=win64&lang=en-US" `
        -ClientName "Mozilla Firefox" `
        -ConfMgrName "Firefox" `
        -RuntimeEstimate "5" `
        -Owner "Your Name Here" ` # Being Deprecated
        -InstallPath "%ProgramFiles%\Mozilla Firefox\" `
        -ExeName "Firefox.exe" `
        -ManualVersion "105.0.3" ` 
        -DeployCollection "Your Collection Here" ` # Recommended to be test collection
        -SiteCode "001" `
        -AppRepo "\\MCM_Site\CM_001_ContentSource\applications\path" `
        -DistribGroup "Distribution Group Name Here" `
        -McmRoot "MCM.YourServerHere.org"
```
