#Requires -Version 5.1
<#
.SYNOPSIS
Prueft eine heruntergeladene Datei anhand ihrer Signatur (GPG/OpenPGP und Authenticode).

.DESCRIPTION
Allgemeines Pruefwerkzeug fuer Downloads, die zusammen mit einer abgetrennten
Signaturdatei (.sig, .asc, .gpg) veroeffentlicht werden - z. B. Notepad++,
7-Zip-Mirror, Linux-ISOs, Git-Releases.

Es werden bis zu drei unabhaengige Pruefungen durchgefuehrt:

  1. GPG        Abgetrennte OpenPGP-Signatur gegen die Datei (gpg --verify).
                Der oeffentliche Schluessel kommt aus -PublicKeyFile, dem
                vorhandenen Schluesselbund oder - nur mit -Fetch - von einem
                Keyserver.
  2. Authenticode  Eingebettete Windows-Signatur (exe, dll, msi, ps1 ...).
                Eine unsignierte Datei ist kein Fehler, sondern wird gemeldet.
  3. SHA-256    Nur wenn -ExpectedSha256 angegeben ist.

WICHTIG zur Vertrauensfrage: Eine "gute" GPG-Signatur beweist nur, dass die
Datei zu DIESEM Schluessel passt - nicht, dass der Schluessel dem Hersteller
gehoert. Ein per -Fetch geholter Schluessel ist deshalb unbelegt. Mit
-ExpectedFingerprint (aus einer zweiten, offiziellen Quelle) wird das
erzwungen; ohne diesen Parameter lautet das Ergebnis hoechstens WARN.

Alle GPG-Arbeiten laufen in einem temporaeren Schluesselbund, der danach
geloescht wird. Der Benutzer-Schluesselbund (~/.gnupg) wird nicht veraendert.

Es wird nichts installiert oder ausgefuehrt; die gepruefte Datei wird nur
gelesen.

.PARAMETER Path
Zu pruefende Datei.

.PARAMETER SignaturePath
Abgetrennte Signaturdatei. Ohne Angabe wird nach <Path>.sig, .asc, .gpg
gesucht; gibt es keine, laufen nur Authenticode und ggf. SHA-256.

.PARAMETER PublicKeyFile
Datei mit dem oeffentlichen Schluessel (ASCII-armored oder binaer).

.PARAMETER ExpectedFingerprint
Erwarteter Fingerabdruck des Signaturschluessels (40 Hex-Zeichen, Leerzeichen
erlaubt). Weicht der echte ab, ist das Ergebnis FAIL.

.PARAMETER Fetch
Erlaubt, den fehlenden oeffentlichen Schluessel per Fingerabdruck von einem
Keyserver zu holen (Netzzugriff, nur der Fingerabdruck wird uebertragen).

.PARAMETER KeyServer
Basis-URL eines HKP-ueber-HTTPS-Keyservers. Standard: https://keyserver.ubuntu.com

.PARAMETER ExpectedSha256
Erwarteter SHA-256-Hash der Datei (optional).

.PARAMETER GpgPath
Pfad zu gpg.exe. Ohne Angabe: PATH, Gpg4win, Git for Windows.

.EXAMPLE
.\Test-FileSignature.ps1 -Path .\npp.8.9.9.Installer.x64.exe -SignaturePath .\npp.8.9.9.Installer.x64.exe.sig -Fetch

Prueft GPG (Schluessel vom Keyserver) und Authenticode. Ergebnis WARN, weil der
Schluessel nicht gegen eine zweite Quelle abgeglichen wurde.

.EXAMPLE
.\Test-FileSignature.ps1 .\app.exe .\app.exe.sig -Fetch -ExpectedFingerprint '14BC E436 2749 B2B5 1F8C 7122 6C42 9F1D 8D84 F46E'

Wie oben, aber der Schluessel muss den angegebenen Fingerabdruck haben: Ergebnis OK.

.EXAMPLE
.\Test-FileSignature.ps1 .\debian.iso .\debian.iso.sign -PublicKeyFile .\release-key.asc

Schluessel liegt lokal vor, kein Netzzugriff.

.OUTPUTS
PSCustomObject mit Ergebnis (OK, WARN, FAIL) und den Einzelbefunden.
Rueckgabewerte sind auch als Prozess-Exitcode nutzbar: 0 OK, 1 WARN, 2 FAIL
(nur beim Aufruf als Skript mit -ExitCode).
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory, Position = 0)]
    [string]$Path,

    [Parameter(Position = 1)]
    [string]$SignaturePath,

    [string]$PublicKeyFile,

    [string]$ExpectedFingerprint,

    [switch]$Fetch,

    [string]$KeyServer = 'https://keyserver.ubuntu.com',

    [string]$ExpectedSha256,

    [string]$GpgPath,

    [switch]$ExitCode
)

Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'

