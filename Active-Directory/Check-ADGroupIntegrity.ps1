param(
    [string]$GroupIdentity = "Domänen-Admins"
)

$BaselineFile = "$($env:TEMP)\PRTG_Baseline_$($GroupIdentity).txt"
$BreachFile = "$($env:TEMP)\PRTG_BREACH_$($GroupIdentity).txt"

function Get-ADGroupMembersCrc32 {
    param([string]$gid)
    try {
        # Versuch 1: Mitglieder holen
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
        # FALLBACK: Get-ADGroupMember ist bei leeren Builtin-Gruppen zickig.
        # Wir prüfen: Existiert die Gruppe überhaupt?
        try {
            $groupCheck = Get-ADGroup -Identity $gid -ErrorAction Stop
            
            # Wenn wir hier ankommen, existiert die Gruppe, hat aber beim Abrufen der Mitglieder 
            # einen Fehler geworfen. Wir werten das als "Leere Gruppe".
            # CRC32 über einen leeren String ist 0.
            return [PSCustomObject]@{ Hash = 0; Count = 0 }
        }
        catch {
            # Gruppe existiert wirklich nicht oder kein Zugriff auf AD
            return $null
        }
    }
}

# --- Hauptlogik (Unverändert) ---

$CurrentState = Get-ADGroupMembersCrc32 -gid $GroupIdentity

if ($null -eq $CurrentState) {
    Write-Host "<prtg><error>1</error><text>Gruppe '$GroupIdentity' nicht gefunden oder Zugriff verweigert</text></prtg>"
    exit 1
}

if (Test-Path -Path $BreachFile) {
    Write-Host "<prtg>"
    Write-Host "  <result><channel>ChangeDetected</channel><value>1</value><LimitMode>1</LimitMode><LimitMaxError>0</LimitMaxError><LimitErrorMsg>Sicherheitsvorfall</LimitErrorMsg></result>"
    Write-Host "  <result><channel>MemberCount</channel><value>$($CurrentState.Count)</value></result>"
    Write-Host "  <text>ALARM: Ein Vorfall wurde registriert und noch nicht quittiert! Löschen Sie die Datei '$BreachFile' zum Reset.</text>"
    Write-Host "</prtg>"
    exit 0
}

if (-not (Test-Path -Path $BaselineFile)) {
    $CurrentState.Hash | Out-File -FilePath $BaselineFile -Force
    Write-Host "<prtg><result><channel>ChangeDetected</channel><value>0</value></result><text>Baseline initialisiert (Mitglieder: $($CurrentState.Count)).</text></prtg>"
    exit 0
}

$BaselineHash = Get-Content -Path $BaselineFile -ErrorAction SilentlyContinue

if ("$($CurrentState.Hash)" -ne "$($BaselineHash)") {
    "Breach detected at $(Get-Date)" | Out-File -FilePath $BreachFile -Force
    
    Write-Host "<prtg>"
    Write-Host "  <result><channel>ChangeDetected</channel><value>1</value><LimitMode>1</LimitMode><LimitMaxError>0</LimitMaxError><LimitErrorMsg>Änderung erkannt</LimitErrorMsg></result>"
    Write-Host "  <result><channel>MemberCount</channel><value>$($CurrentState.Count)</value></result>"
    Write-Host "  <text>ALARM: Abweichung von Baseline! Sicherheitsvorfall wurde fixiert.</text>"
    Write-Host "</prtg>"
}
else {
    Write-Host "<prtg>"
    Write-Host "  <result><channel>ChangeDetected</channel><value>0</value></result>"
    Write-Host "  <result><channel>MemberCount</channel><value>$($CurrentState.Count)</value></result>"
    Write-Host "  <text>OK: Keine Vorfälle.</text>"
    Write-Host "</prtg>"
}