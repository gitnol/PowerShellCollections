# DHCP Leases aus allen autorisierten DHCP-Servern der Domäne abfragen und MAC-Adressen in verschiedenen Formaten ausgeben

# Funktion für MAC-Formatierungen
function Format-MAC {
    param($mac)
    $clean = ($mac -replace "-", "").ToUpper()
    if ($clean.Length -ge 12) {
        [PSCustomObject]@{
            Dash   = $clean.Substring(0, 2) + "-" + $clean.Substring(2, 2) + "-" + $clean.Substring(4, 2) + "-" + $clean.Substring(6, 2) + "-" + $clean.Substring(8, 2) + "-" + $clean.Substring(10, 2)
            Colon  = $clean.Substring(0, 2) + ":" + $clean.Substring(2, 2) + ":" + $clean.Substring(4, 2) + ":" + $clean.Substring(6, 2) + ":" + $clean.Substring(8, 2) + ":" + $clean.Substring(10, 2)
            Plain  = $clean
            Hyphen = $clean.Substring(0, 6) + "-" + $clean.Substring(6, 6)
            Dot    = $clean.Substring(0, 4) + "." + $clean.Substring(4, 4) + "." + $clean.Substring(8, 4)
        }
    }
    else {
        [PSCustomObject]@{
            Dash   = ''
            Colon  = ''
            Plain  = $clean
            Hyphen = ''
            Dot    = ''
        }
    }
}


# Alle autorisierten DHCP-Server der Domäne abrufen
$dhcpServers = (Get-DhcpServerInDC).DnsName

# Leases sammeln
$result = foreach ($server in $dhcpServers) {
    foreach ($scope in Get-DhcpServerv4Scope -ComputerName $server) {
        foreach ($lease in Get-DhcpServerv4Lease -ComputerName $server -ScopeId $scope.ScopeId) {
            $macFormats = Format-MAC $lease.ClientID
            [PSCustomObject]@{
                Server         = $server
                ScopeId        = $scope.ScopeId
                IPAddress      = $lease.IPAddress
                LastOctet      = [int]([string]$lease.IPAddress).Split('.')[-1]
                HostName       = $lease.HostName
                AddressState   = $lease.AddressState
                LeaseExpiry    = $lease.LeaseExpiryTime
                ExpiresInHours = [math]::Round(($lease.LeaseExpiryTime - (Get-Date)).TotalHours, 2)
                ClientID       = $lease.ClientID
                MAC_Dash       = $macFormats.Dash
                MAC_Colon      = $macFormats.Colon
                MAC_Plain      = $macFormats.Plain
                MAC_Hyphen     = $macFormats.Hyphen
                MAC_Dot        = $macFormats.Dot
            }
        }
    }
}

# Ergebnis anzeigen
$result | Out-GridView

# PS5 Kompatibilität
if ((-not $PSScriptRoot) -or ($PSVersionTable.PSVersion.Major -le 5)) { Read-Host "Press Enter" }
