<#
.SYNOPSIS
    Überwacht ALLE privilegierten AD-Gruppen gleichzeitig in einem PRTG-Sensor (Multi-Channel).

.DESCRIPTION
    1. Ermittelt automatisch privilegierte Gruppen (adminCount=1 + Standardgruppen).
    2. Prüft jede Gruppe auf Änderungen (Baseline vs. Ist).
    3. Nutzt Latch-Logik: Ein Alarm (Breach) bleibt bestehen, bis die Datei gelöscht wird.
    4. Aggregiert alle Alarme in einem "Gesamtstatus"-Kanal.

    Quittierung:
    Löschen Sie die Datei '%TEMP%\PRTG_BREACH_<Gruppenname>.txt' auf der Probe.

.PARAMETER MaxGroups
    Maximale Anzahl an Gruppen, die überwacht werden (PRTG Limit beachten: Max 50 Kanäle).
    Standard: 45

#>

[CmdletBinding()]
param(
    [int]$MaxGroups = 45
)

# Pfad-Basis
$TempPath = $env:TEMP

# --- 1. GRUPPEN ERMITTELN ---
# Wir starten mit den Klassikern, um sicherzugehen, dass diese immer dabei sind,
# auch wenn adminCount mal 0 wäre (was bei diesen eigentlich nicht sein sollte).
$CriticalGroups = [System.Collections.Generic.List[string]]::new()
$StandardNames = @(
    "Domänen-Admins", "Organisations-Admins", "Schema-Admins", 
    "Administratoren", "Server-Operatoren", "Sicherungs-Operatoren", 
    "Konten-Operatoren", "Druck-Operatoren"
)
$StandardNames | ForEach-Object { $CriticalGroups.Add($_) }

# Rudimentäre Suche nach offensichtlichen Namen
(Get-ADGroup -Filter * | Where-Object SamAccountName -like "*admin*").samAccountName | ForEach-Object { $CriticalGroups.Add($_) }
(Get-ADGroup -Filter * | Where-Object SamAccountName -like "*operator*").samAccountName | ForEach-Object { $CriticalGroups.Add($_) }

# Dynamische Suche nach adminCount=1 (geschützte Gruppen)
try {
    $ProtectedGroups = Get-ADGroup -Filter { adminCount -eq 1 } -Properties adminCount | Select-Object -ExpandProperty Name
    foreach ($pg in $ProtectedGroups) {
        if (-not $CriticalGroups.Contains($pg)) {
            $CriticalGroups.Add($pg)
        }
    }
}
catch {
    Write-Warning "Konnte AD nicht nach adminCount durchsuchen. Nutze nur Standardliste."
}

# Sortieren und auf PRTG-Limit kürzen
$MonitoredGroups = $CriticalGroups | Sort-Object | Select-Object -Unique -First $MaxGroups

# --- 2. HILFSFUNKTIONEN ---

function Get-ADGroupMembersCrc32 {
    param([string]$gid)
    try {
        # Array erzwingen @()
        $m = @(Get-ADGroupMember -Identity $gid -Recursive -ErrorAction Stop)
        $count = $m.Count
        
        $sorted = $m | Sort-Object -Property ObjectGUID
        $s = ($sorted.ObjectGUID.Guid | ForEach-Object { $_.ToLowerInvariant() }) -join "`n"
        $b = [System.Text.Encoding]::UTF8.GetBytes($s)
        
        # CRC32
        $crc = 0xFFFFFFFFUL
        $mask = 0xFFFFFFFFUL
        foreach ($byte in $b) {
            $crc = ($crc -bxor [uint64]$byte) -band $mask
            for ($i = 0; $i -lt 8; $i++) {
                if (($crc -band 1UL) -ne 0UL) { $crc = (($crc -shr 1) -bxor 0xEDB88320UL) -band $mask } 
                else { $crc = ($crc -shr 1) -band $mask }
            }
        }
        $res = ($crc -bxor 0xFFFFFFFFUL) -band $mask
        return [PSCustomObject]@{ Hash = [uint32]$res; Count = $count; Error = $false }
    }
    catch {
        # Fallback für leere Builtin-Gruppen
        try {
            $null = Get-ADGroup -Identity $gid -ErrorAction Stop
            return [PSCustomObject]@{ Hash = 0; Count = 0; Error = $false }
        }
        catch {
            return [PSCustomObject]@{ Hash = 0; Count = 0; Error = $true }
        }
    }
}

