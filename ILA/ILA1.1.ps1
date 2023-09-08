#Multithread Declaration
$syncHash = [hashtable]::Synchronized(@{})
$newRunspace =[runspacefactory]::CreateRunspace()
$newRunspace.ApartmentState = "STA"
$newRunspace.ThreadOptions = "ReuseThread"         
$newRunspace.Open()
$newRunspace.SessionStateProxy.SetVariable("syncHash",$syncHash)

#Global Variables
$nl = "`r`n"

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
    $Global:DevArray = $null
    #work out how to handle blank spaces
    $syncHash.DevSerial.Text = ($syncHash.DevSerial.Text.Trim()).split([environment]::NewLine,[System.StringSplitOptions]"RemoveEmptyEntries")
    if ($syncHash.DevSerial.Text.count -gt 0) {
        $Global:DevArray = ($syncHash.DevSerial.Text.Trim()).split([environment]::NewLine,[System.StringSplitOptions]"RemoveEmptyEntries")
        $Global:DevArray = $Script:DevArray.TrimStart("UK,GB")
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
    $Script:GraphReturn = $null
    $uri = "https://graph.microsoft.com/$Ver/$($Res)$($Extra)"
    $Script:GraphReturn = Invoke-MgGraphRequest -method $Meth -Uri $uri
}





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
    ListBoxUpdate
    $syncHash.OutPutBox.AppendText("$Script:DevArray")
    
    if ($DevArray.count -gt 0) {
        $global:Session = [PowerShell]::Create().AddScript({
            $syncHash.Window.Dispatcher.Invoke(
                    [action]{
                        $syncHash.OutPutBox.AppendText("$($syncHash.DevArray)")
                    },"Normal"
                )
            
            <#
            function SyncHashAct {
                Param (
                [Parameter(Mandatory=$true, Position=0)]
                [String]$Action
                )
                $syncHash.Window.Dispatcher.Invoke(
                    [action]{
                        $syncHash.$Action
                    },"Normal"
                )
            }

            ConnectMgGraph
            $syncHash.OutPutBox.AppendText("$nl========================================== $nl$TD :  Assessing Devices $nl")
            $Script:GraphR1 = $null
            $Script:Output = @()
            $Recent = @()
            $ObjRem = @()
            $NoObj = @()
        
            $Script:DevArray | ForEach-Object {
                CallMSGraph "GET" "deviceManagement/managedDevices" "v1.0" "?`$filter=SerialNumber+eq+'$_'&`$select=id,lastSyncDateTime"
                $OutRaw = $GraphReturn.value
                if ($OutRaw.value.lenght -gt 0){
                    if (($OutRaw.value.lastSyncDateTime -lt (Get-Date).AddDays(-14)) -or ($syncHash.Bypass14.IsChecked)) {
                        #CallMSGraph "DELETE" "deviceManagement/managedDevices/$($OutRaw.value.id)"
                         
                        #Remove-IntunemanagedDevice -manageddeviceID ($Script:GraphR1.ID) -Verbose
                        $ObjRem += "$_"
                    } else {$Recent += "$_"}
                } else {$NoObj += "$_"}
            }

            if ($Recent.count -ne 0) {
                SyncHashAct "OutPutBox.AppendText("$TD :  Below Objects with Recent Intune Sync: $nl")"
                #$syncHash.OutPutBox.AppendText("$TD :  Below Objects with Recent Intune Sync: $nl")
                $Recent | ForEach-Object {
                    SyncHashAct "OutPutBox.AppendText("         $_ $nl")"
                }
            }
    
            if ($ObjRem.count -ne 0) {
                SyncHashAct "OutPutBox.AppendText("$TD :  Below Objects Removed: $nl")"
                $ObjRem | ForEach-Object {
                    SyncHashAct "OutPutBox.AppendText("         $_ $nl")"
                }
            }
    
            if ($NoObj.count -ne 0) {
                SyncHashAct "OutPutBox.AppendText("$TD :  No Objects Found for Below Serial Number: $nl")"
                $NoObj | ForEach-Object {
                    SyncHashAct "OutPutBox.AppendText("         $_ $nl")"
                }
            }

        #>

        })
    }
    #>
        $Session.Runspace = $newRunspace
        $global:Handle = $Session.BeginInvoke()
})





        


        #https://graph.microsoft.com/v1.0/deviceManagement/managedDevices?$filter=SerialNumber+eq+'H6Y85M3'&$select=id




        <#
        if ($Script:DevArray.count -gt 10) {Get-Graph "deviceManagement/managedDevices" "GET"} else {$Script:DevArray | ForEach-Object {
            if ($_ -like "UK*") {$SNT = $_.TrimStart("UK")} else {$SNT = $_}
            $Script:Output += (Get-IntuneManagedDevice -Filter "SerialNumber eq '$SNT'")  
            }
        }

        
        
        $Script:DevArray | ForEach-Object {
            #$WPFOutPutBox.AppendText("$TD :  Assessing Device: $_ $nl")
            if ($_ -like "UK*") {$SNT = $_.TrimStart("UK")} else {$SNT = $_}
            #$Script:GraphR1 = (Get-IntuneManagedDevice -Filter "SerialNumber eq '$SNT'")
            $Script:GraphR1 = $Script:Output | Where-Object SerialNumber -eq "$SNT"

            if ($null -ne $Script:GraphR1) {
                if (([datetime]($Script:GraphR1.lastSyncDateTime) -lt (Get-Date).AddDays(-14)) -or ($WPFBypass14.IsChecked)) {
                    #$WPFOutPutBox.AppendText("$TD :    --> Device Sync > 14 days $nl")
                    Remove-IntunemanagedDevice -manageddeviceID ($Script:GraphR1.ID) -Verbose
                    #$WPFOutPutBox.AppendText("$TD :    --> Object Removal initiated $nl")
                    $ObjRem += "$_"
                } else {
                    #$WPFOutPutBox.AppendText("$TD :    --> Device Last Sync Within 14 days. Last Sync: $($Script:GraphR1.lastSyncDateTime) $nl")
                    $Recent += "$_"
                }
            } else {
                #$WPFOutPutBox.AppendText("$TD :    --> No Object Found $nl")
                $NoObj += "$_"
            }
            #Start-Sleep 2
        }
    
        if ($Recent.count -ne 0) {
            $WPFOutPutBox.AppendText("$TD :  Below Objects with Recent Intune Sync: $nl")
            $Recent | ForEach-Object {
                $WPFOutPutBox.AppendText("         $_ $nl")
            }
        }

        if ($ObjRem.count -ne 0) {
            $WPFOutPutBox.AppendText("$TD :  Below Objects Removed: $nl")
            $ObjRem | ForEach-Object {
                $WPFOutPutBox.AppendText("         $_ $nl")
            }
        }

        if ($NoObj.count -ne 0) {
            $WPFOutPutBox.AppendText("$TD :  No Objects Found for Below Serial Number: $nl")
            $NoObj | ForEach-Object {
                    $WPFOutPutBox.AppendText("         $_ $nl")
            }
        }
    } 
    if ($WPFBypass14.IsChecked) {$WPFBypass14.IsChecked = $False}
    #>
#})



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