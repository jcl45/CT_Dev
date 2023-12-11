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
Invoke-Command  {reg export 'HKLM\SOFTWARE\BskyB' "$CacheFldr\BskyB.reg"}

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
$AVArray = @()
$AVInfo = Get-CimInstance -Namespace root/SecurityCenter2 -ClassName AntivirusProduct
$AVInfo | ForEach-Object {
    switch ($_.productState) {
        "262144" {$AVState = "Disabled & Up to date. State Code: 262144"}
        "262160" {$AVState = "Disabled & Out of date. State Code: 262160"}
        "266240" {$AVState = "Enabled & Up to date. State Code: 266240"}
        "266256" {$AVState = "Enabled & Out of date. State Code: 266256"}
        "393216" {$AVState = "Disabled & Up to date. State Code: 393216"}
        "393232" {$AVState = "Disabled & Out of date. State Code: 393232"}
        "393488" {$AVState = "Disabled & Out of date. State Code: 393488"}
        "397312" {$AVState = "Enabled & Up to date. State Code: 397312"}
        "397328" {$AVState = "Enabled & Out of date. State Code: 397328"}
        "397584" {$AVState = "Enabled & Out of date. State Code: 397584"}
        "397568" {$AVState = "Enabled & Up to date. State Code: 397568"}
        "393472" {$AVState = "Disabled & Up to date. State Code: 393472"}
        default {$AVState = "Unknown"}
    }
    $AVArray += "$($_.displayName) : $AVState"
}
$AVArray | Out-File -Force -FilePath "$CacheFldr\AV_Status.log"
Invoke-Command  {reg export 'HKLM\SOFTWARE\Policies\Microsoft\Windows Defender' "$CacheFldr\Win_Defender_Pol.reg"}

##Bitlocker Status
Get-BitLockerVolume | Out-File -FilePath "$CacheFldr\Bitlocker_Status.log"

##Hardware Status
$Hardware = @()
$Hardware += Get-WmiObject Win32_ComputerSystem
$Hardware += Get-WmiObject Win32_BIOS
$Hardware | Out-File -FilePath "$CacheFldr\Hardware_Details.log"


##Output System Logs
function SysLogExpo {
    param ($LPath, $ExpoPath, $SS)
    $Logs1 = Get-ChildItem -Path $LPath\* -Include ('*.txt', '*.log', '*.etl') -Exclude ('NOTICE.txt') -Recurse -ErrorAction SilentlyContinue
    $Folders = $Logs1.DirectoryName -gt $LPath
    $Folders | ForEach-Object {
        $CacheSubFldr = "$CacheFldr\$ExpoPath\$($_.Substring($SS))"
        if (-Not(Test-Path $CacheSubFldr)) {
            Write-Host $true
            Invoke-Command  {mkdir $CacheSubFldr}
        }
    }
    $Logs1 | ForEach-Object {
        if ($_.DirectoryName -gt "$LPath") {
            $Destination = "$CacheFldr\$ExpoPath\$($_.DirectoryName.Substring($SS))"
        } else {
            $Destination = "$CacheFldr\$ExpoPath\"
        }
        Copy-Item -Path $_.fullname -Destination $Destination
    }
}
###Output Windows Temp Folder Logs
SysLogExpo -LPath 'C:\Windows\Temp' -ExpoPath 'Windows_Temp' -SS 16
###Output Windows Logs Folder Logs
SysLogExpo -LPath 'C:\Windows\Logs' -ExpoPath 'Windows_Logs' -SS 16
###Output Windows Panther Folder Logs
SysLogExpo -LPath 'C:\Windows\Panther' -ExpoPath 'Windows_Panther' -SS 19
###Output All Users Temp Folder Logs
$UsrProf = Get-ChildItem c:\Users | Where-Object {($_.Name -ne 'defaultuser0') -And ($_.Name -ne 'Public') -And ($_.Name -notlike '*-2')}
$UsrProf | ForEach-Object {
    $UPath = "$($_.FullName)\AppData\Local\Temp"
    SysLogExpo -LPath "$UPath" -ExpoPath "$($_)_Local_Temp" -SS 34
} 
###Output ProgramData Folder Logs
SysLogExpo -LPath 'C:\ProgramData\Cisco' -ExpoPath 'ProgramData_Logs' -SS 15
SysLogExpo -LPath 'C:\ProgramData\Dell' -ExpoPath 'ProgramData_Logs' -SS 15
SysLogExpo -LPath 'C:\ProgramData\Microsoft\UpdateOS' -ExpoPath 'ProgramData_Logs' -SS 15
SysLogExpo -LPath 'C:\ProgramData\Nexthink' -ExpoPath 'ProgramData_Logs' -SS 15

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
