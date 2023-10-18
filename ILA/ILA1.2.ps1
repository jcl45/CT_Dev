#Add-Type –assemblyName PresentationFramework
 
$MaxThreads = 5
$newRunspace = [runspacefactory]::CreateRunspacePool(1, $MaxThreads)
$Runspace.ApartmentState = "STA"
$Runspace.ThreadOptions = "ReuseThread"
$Runspace.Open()
 
$code = {
 
#Build the GUI
$CacheDir = "C:\ProgramData\Sky\Cache\ILA"
if (!(Test-Path $CacheDir)){Invoke-Expression -Command:"md $CacheDir"}
if (!(Test-Path $CacheDir\$Layout)) {Invoke-RestMethod -Uri "https://raw.githubusercontent.com/jcl45/CT_Dev/main/ILA/ILA/MainWindow.xaml" -OutFile "$CacheDir\MainWindow.xaml"}
$inputXML = Get-Content "$CacheDir\MainWindow.xaml" #XAML Raw
$inputXML = $inputXML -replace 'mc:Ignorable="d"','' -replace "x:N",'N' -replace '^<Win.*', '<Window'
[void][System.Reflection.Assembly]::LoadWithPartialName('presentationframework')
[xml]$XAML = $inputXML
$syncHash = [hashtable]::Synchronized(@{})
$reader=(New-Object System.Xml.XmlNodeReader $xaml)
$syncHash.Window=[Windows.Markup.XamlReader]::Load( $reader )
 
# Runspace Functions
function MTTest {
    $syncHash.C
    $PowerShell = [powershell]::Create()
	$PowerShell.RunspacePool = $RunspacePool

	$PowerShell.AddScript($ScriptBlock).AddArgument($($syncHash.C = $syncHash.C =1))
	$Jobs += $PowerShell.BeginInvoke()
}
 
# XAML objects
$syncHash.DevCount = $syncHash.Window.FindName("DevCount")



$syncHash.DevSerial.Add_SelectionChanged({
 
    $syncHash.Host = $host
    $Runspace = [runspacefactory]::CreateRunspace()
    $Runspace.ApartmentState = "STA"
    $Runspace.ThreadOptions = "ReuseThread"
    $Runspace.Open()
    $Runspace.SessionStateProxy.SetVariable("DevCount",$syncHash.DevCount) 

    $code = {
        #$LC = $syncHash.DevSerial.LineCount
        
        $syncHash.Window.Dispatcher.invoke(
        [action]{ $syncHash.DevCount.Text = "Device: 1" }
        )
    }
    $PSinstance = [powershell]::Create().AddScript($Code)
    $PSinstance.Runspace = $Runspace
    $job = $PSinstance.BeginInvoke()

})



$syncHash.Window.ShowDialog()
$Runspace.Close()
$Runspace.Dispose()
 
}
 
$PSinstance1 = [powershell]::Create().AddScript($Code)
$PSinstance1.Runspace = $Runspace
$job = $PSinstance1.BeginInvoke()