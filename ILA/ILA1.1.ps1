#Multithread Declaration
$syncHash = [hashtable]::Synchronized(@{})
$MaxThreads = 3
$newRunspace = [runspacefactory]::CreateRunspacePool(1, $MaxThreads)
#$newRunspace =[runspacefactory]::CreateRunspace()
$newRunspace.ApartmentState = "STA"
$newRunspace.ThreadOptions = "ReuseThread"         
$newRunspace.Open()
$newRunspace.SessionStateProxy.SetVariable("syncHash",$syncHash)

#Global Variables
$global:nl = "`r`n"
$syncHash.C = 0

#Global Functions
function DateTime {
    $Script:TD = (Get-Date).toString("dd/MM HH:mm")
}

function ConnectMSGraph {
    $OutP = $null
    try {
        $OutP = Get-Organization -ErrorAction SilentlyContinue
    }
    catch {
        Connect-MSGraph
    }
    DateTime
    if ($null -eq $OutP) {
        #$WPFOutPutBox.AppendText("$TD :  Not Connected $nl")
        $syncHash.ConStatMSG.Text = "MS Graph: Not Connected"
    } else {
        #$WPFOutPutBox.AppendText("$TD :  Connected to MS Graph $nl")
        $syncHash.ConStatMSG.Text = "MS Graph: Connected"
    } 
}

function ConnectMgGraph {
    $OutP = $null
    try {
        $OutP = Get-MgEnvironment -ErrorAction SilentlyContinue
    }
    catch {
        Connect-MgGraph -Scopes "User.ReadWrite.All", "Directory.ReadWrite.All", "DeviceManagementManagedDevices.ReadWrite.All" -NoWelcome
    }
    DateTime
    if ($null -eq $OutP) {
        #$WPFOutPutBox.AppendText("$TD :  Not Connected $nl")
        $syncHash.ConStatMSG.Text = "MS Graph: Not Connected"
    } else {
        #$WPFOutPutBox.AppendText("$TD :  Connected to MS Graph $nl")
        $syncHash.ConStatMSG.Text = "MS Graph: Connected"
    } 
}

function DevSerialTrim {
    $syncHash.DevSerial.Text = $syncHash.DevSerial.Text.Trim();
}

function ListBoxUpdate {
    $Global:DevArray = @()
    $DevArray = $syncHash.DevSerial.Text
    $DevArray = ($DevArray.Trim()).split([environment]::NewLine,[System.StringSplitOptions]"RemoveEmptyEntries")
    $DevArray = $DevArray.Trim()
    $DevArray = $DevArray.TrimStart("UK,GB")
    $syncHash.DevSerial.Text = $null
    $DevArray | ForEach-Object {
        $syncHash.DevSerial.AppendText("$_`r`n")
    }
    $LC = $syncHash.DevSerial.LineCount
    $syncHash.DevCount.Text = "Device: $LC"
    if ($syncHash.DevSerial.Text.count -gt 0) {
        if ($syncHash.DevArray.count -gt 0) {
            $syncHash.DevArray = $DevArray
        } else {$syncHash.Add('DevArray',$DevArray)}
    }
}

function CallMSGraph {
    Param (
    [Parameter(Mandatory=$true, Position=0)]
    [String]$Res,
    [Parameter(Mandatory=$true, Position=1)]
    [String]$Ver,
    [Parameter(Mandatory=$false, Position=2)]
    [String]$Extra
    )
    $Script:GraphReturn = $null
    $uri = "https://graph.microsoft.com/$Ver/$($Res)$($Extra)"
    $Script:GraphReturn = Invoke-MSGraphRequest -HttpMethod GET -Url $uri
}

