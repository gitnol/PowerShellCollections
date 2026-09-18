<#
.SYNOPSIS
    Erstellt Public Spot Benutzer für LANCOM WLC/Router in Massenverarbeitung basierend auf einer CSV-Datei.

.DESCRIPTION
    Das Skript prüft, ob eine Eingabe-CSV vorhanden ist. Falls nicht, wird eine Beispieldatei erstellt und das Skript beendet sich.
    Anschließend werden die Zeilen eingelesen und Benutzer via REST-API auf dem LANCOM-Gerät angelegt.
    Die generierten Zugangsdaten werden in einer mit Zeitstempel versehenen Ergebnis-CSV gespeichert.
    Nach erfolgreicher Verarbeitung wird die Eingabe-CSV mit demselben Zeitstempel umbenannt.

.EXAMPLE
    $SecurePass = Read-Host -Prompt "Passwort eingeben" -AsSecureString
    .\Create-PublicSpotUsers.ps1 -AdminUser "myuser" -AdminPass $SecurePass -InputCsv ".\Eingabe_Benutzer.csv"
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
    [string]$OutputCsv = ".\Ausgabe_Zugangsdaten.csv"
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
        [int]$VolumeBudget,
        [int]$Active,
        [string]$Username,
        [securestring]$Password
    )

    # Secure String in Klartext umwandeln, da Basic Auth dies zwingend erfordert
    $PlainPassword = (New-Object System.Management.Automation.PSCredential ($Username, $Password)).GetNetworkCredential().Password

    $authInfo = "{0}:{1}" -f $Username, $PlainPassword
    $base64AuthInfo = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes($authInfo))

    # URL-Konstruktion
    $uri = "https://$($ServerIP)/cmdpbspotuser/?action=$($Action)&comment=$($Comment)&unit=$($Unit)+runtime=$($Runtime)&multilogin&print&printcomment&casesensitive=0&nbGuests=$($NbGuests)&expirytype=$($ExpiryType)+validper=$($ValidPer)&ssid=$($SSID)&maxconclogins=$($MaxConcLogins)&bandwidthprofile=$($BandwidthProfile)&timebudget=$($TimeBudget)&volumebudget=$($VolumeBudget)&active=$($Active)"

    try {
        $response = Invoke-RestMethod -Uri $uri `
            -Method Get `
            -Headers @{Authorization = ("Basic $($base64AuthInfo)") } `
            -SkipCertificateCheck
        return $response
    }
    catch {
        Write-Error "Fehler beim API-Aufruf fuer $($Comment) : $($_)"
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

# 2. Daten einlesen
$UserList = Import-Csv -Path $InputCsv -Delimiter ";"
$Results = New-Object System.Collections.Generic.List[PSCustomObject]

Write-Host "Starte Verarbeitung von $($UserList.Count) Benutzern..." -ForegroundColor Cyan

# 3. Schleife über alle Benutzer
foreach ($Row in $UserList) {
    Write-Host "Erstelle Benutzer fuer: $($Row.Comment)..." -NoNewline
    
    $ApiResult = Invoke-CmdPbSpotUser `
        -ServerIP $RouterIP `
        -Action "addpbspotuser" `
        -Comment $Row.Comment `
        -Unit $Row.Unit `
        -Runtime $Row.Runtime `
        -NbGuests 1 `
        -ExpiryType $Row.ExpiryType `
        -ValidPer $Row.ValidPer `
        -SSID $Row.SSID `
        -MaxConcLogins $Row.MaxConcLogins `
        -BandwidthProfile $Row.BandwidthProfile `
        -TimeBudget $Row.TimeBudget `
        -VolumeBudget $Row.VolumeBudget `
        -Active $Row.Active `
        -Username $AdminUser `
        -Password $AdminPass

    if ($ApiResult) {
        # RegEx um das Datenpaket aus der Antwort zu extrahieren
        $pattern = '\{ SSID:.*\}'
        if ($ApiResult -match $pattern) {
            $jsonRaw = $Matches[0]
            
            # Variablen vorab sauber als leere Strings initialisieren
            $extSSID = ""
            $extUser = ""
            $extPass = ""
            $extAccountEnd = ""
            $extLifetime = ""

            # Gezielt nach den einzelnen Feldern suchen (if-then-else)
            if ($jsonRaw -match 'SSID:\s*"([^"]+)"') {
                $extSSID = $Matches[1]
            }
            
            if ($jsonRaw -match 'USERID:\s*"([^"]+)"') {
                $extUser = $Matches[1]
            }
            
            if ($jsonRaw -match 'PASSWORD:\s*"([^"]+)"') {
                $extPass = $Matches[1]
            }

            if ($jsonRaw -match 'ACCOUNTEND:\s*"([^"]+)"') {
                $extAccountEnd = $Matches[1]
            }

            if ($jsonRaw -match 'LIFETIME:\s*"([^"]+)"') {
                $extLifetime = $Matches[1]
            }
            
            $Results.Add([PSCustomObject]@{
                    Comment    = $Row.Comment
                    Username   = $extUser
                    Password   = $extPass
                    SSID       = $extSSID
                    AccountEnd = $extAccountEnd
                    Lifetime   = $extLifetime
                    Status     = "Erfolgreich"
                })
            Write-Host " OK" -ForegroundColor Green
        }
        else {
            $Results.Add([PSCustomObject]@{
                    Comment = $Row.Comment
                    Status  = "Fehler: Antwortformat unbekannt"
                })
            Write-Host " FAILED (Format)" -ForegroundColor Red
        }
    }
}

# 4. Ergebnisse exportieren
$Results | Export-Csv -Path $FinalOutputCsv -Delimiter ";" -NoTypeInformation -Encoding utf8
Write-Host "Verarbeitung abgeschlossen. Ergebnisse gespeichert in: $($FinalOutputCsv)" -ForegroundColor Cyan

# 5. Eingabedatei umbenennen
Rename-Item -Path $InputCsv -NewName $NewInputFileName
Write-Host "Eingabedatei wurde erfolgreich umbenannt zu: $($NewInputFileName)" -ForegroundColor Cyan