function Find-Gpg {
    param([string]$Explicit)
    if ($Explicit) {
        if (Test-Path -LiteralPath $Explicit) { return (Resolve-Path -LiteralPath $Explicit).Path }
        throw "gpg nicht gefunden: $Explicit"
    }
    $cmd = Get-Command gpg.exe -ErrorAction SilentlyContinue
    if ($cmd) { return $cmd.Source }
    $candidates = @(
        "${env:ProgramFiles(x86)}\GnuPG\bin\gpg.exe",
        "$env:ProgramFiles\GnuPG\bin\gpg.exe",
        "$env:ProgramFiles\Git\usr\bin\gpg.exe",
        "${env:ProgramFiles(x86)}\Git\usr\bin\gpg.exe"
    )
    foreach ($c in $candidates) { if ($c -and (Test-Path -LiteralPath $c)) { return $c } }
    return $null
}

# gpg aus Git for Windows (MSYS) versteht "C:/x" nicht als absoluten Pfad und
# haengt das Arbeitsverzeichnis davor; dort ist "/c/x" noetig. Gpg4win (nativ)
# versteht "C:/x" und kein "/c/x".
$script:GpgIsMsys = $false
function ConvertTo-GpgPath {
    param([string]$P)
    $p2 = $P -replace '\\', '/'
    if ($script:GpgIsMsys -and $p2 -match '^([A-Za-z]):/(.*)$') {
        return '/' + $Matches[1].ToLowerInvariant() + '/' + $Matches[2]
    }
    return $p2
}

function Invoke-Gpg {
    param([string]$Gpg, [string[]]$Arguments)
    $old = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'   # stderr von nativen Programmen ist kein Abbruchgrund
    try { $out = & $Gpg @Arguments 2>&1 } finally { $ErrorActionPreference = $old }
    return @($out | ForEach-Object { "$_" })
}

function Format-Fingerprint {
    param([string]$F)
    if (-not $F) { return '' }
    $f = ($F -replace '\s', '').ToUpperInvariant()
    return (($f -split '(.{4})' | Where-Object { $_ }) -join ' ')
}

# --- Eingaben pruefen --------------------------------------------------------
if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { throw "Datei nicht gefunden: $Path" }
$file = (Resolve-Path -LiteralPath $Path).Path

if (-not $SignaturePath) {
    foreach ($ext in '.sig', '.asc', '.gpg') {
        if (Test-Path -LiteralPath ($file + $ext)) { $SignaturePath = $file + $ext; break }
    }
}
if ($SignaturePath -and -not (Test-Path -LiteralPath $SignaturePath -PathType Leaf)) {
    throw "Signaturdatei nicht gefunden: $SignaturePath"
}
if ($SignaturePath) { $SignaturePath = (Resolve-Path -LiteralPath $SignaturePath).Path }

$expFpr = if ($ExpectedFingerprint) { ($ExpectedFingerprint -replace '\s', '').ToUpperInvariant() } else { $null }
if ($expFpr -and $expFpr -notmatch '^[0-9A-F]{40}$') {
    throw 'ExpectedFingerprint muss 40 Hex-Zeichen haben (v4-Fingerabdruck).'
}

$findings = New-Object System.Collections.Generic.List[string]
$level = 0   # 0 OK, 1 WARN, 2 FAIL
function Set-Level { param([int]$L) if ($L -gt $script:level) { $script:level = $L } }

# --- Hash --------------------------------------------------------------------
$sha = (Get-FileHash -LiteralPath $file -Algorithm SHA256).Hash
if ($ExpectedSha256) {
    $exp = ($ExpectedSha256 -replace '\s', '').ToUpperInvariant()
    if ($exp -eq $sha) { $shaState = 'Uebereinstimmung' }
    else { $shaState = 'ABWEICHUNG'; Set-Level 2; $findings.Add("SHA-256 weicht ab (erwartet $exp).") }
}
else { $shaState = 'nicht angefordert' }

# --- Authenticode ------------------------------------------------------------
$authState = 'nicht verfuegbar'; $authSigner = ''; $authThumb = ''
if (Get-Command Get-AuthenticodeSignature -ErrorAction SilentlyContinue) {
    $a = Get-AuthenticodeSignature -LiteralPath $file
    $authState = "$($a.Status)"
    if ($a.SignerCertificate) {
        $authSigner = $a.SignerCertificate.Subject
        $authThumb = $a.SignerCertificate.Thumbprint
    }
    switch ($authState) {
        'Valid'     { }
        'NotSigned' { }   # bei .zip/.iso usw. normal; Bewertung ueber GPG
        default     { Set-Level 2; $findings.Add("Authenticode: $authState - $($a.StatusMessage)") }
    }
}

