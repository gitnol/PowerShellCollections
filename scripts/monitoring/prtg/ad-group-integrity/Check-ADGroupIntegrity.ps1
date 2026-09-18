<#
.SYNOPSIS
    Überwacht die Integrität einer AD-Gruppe für PRTG und setzt einen Alarm (Latch/Breach) bei Änderungen.

.DESCRIPTION
    Dieses Skript erstellt einen Prüfsummen-Vergleich (Baseline vs. Ist-Zustand) einer AD-Gruppe.
    Wird eine Änderung erkannt, wird eine "Breach-Datei" erstellt. Der Sensor bleibt ROT, bis diese Datei
    manuell gelöscht wird (Quittierung).

    --- ERMITTLUNG ZU ÜBERWACHENDER GRUPPEN ---
    
    1. Suche nach offensichtlichen Namen (Rudimentär):
       Get-ADGroup -Filter * | Where-Object SamAccountName -like "*admin*" | Select-Object SamAccountName | Sort-Object SamAccountName
       Get-ADGroup -Filter * | Where-Object SamAccountName -like "*operator*" | Select-Object SamAccountName | Sort-Object SamAccountName

    2. Suche via adminCount (Protected Groups / SDPROP) inkl. rekursiver Auflösung:
       $check = Get-ADGroup -Filter {adminCount -eq 1} -Properties adminCount | Select-Object Name, DistinguishedName
       $check | ForEach-Object {
           $TargetGroup = $_.DistinguishedName
           Write-Verbose "Prüfe: $TargetGroup" -Verbose
           Get-ADGroupMember -Identity $TargetGroup -Recursive | Where-Object { $_.objectClass -eq "group" } | Select-Object Name, DistinguishedName 
       }

.PARAMETER GroupIdentity
    Der Name (SamAccountName/DN) der zu überwachenden Gruppe (z.B. 'Domänen-Admins', 'Server-Operatoren').

.EXAMPLE
    .\Check-ADGroupIntegrity.ps1 -GroupIdentity "Domänen-Admins"
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$GroupIdentity
)

# Pfade für Baseline und Breach-Flag
$BaselineFile = "$($env:TEMP)\PRTG_Baseline_$($GroupIdentity).txt"
$BreachFile = "$($env:TEMP)\PRTG_BREACH_$($GroupIdentity).txt"

# --- Hilfsfunktion: CRC32 Berechnung ---
function Get-ADGroupMembersCrc32 {
    param([string]$gid)
    try {
        # Versuch 1: Mitglieder holen
        # @(...) erzwingt Array, verhindert $null bei 0 Treffern
        $m = @(Get-ADGroupMember -Identity $gid -Recursive -ErrorAction Stop)
        
        $count = $m.Count
        
        # Normale Berechnung
        $sorted = $m | Sort-Object -Property ObjectGUID
        $s = ($sorted.ObjectGUID.Guid | ForEach-Object { $_.ToLowerInvariant() }) -join "`n"
        $b = [System.Text.Encoding]::UTF8.GetBytes($s)
        
        $crc = 0xFFFFFFFFUL
        $mask = 0xFFFFFFFFUL
        foreach ($byte in $b) {
            $crc = ($crc -bxor [uint64]$byte) -band $mask
            for ($i = 0; $i -lt 8; $i++) {
                if (($crc -band 1UL) -ne 0UL) {
                    $crc = (($crc -shr 1) -bxor 0xEDB88320UL) -band $mask
                }
                else {
                    $crc = ($crc -shr 1) -band $mask
                }
            }
        }
        $res = ($crc -bxor 0xFFFFFFFFUL) -band $mask
        
        return [PSCustomObject]@{ Hash = [uint32]$res; Count = $count }

    }
    catch {
        # FALLBACK: Builtin-Gruppen (z.B. Server-Operatoren) werfen Fehler statt leerer Liste, wenn leer.
        # Wir prüfen: Existiert die Gruppe überhaupt?
        try {
            $groupCheck = Get-ADGroup -Identity $gid -ErrorAction Stop
            
            # Wenn wir hier ankommen, existiert die Gruppe, aber Get-ADGroupMember schlug fehl.
            # Wir werten das als "Leere Gruppe".
            return [PSCustomObject]@{ Hash = 0; Count = 0 }
        }
        catch {
            # Gruppe existiert wirklich nicht oder kein Zugriff auf AD
            return $null
        }
    }
}

# --- Hauptlogik ---

# 1. Aktuellen Status holen
$CurrentState = Get-ADGroupMembersCrc32 -gid $GroupIdentity

# Prüfung auf echten Fehler (Gruppe nicht gefunden)
if ($null -eq $CurrentState) {
    Write-Host "<prtg><error>1</error><text>Gruppe '$GroupIdentity' nicht gefunden oder Zugriff verweigert</text></prtg>"
    exit 1
}

# 2. PRÜFUNG AUF VORFALL (LATCH / SELBSTHALTUNG)
if (Test-Path -Path $BreachFile) {
    Write-Host "<prtg>"
    Write-Host "  <result><channel>ChangeDetected</channel><value>1</value><LimitMode>1</LimitMode><LimitMaxError>0</LimitMaxError><LimitErrorMsg>Sicherheitsvorfall</LimitErrorMsg></result>"
    Write-Host "  <result><channel>MemberCount</channel><value>$($CurrentState.Count)</value></result>"
    Write-Host "  <text>ALARM: Ein Vorfall wurde registriert und noch nicht quittiert! Löschen Sie die Datei '$BreachFile' zum Reset.</text>"
    Write-Host "</prtg>"
    exit 0
}

# 3. Initialisierung (Erster Lauf)
if (-not (Test-Path -Path $BaselineFile)) {
    $CurrentState.Hash | Out-File -FilePath $BaselineFile -Force
    Write-Host "<prtg><result><channel>ChangeDetected</channel><value>0</value></result><text>Baseline initialisiert (Mitglieder: $($CurrentState.Count)).</text></prtg>"
    exit 0
}

# 4. Vergleich mit Baseline
$BaselineHash = Get-Content -Path $BaselineFile -ErrorAction SilentlyContinue

if ("$($CurrentState.Hash)" -ne "$($BaselineHash)") {
    # ÄNDERUNG ERKANNT -> Breach File schreiben
    "Breach detected at $(Get-Date)" | Out-File -FilePath $BreachFile -Force
    
    Write-Host "<prtg>"
    Write-Host "  <result><channel>ChangeDetected</channel><value>1</value><LimitMode>1</LimitMode><LimitMaxError>0</LimitMaxError><LimitErrorMsg>Änderung erkannt</LimitErrorMsg></result>"
    Write-Host "  <result><channel>MemberCount</channel><value>$($CurrentState.Count)</value></result>"
    Write-Host "  <text>ALARM: Abweichung von Baseline! Sicherheitsvorfall wurde fixiert.</text>"
    Write-Host "</prtg>"
}
else {
    # Alles sauber
    Write-Host "<prtg>"
    Write-Host "  <result><channel>ChangeDetected</channel><value>0</value></result>"
    Write-Host "  <result><channel>MemberCount</channel><value>$($CurrentState.Count)</value></result>"
    Write-Host "  <text>OK: Keine Vorfälle.</text>"
    Write-Host "</prtg>"
}