<#
.SYNOPSIS
    Exports a certificate from Azure Key Vault to a .pfx file.

.DESCRIPTION
    This function retrieves a certificate from an Azure Key Vault, converts it from Base64, and saves it as a .pfx file.

.PARAMETER VaultName
    The name of the Azure Key Vault.

.PARAMETER CertName
    The name of the certificate in the Key Vault.

.PARAMETER SaveCert
    The file path where the .pfx file will be saved.

.EXAMPLE
    Export-CertificateFromKeyVault -VaultName "MyKeyVault" -CertificateName "MyCert" -OutputFilePath "C:\path\to\cert.pfx"

.NOTES
    Ensure you have the Azure PowerShell module installed and are authenticated to Azure. Signing into Azure purposefully omitted to seperate out functionality/Dependacy. 
.ToDo
convert Write-Verbose to add to central logging for accountability for secure audits.
.Link
https://learn.microsoft.com/en-us/azure/key-vault/certificates/how-to-export-certificate?tabs=azure-powershell
#>
function Export-CertificateFromKeyVault {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [string]$VaultName,

        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [string]$CertName,

        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [string]$SaveCert
    )

    try {
        # Retrieve the certificate secret from Key Vault
        Write-Verbose "Retrieving certificate from $VaultName"
        $pfxSecret = Get-AzKeyVaultSecret -VaultName $VaultName -Name $CertName -AsPlainText

        # Convert the secret from Base64 to byte array
        Write-Verbose "Converting Base64 secret to byte array"
        $certBytes = [Convert]::FromBase64String($pfxSecret)

        # Write the byte array to a .pfx file
        Write-Verbose "Saving Certificate"
        Set-Content -Path $SaveCert -Value $certBytes -AsByteStream

        Write-Verbose "Certificate export completed successfully."
    } catch {
        Write-Error "An error occurred: $_"
    }
}
Export-CertificateFromKeyVault -VaultName "ReplaceMeKeyVault" -CertificateName "ReplaceMeMyCert" -OutputFilePath "ReplaceMecert.pfx"



