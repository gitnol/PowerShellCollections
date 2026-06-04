<#
.SYNOPSIS
    Gleicht BitLocker-Recovery-Informationen aus dem Active Directory mit den lokalen Systemen massiv parallel ab.

.DESCRIPTION
    Dieses Skript führt ein Audit der BitLocker-Wiederherstellungsschlüssel durch. Es kombiniert 
    AD-Abfragen mit parallelen Online-Prüfungen und massiv parallelen WMI-Abfragen via Invoke-Command, 
    um die Laufzeit drastisch zu reduzieren.
    
    Ablauf:
    1. Liest alle im AD gespeicherten msFVE-RecoveryInformation Objekte für Windows-Computer aus.
    2. Prüft den Online-Status dieser Computer über parallele Hintergrundjobs, um WMI-Timeouts zu vermeiden.
    3. Fragt bei allen als "online" erkannten Computern gleichzeitig (via Invoke-Command) das lokale BitLocker-Passwort für Laufwerk C: ab.
    4. Vergleicht die AD-Werte mit den lokalen Werten und gibt das Ergebnis sowie Detailtabellen in Out-GridView aus.

.EXAMPLE
    .\Compare-BitlockerInfos.ps1
    Führt das gesamte Skript ohne Parameter aus und öffnet am Ende drei GridViews mit den Ergebnissen.

.NOTES
    Voraussetzungen: 
    - ActiveDirectory PowerShell-Modul muss geladen/installiert sein.
    - WinRM/PowerShell Remoting muss auf den Ziel-Clients aktiviert sein, damit Invoke-Command funktioniert.
    - Berechtigungen zum Lesen der AD-BitLocker-Objekte sowie lokale Admin-Rechte auf den Ziel-Clients.
#>

# CmdletBinding für erweiterte Parameter-Unterstützung (z.B. -Verbose, -Debug)
[CmdletBinding()]
param()

# -----------------------------------------------------------------------------
# FUNKTION: Parallele Online-Prüfung
# -----------------------------------------------------------------------------
function Get-ComputerOnlineStatus {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $True, ValueFromPipeline = $true)]
        [string[]]$Computers,
        
        [ValidateRange(1, [int]::MaxValue)]
        [int]$numberConcurrentJobs = 32,
        
        [ValidateRange(1, [int]::MaxValue)]
        [int]$pingCounts = 1
    )

    $jobs = @()
    $totalComputers = $Computers.Count
    $jobsStarted = 0

    foreach ($computer in $Computers) {
        # Drosselung: Warten, wenn die maximale Anzahl gleichzeitiger Jobs erreicht ist
        while ((Get-Job -State Running).Count -ge $numberConcurrentJobs) {
            $now = Get-Date
            foreach ($job in (Get-Job -State Running)) {
                # Timeout-Kontrolle: Jobs nach 2 Minuten abbrechen
                if ($now - (Get-Job -Id $job.Id).PSBeginTime -gt [TimeSpan]::FromMinutes(2)) {
                    Stop-Job $job
                    Write-Host ("Job {0} wegen Timeout gestoppt." -f $job.Id) -ForegroundColor Yellow
                }
            }
            Start-Sleep -Milliseconds 500
        }

        # Starten des Ping-Jobs im Hintergrund
        $jobs += Start-Job -ScriptBlock {
            # Zuweisung von $using Variablen in eigene lokale Variablen 
            $lokalerComputer = $using:computer
            $lokalerPingCount = $using:pingCounts

            $isOnline = Test-Connection -ComputerName $lokalerComputer -Count $lokalerPingCount -Quiet
            
            # Rückgabe als PowerShell Custom Object
            [pscustomobject]@{
                Computer = $lokalerComputer
                Online   = $isOnline
            }
        }

        $jobsStarted++
        Write-Progress -Activity "Prüfe Online-Status" -Status "$jobsStarted von $totalComputers" -PercentComplete (($jobsStarted / $totalComputers) * 100)
    }

    # Warten, bis alle verbleibenden Jobs abgeschlossen sind
    While ($jobs | Where-Object { $_.State -eq 'Running' }) {
        Start-Sleep -Seconds 1
    }

    # Ergebnisse einsammeln und aufräumen
    $results = $jobs | Receive-Job
    $jobs | Remove-Job

    return $results | Select-Object Computer, Online
}


# -----------------------------------------------------------------------------
# HAUPTSKRIPT
# -----------------------------------------------------------------------------

# --- Schritt 1: AD-Informationen abrufen ---
$AD_Bitlocker_Informationen = @()
# Aktive Windows-Computer ermitteln
$CompList = Get-ADComputer -Filter { OperatingSystem -like "*Windows*" -and Enabled -eq $true } -Properties Description

Write-Host "Schritt 1: Lese BitLocker-Recovery-Informationen aus dem AD..." -ForegroundColor Cyan

