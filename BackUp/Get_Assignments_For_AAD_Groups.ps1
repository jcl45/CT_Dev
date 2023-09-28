#   *****************************************************************************************************
# ||
# ||                             *Get_Assignments_for_AAD_Groups*
# ||
# ||
# || Version: 1.0
# || Creator: Galen Chand
# ||
# || Date: 23/05/2022
# || Modified: 20/03/2023
# ||
# || Purpose: Used to get Apps, Compliance, Config, PS scripts and Admin Templates assigned to an Azure AD Security Group
# ||
# || 
# || 
# || 
#   *****************************************************************************************************


############################################################################

#Functions
function CallMSGraph {
    Param (
    [Parameter(Mandatory=$true, Position=0)]
    [String]$Res,
    [Parameter(Mandatory=$true, Position=1)]
    [String]$Ver,
    [Parameter(Mandatory=$false, Position=2)]
    [String]$Extra
    )
    $Script:GraphReturn = $null
    $uri = "https://graph.microsoft.com/$Ver/$($Res)$($Extra)"
    $Script:GraphReturn = Invoke-MSGraphRequest -HttpMethod GET -Url $uri
    $RawDataNextLink = $Script:GraphReturn.'@odata.nextLink'
    While ($RawDataNextLink -ne $null){
        $Script:GraphReturn = (Invoke-MSGraphRequest -HttpMethod GET -Url $RawDataNextLink)
        $RawDataNextLink = $Script:GraphReturn.'@odata.nextLink'
        $RawData += $Script:GraphReturn.value
    }
}



# Test connection to MS Graph

try { 
    $OutP = Get-Organization -ErrorAction SilentlyContinue
} catch {
    Connect-MSGraph
}
 
# Which AAD group do we want to check against. Change to relevent group.
#$groupName = "UK HoloLens Users"
$groupName = Read-Host -Prompt 'Pease input the AAD group name'
 
#$Groups = Get-AADGroup | Get-MSGraphAllPages
$Group = Get-AADGroup -Filter "displayname eq '$GroupName'"
 
############################################################################
 
Write-host "AAD Group Name: $($Group.displayName)" -ForegroundColor Green
 
# Apps
CallMSGraph "deviceAppManagement/mobileApps" "beta" '?$expand=Assignments'
$RawData = $GraphReturn.value | Where-Object {$_.assignments.target.groupid -match $Group.id}
Write-host "Number of Apps found: $($RawData.DisplayName.Count)" -ForegroundColor cyan
$RawData | Where-Object {Write-host $_.displayName -ForegroundColor Yellow}

# Device Compliance
CallMSGraph "/deviceManagement/deviceCompliancePolicies" "v1.0" "?`$expand=Assignments"
$RawData = $GraphReturn.value | Where-Object {$_.assignments.target.groupid -match $Group.id}
Write-host "Number of Device Compliance policies found: $($RawData.DisplayName.Count)" -ForegroundColor cyan
$RawData | Where-Object {Write-host $_.displayName -ForegroundColor Yellow}

# Device Configuration Powershell Scripts 
CallMSGraph "deviceManagement/deviceManagementScripts" "Beta" "?`$expand=groupAssignments"
$RawData = $GraphReturn.value | Where-Object {$_.assignments.groupid -match $Group.id}
Write-host "Number of Device Configurations Powershell Scripts found: $($RawData.DisplayName.Count)" -ForegroundColor cyan
$RawData | Where-Object {Write-host $_.displayName -ForegroundColor Yellow}

# Device Configuration
CallMSGraph "deviceManagement/deviceConfigurations" "v1.0" "?`$expand=assignments"
$RawDataDCO = $GraphReturn.value | Where-Object {($_.assignments.target.groupid  -match $Group.id) -and ($_.'@odata.type' -ne "#microsoft.graph.windowsUpdateForBusinessConfiguration")}
Write-host "Number of Device Configurations Profiles found: $($RawDataDCO.DisplayName.Count)" -ForegroundColor cyan
$RawDataDCO | Where-Object {Write-host $_.displayName -ForegroundColor Yellow}

