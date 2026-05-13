<#
.SYNOPSIS
    Erstellt Public Spot Benutzer für LANCOM WLC/Router in Massenverarbeitung basierend auf einer CSV-Datei.

.DESCRIPTION
    Das Skript prüft, ob eine Eingabe-CSV vorhanden ist. Falls nicht, wird eine Beispieldatei erstellt und das Skript beendet sich.
    Anschließend werden die Zeilen eingelesen und Benutzer via REST-API auf dem LANCOM-Gerät angelegt.
    Die generierten Zugangsdaten werden in einer mit Zeitstempel versehenen Ergebnis-CSV gespeichert.
    Nach erfolgreicher Verarbeitung wird die Eingabe-CSV mit demselben Zeitstempel umbenannt.

.PARAMETER RouterIP
    IP-Adresse oder Hostname des LANCOM-Geräts. Standard: 10.0.8.240

.PARAMETER AdminUser
    Benutzername des LANCOM-Administrators für die REST-API.

.PARAMETER AdminPass
    Passwort des LANCOM-Administrators als SecureString.

.PARAMETER InputCsv
    Pfad zur Eingabe-CSV-Datei mit den zu erstellenden Benutzern.

.PARAMETER OutputCsv
    Basispfad der Ausgabe-CSV. Wird automatisch mit Zeitstempel versehen.
    Standard: .\Ausgabe_Zugangsdaten.csv

.PARAMETER SkipCertificateCheck
    Zertifikatsprüfung beim HTTPS-Aufruf überspringen (z.B. bei selbstsignierten Zertifikaten).
    Standard: $true

.EXAMPLE
    $SecurePass = Read-Host -Prompt "Passwort eingeben" -AsSecureString
    .\Create-PublicSpotUsers.ps1 -AdminUser "myuser" -AdminPass $SecurePass -InputCsv ".\Eingabe_Benutzer.csv"

.EXAMPLE
    .\Create-PublicSpotUsers.ps1 -AdminUser "admin" -AdminPass $SecurePass -InputCsv ".\users.csv" -RouterIP "192.168.1.1" -SkipCertificateCheck $false

.NOTES
    Version : 1.5
    Autor   : IT-Administration MyCorp

    Änderungen v1.5:
      - BUGFIX: SSID in der Ausgabe-CSV wurde URL-kodiert zurückgegeben (z.B. "LANCOM%20VISITOR"
                statt "LANCOM VISITOR"). Behoben durch UnescapeDataString() nach dem Regex-Matching.
      - VolumeBudget-Typ von [int] auf [string] geändert, damit API-Suffixe (k/m/g) direkt
                übergeben werden können (z.B. "1m" für 1 Megabyte).

    Änderungen v1.4:
      - BUGFIX (Hauptursache): Der Unit-Wert in der CSV muss englisch sein: 'Day', 'Hour', 'Minute'.
                Deutscher Wert 'Tag' wird vom LANCOM nicht erkannt und löst eine interaktive
                HTML-Wizard-Session aus statt des Datenblocks → FAILED (Format).
      - REVERT v1.3: validper wird wieder für alle ExpiryType-Werte an die URL angehängt.
                Der v1.3-Fix (validper nur bei 'both') war falsch; tatsächliche Ursache war 'Tag' statt 'Day'.
      - Beispiel-CSV aktualisiert: 'Tag' → 'Day' (war in v1.2 fälschlicherweise auf 'Tag' geändert worden).
      - Regex-Pattern auf SingleLine-Modus ((?s)) umgestellt, damit mehrzeilige { SSID:... }-Blöcke
        korrekt erkannt werden.

    Änderungen v1.2 (Korrekturen nach Abgleich mit LANCOM-Dokumentation):
      - REVERT: Das '+' zwischen unit/runtime und expirytype/validper ist laut LANCOM-Doku korrekt.
                Die LANCOM-API verwendet '+' als Combiner für zusammengehörige Sub-Parameter.
      - BUGFIX: Parametername 'maxconclogins' korrigiert zu 'maxconclogin' (laut LANCOM-Doku)
      - BUGFIX: Parametername 'bandwidthprofile' korrigiert zu 'bandwidthprof' (laut LANCOM-Doku)
        Hinweis: Durch stilles Ignorieren falscher Parameter hat LANCOM bei beiden Feldern
                 bisher immer den jeweiligen Default-Wert verwendet statt den übergebenen Wert.

    Änderungen v1.1:
      - BUGFIX: Fehlende URL-Kodierung für Sonderzeichen/Leerzeichen in 'Comment' und 'SSID'
      - BUGFIX: Fehlgeschlagene API-Aufrufe wurden nicht als Fehlerzeile in die Ergebnis-CSV geschrieben
      - NEU: Explizite Int-Konvertierung der CSV-Felder (robustere Verarbeitung)
      - NEU: Write-Progress für Fortschrittsanzeige bei großen Benutzerlisten
      - NEU: Zusammenfassung (Erfolge/Fehler) am Ende der Verarbeitung
      - NEU: Validierung der CSV-Pflichtfelder vor der Verarbeitung
      - NEU: Parameter -SkipCertificateCheck konfigurierbar statt hardcodiert
