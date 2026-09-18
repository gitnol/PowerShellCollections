function Connect-LdapServer {
    param (
        [string]$HostName,
        [string]$UserName,
        [System.Security.SecureString]$Password,
        [int]$Port = 389
    )

    $Null = [System.Reflection.Assembly]::LoadWithPartialName("System.DirectoryServices.Protocols")

    $ldapEndpoint = if ($Port -eq 636) { "ldaps://$HostName" } else { "$HostName" }
    $LDAPConnect = New-Object System.DirectoryServices.Protocols.LdapConnection $ldapEndpoint

    $LDAPConnect.SessionOptions.SecureSocketLayer = ($Port -eq 636)
    $LDAPConnect.SessionOptions.ProtocolVersion = 3

    $LDAPConnect.AuthType = [System.DirectoryServices.Protocols.AuthType]::Basic
    
    $credentials = New-Object System.Net.NetworkCredential -ArgumentList $UserName, $Password

    Try {
        $ErrorActionPreference = 'Stop'
        $LDAPConnect.Bind($credentials)
        $ErrorActionPreference = 'Continue'
        Write-Verbose "Successfully bound to LDAP on port $Port!" -Verbose
    }
    Catch {
        Throw "Error binding to LDAP on port $Port - $($_.Exception.Message)"
    }

    return $LDAPConnect
}

function Perform-LdapSearch {
    param (
        [System.DirectoryServices.Protocols.LdapConnection]$LDAPConnect,
        [string]$BaseDn,
        [string]$Filter = "(sn=Ge*)",
        #        [string]$Filter = "(telephoneNumber=13*)",
        #        [string]$Filter = "(objectClass=person)", # geht nicht, zu viele Ergebnisse
        [System.DirectoryServices.Protocols.SearchScope]$Scope = [System.DirectoryServices.Protocols.SearchScope]::Subtree,
        [array]$Attributes = $null
    )

    $ModelQuery = New-Object System.DirectoryServices.Protocols.SearchRequest -ArgumentList $BaseDn, $Filter, $Scope, $Attributes
    $ModelQuery.SizeLimit = 10  # Set a size limit to avoid exceeding server constraints

    Try {
        $ErrorActionPreference = 'Stop'
        $ModelRequest = $LDAPConnect.SendRequest($ModelQuery)
        $ErrorActionPreference = 'Continue'
    }
    Catch {
        Throw "Problem executing LDAP search - $($_.Exception.Message)"
    }

    return $ModelRequest
}

$hostname = Read-Host "Enter IP-Address of LDAP Server"
$username = 'uid=ldap,dc=web'
$basedn = "dc=web"
$password = Read-Host "Enter Password" -AsSecureString
$connection = Connect-LdapServer -HostName $hostname -UserName $username -Password $password -Port 389