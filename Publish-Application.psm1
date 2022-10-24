function Publish-Application
{
    <#
        .SYNOPSIS
            Install wrapper generator for MCM applications, from PSADT templates. 
            # LICENSE #
            Copyright (C) 2022 - Brandon Purnell
            This program is free software: you can redistribute it and/or modify it under the terms of the GNU Lesser General Public License as published by the Free Software Foundation, either version 3 of the License, or any later version. This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.
            You should have received a copy of the GNU Lesser General Public License along with this program. If not, see <http://www.gnu.org/licenses/>.

        .DESCRIPTION
            Packages basic applications with the PowerShell App Deploy Toolkit for Microsoft Configuration Manager (MCM) deployment.

            Execute within the root directory of a PSADT template, from a Windows-based system.

            The latest installer is downloaded from the specified URL to a PSADT template, which is then copied to the MCM applications folder.
            A new application is created and configured in MCM. The detection method is configured, and the app is deployed to the specified collection.

            The PSADT template should be configured with organizational branding, typical application metadata, and -le 200x200px 'Icon.png' co-located.

        .PARAMETER InstallRename
            This is what the downloaded installer will be renamed to. The file extension is mandatory.

        .PARAMETER DownloadURL
            This is the link pointing to the latest version of the application to be packaged.

        .PARAMETER ClientName
            This is the application name that will appear in the Software Center client. 

        .PARAMETER ConfMgrName
            This is the application name that will appear in MCM.

        .PARAMETER RuntimeEstimate
            This is the manually-specified amount of time the installer is expected to take.

        .PARAMETER Owner
            This is the owner field that will appear in MCM.

        .PARAMETER InstallPath
            This supplies the directory path to the installed executable for use in the MCM detection method. 

        .PARAMETER ExeName
            This supplies the filename of the installed executable for use in the MCM detection method.

        .PARAMETER ManualVersion
            This manually supplies the version number of the installed executable, in the event that the installer did not have it embedded.
            This is for use in the MCM detection method. 

        .PARAMETER DeployCollection 
            This is the collection that the application will be deployed to. 
            It is recommended that this collection be a testing, non-production collection. 

        .PARAMETER SiteCode
            The MCM site code. 

        .PARAMETER AppRepo
            The path to MCM application storage.

        .PARAMETER DistribGroup
            The distribution point group the application will be cached to.

        .PARAMETER McmRoot
            The MCM root.

        .EXAMPLE
            
        .NOTES
            THIS CODE IS MADE AVAILABLE AS IS, WITHOUT WARRANTY OF ANY KIND.
            THE ENTIRE RISK OF THE USE OR THE RESULTS FROM THE USE OF THIS
            CODE REMAINS WITH THE USER.
    #>
    Param
    (
        [Parameter(Mandatory = $True, ValueFromPipeline = $False)]
        [String]$InstallRename,
        [String]$DownloadURL,
        [String]$ClientName,
        [String]$ConfMgrName,
        [String]$RuntimeEstimate,
        [String]$Owner,
        [String]$InstallPath,
        [String]$ExeName,
        [String]$ManualVersion,
        [String[]]$DeployCollection,
        [String]$SiteCode,
        [String]$AppRepo,
        [String[]]$DistribGroup,
        [String]$McmRoot
    ) 

    Begin {
        Import-Module ConfigurationManager 
        $CurrDate = Get-Date -Format g
        ## location of this script when invoked
        $CurrentPath = $Pwd.Path #= Split-Path ((Get-Variable MyInvocation -Scope Script).Value).MyCommand.Path

        ## Function definitions
    }

    Process {
        Write-Host "Connecting to Configuration Manager Site"
        If ($McmRoot){
            If (New-PSDrive -Name "MCM" -PSProvider "CMSite" -Root $McmRoot -Description "MCM site") {Write-Host "Connected to MCM site..."} 
            Else {Write-Host "Failed to connect to MCM site..."; Exit-Script}
            Set-Location MCM:
        }

        
        If  ($DownloadURL){
            ## Download the new Installer & Rename it to a generic name 
            New-PSDrive -Name Template -PSProvider FileSystem -Root $CurrentPath
            $NewInstallerPath = "Template:\Files\$InstallRename"
            Write-Host "New installer path: $NewInstallerPath `nDownloading... $DownloadURL"
            Start-BitsTransfer -Source $DownloadURL -Destination $NewInstallerPath
        }


        ## Detection method version
        $Version = $ManualVersion
        If ($ManualVersion) {$Version = $ManualVersion}
        Else{
            # If ($(Get-Item $NewInstallerPath).Extension -eq '.exe'){$Version = $(Get-Item $NewInstallerPath).VersionInfo.FileVersion}
            # ElseIf ($(Get-Item $NewInstallerPath).Extension -eq '.msi'){
            #     Set-Location Template:
            #     $Version = Get-MsiProductVersion -Path ".\Files\$InstallRename"
            #     Set-Location MCM:
            # }
            # ElseIf (($Null -eq $Version) -or !($Version.Revision -gt -1)) {
            #     If ($ManualVersion){$Version = $ManualVersion}
            #     Else {"No version specified..."; Exit-Script}
            # }
        }
        If (!$Version) {Write-Host "No version supplied"; Exit-Script}
        
        $CMAppName = "$($ConfMgrName)_$($Version)"

        $ContentLoc = "$($AppRepo)\$($ConfMgrName)\$($ConfMgrName)_$($Version)"    ## New app folder will be "AppName_x.y.z"
        $DeployTypeName = "$($ConfMgrName)_PSADT_Template_Script"    ## Deployment script will be named "AppName_PSADT_Template_Script"
        $IconLoc = "$($CurrentPath)\Icon.png"  ## Asumes icon is in same location as this script, and called "Icon.png"

        ## Creates an empty application in MCM and moves it into the specified folder 
        Write-Host "Building Application... $CMAppName `nVersion... $Version"

        ## TO-DO: Check if file downloaded is 64-bit

        ## TO-DO: Check if path to move app to exists
        ## TO-DO: If path does not exist, create it

        New-CMApplication `
            -Name $CMAppName `
            -SoftwareVersion $Version `
            -Owner $Owner `
            -ReleaseDate $CurrDate `
            -LocalizedName $ClientName `
            -IconLocationFile $IconLoc `
            | Move-CMObject -FolderPath ".\Application\$ConfMgrName" `
            | Set-CMApplication -DistributionPointSetting 'AutoDownload'

        ## Debug Log
        Write-Host ""
        Write-Host "Copying Content to $SiteCode"
        Write-Host $ContentLoc

        ## Make new folder on MCM based on app name and version
        $FileSysLoc = "filesystem::$ContentLoc"
        New-Item -ItemType 'Directory' -Path $FileSysLoc
        $AllItems = "$CurrentPath\*" 
        Copy-Item $AllItems -Destination $FileSysLoc -Recurse 

        ## Detection Method -- for use in the "Deployment Script" section. 
        Write-Host "Creating Detection Method"
            
        ## How to detect if the program is already installed
        $DetectionMethod = New-CMDetectionClauseFile `
            -FileName $ExeName `
            -PropertyType Version `
            -ExpectedValue $Version `
            -ExpressionOperator GreaterEquals `
            -Is64Bit:$True `
            -Path $InstallPath `
            -Value:$True 
            ## Ex, 7z.Exe exists, it is installed, and it is version 18.05

        ## Creates the Deployment Script within the application; sets the Detection Method, which we defined above
        Write-Host "Building Deployment Script"
        Write-Host $DeployTypeName

        Add-CMScriptDeploymentType `
            -ApplicationName $CMAppName `
            -ContentFallback:$True `
            -DeploymentTypeName $DeployTypeName `
            -ContentLocation $ContentLoc `
            -AddDetectionClause $DetectionMethod `
            -InstallCommand "Deploy-Application Install" `
            -UninstallCommand "Deploy-Application Uninstall" `
            -RepairCommand "Deploy-Application Repair" `
            -InstallationBehaviorType InstallForSystem `
            -LogonRequirementType WhetherOrNotUserLoggedOn `
            -RebootBehavior BasedOnExitCode `
            -SlowNetworkDeploymentMode Download `
            -EstimatedRuntimeMins $RuntimeEstimate | Out-Null ## Suppress verbosity

        ## Distribute content to distribution points and deploy
        

        ## Distribute the content to the Distribution Point Group
        Write-Host "Distributing $CMAppName to..."
        ForEach ($Group in $DistribGroup)
        {
            Write-Host "$Group ..."
            Start-CMContentDistribution -ApplicationName $CMAppName -DistributionPointGroupName $Group
        }
        

        ## Deploy the new application
        Write-Host "Deploying $CMAppName to..."
        ForEach ($Collection in $DeployCollection)
        {
            Write-Host "$Collection ..."
            New-CMApplicationDeployment -CollectionName $Collection -Name $CMAppName -DeployAction Install -DeployPurpose Available | Out-Null ## Suppress verbosity
        }
        
    }

    End {
        #This is the end
        Set-Location $CurrentPath
        return $True
    }
}