#Global Variables
$Name = "Remove_Intune_Owned_Devices"
$CacheFldr = "C:\ProgramData\Sky\Cache\$Name"

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

function Get-OwnDev {
    param ($UsrID, $DFilter)
    CallMgGraph -Meth 'Get' -Ver 'v1.0' -Res "users/$UsrID/ownedDevices"
    $OwnDev = $GrRaw
    if ($DFilter) {$OwnDev = $OwnDev | Where-Object operatingSystem -eq 'Windows'}
    [System.Collections.ArrayList]$Script:AL = $OwnDev |
        ForEach-Object {        
            $_ | Select-Object `
                @{n="Hostname";e={$_.displayName}},`
                @{n="Make";e={$_.manufacturer}},`
                @{n="Model";e={$_.model}},`
                @{n="LastSync";e={$_.approximateLastSignInDateTime}},`
                @{n="ID";e={$_.id}}`
    }
}

function Remove-OwnDev {
    param ($DevSel, $UsrID)
    $DevSel | ForEach-Object {
        CallMgGraph -Meth 'Delete' -Ver 'v1.0' -Res "users/$UsrID/ownedDevices/$($_.id)/$ref" #$ref is required https://learn.microsoft.com/en-us/graph/api/device-delete-registeredowners?view=graph-rest-1.0&tabs=http#http-request
    }
    #Get-OwnDev
    #Search_Layout -DataSource $AL -Vis "Visible"
}


#WPF Window
$CacheDir = "C:\ProgramData\Sky\Cache\ILA"
if (!(Test-Path $CacheFldr)){Invoke-Expression -Command:"md $CacheFldr"}
Invoke-RestMethod -Uri "https://raw.githubusercontent.com/jcl45/CT_Dev/main/Master_GUI_v1.0/Master_GUI_v1.0/MainWindow.xaml" -OutFile "$CacheFldr\MainWindow.xaml"#>
$inputXML = Get-Content "$CacheFldr\MainWindow.xaml" #XAML Raw
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

######################################
# Set Element Parameters
######################################

## Main Window
$MinHeight = 650 
$MinWidth = 750
#$Form.MinHeight = $MinHeight
$Form.MinWidth = $MinWidth
$Form.Title = "Manage Owned Devices"



## Child Elements
function Default_Layout {
    $WPFRect1.Width = $MinWidth
    $WPFRect1.Height = 60
    $WPFRect1.Visibility = "Visible"
    $WPFTextB1.Foreground = "#FFFFFFFF"
    $WPFTextB1.FontSize = 24
    $WPFTextB1.Text = "Enter UPN of User"
    $WPFTextB1.Visibility = "Visible"
    $WPFInpTxt1.HorizontalAlignment = "Left"
    $WPFInpTxt1.Width = 355
    $WPFInpTxt1.Height = 40
    $InpTxt1_Pos = 105
    $WPFInpTxt1.Margin = "$InpTxt1_Pos,78,0,20"
    $WPFInpTxt1.Padding = "0,9,0,0"
    $WPFInpTxt1.Background = "#FFFFFFFF"
    $WPFInpTxt1.Visibility = "Visible"
    $WPFButton1.Content.Text = "Search"
    $WPFButton1.Content.FontSize = 20
    $WPFButton1.Width = 130
    $WPFButton1.Height = 40
    $WPFButton1.HorizontalAlignment = "Left"
    $WPFButton1.Margin = "$($InpTxt1_Pos +380),78,0,0"
    $WPFButton1.Visibility = "Visible"
}

function Search_Layout {
    Param ($DataSource, $Vis)
    $WPFDataGrid1.ItemsSource = $null
    $WPFDataGrid1.ItemsSource = $DataSource
    $WPFDataGrid1.VerticalAlignment = "Bottom" 
    $WPFDataGrid1.Width = $($MinWidth -90)
    $WPFDataGrid1.Height = $($MinHeight -156)
    $WPFDataGrid1.Margin = "0,0,0,75"
    $WPFDataGrid1.RowHeaderWidth = 0
    $Button_VPos2 = $($MinHeight)
    $Button_HPos2 = $($MinWidth  -245)
    $WPFButton2.Content.Text = "Remove"
    $WPFButton2.Margin = "$Button_HPos2,$Button_VPos2,0,20"
    $WPFButton3.Content.Text = "Clear"
    $WPFButton3.Margin = "$($Button_HPos2 +105),$Button_VPos2,0,0"
    if ($Vis -eq "Visible") {
        $WPFDataGrid1.Visibility = "Visible"
        $WPFButton2.Visibility = "Visible"
        $WPFButton3.Visibility = "Visible"
    } else {
        $WPFDataGrid1.Visibility = "Collapse"
        $WPFButton2.Visibility = "Collapse"
        $WPFButton3.Visibility = "Collapse"
    }
}



######################################
# Element Actions
######################################

Default_Layout

$WPFButton1.Add_Click({
    Default_Layout
    Search_Layout -Vis "Collapse"
    $WPFDataGrid1.ItemsSource = $null
    if ($WPFInpTxt1.Text -match "@") {
        $UsrUPN = $WPFInpTxt1.Text
        CallMgGraph -Meth 'Get' -Ver 'v1.0' -Res 'users' -Extra "?`$filter=userPrincipalName eq '$($WPFInpTxt1.Text)'"
        $UsrID = $GrRaw.id
        if ($null -ne $UsrID) {
            $WPFTextB1.Text = "Users Owned Devices"
            Get-OwnDev -UsrID $UsrID -DFilter $true
            Search_Layout -DataSource $AL -Vis "Visible"
        } else {
            $WPFTextB1.Text = "UPN Not Found, Enter a Valid UPN"
            $WPFTextB1.Foreground = "#9E2A2B"
            $WPFInpTxt1.Background = "#E09F3E"
        }
    }
})

###################### NEEDS WORK ######################
#Remove Button Action
$WPFButton2.Add_Click({
    Remove-OwnDev -DevSel $WPFDataGrid1.SelectedItems -UsrID $UsrID
    <# | ForEach-Object {
        write-host $($_.ID)
    }#>
})

#######################################################

#Clear Button Action
$WPFButton3.Add_Click({
    Search_Layout -Vis "Collapse"
    $WPFDataGrid1.ItemsSource = $null
    $WPFInpTxt1.Text = $null
})


#Show GUI Window
$Form.ShowDialog() | out-null