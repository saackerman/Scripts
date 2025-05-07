<#
.SYNOPSIS
    Retrieves a list of installed programs on the system.

.DESCRIPTION
    This function queries the Windows registry to find installed programs.
    It searches both 32-bit and 64-bit registry paths for installed applications.

.PARAMETER DisplayName
    Specifies a filter for the program name. If omitted, all installed programs are listed.

.EXAMPLE
    Get-InstalledPrograms
    Retrieves all installed programs.

.EXAMPLE
    Get-InstalledPrograms -DisplayName "Google Chrome"
    Retrieves details of installed programs matching "Google Chrome".

.NOTES
    - Requires administrative privileges to access certain registry paths.
    - Uses Set-StrictMode -Off to prevent errors from uninitialized variables.
    - Filters results based on the DisplayName property using wildcard matching.
#>
function Get-InstalledPrograms {
    [CmdletBinding()]
    param (
         [Parameter(ValueFromPipeline=$true, HelpMessage="Enter the name of the program to filter results. Use '*' for wildcard matching.")]
        [string]$DisplayName = '*'
    )

    

    # Define registry paths to search for installed programs
    $registryPaths = @(
        'HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*',
        'HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*',
        'HKLM:\Software\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*',
        'HKCU:\Software\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*'
    )

    # Retrieve installed programs from registry and filter by DisplayName
    Get-ItemProperty -Path $registryPaths -ErrorAction SilentlyContinue |
    Where-Object { $_.DisplayName -like $DisplayName } |
    Select-Object -Property DisplayName, UninstallString, ModifyPath |
    Sort-Object -Property DisplayName
}
