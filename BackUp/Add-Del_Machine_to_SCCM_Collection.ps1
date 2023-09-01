# // *****************************************************************************************************************
# //
# //                      Add-Del_Machine_to_SCCM_Collection
# // Version: 1.0
# // Creator: D Adams
# //
# // Date: 25/10/2018
# // Modified:
# //
# // Purpose:Add's or Del's Machine from SCCM collection
# //
# // 
# //
# // .PARAMETER ComputerName
# //    Hostname of the device to be added or deleted
# // .PARAMETER CollectionID
# //    SCCM Collection ID to which the computer will be added or deleted
# // .PARAMETER Method
# //    Method to be used. For addition of computer to SCCM collection use 'Add'.
# //    For deletion of computer from SCCM collection use 'Del'
# //.EXAMPLE
# //    Addition
# //    Add-Del_Machine_to_SCCM_Collection.ps1 -computerName 'UK028359180357' -collectionID 'S0100193' -method 'Add'
# //    Deletion
# //    Add-Del_Machine_to_SCCM_Collection.ps1 -computerName 'UK028359180357' -collectionID 'S0100193' -method 'Del' 
# //
# // *****************************************************************************************************************



# // *****************************************************************************************************************
# // SCRIPT PARAMETERS
# // *****************************************************************************************************************


Param(
    [Parameter(Mandatory=$True,Position=1,HelpMessage="Hostname of device to be added or deleted...")]
    [string]$computerName,
  
    [Parameter(Mandatory=$True,Position=2,HelpMessage="SCCM Collection ID to which the computer will be added or deleted...")]
    [string]$collectionID,
    
    [Parameter(Mandatory=$True,Position=3,HelpMessage="For Adding host use 'Add', for Deleting host use 'Del'...")]
    [string]$method
)

# Import the AD powershell Module
Import-Module ActiveDirectory


# Import the SCCM Powershell Modules
Import-Module "D:\Program Files\Microsoft Configuration Manager\AdminConsole\bin\ConfigurationManager.psd1"

# Get the members of the collection
$CMComputers = Get-CMDeviceCollectionDirectMembershipRule -CollectionId "S0100193" # -CollectionName ""

# Get the AD Group members
$ADComputers = Get-ADGroupMember -identity “UK Intune USB Storage Exemption” | select name



# Set the SCCM site Server path
set-location -Path S01:


if ($Method -eq 'Add')
    {
    Add-CMDeviceCollectionDirectMembershipRule -CollectionID $CollectionID -ResourceID $(get-cmdevice -name $ComputerName).ResourceID
    }
elseif ($Method -eq 'Del')
    {
    Remove-CMDeviceCollectionDirectMembershipRule -CollectionID $CollectionID -ResourceID $(get-cmdevice -name $ComputerName).ResourceID -Force
    }

Set-Location -Path D:




