<#
.SYNOPSIS
    Prueft einen TCP-Port mit einstellbarem Zeitlimit.

.DESCRIPTION
    Baut eine TCP-Verbindung auf und gibt nach dem Zeitlimit auf - per
    Vorgabe nach einer Sekunde.

    Test-NetConnection ist gruendlicher, braucht dafuer aber merklich laenger
    und laesst sich im Zeitlimit nicht steuern. Beim Durchprobieren vieler
    Ziele oder Ports macht das den Unterschied.

.NOTES
    Ein offener Port heisst nur, dass jemand annimmt - nicht, dass der
    erwartete Dienst antwortet.
#>

# Funktion, um eine Verbindung zu einem Port mit Timeout zu prüfen
function Test-Port {
    param (
        [string]$server,
        [int]$port,
        [int]$timeout = 1000  # Timeout in Millisekunden (1 Sekunde = 1000 ms)
    )
    
    try {
        $tcpClient = New-Object System.Net.Sockets.TcpClient
        $asyncConnect = $tcpClient.BeginConnect($server, $port, $null, $null)
        
        # Warte auf die Verbindung oder breche nach dem Timeout ab
        if ($asyncConnect.AsyncWaitHandle.WaitOne($timeout)) {
            $tcpClient.EndConnect($asyncConnect)
            $tcpClient.Close()
            return $true
        }
        else {
            # Schließe die Verbindung, falls der Timeout erreicht wurde
            $tcpClient.Close()
            return $false
        }
    }
    catch {
        return $false
    }
}

# Server und Ports definieren
$server = "myhost.mydomain.local"
$server = Read-Host -Prompt "IP or Host"citrix wagener volprecht... 

$ports = @(8888,80,443,9090, 9080,9081, 9091, 8080) # Weitere Ports hinzufügen

# Schleife zum Testen der Ports mit Timeout
foreach ($port in $ports) {
    if (Test-Port -server $server -port $port -timeout 1000) {
        Write-Output "Port $port ist offen auf $server"
    }
    else {
        Write-Output "Port $port ist geschlossen oder nicht erreichbar auf $server (Timeout erreicht)"
    }
}