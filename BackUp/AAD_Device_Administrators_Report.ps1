[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$today = get-date -Format "dd-MM-yy_HHmm"
$logname = "Azure Device Administrators - $today.txt"
$logpath = "C:\Scripts\Production\ITSD365Permissions\Output"
$logfile = "C:\Scripts\Production\ITSD365Permissions\Output\$logname"
$date = get-date -Format "dd-MM-yy"

function Get-CredentialVault {
<#
.SYNOPSIS
Retrieve passwords from SkyVault [CyberArk] safe
.DESCRIPTION
Retrieve passwords from SkyVault [CyberArk] safe
Requires Application to be registered in AIM and granted appropriate permission to access Safe.
.PARAMETER AppId
.PARAMETER Safe
.PARAMETER Reason
.PARAMETER ObjectName
.INPUTS
.OUTPUTS
.EXAMPLE
"sqlSVC-APP-Q1IMPRD","svc-aad-connect" | Get-CredentialVault -AppId 'myID-Scripts' -Safe 'myID_IDM-Prod' -Reason 'test'
.LINK
.NOTES
#>
    [CmdletBinding(DefaultParameterSetName = 'Name')]
    Param (
          [Parameter (ParameterSetName="Name",Position=0,Mandatory=$True)]
          [String]$AppId,
          [Parameter (ParameterSetName="Name",Mandatory=$True, ValueFromPipeLine=$True)]
          [String[]]$ObjectName,
          [Parameter (ParameterSetName="Name",Mandatory=$True)]
          [String]$Safe,
          [Parameter (ParameterSetName="Name",Mandatory=$True)]
          [String]$Reason
         )
    begin {
        # establish connection
        Set-Variable -Name SkyVaultProxy -Scope Global -Force
        Set-Variable -Name VaultUri -Scope Global -Force
        if (-not $Global:VaultUri) {
            # until fix is in to use VIP
            $Global:VaultUri = "https://wpamw01a.bskyb.com/AIMWebService/V1.1/AIM.asmx?wsdl" 
        }
        if (-not $Global:SkyVaultProxy) {
            $Global:SkyVaultProxy = New-WebServiceProxy -Uri $Global:VaultUri -Namespace 'SkyVault' -UseDefaultCredential
        }
        $outputObject = @()
    }
    process {
        foreach ($o in $ObjectName) {
            # build query
            $query = New-Object System.Text.StringBuilder
            [void]$query.Append("Safe=$Safe;")
            [void]$query.Append("Folder=Root;")
            [void]$query.Append("Object=$o")
            # build request
            $request = New-Object SkyVault.PasswordRequest
            $request.AppID = $AppId
            $request.Query = $query.ToString()
            $request.Reason = $Reason

            $count = 0
            While ($True) {
                try { 
                    $response = $Global:SkyVaultProxy.GetPassword($request) 
                } catch {
                    Throw
                }
                if ($response.Properties.Where({$_.key -eq 'PasswordChangeInProcess'}).value -eq $True) {
                    if ($count -eq 14) {
                        Throw "Unable to retrieve 'changing' password after 15 attempts"
                    } else {
                        Start-Sleep -s 30
                    }
                } else {
                    break;
                }
                $count++
            }
            #Write-Debug "$($response.UserName) $($response.Content)"
            $outputObject += New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $response.UserName, ($response.Content | ConvertTo-SecureString -AsPlainText -Force)
            $response = $null
        }
    }
    end {
        Write-Output $outputObject
    }
}

Function SendEmail{
$to = "DL-EnterpriseTechClientTechnologies@sky.uk"
$From = "DL-WPT-Messaging-Reports@bskyb.internal"
$subject = "Azure Device Administrator Changes Report: " + $date
$mailserver = "bridgeheads.bskyb.com"
$body =@"
<html>
<head>
<style type="text/css">
p {font-family:calibri;}
td {font-family:calibri;}
</style>
</head>
<body>
<p>The following changes have been made to the Device Administrators role:
<br>
<br>$listtoadd
<br>
<br>$listtoremove
<br>
<br>Please contact <a href="mailto: DL-EnterpriseTechClientTechnologies@sky.uk?subject=Azure Device Administrator Changes Report">DL-EnterpriseTechClientTechnologies</a> if you have any issues.
<br>Regards,
<br>
<br>Enterprise Tech Client Technologies
</p>
</body>
</html>
"@

Send-MailMessage -To $to -From $from -subject $subject -smtpserver $mailserver -bodyashtml $body
}

$now = get-date
"Started $now" | out-file $logfile -append
Import-Module ActiveDirectory
"Imported AD Module" | out-file $logfile -append
Import-Module MSOnline
"Imported MS Online Module" | out-file $logfile -append
#$passpath = "C:\Scripts\svc-app-exchscripts\creds\Global-ExScripts.exscripts.cred"
$passpath = "C:\Scripts\Production\ITSD365Permissions\BG.pass"
#$MSOLADmin = "SVC-APP-ExchScripts@bskyb.com"
$MSOLAdmin = "breakglass@skyglobal.onmicrosoft.com"

$credential = Get-CredentialVault -AppId "Messaging-Scripts" -Safe "O365-Global-Admin-Prod" -ObjectName "Operating System-SkyWindowsDomainAccount-skyglobal.onmicrosoft.com-breakglass@skyglobal.onmicrosoft.com" -Reason "Scheduled task - ITSD Permissions Check and Resolve"

#If(Test-Path -Path $passpath){
#               $MSOLPassword = gc $passpath|ConvertTo-SecureString
#		$credential = new-object -typename System.Management.Automation.PSCredential -argumentlist $MSOLAdmin,$MSOLPassword
#}
#Else{
#"FAILED: Password file missing" | out-file $logfile -append
#$Error | out-file $logfile -append
#Exit
#}

#Connect to 365 MSOL
try{
Connect-MsolService -credential $credential
"Connected to MS Online Service" | out-file $logfile -append
}
catch{
"FAILED: Unable to connect to MS Online Service" | out-file $logfile -append
Exit
}

#Connect to 365 Exchange
try{
$Session = New-PSSession -ConfigurationName Microsoft.Exchange -ConnectionUri https://ps.outlook.com/powershell/ -Credential $credential -Authentication Basic -AllowRedirection
Import-PSSession $Session
"Powershell session created" | out-file $logfile -append
}
catch{
"FAILED: Unable to create Powershell session`n$Error" | out-file $logfile -append
Exit
}
$UsersToNeverTouch = ("svc-q1-js@skyglobal.onmicrosoft.com","svc-app-svcnow@bskyb.com","svc-app-svcnow-dat@bskyb.com","tosiGLBadmin@skytv.it","LoriaGLBadmin@skytv.it","longariniGLBadmin@skytv.it","collutoGLBadmin@skytv.it","caloGLBadmin@skytv.it","borgiaGLBadmin@skytv.it","admasch04@pfad.biz","x1008@pfad.biz","svc-tier0-skyclops@sky.de","vyadmin@skyglobal.onmicrosoft.com","NoferiGLBadmin@skytv.it","bsadmin@skyglobal.onmicrosoft.com","Borislav.Stojcic@sky.de","x0015@pfad.biz","jmh10-2@bskyb.com","ard04-2@bskyb.com")
$UserAccountAdmins = Get-MsolRoleMember -RoleObjectId "fe930be7-5e62-47db-91af-98c3a49a38b1" | %{Get-MSOLUser -ObjectId $_.ObjectID}
#Filter out cloud accounts
$UserAccountAdmins = $UserAccountAdmins | ?{$_.UserPrincipalName -notlike "*@skyglobal.onmicrosoft.com"}
"Got users with User Management Admin role" | out-file $logfile -append
$ITSDUsers = @()
$GroupMembers = Get-ADGroupMember "365 AD User Management" -Recursive
$GroupMembers = $groupmembers | ?{$_.Name -notlike "svc-*"}
"Got members of AD group" | out-file $logfile -append
foreach($groupmember in $groupmembers){
$itsdusers += Get-ADUser $groupmember | Get-Msoluser
}
#Get-MsolGroup -SearchString "DL-WPT Service Desk" | %{Get-MsolGroupMember -GroupObjectId $_.ObjectID} | Get-MsolUser

$ChangesToMake = Compare-Object $UserAccountAdmins $ITSDUsers -Property UserPrincipalName
"Compared current users and AD group members" | out-file $logfile -append
foreach($User in $UsersToNeverTouch)
{
	$ChangesToMake = $ChangesToMake | ?{$_.UserPrincipalName -ne $User}
}

[array]$UsersToAdd = $ChangesToMake | ?{$_.SideIndicator -like "=>"}
[array]$UsersToRemove = $ChangesToMake | ?{$_.SideIndicator -like "<="}

If($UsersToAdd.count -gt 0)
{
	"Users to be added" | out-file $logfile -append
	[array]$listtoadd = "<b>Users added: </b>"
	ForEach($User in $UsersToAdd)
	{
		$UserID = Get-MSOLUser -UserPrincipalName $User.UserPrincipalName;Add-MsolRoleMember -RoleName "User Account Administrator" -RoleMemberObjectID $UserID.ObjectID
		$listtoadd += "<br>`r`n" + $user.userprincipalname
		"$user.UserPrincipalName" | out-file $logfile -append
	}
}
else{
		"No users to be added" | out-file $logfile -append
		$listtoadd = "<b>No new users have been added</b>"
		}

If($UsersToRemove.count -gt 0)
{
	"Users to be removed" | out-file $logfile -append
	[array]$listtoremove = "<b>Users removed: </b>"
	ForEach($User in $UsersToRemove)
	{
		$UserID = Get-MSOLUser -UserPrincipalName $User.UserPrincipalName;Remove-MsolRoleMember -RoleName "User Account Administrator" -RoleMemberObjectID $UserID.ObjectID
		$listtoremove += "<br>`r`n" + $user.userprincipalname
		"$user.userprincipalname" | out-file $logfile -append
	}
}
else{
		"No users to be removed" | out-file $logfile -append
		$listtoremove = "<b>No users have been removed</b>"
		}

If(($UsersToAdd.count -gt 0) -or ($UsersToRemove.count -gt 0)){
SendEmail
"Sent Email" | out-file $logfile -append
}
Get-PSSession | Remove-PSSession
"Ended script" | out-file $logfile -append