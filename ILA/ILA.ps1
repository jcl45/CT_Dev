# Run Script As


# Global Variables
$nl = "`r`n"
$Global:Stamp
Add-Type -AssemblyName System.Windows.Forms
$FileBrowser = New-Object System.Windows.Forms.OpenFileDialog -Property @{ 
    InitialDirectory = [Environment]::GetFolderPath('MyComputer') 
    Filter = 'SpreadSheet (*.csv)|*.csv|Documents (*.txt)|*.txt|Excel Worksheet (*xlsx)|*.xlsx'

}
$ScriptDir = Split-Path -Path $MyInvocation.MyCommand.Definition -Parent


# Global Array
#$DevInbox = @()


# Functions
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
        $WPFConStatMSG.Text = "MS Graph: Not Connected"
    } else {
        #$WPFOutPutBox.AppendText("$TD :  Connected to MS Graph $nl")
        $WPFConStatMSG.Text = "MS Graph: Connected"
    } 
}

function ConnectAAD {
    $OutP = $null
    try {
        $OutP = Get-AzureADTenantDetail
    }
    catch {
        Connect-AzureAD
    }
    DateTime
    if ($null -eq $OutP) {
        $WPFConStatAzAD.Text = "MS Graph: Not Connected"
    } else {
        $WPFConStatAzAD.Text = "MS Graph: Connected"
    } 
}


function DevSerialTrim {
    $WPFDevSerial.Text = $WPFDevSerial.Text.Trim();
}

function Get-Devices {
    $Numb = 1

    $URI = "deviceManagement/managedDevices"
    Write-host "Collecting Page $Numb results"
    $DBResponse = Invoke-MSGraphRequest -HttpMethod GET -Url $URI -Verbose

    $Script:Output = $DBResponse.value

    $OutputNextLink = $DBResponse."@odata.nextLink"

    while ($null -ne $OutputNextLink){
        $Numb = $Numb +1
        Write-Host "Collecting Page $Numb results"
        $DBResponse = (Invoke-MSGraphRequest -HttpMethod GET -Url $OutputNextLink -Verbose)
        $OutputNextLink = $DBResponse."@odata.nextLink"
        $Script:Output += $DBResponse.value
    }
}

function Get-Graph {
        [CmdletBinding()]
        param
        (
            [Parameter(Mandatory=$true, Position=0)]
            [string]$GraphResource,

            [Parameter(Mandatory=$true, Position=1)]
            [string]$Method
        )
        #$Numb = 1
        #Write-host "Collecting Page $Numb results"
        $DBResponse = Invoke-MSGraphRequest -HttpMethod $Method -Url $GraphResource -Verbose
    
        $Script:Output = $DBResponse.value
        $OutputNextLink = $DBResponse."@odata.nextLink"
        while ($null -ne $OutputNextLink){
            #$Numb = $Numb +1
            Write-Host "Collecting Page $Numb results"
            $DBResponse = (Invoke-MSGraphRequest -HttpMethod $Method -Url $OutputNextLink -Verbose)
            $OutputNextLink = $DBResponse."@odata.nextLink"
            $Script:Output += $DBResponse.value
            }
        }
        
function ListBoxUpdate {
    $Script:DevArray = $null
    $Script:DevArray = ($WPFDevSerial.Text.Trim()).split([environment]::NewLine,[System.StringSplitOptions]"RemoveEmptyEntries")
    }

