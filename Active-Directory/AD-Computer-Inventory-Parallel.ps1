#Requires -Version 7.0
#Requires -Modules ActiveDirectory

<#
.SYNOPSIS
    Active Directory Computer Inventory mit automatischer Aktualisierung (PowerShell 7)
    
.DESCRIPTION
    Inventarisiert Computer im Active Directory parallel und speichert Benutzer- und Hardware-Informationen
    im Description-Feld für einfache Suche. Nutzt PowerShell 7 Parallelisierung für optimale Performance.
    
.PARAMETER WeeksBack
    Anzahl Wochen zurück für LastLogon-Filter (Standard: 6)
    
.PARAMETER MaxUsers
    Maximale Anzahl Benutzer im Description-Feld (Standard: 3)
    
.PARAMETER ThrottleLimit
    Anzahl parallele Threads (Standard: 10)
    
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
    [int]$ThrottleLimit = 10,
    
    [Parameter(Mandatory = $false)]
    [switch]$TestMode,
    
    [Parameter(Mandatory = $false)]
    [ValidateRange(1, 10)]
    [int]$PingTimeout = 2
)

# Thread-sichere Collections für Statistiken
$script:Stats = [System.Collections.Concurrent.ConcurrentDictionary[string, int]]::new()
$script:Stats['Total'] = 0
$script:Stats['Online'] = 0
$script:Stats['Offline'] = 0
$script:Stats['Updated'] = 0
$script:Stats['Failed'] = 0
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

# User-Cache für Name-Auflösung
function Initialize-UserCache {
    Write-Log "Lade AD-Benutzer für Name-Auflösung..." -Level Info
    
    try {
        $users = Get-ADUser -Filter * -Properties Name, SamAccountName
        $userCache = @{}
        
        foreach ($user in $users) {
            $userCache[$user.SamAccountName] = $user.Name
        }
        
        Write-Log "AD-Benutzer-Cache erstellt: $($userCache.Count) Benutzer" -Level Success
        return $userCache
    } catch {
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
    } elseif ($CurrentDescription -and $CurrentDescription -notmatch '#.*#$') {
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
            $users = $users[0..($MaxUsers-1)]
        }
    }
    
    return @{
        Users = $users
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
    } elseif ($userPart) {
        return $userPart
    } elseif ($serialPart) {
        return $serialPart
    } else {
        return ''
    }
}

