<#
.SYNOPSIS
    Configures nondomain joined servers to enable updates for other Microsoft products on non-domain joined machines. 
    To be used in combination with https://devblogs.microsoft.com/dotnet/server-operating-systems-auto-updates/

.DESCRIPTION
    This script sets the local group policy to configure automatic updates and enables updates for other Microsoft products.

.EXAMPLE
    Set-LocalGPOUpdate
    This example configures the asset to receive updates for other Microsoft products.

.NOTES
    Author: Sean Ackerman
    Date: 10/31/2024
#>
function Set-LocalGPOUpdate {
    # Define the registry path and value name
    $regPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate"
    $valueName = "AllowMUUpdateService"

    # Check if the registry path exists; if not, create it
    if (-not (Test-Path $regPath)) {
        New-Item -Path $regPath -Force | Out-Null
    }

    # Set the DWORD registry value to enable Microsoft Update
    Set-ItemProperty -Path $regPath -Name $valueName -Value 1 -Type DWord

    Write-Output "Automatic updates for other Microsoft products are now enabled."
}

# Run the function
Set-AllowMUUpdate