function PopUpBoxD {
    param (
        [Parameter(Mandatory=$False, Position=0)]
        [string] $Context
    )
    $WPFWinBlank1.Visibility = "$Context"
    $WPFPopTB1.Visibility = "$Context"
    $WPFPopGrp1.Visibility = "$Context"
    $WPFPopOK1.Visibility = "$Context"
    $WPFPopCan1.Visibility = "$Context"
    $WPFPopBor1.Visibility = "$Context"
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
$reader=(New-Object System.Xml.XmlNodeReader $xaml)
try {
    $Form=[Windows.Markup.XamlReader]::Load( $reader )
} catch {
    Write-Warning "Unable to parse XML, with error: $($Error[0])`n Ensure that there are NO SelectionChanged or TextChanged properties in your textboxes (PowerShell cannot process them)"
    throw
}

#Load XAML Objects In PowerShell
$xaml.SelectNodes("//*[@Name]") | ForEach-Object {"trying item $($_.Name)";
    try {Set-Variable -Name "WPF$($_.Name)" -Value $Form.FindName($_.Name) -ErrorAction Stop} catch {throw}
}

#Control GUI Elements
$WPFDevSerial.Add_SelectionChanged({
    #$WPFDevSerial.Text = $WPFDevSerial.Text.Trim();
    $LC = $WPFDevSerial.LineCount
    $WPFDevCount.Text = "Device: $LC"
})

$WPFSelBoxBak.Add_Click({
    $WPFSelBoxFrame1.Visibility = "Hidden"
    $WPFSelBoxFrame2.Visibility = "Hidden"
    $WPFSelBoxBak.Visibility = "Hidden"
    $WPFSelBoxFN.Visibility = "Hidden"
    $WPFSelWST.Visibility = "Hidden"
    $WPFSelWSNBut.Visibility = "Hidden"
    $WPFSelLBox.Visibility = "Hidden"
    $WPFSelCT.Visibility = "Hidden"
    $WPFSelCBut.Visibility = "Hidden"
    PopUpBoxD Hidden                      
})

$WPFSelWSNBut.Add_Click({
    $WPFSelWST.Visibility = "Hidden"
    $WPFSelWSNBut.Visibility = "Hidden"
    $WPFSelLBox.Visibility = "Hidden"
    $WPFSelCT.Visibility = "Visible"
    $WPFSelCBut.Visibility = "Visible"
    $WPFOutPutBox.AppendText("$nl $AAAA")

})

#$WPFSelLBox_SelectedIndexChanged({
# $AAAA = $WPFSelLBox.SelectedItem.ToString()
#})

$WPFDevImpFile.Add_Click({
    $null = $FileBrowser.ShowDialog()
    $SelFile = $FileBrowser.FileName
    if ($SelFile.Length -gt 0) {
        if (($SelFile -like "*.csv") -or ($SelFile -like "*.xlsx")) {
            #$WPFOutPutBox.AppendText("$nl $SelFile")
            #Import-Module ImportExcel

            $RawSheetInfo = Get-ExcelSheetInfo -Path "$SelFile"
            $WPFOutPutBox.AppendText("$nl $RawSheetInfo")

                $WPFSelBoxFrame1.Visibility = "Visible"
                $WPFSelBoxFrame2.Visibility = "Visible"
                $WPFSelBoxBak.Visibility = "Visible"
                
                $WPFSelBoxFN.Visibility = "Visible"
                $WPFSelWST.Visibility = "Visible"
                $WPFSelWSNBut.Visibility = "Visible"
                $WPFSelLBox.Visibility = "Visible"
                
                $WPFSelBoxFN.Text = $SelFile
                $WPFSelLBox.Items.Clear()

                ($RawSheetInfo).Name | foreach-object {
                    [string]$AddN = $_
                    #$WPFOutPutBox.AppendText("$nl Tab $AddN")

                    $WPFSelLBox.Items.Add("$AddN")
                }  
                

                

                




            <#
            $RawImp = (Import-Csv -Path "$SelFile")."Display Name"
            $DevImpA = @()
            $RawImp | Foreach-Object {
                $RawHost = [String]$_.Split([string[]] "- ",[System.StringSplitOptions]"None")[1]
                $RawHost = $RawHost.replace(' ','')
            $DevImpA += $RawHost
            }
            #>
        } else {$DevImpA = Get-Content -Path "$SelFile"}
        Foreach ($Dev in $DevImpA) {
            $WPFDevSerial.AppendText("$nl$Dev")
        }
    }
    DevSerialTrim
})

$WPFRemIntObj.Add_Click({
    ListBoxUpdate
    if ($Script:DevArray.count -gt 0) {
        ConnectMSGraph
        $WPFOutPutBox.AppendText("$nl========================================== $nl$TD :  Assessing Devices $nl")
        $Script:GraphR1 = $null
        $Script:Output = @()
        $Recent = @()
        $ObjRem = @()
        $NoObj = @()
        
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
})


$WPFRemAADObj.IsEnabled = $False
$WPFRemAADObj.Add_Click({
    
})

$WPFRemAPObj.IsEnabled = $False
$WPFRemAPObj.Add_Click({
    ListBoxUpdate
    if ($Script:DevArray.count -gt 0) {
        ConnectMSGraph
        $Script:APObj = $null
        $Script:APObj = @()
        #Get AP Device Info
        $Script:DevArray | ForEach-Object {
            try {
                $SNT = $null
                if ($_ -like "UK*") {$SNT = $_.TrimStart("UK")} else {$SNT = $_}
                $URI = "/deviceManagement/windowsAutopilotDeviceIdentities?`$filter=contains(serialNumber,'$($SNT)')"
                Get-Graph $URI "GET"
                $Script:APObj += $Script:Output
                }
                catch
                {
                    $Script:APObj += "Error Object Not Found: $_"
                }
        }
                <#
                foreach ($device in $AutopilotDevices)
                {
                    Write-host "   Deleting SerialNumber: $($Device.value.serialNumber)  |  Model: $($Device.value.model)  |  Id: $($Device.value.id)  |  GroupTag: $($Device.value.groupTag)  |  ManagedDeviceId: $($device.value.managedDeviceId) …" –NoNewline
                    $URI = "https://graph.microsoft.com/beta/deviceManagement/windowsAutopilotDeviceIdentities/$($device.value.Id)"
                    $AutopilotDevice = Invoke-MSGraphRequest –Url $uri –HttpMethod DELETE –ErrorAction Stop
                    Write-Host "Success" –ForegroundColor Green
                }
                #>


    }
})

$WPFRemSCCMObj.IsEnabled = $False
$WPFRemSCCMObj.Add_Click({
    
})

$WPFRemAllObj.IsEnabled = $False
$WPFRemAllObj.Add_Click({
    
})

$WPFGrpTagCheck.IsEnabled = $False
$WPFGrpTagCheck.Add_Click({


    
})

$WPFGrpFixTag.IsEnabled = $False
$WPFGrpFixTag.Add_Click({

})

$WPFDevAddGrp.Add_Click({
    PopUpBoxD Visible
    $WPFPopOK1.Add_Click({
        $AA = $WPFPopGrp1.Text
        PopUpBoxD Hidden

       Write-host "$AA"
    })
    $WPFPopCan1.Add_Click({
        PopUpBoxD Hidden
    })
  
    #ConnectAAD
    #ListBoxUpdate
    #PopUpBox Device
    #$Script:PopUpBoxR
    <#
    [string]$groupName = $Script:PopUpBoxR
    $GroupObj = Get-AzureADGroup -SearchString $groupName
    $GroupObj
    $GroupObj.id
    <#
    if ($Script:DevArray.count -gt 0) {
        ConnectMSGraph
        #Varibales
        #$Script:
        #Get AP Device Info
        $Script:DevArray | ForEach-Object {


        }
    }
    #>
    
})



######################## User Actions ########################

<#
$WPFUsrName.Add_SelectionChanged({
    $LC = $WPFUsrName.LineCount
    $WPFUsrCount.Text = "Users: $LC"
})

$WPFUsrImpFile.Add_Click({
    #$null = $FileBrowser.ShowDialog()
    $SelFile = $null
    $RawImp = $null
    $RawHost = $null
    $UsrImpA = $null
    #$SelFile = $FileBrowser.FileName
    <#
    if ($SelFile -like "*.csv") {
        $RawImp = (Import-Csv -Path "$SelFile")."Display Name"
        $UsrImpA = @()
        $RawImp | Foreach-Object {
            $RawHost = [String]$_.Split([string[]] "- ",[System.StringSplitOptions]"None")[1]
            $RawHost = $RawHost.replace(' ','')
        $UsrImpA += $RawHost
        }
    } else {$UsrImpA = Get-Content -Path "$SelFile"}

    $UsrImpA = Get-Content -Path "$SelFile"

    Foreach ($Usr in $UsrImpA) {
        $WPFUsrName.AppendText("$nl$Dev")
    }
    
    

})
#>


#===========================================================================
# Shows the form
#===========================================================================
$Form.ShowDialog() | out-null