# RemoteSessionLock

PowerShell-Modul, um Benutzersitzungen auf lokalen und entfernten
Windows-Rechnern abzufragen und zu sperren.

| Funktion                 | Zweck                                                      |
| ------------------------ | ---------------------------------------------------------- |
| `Get-RemoteSessionStatus` | listet Sitzungen samt Sperrzustand (nur lesend)           |
| `Lock-RemoteSession`      | sperrt offene Sitzungen (aendert den Zustand der Zielrechner) |

Datei: [RemoteSessionLock.psm1](RemoteSessionLock.psm1)

## Wichtig: "Sperren" heisst bei fremden Sitzungen "Trennen"

Eine fremde Sitzung laesst sich nicht per `LockWorkStation` sperren. Das Modul
**trennt** sie stattdessen (`WTSDisconnectSession`, entspricht `tsdiscon`):

| Fall                       | Wirkung                                                         |
| -------------------------- | --------------------------------------------------------------- |
| Konsolensitzung (remote)   | Bildschirm zeigt den Anmelde-/Sperrbildschirm                   |
| RDP-Sitzung                | RDP-Client des Benutzers wird getrennt, Neuverbindung moeglich  |
| Eigener Rechner, ohne Filter | echtes `LockWorkStation`, wie Win+L                           |

In allen Faellen bleibt die Sitzung mit allen Programmen erhalten; nichts wird
beendet und nichts geht verloren. Nur der Zugriff erfordert eine neue Anmeldung.

## Voraussetzungen

- Zielrechner: Windows 10/11 oder Windows Server 2016 und neuer. Unter
  Windows 7 / Server 2008 R2 meldet die WTS-API den Sperrzustand vertauscht.
- WinRM auf den Zielrechnern aktiv; das ausfuehrende Konto ist dort lokaler
  Administrator.
- PowerShell 5.1 oder neuer im `FullLanguage`-Modus (das Modul nutzt `Add-Type`).
  Unter AppLocker/WDAC (Constrained Language Mode) schlaegt die Ausfuehrung mit
  einer Warnung je Rechner fehl.
- ICMP (Ping) zu den Zielrechnern. Offline-Rechner werden vorab aussortiert.

## Technik in Kuerze

- Sitzungen, Sperrzustand und Trennen laufen ueber die WTS-API
  (`wtsapi32.dll`): sprachunabhaengig, kein Parsen von `quser`, kein
  `tsdiscon.exe`.
- Den Sperrzustand liefert `WTSSessionInfoEx` (SessionFlags) - keine
  `LogonUI.exe`-Heuristik.
- Online-Pruefung per ICMP fuer alle Rechner gleichzeitig, Remote-Ausfuehrung
  parallel per `Invoke-Command` (`-ThrottleLimit`).
- Der lokale Rechner wird direkt ausgefuehrt, ohne WinRM-Loopback.
- Die Datei ist reines ASCII und braucht daher kein BOM.

## Einrichten

```powershell
# Heruntergeladene Datei freigeben (sonst blockiert RemoteSigned sie)
Unblock-File -Path .\RemoteSessionLock.psm1

# Fuer die aktuelle Sitzung laden
Import-Module .\RemoteSessionLock.psm1

# Hilfe
Get-Help Lock-RemoteSession -Full
Get-Help Get-RemoteSessionStatus -Examples
```

Dauerhaft installieren (wird dann automatisch geladen):

```powershell
$Ziel = Join-Path $env:ProgramFiles 'WindowsPowerShell\Modules\RemoteSessionLock'
New-Item -Path $Ziel -ItemType Directory -Force | Out-Null
Copy-Item -Path .\RemoteSessionLock.psm1 -Destination $Ziel
```

## Status abfragen

```powershell
# Eigener Rechner
Get-RemoteSessionStatus

# Mehrere Rechner als Tabelle
Get-RemoteSessionStatus -ComputerName PC01, PC02, RDS01 | Format-Table -AutoSize

# Nur offene, ungesperrte Sitzungen
Get-RemoteSessionStatus -ComputerName PC01, PC02 | Where-Object { $_.Gesperrt -eq $false }

# Wo ist ein bestimmter Benutzer angemeldet?
Get-RemoteSessionStatus -ComputerName RDS01, RDS02 | Where-Object { $_.Benutzer -like 'm.muster*' }

# Rechnerliste aus einer Textdatei (ein Name pro Zeile)
Get-Content .\rechner.txt | Get-RemoteSessionStatus | Format-Table -AutoSize
```

Ausgabespalten: `ComputerName`, `Benutzer`, `Domaene`, `SessionID`, `Sitzung`,
`Status`, `Gesperrt`.

| `Gesperrt` | Bedeutung                                   |
| ---------- | ------------------------------------------- |
| `$true`    | Bildschirm gesperrt oder Sitzung getrennt   |
| `$false`   | Sitzung offen - hier waere zu sperren       |
| `$null`    | Zustand unbekannt oder keine Sitzung        |

## Sperren

`Lock-RemoteSession` hat `ConfirmImpact = High` und fragt deshalb vor dem
Sperren nach. Bereits gesperrte und getrennte Sitzungen werden nicht angefasst.

