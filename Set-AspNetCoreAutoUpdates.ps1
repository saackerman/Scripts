<#
.SYNOPSIS
    Configures automatic updates for ASP.NET Core runtimes on Windows. You must opt-in to get updates from Microsoft Update by enabling 
    “Receive updates for other Microsoft products when you update Windows” 
    Find this under Settings > Update & Security > Windows Update > Advanced options. 
    To be used in combination Set-WUSettings.ps1

.DESCRIPTION
    This function enables updates for ASP.NET Core runtimes by setting registry keys to enable automatic updates for these runtimes. 

.PARAMETER RuntimeVersion
    The version of the ASP.NET Core runtime to install and configure updates for (e.g., 8.0, 7.0).

.EXAMPLE
    Set-AspNetCoreAutoUpdates -RuntimeVersion 8.0
    This example installs or updates ASP.NET Core 8.0 and configures automatic updates for it.

.NOTES
    Author: Sean Ackerman
    Date: 10/31/2024
.LINK
    https://docs.microsoft.com/en-us/dotnet/core/install/windows?tabs=net50
    https://devblogs.microsoft.com/dotnet/server-operating-systems-auto-updates/
    https://devblogs.microsoft.com/dotnet/net-core-updates-coming-to-microsoft-update/
#>


function Set-AspNetCoreAutoUpdates {
    param (
        [Parameter(Mandatory=$true)]
        [ValidateSet("8.0", "7.0", "6.0")]
        [string]$RuntimeVersion
    )

    
    $regPathNET = "HKLM:\SOFTWARE\Microsoft"
    $dotNetPath = "$regPath\.NET"
    
        if (-not (Test-Path $dotNetPath)) {
            New-Item -Path $dotNetPathNET -Force | Out-Null
            Write-Output "The .NET key was added to the registry."
        } else {
            Write-Output "The .NET key already exists in the registry."
        }
    
    # Configure registry settings for automatic updates if the runtime is installed
    $regPath = "HKLM:\SOFTWARE\Microsoft\.NET\$RuntimeVersion"
    if (-not (Test-Path $regPath)) {
        New-Item -Path $regPath -Force | Out-Null
    }
    Set-ItemProperty -Path $regPath -Name "AllowAUOnServerOS" -Value 1
    Write-Output "Automatic updates for ASP.NET Core $RuntimeVersion runtime are now enabled."
    }

# Example usage
Set-AspNetCoreAutoUpdates -RuntimeVersion 8.0



