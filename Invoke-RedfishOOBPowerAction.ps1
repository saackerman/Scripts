function Invoke-RedfishOOBPowerAction {
    <#
        .SYNOPSIS
            Controls Dell server power state via iDRAC Redfish API.

        .DESCRIPTION
            Sends power actions to one or more iDRAC endpoints using the
            Redfish REST API. No racadm.exe dependency — pure PowerShell.
            Requires iDRAC 8+ with Redfish enabled (default on iDRAC 9).

        .PARAMETER iDRACIP
            One or more iDRAC IP addresses or hostnames. Accepts pipeline.

        .PARAMETER Action
            Power action to perform. Valid values:
            On, ForceOff, GracefulShutdown, PushPowerButton, PowerCycle.

        .PARAMETER Credential
            PSCredential for iDRAC authentication. Prompted if not provided.

        .EXAMPLE
            Invoke-RedfishOOBPowerAction -iDRACIP '192.0.2.1' -Action GracefulShutdown -Credential $cred

            Graceful shutdown of single server.

        .EXAMPLE
            '192.0.2.1','192.0.2.2' | Invoke-RedfishOOBPowerAction -Action PowerCycle -Credential $cred

            Power cycle multiple servers via pipeline.

        .EXAMPLE
            $devIDRACs = '192.0.2.1','192.0.2.2','192.0.2.3'
            Invoke-RedfishOOBPowerAction -iDRACIP $devIDRACs -Action On -Credential (Get-Credential)

            Power on array of servers.

        .EXAMPLE
            Invoke-RedfishOOBPowerAction -iDRACIP '192.0.2.1' -Action GracefulShutdown -Credential $cred -WhatIf

            Preview without executing.

        .NOTES
            Requires PowerShell 7+ for -SkipCertificateCheck.
            For PS 5.1, add certificate bypass before calling:
            [System.Net.ServicePointManager]::ServerCertificateValidationCallback = { $true }

        .OUTPUTS
            PSCustomObject with iDRACIP, Action, StatusCode, and Result properties.
    #>
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType([PSObject])]
    param (
        [Parameter(Mandatory, ValueFromPipeline, Position = 0,
            HelpMessage = "iDRAC IP address(es), e.g. '192.0.2.1'")]
        [ValidateNotNullOrEmpty()]
        [Alias('IP', 'Host')]
        [string[]]$iDRACIP,

        [Parameter(Mandatory, Position = 1,
            HelpMessage = "Power action: On, ForceOff, GracefulShutdown, PushPowerButton, PowerCycle")]
        [ValidateSet('On', 'ForceOff', 'GracefulShutdown', 'PushPowerButton', 'PowerCycle')]
        [string]$Action,

        [Parameter(Mandatory,
            HelpMessage = "iDRAC credential (typically root)")]
        [System.Management.Automation.PSCredential]
        [System.Management.Automation.Credential()]
        $Credential
    )

    begin {
        $RedfishPath = '/redfish/v1/Systems/System.Embedded.1/Actions/ComputerSystem.Reset'
        $Body = @{ ResetType = $Action } | ConvertTo-Json
    }

    process {
        foreach ($IP in $iDRACIP) {
            $Uri = "https://$IP$RedfishPath"

            if ($PSCmdlet.ShouldProcess("$IP", "$Action via Redfish")) {
                try {
                    $RestParams = @{
                        Uri                  = $Uri
                        Method               = 'Post'
                        Credential           = $Credential
                        Authentication       = 'Basic'
                        Body                 = $Body
                        ContentType          = 'application/json'
                        SkipCertificateCheck = $true
                        ErrorAction          = 'Stop'
                    }
                    $Response = Invoke-RestMethod @RestParams

                    [PSCustomObject]@{
                        iDRACIP    = $IP
                        Action     = $Action
                        StatusCode = 204
                        Result     = 'Success'
                    }
                    Write-Verbose "$IP — $Action completed successfully"
                }
                catch {
                    $StatusCode = if ($_.Exception.Response) {
                        [int]$_.Exception.Response.StatusCode
                    } else { 0 }

                    [PSCustomObject]@{
                        iDRACIP    = $IP
                        Action     = $Action
                        StatusCode = $StatusCode
                        Result     = "Failed: $($_.Exception.Message)"
                    }
                    Write-Warning "$IP — $Action failed: $($_.Exception.Message)"
                }
            }
        }
    }
}
