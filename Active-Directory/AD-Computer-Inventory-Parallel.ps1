#Requires -Version 7.0
#-- #Requires -Modules ActiveDirectory

<#
.SYNOPSIS
    Inventarisiert AD-Computer parallel und aktualisiert Benutzer- sowie Hardware-Informationen im Description-Feld.
    
.DESCRIPTION
    Inventarisiert Computer im Active Directory parallel und speichert Benutzer- und Hardware-Informationen
    im Description-Feld für einfache Suche. Nutzt PowerShell 7 Parallelisierung für optimale Performance.
    Die Datensammlung erfolgt parallel, die Aktualisierung der AD-Objekte seriell.
    Die Benutzererkennung erfolgt über die eindeutige SID, um lokale von Domänenbenutzern zu unterscheiden.
    Änderungen werden in einer täglichen Logdatei protokolliert.
    
.PARAMETER WeeksBack
    Anzahl Wochen zurück für LastLogon-Filter (Standard: 6)
    
.PARAMETER MaxUsers
    Maximale Anzahl Benutzer im Description-Feld (Standard: 3)
    
.PARAMETER ThrottleLimit
    Anzahl parallele Threads für die Datensammlung (Standard: 30)
    
.PARAMETER TestMode
    Simulation ohne AD-Änderungen (Standard: $false)
    
.PARAMETER PingTimeout
    Ping-Timeout in Sekunden (Standard: 2)
    
.EXAMPLE
    .\AD-Computer-Inventory-Parallel.ps1 -WeeksBack 4 -ThrottleLimit 15
    
.EXAMPLE
    .\AD-Computer-Inventory-Parallel.ps1 -TestMode -Verbose
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [ValidateRange(1, 52)]
    [int]$WeeksBack = 6,
    
    [Parameter(Mandatory = $false)]
    [ValidateRange(1, 10)]
    [int]$MaxUsers = 3,
    
    [Parameter(Mandatory = $false)]
    [ValidateRange(1, 50)]
    [int]$ThrottleLimit = 30,
    
    [Parameter(Mandatory = $false)]
    [switch]$TestMode,
    
    [Parameter(Mandatory = $false)]
    [ValidateRange(1, 10)]
    [int]$PingTimeout = 2,
	
    [Parameter(Mandatory = $false)]
    [switch]$OutputOnlinePCsWithLoggedOnUsers
)

# Thread-sichere Collections für Statistiken
$script:Stats = [System.Collections.Concurrent.ConcurrentDictionary[string, int]]::new()
$script:Stats['Total'] = 0
$script:Stats['Online'] = 0
$script:Stats['Offline'] = 0
$script:Stats['NeedsUpdate'] = 0
$script:Stats['SucceededUpdates'] = 0
$script:Stats['FailedUpdates'] = 0
$script:Stats['CollectionFailed'] = 0
$script:Stats['NoChange'] = 0

# Logging-Funktionen
function Write-Log {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Message,
        
        [Parameter(Mandatory = $false)]
        [ValidateSet('Info', 'Success', 'Warning', 'Error')]
        [string]$Level = 'Info'
    )
    
    $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    $colors = @{
        'Info'    = 'White'
        'Success' = 'Green'
        'Warning' = 'Yellow' 
        'Error'   = 'Red'
    }
    
    Write-Host "[$timestamp] [$Level] $Message" -ForegroundColor $colors[$Level]
}