# Speicher für Ergebnisse
$Results = @()
$MasterErrorCount = 0
$BreachDetails = @()

# --- 3. HAUPTSCHLEIFE ÜBER ALLE GRUPPEN ---

foreach ($Group in $MonitoredGroups) {
    
    # Dateinamen sanitizen (falls Gruppenname Sonderzeichen hat, die im Dateisystem verboten sind)
    $SafeName = $Group -replace '[\\/*?:"<>|]', '_'
    $BaselineFile = "$TempPath\PRTG_Baseline_$($SafeName).txt"
    $BreachFile = "$TempPath\PRTG_BREACH_$($SafeName).txt"
    
    $Status = 0 # 0=OK, 1=ALARM
    $Msg = "OK"

    # A) BREACH DATEI PRÜFEN (LATCH)
    if (Test-Path -Path $BreachFile) {
        $Status = 1
        $Msg = "Vorfall nicht quittiert"
        $BreachDetails += "$Group (Nicht quittiert)"
    }
    else {
        # B) AKTUELLEN WERT HOLEN
        $State = Get-ADGroupMembersCrc32 -gid $Group
        
        if ($State.Error) {
            # Gruppe nicht gefunden -> Wir werten das hier als Warnung/Fehler im Sensor
            $Status = 1 
            $Msg = "Lesefehler"
            $BreachDetails += "$Group (Lesefehler)"
        }
        else {
            # C) BASELINE PRÜFEN
            if (-not (Test-Path -Path $BaselineFile)) {
                # Init
                $State.Hash | Out-File -FilePath $BaselineFile -Force
                $Msg = "Baseline erstellt"
            }
            else {
                # Vergleich
                $OldHash = Get-Content -Path $BaselineFile -ErrorAction SilentlyContinue
                if ("$($State.Hash)" -ne "$($OldHash)") {
                    $Status = 1
                    $Msg = "Änderung erkannt!"
                    $BreachDetails += "$Group (Änderung)"
                    # Breach setzen
                    "Breach at $(Get-Date)" | Out-File -FilePath $BreachFile -Force
                }
            }
        }
    }

    if ($Status -eq 1) { $MasterErrorCount++ }

    # Ergebnisobjekt für XML Ausgabe merken
    $Results += [PSCustomObject]@{
        Name    = $Group
        Value   = $Status
        Message = $Msg
    }
}

# --- 4. XML AUSGABE AN PRTG ---

Write-Host "<prtg>"

# A) MASTER KANAL (Aggregiert)
# Wenn MasterErrorCount > 0, dann Alarm.
Write-Host "  <result>"
Write-Host "    <channel>Gesamtstatus</channel>"
Write-Host "    <value>$MasterErrorCount</value>"
Write-Host "    <unit>Count</unit>"
Write-Host "    <LimitMode>1</LimitMode>" # Max Error Limit aktiv
Write-Host "    <LimitMaxError>0</LimitMaxError>" # Fehler wenn > 0
Write-Host "    <LimitErrorMsg>Kritische Änderungen erkannt</LimitErrorMsg>"
Write-Host "  </result>"

# B) EINZELKANÄLE
foreach ($Res in $Results) {
    Write-Host "  <result>"
    Write-Host "    <channel>$($Res.Name)</channel>"
    Write-Host "    <value>$($Res.Value)</value>"
    Write-Host "    <showchart>0</showchart>" # Chart meist unnötig bei 0/1
    Write-Host "    <showtable>1</showtable>"
    Write-Host "    <LimitMode>1</LimitMode>"
    Write-Host "    <LimitMaxError>0</LimitMaxError>"
    Write-Host "    <LimitErrorMsg>Änderung: $($Res.Message)</LimitErrorMsg>"
    Write-Host "  </result>"
}

# C) TEXT MESSAGE
if ($MasterErrorCount -gt 0) {
    $Text = "ALARM: $MasterErrorCount privilegierte Gruppe(n) betroffen: " + ($BreachDetails -join ", ")
    Write-Host "  <text>$Text</text>"
}
else {
    Write-Host "  <text>OK: Alle $($MonitoredGroups.Count) überwachten Gruppen entsprechen der Baseline.</text>"
}

Write-Host "</prtg>"