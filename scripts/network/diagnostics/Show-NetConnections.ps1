function Show-NetConnections {
    <#
.SYNOPSIS
Zeigt aktive TCP/UDP-Verbindungen inkl. Prozessinformationen, ähnlich netstat -anob.
#>
    [CmdletBinding(DefaultParameterSetName = 'All')]
    param(
        [Parameter(ParameterSetName = 'TCP')]
        [switch]$Tcp,

        [Parameter(ParameterSetName = 'UDP')]
        [switch]$Udp,

        [Parameter(ParameterSetName = 'All')]
        [switch]$All,

        [string]$LocalAddress = '*',
        [string]$RemoteAddress = '*',
        [string]$LocalPort = '*',
        [string]$RemotePort = '*',
        [string]$State = '*',
        [string]$ProcessId = '*',

        [switch]$ResolveHostnames
    )

    function Resolve-Hostname {
        param([string]$IP)
        if ([string]::IsNullOrWhiteSpace($IP) -or $IP -eq '0.0.0.0' -or $IP -eq '::') {
            return $IP
        }
        try {
            [System.Net.Dns]::GetHostEntry($IP).HostName
        }
        catch {
            $IP
        }
    }

    $connections = @()

    if ($Tcp -or $All) {
        $connections += Get-NetTCPConnection -ErrorAction SilentlyContinue | ForEach-Object {
            [PSCustomObject]@{
                Protocol      = 'TCP'
                LocalAddress  = $_.LocalAddress
                LocalPort     = $_.LocalPort
                RemoteAddress = $_.RemoteAddress
                RemotePort    = $_.RemotePort
                State         = $_.State
                ProcessId     = $_.OwningProcess
                ProcessName   = (Get-Process -Id $_.OwningProcess -ErrorAction SilentlyContinue).ProcessName
            }
        }
    }

    if ($Udp -or $All) {
        $connections += Get-NetUDPEndpoint -ErrorAction SilentlyContinue | ForEach-Object {
            [PSCustomObject]@{
                Protocol      = 'UDP'
                LocalAddress  = $_.LocalAddress
                LocalPort     = $_.LocalPort
                RemoteAddress = ''
                RemotePort    = ''
                State         = ''
                ProcessId     = $_.OwningProcess
                ProcessName   = (Get-Process -Id $_.OwningProcess -ErrorAction SilentlyContinue).ProcessName
            }
        }
    }

    # Filter mit Wildcards
    $filtered = $connections | Where-Object {
        ($_.LocalAddress -like $LocalAddress) -and
        ($_.RemoteAddress -like $RemoteAddress) -and
        ($_.LocalPort -like $LocalPort) -and
        ($_.RemotePort -like $RemotePort) -and
        ($_.State -like $State) -and
        ($_.ProcessId.ToString() -like $ProcessId)
    }

    # Hostnamen nur für gefilterte Ergebnisse auflösen
    if ($ResolveHostnames) {
        $filtered = $filtered | ForEach-Object {
            $_.LocalAddress = Resolve-Hostname $_.LocalAddress
            if ($_.RemoteAddress) { $_.RemoteAddress = Resolve-Hostname $_.RemoteAddress }
            $_
        }
    }

    return $filtered | Sort-Object Protocol, LocalPort
}


# Alle Verbindungen (TCP + UDP)
Show-NetConnections -All

# Nur TCP mit Remoteadresse, die "10.10" enthält
Show-NetConnections -Tcp -RemoteAddress '*10.10*'

# Nur UDP-Verbindungen, die Port 53 nutzen
Show-NetConnections -Udp -LocalPort 53

# Mit Hostname-Auflösung (langsamer, aber wie netstat -f)
Show-NetConnections -Tcp -ResolveHostnames

# Nach Prozess-ID 1234 filtern
Show-NetConnections -All -ProcessId 1234

