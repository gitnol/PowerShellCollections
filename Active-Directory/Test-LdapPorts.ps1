function Test-LdapPorts {
    param(
        [string]$TargetIP              # Ziel-IP-Adresse
    )

    # Standardpfad zu nmap.exe
    $NmapPath = 'C:\Program Files (x86)\Nmap\nmap.exe'

    # Ports für LDAP und LDAPS
    $ldapPorts = @(389, 636)
    $results = @()

    foreach ($port in $ldapPorts) {
        Write-Host "Scanne Port $port an $TargetIP..."

        # Nmap Befehl ausführen
        $command = & $NmapPath -p $port $TargetIP
        if ($command -match "open") {
            $results += [PSCustomObject]@{
                TargetIP = $TargetIP
                Port     = $port
                Status   = 'Open'
            }
        }
        else {
            $results += [PSCustomObject]@{
                TargetIP = $TargetIP
                Port     = $port
                Status   = 'Closed'
            }
        }
    }

    # Ergebnisse anzeigen
    $results | Format-Table -AutoSize
}

function Test-LdapsBind {
    param(
        [string]$Server = "192.168.1.100",
        [int]$Port = 636,
        [pscredential]$Cred
    )

    try {
        $entry = New-Object System.DirectoryServices.DirectoryEntry(
            "LDAP://$Server`:$Port",
            $Cred.UserName,
            $Cred.GetNetworkCredential().Password,
            [System.DirectoryServices.AuthenticationTypes]::SecureSocketsLayer
        )

        # Versuch auf NativeObject → löst Bind aus
        $null = $entry.NativeObject

        [PSCustomObject]@{
            Server  = $Server
            Port    = $Port
            User    = $Cred.UserName
            Success = $true
            Message = "LDAPS-Bind erfolgreich"
        }
    }
    catch {
        [PSCustomObject]@{
            Server  = $Server
            Port    = $Port
            User    = $Cred.UserName
            Success = $false
            Message = $_.Exception.Message
        }
    }
}


$cred = Get-Credential
Test-LdapsBind -Server "192.168.1.100" -Cred $cred


# Beispielaufruf
Test-LdapPorts -TargetIP '192.168.1.100'
