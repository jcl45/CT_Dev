<#
.SYNOPSIS
  <Overview of script>

.DESCRIPTION
  <Brief description of script>

.PARAMETER <Parameter_Name>
  <Brief description of parameter input required. Repeat this attribute if required>

.INPUTS
  <Inputs if any, otherwise state None>

.OUTPUTS Log File
  The script log file stored in C:\Windows\Temp\<name>.log

.NOTES
  Version:        1.0
  Author:         <Name>
  Creation Date:  <Date>
  Purpose/Change: Initial script development

.EXAMPLE
  <Example explanation goes here>
  
  <Example goes here. Repeat this attribute for more than one example>
#>

##*=============================================================================================================================================
##*                                               VARIABLE DECLARATION
##*=============================================================================================================================================
$Name = "Sky_App_Packaging_01"
$CacheFldr = "C:\ProgramData\Sky\Cache\$Name"
$LOUsr = (Get-CimInstance -class Win32_ComputerSystem -ErrorAction SilentlyContinue).username.substring(6)

##*=============================================================================================================================================
##*                                                     FUNCTIONS
##*=============================================================================================================================================
Function GHDownLatest {
    Param ($Res, $Pat)
    $GHRel = "https://api.github.com/repos/$Res/releases/latest"
    $GHRaw = (((Invoke-WebRequest $GHRel) | ConvertFrom-Json).assets.browser_download_url | select-string -Pattern "$Pat").Line
    $Script:DLFile = "$CacheFldr\$($GHRaw.Substring($GHRaw.LastIndexOf('/') +1))"
    Invoke-WebRequest $GHRaw -OutFile "$DLFile"
}

Function IntunePKG {
    Rename-Item -Path "$CacheFldr\TempDir\Toolkit" -NewName "Source"
    New-Item -Path "$CacheFldr" -Name "Intunewin" -ItemType Directory -Force
    New-Item -Path "$CacheFldr" -Name "Requirements" -ItemType Directory -Force
    New-Item -Path "$CacheFldr" -Name "Detection" -ItemType Directory -Force
    New-Item -Path "$CacheFldr" -Name "Logo" -ItemType Directory -Force
}

##*=============================================================================================================================================
##*                                                     EXECUTION
##*=============================================================================================================================================

if (!(Test-path $CacheFldr)) {Invoke-Expression -Command:"md $CacheFldr"}
if ((Get-ChildItem -Path $CacheFldr).count -gt 0) {Remove-Item "$CacheFldr\*" -Recurse -Force}

GHDownLatest -Res 'PSAppDeployToolkit/PSAppDeployToolkit' -Pat 'zip'
Start-Sleep 3

try {
    New-Item -Path "$CacheFldr" -Name "TempDir" -ItemType Directory -Force
    Expand-Archive -Path "$DLFile" -DestinationPath "$CacheFldr\TempDir"
    Copy-Item "$CacheFldr\TempDir\Toolkit\" $CacheFldr -Recurse
}
finally {
    Get-ChildItem -Path $CacheFldr | Where-Object Name -like "PSAppDeployToolkit*" | Remove-Item -Force
    if (Test-Path "$CacheFldr\TempDir") {Remove-Item "$CacheFldr\TempDir" -Recurse -Force}
}

#Update Log file location
$xmlFile = "$CacheFldr\Toolkit\AppDeployToolkit\AppDeployToolkitConfig.xml"
$xml = [xml](Get-Content -Path "$xmlFile")
$xml.AppDeployToolkit_Config.Toolkit_Options.Toolkit_LogPath = "`$envWinDir\BSKYB_Logs"
$xml.Save($xmlFile)

Rename-Item -Path "$CacheFldr\Toolkit" -NewName "Source"
$NName = Read-Host "Enter Package Name"
Rename-Item -Path "$CacheFldr" -NewName $NName
$CacheFldr = $CacheFldr.trim($Name) + $NName



################## Needs work, clean up sections ##################



Function CleanUpLines {
    param ($From, $FMod, $To, $TMod)
    $Start = $AL.IndexOf(($AL -like "*$From*")[0]) + $FMod
    $Finish = $AL.IndexOf(($AL -like "*$To*")[0]) + $TMod
    $End = ($Finish - $Start)
    $Tick = 0
    do {
        $Tick = $Tick +1
        $AL.removeat($Start)
    } until ($Tick -eq $End)
}

