#Variables
$TokenTail = "?sp=raw&st=2023-08-14T13:43:11Z&se=2024-08-14T21:43:11Z&spr=https&sv=2022-11-02&sr=c&sig=T5DudPYdDf%2FsbhZ2a0F84%2FIBw9HEYn9VSALTDM2Zrow%3D"
$Date_Time = (Get-Date).toString("ddMMyyyy.HHmm")
$CacheFldr = "C:\ProgramData\Sky\Diagnostics\$Date_Time"
$Hostname = & hostname
$zipfile = "$CacheFldr\$Hostname.$Date_Time.zip"


#Pre-flight
if (!(Test-path $CacheFldr)) {
    Invoke-Expression -Command:"md $CacheFldr"
}

#Script Body
##Output Reg Location: HKLM:\SOFTWARE\BskyB
New-Item -ItemType directory -Path "$CacheFldr\Registry"
Get-ItemProperty Registry::HKEY_LOCAL_MACHINE\SOFTWARE\BskyB  | Out-File -FilePath "$CacheFldr\Registry\HKLM_Software_BskyB.log"
$Map = (Get-ChildItem Registry::HKEY_LOCAL_MACHINE\SOFTWARE\BskyB -Recurse).Name
$Map | ForEach-Object {
    Add-content "$CacheFldr\Registry\HKLM_Software_BskyB.log" -value "`r`n -------------------------------------- `r`n"
    Get-ItemProperty Registry::$_ | Out-File -Append -FilePath "$CacheFldr\Registry\HKLM_Software_BskyB.log"
} 

##Copy C:\Windows\Bskyb_logs
New-Item -ItemType directory -Path "$CacheFldr\BSKYB_Logs"
Copy-Item -Path "C:\Windows\BSKYB_Logs\*" -Destination "$CacheFldr\BSKYB_Logs"-Recurse

##Output Certs
function CSVExpo {
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory=$true, Position=0)]
        [string]$Path,
        [Parameter(Mandatory=$true, Position=1)]
        [string]$StoreN
    )
    Get-ChildItem -path cert:\$Path | 
    ForEach-Object {        
        $_ | Select-Object `
            @{n="Store";e={$StoreN}},`
            @{n="Thumbprint";e={$_.Thumbprint}},`
            @{n="Subject";e={$_.Subject}},`
            @{n="EnhancedKeyUsageList";e={$_.EnhancedKeyUsageList}},`
            @{n="Begins";e={$_.NotBefore}},`
            @{n="Expires";e={$_.NotAfter}}`
        } | Export-Csv -NoClobber -Append "$CacheFldr\Certificates.csv" -NoTypeInformation 
}

CSVExpo LocalMachine\my LocalMachine\Personal
CSVExpo LocalMachine\root LocalMachine\TruestedRoot
CSVExpo LocalMachine\ca LocalMachine\Intermediate

Get-ItemProperty HKLM:\SOFTWARE\Microsoft\EnterpriseCertificates\NTAuth\Certificates\* -name blob | ForEach-Object {New-Object System.Security.Cryptography.X509Certificates.X509Certificate2($_.Blob,$null)} |
ForEach-Object {        
    $_ | Select-Object `
        @{n="Store";e={"LocalMachine\NTAuth"}},`
        @{n="Thumbprint";e={$_.Thumbprint}},`
        @{n="Subject";e={$_.Subject}},`
        @{n="EnhancedKeyUsageList";e={$_.EnhancedKeyUsageList}},`
        @{n="Begins";e={$_.NotBefore}},`
        @{n="Expires";e={$_.NotAfter}}`
    } | Export-Csv -NoClobber -Append "$CacheFldr\Certificates.csv" -NoTypeInformation

##Output AV Status
Get-CimInstance -Namespace root/SecurityCenter2 -ClassName AntivirusProduct | Out-File -FilePath "$CacheFldr\AV_Status.log"

##Bitlocker Status
Get-BitLockerVolume | Out-File -FilePath "$CacheFldr\Bitlocker_Status.log"

##Hardware Status
$Hardware = @()
$Hardware += Get-WmiObject Win32_ComputerSystem
$Hardware += Get-WmiObject Win32_BIOS
$Hardware | Out-File -FilePath "$CacheFldr\Hardware_Details.log"

<#
##Output C:\Windows\Temp Logshos
$A = Get-ChildItem -Path C:\Windows\temp\* -Include ('*.txt', '*.log', '*.etl') -Recurse
($A[1].DirectoryName).Substring(16)

#>

##Compress Logs
Compress-Archive -Path $CacheFldr\* -DestinationPath $zipfile

##Upload File
$name = (Get-Item $zipfile).Name
$uri = "https://skyukclienttech.blob.core.windows.net/logs/$($name)$TokenTail"
$headers = @{
    'x-ms-blob-type' = 'BlockBlob'
}
Invoke-RestMethod -Uri $uri -Method Put -Headers $headers -InFile $zipfile

#Clean-up
Start-Sleep 10
Remove-Item -Path $CacheFldr -Recurse -Force

Remove-item -Path $CacheFldr\* -Force