<#
.SYNOPSIS
    Prueft, ob Benutzername und Passwort gegen eine Domaene gueltig sind.

.DESCRIPTION
    Bindet sich ueber System.DirectoryServices.AccountManagement an die
    angegebene Domaene und gibt $true oder $false zurueck. Die Anmeldedaten
    lassen sich wahlweise als PSCredential oder als Benutzername plus
    SecureString uebergeben.

.NOTES
    Ein fehlgeschlagener Versuch zaehlt auf den Sperrzaehler des Kontos ein.
    In einer Schleife ueber viele Passwoerter sperrt man damit das Konto.
#>

# This script checks whether the user name and password are correct and returns true or false accordingly.
function Test-DomainCredentials {
    param (
        # Credential-based input
        [Parameter(ParameterSetName = 'CredentialSet', Mandatory = $true)]
        [PSCredential] $Credential,

        # Username and Password input
        [Parameter(ParameterSetName = 'UserPassSet', Mandatory = $true)]
        [string] $Username,

        [Parameter(ParameterSetName = 'UserPassSet', Mandatory = $true)]
        [SecureString] $Password,

        # Common parameter
        [Parameter(Mandatory = $true)]
        [string] $Domain
    )
    
    try {
        # Load necessary .NET assembly
        [System.Reflection.Assembly]::LoadWithPartialName("System.DirectoryServices.AccountManagement") | Out-Null

        # Handle credential input
        if ($PSCmdlet.ParameterSetName -eq 'CredentialSet') {
            $Username = $Credential.UserName
            $Password = $Credential.Password
        }

        # Convert SecureString password to plain text
        $passwordPlainText = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto(
            [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($Password)
        )

        # Create PrincipalContext object for domain
        $principalContext = New-Object System.DirectoryServices.AccountManagement.PrincipalContext([System.DirectoryServices.AccountManagement.ContextType]::Domain, $Domain)

        # Validate credentials
        $result = $principalContext.ValidateCredentials($Username, $passwordPlainText)
        return $result
    } catch {
        Write-Error "An error occurred: $_"
        return $false
    }
}