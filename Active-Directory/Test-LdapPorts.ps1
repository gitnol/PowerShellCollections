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

# Beispielaufruf
Test-LdapPorts -TargetIP '192.168.1.100'
