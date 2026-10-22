# Remote Execution – PowerShellCollections

Rund ein Fünftel der Sammlung führt Code auf entfernten Windows-Rechnern aus: rund 30 Skripte in 18 Themenordnern nutzen
`Invoke-Command`, `New-PSSession` oder CIM-Sessions (Stand 2026-10-11), dazu kommen Remote-Registry- und
Eventlog-Abfragen. SSH/SCP auf Linux-Ziele kommt im Bestand nicht vor — der entsprechende Template-Abschnitt ist
gestrichen; bei Bedarf aus `docs_template` (`stacks/powershell-automation/architecture/REMOTE_EXECUTION.md`) ergänzen.

---

## Ziel-Systeme

Hosts sind immer Parameter (`-ComputerName`) oder kommen aus AD (`Get-ADComputer`); konkrete Namen nie im Repo.

| Hostname / Typ | Verbindungsart | Auth-Verfahren | Remote-Aktion |
|----------------|---------------|---------------|--------------|
| Domänenrechner (Clients/Server), oft alle aus AD | WinRM (`Invoke-Command -ComputerName … -ThrottleLimit`) | Kerberos, Konto des Administrators | Abfragen (Sessions, Prozesse, Dienste, Software, BitLocker, Secure Boot) und Änderungen (Registry, Dienste, Profile, TeamViewer-Zugriff) |
| Domänenrechner | CIM-Session (WSMan/DCOM) | Kerberos | WMI-Abfragen (`Get-LoggedInUsersCim.ps1`, Inventar) |
| Domänenrechner | Remote-Registry, Eventlog-Remotezugriff | Kerberos | Registry-Werte, Anmelde-/Sperr-Events |
| Domain Controller | WinRM / Eventlog | Kerberos | Anmelde- und Lockout-Events aller DCs |
| Exchange Server | Remote-PowerShell `http://<server>/PowerShell/` | Kerberos | Postfachabfragen und -berechtigungen |
| SQL-Server-Hosts | WinRM | Kerberos | Instanzversionen (`Get-SqlServerVersion.ps1`) |
| Zielrechner für Installationen | Admin-Freigabe `\\<host>\C$` + WinRM | Kerberos | Installer kopieren und starten (`Install-FalconSensor.ps1`) |

---

## WinRM (Windows → Windows)

### Voraussetzungen auf Zielserver

```powershell
# WinRM aktivieren (einmalig, auf Zielserver, als Admin) — in Domänen üblich per GPO
Enable-PSRemoting -Force

# Verbindungstest vom Verwaltungs-PC
Test-WSMan -ComputerName SRV01
```

Für Läufe über viele Rechner vorher die Erreichbarkeit prüfen (`Test-ConnectionInParallel` bzw.
`Get-ComputerOnlineStatus` aus `modules/PSCollections.Connectivity`) und nur die erreichbaren Ziele an
`Invoke-Command` geben — so arbeiten `Get-BitLockerStatus.ps1` und `Set-TeamViewerAccess.ps1`.

### Variablen in remote ScriptBlocks

```powershell
# Lokale Variable → $using: Prefix
$LocalVariable = "wert"
Invoke-Command -ComputerName SRV01 -ScriptBlock {
    Write-Output $using:LocalVariable   # korrekt
    Write-Output $LocalVariable         # FEHLER: im remote Scope nicht definiert
}
```

**Lokale Funktionen sind in remote ScriptBlocks nicht verfügbar.**
Wenn eine Funktion remote ausgeführt werden soll:

```powershell
# Option A: Funktionsdefinition als String übergeben und per ScriptBlock neu definieren
$FunctionDef = ${function:Get-LocalInfo}
Invoke-Command -ComputerName SRV01 -ScriptBlock {
    $Function = [ScriptBlock]::Create($using:FunctionDef)
    . $Function
    Get-LocalInfo -Param "wert"
}

# Option B: eigenständig lauffähige Datei per FilePath ausführen
Invoke-Command -ComputerName SRV01 -FilePath ".\Invoke-SecureBootCertUpdate.ps1" -ArgumentList $Param
```

Option A bei kleinen Hilfsfunktionen (< 20 Zeilen), Option B bei Skripten, die auf dem Zielrechner eigenständig
laufen müssen. Variante im Bestand: `Invoke-SecureBootCertUpdate.ps1` wird als Text gelesen und auf dem Ziel per
`[scriptblock]::Create($using:ScriptContent)` erzeugt (README des Themenordners). Solcher Code darf **keine**
Datei des Repos voraussetzen — kein `modules/`, kein `$PSScriptRoot`, keine gemeinsame `Write-Log`
(`docs/BACKLOG.md` Abschnitt 4). Nie lokale Funktionen in `Invoke-Command` aufrufen, ohne eine dieser Optionen
anzuwenden — der Fehler tritt erst zur Laufzeit auf, nicht bei der Syntaxprüfung.