function CallMgGraph {
    Param (
    [Parameter(Mandatory=$true, Position=0)]
    [String]$Meth,
    [Parameter(Mandatory=$true, Position=1)]
    [String]$Res,
    [Parameter(Mandatory=$true, Position=2)]
    [String]$Ver,
    [Parameter(Mandatory=$false, Position=3)]
    [String]$Extra
    )
    $Global:GraphReturn = $null
    $uri = "https://graph.microsoft.com/$Ver/$($Res)$($Extra)"
    $Global:GraphReturn = Invoke-MgGraphRequest -method $Meth -Uri $uri
}

function MTTest {
    $PowerShell = [powershell]::Create()
	$PowerShell.RunspacePool = $newRunspace
	$PowerShell.AddScript($ScriptBlock).AddArgument($($syncHash.C = $syncHash.C =1))
	$Jobs += $PowerShell.BeginInvoke()
}

function MTMsGraph {
    param($Meth,$Res,$Ver,$Extra,$DataS)

    $DataS | Foreach-Object {
    $PowerShell = [powershell]::Create()
    $PowerShell.RunspacePool = $newRunspace
    $PowerShell.AddScript({
        $uri = "https://graph.microsoft.com/$Ver/$($Res)$($Extra)"
        Invoke-MgGraphRequest -method $Meth -Uri $uri
    })
    $Jobs += $PowerShell.BeginInvoke()
}}



#WPF Window
$CacheDir = "C:\ProgramData\Sky\Cache\ILA"
if (!(Test-Path $CacheDir)){Invoke-Expression -Command:"md $CacheDir"}
Invoke-RestMethod -Uri "https://raw.githubusercontent.com/jcl45/CT_Dev/main/ILA/ILA/MainWindow.xaml" -OutFile "$CacheDir\MainWindow.xaml"
$inputXML = Get-Content "$CacheDir\MainWindow.xaml" #XAML Raw
$inputXML = $inputXML -replace 'mc:Ignorable="d"','' -replace "x:N",'N' -replace '^<Win.*', '<Window'
[void][System.Reflection.Assembly]::LoadWithPartialName('presentationframework')
[xml]$XAML = $inputXML

#Read XAML 
$reader = (New-Object System.Xml.XmlNodeReader $xaml)
try {
    $syncHash.Window = [Windows.Markup.XamlReader]::Load( $reader )
} catch {
    Write-Warning "Unable to parse XML, with error: $PSItem `n Ensure that there are NO SelectionChanged or TextChanged properties in your textboxes (PowerShell cannot process them)"
    throw
}


#Load XAML Objects In PowerShell
$xaml.SelectNodes("//*[@Name]") | ForEach-Object {
    try {
        Write-Output "Adding $($PSItem.Name)"
        $syncHash.Add($PSItem.Name,$syncHash.Window.FindName($PSItem.Name))
    } catch {
        throw
    }
}


#Control GUI Elements
$syncHash.DevSerial.Add_SelectionChanged({
    $LC = $syncHash.DevSerial.LineCount
    $syncHash.DevCount.Text = "Device: $LC"
})

$syncHash.RemIntObj.Add_Click({




    $syncHash.OutPutBox.AppendText("$($syncHash.C)$nl")

    <#ListBoxUpdate
    if ($syncHash.DevArray.count -gt 1) {
        $syncHash.DevArray | ForEach-Object {
            $syncHash.OutPutBox.AppendText("$($_)$nl")
        }
    } else {
        $syncHash.OutPutBox.AppendText("$($syncHash.DevArray)$nl")
    }#>


})


#Show the form
## check if a command is still running when exiting the GUI
$syncHash.Window.add_Closing({
    if ($null -ne $Session -and $Handle.IsCompleted -eq $false) {
        [Windows.MessageBox]::Show('A command is still running.')
        # the event object is automatically passed through as $_
        $PSItem.Cancel = $true
    }
})

$syncHash.Window.add_Closed({
    if ($null -ne $Session) {
        $Session.EndInvoke($Handle)
    }

    $newRunspace.Close()
})

$syncHash.Window.ShowDialog() | Out-Null