# User-Cache für Name-Auflösung (SID-basiert)
function Initialize-UserCache {
    Write-Log "Lade AD-Benutzer für SID-basierte Name-Auflösung..." -Level Info
    
    try {
        $users = Get-ADUser -Filter * -Properties Name, SID
        $userCache = @{}
        
        foreach ($user in $users) {
            # Sicherstellen, dass das Benutzerobjekt eine SID hat, bevor es dem Cache hinzugefügt wird
            if ($null -ne $user.SID) {
                # SID prüfen: falls Value existiert und mit S-1-5-21 beginnt, diesen nehmen
                $sidString = if ($user.SID.Value -like 'S-1-5-21*') { 
                    $user.SID.Value 
                }
                else { 
                    $user.SID 
                }

                # In Hashtable ablegen
                $userCache[$sidString] = $user.Name
            }
        }
        
        Write-Log "AD-Benutzer-Cache erstellt: $($userCache.Count) Benutzer" -Level Success
        return $userCache
    }
    catch {
        Write-Log "Fehler beim Laden des Benutzer-Cache: $($_.Exception.Message)" -Level Warning
        return @{}
    }
}

# Benutzer-Liste verwalten (FIFO mit Duplikat-Vermeidung)
function Update-UserList {
    param(
        [Parameter(Mandatory = $false)]
        [string]$CurrentDescription = '',
        
        [Parameter(Mandatory = $false)]
        [string]$NewUser = '',
        
        [Parameter(Mandatory = $true)]
        [int]$MaxUsers
    )
    
    # Aktuelle Benutzer und Seriennummer extrahieren
    $users = @()
    $serialNumber = ''
    
    if ($CurrentDescription -match '^(.+?)\s*#(.+)#$') {
        $userPart = $matches[1].Trim()
        $serialNumber = $matches[2].Trim()
        
        if ($userPart) {
            $users = $userPart -split ';' | ForEach-Object { $_.Trim() } | Where-Object { $_ }
        }
    }
    elseif ($CurrentDescription -and $CurrentDescription -notmatch '#.*#$') {
        # Legacy Format ohne Seriennummer - als einzelner User behandeln
        $users = @($CurrentDescription.Trim())
    }
    
    # Benutzer nur hinzufügen wenn tatsächlich ein neuer Benutzer übergeben wurde
    if ($NewUser -and $NewUser.Trim()) {
        $cleanNewUser = $NewUser.Trim()
        # Duplikat entfernen (case-insensitive)
        $users = $users | Where-Object { $_ -ne $cleanNewUser }
        
        # Neuen User an erste Stelle setzen
        $users = @($cleanNewUser) + $users
        
        # Auf MaxUsers begrenzen
        if ($users.Count -gt $MaxUsers) {
            $users = $users[0..($MaxUsers - 1)]
        }
    }
    
    return @{
        Users        = $users
        SerialNumber = $serialNumber
    }
}

# Description-String formatieren
function Format-Description {
    param(
        [Parameter(Mandatory = $false)]
        [string[]]$Users = @(),
        
        [Parameter(Mandatory = $false)]
        [string]$SerialNumber = ''
    )
    
    $userPart = if ($Users.Count -gt 0) { $Users -join ';' } else { '' }
    $serialPart = if ($SerialNumber) { "#$SerialNumber#" } else { '' }
    
    if ($userPart -and $serialPart) {
        return "$userPart $serialPart"
    }
    elseif ($userPart) {
        return $userPart
    }
    elseif ($serialPart) {
        return $serialPart
    }
    else {
        return ''
    }
}

