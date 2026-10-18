# Task Scheduler – PowerShellCollections

Konfiguration des Windows Task Schedulers für die Teile der Sammlung, die als geplante Aufgabe laufen. Verbindet
sich mit `architecture/CREDENTIAL_STRATEGY.md` und `operations/MONITORING.md`.

Im Bestand sind das die beiden Aufgaben aus `scripts/windows/shadow-copy/` (Bedingung der Template-Datei: Skript bzw.
Aktion läuft per Task Scheduler). Daneben **verwalten** einige Skripte fremde Aufgaben, ohne selbst geplant zu
laufen: `scripts/windows/scheduled-tasks/` (Export/Auflistung), `Set-AutorunEntry.ps1` (`schtasks /Change`),
`Get-TasksAndServices.ps1` (Aufgaben unter Domänenkonten finden).

---

## Task-Definition

| Feld | `Snapshot_C_Täglich` | `Wiederherstellungspunkt_C_Täglich` |
|---|---|---|
| Beschreibung | tägliche Schattenkopie von `C:` | täglicher Systemwiederherstellungspunkt |
| Trigger | täglich (`DaysInterval` 1) | täglich (`DaysInterval` 1) |
| Aktion | `powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "… Win32_ShadowCopy.Create('C:\', 'ClientAccessible') …"` | `powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "Checkpoint-Computer …"` |
| Konto | `SYSTEM` (SID `S-1-5-18`) | `SYSTEM` |
| Mit höchsten Privilegien | ja (`HighestAvailable`) — nötig für VSS bzw. Wiederherstellungspunkt | ja |
| Protokoll | `C:\Install\shadowcopy_task.log` | `C:\Install\shadowcopy_task.log` |
| Registrierung | `New-ScheduledTaskFromXml.ps1` oder `Enable-ShadowCopy.ps1` per `schtasks /create /xml … /f` | dito |

Der Befehl steht inline in der Aufgabe (kein Skript auf der Platte nötig); damit gibt es kein Arbeitsverzeichnis
und keine Datei, die ein Angreifer austauschen könnte.

---

## Erstellung per XML

XML-Definitionen liegen versioniert neben den Skripten in `scripts/windows/shadow-copy/` — als UTF-16 LE mit BOM,
wie `Export-ScheduledTask` bzw. `schtasks /query /xml` sie liefern (Encoding-Ausnahme laut `CONVENTIONS.md` §3).

> **Achtung (Bestand):** Die `.gitattributes` behandelt `*.xml` als Text mit `eol=crlf`; dadurch werden genau diese
> UTF-16-Dateien beim Checkout beschädigt (`KNOWN_ISSUES.md` K2). Bis zur Korrektur (`TODO.md` I2) die XML aus dem
> Git-Blob schreiben (`operations/RUNBOOK.md`) und vor dem Registrieren prüfen. Die Dateinamen enthalten außerdem
> einen Umlaut (Namensregel, `TODO.md` Niedrige Priorität).

Registrierung (wie im Bestand, als Administrator auf dem Zielrechner):

```powershell
schtasks /create /tn "Snapshot_C_Täglich" /xml "Snapshot_C_Täglich.xml" /f
```

Gleichwertig mit Cmdlets (bevorzugt für neue Aufgaben, Fehler werden als Exception sichtbar; Dateiname hier schon
mit ASCII-Namen, wie nach der geplanten Umbenennung):

```powershell
Register-ScheduledTask -Xml (Get-Content -Raw -Encoding Unicode .\Snapshot_C_Taeglich.xml) -TaskName 'Snapshot_C_Taeglich'
```

Neue Aufgaben mit eigenem Dienstkonto: Konto nur beim Registrieren angeben (`-User`/`-Password` interaktiv), nie
im XML oder Skript (`architecture/CREDENTIAL_STRATEGY.md`).

---

## Typische Fallen

| Symptom | Ursache | Fix |
|---|---|---|
| `schtasks /create /xml` meldet ungültiges XML | UTF-16-Datei beim Checkout beschädigt (K2) | Datei aus dem Blob schreiben; `.gitattributes` korrigieren (I2) |
| `0x80070005` Access Denied | Konto hat keine Rechte | Konto und RunLevel prüfen |
| `0x1` LastTaskResult | unbehandelte Exception im Befehl | Aufgaben-Log und Ereignisanzeige prüfen |
| Aufgabe „erfolgreich", aber keine Schattenkopie | Rückgabewert von `Win32_ShadowCopy.Create` ≠ 0 wird nur geloggt | `C:\Install\shadowcopy_task.log` auf `Return:`-Werte prüfen |
| Skripte prüfen `schtasks`-Exit-Code nicht | `Enable-ShadowCopy.ps1`/`New-ScheduledTaskFromXml.ps1` werten `$LASTEXITCODE` nicht aus | nach dem Lauf `Get-ScheduledTask -TaskName …` prüfen |

---

## Monitoring

| Quelle | Was prüfen |
|---|---|
| `Get-ScheduledTaskInfo -TaskName "Snapshot_C_Täglich"` | `LastRunTime`, `LastTaskResult`, `NextRunTime` |
| Event-Log „Microsoft-Windows-TaskScheduler/Operational" | Start, Ende, Errors |
| `C:\Install\shadowcopy_task.log` | Rückgabewert und ID je Lauf |
| `Get-ShadowStorage.ps1` | vorhandene Schattenkopien und Speicherverbrauch |

---

## Logging-Pfade

| Senke | Wozu |
|---|---|
| `C:\Install\shadowcopy_task.log` | Ergebnis je Aufgabenlauf |
| `C:\Install\shadowcopy.log` | Einrichtung durch `Enable-ShadowCopy.ps1` |
| Ereignisanzeige (TaskScheduler/Operational) | Start/Ende/Fehler der Aufgabe |

Die Logs werden fortgeschrieben, nicht rotiert (`security/DATA_HANDLING.md` §5).

---

## Pflege

Trigger: neue Aufgabe / Trigger-Änderung / Kontowechsel → diese Datei + XML im Themenordner + ggf.
`architecture/CREDENTIAL_STRATEGY.md` anpassen.
