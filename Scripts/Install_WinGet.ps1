###Global Variables
$CacheDir = "C:\ProgramData\Sky\Cache\WinGet"
if (!(Test-Path $CacheDir)){Invoke-Expression -Command:"md $CacheDir"}
$CacheFdr = "$env:ProgramData\Sky\Cache"
$Logfile = "C:\Windows\BSKYB_LOGS\$Name.log"
$URL = "https://skyukclienttech.blob.core.windows.net/software/Sky/Desktop_App_Installer.zip?sp=r&st=2023-03-10T10:45:14Z&se=2024-03-10T18:45:14Z&spr=https&sv=2021-12-02&sr=b&sig=WQQ3XJkdZJbwF%2BliQT48tCGlj4Op%2FQKxOHRDzWR8By8%3D"

###Functions
function LogWrite{
    Param ([string]$logstring)
     $Stamp = (Get-Date).toString("yyyy/MM/dd HH:mm:ss")
     $fullString = $stamp + ": " + $logstring
    Add-content $Logfile -value $fullString
 }


###Pre-Flight
#Stage BSKYBLogs folder
if (!(Test-Path "c:\Windows\BSKYB_Logs")) {
    LogWrite "Creating Log folder"
    New-Item -ItemType Directory -Path "c:\Windows\BSKYB_Logs" -force
    }
#Stage Download Cache Folder
if (!(Test-Path $CacheFdr)) {
    LogWrite "Creating Cache folder"
    Invoke-Expression -Command:"md `"$CacheFdr`""
    }


###Script Body
<#Download Files
$Source = "$CacheFdr\Desktop_App_Installer"
If (Test-Path $Source) {Remove-Item -Path $Source -Recurse -Force}
New-Item -ItemType directory -Path $Source
Invoke-WebRequest "$Url" -OutFile "$Source\Desktop_App_Installer.zip"

#UnZip files
Expand-Archive -Path "$Source\Desktop_App_Installer.zip" -DestinationPath $Source#>




function GHLateDL {
    param ($Repo, $Pattern, $Out)
    $Script:GHLatest = "https://api.github.com/repos/$Repo/releases/latest"
    $Script:GHRel = (((Invoke-WebRequest $GHLatest) | ConvertFrom-Json).assets.browser_download_url | select-string -Pattern "$Pattern").Line
    Invoke-WebRequest $GHRel -OutFile "$CacheDir\$($GHRel.substring($GHRel.LastIndexOf('/') +1))"
}

GHLateDL -Repo 'microsoft/winget-cli' -Pattern 'xml'
GHLateDL -Repo 'microsoft/winget-cli' -Pattern 'msixbundle'
GHLateDL -Repo 'microsoft/microsoft-ui-xaml' -Pattern 'x64.appx'
Invoke-WebRequest -Uri 'https://aka.ms/Microsoft.VCLibs.x64.14.00.Desktop.appx' -OutFile "$CacheDir\Microsoft.VCLibs.x64.14.00.Desktop.appx"

######################## NEEDS WORK
#Install Desktop App Installer
$Files = Get-ChildItem -Path $CacheDir
$Params1 = @(
    "/Online"
    "/Add-ProvisionedAppxPackage"
    "/PackagePath:$Source\Microsoft.DesktopAppInstaller_2023.118.406.0_neutral_~_8wekyb3d8bbwe.Msixbundle"
    "/DependencyPackagePath:$Source\Microsoft.UI.Xaml.2.7_7.2208.15002.0_x64__8wekyb3d8bbwe.Appx"
    "/DependencyPackagePath:$Source\Microsoft.VCLibs.140.00.UWPDesktop_14.0.30704.0_x64__8wekyb3d8bbwe.Appx"
    "/LicensePath:$Source\Microsoft.DesktopAppInstaller_8wekyb3d8bbwe_97612282-d1e8-1d6a-9e92-c271e7f177ef.xml"
)
Invoke-Expression -Command:"Dism.exe $Params1" -

###############################

#Update Store Apps
$namespaceName = "root\cimv2\mdm\dmmap"
$className = "MDM_EnterpriseModernAppManagement_AppManagement01"
$wmiObj = Get-WmiObject -Namespace $namespaceName -Class $className
$result = $wmiObj.UpdateScanMethod()#>