# Redfish OOB Operations Guide

Safe out-of-band power management via iDRAC Redfish API. Use these scripts together to verify host identity before issuing power actions.

## Scripts

| Script | Purpose |
|--------|---------|
| `Get-RedfishPowerState.ps1` | Query power state, hostname, model, service tag |
| `Invoke-RedfishOOBPowerAction.ps1` | Execute power actions (shutdown, power on, cycle) |

## Prerequisites

- PowerShell 7+ (required for `-SkipCertificateCheck` and `-Authentication Basic`)
- Network access to iDRAC management subnet (172.26.80.x)
- iDRAC credentials (root account)
- Dot-source both scripts before use

```powershell
. .\Get-RedfishPowerState.ps1
. .\Invoke-RedfishOOBPowerAction.ps1
$cred = Get-Credential root
```

---

## Step 1 — Identify the Host

Before any power action, always verify the iDRAC IP maps to the correct server.

```powershell
Get-RedfishPowerState -iDRACIP '172.26.80.86' -Credential $cred
```

Output:
```
iDRACIP       HostName            Model               ServiceTag  PowerState
-------       --------            -----               ----------  ----------
172.26.80.86  dev1-w2c1-esx05     PowerEdge R660xs    ABC1234     On
```

**Confirm the HostName and ServiceTag match your inventory before proceeding.**

---

## Step 2 — Validate Multiple Hosts (Bulk)

When targeting a group, query all IPs first and review the list.

```powershell
$targets = 82..93 | ForEach-Object { "172.26.80.$_" }
$inventory = $targets | Get-RedfishPowerState -Credential $cred
$inventory | Format-Table -AutoSize
```

Review the output. Look for:
- Unexpected hostnames (wrong server in the IP slot)
- 401 errors (credential mismatch — different password)
- Already powered-off hosts (no action needed)

---

## Step 3 — Confirm Targets

Filter to only the hosts you intend to act on.

```powershell
# Only powered-on hosts
$toShutdown = $inventory | Where-Object PowerState -eq 'On'
$toShutdown | Format-Table iDRACIP, HostName, ServiceTag
```

Verify the list. If anything looks wrong, remove it:

```powershell
$toShutdown = $toShutdown | Where-Object HostName -ne 'wrong-host-name'
```

---

## Step 4 — Execute Power Action

### Graceful Shutdown

```powershell
$toShutdown.iDRACIP | Invoke-RedfishOOBPowerAction -Action GracefulShutdown -Credential $cred
```

### Power On

```powershell
$toShutdown.iDRACIP | Invoke-RedfishOOBPowerAction -Action On -Credential $cred
```

### Preview with WhatIf

```powershell
$toShutdown.iDRACIP | Invoke-RedfishOOBPowerAction -Action GracefulShutdown -Credential $cred -WhatIf
```

---

## Step 5 — Verify Result

Wait 2-3 minutes, then check power state again.

```powershell
Start-Sleep -Seconds 120
$toShutdown.iDRACIP | Get-RedfishPowerState -Credential $cred | Format-Table
```

All hosts should show `PowerState: Off` after graceful shutdown.

---

## Full Safe Workflow (Copy-Paste Ready)

```powershell
# Setup
. .\Get-RedfishPowerState.ps1
. .\Invoke-RedfishOOBPowerAction.ps1
$cred = Get-Credential root

# Define targets
$targets = 82..93 | ForEach-Object { "172.26.80.$_" }

# Step 1: Verify identity
$inventory = $targets | Get-RedfishPowerState -Credential $cred
$inventory | Format-Table -AutoSize

# Step 2: Filter to powered-on only
$toShutdown = $inventory | Where-Object PowerState -eq 'On'
Write-Host "Shutting down $($toShutdown.Count) host(s):" -ForegroundColor Yellow
$toShutdown | Select-Object iDRACIP, HostName, ServiceTag | Format-Table

# Step 3: Confirm (manual pause)
Read-Host "Press Enter to proceed or Ctrl+C to abort"

# Step 4: Execute
$results = $toShutdown.iDRACIP | Invoke-RedfishOOBPowerAction -Action GracefulShutdown -Credential $cred
$results | Format-Table

# Step 5: Verify (wait then check)
Start-Sleep -Seconds 120
$toShutdown.iDRACIP | Get-RedfishPowerState -Credential $cred | Format-Table
```

---

## Troubleshooting

| Symptom | Cause | Fix |
|---------|-------|-----|
| 401 Unauthorized | Wrong creds for that iDRAC | Check CyberArk, password was rotated |
| No such host is known | Missing `-Authentication Basic` | Update script (already fixed) |
| HostName blank | iDRAC hasn't been configured with hostname | Match by ServiceTag instead |
| PowerState still On after shutdown | Host hung during shutdown | Use `ForceOff` (last resort) |
| Timeout / no response | iDRAC network unreachable | Check `Test-NetConnection -Port 443` |

## Power Actions Reference

| Action | Behavior |
|--------|----------|
| `On` | Power on (from Off state) |
| `ForceOff` | Hard power off (like pulling plug — data loss risk) |
| `GracefulShutdown` | OS-level shutdown via ACPI |
| `PushPowerButton` | Simulate physical button press |
| `PowerCycle` | Off then On (hard reboot) |

## Related Scripts

- `Stop-ESXHostSafe.ps1` — vCenter-based shutdown (evacuates VMs first via DRS)
- `Invoke-iDRACPowerAction.ps1` — Legacy racadm.exe version (same concept, external tool dependency)
- `vxrail_readme.md` — Full inventory with iDRAC IP to hostname mapping