# Hauptfunktion für Computer-Verarbeitung
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
    
    Write-Log "Starte parallele Verarbeitung von $($Computers.Count) Computern mit $ThrottleLimit Threads" -Level Info
    
    $startTime = Get-Date
    
    # Parallele Verarbeitung mit PowerShell 7
    $results = $Computers | ForEach-Object -ThrottleLimit $ThrottleLimit -Parallel {
        # Variablen in Parallel-Block importieren
        $computer = $_
        $maxUsers = $using:MaxUsers
        $testMode = $using:TestMode
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
            } elseif ($CurrentDescription -and $CurrentDescription -notmatch '#.*#$') {
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
                    $users = $users[0..($MaxUsers-1)]
                }
            }
            
            return @{
                Users = $users
                SerialNumber = $serialNumber
            }
        }
        
        function Format-DescriptionLocal {
            param($Users = @(), $SerialNumber = '')
            
            $userPart = if ($Users.Count -gt 0) { $Users -join ';' } else { '' }
            $serialPart = if ($SerialNumber) { "#$SerialNumber#" } else { '' }
            
            if ($userPart -and $serialPart) {
                return "$userPart $serialPart"
            } elseif ($userPart) {
                return $userPart
            } elseif ($serialPart) {
                return $serialPart
            } else {
                return ''
            }
        }
        
        $result = @{
            ComputerName = $computer.Name
            Status = 'Processing'
            Online = $false
            CurrentUser = ''
            SerialNumber = ''
            OldDescription = $computer.Description
            NewDescription = ''
            Updated = $false
            Error = ''
        }
        
        try {
            # Online-Status prüfen
            $pingResult = Test-Connection -ComputerName $computer.Name -Count 1 -TimeoutSeconds $pingTimeout -Quiet -ErrorAction SilentlyContinue
            $result.Online = $pingResult
            
            if ($pingResult) {
                $stats['Online'] = $stats['Online'] + 1
                
                # CIM-Session erstellen für bessere Performance
                $cimSession = $null
                try {
                    $cimSessionOption = New-CimSessionOption -Protocol WSMan
                    $cimSession = New-CimSession -ComputerName $computer.Name -SessionOption $cimSessionOption -OperationTimeoutSec 15 -ErrorAction SilentlyContinue
                    
                    if ($cimSession) {
                        # Aktueller Benutzer ermitteln
                        try {
                            $computerSystem = Get-CimInstance -CimSession $cimSession -ClassName Win32_ComputerSystem -ErrorAction SilentlyContinue
                            if ($computerSystem.UserName) {
                                $user = $computerSystem.UserName
                                if ($user.Contains('\')) {
                                    $result.CurrentUser = $user.Split('\')[1]
                                } else {
                                    $result.CurrentUser = $user
                                }
                            }
                        } catch {
                            # Benutzer konnte nicht ermittelt werden
                        }
                        
                        # BIOS-Seriennummer ermitteln
                        try {
                            $bios = Get-CimInstance -CimSession $cimSession -ClassName Win32_BIOS -ErrorAction SilentlyContinue
                            if ($bios.SerialNumber) {
                                $result.SerialNumber = $bios.SerialNumber.Trim()
                            }
                        } catch {
                            # Seriennummer konnte nicht ermittelt werden
                        }
                    }
                } catch {
                    # CIM-Session konnte nicht erstellt werden - Fallback ohne Session
                    try {
                        $computerSystem = Get-CimInstance -ComputerName $computer.Name -ClassName Win32_ComputerSystem -OperationTimeoutSec 10 -ErrorAction SilentlyContinue
                        if ($computerSystem.UserName) {
                            $user = $computerSystem.UserName
                            if ($user.Contains('\')) {
                                $result.CurrentUser = $user.Split('\')[1]
                            } else {
                                $result.CurrentUser = $user
                            }
                        }
                        
                        $bios = Get-CimInstance -ComputerName $computer.Name -ClassName Win32_BIOS -OperationTimeoutSec 10 -ErrorAction SilentlyContinue
                        if ($bios.SerialNumber) {
                            $result.SerialNumber = $bios.SerialNumber.Trim()
                        }
                    } catch {
                        # Auch Fallback fehlgeschlagen
                    }
                } finally {
                    # CIM-Session aufräumen
                    if ($cimSession) {
                        try {
                            Remove-CimSession -CimSession $cimSession -ErrorAction SilentlyContinue
                        } catch {
                            # Session-Cleanup fehlgeschlagen
                        }
                    }
                }
            } else {
                $stats['Offline'] = $stats['Offline'] + 1
            }
            
            # Description aktualisieren - nur wenn neue Daten verfügbar sind
            $userInfo = if ($result.CurrentUser) {
                # Nur aktualisieren wenn tatsächlich ein Benutzer angemeldet ist
                Update-UserListLocal -CurrentDescription $computer.Description -NewUser $result.CurrentUser -MaxUsers $maxUsers
            } else {
                # Kein Benutzer angemeldet - bestehende Struktur beibehalten
                Update-UserListLocal -CurrentDescription $computer.Description -MaxUsers $maxUsers
            }
            
            # Seriennummer-Logik: Nur überschreiben wenn neue Seriennummer nicht leer/null ist
            $finalSerial = if ($result.SerialNumber -and $result.SerialNumber.Trim()) { 
                $result.SerialNumber.Trim() 
            } else { 
                $userInfo.SerialNumber
            }
            
            $newDescription = Format-DescriptionLocal -Users $userInfo.Users -SerialNumber $finalSerial
            $result.NewDescription = $newDescription
            
            # Prüfen ob Update erforderlich ist
            if ($computer.Description -ne $newDescription) {
                if (-not $testMode) {
                    try {
                        Set-ADComputer -Identity $computer.DistinguishedName -Description $newDescription -ErrorAction Stop
                        $result.Updated = $true
                        $result.Status = 'Updated'
                        $stats['Updated'] = $stats['Updated'] + 1
                    } catch {
                        $result.Error = $_.Exception.Message
                        $result.Status = 'Failed'
                        $stats['Failed'] = $stats['Failed'] + 1
                    }
                } else {
                    $result.Updated = $true
                    $result.Status = 'TestMode-WouldUpdate'
                    $stats['Updated'] = $stats['Updated'] + 1
                }
            } else {
                $result.Status = 'NoChange'
                $stats['NoChange'] = $stats['NoChange'] + 1
            }
            
        } catch {
            $result.Error = $_.Exception.Message
            $result.Status = 'Error'
            $stats['Failed'] = $stats['Failed'] + 1
        }
        
        return $result
    }
    
    $endTime = Get-Date
    $duration = $endTime - $startTime
    
    Write-Log "Parallele Verarbeitung abgeschlossen in $($duration.TotalSeconds.ToString('F2')) Sekunden" -Level Success
    
    return $results
}

# Hauptscript
try {
    Write-Log "=== Active Directory Computer Inventory (PowerShell 7) ===" -Level Info
    Write-Log "Parameter: WeeksBack=$WeeksBack, MaxUsers=$MaxUsers, ThrottleLimit=$ThrottleLimit, TestMode=$TestMode" -Level Info
    
    # Benutzer-Cache initialisieren
    $userCache = Initialize-UserCache
    
    # LastLogon-Zeitpunkt berechnen
    $lastLogonDate = (Get-Date).AddDays(-($WeeksBack * 7))
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
    
    # Inventarisierung durchführen
    $results = Invoke-ComputerInventory -Computers $computers -ThrottleLimit $ThrottleLimit -MaxUsers $MaxUsers -TestMode $TestMode -PingTimeout $PingTimeout -UserCache $userCache
    
    # Statistiken ausgeben
    Write-Log "=== Verarbeitungsstatistiken ===" -Level Info
    Write-Log "Computer gesamt: $($script:Stats['Total'])" -Level Info
    Write-Log "Online: $($script:Stats['Online'])" -Level Success
    Write-Log "Offline: $($script:Stats['Offline'])" -Level Warning
    Write-Log "Aktualisiert: $($script:Stats['Updated'])" -Level Success
    Write-Log "Unverändert: $($script:Stats['NoChange'])" -Level Info
    Write-Log "Fehlgeschlagen: $($script:Stats['Failed'])" -Level Error
    
    # Detailergebnisse bei Bedarf
    if ($VerbosePreference -eq 'Continue' -or $TestMode) {
        Write-Log "=== Detailergebnisse ===" -Level Info
        
        $results | Where-Object { $_.Updated -or $_.Error } | ForEach-Object {
            $status = if ($_.Error) { "ERROR: $($_.Error)" } else { $_.Status }
            Write-Log "$($_.ComputerName): $status" -Level $(if ($_.Error) { 'Error' } else { 'Info' })
            
            if ($_.Updated) {
                # Benutzer für Anzeige in Anzeigenamen konvertieren
                $oldUsers = @()
                $newUsers = @()
                
                # Alte Description parsen für Anzeige
                if ($_.OldDescription -match '^(.+?)\s*#(.+)#$') {
                    $oldUserPart = $matches[1].Trim()
                    if ($oldUserPart) {
                        $oldSamAccounts = $oldUserPart -split ';' | ForEach-Object { $_.Trim() } | Where-Object { $_ }
                        foreach ($samAccount in $oldSamAccounts) {
                            if ($userCache.ContainsKey($samAccount)) {
                                $oldUsers += $userCache[$samAccount]
                            } else {
                                $oldUsers += $samAccount
                            }
                        }
                    }
                }
                
                # Neue Description parsen für Anzeige
                if ($_.NewDescription -match '^(.+?)\s*#(.+)#$') {
                    $newUserPart = $matches[1].Trim()
                    $serialPart = $matches[2].Trim()
                    if ($newUserPart) {
                        $newSamAccounts = $newUserPart -split ';' | ForEach-Object { $_.Trim() } | Where-Object { $_ }
                        foreach ($samAccount in $newSamAccounts) {
                            if ($userCache.ContainsKey($samAccount)) {
                                $newUsers += $userCache[$samAccount]
                            } else {
                                $newUsers += $samAccount
                            }
                        }
                    }
                    $displayNewDescription = if ($newUsers.Count -gt 0) { 
                        ($newUsers -join ';') + " #$serialPart#" 
                    } else { 
                        "#$serialPart#" 
                    }
                } else {
                    $displayNewDescription = $_.NewDescription
                }
                
                $displayOldDescription = if ($oldUsers.Count -gt 0) { 
                    if ($_.OldDescription -match '#(.+)#$') {
                        ($oldUsers -join ';') + " #$($matches[1])#"
                    } else {
                        $oldUsers -join ';'
                    }
                } else { 
                    $_.OldDescription 
                }
                
                Write-Log "  Alt: '$displayOldDescription'" -Level Info
                Write-Log "  Neu: '$displayNewDescription'" -Level Info
            }
        }
    }
    
    # Suchbeispiele ausgeben
    Write-Log "=== Suchbeispiele nach Script-Ausführung ===" -Level Info
    Write-Log "Nach Benutzer suchen:" -Level Info
    Write-Log 'Get-ADComputer -Filter "Description -like ""*Mustermann*"""' -Level Info
    Write-Log "Nach Seriennummer suchen:" -Level Info  
    Write-Log 'Get-ADComputer -Filter "Description -like ""*#5TS052KL#*"""' -Level Info
    Write-Log "Kombinierte Suche:" -Level Info
    Write-Log 'Get-ADComputer -Filter "Description -like ""*Mustermann*"" -and Description -like ""*#5TS052KL#*"""' -Level Info
    
    if ($TestMode) {
        Write-Log "TESTMODUS: Keine tatsächlichen AD-Änderungen durchgeführt" -Level Warning
    }
    
} catch {
    Write-Log "Kritischer Fehler: $($_.Exception.Message)" -Level Error
    throw
} finally {
    Write-Log "Script beendet: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -Level Info
}