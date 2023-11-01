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

#$UsrUPN = "james.cockerill@sky.uk"



#$DevSel = $AL | Out-GridView -Title "Select Devices to Remove" –PassThru
if ($null -ne $DevSel) {
    $DevSel | ForEach-Object {
        CallMgGraph -Meth 'Delete' -Ver 'v1.0' -Res "users/$UsrID/ownedDevices/$($_.id)/$ref" #$ref is required https://learn.microsoft.com/en-us/graph/api/device-delete-registeredowners?view=graph-rest-1.0&tabs=http#http-request
    }
}#>

#WPF Window
$CacheDir = "C:\ProgramData\Sky\Cache\ILA"
<#if (!(Test-Path $CacheFldr)){Invoke-Expression -Command:"md $CacheFldr"}
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
$Form.MinHeight = $MinHeight
$Form.MinWidth = $MinWidth
$Form.Title = "Manage Owned Devices"



## Child Elements
$WPFRect1.Width = $MinWidth
$WPFRect1.Height = 60
$WPFRect1.Visibility = "Visible"
$WPFTextB1.FontSize = 24
$WPFTextB1.Text = "Enter UPN of User"
$WPFTextB1.Visibility = "Visible"
$WPFInpTxt1.HorizontalAlignment = "Left"
$WPFInpTxt1.Width = 355
$WPFInpTxt1.Height = 40
$InpTxt1_Pos = 105
$WPFInpTxt1.Margin = "$InpTxt1_Pos,78,0,0"
$WPFInpTxt1.Visibility = "Visible"
$WPFButton1.Content.Text = "OK"
$WPFButton1.Content.FontSize = 20
$WPFButton1.Width = 130
$WPFButton1.Height = 40
$WPFButton1.HorizontalAlignment = "Left"
$WPFButton1.Margin = "$($InpTxt1_Pos +380),78,0,0"
$WPFButton1.Visibility = "Visible"

######################################
# Element Actions
######################################

$WPFButton1.Add_Click({
    if ($WPFInpTxt1.Text -match "@") {
        $UsrUPN = $WPFInpTxt1.Text
        CallMgGraph -Meth 'Get' -Ver 'v1.0' -Res 'users' -Extra "?`$filter=userPrincipalName eq '$UsrUPN'"
        $UsrID = $GrRaw.id
        Write-Host "$($UsrID)"
        CallMgGraph -Meth 'Get' -Ver 'v1.0' -Res "users/$UsrID/ownedDevices"
        $OwnDev = $GrRaw #| Where-Object operatingSystem -eq 'Windows'
        [System.Collections.ArrayList]$Script:AL = $OwnDev |
            ForEach-Object {        
                $_ | Select-Object `
                    @{n="Hostname";e={$_.displayName}},`
                    @{n="Make";e={$_.manufacturer}},`
                    @{n="Model";e={$_.model}},`
                    @{n="LastSync";e={$_.approximateLastSignInDateTime}},`
                    @{n="ID";e={$_.id}}`
        }


        #$WPFButton1.Visibility = "Hidden"
        $WPFDataGrid1.VerticalAlignment = "Bottom" 
        $WPFDataGrid1.Width = $($MinWidth -90)
        $WPFDataGrid1.Height = $($MinHeight -226)
        $WPFDataGrid1.Margin = "0,0,0,16"
        $WPFDataGrid1.ItemsSource = $null
        $WPFDataGrid1.ItemsSource = $AL
        $WPFDataGrid1.RowHeaderWidth = 0
        $WPFDataGrid1.Visibility = "Visible"

    }





})



#Show GUI Window
$Form.ShowDialog() | out-null