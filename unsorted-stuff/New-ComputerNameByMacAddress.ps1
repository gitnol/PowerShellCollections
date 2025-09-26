function Get-MyComputerName {
    <#
    .SYNOPSIS
    Ermittelt AABBCC aus PermanentAddress (alle Trennzeichen entfernt).
    Suffix "-M" wenn ein WLAN-Adapter gefunden wird, sonst "-D".
    Setzt MYCOMPUTERNAME in aktueller Session und, falls Adminrechte vorhanden, systemweit.
    
    .DESCRIPTION
    Diese Funktion generiert einen Computernamen basierend auf der letzten 6 Zeichen der MAC-Adresse
    mit einem Suffix (-M für WLAN, -D für Ethernet/Desktop).
    
    .EXAMPLE
    Get-MyComputerName
    Generiert den Computernamen und setzt die Umgebungsvariable
    
    .OUTPUTS
    PSCustomObject mit Details zum generierten Namen
    #>
    
    [CmdletBinding()]
    param()
    
    try {
        Write-Verbose "Starte Ermittlung der Netzwerkadapter..." -Verbose
        
        # CIM-Adapter holen (MSFT_NetAdapter bevorzugt)
        $adapters = $null
        try {
            $adapters = Get-CimInstance -Namespace root/StandardCimv2 -ClassName MSFT_NetAdapter -ErrorAction Stop
            Write-Verbose "MSFT_NetAdapter erfolgreich abgerufen" -Verbose
        }
        catch {
            Write-Verbose "MSFT_NetAdapter nicht verfügbar, verwende Win32_NetworkAdapter Fallback" -Verbose
            try {
                $adapters = Get-CimInstance -ClassName Win32_NetworkAdapter -ErrorAction Stop
            }
            catch {
                throw "Keine Netzwerkadapter-Informationen verfügbar: $($_.Exception.Message)"
            }
        }
        
        if (-not $adapters) {
            throw 'Keine Netzwerkadapter gefunden.'
        }
        
        Write-Verbose "Anzahl gefundener Adapter: $($adapters.Count)" -Verbose
        
        # Erste gültige MAC-Adresse finden (nicht 00:00:00:00:00:00 oder leer)
        $validAdapters = $adapters | Where-Object { 
            $_.PermanentAddress -and 
            ($_.PermanentAddress -notmatch '^(00[:\-\.\s]?){5}00$') -and
            ($_.PermanentAddress -notmatch '^[:\-\.\s]*$') -and
            ($_.PermanentAddress.Length -ge 12)
        }
        
        $macRaw = $validAdapters | Select-Object -First 1 -ExpandProperty PermanentAddress
        
        if (-not $macRaw) {
            throw 'Keine gültige MAC-Adresse gefunden. Alle Adapter haben ungültige oder leere PermanentAddress-Werte.'
        }
        
        Write-Verbose "Verwendete MAC-Adresse (raw): $macRaw" -Verbose
        
        # Normalisieren: Trennzeichen entfernen, Großbuchstaben, letzten 6 Zeichen (AABBCC)
        $macClean = ($macRaw -replace '[:\-\.\s]', '').ToUpper()
        
        if ($macClean.Length -lt 6) { 
            throw "PermanentAddress-String zu kurz nach Normalisierung: '$macClean' (Länge: $($macClean.Length))"
        }
        
        $short = $macClean.Substring($macClean.Length - 6)
        Write-Verbose "Kurze MAC (letzten 6 Zeichen): $short" -Verbose
        
        # WLAN-Prüfung (erweiterte Stichwortliste)
        $wlanPattern = 'WLAN|Wi-?Fi|Wireless|Drahtlos|802\.11|WiFi|Bluetooth.*WLAN|Intel.*Wireless|Qualcomm.*Wireless|Realtek.*Wireless|Broadcom.*Wireless'
        
        $wlanAdapters = $adapters | Where-Object {
            ($_.InterfaceDescription -and ($_.InterfaceDescription -match $wlanPattern)) -or
            ($_.Name -and ($_.Name -match $wlanPattern)) -or
            ($_.Description -and ($_.Description -match $wlanPattern))
        }
        
        $isWlan = ($wlanAdapters | Measure-Object).Count -gt 0
        
        if ($isWlan) {
            Write-Verbose "WLAN-Adapter erkannt: $($wlanAdapters[0].InterfaceDescription)" -Verbose
        }
        else {
            Write-Verbose "Kein WLAN-Adapter erkannt - verwende Desktop-Suffix" -Verbose
        }
        
        $suffix = if ($isWlan) { 'M' } else { 'D' }
        $computerName = "$short-$suffix"
        
        Write-Verbose "Generierter Computername: $computerName" -Verbose
        
        # Session-Umgebungsvariable setzen
        $env:MYCOMPUTERNAME = $computerName
        Write-Verbose "MYCOMPUTERNAME in aktueller Session gesetzt: $computerName" -Verbose
        
        # Überprüfung der Session-Variable
        if ($env:MYCOMPUTERNAME -ne $computerName) {
            Write-Warning "Session-Umgebungsvariable konnte nicht korrekt gesetzt werden!"
        }
        
        # Admin-Prüfung für systemweite Umgebungsvariable
        $currentPrincipal = [Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()
        $isAdmin = $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
        
        $systemWideSet = $false
        if ($isAdmin) {
            try {
                [System.Environment]::SetEnvironmentVariable('MYCOMPUTERNAME', $computerName, [System.EnvironmentVariableTarget]::Machine)
                Write-Verbose "MYCOMPUTERNAME systemweit gesetzt (Registry)" -Verbose
                
                # Überprüfung der systemweiten Variable
                $systemValue = [System.Environment]::GetEnvironmentVariable('MYCOMPUTERNAME', [System.EnvironmentVariableTarget]::Machine)
                if ($systemValue -eq $computerName) {
                    $systemWideSet = $true
                    Write-Verbose "Systemweite Umgebungsvariable erfolgreich verifiziert" -Verbose
                }
                else {
                    Write-Warning "Systemweite Umgebungsvariable konnte nicht verifiziert werden. Erwartet: '$computerName', Gefunden: '$systemValue'"
                }
            }
            catch {
                Write-Warning "Fehler beim Setzen der systemweiten Umgebungsvariable: $($_.Exception.Message)"
            }
        }
        else {
            Write-Verbose "Keine Administratorrechte: MYCOMPUTERNAME nur in aktueller Session gesetzt." -Verbose
        }
        
        # Benutzer-Umgebungsvariable als zusätzliche Option setzen
        try {
            [System.Environment]::SetEnvironmentVariable('MYCOMPUTERNAME', $computerName, [System.EnvironmentVariableTarget]::User)
            $userValue = [System.Environment]::GetEnvironmentVariable('MYCOMPUTERNAME', [System.EnvironmentVariableTarget]::User)
            $userSet = ($userValue -eq $computerName)
            if ($userSet) {
                Write-Verbose "MYCOMPUTERNAME in Benutzer-Umgebung gesetzt" -Verbose
            }
        }
        catch {
            Write-Warning "Fehler beim Setzen der Benutzer-Umgebungsvariable: $($_.Exception.Message)"
            $userSet = $false
        }
        
        # Ergebnis als PSCustomObject zurückgeben
        $result = [PSCustomObject]@{
            ComputerName       = $computerName
            PermanentRaw       = $macRaw
            PermanentClean     = $macClean
            Short              = $short
            Suffix             = $suffix
            IsWlan             = $isWlan
            WlanAdaptersFound  = ($wlanAdapters | Measure-Object).Count
            IsAdmin            = $isAdmin
            SessionVariableSet = ($env:MYCOMPUTERNAME -eq $computerName)
            SystemWideSet      = $systemWideSet
            UserVariableSet    = $userSet
        }
        
        Write-Host "✓ Computername erfolgreich generiert: $computerName" -ForegroundColor Green
        
        return $result
    }
    catch {
        Write-Error "Fehler in Get-MyComputerName: $($_.Exception.Message)"
        throw
    }
}

# Funktion zum Testen der Umgebungsvariablen
function Test-MyComputerNameEnvironment {
    <#
    .SYNOPSIS
    Testet die MYCOMPUTERNAME Umgebungsvariable in allen Scopes
    #>
    
    Write-Host "`n=== Test der MYCOMPUTERNAME Umgebungsvariable ===" -ForegroundColor Cyan
    
    # Session/Process Variable
    $sessionValue = $env:MYCOMPUTERNAME
    Write-Host "Session (Process): " -NoNewline
    if ($sessionValue) {
        Write-Host $sessionValue -ForegroundColor Green
    }
    else {
        Write-Host "Nicht gesetzt" -ForegroundColor Red
    }
    
    # Benutzer Variable
    $userValue = [System.Environment]::GetEnvironmentVariable('MYCOMPUTERNAME', [System.EnvironmentVariableTarget]::User)
    Write-Host "Benutzer:         " -NoNewline
    if ($userValue) {
        Write-Host $userValue -ForegroundColor Green
    }
    else {
        Write-Host "Nicht gesetzt" -ForegroundColor Red
    }
    
    # System Variable
    $systemValue = [System.Environment]::GetEnvironmentVariable('MYCOMPUTERNAME', [System.EnvironmentVariableTarget]::Machine)
    Write-Host "System:           " -NoNewline
    if ($systemValue) {
        Write-Host $systemValue -ForegroundColor Green
    }
    else {
        Write-Host "Nicht gesetzt" -ForegroundColor Red
    }
    
    Write-Host "================================================`n" -ForegroundColor Cyan
}

# Aufrufen
Write-Host "Starte Get-MyComputerName..." -ForegroundColor Yellow
$result = Get-MyComputerName
$result | Format-Table -AutoSize

# Test der Umgebungsvariablen
Test-MyComputerNameEnvironment