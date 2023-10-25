#Global Variables
$FlgPath = "HKLM:\SOFTWARE\BskyB\Baseline\Defender"
$Logfile = "C:\Windows\BSKYB_LOGS\CS_Falcon_Re-Registration.log"
$Count = 0

#Function
Function LogWrite{
    Param ([string]$logstring)
    $Stamp = (Get-Date).toString("yyyy/MM/dd HH:mm:ss")
    $fullString = $stamp + ": " + $logstring
    Add-content $Logfile -value $fullString
}

#Stamp Registry
if (!(Test-Path -Path HKLM:\SOFTWARE\BskyB\Baseline)) {New-Item -Path HKLM:\SOFTWARE\BskyB -Name "Baseline"}
if (!(Test-Path -Path $FlgPath)) {New-Item -Path HKLM:\SOFTWARE\BskyB\Baseline -Name "Defender"}
if ($null -eq (Get-Item -Path $FlgPath).GetValue("CI_Remediation_Count")) {
    $Count = 1
} else {
    $Count = ([int](Get-ItemProperty -Path "$FlgPath")."CI_Remediation_Count") + 1
}
New-ItemProperty -Path "$FlgPath" -Name "CI_Remediation_Count" -Value "$Count" -PropertyType String -Force
New-ItemProperty -Path "$FlgPath" -Name "CS_Falcon_Re-Registered" -Value "$((Get-Date).toString("dd/MM/yy"))" -PropertyType String -Force


#Trigger Windows Security to Re-regiser CS Falcon
New-ItemProperty -Path "HKLM:\Software\Policies\Microsoft\Windows Defender" -Name "DisableAntiSpyware" -Value "1" -PropertyType DWord -Force -Verbose
LogWrite "Run count: $count  ::  Re-registering CS Falcon"
Invoke-Expression -Command "GPupdate /Force"