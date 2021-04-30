Clear-Host

<#
.SYNOPSIS
  Name: WakeOnLANFromCSV.ps1
  The purpose of this script is to ingest a CSV file containing MAC addresses and then send a WoL magic packet to each MAC address
  
.DESCRIPTION
  See synopsis

.NOTES
    Release Date: 2021-04-30T11:48
    Last Updated: 2021-04-30T12:13
   
    Author: Luke Nichols
    Github link: https://github.com/jlukenichols/WakeOnLANFromCSV

.EXAMPLE
    Just run the script without parameters, it's not designed to be called like a function
#>

#-------------------------- Begin defining functions --------------------------

Function Convert-IPv4AddressToBinaryString {
#Function taken from https://codeandkeep.com/PowerShell-Get-Subnet-NetworkID/
    Param(
        [IPAddress]$IPAddress='0.0.0.0'
    )
    $addressBytes=$IPAddress.GetAddressBytes()

    $strBuilder=New-Object -TypeName Text.StringBuilder

    foreach($byte in $addressBytes) {
        $8bitString=[Convert]::ToString($byte,2).PadRight(8,'0')
        [void]$strBuilder.Append($8bitString)
    }
    Write-Output $strBuilder.ToString()
}

Function ConvertIPv4ToInt {
#Function taken from https://codeandkeep.com/PowerShell-Get-Subnet-NetworkID/
    [CmdletBinding()]
    Param(
        [String]$IPv4Address
    )
    Try {
        $ipAddress=[IPAddress]::Parse($IPv4Address)

        $bytes=$ipAddress.GetAddressBytes()
        [Array]::Reverse($bytes)

        [System.BitConverter]::ToUInt32($bytes,0)
    } Catch {
        Write-Error -Exception $_.Exception `
            -Category $_.CategoryInfo.Category
    }
}

Function ConvertIntToIPv4 {
#Function taken from https://codeandkeep.com/PowerShell-Get-Subnet-NetworkID/
    [CmdletBinding()]
    Param(
        [uint32]$Integer
    )
    Try {
        $bytes=[System.BitConverter]::GetBytes($Integer)
        [Array]::Reverse($bytes)
        ([IPAddress]($bytes)).ToString()
    } Catch {
        Write-Error -Exception $_.Exception `
            -Category $_.CategoryInfo.Category
    }
}

Function Add-IntToIPv4Address {
#Function taken from https://codeandkeep.com/PowerShell-Get-Subnet-NetworkID/
    Param(
        [String]$IPv4Address,

        [int64]$Integer
    )
    Try {
        $ipInt=ConvertIPv4ToInt -IPv4Address $IPv4Address `
            -ErrorAction Stop
        $ipInt+=$Integer

        ConvertIntToIPv4 -Integer $ipInt
    } Catch {
        Write-Error -Exception $_.Exception `
            -Category $_.CategoryInfo.Category
    }
}

Function CIDRToNetMask {
#Function taken from https://codeandkeep.com/PowerShell-Get-Subnet-NetworkID/
    [CmdletBinding()]
    Param(
        [ValidateRange(0,32)]
        [int16]$PrefixLength=0
    )
    $bitString=('1' * $PrefixLength).PadRight(32,'0')

    $strBuilder=New-Object -TypeName Text.StringBuilder

    for($i=0;$i -lt 32;$i+=8) {
        $8bitString=$bitString.Substring($i,8)
        [void]$strBuilder.Append("$([Convert]::ToInt32($8bitString,2)).")
    }

    $strBuilder.ToString().TrimEnd('.')
}

