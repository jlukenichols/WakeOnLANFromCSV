# If you want to specify custom settings for your script just copy this file and rename to "CustomSettings.ps1" in the same directory.
# Modify the variables in CustomSettings.ps1 as needed.

#Set variables for write-log function
$LoggingMode = $true #Set to $false to disable all logging
$VerboseLogging = $true #Set to $true if you want all log output to also be displayed in the console

#Define the root path of the running script
$myPSScriptRoot = $PSScriptRoot

#Define the path to the log file
[string]$LogFilePath = "$($myPSScriptRoot)\logs\WakeOnLANFromCSV_$($currentYear)-$($currentMonth)-$($currentDay)T$($currentHour)$($currentMinute)$($currentSecond)_$($env:computername).txt"

#Define pattern to match interface name on. Must include wildcards in string.
$InterfaceAliasPattern = "*Ethernet*"

#Define the path to the CSV file containing the MAC addresses. Assumes the first line is the header line and that there is a "MACAddress" field.
$FullPathToCSV = "C:\Scripts\WakeOnLANFromCSV\MACAddresses.csv"