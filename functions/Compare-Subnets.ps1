#https://geekseat.wordpress.com/2011/02/21/comparubg-ips-using-powershell-script-of-the-day/
Function Compare-Subnets {
    param (
    [parameter(Mandatory=$true)]
    [Net.IPAddress]
    $ip1,
 
    [parameter(Mandatory=$true)]
    [Net.IPAddress]
    $ip2,
 
    [parameter()]
    [alias("SubnetMask")]
    [Net.IPAddress]
    $mask ="255.255.255.0"
    )
 
    if (($ip1.address -band $mask.address) -eq ($ip2.address -band $mask.address)) {
        return $true
    } else {
        return $false
    } 
}