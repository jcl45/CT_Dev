$AVInfo = Get-CimInstance -Namespace root/SecurityCenter2 -ClassName AntivirusProduct
if (($AVInfo.displayName -match "CrowdStrike Falcon Sensor").count -gt 0) {
    $ProdState1 = ($AVInfo | Where-Object displayName -eq "CrowdStrike Falcon Sensor").productState
    switch ($ProdState1) {
        "266240" {Write-Host "Falcon Sensor Enabled and Up to date" ;break}
        "262144" {Write-Host "Falcon Sensor Disabled and Out of date" ;break}
        default {Write-Host "Falcon Sensor Unknown :: " ;break}
    }
}
$ProdState2 = ($AVInfo | Where-Object displayName -eq "Windows Defender").productState
switch ($ProdState2) {
    "262144" {Write-Host "Defender Disabled and Up to date"; $Remediate = $false;break}
    "262160" {Write-Host "Defender Disabled and Out of date"; $Remediate = $false ;break}
    "266240" {Write-Host "Defender Enabled and Up to date"; $Remediate = $true ;break}
    "266256" {Write-Host "Defender Enabled and Out of date"; $Remediate = $true ;break}
    "393216" {Write-Host "Defender Disabled and Up to date"; $Remediate = $false ;break}
    "393232" {Write-Host "Defender Disabled and Out of date"; $Remediate = $false ;break}
    "393488" {Write-Host "Defender Disabled and Out of date"; $Remediate = $false ;break}
    "397312" {Write-Host "Defender Enabled and Up to date"; $Remediate = $true ;break}
    "397328" {Write-Host "Defender Enabled and Out of date"; $Remediate = $true ;break}
    "397584" {Write-Host "Defender Enabled and Out of date"; $Remediate = $true ;break}
    "397568" {Write-Host "Defender Enabled and Up to date"; $Remediate = $true; break}
    "393472" {Write-Host "Defender Disabled and Up to date"; $Remediate = $false ;break}
    default {Write-Host "Defender Unknown"; $Remediate = $true ;break}
}

if (!($Remediate)) {
    exit 1
} 