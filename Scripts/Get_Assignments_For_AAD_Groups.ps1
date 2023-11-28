<#
.SYNOPSIS
  Get Assignments for AAD Groups
.DESCRIPTION
  Used to get Apps, Compliance, Config, PS scripts and Admin Templates assigned to an Azure AD Security Group
.NOTES
  Version:        2.0
  Author:         Galen Chand
  Creation Date:  23/05/2022
  Purpose/Change: Initial script development
                  Script updated to use MgGraph & Inlude more Intune categories - JCL45 - 14/11/2023
#>

##*=============================================================================================================================================
##*                                                  INITIALISATIONS
##*=============================================================================================================================================

##Modules
if ($null -eq (Get-Module -Name Microsoft.Graph.Authentication)) {Install-Module Microsoft.Graph.Authentication}

##*=============================================================================================================================================
##*                                                     FUNCTIONS
##*=============================================================================================================================================

#Functions
function ConnectMgGraph {
    try {$OutP = Get-MgOrganization -ErrorAction Stop}
    catch {Connect-MgGraph -Scopes "User.ReadWrite.All", "Directory.ReadWrite.All", "DeviceManagementManagedDevices.ReadWrite.All" , "DeviceManagementConfiguration.ReadWrite.All" -NoWelcome}
}

function CallMgGraph {
    Param ($Meth, $Res, $Ver, $Extra)
    ConnectMgGraph
    $Script:GraphReturn = $null
    $Script:GrRaw = $null
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

## Prompt for AAD group Name
$groupName = Read-Host -Prompt 'Pease input the AAD group name'
CallMgGraph -Meth 'Get' -Ver 'v1.0' -Res 'groups' -Extra "?`$filter=displayName eq `'$groupName`'"
$Group = $GrRaw 
Write-host "AAD Group Name: $($Group.displayName)" -ForegroundColor Green
 
## Apps
CallMgGraph -Meth 'Get' -Ver 'Beta' -Res 'deviceAppManagement/mobileApps' -Extra '?$expand=Assignments'
$GrReturn = $GrRaw | Where-Object {$_.assignments.target.groupid -match $Group.id}
Write-host "Number of Apps found: $($GrReturn.DisplayName.Count)" -ForegroundColor cyan
$GrReturn | Where-Object {Write-host $_.displayName -ForegroundColor Yellow}

## Device Compliance
CallMgGraph -Meth 'Get' -Ver 'v1.0' -Res 'deviceManagement/deviceCompliancePolicies' -Extra '?$expand=Assignments'
$GrReturn = $GrRaw | Where-Object {$_.assignments.target.groupid -match $Group.id}
Write-host "Number of Device Compliance policies found: $($GrReturn.DisplayName.Count)" -ForegroundColor cyan
$GrReturn | Where-Object {Write-host $_.displayName -ForegroundColor Yellow}

## Device Configuration Powershell Scripts 
CallMgGraph -Meth 'Get' -Ver 'Beta' -Res 'deviceManagement/deviceManagementScripts' -Extra '?$expand=Assignments'
$GrReturn = $GrRaw | Where-Object {$_.assignments.groupid -match $Group.id}
Write-host "Number of Device Configurations Powershell Scripts found: $($GrReturn.DisplayName.Count)" -ForegroundColor cyan
$GrReturn | Where-Object {Write-host $_.displayName -ForegroundColor Yellow}

## Device Configuration
CallMgGraph -Meth 'Get' -Ver 'beta' -Res 'deviceManagement/deviceConfigurations' -Extra '?$expand=Assignments'
$GrReturn = $GrRaw | Where-Object {($_.assignments.target.groupid  -match $Group.id) -and ($_.'@odata.type' -ne "#microsoft.graph.windowsUpdateForBusinessConfiguration")}
Write-host "Number of Device Configurations Profiles found: $($GrReturn.DisplayName.Count)" -ForegroundColor cyan
$GrReturn | Where-Object {Write-host $_.displayName -ForegroundColor Yellow}

## Update Rings
$GrReturn = $GrRaw | Where-Object {($_.assignments.target.groupid  -match $Group.id) -and ($_.'@odata.type' -eq "#microsoft.graph.windowsUpdateForBusinessConfiguration")}
Write-host "Number of Update Ring Assisgnments found: $($GrReturn.DisplayName.Count)" -ForegroundColor cyan
$GrReturn | Where-Object {Write-host $_.displayName -ForegroundColor Yellow}

## Administrative templates
CallMgGraph -Meth 'Get' -Ver 'Beta' -Res 'deviceManagement/groupPolicyConfigurations' -Extra '?$expand=Assignments'
$GrReturn = $GrRaw  | Where-Object {$_.assignments.id -match $Group.id}
Write-host "Number of Device Administrative Templates found: $($GrReturn.DisplayName.Count)" -ForegroundColor cyan
$GrReturn | Where-Object {Write-host $_.displayName -ForegroundColor Yellow}

## Settings Catalog 
CallMgGraph -Meth 'Get' -Ver 'Beta' -Res 'deviceManagement/configurationPolicies' -Extra '?$expand=Assignments'
$GrReturn = $GrRaw  | Where-Object {$_.assignments.target.groupid -match $Group.id}
Write-host "Number of Settings Catalog Profiles found: $($GrReturn.Name.Count)" -ForegroundColor cyan
$GrReturn | Where-Object {Write-host $_.name -ForegroundColor Yellow}

## Enrolment Status Page Profiles
CallMgGraph -Meth 'Get' -Ver 'Beta' -Res 'deviceManagement/deviceEnrollmentConfigurations' -Extra '?$expand=Assignments'
$GrReturn = $GrRaw  | Where-Object {($_.assignments.id -match $Group.id) -and ($_.'@odata.type' -eq "#microsoft.graph.windows10EnrollmentCompletionPageConfiguration")}
Write-host "Number of Enrolment Status Page Profiles found: $($GrReturn.DisplayName.Count)" -ForegroundColor cyan
$GrReturn | Where-Object {Write-host $_.displayName -ForegroundColor Yellow}

## Co-management Authority Profiles
$GrReturn = $GrRaw | Where-Object {($_.assignments.id -match $Group.id) -and ($_.'@odata.type' -eq "#microsoft.graph.deviceComanagementAuthorityConfiguration")}
Write-host "Number of Co-management Authority Profiles found: $($GrReturn.DisplayName.Count)" -ForegroundColor cyan
$GrReturn | Where-Object {Write-host $_.displayName -ForegroundColor Yellow}

## Remediation Scripts
CallMgGraph -Meth 'Get' -Ver 'Beta' -Res 'deviceManagement/deviceHealthScripts' -Extra '?$expand=Assignments'
$GrReturn = $GrRaw | Where-Object {$_.assignments.id -match $Group.id}
Write-host "Number of Remediation Scripts found: $($GrReturn.DisplayName.Count)" -ForegroundColor cyan
$GrReturn | Where-Object {Write-host $_.displayName -ForegroundColor Yellow}

## Windows Autopilot Deployment profiles
CallMgGraph -Meth 'Get' -Ver 'Beta' -Res 'deviceManagement/windowsAutopilotDeploymentProfiles' -Extra '?$expand=Assignments'
$GrReturn = $GrRaw | Where-Object {$_.assignments.id -match $Group.id}
Write-host "Number of Autopilot Deployment Profiles found: $($GrReturn.DisplayName.Count)" -ForegroundColor cyan
$GrReturn | Where-Object {Write-host $_.displayName -ForegroundColor Yellow}

## Driver Update
CallMgGraph -Meth 'Get' -Ver 'Beta' -Res 'deviceManagement/windowsDriverUpdateProfiles' -Extra '?$expand=Assignments'
$GrReturn = $GrRaw | Where-Object {$_.assignments.id -match $Group.id}
Write-host "Number of Driver Update Profiles found: $($GrReturn.DisplayName.Count)" -ForegroundColor cyan
$GrReturn | Where-Object {Write-host $_.displayName -ForegroundColor Yellow}



<#================ WIP ================

## Intents
CallMSGraph "deviceManagement/intents" "Beta" "?`$filter=isAssigned+eq+true"
$RawDataINR = $GraphReturn.value
$IntArray = @()
foreach ($In in $RawDataINR) {
    CallMSGraph "deviceManagement/intents/$($In.ID)/Assignments" "Beta"
    if (($GraphReturn.value.target.groupid -match $Group.id).Length -gt 0) {
        $IntArray += "$In"
    }
}
$IntArray | Where-Object {Write-host $_.displayName -ForegroundColor Yellow}


CallMSGraph "deviceManagement/intents/$($RawDataINR.ID)/Assignments" "Beta"

$RawDataIN = $GraphReturn.value | Where-Object {$_.target.groupid -match $Group.id}
Write-host "Number of Device Intents found: $($RawData.DisplayName.Count)" -ForegroundColor cyan
$RawData | Where-Object {Write-host $_.displayName -ForegroundColor Yellow}



$uri = "https://graph.microsoft.com/beta/deviceAppManagement/mobileApps?`$filter=isAssigned+eq+true&`$expand=Assignments"

$result = (Invoke-mggraphrequest -method GET -Uri $uri).value
#>
