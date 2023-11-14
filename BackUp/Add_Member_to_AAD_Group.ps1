##Connect to Azure AD
try {Get-AzureADTenantDetail} 
    catch {Connect-AzureAD}

$Dev = @(
    "UK4S541T3"
    "UK49041T3"
    "UK23G31T3"
    "UKF0951T3"
    "UK38041T3"
    "UKH8T31T3"
    "UKJJ351T3"
    "UK411Y0T3"
    "UK2RNX0T3"
    "UKBBVX0T3"
    "UKJ49X0T3"
)

$AADGrp = "UK WinEP - Enable Developer Mode"
$AADGrpID = (Get-AzureADGroup -Filter "DisplayName eq '$($AADGrp)'").ObjectId

$Dev | ForEach-Object {
    $RawRes = $null
    $RawRes = (Get-AzureADDevice -Filter "DisplayName eq '$($_)'").ObjectId
    try {
        Write-Host "$RawRes"
        Add-AzureADGroupMember -ObjectId "$AADGrpID" -RefObjectId "$RawRes" -Verbose
        
    }
    catch {
        Write-Host "Device Already a member of specified AAD group"
    }
}