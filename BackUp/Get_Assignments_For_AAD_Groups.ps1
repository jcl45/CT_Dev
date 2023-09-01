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
}



# Connect and change schema

if (!((Get-MSGraphEnvironment).SchemaVersion -eq "beta")) {
    Update-MSGraphEnvironment -SchemaVersion beta
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
$AllAssignedApps = Get-IntuneMobileApp -Filter "isAssigned eq true" -Select id, displayName, lastModifiedDateTime, assignments -Expand assignments | Where-Object {$_.assignments -match $Group.id}
Write-host "Number of Apps found: $($AllAssignedApps.DisplayName.Count)" -ForegroundColor cyan
Foreach ($Config in $AllAssignedApps) {
 
Write-host $Config.displayName -ForegroundColor Yellow
 
}
 
 
# Device Compliance
$AllDeviceCompliance = Get-IntuneDeviceCompliancePolicy -Select id, displayName, lastModifiedDateTime, assignments -Expand assignments | Where-Object {$_.assignments -match $Group.id}
Write-host "Number of Device Compliance policies found: $($AllDeviceCompliance.DisplayName.Count)" -ForegroundColor cyan
Foreach ($Config in $AllDeviceCompliance) {
 
Write-host $Config.displayName -ForegroundColor Yellow
 
}
 
##################### Good to go
# Device Configuration Powershell Scripts 
CallMSGraph "deviceManagement/deviceManagementScripts" "Beta" "?`$expand=groupAssignments"
$RawData = $GraphReturn.value | Where-Object {$_.assignments.groupid -match $Group.id}
Write-host "Number of Device Configurations Powershell Scripts found: $($RawData.DisplayName.Count)" -ForegroundColor cyan
$RawData | Where-Object {Write-host $_.displayName -ForegroundColor Yellow}
#####################



# Device Configuration
$AllDeviceConfig = Get-IntuneDeviceConfigurationPolicy -Select id, displayName, lastModifiedDateTime, assignments -Expand assignments | Where-Object {$_.assignments -match $Group.id}
Write-host "Number of Device Configurations found: $($AllDeviceConfig.DisplayName.Count)" -ForegroundColor cyan
Foreach ($Config in $AllDeviceConfig) {Write-host $Config.displayName -ForegroundColor Yellow}
 


##################### Good to go

# Administrative templates
CallMSGraph "deviceManagement/groupPolicyConfigurations" "Beta" "?`$expand=Assignments"
$RawData = $GraphReturn.value | Where-Object {$_.assignments.id -match $Group.id}
Write-host "Number of Device Administrative Templates found: $($RawData.DisplayName.Count)" -ForegroundColor cyan
$RawData | Where-Object {Write-host $_.displayName -ForegroundColor Yellow}

# Settings Catalog 
CallMSGraph "deviceManagement/configurationPolicies" "Beta" "?`$expand=assignments"
$RawData = $GraphReturn.value | Where-Object {$_.assignments.target.groupid -match $Group.id}
Write-host "Number of Device Administrative Templates found: $($RawData.DisplayName.Count)" -ForegroundColor cyan
$RawData | Where-Object {Write-host $_.name -ForegroundColor Yellow}

#####################






# Enrolment Status Page Profiles
$uri = "https://graph.microsoft.com/beta/deviceManagement/deviceEnrollmentConfigurations?$expandFilter$selectFilter"
$EDCs = Invoke-MSGraphRequest -Url $uri | Get-MSGraphAllPages
$W10ESPs = $EDCs | Where-Object {$_.id -like "*Windows10EnrollmentCompletionPageConfiguration"}
$AllESP = @()
$W10ESPs | ForEach-Object {
    $uri = "https://graph.microsoft.com/beta/deviceManagement/deviceEnrollmentConfigurations/$($_.id)/assignments"
    $MSGRet = Invoke-MSGraphRequest -Url $uri | Get-MSGraphAllPages
    if ($msgret.target.groupid -match $Group.id) {$AllESP += $_.DisplayName}
}
Write-host "Number of Enrolment Status Page Profiles found: $($AllESP.Count)" -ForegroundColor cyan
Foreach ($Config in $AllESP) {
 
Write-host $AllESP -ForegroundColor Yellow
 
}










# Co-management Authority Profiles
CallMSGraph "deviceManagement/deviceEnrollmentConfigurations" "Beta"
$GraphReturn.value | Where-Object {$_.id -like "*DeviceComanagementAuthorityConfiguration"}

$ALLSC = $GraphReturn.value | Where-Object {$_.assignments -match $Group.id}
Write-host "Number of Settings Catalog Profiles found: $($ALLSC.DisplayName.Count)" -ForegroundColor cyan
Foreach ($Config in $ALLSC) {Write-host $Config.displayName -ForegroundColor Yellow}





$uri = "https://graph.microsoft.com/beta/deviceManagement/deviceEnrollmentConfigurations?$expandFilter$selectFilter"
$EDCs = Invoke-MSGraphRequest -Url $uri | Get-MSGraphAllPages
$CoMan = $EDCs | Where-Object {$_.id -like "*DeviceComanagementAuthorityConfiguration"}
$AllCoMan = @()
$CoMan | ForEach-Object {
    $uri = "https://graph.microsoft.com/beta/deviceManagement/deviceEnrollmentConfigurations/$($_.id)/assignments"
    $MSGRet = Invoke-MSGraphRequest -Url $uri | Get-MSGraphAllPages
    if ($msgret.target.groupid -match $Group.id) {$AllCoMan += $_.DisplayName}
}
Write-host "Number of Co-Management Profiles found: $($AllCoMan.Count)" -ForegroundColor cyan
Foreach ($Config in $AllCoMan) {
 
Write-host $AllCoMan -ForegroundColor Yellow
 
}

# Remediation Scripts
$uri = "https://graph.microsoft.com/beta/deviceManagement/deviceHealthScripts"
$EDCs = Invoke-MSGraphRequest -Url $uri | Get-MSGraphAllPages
$AllRemScr = @()
$EDCs | ForEach-Object {
    $uri = "https://graph.microsoft.com/beta/deviceManagement/deviceHealthScripts/$($_.id)/assignments"
    $MSGRet = Invoke-MSGraphRequest -Url $uri | Get-MSGraphAllPages
    if ($msgret.target.groupid -match $Group.id) {$AllRemScr += $_.DisplayName}
}
Write-host "Number of Remediation Scripts found: $($AllRemScr.Count)" -ForegroundColor cyan
Foreach ($Config in $AllRemScr) {
 
Write-host $AllRemScr -ForegroundColor Yellow
 
}

# Windows Autopilot Deployment profiles
$uri = "https://graph.microsoft.com/beta/deviceManagement/windowsAutopilotDeploymentProfiles"
$EDCs = Invoke-MSGraphRequest -Url $uri | Get-MSGraphAllPages
$AllAPDep = @()
$EDCs | ForEach-Object {
    $uri = "https://graph.microsoft.com/beta/deviceManagement/windowsAutopilotDeploymentProfiles/$($_.id)/assignments"
    $MSGRet = Invoke-MSGraphRequest -Url $uri | Get-MSGraphAllPages
    if ($msgret.target.groupid -match $Group.id) {$AllAPDep += $_.DisplayName}
}
Write-host "Number of Autopilot Deployment Profiles found: $($AllAPDep.Count)" -ForegroundColor cyan
Foreach ($Config in $AllAPDep) {
 
Write-host $AllAPDep -ForegroundColor Yellow
 
}

# Update Rings
$uri = 'https://graph.microsoft.com/beta/deviceManagement/deviceConfigurations?$filter=(isof(''microsoft.graph.windowsUpdateForBusinessConfiguration''))'
$EDCs = Invoke-MSGraphRequest -Url $uri | Get-MSGraphAllPages
$AllUpRing = @()
$EDCs | ForEach-Object {
    $uri = "https://graph.microsoft.com/beta/deviceManagement/deviceConfigurations/$($_.id)/assignments"
    $MSGRet = Invoke-MSGraphRequest -Url $uri | Get-MSGraphAllPages
    if ($msgret.target.groupid -match $Group.id) {$AllUpRing += $_.DisplayName}
}
Write-host "Number of Update Ring Assisgnments found: $($AllUpRing.Count)" -ForegroundColor cyan
Foreach ($Config in $AllUpRing) {
 
Write-host $AllUpRing -ForegroundColor Yellow
 
}

# Driver Update
$uri = "https://graph.microsoft.com/beta/deviceManagement/windowsDriverUpdateProfiles"
$EDCs = Invoke-MSGraphRequest -Url $uri | Get-MSGraphAllPages
$AllDrvUp = @()
$EDCs | ForEach-Object {
    $uri = "https://graph.microsoft.com/beta/deviceManagement/windowsDriverUpdateProfiles/$($_.id)/assignments"
    $MSGRet = Invoke-MSGraphRequest -Url $uri | Get-MSGraphAllPages
    if ($msgret.target.groupid -match $Group.id) {$AllDrvUp += $_.DisplayName}
}
Write-host "Number of Driver Update Profiles found: $($AllDrvUp.Count)" -ForegroundColor cyan
Foreach ($Config in $AllDrvUp) {
 
Write-host $AllDrvUp -ForegroundColor Yellow
 
}

# Endpoint Security - Account Protection policies
# Endpoint Security - Antivirus policies
# Endpoint Security - Attack Surface Reduction policies
# Endpoint Security - Defender policies
# Endpoint Security - Disk Encryption policies
# Endpoint Security - Endpoint Detection and Response policies
# Endpoint Security - Firewall policies
# Endpoint Security - Security baselines

# Configuration policies - Settings Catalog
#Invoke-MSGraphRequest -Url ("https://graph.microsoft.com/beta/deviceManagement/configurationPolicies?`$filter=(platforms eq 'windows10' or platforms eq 'macOS' or platforms eq 'iOS') and (technologies eq 'mdm' or technologies eq 'windows10XManagement' or technologies eq 'appleRemoteManagement' or technologies eq 'mdm,appleRemoteManagement') and (templateReference/templateFamily eq 'none')$custExpandFilter$custSelectFilter" -replace "\s+", "%20") | Get-MSGraphAllPages | select @{n = 'Displayname'; e = { $_.Name } }, * -ExcludeProperty 'Name', 'assignments@odata.context'
# Configuration policies - Templates
#Invoke-MSGraphRequest -Url ("https://graph.microsoft.com/beta/deviceManagement/deviceConfigurations?`$filter=(not isof('microsoft.graph.windowsUpdateForBusinessConfiguration') and not isof('microsoft.graph.iosUpdateConfiguration'))$expandFilter$selectFilter" -replace "\s+", "%20") | Get-MSGraphAllPages | select * -ExcludeProperty 'assignments@odata.context'

