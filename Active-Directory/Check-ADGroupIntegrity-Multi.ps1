#Requires -Version 5.1
<#
.SYNOPSIS
    Ueberwacht ALLE privilegierten AD-Gruppen (Multi-Channel) mittels SHA256.
    Kompatibel mit PowerShell 5.1 (Windows Server 2016/2019).

.DESCRIPTION
    Funktionsweise:
    1. Ermittelt automatisch kritische Gruppen (adminCount=1 + Standardliste).
    2. Erstellt einen SHA256-Hash ueber die sortierten GUIDs der Mitglieder.
    3. Vergleicht Hash mit gespeicherter Baseline.
    4. Bei Aenderung: Setzt "Breach"-Datei -> Sensor bleibt ROT bis zur manuellen Quittierung.
    
    Quittierung: Datei '%TEMP%\PRTG_BREACH_<Gruppenname>.txt' loeschen.
#>

[CmdletBinding()]
param(
    [int]$MaxGroups = 45
)

$TempPath = $env:TEMP

# --- 1. GRUPPEN ERMITTELN (Auto-Discovery) ---
$CriticalGroups = New-Object System.Collections.Generic.List[string]

# Standard-Liste (wird immer geprueft)
$StandardNames = @(
    "Domänen-Admins", "Organisations-Admins", "Schema-Admins", 
    "Administratoren", "Server-Operatoren", "Sicherungs-Operatoren", 
    "Konten-Operatoren", "Druck-Operatoren", "Workstation-Admins"
)
$StandardNames | ForEach-Object { if (-not $CriticalGroups.Contains($_)) { $CriticalGroups.Add($_) } }

# Dynamische Suche nach adminCount=1
try {
    $ProtectedGroups = Get-ADGroup -Filter "adminCount -eq 1" -Properties adminCount | Select-Object -ExpandProperty Name
    foreach ($pg in $ProtectedGroups) {
        if (-not $CriticalGroups.Contains($pg)) {
            $CriticalGroups.Add($pg)
        }
    }
}
catch {
    Write-Warning "Konnte AD nicht nach adminCount durchsuchen. Nutze nur Standardliste."
}

# Sortieren und auf PRTG-Limit begrenzen
$MonitoredGroups = $CriticalGroups | Sort-Object | Select-Object -Unique -First $MaxGroups

# --- 2. HASH FUNKTION (SHA256) ---
function Get-ADGroupHash {
    param([string]$gid)
    try {
        # @() erzwingt Array -> verhindert Fehler bei 0 oder 1 Mitglied
        $m = @(Get-ADGroupMember -Identity $gid -Recursive -ErrorAction Stop)
        $count = $m.Count
        
        # Sortieren ist PFLICHT fuer stabilen Hash.
        # .ToString() ist PFLICHT fuer PS 5.1, da ObjectGUID dort kein String ist.
        $sortedGuids = $m | Sort-Object -Property ObjectGUID | ForEach-Object { $_.ObjectGUID.ToString() }
        $dataString = $sortedGuids -join "`n"
        
        # SHA256 Berechnung (Native .NET)
        $bytes = [System.Text.Encoding]::UTF8.GetBytes($dataString)
        $sha256 = [System.Security.Cryptography.SHA256]::Create()
        $hashBytes = $sha256.ComputeHash($bytes)
        
        # Rueckgabe als Base64 String
        $resultHash = [Convert]::ToBase64String($hashBytes)
        
        return [PSCustomObject]@{ Hash = $resultHash; Count = $count; Error = $false }
    }
    catch {
        # Fallback: Leere Gruppen (oft bei Builtin) werfen Fehler in Get-ADGroupMember
        try {
            $null = Get-ADGroup -Identity $gid -ErrorAction Stop
            return [PSCustomObject]@{ Hash = "EMPTY_GROUP"; Count = 0; Error = $false }
        }
        catch {
            return [PSCustomObject]@{ Hash = "ERROR"; Count = 0; Error = $true }
        }
    }
}

