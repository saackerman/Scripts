<#
    .DESCRIPTION 
        This script generates a random password with a minimum length of 16 characters and a maximum length of 20 characters.
        The password will contain at least 2 uppercase letters, 2 numbers, and 2 special characters.
        The remaining characters will be randomly selected from the set of uppercase letters, lowercase letters, numbers, and special characters.
        The password is shuffled to ensure randomness.
    .PARAMETER MaxLength 
        The maximum length of the password. The default value is 20.
    .EXAMPLE 
        Generate-RandomPassword
        Generates a random password with a length between 16 and 20 characters.
    .EXAMPLE 
        Generate-RandomPassword -MaxLength 25
        Generates a random password with a length between 16 and 25 characters.
    .EXAMPLE 
        Generate-RandomPassword -MaxLength 10
        Throws an error because the generated password is less than 16 characters long.
    .EXAMPLE 
        Generate-RandomPassword.ps1 -MaxLength 25
        Generates a random password with a length between 16 and 25 characters.
    .NOTES
        File Name      : Generate-RandomPassword.ps1
        Author         : CoPilot
        Code Review    : Sean Ackerman
        Prerequisite   : PowerShell V7+
    .LINK
      https://github.com/saackerman/Scripts/blob/master/generate-RandomPassword.ps1
#>
function Generate-RandomPassword {
    [CmdletBinding()]
    param (
        [ValidateScript({if ($_ -ge 16) { $true } else { throw "MaxLength must be at least 16." }})]
        [int]$MaxLength = 20
    )
    
    $MinLength = 16
    $upperChars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ'
    $lowerChars = 'abcdefghijklmnopqrstuvwxyz'
    $numbers = '1234567890'
    $specialChars = '!@#$%^&*()'

    $password = New-Object System.Collections.Generic.List[char]

    # Generate required characters
    $password.AddRange((1..2 | ForEach-Object { $upperChars[(Get-Random -Maximum $upperChars.Length)] }))
    $password.AddRange((1..2 | ForEach-Object { $numbers[(Get-Random -Maximum $numbers.Length)] }))
    $password.AddRange((1..2 | ForEach-Object { $specialChars[(Get-Random -Maximum $specialChars.Length)] }))

    # Generate remaining characters
    $remainingLength = Get-Random -Minimum ($MinLength - $password.Count) -Maximum ($MaxLength - $password.Count + 1)
    $allChars = $upperChars + $lowerChars + $numbers + $specialChars
    $password.AddRange((1..$remainingLength | ForEach-Object { $allChars[(Get-Random -Maximum $allChars.Length)] }))

    # Shuffle the password to ensure randomness
    $password = -join ($password | Sort-Object {Get-Random})

    if ($password.Length -lt $MinLength) {
        throw "Generated password is less than $MinLength characters long."
    }

    return $password
}
