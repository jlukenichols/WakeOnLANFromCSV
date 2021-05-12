Clear-Host

<#
.SYNOPSIS
  Name: WakeOnLANFromCSV.ps1
  The purpose of this script is to ingest a CSV file containing MAC addresses and then send a WoL magic packet to each MAC address
  
.DESCRIPTION
  See synopsis

.NOTES
    Release Date: 2021-04-30T11:48
    Last Updated: 2021-05-12T12:27
   
    Author: Luke Nichols
    Github link: https://github.com/jlukenichols/WakeOnLANFromCSV

.EXAMPLE
    Just run the script without parameters, it's not designed to be called like a function
#>

#-------------------------- Begin defining functions --------------------------

cd $PSScriptRoot

#Dot-source functions needed for manipulating IP addresses and whatnot
. .\functions\GetNetworkIDAndSubnetInfo.ps1

#Dot-source functions needed for comparing IP addresses
. .\functions\Compare-Subnets.ps1

# Dot-source function for sending WoL packets
. .\functions\Invoke-WakeOnLan.ps1

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

#Import the CSV
$ArrayOfMACAddresses = Import-Csv -Path $FullPathToCSV

#Initialize counter variables
$PacketsSent = 0
$UnwakeableCount = 0

#Loop through the CSV file
:loopThroughCSVFile Foreach ($line in $ArrayOfMACAddresses) {    
    #Loop through the system's network interfaces
    :loopThroughSystemIPAddresses Foreach ($NetIPAddress in (Get-NetIPAddress | Where-Object {($_.AddressFamily -eq "IPv4") -and ($_.InterfaceAlias -notlike "*Loopback*")})) {
        $SubnetMask = CIDRToNetMask $NetIPAddress.PrefixLength
        $LogMessage = "Is $($line.'Computer IP Address') in the same subnet as $($NetIPAddress.IPAddress)? Subnet: $SubnetMask"
        Write-Log $LogMessage
        #Determine if the IP address of the current line in the CSV file is in the same subnet as the IP address of the current network interface
        if (Compare-Subnets $($line."Computer IP Address") $NetIPAddress.IPAddress $SubnetMask) {
            #The IPs are in the same subnet, 
            $LogMessage = "Yes"
            Write-Log $LogMessage

            $WolInterface = $NetIPAddress
            $BroadcastAddress = (Get-IPv4Subnet -IPAddress ($WolInterface.IPAddress) -Subnetmask (CIDRToNetMask $($WoLInterface.PrefixLength))).Broadcast

            $LogMessage = "`$BroadcastAddress = $BroadcastAddress"
            Write-Log $LogMessage

            $LogMessage = "Sending WoL packet to $($line.'Computer Name') with IP $($line.'Computer IP Address') and MAC $($line.'Computer MAC Address')"
            Write-Log $LogMessage
            Invoke-WakeOnLan -Verbose -MacAddress $($line."Computer MAC Address") -BroadcastAddress $BroadcastAddress
            
            #Increment the counter
            $PacketsSent += 1

            #Jump to the next line in the CSV file since we already found a matching NIC
            continue loopThroughCSVFile
        } else {
            $LogMessage = "No"
            Write-Log $LogMessage
        }
    }
    #If the script reaches this point then there is no network interface capable of waking this computer.
    $LogMessage = "ERROR: There is no network interface on this system residing on the same subnet as IP $($line.'Computer IP Address'). Cannot Wake computer $($line.'Computer Name')."
    Write-Log $LogMessage

    $UnwakeableCount += 1
}

$LogMessage = "Total Wake-on-LAN packets sent: $PacketsSent"
Write-Log $LogMessage

$LogMessage = "Unwakeable computers: $UnwakeableCount"
Write-Log $LogMessage

#-------------------------- End main script body --------------------------