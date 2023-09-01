# Import the AD powershell module
Import-Module ActiveDirectory


# Database variables
[string] $serverInstance = "WPSQL3F\CMDMS1P"
[string] $databaseName = "BS_ITO_CMDATAMART_PRD_001"
[string] $userName = "sqlSVC-APP-CMDMViewOnly"
[string] $userPassword = "I2rMMVUK"

# AD OU to place the Microsoft devices
$MicrosoftOU=‘OU=Azure Devices,OU=NGD-Workstations,DC=bskyb,DC=com’

# AD OU to place the Apple devices
$AppleOU=‘OU=DEP,OU=MACs,DC=bskyb,DC=com’
 

# Build the SQL query to get devices added within the last 1 day
$sqlQuery = "SELECT serial_number, dv_manufacturer FROM dbo.[~cmdb_ci_computer] WHERE sys_created_by = 'wptassetimport' AND sys_created_on > getdate() - 1"

   
# Connect to CMDB Database and execute query    
$connection = New-Object System.Data.SQLClient.SQLConnection
#$connection.ConnectionString = "server='$serverInstance';database='$databaseName';trusted_connection=true;"
$connection.ConnectionString = "server='$serverInstance';database='$databaseName';User Id='$userName';Password='$userPassword';"
$connection.Open()
$command = New-Object System.Data.SQLClient.SQLCommand
$command.Connection = $connection
$command.CommandText = $sqlQuery
$reader = $command.ExecuteReader()


# Loop through the records
while ($reader.Read()) {
 
    
    #Check to see if device is Microsoft or Apple
    if ($reader.GetValue(1) -eq "Microsoft")
        {
        $Hostname = "UK" + $reader.GetValue(0)
        # Check hostname doesnt already exist in AD
        if ((Get-ADComputer $Hostname) -eq $null)
            {
            #Add Microsft Computer to the Domain
            Write-Host "Adding Microsoft Computer $Hostname to the Domain OU $MicrosoftOU"
            #New-ADComputer -Name "UK$Row" -Path $OU -Enabled $true -Description "Intune Enrolled Surface Devices"
            }
        
        }

    elseif ($reader.GetValue(1) -eq "Apple")
        {
        $Hostname = "UK" + $reader.GetValue(1)
        # Check hostname doesnt already exist in AD
        if ((Get-ADComputer $Hostname) -eq $null)
            {
            #Add Apple Computer to the Domain
            Write-Host "Adding Apple Computer $Hostname to the Domain OU $AppleOU"
            #New-ADComputer -Name "UK$Row" -Path $OU -Enabled $true -Description "Intune Enrolled Surface Devices"
            }
        }




   
}
$connection.Close()

