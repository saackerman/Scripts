function Set-VMHostServiceState {
    <#
        .SYNOPSIS
            Starts or stops a service on ESXi hosts in a cluster.

        .DESCRIPTION
            Targets all hosts in the specified cluster and starts or stops
            the given host service. Defaults to SSH (TSM-SSH) and Start action.
            Results stored in $HostServiceResults for later use.

        .PARAMETER Cluster
            Name of the cluster containing the target hosts.

        .PARAMETER ServiceKey
            The ESXi host service key. Defaults to 'TSM-SSH' (SSH).
            Common keys: TSM-SSH (SSH), TSM (ESXi Shell), ntpd (NTP),
            DCUI (Direct Console), vpxa (vCenter Agent).

        .PARAMETER Action
            Start or Stop the service. Defaults to Start.

        .OUTPUTS
            System.Collections.Generic.List[PSCustomObject]
            Each object has VMHost, Service, Action, and Status properties.

        .EXAMPLE
            Set-VMHostServiceState -Cluster 'BattleStarGalactica'

            Starts SSH on all hosts in BattleStarGalactica cluster.

        .EXAMPLE
            Set-VMHostServiceState -Cluster 'BattleStarGalactica' -Action Stop

            Stops SSH on all hosts in BattleStarGalactica cluster.

        .EXAMPLE
            Set-VMHostServiceState -Cluster 'BattleStarGalactica' -ServiceKey 'ntpd'

            Starts NTP on all hosts in BattleStarGalactica cluster.

        .EXAMPLE
            Set-VMHostServiceState -Cluster 'BattleStarGalactica' -WhatIf

            Preview without making changes.

        .EXAMPLE
            Set-VMHostServiceState -Cluster 'BattleStarGalactica'
            $HostServiceResults | Out-GridView

            Start SSH, then review results in grid.

        .NOTES
            Requires an active vCenter connection (Connect-VIServer).
            Requires VMware.PowerCLI module.
    #>
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType([PSCustomObject])]
    param (
        # Cluster name containing target hosts
        [Parameter(Mandatory = $true, Position = 0,
            HelpMessage = "Name of the cluster, e.g. 'BattleStarGalactica'")]
        [ValidateNotNullOrEmpty()]
        [Alias('Name')]
        [string]$Cluster,

        # ESXi host service key — default SSH. Run Get-VMHostService to see all keys.
        [Parameter(Position = 1,
            HelpMessage = "Service key, e.g. 'TSM-SSH' for SSH, 'ntpd' for NTP. Run Get-VMHostService to list all.")]
        [ValidateNotNullOrEmpty()]
        [Alias('Service', 'Key')]
        [string]$ServiceKey = 'TSM-SSH',

        # Start or Stop the service
        [Parameter()]
        [ValidateSet('Start', 'Stop')]
        [string]$Action = 'Start'
    )

    begin {
        Set-StrictMode -Version Latest
        $ErrorActionPreference = 'Stop'

        $script:HostServiceResults = [System.Collections.Generic.List[PSCustomObject]]::new()
    }

    process {
        try {
            $ClusterObj = Get-Cluster -Name $Cluster -ErrorAction Stop
            $VMHosts = Get-VMHost -Location $ClusterObj -ErrorAction Stop

            Write-Verbose "Found $($VMHosts.Count) hosts in cluster '$Cluster'"

            foreach ($VMHost in $VMHosts) {
                $HostService = $VMHost |
                    Get-VMHostService |
                    Where-Object { $_.Key -eq $ServiceKey }

                if (-not $HostService) {
                    $script:HostServiceResults.Add([PSCustomObject]@{
                        VMHost  = $VMHost.Name
                        Service = $ServiceKey
                        Action  = $Action
                        Status  = 'Skipped'
                        Message = "Service '$ServiceKey' not found on host"
                    })
                    Write-Warning "$($VMHost.Name): Service '$ServiceKey' not found"
                    continue
                }

                $AlreadyRunning = $HostService.Running

                if ($Action -eq 'Start' -and $AlreadyRunning) {
                    $script:HostServiceResults.Add([PSCustomObject]@{
                        VMHost  = $VMHost.Name
                        Service = $ServiceKey
                        Action  = $Action
                        Status  = 'Already Running'
                        Message = 'No action needed'
                    })
                    Write-Verbose "$($VMHost.Name): $ServiceKey already running"
                    continue
                }

                if ($Action -eq 'Stop' -and -not $AlreadyRunning) {
                    $script:HostServiceResults.Add([PSCustomObject]@{
                        VMHost  = $VMHost.Name
                        Service = $ServiceKey
                        Action  = $Action
                        Status  = 'Already Stopped'
                        Message = 'No action needed'
                    })
                    Write-Verbose "$($VMHost.Name): $ServiceKey already stopped"
                    continue
                }

                if ($PSCmdlet.ShouldProcess("$($VMHost.Name) — $ServiceKey", "$Action service")) {
                    try {
                        if ($Action -eq 'Start') {
                            $HostService | Start-VMHostService -Confirm:$false | Out-Null
                        }
                        else {
                            $HostService | Stop-VMHostService -Confirm:$false | Out-Null
                        }

                        $script:HostServiceResults.Add([PSCustomObject]@{
                            VMHost  = $VMHost.Name
                            Service = $ServiceKey
                            Action  = $Action
                            Status  = 'Success'
                            Message = "$Action completed"
                        })
                        Write-Verbose "$($VMHost.Name): $ServiceKey $Action completed"
                    }
                    catch {
                        $script:HostServiceResults.Add([PSCustomObject]@{
                            VMHost  = $VMHost.Name
                            Service = $ServiceKey
                            Action  = $Action
                            Status  = 'Failed'
                            Message = "Error: $_"
                        })
                        Write-Error "$($VMHost.Name): Failed to $Action $ServiceKey — $_"
                    }
                }
            }

            Write-Verbose "$Action $ServiceKey on $($script:HostServiceResults.Count) hosts processed"
            $script:HostServiceResults
        }
        catch {
            Write-Error "Failed to $Action service '$ServiceKey' on cluster '$Cluster': $_"
        }
    }
}
