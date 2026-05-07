<#
.SYNOPSIS
    Pull VM and networking/VLAN info using PowerCLI.
    Handles both distributed and standard port groups without deprecated warnings.

.DESCRIPTION
    For each VM, retrieves network adapters and resolves the port group to get
    VLAN ID, port group type (Distributed/Standard), switch name, IP, and MAC.
    Results stored in $VMinfo for later use (Out-GridView, Export-Csv, etc.).

.PARAMETER vms
    One or more VM names to query.

.EXAMPLE
    .\Get-VMVLAN.ps1 -vms 'WebServer01'

.EXAMPLE
    .\Get-VMVLAN.ps1 -vms (Get-Content .\servers.txt)

.EXAMPLE
    .\Get-VMVLAN.ps1 -vms 'VM1','VM2','VM3'
    $VMinfo | Out-GridView

.EXAMPLE
    .\Get-VMVLAN.ps1 -vms 'VM1'
    $VMinfo | Export-Csv .\vm-vlan-report.csv -NoTypeInformation

.CREDIT
    https://www.undocumented-features.com/2019/10/09/creating-an-array-with-header-columns-from-a-string-using-pscustomobject/
#>

param (
    [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
    [string[]]$vms
)

[System.Collections.Generic.List[PSCustomObject]]$VMinfo = @()
$date = Get-Date -Format MM_dd_yyyy_ss
$file = "VM2VLANmigration.csv"

foreach ($vmName in $vms) {
    $vm = Get-VM -Name $vmName -ErrorAction SilentlyContinue
    if (-not $vm) {
        Write-Warning "VM not found: $vmName"
        continue
    }

    [string]$ip = ($vm.Guest.IPAddress) -join ', '
    [string]$mac = ($vm.Guest.Nics.MacAddress) -join ', '

    $NetworkAdapters = Get-NetworkAdapter -VM $vm

    if (-not $NetworkAdapters) {
        $VMinfo.Add([PSCustomObject]@{
            Servername     = $vm.Name
            NetworkAdapter = 'None'
            NetworkName    = 'N/A'
            VlanId         = 'N/A'
            PortGroupType  = 'N/A'
            SwitchName     = 'N/A'
            IPaddress      = $ip
            MAC            = $mac
            ESXHost        = $vm.VMHost
        })
        continue
    }

    foreach ($Adapter in $NetworkAdapters) {
        $PG = $null
        $VlanId = 'N/A'
        $PortGroupType = 'Unknown'
        $SwitchName = 'N/A'

        # Try distributed port group first
        $PG = $Adapter | Get-VDPortgroup -ErrorAction SilentlyContinue

        if ($PG) {
            $PortGroupType = 'Distributed'
            $SwitchName = $PG.VDSwitch.Name

            try {
                $VlanObj = $PG.ExtensionData.Config.DefaultPortConfig.Vlan
                if ($VlanObj -is [VMware.Vim.VmwareDistributedVirtualSwitchVlanIdSpec]) {
                    $VlanId = $VlanObj.VlanId
                }
                elseif ($VlanObj -is [VMware.Vim.VmwareDistributedVirtualSwitchTrunkVlanSpec]) {
                    $VlanId = ($VlanObj.VlanId | ForEach-Object { "$($_.Start)-$($_.End)" }) -join ','
                }
            }
            catch {
                $VlanId = 'N/A'
            }
        }
        else {
            # Fall back to standard port group
            $PG = Get-VirtualPortGroup -VMHost $vm.VMHost -Standard -ErrorAction SilentlyContinue |
                Where-Object { $_.Name -eq $Adapter.NetworkName }

            if ($PG) {
                $PortGroupType = 'Standard'
                $VlanId = $PG.VLanId
                $SwitchName = $PG.VirtualSwitchName
            }
        }

        $VMinfo.Add([PSCustomObject]@{
            Servername     = $vm.Name
            NetworkAdapter = $Adapter.Name
            NetworkName    = $Adapter.NetworkName
            VlanId         = $VlanId
            PortGroupType  = $PortGroupType
            SwitchName     = $SwitchName
            IPaddress      = $ip
            MAC            = $Adapter.MacAddress
            ESXHost        = $vm.VMHost
        })
    }
}

# Output to console
$VMinfo | Format-List -Property Servername, IPaddress, NetworkAdapter, NetworkName, VlanId, PortGroupType, SwitchName,ESXHost

# Results stored in $VMinfo for later use:
#   $VMinfo | Out-GridView
#   $VMinfo | Export-Csv ($date + $file) -NoTypeInformation
