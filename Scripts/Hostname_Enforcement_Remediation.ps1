<#
.SYNOPSIS
  Script renames device based on location information pulled from Intune's Autopilot data and the devices serial number.

.OUTPUTS Log File
  The script log file stored in C:\Windows\BSKYB_LOGS\Hostname_Enforcement_Remediation.log

.NOTES
  Version:        1.0
  Author:         JCL45 - James Cockerill
  Creation Date:  19/02/24
  Purpose/Change: Initial script development
#>

##*=============================================================================================================================================
##*                                                  INITIALISATIONS
##*=============================================================================================================================================

if (!([bool](Get-PackageProvider -Name 'NuGet'))) {Install-PackageProvider NuGet -Force;}
if ((Get-PSRepository -Name PSGallery).InstallationPolicy -ne 'Trusted') {Set-PSRepository PSGallery -InstallationPolicy Trusted}
$AvailableModules = (Get-ChildItem -Path 'C:\Program Files\WindowsPowerShell\Modules').Name
if (!([bool]($AvailableModules -match 'Microsoft.Graph.Authentication'))) {Install-Module Microsoft.Graph.Authentication -Force}
Import-Module Microsoft.Graph.Authentication

##*=============================================================================================================================================
##*                                               VARIABLE DECLARATION
##*=============================================================================================================================================

$Name = "Hostname_Enforcement_Remediation"
$ApplicationId = "c854312c-71e1-4800-bcfa-94db0e0615e6"
$SecuredPassword = "vvp8Q~tS4Q_sIJM5_QSZFCDSd3ii2fHiNu.JxcsG"
$tenantID = "68b865d5-cf18-4b2b-82a4-a4eddb9c5237"
$Logfile = "C:\Windows\BSKYB_LOGS\$Name.log"

##*=============================================================================================================================================
##*                                                     FUNCTIONS
##*=============================================================================================================================================

function CallMgGraph {
    Param ($Meth, $Res, $Ver, $Extra)
    $Global:GraphReturn = $null
    $uri = "https://graph.microsoft.com/$Ver/$($Res)$($Extra)"
    $GraphReturn = Invoke-MgGraphRequest -method $Meth -Uri $uri
    $Script:GrRaw = $GraphReturn.value
    $OutputNextLink = $GraphReturn."@odata.nextLink"
    while ($null -ne $OutputNextLink){
            $GraphReturn = (Invoke-MgGraphRequest -method $Meth -Uri $OutputNextLink)
            $OutputNextLink = $GraphReturn."@odata.nextLink"
            $Script:GrRaw += $GraphReturn.value
            }
}

Function LogWrite {
    Param ([string]$logstring)
     $Stamp = (Get-Date).toString("yyyy/MM/dd HH:mm:ss")
     $fullString = $stamp + ": " + $logstring
    Add-content $Logfile -value $fullString
 }

##*=============================================================================================================================================
##*                                                     PRE-EXECUTION
##*=============================================================================================================================================

if (!(Test-Path C:\Windows\BSKYB_Logs)) {New-Item C:\Windows\BSKYB_Logs -type directory -Force}

##*=============================================================================================================================================
##*                                                     EXECUTION
##*=============================================================================================================================================

### Connect to MS Graph via Entra App
$SecuredPasswordPassword = ConvertTo-SecureString `
-String $SecuredPassword -AsPlainText -Force
$ClientSecretCredential = New-Object `
-TypeName System.Management.Automation.PSCredential `
-ArgumentList $ApplicationId, $SecuredPasswordPassword
Connect-MgGraph -TenantId $tenantID -ClientSecretCredential $ClientSecretCredential -NoWelcome

### Gather Data
LogWrite "Gathering Device Data from Intune"
$SN = $((Get-CimInstance Win32_BIOS).SerialNumber)
CallMgGraph -Meth 'Get' -Ver 'v1.0' -Res 'deviceManagement/windowsAutopilotDeviceIdentities' -Extra "?`$filter=contains(serialNumber,'$SN')"
$CloudDevData = $GrRaw

### Set Expected Hostname
switch ($CloudDevData.groupTag) {
    'UK' {$LocPre = 'UK';break}
    'ID:UK' {$LocPre = 'IU';break}
    'CZ:UK' {$LocPre = 'CU';break}
}
$ExpectedName = $LocPre + $SN
LogWrite "Expected Hostname: $ExpectedName :: Current Hostname: $env:computername"

### Rename Device
LogWrite "Renaming hostname to: $ExpectedName"
Remove-ItemProperty -path "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters" -name "Hostname" 
Remove-ItemProperty -path "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters" -name "NV Hostname" 
Set-ItemProperty -path "HKLM:\SYSTEM\CurrentControlSet\Control\Computername\Computername" -name "Computername" -value $ExpectedName
Set-ItemProperty -path "HKLM:\SYSTEM\CurrentControlSet\Control\Computername\ActiveComputername" -name "Computername" -value $ExpectedName
Set-ItemProperty -path "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters" -name "Hostname" -value $ExpectedName
Set-ItemProperty -path "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters" -name "NV Hostname" -value  $ExpectedName
Set-ItemProperty -path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon" -name "AltDefaultDomainName" -value $ExpectedName
Set-ItemProperty -path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon" -name "DefaultDomainName" -value $ExpectedName
Restart-Service -Name winmgmt -Force