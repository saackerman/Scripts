<#
.SYNOPSIS
    Configures Windows Update settings to set AUOptions and other policies.

.DESCRIPTION
    This script sets the Windows Update settings by modifying the registry to configure AUOptions, AllowMUUpdateService, and IncludeRecommendedUpdates with parameterized values.

.PARAMETER AUOptions
    The AUOptions DWORD value to set (default: 3).

.PARAMETER AllowMUUpdateService
    The AllowMUUpdateService DWORD value to set (default: 1).

.PARAMETER IncludeRecommendedUpdates
    The IncludeRecommendedUpdates DWORD value to set (default: 1).

.EXAMPLE
    Set-WindowsUpdateSettings -AUOptions 4
    This example configures the Windows Update settings with AUOptions set to 4.

.NOTES
    Author: Sean Ackerman
    Date: Today's Date
#>
function Set-WUSettings {
    param (
        [int]$AUOptions = 3,
        [int]$AllowMUUpdateService = 1,
        [int]$IncludeRecommendedUpdates = 1
    )

    $regPathWU = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate"
    $regPathAU = "$regPathWU\AU"

    # Check if the Windows Update registry path exists; if not, create it
    if (-not (Test-Path $regPathWU)) {
        New-Item -Path $regPathWU -Force | Out-Null
    }

    # Check if the AU registry path exists; if not, create it
    if (-not (Test-Path $regPathAU)) {
        New-Item -Path $regPathAU -Force | Out-Null
    }

    # Set the registry values
    Set-ItemProperty -Path $regPathAU -Name "AUOptions" -Value $AUOptions -Type DWord
    Set-ItemProperty -Path $regPathWU -Name "AllowMUUpdateService" -Value $AllowMUUpdateService -Type DWord
    Set-ItemProperty -Path $regPathWU -Name "IncludeRecommendedUpdates" -Value $IncludeRecommendedUpdates -Type DWord

    Write-Output "Windows Update settings have been configured."
}

# Example usage
Set-WUSettings -AUOptions 4 -AllowMUUpdateService 1 -IncludeRecommendedUpdates 1
