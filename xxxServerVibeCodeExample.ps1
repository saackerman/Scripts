<#
.SYNOPSIS
    Windows Server Inventory Script
    Collects installed software information and checks for IIS/SQL configurations
    
.DESCRIPTION
    This script inventories a Windows Server, collecting details about installed software
    and specific configurations for IIS and SQL Server if present.
    
.PARAMETER OutputPath
    Specifies the path where the inventory report will be saved
    
.EXAMPLE
    .\ServerInventory.ps1 -OutputPath "C:\Reports"
#>

[CmdletBinding()]
param (
    [Parameter(Mandatory = $true)]
    [ValidateScript({Test-Path $_ -PathType Container})]
    [string]$OutputPath
)

# Set error handling
$ErrorActionPreference = "Stop"

# Function to get installed software
function Get-InstalledSoftware {
    [CmdletBinding()]
    param ()
    
    Write-Verbose "Collecting installed software information..."
    
    try {
        $software = Get-ItemProperty "HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*" -ErrorAction SilentlyContinue |
            Where-Object { $_.DisplayName } |
            Select-Object DisplayName, DisplayVersion, Publisher, InstallDate
        
        $software += Get-ItemProperty "HKLM:\Software\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*" -ErrorAction SilentlyContinue |
            Where-Object { $_.DisplayName } |
            Select-Object DisplayName, DisplayVersion, Publisher, InstallDate
            
        return $software | Sort-Object DisplayName
    }
    catch {
        Write-Error "Failed to retrieve installed software: $_"
        return $null
    }
}

# Function to check IIS configuration
function Get-IISConfiguration {
    [CmdletBinding()]
    param ()
    
    Write-Verbose "Checking IIS configuration..."
    
    try {
        if (Get-Service -Name "W3SVC" -ErrorAction SilentlyContinue) {
            Import-Module WebAdministration -ErrorAction Stop
            $iisInfo = [PSCustomObject]@{
                Version        = (Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\InetStp\").SetupString
                Sites          = (Get-Website | Select-Object -Property Name, State, PhysicalPath)
                AppPools       = (Get-IISAppPool | Select-Object -Property Name, State)
                WorkerProcesses = Get-CimInstance Win32_PerfFormattedData_W3SVC_WebService
            }
            return $iisInfo
        }
        else {
            Write-Verbose "IIS not installed"
            return "Not Installed"
        }
    }
    catch {
        Write-Error "Failed to retrieve IIS configuration: $_"
        return $null
    }
}

# Function to check SQL Server configuration
function Get-SQLConfiguration {
    [CmdletBinding()]
    param ()
    
    Write-Verbose "Checking SQL Server configuration..."
    
    try {
        $sqlInstances = Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Microsoft SQL Server\Instance Names\SQL" -ErrorAction SilentlyContinue
        if ($sqlInstances) {
            $sqlInfo = [PSCustomObject]@{
                Instances = $sqlInstances.PSObject.Properties | Select-Object Name, Value
                Version   = (Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Microsoft SQL Server\$($sqlInstances.PSObject.Properties.Value)\Setup").Version
                Edition   = (Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Microsoft SQL Server\$($sqlInstances.PSObject.Properties.Value)\Setup").Edition
                Services  = Get-Service -Name "*SQL*" | Select-Object Name, Status, StartType
            }
            return $sqlInfo
        }
        else {
            Write-Verbose "SQL Server not installed"
            return "Not Installed"
        }
    }
    catch {
        Write-Error "Failed to retrieve SQL configuration: $_"
        return $null
    }
}

# Main execution
try {
    # Create report object
    $inventoryReport = [PSCustomObject]@{
        ComputerName    = $env:COMPUTERNAME
        DateCollected   = Get-Date
        Software        = Get-InstalledSoftware
        IISConfig       = Get-IISConfiguration
        SQLConfig       = Get-SQLConfiguration
    }
    
    # Generate output file name
    $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
    $fileName = "ServerInventory_$($env:COMPUTERNAME)_$timestamp.html"
    $fullPath = Join-Path -Path $OutputPath -ChildPath $fileName
    
    # Convert to HTML with styling
    $htmlHeader = @"
    <style>
        body { font-family: Arial, sans-serif; }
        table { border-collapse: collapse; width: 100%; margin-bottom: 20px; }
        th, td { border: 1px solid #ddd; padding: 8px; text-align: left; }
        th { background-color: #f2f2f2; }
        h2 { color: #333; }
    </style>
"@

    $htmlBody = $inventoryReport | ConvertTo-Html -Head $htmlHeader -PreContent "<h2>Server Inventory Report</h2>"
    
    # Save report
    $htmlBody | Out-File -FilePath $fullPath -Encoding UTF8
    Write-Host "Inventory report saved to: $fullPath" -ForegroundColor Green
    
    # Export raw data as JSON backup
    $jsonPath = $fullPath.Replace('.html', '.json')
    $inventoryReport | ConvertTo-Json -Depth 4 | Out-File -FilePath $jsonPath -Encoding UTF8
    Write-Host "JSON backup saved to: $jsonPath" -ForegroundColor Green
}
catch {
    Write-Error "Script execution failed: $_"
    exit 1
}
finally {
    Write-Verbose "Script execution completed"
}
