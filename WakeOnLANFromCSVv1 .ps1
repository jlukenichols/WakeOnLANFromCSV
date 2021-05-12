Clear-Host

<#
.SYNOPSIS
  Name: WakeOnLANFromCSV.ps1
  The purpose of this script is to ingest a CSV file containing MAC addresses and then send a WoL magic packet to each MAC address
  
.DESCRIPTION
  See synopsis

.NOTES
    Release Date: 2021-04-30T11:48
    Last Updated: 2021-05-12T10:58
   
    Author: Luke Nichols
    Github link: https://github.com/jlukenichols/WakeOnLANFromCSV

.EXAMPLE
    Just run the script without parameters, it's not designed to be called like a function
#>

#-------------------------- Begin defining functions --------------------------

cd $PSScriptRoot

#Dot-source functions needed for manipulating IP addresses and whatnot
. .\functions\GetNetworkIDAndSubnetInfo.ps1

# Dot-source function for sending WoL packets
. .\functions\Invoke-WakeOnLan.ps1

# Dot-source function for converting CIDR prefix length to subnet mask
# Not needed currently, being handled by a function in the GetNetworkIDAndSubnetInfo function library
#. .\functions\Convert-PrefixLengthToNetmask.ps1

# Dot-source functions for writing to log file
. .\functions\Write-Log.ps1

#-------------------------- End defining functions --------------------------

#-------------------------- Set any initial values --------------------------
$ScriptExecutionDate = Get-Date

#Grab the individual portions of the date and put them in vars
[DateTime]$currentDate=Get-Date
$currentYear = $($currentDate.Year)
$currentMonth = $($currentDate.Month).ToString("00")
$currentDay = $($currentDate.Day).ToString("00")

$currentHour = $($currentDate.Hour).ToString("00")
$currentMinute = $($currentDate.Minute).ToString("00")
$currentSecond = $($currentDate.Second).ToString("00")

#Dot-source settings file
if (Test-Path .\CustomSettings.ps1) {
    . .\CustomSettings.ps1
    $LogMessage = "Importing settings from CustomSettings.ps1"
} else {
    . .\DefaultSettings.ps1
    $LogMessage = "Importing settings from DefaultSettings.ps1"
}

#-------------------------- End setting initial values --------------------------

#-------------------------- Start main script body --------------------------

#Clean out old log files
Delete-OldFiles -NumberOfDays 30 -PathToLogs "$($myPSScriptRoot)\logs"

#Start the log file
Write-Log $LogMessage

#Show the path to the input file in the log
$LogMessage = "`$FullPathToCSV = $FullPathToCSV"
Write-Log $LogMessage

# Define the appropriate IP Interface to send the WoL packets from
$AssociatedIPInterface = Get-NetIPInterface | Where-Object {$_.InterfaceAlias -like "$InterfaceAliasPattern"}
# Determine the IP address of the interface to send the WoL packets from
$WoLInterface =  Get-NetIPAddress -AddressFamily IPv4 -AssociatedIPInterface $AssociatedIPInterface

ForEach ($Interface in $WoLInterface) {
    #Determine the CIDR prefix for the IP address and then convert to a subnet mask in decimal
    #$BroadcastAddress = (Get-IPv4Subnet -IPAddress ($Interface.IPAddress) -Subnetmask (Convert-PrefixLengthToNetmask $($WoLInterface.PrefixLength))).Broadcast
    $BroadcastAddress = (Get-IPv4Subnet -IPAddress ($Interface.IPAddress) -Subnetmask (CIDRToNetMask $($WoLInterface.PrefixLength))).Broadcast

    $LogMessage = "`$BroadcastAddress = $BroadcastAddress"
    Write-Log $LogMessage
}

#Import the CSV
$ArrayOfMACAddresses = Import-Csv -Path $FullPathToCSV

#Initialize a counter variable
$count = 0

#Send a WoL packet to each MAC address in the CSV file
Foreach ($line in $ArrayOfMACAddresses) {
    $count += 1
    $LogMessage = "Sending WoL packet to $($line.ComputerName) with IP $($line.IPAddress) and MAC $($line.MACAddress)"
    Write-Log $LogMessage
    Invoke-WakeOnLan -Verbose -MacAddress $line.MACAddress #-BroadcastAddress $BroadcastAddress
}

$LogMessage = "Total Wake-on-LANs attempted: $count"
Write-Log $LogMessage

#$ArrayOfMACAddresses | Select-Object -Property MACAddress | Invoke-WakeOnLan -Verbose #-BroadcastAddress $BroadcastAddress

#-------------------------- End main script body --------------------------