foreach ($CL in $CompList) {
    # Suche nach BitLocker-Recovery-Objekten unterhalb des Computer-Objekts im AD
    $Bitlocker_Objects = Get-ADObject -Filter { objectclass -eq 'msFVE-RecoveryInformation' } -SearchBase $CL.DistinguishedName -Properties 'msFVE-RecoveryPassword'
    
    foreach ($Obj in $Bitlocker_Objects) {
        $anzahlkeys = $Obj.'msFVE-RecoveryPassword'.Count
        
        # Parsen des DistinguishedName zur Ermittlung von KeyID und Zeitstempel
        $dnTeil1 = ($Obj.DistinguishedName -split ",")[0]
        $keyID = ($dnTeil1 -split '{')[1] -replace '}', ''
        $rawDate = ($dnTeil1 -split '{')[0] -replace 'CN=', '' -replace '\\', ''
        
        $parsedDate = [DateTime]::MinValue
        if (-not [string]::IsNullOrWhiteSpace($rawDate)) {
            $parsedDate = [DateTime]::Parse($rawDate)
        }

        $AD_Bitlocker_Informationen += [PSCustomObject]@{
            Computername                  = $CL.Name
            Beschreibung                  = $CL.Description
            BitlockerKeyCount             = $anzahlkeys
            BitlockerKeyRecoveryPasswords = $Obj.'msFVE-RecoveryPassword'
            ComputerDistinguishedName     = $CL.DistinguishedName
            msFVE_DN_KeyID                = $keyID
            msFVE_DN_TimeStamp            = $parsedDate
        }
    }
}


# --- Schritt 2: Online-Status prüfen ---
# Filtere nur die Rechner heraus, die auch Schlüssel im AD hinterlegt haben
$RechnerMitKeys = $AD_Bitlocker_Informationen | Where-Object { $_.BitlockerKeyCount -gt 0 } | Select-Object -ExpandProperty Computername -Unique

Write-Host ("Schritt 2: Prüfe Online-Status von {0} Computern..." -f $RechnerMitKeys.Count) -ForegroundColor Cyan
$OnlineStatus = Get-ComputerOnlineStatus -Computers $RechnerMitKeys -numberConcurrentJobs 40
$OnlineRechner = ($OnlineStatus | Where-Object { $_.Online -eq $true }).Computer


# --- Schritt 3: Lokale Informationen massiv parallel abrufen ---
$OnlineComputerBitlockerInfos = @()

if ($OnlineRechner.Count -gt 0) {
    Write-Host ("Schritt 3: Lade lokale BitLocker-Daten von {0} Online-Computern (massiv parallel)..." -f $OnlineRechner.Count) -ForegroundColor Cyan
    
    $scriptBlockBitlocker = {
        # Ruft das BitLocker-Volume für C: ab. Fehler werden unterdrückt, falls unverschlüsselt.
        $bitlockerVolume = Get-BitLockerVolume -MountPoint "C:" -ErrorAction SilentlyContinue
        
        # Prüft mittels klassischem If-Else, ob ein Volume gefunden wurde
        if ($bitlockerVolume) {
            $recoveryPwd = ($bitlockerVolume.KeyProtector | Where-Object { $_.KeyProtectorType -eq 'RecoveryPassword' }).RecoveryPassword
            [PSCustomObject]@{
                Lokales_RecoveryPassword = $recoveryPwd
                VolumeStatus_C           = $bitlockerVolume.VolumeStatus
            }
        }
        else {
            [PSCustomObject]@{
                Lokales_RecoveryPassword = $null
                VolumeStatus_C           = "Nicht gefunden/verschlüsselt"
            }
        }
    }

    # Führt den Scriptblock asynchron und parallel auf allen definierten Online-Computern aus
    $LokaleAbfragen = Invoke-Command -ComputerName $OnlineRechner -ScriptBlock $scriptBlockBitlocker -ThrottleLimit 50 -ErrorAction SilentlyContinue
    
    foreach ($Resultat in $LokaleAbfragen) {
        $OnlineComputerBitlockerInfos += [PSCustomObject]@{
            Computername             = $Resultat.PSComputerName
            Lokales_RecoveryPassword = $Resultat.Lokales_RecoveryPassword
            VolumeStatus_C           = $Resultat.VolumeStatus_C
        }
    }
}


# --- Schritt 4: Daten vergleichen ---
Write-Host "Schritt 4: Vergleiche AD-Daten mit lokalen Daten..." -ForegroundColor Cyan
$Ergebnis = @()

foreach ($LocalInfo in $OnlineComputerBitlockerInfos) {
    $aktueller_computer = $LocalInfo.Computername
    $aktuelles_bitlockerpasswort = $LocalInfo.Lokales_RecoveryPassword
    
    # Sucht alle AD-Einträge, die zu dem aktuellen lokalen Rechner passen
    $MatchInAD = $AD_Bitlocker_Informationen | Where-Object { $_.Computername -eq $aktueller_computer }
    
    foreach ($Eintrag in $MatchInAD) {
        $identisch = $false
        
        # Vergleicht die Passwörter mithilfe einer If-Else Abfrage (Vermeidung des Ternary-Operators)
        if ($Eintrag.BitlockerKeyRecoveryPasswords -eq $aktuelles_bitlockerpasswort) {
            $identisch = $true
        }
        else {
            $identisch = $false
        }

        $Ergebnis += [PSCustomObject]@{
            Computername              = $aktueller_computer
            AD_Bitlocker_Kennwort     = $Eintrag.BitlockerKeyRecoveryPasswords
            Lokales_Bitlockerpasswort = $aktuelles_bitlockerpasswort
            Identisch                 = $identisch
            VolumeStatus_C            = $LocalInfo.VolumeStatus_C
            msFVE_DN_KeyID            = $Eintrag.msFVE_DN_KeyID
            msFVE_DN_TimeStamp        = $Eintrag.msFVE_DN_TimeStamp
        }
    }
}


# --- AUSGABE ---
$AD_Bitlocker_Informationen | Out-GridView -Title "Alle Bitlocker Informationen aus dem AD"
$Ergebnis | Out-GridView -Title "Vergleichtabelle zwischen lokalen und AD Informationen"
$OnlineComputerBitlockerInfos | Out-GridView -Title "Alle Bitlockerinformationen von ONLINE Rechnern"

Write-Host "Skript erfolgreich beendet." -ForegroundColor Green