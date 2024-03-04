<#
.SYNOPSIS
  Script validates devices hostname againts expected hostname determined by pulling from Intune's Autopilot data and the devices serial number.

.NOTES
  Version:        1.0
  Author:         JCL45 - James Cockerill
  Creation Date:  19/02/24
  Purpose/Change: Initial script development
#>

##*=============================================================================================================================================
##*                                               VARIABLE DECLARATION
##*=============================================================================================================================================

$ApplicationId = "c854312c-71e1-4800-bcfa-94db0e0615e6"
$SecuredPassword = "vvp8Q~tS4Q_sIJM5_QSZFCDSd3ii2fHiNu.JxcsG"
$tenantID = "68b865d5-cf18-4b2b-82a4-a4eddb9c5237"

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
$SN = $((Get-CimInstance Win32_BIOS).SerialNumber)
CallMgGraph -Meth 'Get' -Ver 'v1.0' -Res 'deviceManagement/windowsAutopilotDeviceIdentities' -Extra "?`$filter=contains(serialNumber,'$SN')"
$CloudDevData = $GrRaw
$LocHostname = $env:computername

### Set Expected Hostname & Validate
switch ($CloudDevData.groupTag) {
    'UK' {$LocPre = 'UK';break}
    'ID:UK' {$LocPre = 'IU';break}
    'CZ:UK' {$LocPre = 'CU';break}
}
$ExpectedName = $LocPre + $SN
$HostCheck = $ExpectedName -match $LocHostname

Break
### Validation
if ($HostCheck) {
  Write-Host "Hostname Valid"
  Exit 0
} else {
  Write-host "Hostname Invalid"
  Exit 1
}