# --- 3. HAUPTSCHLEIFE ---

$Results = @()
$MasterErrorCount = 0
$BreachDetails = @()

foreach ($Group in $MonitoredGroups) {
    
    # Dateinamen bereinigen
    $SafeName = $Group -replace '[\\/*?:"<>|]', '_'
    $BaselineFile = "$TempPath\PRTG_Baseline_$($SafeName).txt"
    $BreachFile = "$TempPath\PRTG_BREACH_$($SafeName).txt"
    
    $Status = 0 
    $Msg = "OK"

    # A) LATCH-PRUEFUNG (Breach File)
    if (Test-Path -Path $BreachFile) {
        $Status = 1
        $Msg = "Vorfall nicht quittiert"
        $BreachDetails += "$Group (Nicht quittiert)"
    }
    else {
        # B) STATUS ERMITTELN
        $State = Get-ADGroupHash -gid $Group
        
        if ($State.Error) {
            # Gruppe nicht gefunden oder AD-Zugriffsfehler -> Sensor Gelb/Rot
            $Status = 1 
            $Msg = "Lesefehler"
            $BreachDetails += "$Group (Lesefehler)"
        }
        else {
            # C) BASELINE VERGLEICH
            if (-not (Test-Path -Path $BaselineFile)) {
                # Erste Ausfuehrung -> Baseline erstellen
                $State.Hash | Out-File -FilePath $BaselineFile -Force -Encoding ASCII
                $Msg = "Baseline erstellt"
            }
            else {
                $OldHash = Get-Content -Path $BaselineFile -ErrorAction SilentlyContinue
                # String-Vergleich
                if ("$($State.Hash)" -ne "$($OldHash)") {
                    $Status = 1
                    $Msg = "Aenderung erkannt!"
                    $BreachDetails += "$Group (Aenderung)"
                    # Breach-Datei setzen (Alarm verriegeln)
                    "Breach detected at $(Get-Date)" | Out-File -FilePath $BreachFile -Force -Encoding ASCII
                }
            }
        }
    }

    if ($Status -eq 1) { $MasterErrorCount++ }

    $Results += [PSCustomObject]@{
        Name    = $Group
        Value   = $Status
        Message = $Msg
    }
}

# --- 4. OUTPUT AN PRTG ---
Write-Host "<prtg>"

# Master-Kanal (Zusammenfassung)
Write-Host "  <result>"
Write-Host "    <channel>Gesamtstatus</channel>"
Write-Host "    <value>$MasterErrorCount</value>"
Write-Host "    <unit>Count</unit>"
Write-Host "    <LimitMode>1</LimitMode>"
Write-Host "    <LimitMaxError>0</LimitMaxError>"
Write-Host "    <LimitErrorMsg>Alarm bei privilegierten Gruppen</LimitErrorMsg>"
Write-Host "  </result>"

# Einzel-Kanaele
foreach ($Res in $Results) {
    Write-Host "  <result>"
    Write-Host "    <channel>$($Res.Name)</channel>"
    Write-Host "    <value>$($Res.Value)</value>"
    Write-Host "    <showchart>0</showchart>"
    Write-Host "    <showtable>1</showtable>"
    Write-Host "    <LimitMode>1</LimitMode>"
    Write-Host "    <LimitMaxError>0</LimitMaxError>"
    # Keine Umlaute verwenden fuer maximale Sicherheit
    Write-Host "    <LimitErrorMsg>$($Res.Message)</LimitErrorMsg>"
    Write-Host "  </result>"
}

if ($MasterErrorCount -gt 0) {
    $Text = "ALARM: $MasterErrorCount Gruppe(n): " + ($BreachDetails -join ", ")
    Write-Host "  <text>$Text</text>"
}
else {
    Write-Host "  <text>OK: Alle $($MonitoredGroups.Count) Gruppen entsprechen der Baseline.</text>"
}

Write-Host "</prtg>"