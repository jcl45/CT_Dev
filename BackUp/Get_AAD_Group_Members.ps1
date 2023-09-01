# Get the group ID

try {
    $Out = Get-AzureADTenantDetail
}
catch {
    Connect-AzureAD
}


$groupName = "UK WinEP - CIS Profile Testing - User"

$groupID = (Get-AzureADGroup -Filter "DisplayName eq '$($groupName)'").ObjectId
# Get the group members
$groupMembers = Get-AzureADGroupMember -ObjectId $groupID -All $true

# Write the list of members to a file
Write-Host "List of group members:"
ForEach ($member in $groupMembers)
{
    Write-Host $member.UserPrincipalName
}