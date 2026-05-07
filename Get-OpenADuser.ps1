<#
.SYNOPSIS
    Exports all Active Directory user accounts and their properties to a CSV file.

.DESCRIPTION
    This script retrieves all user accounts from Active Directory with all available
    properties using Get-OpenADUser. It iterates through each user, normalizes property
    values for CSV compatibility (handling nulls, collections, security identifiers, and
    dates), and exports the results to a UTF-8 encoded CSV file.

    Collection/array properties (e.g., proxyAddresses, memberOf) are joined with
    semicolons for readability. Null values are replaced with empty strings.

.OUTPUTS
    A CSV file (default: ADUsers.csv) containing all AD user properties.

.NOTES
    - Requires the appropriate Active Directory module providing Get-OpenADUser.
    - May take significant time in large environments due to fetching all properties
      for all users.
#>

# Define the output path
$OutputPath = "ADUsers.csv"

# Fetch all users with every available property
Write-Host "Fetching users from Active Directory... This may take a moment." -ForegroundColor Cyan
#$ADUsers = Get-ADUser -Filter * -Properties *
$ADUsers = Get-OpenADUser -Properties *

$Report = New-Object System.Collections.Generic.List[PSObject]

foreach ($User in $ADUsers) {
    $UserObject = [ordered]@{}
    
    # Get all property names present on this specific user object
    $PropertyNames = $User.PSObject.Properties.Name | Sort-Object

    foreach ($Prop in $PropertyNames) {
        $Value = $User.$Prop

        if ($null -eq $Value) {
            $UserObject.$Prop = ""
        }
        # Check if the attribute is a collection/array (e.g., proxyAddresses, memberOf)
        elseif ($Value -is [System.Collections.IEnumerable] -and $Value -isnot [string]) {
            # Join array elements with a semi-colon for CSV readability
            $UserObject.$Prop = ($Value | Out-String).Trim() -replace "`r`n", "; "
        }
        # Handle specific object types that don't stringify well by default
        elseif ($Value -is [System.Security.Principal.SecurityIdentifier] -or $Value -is [datetime]) {
            $UserObject.$Prop = $Value.ToString()
        }
        else {
            $UserObject.$Prop = $Value.ToString()
        }
    }

    $Report.Add([PSCustomObject]$UserObject)
}

# Export to CSV
Write-Host "Exporting to $OutputPath..." -ForegroundColor Green
$Report | Export-Csv -Path $OutputPath -NoTypeInformation -Encoding UTF8

Write-Host "Done!" -ForegroundColor Yellow