### Fehlerbehandlung in remote ScriptBlocks

```powershell
# Fehler je Ziel als Ergebnisobjekt zurückgeben, statt den ganzen Lauf abzubrechen
$results = Invoke-Command -ComputerName $TargetHosts -ThrottleLimit 20 -ScriptBlock {
    $ErrorActionPreference = 'Stop'
    Set-StrictMode -Version 3.0     # die Remote-Sitzung erbt beides nicht vom Aufrufer
    try {
        # ... Aktion ...
        [PSCustomObject]@{ ComputerName = $env:COMPUTERNAME; Status = 'OK'; Fehler = $null }
    }
    catch {
        [PSCustomObject]@{ ComputerName = $env:COMPUTERNAME; Status = 'Fehler'; Fehler = $_.Exception.Message }
    }
} -ErrorAction SilentlyContinue -ErrorVariable remoteErrors

# Verbindungsfehler (Ziel nicht erreichbar) stehen in $remoteErrors, nicht in $results
```

**Logging-Regel:** Logging-Funktionen nach dem `Invoke-Command`-Block aufrufen, nicht darin. Rückgabewerte aus dem
remote Block als Variable fangen und danach lokal loggen.

### PSSession für mehrere Operationen (Copy + Invoke)

```powershell
# Session einmal öffnen, für Copy-Item und Invoke-Command wiederverwenden
$Session = New-PSSession -ComputerName SRV01

try {
    Copy-Item -Path .\Setup.exe -Destination C:\Temp\ -ToSession $Session
    Invoke-Command -Session $Session -ScriptBlock {
        # ... Aktion mit kopierten Dateien ...
    }
}
finally {
    Remove-PSSession -Session $Session
}
```

Altbestand: `Install-FalconSensor.ps1` kopiert über die Admin-Freigabe `C$` statt `-ToSession` und entfernt den
Installer danach nicht (siehe Checkliste).

---

## Remote-Dateien und Cleanup

Temporäre Dateien, die remote kopiert werden (Installer, Skripte, Zertifikate), nach Verwendung löschen — im
`finally`-Teil:

```powershell
$RemoteFile = "C:\Temp\Setup.exe"
try {
    Copy-Item -Path .\Setup.exe -Destination C:\Temp\ -ToSession $Session
    Invoke-Command -Session $Session -ScriptBlock {
        # ... Aktion ...
    }
}
finally {
    Invoke-Command -Session $Session -ScriptBlock {
        if (Test-Path $using:RemoteFile) { Remove-Item $using:RemoteFile -Force }
    }
    Remove-PSSession -Session $Session
}
```

---

## Sicherheit

- **Reichweite:** Viele Skripte laufen gegen *alle* Rechner aus AD. Ein Fehler im Scriptblock wirkt auf die ganze
  Domäne — zustandsändernde Remote-Skripte brauchen `-WhatIf`/`SupportsShouldProcess` und einen Testlauf gegen
  einzelne Ziele (`security/THREAT_MODEL.md` Bedrohung 4).
- **Integrität des Skripttexts:** Was als Text gelesen und remote ausgeführt wird, läuft mit Admin-Rechten auf jedem
  Ziel. Das Arbeitsverzeichnis auf dem Verwaltungs-PC darf nur vom Administrator beschreibbar sein.
- **Exchange-Remoting über `http://`** ist mit Kerberos üblich (Nutzdaten werden auf WinRM-Ebene verschlüsselt);
  `-SkipCACheck`/`-SkipCNCheck` sind dabei wirkungslos und sollten nicht als Gewohnheit kopiert werden — bei
  `https://` würden sie die Zertifikatsprüfung abschalten.

---

## Checkliste vor Commit

- [ ] Alle `Invoke-Command`-Blöcke: lokale Variablen nur via `$using:` referenziert
- [ ] Lokale Funktionen (WriteLog, Helpers) nicht direkt in remote Blöcken aufgerufen
- [ ] `$ErrorActionPreference = 'Stop'` und `Set-StrictMode -Version 3.0` am Anfang jedes remote ScriptBlocks, Fehler als
      Ergebnisobjekt zurück
- [ ] Remote-Code setzt keine Repo-Dateien voraus (`modules/`, `$PSScriptRoot`)
- [ ] Erreichbarkeit vor dem Lauf geprüft; `-ThrottleLimit` gesetzt
- [ ] Zustandsändernde Remote-Aktionen mit `-WhatIf`/`SupportsShouldProcess`
- [ ] Temporäre Remote-Dateien in `finally`-Block bereinigt
- [ ] PSSession in `finally`-Block geschlossen (`Remove-PSSession`)
