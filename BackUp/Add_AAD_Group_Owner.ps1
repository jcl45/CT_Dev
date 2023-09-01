#Pop-up box to collect target user
[void][Reflection.Assembly]::LoadWithPartialName('Microsoft.VisualBasic')
$Title = 'Target User'
$Msg = 'Enter the UPN of the target user:'
$Usr = [Microsoft.VisualBasic.Interaction]::InputBox($Msg, $Title)
#Convert UPN to User ID
$UsrID = (Get-AzureADUser -Filter "userPrincipalName eq '$Usr'").ObjectId

#Target AAD groups
$AADGrp = @(
    "UK WinEP - Autopilot HP",
    "UK WinEP - Autopilot Test Apps",
    "UK WinEP - Autopilot Test Apps 02",
    "UK WinEP - MFT Configuration",
    "UK WinEP - Autopilot Test Apps Users",
    "UK WinEP - Autopilot Test Profiles Device",
    "UK WinEP - Autopilot Test Profiles User",
    "UK WinEP - Autopilot Enrolment ESP 1",
    "UK WinEP - Intune SCCM client auto install  ",
    "UK WinEP - Autopilot Enrolment ESP 2",
    "UK WinEP - Autopilot Test Apps 03"
)

Function Graph {
    #Poll Graph for AAD group details
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory=$true, Position=0)]
        [string]$GN
    )
    $GraphVersion = "v1.0"
    $GraphResource = "groups?`$filter=DisplayName eq '$GN'"
    $GraphURI = "https://graph.microsoft.com/$($GraphVersion)/$($GraphResource)"
    $AuthToken = Get-MSIntuneAuthToken -TenantName skyglobal.onmicrosoft.com -ClientID d1ddf0e4-d672-4dae-b554-9d5bdfd93547
    $Script:Output = ""
    $GraphResponse = (Invoke-RestMethod -Uri $GraphURI –Headers $authToken –Method Get -Verbose)
        $Script:Output = $GraphResponse.value
        $GraphNextLink = $GraphResponse."@odata.nextLink"
            while ($GraphNextLink -ne $null){
                $GraphResponse = (Invoke-RestMethod -Uri $GraphNextLink –Headers $authToken –Method Get -Verbose)
                $GraphNextLink = $GraphResponse."@odata.nextLink"
                $Script:Output += $GraphResponse.value
            }
}

#Convert Group Name to Group ID
$AADGrpID = @()
Foreach ($Grp in $AADGrp){
    Graph "$Grp"
     $AADGrpID += [String]$Output.id
}

#Add specified user as owner of the listed AAD groups
$AADGrpID | ForEach-Object { 
    Add-AzureADGroupOwner -ObjectId "$_" -RefObjectId "$UsrID" -Verbose -ErrorAction SilentlyContinue
}