# Administrative templates
CallMSGraph "deviceManagement/groupPolicyConfigurations" "Beta" "?`$expand=Assignments"
$RawData = $GraphReturn.value | Where-Object {$_.assignments.id -match $Group.id}
Write-host "Number of Device Administrative Templates found: $($RawData.DisplayName.Count)" -ForegroundColor cyan
$RawData | Where-Object {Write-host $_.displayName -ForegroundColor Yellow}

# Settings Catalog 
CallMSGraph "deviceManagement/configurationPolicies" "Beta" "?`$expand=assignments"
$RawData = $GraphReturn.value | Where-Object {$_.assignments.target.groupid -match $Group.id}
Write-host "Number of Settings Catalog Profiles found: $($RawData.DisplayName.Count)" -ForegroundColor cyan
$RawData | Where-Object {Write-host $_.name -ForegroundColor Yellow}

# Enrolment Status Page Profiles
CallMSGraph "deviceManagement/deviceEnrollmentConfigurations" "Beta" "?`$expand=assignments"
$RawDataECO = $GraphReturn.value | Where-Object {($_.assignments.id -match $Group.id) -and ($_.'@odata.type' -eq "#microsoft.graph.windows10EnrollmentCompletionPageConfiguration")}
Write-host "Number of Enrolment Status Page Profiles found: $($RawDataECO.DisplayName.Count)" -ForegroundColor cyan
$RawDataECO | Where-Object {Write-host $_.displayName -ForegroundColor Yellow}

# Co-management Authority Profiles
$RawDataECO = $GraphReturn.value | Where-Object {($_.assignments.id -match $Group.id) -and ($_.'@odata.type' -eq "#microsoft.graph.deviceComanagementAuthorityConfiguration")}
Write-host "Number of Co-management Authority Profiles found: $($RawDataECO.DisplayName.Count)" -ForegroundColor cyan
$RawDataECO | Where-Object {Write-host $_.displayName -ForegroundColor Yellow}

# Remediation Scripts
CallMSGraph "deviceManagement/deviceHealthScripts" "Beta" "?`$expand=assignments"
$RawData = $GraphReturn.value | Where-Object {$_.assignments.id -match $Group.id}
Write-host "Number of Remediation Scripts found: $($RawData.DisplayName.Count)" -ForegroundColor cyan
$RawData | Where-Object {Write-host $_.displayName -ForegroundColor Yellow}

# Windows Autopilot Deployment profiles
CallMSGraph "deviceManagement/windowsAutopilotDeploymentProfiles" "Beta" "?`$expand=assignments"
$RawData = $GraphReturn.value | Where-Object {$_.assignments.id -match $Group.id}
Write-host "Number of Autopilot Deployment Profiles found: $($RawData.DisplayName.Count)" -ForegroundColor cyan
$RawData | Where-Object {Write-host $_.displayName -ForegroundColor Yellow}

# Update Rings
$RawDataDCO = $GraphReturn.value | Where-Object {($_.assignments.target.groupid  -match $Group.id) -and ($_.'@odata.type' -eq "#microsoft.graph.windowsUpdateForBusinessConfiguration")}
Write-host "Number of Update Ring Assisgnments found: $($RawDataDCO.DisplayName.Count)" -ForegroundColor cyan
$RawDataDCO | Where-Object {Write-host $_.displayName -ForegroundColor Yellow}

# Driver Update
CallMSGraph "deviceManagement/windowsDriverUpdateProfiles" "Beta" "?`$expand=assignments"
$RawData = $GraphReturn.value | Where-Object {$_.assignments.id -match $Group.id}
Write-host "Number of Driver Update Profiles found: $($RawData.DisplayName.Count)" -ForegroundColor cyan
$RawData | Where-Object {Write-host $_.displayName -ForegroundColor Yellow}


Break
================ Device Config profiles not listing ================
================ needs work =====================
# Intents
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

# Endpoint Security - Endpoint Detection and Response policies
# Endpoint Security - Firewall policies
# Endpoint Security - Security baselines
