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
##*                                                 SCRIPT PARAMETERS
##*=============================================================================================================================================

Param (
  #Script parameters go here
)

##*=============================================================================================================================================
##*                                                  INITIALISATIONS
##*=============================================================================================================================================



##*=============================================================================================================================================
##*                                               VARIABLE DECLARATION
##*=============================================================================================================================================
$Name = "ILA"
$CacheDir = "C:\ProgramData\Sky\Cache\$Name"
$GHUri = "https://raw.githubusercontent.com/jcl45/CT_Dev/main/ILA/ILA/MainWindow.xaml"
$Global:Scriptblock = $null


##*=============================================================================================================================================
##*                                                     FUNCTIONS
##*=============================================================================================================================================
function ConnectMgGraph {
    try {$OutP = Get-MgOrganization -ErrorAction Stop}
    catch {Connect-MgGraph -Scopes "User.ReadWrite.All", "Directory.ReadWrite.All", "DeviceManagementManagedDevices.ReadWrite.All" -NoWelcome}
}

function CallMgGraph {
    Param ($Meth, $Res, $Ver, $Extra)
    ConnectMgGraph
    $Global:GraphReturn = $null
    $uri = "https://graph.microsoft.com/$Ver/$($Res)$($Extra)"
    $GraphReturn = Invoke-MgGraphRequest -method $Meth -Uri $uri
    $Script:GrRaw = $GraphReturn.value
    $OutputNextLink = $GraphReturn."@odata.nextLink"
    while ($null -ne $OutputNextLink){
            $GraphReturn = (Invoke-MSGraphRequest -HttpMethod $Method -Url $OutputNextLink -Verbose)
            $OutputNextLink = $GraphReturn."@odata.nextLink"
            $Script:GrRaw += $GraphReturn.value
            }
}

function RunSpacePool {
    param ($Scriptblock, $TargArray)
    $RunspacePool = [RunspaceFactory]::CreateRunspacePool(5,5)
    $RunspacePool.Open()
    $Jobs = 
        $TargArray | ForEach-Object {
                $Job = [powershell]::Create().
                        AddScript($ScriptBlock)
                $Job.RunspacePool = $RunspacePool

                [PSCustomObject]@{
                Pipe = $Job
                Result = $Job.BeginInvoke()
                }
            }

    Write-Host 'Working..' -NoNewline
    Do {
    Write-Host '.' -NoNewline
    Start-Sleep -Seconds 1
    } While ( $Jobs.Result.IsCompleted -contains $false)

    $TargArray | ForEach-Object 
    { $Job.Pipe.EndInvoke($Job.Result) }
    $RunspacePool.Close()
    $RunspacePool.Dispose()
}



##*=============================================================================================================================================
##*                                                 GUI PREPERATION
##*=============================================================================================================================================

## Get XAML App Content
if (!(Test-Path "$CacheDir\MainWindow.xaml")) {
    if (!(Test-Path $CacheDir)) {Invoke-Expression -Command:"md $CacheDir"}
    Invoke-RestMethod -Uri "$GHUri" -OutFile "$CacheDir\MainWindow.xaml"
}
$inputXML = Get-Content "$CacheDir\MainWindow.xaml" #XAML Raw

## Parse XAML to PoSH use
$inputXML = $inputXML -replace 'mc:Ignorable="d"','' -replace "x:N",'N' -replace '^<Win.*', '<Window'
[void][System.Reflection.Assembly]::LoadWithPartialName('presentationframework')
[xml]$XAML = $inputXML
    
## Read XAML 
$reader=(New-Object System.Xml.XmlNodeReader $xaml)
try {
    $Form = [Windows.Markup.XamlReader]::Load( $reader )
} catch {
    Write-Warning "Unable to parse XML, with error: $($Error[0])`n Ensure that there are NO SelectionChanged or TextChanged properties in your textboxes (PowerShell cannot process them)"
    throw
}

## Load XAML Objects In PowerShell
$xaml.SelectNodes("//*[@Name]") | ForEach-Object {
try {Set-Variable -Name "WPF$($_.Name)" -Value $Form.FindName($_.Name) -ErrorAction Stop}
    catch {throw}
}

$WPFRemIntObj.Add_Click({

    $Scriptblock = 
    {
        CallMgGraph -Meth 'Get' -Ver 'v1.0' -Res 'deviceManagement/managedDevices' -Extra "?`$filter=serialNumber eq '$($_)'"
        Add-Content -Path "C:\Temp\Cache\ILA.log" -Value "$GrRaw"
        <#  [PSCustomObject]@{
        Address = $Address
        Ping    = $ping_result
        DNS     = $hostname
        }#>
    }




    $TargArray = $WPFDevSerial.Text

    #Write-Host "$TargArray"
    RunSpacePool -Scriptblock $Scriptblock -TargArray $TargArray



})


##*=============================================================================================================================================
##*                                                     EXECUTION
##*=============================================================================================================================================

#Show GUI Window
$Form.ShowDialog() | out-null