#>

[CmdletBinding()]
param (
    [Parameter(Mandatory = $false)]
    [string]$RouterIP = "10.0.8.240",

    [Parameter(Mandatory = $true)]
    [string]$AdminUser,

    [Parameter(Mandatory = $true)]
    [securestring]$AdminPass,

    [Parameter(Mandatory = $true)]
    [string]$InputCsv,

    [Parameter(Mandatory = $false)]
    [string]$OutputCsv = ".\Ausgabe_Zugangsdaten.csv",

    [Parameter(Mandatory = $false)]
    [bool]$SkipCertificateCheck = $true
)

# --- FUNKTIONEN ---

function Invoke-CmdPbSpotUser {
    param (
        [string]$ServerIP,
        [string]$Action,
        [string]$Comment,
        [string]$Unit,
        [int]$Runtime,
        [int]$NbGuests,
        [string]$ExpiryType,
        [int]$ValidPer,
        [string]$SSID,
        [int]$MaxConcLogins,
        [int]$BandwidthProfile,
        [int]$TimeBudget,
        [string]$VolumeBudget,
        [int]$Active,
        [string]$Username,
        [securestring]$Password,
        [bool]$SkipCertCheck = $true
    )

    # Secure String in Klartext umwandeln, da Basic Auth dies zwingend erfordert
    $PlainPassword = (New-Object System.Management.Automation.PSCredential ($Username, $Password)).GetNetworkCredential().Password

    $authInfo = "{0}:{1}" -f $Username, $PlainPassword
    $base64AuthInfo = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes($authInfo))

    # URL-Kodierung für Felder mit Leerzeichen oder Sonderzeichen.
    # Hinweis: Die LANCOM-API unterstützt keine deutschen Umlaute im Comment-Feld.
    # Hinweis: '+' ist LANCOM-internes Sub-Parameter-Trennzeichen (unit+runtime, expirytype+validper).
    #          EscapeDataString kodiert Leerzeichen als %20 (nicht als '+') um Kollisionen zu vermeiden.
    $encodedComment = [System.Uri]::EscapeDataString($Comment)
    $encodedSSID = [System.Uri]::EscapeDataString($SSID)

    # URL-Aufbau gemäß LANCOM-Dokumentation:
    # - unit und runtime werden per '+' verbunden (LANCOM Sub-Parameter-Syntax, kein URL-Trennzeichen)
    # - expirytype und validper werden per '+' verbunden
    # - Unit-Werte müssen englisch sein: Day, Hour, Minute (nicht Tag, Stunde)
    # - Korrekte Parameternamen: maxconclogin (ohne 's'), bandwidthprof (ohne 'ile')
    $uri = "https://$($ServerIP)/cmdpbspotuser/" +
    "?action=$($Action)" +
    "&comment=$($encodedComment)" +
    "&unit=$($Unit)+runtime=$($Runtime)" +
    "&multilogin" +
    "&print" +
    "&printcomment" +
    "&casesensitive=0" +
    "&nbGuests=$($NbGuests)" +
    "&expirytype=$($ExpiryType)+validper=$($ValidPer)" +
    "&ssid=$($encodedSSID)" +
    "&maxconclogin=$($MaxConcLogins)" +
    "&bandwidthprof=$($BandwidthProfile)" +
    "&timebudget=$($TimeBudget)" +
    "&volumebudget=$($VolumeBudget)" +
    "&active=$($Active)"

    try {
        $response = Invoke-RestMethod -Uri $uri `
            -Method Get `
            -Headers @{ Authorization = ("Basic $($base64AuthInfo)") } `
            -SkipCertificateCheck:$SkipCertCheck
        return $response
    }
    catch {
        Write-Error "Fehler beim API-Aufruf fuer '$($Comment)': $($_)"
        return $null
    }
}

# --- HAUPTSKRIPT ---

# 1. Prüfen ob Eingabe-Datei existiert, sonst erstellen und beenden
if (-not (Test-Path $InputCsv)) {
    Write-Host "Eingabedatei nicht gefunden. Erstelle Beispieldatei: $($InputCsv)" -ForegroundColor Yellow
    $defaultContent = @"
Comment;Unit;Runtime;ExpiryType;ValidPer;SSID;MaxConcLogins;BandwidthProfile;TimeBudget;VolumeBudget;Active
Max Mustermann;Day;1;absolute;1;LVISITOR;1;1;0;0;1
Techniker Firma X;Day;7;absolute;7;LVISITOR;2;1;0;0;1
Besprechungsraum A;Minute;240;relative;0;LVISITOR;5;2;0;0;1
"@
    $defaultContent | Out-File -FilePath $InputCsv -Encoding utf8
    Write-Host "Bitte fuellen Sie die Datei aus und starten Sie das Skript erneut." -ForegroundColor Yellow
    return
}

# 2. Daten einlesen
$UserList = Import-Csv -Path $InputCsv -Delimiter ";"

# Leereliste abfangen
if ($UserList.Count -eq 0) {
    Write-Host "Eingabedatei ist leer oder enthaelt keine Datenzeilen. Vorgang abgebrochen." -ForegroundColor Yellow
    return
}

# Pflichtfelder der CSV validieren
$requiredColumns = @('Comment', 'Unit', 'Runtime', 'ExpiryType', 'ValidPer', 'SSID', 'MaxConcLogins', 'BandwidthProfile', 'TimeBudget', 'VolumeBudget', 'Active')
$csvColumns = $UserList[0].PSObject.Properties.Name
$missingColumns = $requiredColumns | Where-Object { $_ -notin $csvColumns }

if ($missingColumns.Count -gt 0) {
    Write-Host "Fehlende Pflichtspalten in der CSV: $($missingColumns -join ', ')" -ForegroundColor Red
    Write-Host "Vorgang abgebrochen." -ForegroundColor Red
    return
}

# Zeitstempel generieren und Dateinamen vorbereiten
$TimeStamp = Get-Date -Format "yyyyMMdd_HHmmss"

$OutDir = Split-Path $OutputCsv -Parent
if ($OutDir -eq "") { $OutDir = "." }
$OutBase = [System.IO.Path]::GetFileNameWithoutExtension($OutputCsv)
$OutExt = [System.IO.Path]::GetExtension($OutputCsv)
$FinalOutputCsv = Join-Path $OutDir "$($OutBase)_$($TimeStamp)$($OutExt)"

$InBase = [System.IO.Path]::GetFileNameWithoutExtension($InputCsv)
$InExt = [System.IO.Path]::GetExtension($InputCsv)
$NewInputFileName = "$($InBase)_$($TimeStamp)$($InExt)"

$Results = New-Object System.Collections.Generic.List[PSCustomObject]
$CountSuccess = 0
$CountFailed = 0
$Total = $UserList.Count

Write-Host "Starte Verarbeitung von $($Total) Benutzern..." -ForegroundColor Cyan

# 3. Schleife über alle Benutzer
for ($i = 0; $i -lt $Total; $i++) {
    $Row = $UserList[$i]

    Write-Progress -Activity "LANCOM PublicSpot - Benutzer anlegen" `
        -Status "Verarbeite '$($Row.Comment)' ($($i + 1) von $($Total))" `
        -PercentComplete (($i / $Total) * 100)

    Write-Host "Erstelle Benutzer fuer: $($Row.Comment)..." -NoNewline

    # Explizite Int-Konvertierung der CSV-Werte (CSV liefert immer Strings)
    $ApiResult = Invoke-CmdPbSpotUser `
        -ServerIP         $RouterIP `
        -Action           "addpbspotuser" `
        -Comment          $Row.Comment `
        -Unit             $Row.Unit `
        -Runtime          ([int]$Row.Runtime) `
        -NbGuests         1 `
        -ExpiryType       $Row.ExpiryType `
        -ValidPer         ([int]$Row.ValidPer) `
        -SSID             $Row.SSID `
        -MaxConcLogins    ([int]$Row.MaxConcLogins) `
        -BandwidthProfile ([int]$Row.BandwidthProfile) `
        -TimeBudget       ([int]$Row.TimeBudget) `
        -VolumeBudget     $Row.VolumeBudget `
        -Active           ([int]$Row.Active) `
        -Username         $AdminUser `
        -Password         $AdminPass `
        -SkipCertCheck    $SkipCertificateCheck

    if ($null -eq $ApiResult) {
        $Results.Add([PSCustomObject]@{
                Comment    = $Row.Comment
                Username   = ""
                Password   = ""
                SSID       = ""
                AccountEnd = ""
                Lifetime   = ""
                Status     = "Fehler: API-Aufruf fehlgeschlagen"
            })
        $CountFailed++
        Write-Host " FAILED (API)" -ForegroundColor Red
        continue
    }

    # Regex mit (?s) (SingleLine-Modus): { SSID:... }-Block wird auch bei mehrzeiligen Antworten erkannt
    $pattern = '(?s)\{ SSID:.*?\}'
    if ($ApiResult -match $pattern) {
        $jsonRaw = $Matches[0]

        $extSSID = if ($jsonRaw -match 'SSID:\s*"([^"]+)"') { [System.Uri]::UnescapeDataString($Matches[1]) } else { "" }
        $extUser = if ($jsonRaw -match 'USERID:\s*"([^"]+)"') { $Matches[1] } else { "" }
        $extPass = if ($jsonRaw -match 'PASSWORD:\s*"([^"]+)"') { $Matches[1] } else { "" }
        $extAccountEnd = if ($jsonRaw -match 'ACCOUNTEND:\s*"([^"]+)"') { $Matches[1] } else { "" }
        $extLifetime = if ($jsonRaw -match 'LIFETIME:\s*"([^"]+)"') { $Matches[1] } else { "" }

        $Results.Add([PSCustomObject]@{
                Comment    = $Row.Comment
                Username   = $extUser
                Password   = $extPass
                SSID       = $extSSID
                AccountEnd = $extAccountEnd
                Lifetime   = $extLifetime
                Status     = "Erfolgreich"
            })
        $CountSuccess++
        Write-Host " OK" -ForegroundColor Green
    }
    else {
        $Results.Add([PSCustomObject]@{
                Comment    = $Row.Comment
                Username   = ""
                Password   = ""
                SSID       = ""
                AccountEnd = ""
                Lifetime   = ""
                Status     = "Fehler: Antwortformat unbekannt"
            })
        $CountFailed++
        Write-Host " FAILED (Format)" -ForegroundColor Red
    }
}

Write-Progress -Activity "LANCOM PublicSpot - Benutzer anlegen" -Completed

# 4. Ergebnisse exportieren
$Results | Export-Csv -Path $FinalOutputCsv -Delimiter ";" -NoTypeInformation -Encoding utf8
Write-Host "Verarbeitung abgeschlossen. Ergebnisse gespeichert in: $($FinalOutputCsv)" -ForegroundColor Cyan

# Abschlusszusammenfassung
Write-Host "Zusammenfassung: $($CountSuccess) erfolgreich, $($CountFailed) fehlgeschlagen (gesamt $($Total))." -ForegroundColor $(if ($CountFailed -gt 0) { "Yellow" } else { "Green" })

# 5. Eingabedatei umbenennen
Rename-Item -Path $InputCsv -NewName $NewInputFileName
Write-Host "Eingabedatei wurde erfolgreich umbenannt zu: $($NewInputFileName)" -ForegroundColor Cyan
