function Start-RemotePacketCapture {
    <#
        .SYNOPSIS
            Starts, stops, and collects packet captures across multiple remote servers.

        .DESCRIPTION
            Uses PSSessions to manage NetEventSession packet captures on remote servers.
            Three phases: Start captures → wait for reproduction → Stop and collect .etl files.
            Filters by destination IP and protocol (TCP by default).

        .PARAMETER ComputerName
            One or more remote server names to capture on.

        .PARAMETER IPAddresses
            IP addresses to filter (source OR destination). Required.

        .PARAMETER IpProtocol
            IP protocol number. Defaults to 6 (TCP). 17=UDP, 1=ICMP.

        .PARAMETER SessionName
            Name for the NetEventSession. Defaults to 'PacketTrace'.

        .PARAMETER RemotePath
            Path on remote servers for .etl file. Defaults to C:\temp.

        .PARAMETER LocalPath
            Local path to copy .etl files back to. Defaults to C:\temp\captures.

        .PARAMETER MaxFileSizeMB
            Max capture file size in MB. Defaults to 512.

        .PARAMETER Credential
            Credential for remote access. Prompts if omitted.

        .PARAMETER SkipCollect
            Skip copying .etl files back after stopping.

        .EXAMPLE
            Start-RemotePacketCapture -ComputerName 'Srv01','Srv02','Srv03','Srv04','Srv05','Srv06' `
                -IPAddresses '10.0.162.189','12.0.177.189'

        .EXAMPLE
            Start-RemotePacketCapture -ComputerName (Get-Content .\servers.txt) `
                -IPAddresses '10.0.0.50' -IpProtocol 17

        .NOTES
            Requires admin rights on remote servers.
            Requires WinRM enabled on targets.
            .etl files can be opened in Wireshark or Microsoft Network Monitor.
            convert ETL To PCAP https://github.com/microsoft/etl2pcapng/
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, Position = 0,
            HelpMessage = "Remote server names to capture on")]
        [ValidateNotNullOrEmpty()]
        [Alias('CN', 'Servers')]
        [string[]]$ComputerName,

        [Parameter(Mandatory = $true, Position = 1,
            HelpMessage = "IP addresses to filter (source or destination)")]
        [ValidateNotNullOrEmpty()]
        [string[]]$IPAddresses,

        [Parameter(HelpMessage = "IP protocol number: 1=ICMP, 6=TCP, 17=UDP. Defaults to 6 (TCP).")]
        [ValidateSet(1, 6, 17)]
        [int]$IpProtocol = 6,

        [Parameter()]
        [string]$SessionName = 'PacketTrace',

        [Parameter()]
        [string]$RemotePath = 'C:\temp',

        [Parameter()]
        [string]$LocalPath = 'C:\temp\captures',

        [Parameter(HelpMessage = "Default is 512 MB, valid range 1- 4096")]
        [ValidateRange(1, 4096)]
        [int]$MaxFileSizeMB = 512,

        [Parameter()]
        [PSCredential]$Credential,

        [Parameter(HelpMessage = "Enable to skip the collection of files")]
        [switch]$SkipCollect
    )

    begin {
        Set-StrictMode -Version Latest
        $ErrorActionPreference = 'Stop'

        # Ensure local collection path exists
        if (-not (Test-Path -Path $LocalPath)) {
            New-Item -ItemType Directory -Path $LocalPath -Force | Out-Null
            Write-Verbose "Created local path: $LocalPath"
        }
    }

    process {
        # ── Build PSSessions ─────────────────────────────────────
        Write-Host "`n[1/4] Connecting to $($ComputerName.Count) server(s)..." -ForegroundColor Cyan

        $SessionParams = @{
            ComputerName = $ComputerName
            ErrorAction  = 'Stop'
        }
        if ($Credential) { $SessionParams['Credential'] = $Credential }

        $Sessions = New-PSSession @SessionParams
        Write-Host "  Connected: $($Sessions.ComputerName -join ', ')" -ForegroundColor Green

        # ── Start captures ───────────────────────────────────────
        Write-Host "`n[2/4] Starting packet captures..." -ForegroundColor Cyan
        Write-Host "  Filter IPs: $($IPAddresses -join ', ')" -ForegroundColor DarkGray
        Write-Host "  Protocol: $IpProtocol (6=TCP, 17=UDP, 1=ICMP)" -ForegroundColor DarkGray

        $StartParams = @{
            Session     = $Sessions
            ScriptBlock = {
                param ($SName, $RPath, $IPs, $Proto, $MaxSize)

                # Ensure remote path exists
                if (-not (Test-Path $RPath)) {
                    New-Item -ItemType Directory -Path $RPath -Force | Out-Null
                }

                $FilePath = Join-Path $RPath "$SName-$env:COMPUTERNAME.etl"

                # Remove stale session if exists
                $existing = Get-NetEventSession -Name $SName -ErrorAction SilentlyContinue
                if ($existing) {
                    Stop-NetEventSession -Name $SName -ErrorAction SilentlyContinue
                    Remove-NetEventSession -Name $SName -ErrorAction SilentlyContinue
                }

                # Create and start
                New-NetEventSession -Name $SName -CaptureMode SaveToFile -LocalFilePath $FilePath -MaxFileSize $MaxSize | Out-Null
                Add-NetEventPacketCaptureProvider -SessionName $SName -Level 4 -CaptureType Physical -IPAddresses $IPs -IpProtocols $Proto | Out-Null
                Start-NetEventSession -Name $SName

                [PSCustomObject]@{
                    Computer = $env:COMPUTERNAME
                    Status   = 'Capturing'
                    FilePath = $FilePath
                }
            }
            ArgumentList = @($SessionName, $RemotePath, $IPAddresses, $IpProtocol, $MaxFileSizeMB)
        }

        $startResults = Invoke-Command @StartParams
        $startResults | Format-Table Computer, Status, FilePath -AutoSize

        # ── Wait for user ────────────────────────────────────────
        Write-Host "`n[3/4] Captures running on all servers." -ForegroundColor Yellow
        Write-Host "  Reproduce the issue now, then press Enter to stop captures." -ForegroundColor Yellow
        Read-Host "  Press Enter to stop"

        # ── Stop captures ────────────────────────────────────────
        Write-Host "`n[4/4] Stopping captures and collecting files..." -ForegroundColor Cyan

        $StopParams = @{
            Session     = $Sessions
            ScriptBlock = {
                param ($SName, $RPath)

                Stop-NetEventSession -Name $SName -ErrorAction SilentlyContinue
                Remove-NetEventSession -Name $SName -ErrorAction SilentlyContinue

                $FilePath = Join-Path $RPath "$SName-$env:COMPUTERNAME.etl"
                $FileSize = if (Test-Path $FilePath) {
                    [math]::Round((Get-Item $FilePath).Length / 1MB, 2)
                }
                else { 0 }

                [PSCustomObject]@{
                    Computer = $env:COMPUTERNAME
                    Status   = 'Stopped'
                    FilePath = $FilePath
                    SizeMB   = $FileSize
                }
            }
            ArgumentList = @($SessionName, $RemotePath)
        }

        $stopResults = Invoke-Command @StopParams
        $stopResults | Format-Table Computer, Status, SizeMB, FilePath -AutoSize

        # ── Collect .etl files ───────────────────────────────────
        if (-not $SkipCollect) {
            Write-Host "`n  Copying .etl files to $LocalPath ..." -ForegroundColor DarkGray

            foreach ($Session in $Sessions) {
                $RemoteFile = Join-Path $RemotePath "$SessionName-$($Session.ComputerName).etl"
                $LocalFile = Join-Path $LocalPath "$SessionName-$($Session.ComputerName).etl"

                try {
                    Copy-Item -FromSession $Session -Path $RemoteFile -Destination $LocalFile -ErrorAction Stop
                    Write-Host "  Copied: $($Session.ComputerName) → $LocalFile" -ForegroundColor Green
                }
                catch {
                    Write-Warning "  Failed to copy from $($Session.ComputerName): $_"
                }
            }
        }

        # ── Cleanup sessions ─────────────────────────────────────
        Remove-PSSession -Session $Sessions
        Write-Host "`nDone. Covert .etl files to PCAP so Wireshark can consume. `n ETL To PCAP https://github.com/microsoft/etl2pcapng/#usage. `n Format is etl2pcapng.exe in.etl out.pcapng " -ForegroundColor Cyan
    }
}
