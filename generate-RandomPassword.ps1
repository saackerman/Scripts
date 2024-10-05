function Generate-RandomPassword {
    [CmdletBinding()]
    param (
        [Parameter(
            Mandatory = $false,
            HelpMessage = "The maximum length of the generated password.",
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

    if ($password.Length -lt $MinLength) {
        throw "Generated password is less than $MinLength characters long."
    }

    return $password
}

# Call the function to generate and display the password
Generate-RandomPassword -MaxLength 23  
