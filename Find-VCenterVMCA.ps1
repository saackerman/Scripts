function Find-VCenterVMCA {
    <#
        .SYNOPSIS
            Locates vCenter VCSA VM on ESXi hosts when vSphere UI is down.

        .DESCRIPTION
            When vCenter is down and you can't use the UI to find where the VCSA
            VM is running, this script connects directly to ESXi hosts via SSH
            or PowerCLI and searches for the vCenter VM by name pattern.

            Three methods available:
            1. DNS lookup (resolve vCenter FQDN to IP, find which host has that IP)
            2. Direct ESXi connection via PowerCLI (Get-VM on each host)
            3. SSH to ESXi hosts and search vim-cmd

        .PARAMETER VCenterName
            Name or pattern of the vCenter VM to find (e.g. 'vcw001', '*vcenter*').

        .PARAMETER ESXiHosts
            List of ESXi host FQDNs or IPs to search.

        .PARAMETER Credential
            Credential for ESXi host access (root).

        .PARAMETER Method
            Search method: DNS, PowerCLI, or SSH. Defaults to PowerCLI.

        .EXAMPLE
            Find-VCenterVMCA -VCenterName '*vcw001*' -ESXiHosts (Get-Content .\esxhosts.txt)

        .EXAMPLE
            Find-VCenterVMCA -VCenterName 'p01vcw001' -ESXiHosts 'esx01','esx02','esx03' -Method DNS

        .EXAMPLE
            Find-VCenterVMCA -VCenterName '*vcenter*' -ESXiHosts 'esx01','esx02' -Credential (Get-Credential root)

        .NOTES
            Use when vCenter UI is down and you need to find which ESXi host
            is running the VCSA to access it via host client (https://esxhost/ui).
            
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param (
        [Parameter(Mandatory = $true, Position = 0,
            HelpMessage = "vCenter VM name or wildcard pattern, e.g. '*vcw001*'")]
        [ValidateNotNullOrEmpty()]
        [Alias('Name', 'VM')]
        [string]$VCenterName,

        [Parameter(Mandatory = $true, Position = 1,
            HelpMessage = "ESXi host FQDNs or IPs to search")]
        [ValidateNotNullOrEmpty()]
        [Alias('Hosts')]
        [string[]]$ESXiHosts,

        [Parameter(HelpMessage = "Credential for ESXi host access (typically root)")]
        [PSCredential]$Credential,

        [Parameter(HelpMessage = "Search method: DNS, PowerCLI, or SSH")]
        [ValidateSet('DNS', 'PowerCLI', 'SSH')]
        [string]$Method = 'PowerCLI'
    )

    begin {
        Set-StrictMode -Version Latest
        $ErrorActionPreference = 'Stop'
    }

    process {
        switch ($Method) {

            'DNS' {
                Write-Host "Method: DNS — Resolving vCenter FQDN to find hosting ESXi..." -ForegroundColor Cyan

                # Resolve vCenter name to IP
                try {
                    $VCenterIP = (Resolve-DnsName -Name $VCenterName -Type A -ErrorAction Stop).IPAddress
                    Write-Host "  vCenter IP: $VCenterIP" -ForegroundColor Green
                }
                catch {
                    Write-Error "Cannot resolve '$VCenterName' via DNS: $_"
                    return
                }

                # Check each ESXi host for a VM with that IP
                foreach ($ESXHost in $ESXiHosts) {
                    Write-Verbose "Checking $ESXHost..."
                    try {
                        $ConnParams = @{ Server = $ESXHost; ErrorAction = 'Stop' }
                        if ($Credential) { $ConnParams['Credential'] = $Credential }

                        Connect-VIServer @ConnParams | Out-Null
                        $VM = Get-VM | Where-Object { $_.Guest.IPAddress -contains $VCenterIP }

                        if ($VM) {
                            [PSCustomObject]@{
                                VCenterVM  = $VM.Name
                                ESXiHost   = $ESXHost
                                PowerState = $VM.PowerState
                                IP         = $VCenterIP
                                Method     = 'DNS'
                            }
                            Write-Host "`n  FOUND: '$($VM.Name)' on $ESXHost" -ForegroundColor Green
                            Disconnect-VIServer -Server $ESXHost -Confirm:$false
                            return
                        }
                        Disconnect-VIServer -Server $ESXHost -Confirm:$false
                    }
                    catch {
                        Write-Warning "  $ESXHost — connection failed: $_"
                    }
                }
            }

            'PowerCLI' {
                Write-Host "Method: PowerCLI — Connecting to each ESXi host directly..." -ForegroundColor Cyan

                foreach ($ESXHost in $ESXiHosts) {
                    Write-Verbose "Searching $ESXHost..."
                    try {
                        $ConnParams = @{ Server = $ESXHost; ErrorAction = 'Stop' }
                        if ($Credential) { $ConnParams['Credential'] = $Credential }

                        Connect-VIServer @ConnParams | Out-Null
                        $VMs = Get-VM -Name $VCenterName -ErrorAction SilentlyContinue

                        if ($VMs) {
                            foreach ($VM in $VMs) {
                                $Result = [PSCustomObject]@{
                                    VCenterVM  = $VM.Name
                                    ESXiHost   = $ESXHost
                                    PowerState = $VM.PowerState
                                    IP         = ($VM.Guest.IPAddress -join ', ')
                                    NumCPU     = $VM.NumCpu
                                    MemoryGB   = $VM.MemoryGB
                                    Method     = 'PowerCLI'
                                }
                                Write-Host "`n  FOUND: '$($VM.Name)' on $ESXHost [$($VM.PowerState)]" -ForegroundColor Green
                                $Result
                            }
                            Disconnect-VIServer -Server $ESXHost -Confirm:$false
                            return
                        }
                        Disconnect-VIServer -Server $ESXHost -Confirm:$false
                    }
                    catch {
                        Write-Warning "  $ESXHost — $($_.Exception.Message)"
                    }
                }
            }

            'SSH' {
                Write-Host "Method: SSH — Running vim-cmd on each ESXi host..." -ForegroundColor Cyan
                Write-Host "  Requires PowerShell 7+ with SSH remoting and key-based auth configured." -ForegroundColor DarkGray

                if ($PSVersionTable.PSVersion.Major -lt 7) {
                    Write-Error "SSH method requires PowerShell 7+ with SSH remoting. Use PowerCLI or DNS method on PS 5.1."
                    return
                }

                foreach ($ESXHost in $ESXiHosts) {
                    Write-Verbose "SSH to $ESXHost..."
                    try {
                        $SshParams = @{
                            HostName    = $ESXHost
                            UserName    = if ($Credential) { $Credential.UserName } else { 'root' }
                            ScriptBlock = { vim-cmd vmsvc/getallvms }
                        }
                        $SshResult = Invoke-Command @SshParams

                        $Match = $SshResult | Where-Object { $_ -match $VCenterName }
                        if ($Match) {
                            Write-Host "`n  FOUND on $ESXHost`:" -ForegroundColor Green
                            $Match | ForEach-Object { Write-Host "    $_" }

                            [PSCustomObject]@{
                                VCenterVM  = ($Match -split '\s+')[1]
                                ESXiHost   = $ESXHost
                                PowerState = 'Unknown (SSH)'
                                IP         = 'N/A'
                                Method     = 'SSH'
                                RawOutput  = $Match -join '; '
                            }
                            return
                        }
                    }
                    catch {
                        Write-Warning "  $ESXHost — SSH failed: $_"
                    }
                }
            }
        }

        Write-Warning "vCenter VM '$VCenterName' not found on any of the provided ESXi hosts."
    }
}