function Clean-InstTop {
    #Installation Section
    CleanUpLines -From "deploymentType -ine 'Uninstall' -and" -To "deploymentType -ieq 'Uninstall'"
    $LModI = $AL.IndexOf(($AL -like "*deploymentType -ieq 'Uninstall'*")[0])
    $AL[$LModI] = "    If (`$deploymentType -ieq 'Uninstall') {"
    $InstS = $true
}

function Clean-UninTop {
    #Installation Section
    CleanUpLines -From "deploymentType -ieq 'Uninstall'" -To "deploymentType -ieq 'Repair'"
}

function Clean-RepTop {
    #Installation Section
    CleanUpLines -From "deploymentType -ieq 'Repair'" -To "END SCRIPT BODY" -TMod "-1"
}

function Clean-PreInst {
    #Pre-Installation Section
    param ($PIS, $SWM, $SPM)
    if ($PIS) {CleanUpLines -From "installPhase = 'Pre-Installation'" -FMod "-3" -To "Perform Pre-Installation tasks here" -TMod "+3"}
    if ($SWM) {CleanUpLines -From "Show Welcome Message" -To "Show Welcome Message" -TMod "+3"}
    if ($SPM) {CleanUpLines -From "Show Progress Message" -To "Show Progress Message" -TMod "+3"}
}

function Clean-Inst {
    #Installation Section
    CleanUpLines -From "Handle Zero-Config MSI Installations" -To "Perform Installation tasks here"
}

function Clean-PostInst {
  param ($PIM, $PIA)
    #Post-Installation Section
    if ($PIM) {CleanUpLines -From "Display a message at the end of the install" -To "deploymentType -ieq 'Uninstall'" -TMod "-1"}
    if ($PIA) {CleanUpLines -From "installPhase = 'Post-Installation'" -FMod "-3" -To "deploymentType -ieq 'Uninstall'" -TMod "-1"}
}

####
[System.Collections.ArrayList]$Script:AL = Get-Content -Path "$CacheFldr\Source\Deploy-Application.ps1"


IntunePKG

Clean-PreInst -PIS $true
Clean-Inst
Clean-PostInst -PIM $true
Clean-UninTop
Clean-RepTop


$SDate = $AL.IndexOf(($AL -like "*appScriptDate*")[0])
$AL[$SDate] = $AL[$SDate].Substring(0,29) + "`'$(Get-Date -Format "dd/MM/yy")`'"

$SAuth = $AL.IndexOf(($AL -like "*appScriptAuthor*")[0])
$AL[$SAuth] = $AL[$SAuth].Substring(0,31) + "`'$LOUsr`'"

$InArray = @"
        Write-Log -Message "Adding the BSkyB custom registry keys"
        `$RegPath = "`$appName``_`$appVersion"
        New-Item -Path "HKLM:\SOFTWARE\BskyB\Packages" -Name "`$RegPath" -Force
        New-ItemProperty -Path "HKLM:\SOFTWARE\BskyB\Packages\`$RegPath" -Name "Application Name" -Value "`$appName" -PropertyType String -Force -Verbose
        New-ItemProperty -Path "HKLM:\SOFTWARE\BskyB\Packages\`$RegPath" -Name "Application Version" -Value "`$appVersion" -PropertyType String -Force -Verbose
        New-ItemProperty -Path "HKLM:\SOFTWARE\BskyB\Packages\`$RegPath" -Name "Installed" -Value ((Get-Date).ToShortDateString()) -PropertyType String -Force -Verbose
"@

$PISt = $AL.IndexOf(($AL -like "*Perform Post-Installation tasks here*")[0])
$AL.removeat($PISt)
$AL.Insert($PISt, $InArray)

$AL | Out-File -FilePath "$CacheFldr\Source\Deploy-Application.ps1" -Force

$WshShell = New-Object -comObject WScript.Shell
$Shortcut = $WshShell.CreateShortcut("$CacheFldr\PSAppDeployToolkit.pdf.url")
$Shortcut.TargetPath = "https://github.com/PSAppDeployToolkit/PSAppDeployToolkit/blob/master/PSAppDeployToolkit.pdf"
$Shortcut.Save()


##################################################################