# Hauptfunktion für Computer-Verarbeitung (Datensammlung)
function Invoke-ComputerInventory {
    param(
        [Parameter(Mandatory = $true)]
        [Object[]]$Computers,
        
        [Parameter(Mandatory = $true)]
        [int]$ThrottleLimit,
        
        [Parameter(Mandatory = $true)]
        [int]$MaxUsers,
        
        [Parameter(Mandatory = $true)]
        [bool]$TestMode,
        
        [Parameter(Mandatory = $true)]
        [int]$PingTimeout,
        
        [Parameter(Mandatory = $true)]
        [hashtable]$UserCache
    )
    
    Write-Log "Starte parallele Datensammlung von $($Computers.Count) Computern mit $ThrottleLimit Threads" -Level Info
    
    $startTime = Get-Date
    
    # Parallele Verarbeitung mit PowerShell 7
    $results = $Computers | ForEach-Object -ThrottleLimit $ThrottleLimit -Parallel {
        # Variablen in Parallel-Block importieren
        $computer = $_
        $maxUsers = $using:MaxUsers
        $pingTimeout = $using:PingTimeout
        $stats = $using:script:Stats
        $userCache = $using:UserCache
        
        # Lokale Funktionen für Parallel-Block
        function Update-UserListLocal {
            param($CurrentDescription = '', $NewUser = '', $MaxUsers)
            
            $users = @()
            $serialNumber = ''
            
            if ($CurrentDescription -match '^(.+?)\s*#(.+)#$') {
                $userPart = $matches[1].Trim()
                $serialNumber = $matches[2].Trim()
                
                if ($userPart) {
                    $users = $userPart -split ';' | ForEach-Object { $_.Trim() } | Where-Object { $_ }
                }
            }
            elseif ($CurrentDescription -and $CurrentDescription -notmatch '#.*#$') {
                $users = @($CurrentDescription.Trim())
            }
            
            if ($NewUser -and $NewUser.Trim()) {
                $cleanNewUser = $NewUser.Trim()
                $users = $users | Where-Object { $_ -ne $cleanNewUser }
                $users = @($cleanNewUser) + $users
                
                if ($users.Count -gt $MaxUsers) {
                    $users = $users[0..($MaxUsers - 1)]
                }
            }
            
            return @{
                Users        = $users
                SerialNumber = $serialNumber
            }
        }
        
        function Format-DescriptionLocal {
            param($Users = @(), $SerialNumber = '')
            
            $userPart = if ($Users.Count -gt 0) { $Users -join ';' } else { '' }
            $serialPart = if ($SerialNumber) { "#$SerialNumber#" } else { '' }
            
            if ($userPart -and $serialPart) {
                return "$userPart $serialPart"
            }
            elseif ($userPart) {
                return $userPart
            }
            elseif ($serialPart) {
                return $serialPart
            }
            else {
                return ''
            }
        }
        
        $result = [PSCustomObject]@{
            ComputerName      = $computer.Name
            DistinguishedName = $computer.DistinguishedName
            Status            = 'Processing'
            Online            = $false
            CurrentUser       = ''
            SerialNumber      = ''
            OldDescription    = $computer.Description
            NewDescription    = ''
            ShouldUpdate      = $false
            Error             = ''
        }
        
        try {
            # Online-Status prüfen
            $pingResult = Test-Connection -ComputerName $computer.Name -Count 1 -TimeoutSeconds $pingTimeout -Quiet -ErrorAction SilentlyContinue
            $result.Online = $pingResult
            
            if ($pingResult) {
                [void]$stats.TryUpdate('Online', $stats['Online'] + 1, $stats['Online'])
                
                # CIM-Session erstellen für bessere Performance
                $cimSession = $null
                try {
                    $cimSessionOption = New-CimSessionOption -Protocol WSMan
                    $cimSession = New-CimSession -ComputerName $computer.Name -SessionOption $cimSessionOption -OperationTimeoutSec 15 -ErrorAction SilentlyContinue
                    
                    if ($cimSession) {
                        # Aktuellen Benutzer über den Besitzer des explorer.exe Prozesses ermitteln
                        # Write-Host($computer.Name)
                        $explorerProcess = Get-CimInstance -CimSession $cimSession -ClassName Win32_Process -Filter "Name = 'explorer.exe'" | Select-Object -First 1
                        if ($explorerProcess) {
                            # SID des Prozess-Besitzers direkt abfragen. Dies umgeht das Double-Hop-Problem.
                            $ownerSidInfo = Invoke-CimMethod -InputObject $explorerProcess -MethodName GetOwnerSid
                            
                            # Prüfen, ob die Methode erfolgreich war und eine SID zurückgegeben wurde
                            if ($ownerSidInfo.ReturnValue -eq 0 -and $ownerSidInfo.Sid) {
                                $userSid = $ownerSidInfo.Sid
                                
                                # Vollen Namen aus dem SID-basierten Cache nachschlagen.
                                # Wenn die SID nicht gefunden wird, ist es ein lokaler Benutzer und wird ignoriert.
                                if ($userSid -and $userCache.ContainsKey($userSid)) {
                                    $result.CurrentUser = $userCache[$userSid]
                                }
                                # NEU: Wenn nicht im Cache, nach lokalem Benutzer suchen.
                                else {
                                    try {
                                        # Per CIM den lokalen Benutzer anhand der SID auf dem Zielcomputer suchen.
                                        $localUser = Get-CimInstance -CimSession $cimSession -ClassName Win32_UserAccount -Filter "SID = '$userSid'" -ErrorAction Stop
										
                                        if ($localUser) {
                                            # Benutzer im Format <Hostname>\<Username> formatieren.
                                            $result.CurrentUser = "$($computer.Name)\$($localUser.Name)"
                                        }
                                    }
                                    catch {
                                        # Fehler protokollieren, falls die Abfrage des lokalen Benutzers fehlschlägt.
                                        $result.Error = "Konnte lokalen Benutzer mit SID $userSid nicht abfragen. Fehler: $($_.Exception.Message)"
                                    }
                                }
                            }
                        }
                        
                        # BIOS-Seriennummer ermitteln
                        $bios = Get-CimInstance -CimSession $cimSession -ClassName Win32_BIOS -ErrorAction SilentlyContinue
                        if ($bios.SerialNumber) {
                            $result.SerialNumber = $bios.SerialNumber.Trim()
                        }
                    }
                }
                catch {
                    # Fehler bei CIM-Session wird nun protokolliert
                    $result.Error = "CIM/WMI Error: $($_.Exception.Message)"
                }
                finally {
                    if ($cimSession) {
                        Remove-CimSession -CimSession $cimSession -ErrorAction SilentlyContinue
                    }
                }
            }
            else {
                [void]$stats.TryUpdate('Offline', $stats['Offline'] + 1, $stats['Offline'])
            }
            
            # Nur fortfahren, wenn kein CIM-Fehler aufgetreten ist
            if (-not $result.Error) {
                # Description aktualisieren - nur wenn neue Daten verfügbar sind
                $userInfo = Update-UserListLocal -CurrentDescription $computer.Description -NewUser $result.CurrentUser -MaxUsers $maxUsers
                
                # Seriennummer-Logik: Nur überschreiben wenn neue Seriennummer nicht leer/null ist
                $finalSerial = if ($result.SerialNumber -and $result.SerialNumber.Trim()) { 
                    $result.SerialNumber.Trim() 
                }
                else { 
                    $userInfo.SerialNumber
                }
                
                $newDescription = Format-DescriptionLocal -Users $userInfo.Users -SerialNumber $finalSerial
                $result.NewDescription = $newDescription
                
                # Prüfen ob Update erforderlich ist ($null vs. '' sicherstellen)
                if (("$($computer.Description)" -ne "$($newDescription)") -and ($newDescription -ne '') -and ($null -ne $newDescription)) {
                    $result.ShouldUpdate = $true
                    $result.Status = 'NeedsUpdate'
                    [void]$stats.TryUpdate('NeedsUpdate', $stats['NeedsUpdate'] + 1, $stats['NeedsUpdate'])
                }
                else {
                    $result.Status = 'NoChange'
                    [void]$stats.TryUpdate('NoChange', $stats['NoChange'] + 1, $stats['NoChange'])
                }
            }
            else {
                # Wenn ein CIM-Fehler aufgetreten ist, markieren wir dies
                $result.Status = 'Error'
                [void]$stats.TryUpdate('CollectionFailed', $stats['CollectionFailed'] + 1, $stats['CollectionFailed'])
            }
            
        }
        catch {
            $result.Error = $_.Exception.Message
            $result.Status = 'Error'
            [void]$stats.TryUpdate('CollectionFailed', $stats['CollectionFailed'] + 1, $stats['CollectionFailed'])
        }
        
        return $result
    }
    
    $endTime = Get-Date
    $duration = $endTime - $startTime
    
    Write-Log "Parallele Datensammlung abgeschlossen in $($duration.TotalSeconds.ToString('F2')) Sekunden" -Level Success
    
    return $results
}

