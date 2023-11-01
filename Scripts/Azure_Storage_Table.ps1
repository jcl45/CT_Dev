$SAName = "skyukclienttech"
$SAKey = "oE2z1zCkfBVhHxF/g5rKLjvCfirPE53yjTsbMT68A43bd4034aXhN3p0/BUG5Mil5gT+/AzJVDSb+ASt/UezNw=="
$tableURL = "https://skyukclienttech.table.core.windows.net/UKOnPremADO"
$tableName = "UKOnPremADO"

$ctx = New-AzureStorageContext -StorageAccountName $SAName -StorageAccountKey $SAKey
$Table = Get-AzureStorageTable -Name $tableName -Context $ctx 
Get-AzureStorageTableRowAll -table $Table