<#
.SYNOPSIS
Prüft den Online-Status von AD-Computern und führt optional einen Neustart oder eine SID-Prüfung durch.
.PARAMETER Filter
AD-Filter für 'Get-ADComputer'. Standard: Alle Windows-Systeme.
.PARAMETER Restart
Schalter, um alle gefundenen Online-Computer neu zu starten.
.PARAMETER CheckSID
Schalter, um bei allen gefundenen Online-Computern die Maschinen-SID zu prüfen und Duplikate zu finden.
(Standard: $true)
.PARAMETER ThrottleLimit
Anzahl der parallelen Threads für Ping-Test und Invoke-Command.
.EXAMPLE
.\DeinSkript.ps1
Sucht alle Windows-Systeme, prüft deren Online-Status und listet doppelte Maschinen-SIDs auf (Standardaktion).
.EXAMPLE
.\DeinSkript.ps1 -CheckSID:$false
Sucht alle Windows-Systeme und prüft nur den Online-Status (keine Aktion).
.EXAMPLE
.\DeinSkript.ps1 -Filter "OperatingSystem -like '*Server*' -and Name -notlike '*cx*'" -Restart
Sucht alle Server (außer 'cx'), prüft den Online-Status und startet die erreichbaren neu.
.EXAMPLE
.\DeinSkript.ps1 -Restart -WhatIf
Simuliert den Neustart-Vorgang, ohne ihn tatsächlich durchzuführen.
#>
[CmdletBinding(SupportsShouldProcess = $true)]
param (
    [string]$Filter = "OperatingSystem -like '*Windows*'",
    [switch]$Restart,
    [switch]$CheckSID = $true,
    [int]$ThrottleLimit = 30
)

# DNS-Cache leeren, um potenziell veraltete Einträge zu entfernen
$null = & ipconfig /flushdns

Write-Host "Suche Computer mit AD-Filter: $Filter"

# 1. Server-Erkennung
try {
    $ServerNames = Get-ADComputer -Filter $Filter -Properties OperatingSystem -ErrorAction Stop | Select-Object -ExpandProperty Name
}
catch {
    Write-Error "Fehler beim Abrufen der Computer aus dem AD: $($_.Exception.Message)"
    Write-Error "Stelle sicher, dass das ActiveDirectory-Modul installiert ist und du Berechtigungen hast."
    return
}

$OnlineServer = [System.Collections.Concurrent.ConcurrentBag[PSObject]]::new()

Write-Host "Prüfe Erreichbarkeit von $($ServerNames.Count) Computern (Throttle: $ThrottleLimit)..."

# 2. Parallelisierter Online-Check
$ServerNames | ForEach-Object -Parallel {
    $Name = $_
    # Gemäß Präferenz: $using-Variablen lokal zuweisen
    $OnlineServerBag = $using:OnlineServer

    if (Test-Connection -ComputerName $Name -Count 1 -TimeoutSeconds 1 -Quiet) {
        try {
            # Nur A-Records (IPv4) auflösen
            $IP = (Resolve-DnsName -Name $Name -Type A -ErrorAction Stop | Select-Object -First 1 -ExpandProperty IPAddress)
        }
        catch {
            $IP = "unbekannt"
        }

        $OnlineServerBag.Add([pscustomobject]@{
            Server    = $Name
            IPAddress = $IP
            Timestamp = (Get-Date)
        })
        Write-Host "$Name ($IP) ist online."
    }
    else {
        Write-Host "$Name ist offline."
    }
} -ThrottleLimit $ThrottleLimit

# Sortierte Liste der Online-Server
$OnlineServerList = $OnlineServer | Sort-Object Server
Write-Host "--- $($OnlineServerList.Count) von $($ServerNames.Count) Computern sind online ---"
$OnlineServerList | Format-Table

# --- Aktionen ---

# 3. Aktion: Neustart (wenn -Restart angegeben wurde)
if ($Restart) {
    Write-Host "Aktion: Neustart wird für $($OnlineServerList.Count) Computer eingeleitet..." -ForegroundColor Yellow
    
    # $PSSC-Variable wird für -WhatIf benötigt
    if ($PSCmdlet.ShouldProcess("Alle $($OnlineServerList.Count) Online-Computer", "Neustart")) {
        Invoke-Command -ComputerName $OnlineServerList.Server -ScriptBlock {
            # -WhatIf wird von [CmdletBinding()] automatisch geerbt
            Restart-Computer -Force
        } -ThrottleLimit $ThrottleLimit
    }
}

# 4. Aktion: SID-Prüfung (wenn -CheckSID angegeben wurde)
if ($CheckSID -and $OnlineServerList.Count -gt 0) {
    Write-Host "Aktion: Maschinen-SID wird auf $($OnlineServerList.Count) Computern geprüft..." -ForegroundColor Yellow

    # --- KORRIGIERTER SCRIPTBLOCK ---
    $scriptblock = {
        function Get-MachineSID {
            <#
            .SYNOPSIS
                Gibt die Maschinen-SID (AccountDomainSID) des lokalen Rechners zurück.
            #>
            [CmdletBinding()]
            param ()
            
            try {
                # Robuste Methode: Suche den ersten lokalen Benutzer, dessen SID mit S-1-5-21- beginnt.
                # Dies filtert AAD/MSA-Konten (S-1-12-...) und andere Built-in-Typen heraus.
                $localUser = Get-LocalUser | Where-Object { $_.SID.Value -like 'S-1-5-21-*' } | Select-Object -First 1

                if (-not $localUser) {
                    throw "Keinen lokalen Benutzer mit einer 'S-1-5-21-...' SID gefunden."
                }
                
                $localUserSidValue = $localUser.SID.Value

                # Maschinen-SID durch Entfernen des letzten RID-Teils
                $parts = $localUserSidValue -split "-"
                $machineSid = ($parts[0..($parts.Length-2)] -join "-")
                
                [PSCustomObject]@{
                    ComputerName = $env:COMPUTERNAME
                    MachineSID   = $machineSid
                }
            }
            catch {
                Write-Error "Fehler beim Auslesen der Maschinen-SID auf $env:COMPUTERNAME: $_"
                [PSCustomObject]@{
                    ComputerName = $env:COMPUTERNAME
                    MachineSID   = "FEHLER: $($_.Exception.Message)"
                }
            }
        }
        
        # Funktion aufrufen (AsObject ist nicht mehr nötig, da die Funktion nur noch ein Objekt zurückgibt)
        Get-MachineSID
    }

    $sidResults = Invoke-Command -ComputerName $OnlineServerList.Server -ScriptBlock $scriptblock -ThrottleLimit $ThrottleLimit -ErrorAction SilentlyContinue

    # Ergebnisse gruppieren und ausgeben
    Write-Host "--- Ergebnisse der SID-Prüfung ---" -ForegroundColor Green
    $groupedSIDs = $sidResults | Group-Object MachineSID | Sort-Object Count -Descending

    $groupedSIDs | ForEach-Object {
        [PSCustomObject]@{
            MachineSID = $_.Name
            Count      = $_.Count
            Computers  = ($_.Group.ComputerName -join ', ')
        }
    } | Format-Table -AutoSize
}
elseif ($CheckSID) {
    Write-Host "Aktion: SID-Prüfung übersprungen, da keine Computer online sind." -ForegroundColor Yellow
}

Write-Host "Skript beendet."