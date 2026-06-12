# Get-VMInformation

## Synopsis

Returns comprehensive VM details from vCenter including placement, networking, and tools status.

## Description

Queries a connected vCenter for VM objects and returns a structured PSCustomObject with datacenter, cluster, host, datastore, folder, guest OS, network, IP, MAC, and VMware Tools info. Supports both direct name input and pipeline input from `Get-VM`.

## Prerequisites

- PowerShell 5.1+
- VMware.PowerCLI module
- Active vCenter connection (`Connect-VIServer`)

## Parameters

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| Name | string[] | No | VM name(s) to query. Accepts wildcards. |
| InputObject | PSObject[] | No | VM object(s) from pipeline (`Get-VM` output) |

## Output

| Property | Type | Description |
|----------|------|-------------|
| Name | string | VM name |
| PowerState | string | PoweredOn, PoweredOff, Suspended |
| vCenter | string | Connected vCenter server |
| Datacenter | string | Parent datacenter |
| Cluster | string | Parent cluster |
| VMHost | string | ESXi host running the VM |
| Datastore | string | Datastore(s), comma-separated |
| FolderName | string | vCenter folder location |
| GuestOS | string | Full guest OS name |
| NetworkName | string | Port group(s), comma-separated |
| IPAddress | string | Guest IP address(es), comma-separated |
| MacAddress | string | NIC MAC address(es), comma-separated |
| VMTools | string | Tools version status |

## Examples

```powershell
# Single VM by name
Get-VMInformation -Name 'server01'

# Multiple VMs
Get-VMInformation -Name 'server01', 'server02', 'server03'

# Pipeline from Get-VM
Get-VM -Location 'Production' | Get-VMInformation

# Export to CSV
Get-VM -Name 'web*' | Get-VMInformation | Export-Csv -Path '.\reports\vm-info.csv' -NoTypeInformation

# Filter powered-off VMs
Get-VM | Get-VMInformation | Where-Object PowerState -eq 'PoweredOff'
```

## Flow Diagram

```mermaid
flowchart TD
    A[Start] --> B{Input method?}
    B -->|Name parameter| C[Get-VM by name]
    B -->|Pipeline| D[Receive VM objects]
    C --> E{Connected to vCenter?}
    D --> E
    E -->|No| F[Write-Error + Stop]
    E -->|Yes| G[Validate VM objects]
    G --> H{Valid VM object?}
    H -->|No| I[Write-Error + Stop]
    H -->|Yes| J[Loop: foreach VM]
    J --> K[Extract vCenter from UID]
    K --> L[Get Datacenter, Cluster, Host]
    L --> M[Get Datastore, Network, IP, MAC]
    M --> N[Build PSCustomObject]
    N --> O[Output to pipeline]
    O --> P{More VMs?}
    P -->|Yes| J
    P -->|No| Q[End]
```

## Sequence Diagram

```mermaid
sequenceDiagram
    participant User
    participant Script as Get-VMInformation
    participant VCenter as vCenter API
    participant VMHost as ESXi Host

    User->>Script: -Name or pipeline VM objects
    Script->>VCenter: Get-VM (if Name param)
    VCenter-->>Script: VM object(s)
    loop Each VM
        Script->>VCenter: Get-Datacenter (from VMHost)
        Script->>VCenter: Get-Cluster (from VMHost)
        Script->>VCenter: Get-Datastore (from VM)
        Script->>VCenter: Get-NetworkAdapter (from VM)
        Script->>Script: Extract IP from ExtensionData
        Script->>Script: Extract Tools status from ExtensionData
        Script-->>User: PSCustomObject with all properties
    end
```

## Notes

- Requires active vCenter connection — fails fast if `$Global:DefaultVIServer` is null
- Progress bar displayed during processing
- Multi-value properties (Datastore, NetworkName, IP, MAC) are comma-separated strings
- Does not include CPU count, RAM, or disk sizing — use `Get-VM` directly for those
- Original author: theSysadminChannel (2019)
