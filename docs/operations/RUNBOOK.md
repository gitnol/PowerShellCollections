# Runbook – PowerShellCollections

Häufige Operationen und Troubleshooting beim Einsatz und bei der Pflege der Skriptsammlung. Es gibt kein
Hauptskript; die Befehle unten gelten für jedes Skript sinngemäß.

---

## Häufige Commands

```powershell
# Skript finden und Hilfe lesen, ohne es zu laden
Select-String -Path .\INDEX.md -Pattern 'bitlocker'
Get-Help .\scripts\security\bitlocker\Get-BitLockerStatus.ps1 -Full

# Testlauf ohne Änderungen (nur Skripte mit SupportsShouldProcess)
.\scripts\<system>\<thema>\<Skript>.ps1 -WhatIf

# Ausführliches Logging aktivieren
.\scripts\<system>\<thema>\<Skript>.ps1 -Verbose

# Fehlerdetails anzeigen
$Error[0] | Format-List * -Force

# Strukturfehler finden, die der Parser nicht meldet (KNOWN_ISSUES.md K1/K3)
Invoke-ScriptAnalyzer -Path .\scripts -Recurse -Severity ParseError
```

---

## Troubleshooting

### "cannot be loaded because running scripts is disabled"
```
.\script.ps1 : File cannot be loaded because running scripts is disabled on this system.
```
→ Execution Policy setzen (einmalig):
```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```
→ In Task Scheduler: `-ExecutionPolicy Bypass` als PowerShell-Argument (so in den Schattenkopie-Aufgaben)

### Umlaute kaputt, Regex mit Umlauten findet nichts (Windows PowerShell 5.1)
Symptom: Ausgabe `PrÃ¼fe` statt `Prüfe`; Auswertung deutschsprachiger Eventlog-Texte liefert still keine Treffer.
→ Datei hat kein UTF-8-BOM. Prüfen und reparieren:
```powershell
.\tools\Repair-ScriptEncoding.ps1 -WhatIf
.\tools\Repair-ScriptEncoding.ps1
```

### Modul nicht gefunden
```
The term 'Test-ConnectionInParallel' is not recognized as the name of a cmdlet
```
→ Skript wurde ohne den Repo-Baum kopiert: der Import sucht `modules/` nach oben vom Skriptordner aus. Skript im Klon
  starten oder `modules/` mitkopieren.
→ Externes Modul: `Get-Module -Name <Modul> -ListAvailable`; fehlende RSAT-Features bzw. Module laut
  `architecture/DEPENDENCIES.md` installieren (Scope beachten: `CurrentUser` für interaktive Läufe).

### `begin`/`process` „nicht erkannt" bzw. `Get-Process`-Fehler beim Start
→ Code steht vor den benannten Blöcken (`KNOWN_ISSUES.md` K1). Bis zum Fix den Stand vor Commit `3778de1` verwenden.

### WinRM-Ziele antworten nicht
```
Connecting to remote server SRV01 failed … WinRM cannot complete the operation
```
→ `Test-WSMan -ComputerName SRV01`; Firewall/GPO für WinRM prüfen; Rechner überhaupt online
  (`Test-ConnectionInParallel`)? In Mehrrechner-Läufen erscheinen solche Ziele als „offline" im Ergebnis, der Lauf
  geht weiter.

### Credentials fehlen / falsch
```
401 Unauthorized / 403 Forbidden / "Access denied"
```
→ Interaktiv eingegebene Zugangsdaten korrekt? Token abgelaufen (Zammad)?
→ Für AD/WinRM: Rechte des angemeldeten Kontos auf dem Ziel (`security/AUTHENTICATION.md`)
→ Zertifikatsfehler bei Geräten mit selbstsigniertem Zertifikat: Zertifikat vertrauen, nicht die Prüfung abschalten
  (`security/THREAT_MODEL.md` Bedrohung 2)

### `Out-GridView` nicht verfügbar
→ In nicht-interaktiven Sitzungen (Invoke-Command, geplante Aufgabe) gibt es keine GUI. PowerShell 7.0–7.3 brauchte
  dafür `Microsoft.PowerShell.GraphicalTools` (`docs/BACKLOG.md` Abschnitt 9). Ausgabe stattdessen in die Pipeline
  oder per `Export-Csv`.

### Pre-commit-Hook bricht ab
→ Meldung „schuetzenswerte Inhalte gefunden": Zeile durch Platzhalterwerte ersetzen (`docs/CONVENTIONS.md` §11);
  echter Platzhalter in Beispielcode, den die Regex nicht unterscheiden kann → `allowlist secret` im Kommentar
  derselben Zeile. Bypass (`--no-verify`) nur bewusst.
→ Hinweis „forbidden-patterns.local.txt fehlt": lokale Liste anlegen (`operations/SETUP.md`).

### Task Scheduler: Aufgabe läuft manuell, aber nicht automatisch
→ Konto der Aufgabe (`SYSTEM` bei den Schattenkopien) und „Mit höchsten Privilegien" prüfen
→ PowerShell-Pfad explizit angeben: `C:\Program Files\PowerShell\7\pwsh.exe` (PS7) oder `%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe` (PS5)
→ Ereignisanzeige → Microsoft-Windows-TaskScheduler/Operational; Details `operations/TASK_SCHEDULER.md`

### `schtasks /create /xml` meldet ein ungültiges XML
→ Die UTF-16-Aufgabendefinition wurde beim Checkout beschädigt (`KNOWN_ISSUES.md` K2). Datei aus dem Blob schreiben:
```sh
# in Git Bash ausführen – eine PowerShell-Umleitung (>) würde die Bytes neu kodieren
git show "HEAD:scripts/windows/shadow-copy/Snapshot_C_Täglich.xml" > Snapshot.xml
```

---

## Pflege vor dem Push

```powershell
.\tools\Build-ScriptIndex.ps1
.\tools\Find-ScriptDependency.ps1 -CrossFolderOnly   # Soll: ungedeckt: 0
.\tools\Repair-ScriptEncoding.ps1 -WhatIf            # Soll: 0 Datei(en) betroffen
```

---

## Deployment-Checkliste (Einsatz eines Skripts)

- [ ] Skript gelesen (nicht geladen), Hilfe und `.NOTES` beachtet (Warnhinweise wie Sperrzähler)
- [ ] PowerShell-Version passt (`#Requires`), benötigte Module installiert (`architecture/DEPENDENCIES.md`)
- [ ] Lokale Konfiguration angelegt — **ohne** Credentials (`architecture/CONFIGURATION.md`)
- [ ] Testlauf in der Testumgebung bzw. mit `-WhatIf` erfolgreich
- [ ] Ausgabedateien mit Personenbezug in geschütztem Verzeichnis, Löschfrist notiert (`security/DATA_HANDLING.md`)
- [ ] Geplante Aufgabe: angelegt, manuell gestartet, `LastTaskResult` geprüft (`operations/TASK_SCHEDULER.md`)
