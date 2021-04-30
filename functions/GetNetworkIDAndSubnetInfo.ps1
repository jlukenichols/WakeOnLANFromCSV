#Functions taken from https://codeandkeep.com/PowerShell-Get-Subnet-NetworkID/

Function Convert-IPv4AddressToBinaryString {
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