<#
.SYNOPSIS
    Retrieves TLS/SSL certificate details from a remote network endpoint.

.DESCRIPTION
    This script connects to a specified website or server over a network port (like 443) 
    using raw .NET sockets. It inspects the SSL/TLS handshake to extract the certificate 
    details (Thumbprint, Issuer, Expiration Date) without downloading the certificate or 
    requiring local admin rights. 
    
    It safely bypasses SSL validation errors, meaning it will successfully read and report 
    on expired, untrusted, or self-signed certificates instead of crashing.

.PARAMETER Url
    The domain name or IP address of the target server. Defaults to 'www.google.com'.

.PARAMETER Port
    The network port to connect to. Defaults to 443 (HTTPS).

.PARAMETER Timeout
    The maximum time in milliseconds to wait for the connection or handshake before 
    giving up. Defaults to 5000 (5 seconds).

.EXAMPLE
    .\Get-CertInfo.ps1 -Url "www.google.com"
    
    Retrieves the certificate information for Google over the default port 443.

.EXAMPLE
    .\Get-CertInfo.ps1 -Url "internal-router.local" -Port 8443 -Timeout 2000
    
    Queries a custom internal site on port 8443, shortening the timeout threshold to 2 seconds.

.EXAMPLE
    "www.microsoft.com", "www.github.com" | .\Get-CertInfo.ps1
    
    Demonstrates pipeline capability. You can pipe multiple URLs directly into the script 
    to scan them sequentially.

.OUTPUTS
    [PSCustomObject] containing Hostname, Port, Subject, Issuer, Thumbprint, Start, End, 
    ExpirationDays, and IsValid properties.
#>

[CmdletBinding()]
param (
    [Parameter(Position = 0, ValueFromPipeline = $true)]
    [string[]]$Url = "www.google.com",

    [Parameter(Position = 1)]
    [int]$Port = 443,

    [Parameter()]
    [int]$Timeout = 5000
)

process {
    $tcpClient = $null
    $sslStream = $null

    try {
        # Initialize TCP client with explicit network timeouts
        $tcpClient = [System.Net.Sockets.TcpClient]::new()
        $tcpClient.ReceiveTimeout = $Timeout
        $tcpClient.SendTimeout = $Timeout

        # Establish network connection
        $tcpClient.Connect($Url, $Port)

        # Create a .NET validation callback delegate that forces 'true'.
        # This stops the script from crashing when checking expired or self-signed certs.
        $validationCallback = [System.Net.Security.RemoteCertificateValidationCallback]{ 
            param($sender, $certificate, $chain, $sslPolicyErrors) 
            return $true 
        }

        # Bind the SSL stream to the network connection
        $networkStream = $tcpClient.GetStream()
        $sslStream = [System.Net.Security.SslStream]::new($networkStream, $false, $validationCallback)
        
        # Perform SSL/TLS handshake
        $sslStream.AuthenticateAsClient($Url)

        # Extract data safely from the X509Certificate2 object if available
        if ($sslStream.RemoteCertificate) {
            $cert = [System.Security.Cryptography.X509Certificates.X509Certificate2]$sslStream.RemoteCertificate
            
            $expirationDate = $cert.NotAfter
            $daysRemaining = ($expirationDate - (Get-Date)).Days

            # Output a rich object for easy sorting, filtering, or exporting to CSV
            [pscustomobject]@{
                Hostname       = $Url
                Port           = $Port
                Subject        = $cert.Subject
                Issuer         = $cert.Issuer
                Thumbprint     = $cert.Thumbprint
                Start          = $cert.NotBefore
                End            = $expirationDate
                ExpirationDays = $daysRemaining
                IsValid        = $daysRemaining -gt 0
            }
        }
    }
    catch {
        Write-Error "Failed to retrieve certificate for $Url`:$Port. Reason: $_"
    }
    finally {
        # Always clean up and close open network sockets to prevent memory leaks
        if ($sslStream) { $sslStream.Dispose() }
        if ($tcpClient) { $tcpClient.Dispose() }
    }
}