Function NetMaskToCIDR {
#Function taken from https://codeandkeep.com/PowerShell-Get-Subnet-NetworkID/
    [CmdletBinding()]
    Param(
        [String]$SubnetMask='255.255.255.0'
    )
    $byteRegex='^(0|128|192|224|240|248|252|254|255)$'
    $invalidMaskMsg="Invalid SubnetMask specified [$SubnetMask]"
    Try {
        $netMaskIP=[IPAddress]$SubnetMask
        $addressBytes=$netMaskIP.GetAddressBytes()

        $strBuilder=New-Object -TypeName Text.StringBuilder

        $lastByte=255

        foreach($byte in $addressBytes) {

            # Validate byte matches net mask value
            if($byte -notmatch $byteRegex) {
                Write-Error -Message $invalidMaskMsg `
                    -Category InvalidArgument `
                    -ErrorAction Stop
            } elseif($lastByte -ne 255 -and $byte -gt 0) {
                Write-Error -Message $invalidMaskMsg `
                    -Category InvalidArgument `
                    -ErrorAction Stop
            }

            [void]$strBuilder.Append([Convert]::ToString($byte,2))
            $lastByte=$byte
        }

        ($strBuilder.ToString().TrimEnd('0')).Length
    } Catch {
        Write-Error -Exception $_.Exception `
            -Category $_.CategoryInfo.Category
    }
}

Function Get-IPv4Subnet {
#Function taken from https://codeandkeep.com/PowerShell-Get-Subnet-NetworkID/
    [CmdletBinding(DefaultParameterSetName='PrefixLength')]
    Param(
        [Parameter(Mandatory=$true,Position=0)]
        [IPAddress]$IPAddress,

        [Parameter(Position=1,ParameterSetName='PrefixLength')]
        [Int16]$PrefixLength=24,

        [Parameter(Position=1,ParameterSetName='SubnetMask')]
        [IPAddress]$SubnetMask
    )
    Begin {}
    Process {
    Try {
        if($PSCmdlet.ParameterSetName -eq 'SubnetMask'){
            $PrefixLength=NetMaskToCidr -SubnetMask $SubnetMask `
                -ErrorAction Stop
            } else {
                $SubnetMask=CIDRToNetMask -PrefixLength $PrefixLength `
                    -ErrorAction Stop
            }
      
            $netMaskInt=ConvertIPv4ToInt -IPv4Address $SubnetMask     
            $ipInt=ConvertIPv4ToInt -IPv4Address $IPAddress
      
            $networkID=ConvertIntToIPv4 -Integer ($netMaskInt -band $ipInt)

            $maxHosts=[math]::Pow(2,(32-$PrefixLength)) - 2
            $broadcast=Add-IntToIPv4Address -IPv4Address $networkID `
            -Integer ($maxHosts+1)

            $firstIP=Add-IntToIPv4Address -IPv4Address $networkID -Integer 1
            $lastIP=Add-IntToIPv4Address -IPv4Address $broadcast -Integer -1

            if($PrefixLength -eq 32) {
                $broadcast=$networkID
                $firstIP=$null
                $lastIP=$null
                $maxHosts=0
            }

            $outputObject=New-Object -TypeName PSObject 

            $memberParam=@{
                InputObject=$outputObject;
                MemberType='NoteProperty';
                Force=$true;
            }
            Add-Member @memberParam -Name CidrID -Value "$networkID/$PrefixLength"
            Add-Member @memberParam -Name NetworkID -Value $networkID
            Add-Member @memberParam -Name SubnetMask -Value $SubnetMask
            Add-Member @memberParam -Name PrefixLength -Value $PrefixLength
            Add-Member @memberParam -Name HostCount -Value $maxHosts
            Add-Member @memberParam -Name FirstHostIP -Value $firstIP
            Add-Member @memberParam -Name LastHostIP -Value $lastIP
            Add-Member @memberParam -Name Broadcast -Value $broadcast

            Write-Output $outputObject
        } Catch {
            Write-Error -Exception $_.Exception `
                -Category $_.CategoryInfo.Category
        }
    }
    End{}
}

function Invoke-WakeOnLan {
#Function taken from https://powershell.one/code/11.html
    param (
        # one or more MACAddresses
        [Parameter(Mandatory,ValueFromPipeline,ValueFromPipelineByPropertyName)]
        # mac address must be a following this regex pattern:
        [ValidatePattern('^([0-9A-F]{2}[:-]){5}([0-9A-F]{2})$')]
        [string[]]
        $MacAddress,
        [Parameter]
        [ipaddress]$BroadcastAddress = 255.255.255.255
    )
 
    begin {
        # instantiate a UDP client:
        $UDPclient = [System.Net.Sockets.UdpClient]::new()
    }
    process {
        foreach($_ in $MacAddress) {
            try {
                $currentMacAddress = $_
        
                # get byte array from mac address:
                $mac = $currentMacAddress -split '[:-]' |
                    # convert the hex number into byte:

                    ForEach-Object {
                        [System.Convert]::ToByte($_, 16)
                    }
 
                #region compose the "magic packet"
        
                # create a byte array with 102 bytes initialized to 255 each:
                $packet = [byte[]](,0xFF * 102)
        
                # leave the first 6 bytes untouched, and
                # repeat the target mac address bytes in bytes 7 through 102:
                6..101 | Foreach-Object { 
                    # $_ is indexing in the byte array,
                    # $_ % 6 produces repeating indices between 0 and 5
                    # (modulo operator)
                    $packet[$_] = $mac[($_ % 6)]
                }
        
                #endregion
        
                # connect to port 400 on broadcast address:
                #$UDPclient.Connect(([System.Net.IPAddress]::Broadcast),4000)
                #$UDPclient.Connect($BroadcastAddress,4000)
                #TODO: Figure out how to get this to take the $BroadcastAddress parameter without breaking
                #$UDPclient.Connect("172.20.7.255",4000)
                $UDPclient.Connect("$BroadcastAddress",4000)
        
                # send the magic packet to the broadcast address:
                $null = $UDPclient.Send($packet, $packet.Length)
            Write-Verbose "sent magic packet to $currentMacAddress..."
            }
            catch {
                Write-Warning "Unable to send ${mac}: $_"
            }
        }
    }
    end {
        # release the UDF client and free its memory:
        $UDPclient.Close()
        $UDPclient.Dispose()
    }
}

<#Function Convert-PrefixLengthToNetmask ($PrefixLength) {
# Function created by Luke Nichols, not needed currently
    $ConversionTable = @{
        8=255;
        7=254;
        6=252;
        5=248;
        4=240;
        3=224;
        2=192;
        1=128
    }
    if ($PrefixLength -eq 32) {
        $Netmask = "255.255.255.255"
        $Netmask
    } elseif ($PrefixLength -gt 24) {
        $FirstOctet = 255
        $SecondOctet = 255
        $ThirdOctet = 255
        $FourthOctet = $ConversionTable[($PrefixLength - 24)]

        $NetMask = "$($FirstOctet).$($SecondOctet).$($ThirdOctet).$($FourthOctet)"
        $NetMask
    } elseif ($PrefixLength -eq 24) {
        $Netmask = "255.255.255.255"
        $Netmask
    } elseif ($PrefixLength -gt 16) {
        $FirstOctet = 255
        $SecondOctet = 255
        $ThirdOctet = $ConversionTable[($PrefixLength - 16)]
        $FourthOctet = 0

        $NetMask = "$($FirstOctet).$($SecondOctet).$($ThirdOctet).$($FourthOctet)"
        $NetMask
    } elseif ($PrefixLength -eq 16) {
        $Netmask = "255.255.0.0"
        $Netmask
    } elseif ($PrefixLength -gt 8) {
        $FirstOctet = 255
        $SecondOctet = $ConversionTable[($PrefixLength - 8)]
        $ThirdOctet = 0
        $FourthOctet = 0

        $NetMask = "$($FirstOctet).$($SecondOctet).$($ThirdOctet).$($FourthOctet)"
        $NetMask
    } elseif ($PrefixLength -eq 8) {
        $Netmask = "255.0.0.0"
        $Netmask
    } elseif ($PrefixLength -gt 0) {
        $FirstOctet = $ConversionTable[($PrefixLength)]
        $SecondOctet = 0
        $ThirdOctet = 0
        $FourthOctet = 0

        $NetMask = "$($FirstOctet).$($SecondOctet).$($ThirdOctet).$($FourthOctet)"
        $Netmask
    } elseif ($PrefixLength -eq 0) {
        $Netmask = "0.0.0.0"
        $Netmask
    }
}#>

function Write-Log {
#Function created by Luke Nichols
    Param ([string]$logString)

    if ($LoggingMode -eq $true) {
        #Generate fresh date info for logging dates/times into log
        $mostCurrentYear = (Get-Date).Year
        $mostCurrentMonth = ((Get-Date).Month).ToString("00")
        $mostCurrentDay = ((Get-Date).Day).ToString("00")
        $mostCurrentHour = ((Get-Date).Hour).ToString("00")
        $mostCurrentMinute = ((Get-Date).Minute).ToString("00")
        $mostCurrentSecond = ((Get-Date).Second).ToString("00")
  
        #Log the content
        $LogContent = "$mostCurrentYear-$mostCurrentMonth-$($mostCurrentDay)T$($mostCurrentHour):$($mostCurrentMinute):$($mostCurrentSecond),$logString"
        Add-Content $LogFilePath -value $LogContent
        if ($VerboseLogging -eq $true) {
            Write-Host $LogMessage
        }
    }
}

Function Delete-OldFiles {
#Function written by Luke Nichols
    param ([int]$NumberOfDays, [string]$PathToLogs)

    #Fetch the current date minus $NumberOfDays
    [DateTime]$limit = (Get-Date).AddDays(-$NumberOfDays)

    #Delete files older than $limit.
    Get-ChildItem -Path $PathToLogs | Where-Object { (($_.CreationTime -le $limit) -and (($_.Name -like "*.log*") -or ($_.Name -like "*.txt*"))) } | Remove-Item -Force
}

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

#Set variables for write-log function
#$LoggingMode = $true
#$VerboseLogging = $true

#Define the root path of the running script
#$myPSScriptRoot = "C:\Scripts\WakeOnLANFromCSV"

#Define the path to the log file
#[string]$LogFilePath = "$($myPSScriptRoot)\logs\WakeOnLANFromCSV_$($currentYear)-$($currentMonth)-$($currentDay)T$($currentHour)$($currentMinute)$($currentSecond)_$($env:computername).txt"

#Dot-source settings file
if (Test-Path .\CustomSettings.ps1) {
    . .\CustomSettings.ps1
    $LogMessage = "Importing settings from CustomSettings.ps1"
} else {
    . .\DefaultSettings.ps1
    $LogMessage = "Importing settings from DefaultSettings.ps1"
}

#Define the path to the CSV file containing the MAC addresses. Assumes the first line is the header line and that there is a "MACAddress" field.
#$FullPathToCSV = "\\kuit.ku.kettering.edu\itstuff\Software\PDQ_Deploy_Repo\Reports\MacAddrOn620\MAC Addresses on 620 VLAN.csv"

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