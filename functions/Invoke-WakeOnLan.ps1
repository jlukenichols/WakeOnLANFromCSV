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