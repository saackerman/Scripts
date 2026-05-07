function Measure-WebApiCall {
    <#
        .SYNOPSIS
            Measures web API call timing like curl -w, using pure .NET.

        .DESCRIPTION
            Mimics curl's timing output:
              dns=time_namelookup
              connect=time_connect
              tls=time_appconnect
              ttfb=time_starttransfer
              total=time_total

            All times are cumulative from start (in seconds), matching curl behavior.
            Uses raw .NET sockets for accurate phase measurement.

        .PARAMETER Uri
            URL to measure.

        .PARAMETER IgnoreCert
            Skip TLS certificate validation (like curl -k).

        .PARAMETER Iterations
            Number of times to repeat. Defaults to 1.

        .PARAMETER Method
            HTTP method. Defaults to GET.

        .PARAMETER Body
            Request body for POST/PUT.

        .OUTPUTS
            PSCustomObject with dns, connect, tls, ttfb, total (seconds).
            Results stored in $WebApiMetrics.

        .EXAMPLE
            Measure-WebApiCall -Uri 'https://s3website.amazonaws.com' -IgnoreCert

        .EXAMPLE
            Measure-WebApiCall -Uri 'https://api.example.com/health' -Iterations 5

        .EXAMPLE
            Measure-WebApiCall -Uri 'https://api.example.com' -IgnoreCert | Format-Table
        .EXAMPLE
            $Servers = Get-Content .\servers.txt
            $Sessions = New-PSSession -ComputerName $Servers

            $FunctionDef = Get-Content .\Measure-WebApiCall.ps1 -Raw

            $Uris = @(
                'https://somesillything-uswest5.elb.amazonaws.com'
                'https://www.google.com'
                'https://www.msn.com'
            )

            $Results = Invoke-Command -Session $Sessions -ScriptBlock {
                param ($FnDef, $TargetUris)

                Invoke-Expression $FnDef

                foreach ($Uri in $TargetUris) {
                    Measure-WebApiCall -Uri $Uri -IgnoreCert -Iterations 3
                }
            } -ArgumentList $FunctionDef, (,$Uris)

            $Results | Format-Table PSComputerName, Uri, dns, connect, tls, ttfb, total
            $Results | Export-Csv .\WebApiMetrics-MultiUri.csv -NoTypeInformation

            Remove-PSSession $Sessions



        .NOTES
            Equivalent to:
            curl -o /dev/null -sS -w "dns=%{time_namelookup} connect=%{time_connect} tls=%{time_appconnect} ttfb=%{time_starttransfer} total=%{time_total}\n" -k <url>
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param (
        [Parameter(Mandatory = $true, Position = 0, ValueFromPipeline = $true,
            HelpMessage = "URL to measure")]
        [ValidateNotNullOrEmpty()]
        [Alias('Url')]
        [string]$Uri,

        [Parameter()]
        [Alias('k')]
        [switch]$IgnoreCert,

        [Parameter()]
        [ValidateRange(1, 1000)]
        [int]$Iterations = 1,

        [Parameter()]
        [ValidateSet('GET', 'POST', 'PUT', 'DELETE', 'HEAD')]
        [string]$Method = 'GET',

        [Parameter()]
        [string]$Body
    )

    begin {
        $script:WebApiMetrics = [System.Collections.Generic.List[PSCustomObject]]::new()

        # Force TLS 1.2+ (required for PS 5.1 / .NET Framework)
        [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12 -bor [System.Net.SecurityProtocolType]::Tls13
    }

    process {
        $parsedUri = [System.Uri]::new($Uri)
        $isHttps = $parsedUri.Scheme -eq 'https'
        $port = if ($parsedUri.Port -gt 0 -and $parsedUri.Port -ne 80 -and $parsedUri.Port -ne 443) {
            $parsedUri.Port
        }
        elseif ($isHttps) { 443 }
        else { 80 }

        for ($i = 1; $i -le $Iterations; $i++) {
            $totalSw = [System.Diagnostics.Stopwatch]::new()
            $tcpClient = $null
            $sslStream = $null
            $netStream = $null

            try {
                $totalSw.Start()

                # ── DNS ──────────────────────────────────────────
                $dnsEntries = [System.Net.Dns]::GetHostAddresses($parsedUri.Host)
                $dnsTime = $totalSw.Elapsed.TotalSeconds
                $ipAddress = $dnsEntries[0]

                # ── TCP Connect ──────────────────────────────────
                $tcpClient = [System.Net.Sockets.TcpClient]::new()
                $tcpClient.ConnectAsync($ipAddress, $port).Wait(30000) | Out-Null
                $connectTime = $totalSw.Elapsed.TotalSeconds

                # ── TLS Handshake ────────────────────────────────
                $tlsTime = $connectTime
                if ($isHttps) {
                    $netStream = $tcpClient.GetStream()

                    $certCallback = if ($IgnoreCert) {
                        [System.Net.Security.RemoteCertificateValidationCallback]{ $true }
                    }
                    else { $null }

                    $sslStream = [System.Net.Security.SslStream]::new($netStream, $false, $certCallback)
                    $sslStream.AuthenticateAsClient($parsedUri.Host, $null, [System.Security.Authentication.SslProtocols]::Tls12, $false)
                    $tlsTime = $totalSw.Elapsed.TotalSeconds
                }

                # ── Send HTTP Request ────────────────────────────
                $stream = if ($sslStream) { $sslStream } else { $tcpClient.GetStream() }

                $path = if ($parsedUri.PathAndQuery) { $parsedUri.PathAndQuery } else { '/' }
                $hostHeader = if ($parsedUri.Port -ne 80 -and $parsedUri.Port -ne 443 -and $parsedUri.Port -gt 0) {
                    "$($parsedUri.Host):$($parsedUri.Port)"
                }
                else { $parsedUri.Host }

                $requestLine = "$Method $path HTTP/1.1`r`nHost: $hostHeader`r`nConnection: close`r`nUser-Agent: PowerShell/Measure-WebApiCall`r`n"

                if ($Body) {
                    $requestLine += "Content-Length: $($Body.Length)`r`nContent-Type: application/json`r`n`r`n$Body"
                }
                else {
                    $requestLine += "`r`n"
                }

                $requestBytes = [System.Text.Encoding]::ASCII.GetBytes($requestLine)
                $stream.Write($requestBytes, 0, $requestBytes.Length)
                $stream.Flush()

                # ── TTFB (read first byte of response) ───────────
                $buffer = [byte[]]::new(1)
                $stream.ReadTimeout = 30000
                $stream.Read($buffer, 0, 1) | Out-Null
                $ttfbTime = $totalSw.Elapsed.TotalSeconds

                # ── Read rest of response ────────────────────────
                $responseBuffer = [byte[]]::new(65536)
                $totalBytes = 1
                while ($true) {
                    $bytesRead = $stream.Read($responseBuffer, 0, $responseBuffer.Length)
                    if ($bytesRead -eq 0) { break }
                    $totalBytes += $bytesRead
                }

                $totalSw.Stop()
                $totalTime = $totalSw.Elapsed.TotalSeconds

                $result = [PSCustomObject]@{
                    Iteration = $i
                    Uri       = $Uri
                    dns       = [math]::Round($dnsTime, 6)
                    connect   = [math]::Round($connectTime, 6)
                    tls       = [math]::Round($tlsTime, 6)
                    ttfb      = [math]::Round($ttfbTime, 6)
                    total     = [math]::Round($totalTime, 6)
                    bytes     = $totalBytes
                }

                # Print curl-style one-liner
                Write-Host "dns=$($result.dns) connect=$($result.connect) tls=$($result.tls) ttfb=$($result.ttfb) total=$($result.total)"

                $script:WebApiMetrics.Add($result)
                $result
            }
            catch {
                $totalSw.Stop()
                Write-Error "Failed: $_"
            }
            finally {
                if ($sslStream) { $sslStream.Dispose() }
                if ($tcpClient) { $tcpClient.Dispose() }
            }
        }
    }
}
 
