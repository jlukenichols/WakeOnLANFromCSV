Function Convert-PrefixLengthToNetmask ($PrefixLength) {
# Function created by Luke Nichols
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
}