# --- GPG ---------------------------------------------------------------------
$gpgState = 'keine Signaturdatei'; $gpgFpr = ''; $gpgSigner = ''; $gpgCreated = ''; $keySource = ''
if ($SignaturePath) {
    $gpg = Find-Gpg -Explicit $GpgPath
    if (-not $gpg) {
        $gpgState = 'gpg fehlt'
        Set-Level 2
        $findings.Add('gpg.exe nicht gefunden (Gpg4win oder Git for Windows installieren, oder -GpgPath angeben).')
    }
    else {
        $script:GpgIsMsys = ($gpg -match '[\\/]usr[\\/]bin[\\/]gpg\.exe$')
        $home_ = Join-Path ([IO.Path]::GetTempPath()) ('fsig_' + [guid]::NewGuid().ToString('N'))
        New-Item -ItemType Directory -Path $home_ -Force | Out-Null
        $homeArg = ConvertTo-GpgPath $home_
        $base = @('--homedir', $homeArg, '--batch', '--no-tty', '--no-autostart')
        try {
            # Fingerabdruck des Signierers aus dem Signaturpaket lesen
            $pk = Invoke-Gpg $gpg ($base + @('--list-packets', (ConvertTo-GpgPath $SignaturePath)))
            $issuer = $null
            foreach ($l in $pk) {
                if ($l -match 'issuer fpr v4\s+([0-9A-Fa-f]{40})') { $issuer = $Matches[1].ToUpperInvariant(); break }
            }
            if (-not $issuer) {
                foreach ($l in $pk) { if ($l -match 'keyid\s+([0-9A-Fa-f]{16})') { $issuer = $Matches[1].ToUpperInvariant(); break } }
            }

            # Schluessel beschaffen
            $keyFile = $null
            if ($PublicKeyFile) {
                if (-not (Test-Path -LiteralPath $PublicKeyFile)) { throw "Schluesseldatei nicht gefunden: $PublicKeyFile" }
                $keyFile = (Resolve-Path -LiteralPath $PublicKeyFile).Path
                $keySource = 'Datei'
            }
            elseif ($Fetch) {
                if (-not $issuer) { throw 'Signatur nennt keinen Schluessel - Abruf nicht moeglich.' }
                [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
                $keyFile = Join-Path $home_ 'key.asc'
                $url = ($KeyServer.TrimEnd('/')) + '/pks/lookup?op=get&search=0x' + $issuer
                Invoke-WebRequest -Uri $url -UseBasicParsing -OutFile $keyFile -TimeoutSec 30
                $keySource = "Keyserver ($KeyServer)"
            }
            elseif ($env:GNUPGHOME -or (Test-Path (Join-Path $HOME '.gnupg'))) {
                # vorhandenen Benutzer-Schluesselbund nur lesend verwenden
                $keySource = 'Benutzer-Schluesselbund'
            }

            if ($keyFile) {
                [void](Invoke-Gpg $gpg ($base + @('--import', (ConvertTo-GpgPath $keyFile))))
                $verBase = $base
            }
            elseif ($keySource -eq 'Benutzer-Schluesselbund') {
                $verBase = @('--batch', '--no-tty', '--no-autostart')
            }
            else { $verBase = $base }

            $v = Invoke-Gpg $gpg ($verBase + @('--status-fd', '1', '--verify',
                    (ConvertTo-GpgPath $SignaturePath), (ConvertTo-GpgPath $file)))
            $status = @($v | Where-Object { $_ -match '^\[GNUPG:\]' })

            $good = $status | Where-Object { $_ -match '\[GNUPG:\] GOODSIG\s+(\S+)\s+(.*)$' } | Select-Object -First 1
            $valid = $status | Where-Object { $_ -match '\[GNUPG:\] VALIDSIG\s+([0-9A-Fa-f]{40})\s+(\S+)' } | Select-Object -First 1
            if ($good -and $good -match 'GOODSIG\s+(\S+)\s+(.*)$') { $gpgSigner = $Matches[2] }
            if ($valid -and $valid -match 'VALIDSIG\s+([0-9A-Fa-f]{40})\s+(\S+)') {
                $gpgFpr = $Matches[1].ToUpperInvariant()
                $gpgCreated = $Matches[2]
            }

            if     ($status -match '\[GNUPG:\] BADSIG')     { $gpgState = 'UNGUELTIG (Datei veraendert oder falsche Signatur)'; Set-Level 2 }
            elseif ($status -match '\[GNUPG:\] NO_PUBKEY')  { $gpgState = 'Schluessel fehlt'; Set-Level 2
                $findings.Add("Oeffentlicher Schluessel nicht vorhanden (Signierer $issuer). -PublicKeyFile oder -Fetch verwenden.") }
            elseif ($status -match '\[GNUPG:\] REVKEYSIG')  { $gpgState = 'Schluessel WIDERRUFEN'; Set-Level 2 }
            elseif ($status -match '\[GNUPG:\] ERRSIG')     { $gpgState = 'Pruefung fehlgeschlagen'; Set-Level 2 }
            elseif ($good -and $valid) {
                $gpgState = 'Gueltig'
                if ($status -match '\[GNUPG:\] EXPKEYSIG') {
                    $gpgState = 'Gueltig, Schluessel abgelaufen'; Set-Level 1
                    $findings.Add('Signaturschluessel ist abgelaufen.')
                }
                elseif ($status -match '\[GNUPG:\] EXPSIG') {
                    $gpgState = 'Gueltig, Signatur abgelaufen'; Set-Level 1
                }
                if ($expFpr) {
                    if ($gpgFpr -ne $expFpr) {
                        # Fingerabdruck des Hauptschluessels kann abweichen (Unterschluessel)
                        $primary = $null
                        if ($valid -match 'VALIDSIG(?:\s+\S+){8}\s+([0-9A-Fa-f]{40})') { $primary = $Matches[1].ToUpperInvariant() }
                        if ($primary -and $primary -eq $expFpr) { }
                        else { $gpgState = 'Gueltig, aber FALSCHER Schluessel'; Set-Level 2
                            $findings.Add("Fingerabdruck $gpgFpr weicht vom erwarteten $expFpr ab.") }
                    }
                }
                elseif ($keySource -ne 'Datei') {
                    Set-Level 1
                    $findings.Add('Schluessel-Echtheit nicht belegt: Fingerabdruck mit offizieller Quelle abgleichen oder -ExpectedFingerprint angeben.')
                }
                else {
                    Set-Level 1
                    $findings.Add('Kein -ExpectedFingerprint angegeben: Herkunft der Schluesseldatei selbst pruefen.')
                }
            }
            else {
                $gpgState = 'unklar'; Set-Level 2
                $findings.Add('gpg lieferte kein eindeutiges Ergebnis: ' + (($v | Select-Object -First 3) -join ' | '))
            }
        }
        finally {
            # gpg-agent/keyboxd halten das Verzeichnis offen
            try {
                if (Test-Path (Join-Path (Split-Path $gpg) 'gpgconf.exe')) {
                    [void](Invoke-Gpg (Join-Path (Split-Path $gpg) 'gpgconf.exe') @('--homedir', $homeArg, '--kill', 'all'))
                }
            } catch { }
            Start-Sleep -Milliseconds 300
            Remove-Item -LiteralPath $home_ -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}
elseif ($authState -in 'NotSigned', 'nicht verfuegbar' -and -not $ExpectedSha256) {
    Set-Level 1
    $findings.Add('Weder Signaturdatei noch Authenticode noch Hash vorhanden - nichts belegt.')
}

# --- Ergebnis ----------------------------------------------------------------
$names = @('OK', 'WARN', 'FAIL')
$result = [pscustomobject][ordered]@{
    Ergebnis         = $names[$level]
    Datei            = $file
    Groesse          = (Get-Item -LiteralPath $file).Length
    SHA256           = $sha
    SHA256Pruefung   = $shaState
    GpgStatus        = $gpgState
    GpgFingerprint   = (Format-Fingerprint $gpgFpr)
    GpgSignierer     = $gpgSigner
    GpgErstellt      = $gpgCreated
    GpgSchluesselQuelle = $keySource
    AuthenticodeStatus  = $authState
    AuthenticodeSigner  = $authSigner
    AuthenticodeThumbprint = $authThumb
    Hinweise         = @($findings)
}

$color = @('Green', 'Yellow', 'Red')[$level]
Write-Host ("Ergebnis: {0}  -  {1}" -f $names[$level], (Split-Path $file -Leaf)) -ForegroundColor $color
Write-Host ("  SHA-256 : {0}  [{1}]" -f $sha, $shaState)
Write-Host ("  GPG     : {0}" -f $gpgState)
if ($gpgFpr) { Write-Host ("            {0}  {1}  (Schluessel: {2})" -f (Format-Fingerprint $gpgFpr), $gpgSigner, $keySource) }
Write-Host ("  Authenticode: {0}  {1}" -f $authState, $authSigner)
foreach ($f in $findings) { Write-Host "  ! $f" -ForegroundColor $color }

if ($ExitCode) { exit $level }
$result
