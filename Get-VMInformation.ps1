
<#
.SYNOPSIS
    Get information from a VM object. Properties inlcude Name, PowerState, vCenterServer, Datacenter, Cluster, VMHost, Datastore, Folder, GuestOS, NetworkName, IPAddress, MacAddress, VMTools
 
 
.NOTES   
    Name: Get-VMInformation
    Author: theSysadminChannel
    Version: 1.0
    DateCreated: 2019-Apr-29
 
 
.EXAMPLE
    For updated help and examples refer to -Online version.
 
 
.LINK
    https://thesysadminchannel.com/get-vminformation-using-powershell-and-powercli -
     
#>
 
    [CmdletBinding()]
 
    param(
        [Parameter(
            Position=0,
            ParameterSetName="NonPipeline"
        )]
        [Alias("VM")]
        [string[]]  $Name,
 
 
        [Parameter(
            Position=1,
            ValueFromPipeline=$true,
            ValueFromPipelineByPropertyName=$true,
            ParameterSetName="Pipeline"
            )]
        [PSObject[]]  $InputObject
 
    )
 
 
    BEGIN {
        if (-not $Global:DefaultVIServer) {
            Write-Error "Unable to continue.  Please connect to a vCenter Server." -ErrorAction Stop
        }
 
        #Verifying the object is a VM
        if ($PSBoundParameters.ContainsKey("Name")) {
            $InputObject = Get-VM $Name
        }
 
        $i = 1
        $Count = $InputObject.Count
    }
 
    PROCESS {
        if (($null -eq $InputObject.VMHost) -and ($null -eq $InputObject.MemoryGB)) {
            Write-Error "Invalid data type. A virtual machine object was not found" -ErrorAction Stop
        }
 
        foreach ($Object in $InputObject) {
            try {
                $vCenter = $Object.Uid -replace ".+@"; $vCenter = $vCenter -replace ":.+"

                # Disk info — each hard disk with capacity, format, and controller type
                $HardDisks = $Object | Get-HardDisk -ErrorAction SilentlyContinue
                $AllDevices = $Object.ExtensionData.Config.Hardware.Device

                # Build controller lookup: key = controller key, value = controller type label
                $ControllerLookup = @{}
                foreach ($Dev in $AllDevices) {
                    if ($Dev -is [VMware.Vim.VirtualSCSIController] -or
                        $Dev -is [VMware.Vim.VirtualNVMEController] -or
                        $Dev -is [VMware.Vim.VirtualIDEController] -or
                        $Dev -is [VMware.Vim.VirtualSATAController]) {
                        $CtrlType = switch -Wildcard ($Dev.GetType().Name) {
                            'ParaVirtualSCSIController'     { 'PVSCSI' }
                            'VirtualLsiLogicSASController'  { 'LSI Logic SAS' }
                            'VirtualLsiLogicController'     { 'LSI Logic' }
                            'VirtualBusLogicController'     { 'BusLogic' }
                            '*NVMEController'               { 'NVMe' }
                            '*IDEController'                { 'IDE' }
                            '*SATAController'               { 'SATA' }
                            default                         { $Dev.GetType().Name }
                        }
                        $ControllerLookup[$Dev.Key] = $CtrlType
                    }
                }

                $DiskSummary = if ($HardDisks) {
                    ($HardDisks | ForEach-Object {
                        # Match disk to controller via ExtensionData
                        $DiskDevice = $AllDevices | Where-Object { $_.DeviceInfo.Label -eq $_.Name } |
                            Select-Object -First 1
                        $CtrlKey = $_.ExtensionData.ControllerKey
                        $CtrlType = if ($CtrlKey -and $ControllerLookup.ContainsKey($CtrlKey)) {
                            $ControllerLookup[$CtrlKey]
                        } else { 'Unknown' }
                        "{0}:{1}GB({2})[{3}]" -f $_.Name, [math]::Round($_.CapacityGB, 1), $_.StorageFormat, $CtrlType
                    }) -join '; '
                } else { 'N/A' }

                $TotalDiskGB = if ($HardDisks) {
                    [math]::Round(($HardDisks | Measure-Object -Property CapacityGB -Sum).Sum, 1)
                } else { 0 }

                # NIC info — adapter type (e1000e, vmxnet3, etc.)
                $NICs = $Object | Get-NetworkAdapter -ErrorAction SilentlyContinue
                $NicSummary = if ($NICs) {
                    ($NICs | ForEach-Object {
                        "{0}:{1}({2})" -f $_.Name, $_.NetworkName, $_.Type
                    }) -join '; '
                } else { 'N/A' }

                [PSCustomObject]@{
                    Name        = $Object.Name
                    PowerState  = $Object.PowerState
                    vCenter     = $vCenter
                    Datacenter  = $Object.VMHost | Get-Datacenter | select -ExpandProperty Name
                    Cluster     = $Object.VMhost | Get-Cluster | select -ExpandProperty Name
                    VMHost      = $Object.VMhost
                    Datastore   = ($Object | Get-Datastore | select -ExpandProperty Name) -join ', '
                    FolderName  = $Object.Folder
                    GuestOS     = $Object.ExtensionData.Config.GuestFullName
                    NumCPU      = $Object.NumCpu
                    MemoryGB    = $Object.MemoryGB
                    DiskCount   = if ($HardDisks) { $HardDisks.Count } else { 0 }
                    TotalDiskGB = $TotalDiskGB
                    Disks       = $DiskSummary
                    NetworkName = ($NICs | ForEach-Object { $_.NetworkName }) -join ', '
                    NICs        = $NicSummary
                    IPAddress   = ($Object.ExtensionData.Summary.Guest.IPAddress) -join ', '
                    MacAddress  = ($NICs | ForEach-Object { $_.MacAddress }) -join ', '
                    VMTools     = $Object.ExtensionData.Guest.ToolsVersionStatus2
                }
 
            } catch {
                Write-Error $_.Exception.Message
 
            } finally {
                if ($PSBoundParameters.ContainsKey("Name")) {
                    $PercentComplete = ($i/$Count).ToString("P")
                    Write-Progress -Activity "Processing VM: $($Object.Name)" -Status "$i/$count : $PercentComplete Complete" -PercentComplete $PercentComplete.Replace("%","")
                    $i++
                } else {
                    Write-Progress -Activity "Processing VM: $($Object.Name)" -Status "Completed: $i"
                    $i++
                }
            }
        }
    }
 
    END {}
