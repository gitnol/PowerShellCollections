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