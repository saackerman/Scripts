<#
.DESCRIPTION
gets certificate info. Add fields you want as needed. gets cert thumbprint, name, and start/end date. calculates days until it expires. Work with powershell 7 and above till the class is retired for something better.

.PARAMETER url
Enter url , default is good if you enter nothing

.PARAMETER port
Enter port default is 443

.EXAMPLE
get-certinfo.ps1 -url www.msn.com -port 443
get-certinfo.ps1 -url mylocalsite.local -port 8443

.OUTPUTS
$certInfo will contain for example
Hostname       : www.google.com
Thumbprint     : F5CCDAB5BA1E141444CC279092CC601F5F08AF77
Start          : 10/16/2023 01:10:46
End            : 01/08/2024 01:10:45
ExpirationDays : 66

.NOTES
Used AI to clean up code.
VScode editor.

.Link
https://learn.microsoft.com/en-us/dotnet/api/system.net.sockets.tcpclient?view=net-7.0

.FUNCTIONALITY
Cool huh kids.

#>

[CmdletBinding()]
param (
    [Parameter()]
    [string]$url = "www.google.com",
    [int]$port = "443"
)

$request = [System.Net.Sockets.TcpClient]::new($url, $port)
$stream = [System.Net.Security.SslStream]::new($request.GetStream())
$stream.AuthenticateAsClient($url)
$effectiveDate = $stream.RemoteCertificate.GetEffectiveDateString() -as [datetime]
$expirationDate = $stream.RemoteCertificate.GetExpirationDateString() -as [datetime]
# create custom object, adjust parameters as needed
$certInfo = [pscustomobject] @{
    Hostname        = $stream.TargetHostName
    Thumbprint      = $stream.RemoteCertificate.Thumbprint
    Start           = [string]$effectiveDate
    End             = [string]$expirationDate
    ExpirationDays  = (New-TimeSpan -Start (Get-Date) -End $expirationDate).Days
}
$certInfo
