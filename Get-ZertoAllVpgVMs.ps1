#Requires -Version 5.1

<#
    .SYNOPSIS
        Exports all Zerto-protected VMs grouped by VPG to CSV across multiple ZVMs.

    .DESCRIPTION
        Loops through one or more ZVM servers, prompting for credentials at each.
        Authenticates via Keycloak (Zerto 10.x), queries /v1/vms for all protected
        VMs, and exports a single combined CSV sorted by ZVM, VPG, then VM name.

    .PARAMETER ZvmServer
        One or more ZVM hostnames or IPs. Prompts for credentials per server.

    .PARAMETER Port
        ZVM API port. Defaults to 443.

    .PARAMETER ExportCsv
        Path to export CSV. Defaults to .\reports\ZertoVpgVMs_<date>.csv

    .EXAMPLE
        .\Get-ZertoAllVpgVMs.ps1 -ZvmServer 'zvm-prod.example.com'

        Single ZVM — prompts for creds, exports all VPGs/VMs.

    .EXAMPLE
        .\Get-ZertoAllVpgVMs.ps1 -ZvmServer 'zvm-prod.example.com', 'zvm-dr.example.com'

        Multiple ZVMs — prompts for creds at each, combines results into one CSV.

    .EXAMPLE
        .\Get-ZertoAllVpgVMs.ps1 -ZvmServer (Get-Content .\zvm-list.txt)

        Read ZVM list from file.

    .NOTES
        Zerto API v1 on port 443 with Keycloak auth (Zerto 10.x).
        Each ZVM gets its own credential prompt — creds are not reused between servers.
#>

[CmdletBinding()]
param (
    [Parameter(Mandatory, Position = 0, HelpMessage = "One or more ZVM hostnames or IPs")]
    [ValidateNotNullOrEmpty()]
    [Alias('ZVM', 'Server')]
    [string[]]$ZvmServer,

    [Parameter()]
    [ValidateRange(1, 65535)]
    [int]$Port = 443,

    [Parameter(HelpMessage = "Path to export CSV")]
    [string]$ExportCsv = ".\reports\ZertoVpgVMs_$(Get-Date -Format 'yyyy-MM-dd').csv"
)

Set-StrictMode -Version Latest

#region TLS settings
$SkipCert = @{ SkipCertificateCheck = $true }
#endregion

$AllResults = [System.Collections.Generic.List[PSCustomObject]]::new()

foreach ($Server in $ZvmServer) {
    Write-Host "`n--- Processing ZVM: $Server ---" -ForegroundColor Cyan

    #region Prompt for credentials per server
    $Credential = Get-Credential -Message "Enter credentials for ZVM: $Server"
    if (-not $Credential) {
        Write-Warning "No credentials provided for '$Server'. Skipping."
        continue
    }
    #endregion

    #region Authenticate to ZVM (Keycloak — Zerto 10.x)
    $BaseUrl = "https://${Server}:${Port}/v1"
    $Username = $Credential.UserName
    $Password = $Credential.GetNetworkCredential().Password

    Write-Verbose "Authenticating to ZVM at $Server`:$Port..."

    $KeycloakUrl = "https://${Server}:${Port}/auth/realms/zerto/protocol/openid-connect/token"
    $TokenBody = @{
        grant_type = 'password'
        client_id  = 'zerto-client'
        username   = $Username
        password   = $Password
    }

    try {
        $TokenResponse = Invoke-RestMethod -Uri $KeycloakUrl -Method POST -Body $TokenBody @SkipCert -ErrorAction Stop
        $ApiHeaders = @{
            'Accept'        = 'application/json'
            'Authorization' = "Bearer $($TokenResponse.access_token)"
        }
        Write-Verbose "Keycloak auth succeeded for $Server."
    }
    catch {
        Write-Warning "Failed to authenticate to '$Server': $($_.Exception.Message). Skipping."
        continue
    }
    #endregion

    #region Query all VMs
    $VmUrl = "$BaseUrl/vms"
    Write-Verbose "Querying all protected VMs on $Server..."

    try {
        $VmList = Invoke-RestMethod -Uri $VmUrl -Headers $ApiHeaders -ContentType 'application/json' -TimeoutSec 120 @SkipCert -ErrorAction Stop
    }
    catch {
        Write-Warning "Failed to query VMs on '$Server': $($_.Exception.Message). Skipping."
        continue
    }

    if (-not $VmList -or $VmList.Count -eq 0) {
        Write-Warning "No protected VMs found on '$Server'."
        continue
    }
    #endregion

    #region Add results
    foreach ($Vm in $VmList) {
        $AllResults.Add([PSCustomObject]@{
            ZvmServer       = $Server
            VpgName         = $Vm.VpgName
            VmName          = $Vm.VmName
            UsedStorageMB   = $Vm.UsedStorageInMB
            SourceSite      = $Vm.SourceSite
            TargetSite      = $Vm.TargetSite
            Priority        = $Vm.Priority
            Status          = $Vm.Status
        })
    }

    Write-Host "  Found $($VmList.Count) VM(s) on $Server" -ForegroundColor Green
    #endregion
}

#region Sort and export
if ($AllResults.Count -eq 0) {
    Write-Warning "No VMs collected from any ZVM."
    return
}

$AllResults = $AllResults | Sort-Object ZvmServer, VpgName, VmName

$VpgCount = ($AllResults | Select-Object -ExpandProperty VpgName -Unique).Count

$OutputDir = Split-Path -Path $ExportCsv -Parent
if ($OutputDir -and -not (Test-Path $OutputDir)) {
    New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null
}
$AllResults | Export-Csv -Path $ExportCsv -NoTypeInformation -Force

Write-Host "`nExported $($AllResults.Count) VMs across $VpgCount VPGs from $($ZvmServer.Count) ZVM(s) to: $ExportCsv" -ForegroundColor Green
#endregion

$AllResults