```powershell
# Immer zuerst ein Testlauf: zeigt nur, was passieren wuerde
Lock-RemoteSession -ComputerName PC01, PC02 -WhatIf

# Alle offenen Sitzungen sperren (mit Rueckfrage)
Lock-RemoteSession -ComputerName PC01, PC02

# Ohne Rueckfrage
Lock-RemoteSession -ComputerName PC01 -Confirm:$false

# Bestimmte Sitzungen auf einem Terminalserver
Lock-RemoteSession -ComputerName RDS01 -SessionId 4, 7

# Bestimmter Benutzer, mit oder ohne Domaene, Platzhalter erlaubt
Lock-RemoteSession -ComputerName PC01, PC02 -UserName 'CONTOSO\m.mustermann'
Lock-RemoteSession -ComputerName RDS01 -UserName 'azubi*'

# Eigenen Rechner sperren (wie Win+L)
Lock-RemoteSession
```

### Status abfragen und gezielt sperren

Per Pipeline werden `ComputerName` und `SessionID` paarweise uebernommen - es
werden also genau die uebergebenen Sitzungen gesperrt:

```powershell
Get-RemoteSessionStatus -ComputerName RDS01, RDS02 |
    Where-Object { $_.Gesperrt -eq $false -and $_.Benutzer -like 'azubi*' } |
    Lock-RemoteSession
```

> Filtere immer mit `$_.Gesperrt -eq $false`. Mit `-not $_.Gesperrt` rutschen
> Zeilen ohne Sitzung (`$null`) mit durch.

## Active Directory

```powershell
$Rechner = Get-ADComputer -Filter 'Enabled -eq $true' -SearchBase 'OU=Workstations,DC=contoso,DC=local' |
    Select-Object -ExpandProperty Name

# Ueberblick
$Rechner | Get-RemoteSessionStatus | Format-Table -AutoSize

# Alle offenen Sitzungen dieser OU sperren, vorher ein Testlauf
$Rechner | Lock-RemoteSession -WhatIf
$Rechner | Lock-RemoteSession -Confirm:$false
```

Gib nur die Namen weiter (`-ExpandProperty Name`), nicht die ganzen
AD-Objekte. Die haben sowohl `Name` als auch `DNSHostName`, und die Zuordnung
zum Parameter waere nicht eindeutig.

## Weitere Optionen

```powershell
# Anderes Admin-Konto
$Cred = Get-Credential 'CONTOSO\adm.mustermann'
Get-RemoteSessionStatus -ComputerName PC01 -Credential $Cred
Lock-RemoteSession -ComputerName PC01 -Credential $Cred -Confirm:$false

# Viele Rechner: mehr gleichzeitige Verbindungen, kuerzerer Ping-Timeout
$Rechner | Get-RemoteSessionStatus -ThrottleLimit 64 -PingTimeoutMs 500

# Offline- und Fehlermeldungen sammeln statt nur anzeigen
$Status = $Rechner | Get-RemoteSessionStatus -WarningVariable Probleme -WarningAction SilentlyContinue
$Probleme | ForEach-Object { $_.Message }
```

| Parameter        | Standard | Bereich   |
| ---------------- | -------- | --------- |
| `-ThrottleLimit` | 32       | 1 - 256   |
| `-PingTimeoutMs` | 1000     | 100 - 10000 |

## Export als CSV (UTF-8 ohne BOM)

```powershell
$Csv = Get-RemoteSessionStatus -ComputerName PC01, PC02 |
    ConvertTo-Csv -NoTypeInformation -Delimiter ';'
[System.IO.File]::WriteAllText('C:\Temp\Sitzungen.csv', ($Csv -join "`r`n"), [System.Text.UTF8Encoding]::new($false))
```

## Geplanter Task

Inhalt von `C:\Scripts\Sperren.ps1`:

```powershell
Import-Module RemoteSessionLock -ErrorAction Stop
Get-Content 'C:\Scripts\rechner.txt' | Lock-RemoteSession -Confirm:$false
```

Aufruf im Task:

```text
powershell.exe -NoProfile -NonInteractive -ExecutionPolicy RemoteSigned -File C:\Scripts\Sperren.ps1
```

Ohne `-Confirm:$false` bricht der Task wegen der Rueckfrage mit einem Fehler ab.
Das ist gewollt.

## Haeufige Warnungen

| Warnung                               | Ursache                                                    |
| ------------------------------------- | ---------------------------------------------------------- |
| `antwortet nicht auf ICMP`            | Rechner aus oder Ping durch die Firewall blockiert         |
| `Zugriff verweigert`                  | Konto ist auf dem Zielrechner kein lokaler Administrator   |
| `WinRM cannot complete the operation` | WinRM ist auf dem Zielrechner nicht aktiv                  |
| `Cannot add type`                     | AppLocker oder WDAC aktiv (eingeschraenkter Sprachmodus)   |

## Erster Test

Mit einem einzelnen Testrechner beginnen: `Get-RemoteSessionStatus` einmal bei
gesperrtem und einmal bei offenem Bildschirm aufrufen und pruefen, ob
`Gesperrt` stimmt - erst dann `Lock-RemoteSession` einsetzen.
