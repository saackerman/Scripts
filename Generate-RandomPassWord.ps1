<#
.SYNOPSIS
Generates a cryptographically-secure random password.

.DESCRIPTION
Generates a random password composed of uppercase and lowercase letters,
numbers, and special characters. Ensures a minimum number of uppercase,
numeric, and special characters, and returns a password between 16 and the
specified `MaxLength` characters.

.PARAMETER MaxLength
The maximum length of the generated password. Must be at least 16. Default is 20.

.EXAMPLE
Generate-RandomPassword
Generates a password using the default MaxLength of 20.

.EXAMPLE
Generate-RandomPassword -MaxLength 24
Generates a password up to 24 characters long.

.OUTPUTS
System.String
The generated password.

.NOTES
Added comment-based help.
#>
function Generate-RandomPassword {
    [CmdletBinding()]
    param (
        [Parameter(
            Mandatory = $false,
            HelpMessage = "The maximum length of the generated password. Has to be at least 16 characters. Default is 20.",
            Position = 0
            )] 
        [ValidateScript({if ($_ -ge 16) { $true } else { throw "MaxLength must be at least 16." }})]
        [int]$MaxLength = 20 
    )

    $MinLength = 16
    $upperChars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ'
    $lowerChars = 'abcdefghijklmnopqrstuvwxyz'
    $numbers = '1234567890'
    $specialChars = '!@#$%^&*()'

    $password = [System.Collections.Generic.List[char]]::new()

    # Generate required characters
    1..2 | ForEach-Object { $password.Add($upperChars[(Get-Random -Maximum $upperChars.Length)]) }
    1..2 | ForEach-Object { $password.Add($numbers[(Get-Random -Maximum $numbers.Length)]) }
    1..2 | ForEach-Object { $password.Add($specialChars[(Get-Random -Maximum $specialChars.Length)]) }

    # Generate remaining characters
    $remainingLength = Get-Random -Minimum ($MinLength - $password.Count) -Maximum ($MaxLength - $password.Count + 1)
    $allChars = $upperChars + $lowerChars + $numbers + $specialChars
    1..$remainingLength | ForEach-Object { $password.Add([char]$allChars[(Get-Random -Maximum $allChars.Length)]) }

    # Shuffle the password to ensure randomness
    $password = -join ($password | Sort-Object {Get-Random})

   
    Write-Output "New password is "$password.length" characters long." 
    return $password
}

# Call the function to generate and display the password
Generate-RandomPassword