# Hauptscript
try {
    Write-Log "=== Active Directory Computer Inventory (PowerShell 7) ===" -Level Info
    Write-Log "Parameter: WeeksBack=$WeeksBack, MaxUsers=$MaxUsers, ThrottleLimit=$ThrottleLimit, TestMode=$TestMode" -Level Info
    
    # Logdatei-Konfiguration
    if (-not $TestMode) {
        $scriptPath = $PSScriptRoot
        $logDirectory = Join-Path -Path $scriptPath -ChildPath "logs"
        if (-not (Test-Path $logDirectory)) {
            New-Item -Path $logDirectory -ItemType Directory | Out-Null
        }
        $logDate = Get-Date -Format 'yyyy-MM-dd'
        $logFile = Join-Path -Path $logDirectory -ChildPath "AD-Inventory-Changes_$logDate.log"
    }
    
    # Benutzer-Cache initialisieren
    $userCache = Initialize-UserCache
    
    # LastLogon-Zeitpunkt berechnen
    $lastLogonDate = (Get-Date).AddDays( - ($WeeksBack * 7))
    $lastLogonFileTime = $lastLogonDate.ToFileTime()
    
    Write-Log "Suche Computer mit LastLogon seit: $($lastLogonDate.ToString('yyyy-MM-dd'))" -Level Info
    
    # Computer aus AD abrufen
    $computers = Get-ADComputer -Filter "Enabled -eq 'True' -and LastLogonTimeStamp -gt $lastLogonFileTime" -Properties Name, Description, LastLogonTimeStamp, DistinguishedName
    
    $script:Stats['Total'] = $computers.Count
    
    if ($computers.Count -eq 0) {
        Write-Log "Keine Computer gefunden, die den Kriterien entsprechen" -Level Warning
        return
    }
    
    Write-Log "Gefundene Computer: $($computers.Count)" -Level Success
    
    # Serialisierung, da ansonsten bei der Parallisierung Probleme mit dem AD-Objekt auftreten können
    # Nur die benötigten Eigenschaften extrahieren
    $computerData = $computers | Select-Object Name, Description, DistinguishedName

    # Inventarisierung (Datensammlung) durchführen
    $results = Invoke-ComputerInventory -Computers $computerData -ThrottleLimit $ThrottleLimit -MaxUsers $MaxUsers -TestMode $TestMode -PingTimeout $pingTimeout -UserCache $userCache
    
    # Serielle Aktualisierung der AD-Objekte
    # Das Ergebnis wird in @() eingeschlossen, um sicherzustellen, dass es immer ein Array ist.
    $computersToUpdate = @($results | Where-Object { $_.ShouldUpdate -and !$_.Error })
    
    if (-not $TestMode) {
        if ($computersToUpdate.Count -gt 0) {
            Write-Log "=== Starte serielle Aktualisierung für $($computersToUpdate.Count) Computer ===" -Level Info
            foreach ($item in $computersToUpdate) {
                try {
                    $null = Set-ADComputer -Identity $item.DistinguishedName -Description $item.NewDescription -ErrorAction Stop
                    $script:Stats['SucceededUpdates']++
                    Write-Verbose "Aktualisiert: $($item.ComputerName)"
                    
                    # Logeintrag in Datei schreiben
                    $logTimestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
                    $logMessage = "[$logTimestamp] [UPDATE] Computer: $($item.ComputerName) | Old: '$($item.OldDescription)' | New: '$($item.NewDescription)'"
                    $null = Add-Content -Path $logFile -Value $logMessage

                }
                catch {
                    $script:Stats['FailedUpdates']++
                    Write-Log "Fehler bei Aktualisierung von '$($item.ComputerName)': $($_.Exception.Message)" -Level Error
                }
            }
            Write-Log "Serielle Aktualisierung abgeschlossen." -Level Success
        }
    }
    else {
        if ($computersToUpdate.Count -gt 0) {
            Write-Log "TESTMODUS: $($computersToUpdate.Count) Computer würden aktualisiert werden." -Level Warning
        }
    }

    # Statistiken ausgeben
    Write-Log "=== Verarbeitungsstatistiken ===" -Level Info
    Write-Log "Computer gesamt: $($script:Stats['Total'])" -Level Info
    Write-Log "Online: $($script:Stats['Online'])" -Level Success
    Write-Log "Offline: $($script:Stats['Offline'])" -Level Warning
    Write-Log "Für Update identifiziert: $($script:Stats['NeedsUpdate'])" -Level Info
    Write-Log "Unverändert: $($script:Stats['NoChange'])" -Level Info
    if (-not $TestMode) {
        Write-Log "Erfolgreich aktualisiert: $($script:Stats['SucceededUpdates'])" -Level Success
        Write-Log "Fehler bei Aktualisierung: $($script:Stats['FailedUpdates'])" -Level Error
        if (Test-Path $logFile) {
            Write-Log "Änderungen protokolliert in: $logFile" -Level Info
        }
    }
    Write-Log "Fehler bei Datenerfassung: $($script:Stats['CollectionFailed'])" -Level Error
    
    # Detailergebnisse bei Bedarf
    if ($VerbosePreference -eq 'Continue' -or $TestMode) {
        Write-Log "=== Detailergebnisse (Änderungen & Fehler) ===" -Level Info
        
        $results | Where-Object { $_.ShouldUpdate -or $_.Error } | ForEach-Object {
            $status = if ($_.Error) { "FEHLER bei Sammlung: $($_.Error)" } elseif ($_.ShouldUpdate) { "Wird aktualisiert" } else { $_.Status }
            Write-Log "$($_.ComputerName): $status" -Level $(if ($_.Error) { 'Error' } else { 'Info' })
            
            if ($_.ShouldUpdate) {
                Write-Log "  Alt: '$($_.OldDescription)'" -Level Info
                Write-Log "  Neu: '$($_.NewDescription)'" -Level Info
            }
        }
    }
    
    if ($TestMode) {
        Write-Log "TESTMODUS: Keine tatsächlichen AD-Änderungen durchgeführt" -Level Warning
    }
	
    if ($OutputOnlinePCsWithLoggedOnUsers) {
        Write-Verbose 'foreach ($myresult in ($myresults | Where-Object { ($_.Online -eq $true) -and !$_.Error })) {Write-Verbose ($myresult.ComputerName + ":" + $myresult.CurrentUser) -Verbose}'
        Write-Verbose '$myresults | Where-Object { ($_.Online -eq $true) -and !$_.Error } | Select ComputerName,CurrentUser | Out-GridView -Title "Online Computers with loggedOn Users"'
        Write-Verbose '$myresults | Where-Object { ($_.Online -eq $true) -and !$_.Error } | Select ComputerName,CurrentUser,NewDescription | Out-GridView -Title "Online Computers with loggedOn Users" -PassThru | % {Invoke-Command -ComputerName $_.ComputerName -ScriptBlock {Stop-Computer -Force -WhatIf -Verbose}}'
    }
	
    return $results
	
}
catch {
    Write-Log "Kritischer Fehler im Hauptskript: $($_.Exception.Message)" -Level Error
    throw
}
finally {
    Write-Log "Script beendet: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -Level Info
}

