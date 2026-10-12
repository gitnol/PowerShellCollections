# Monitoring & Betrieb – PowerShellCollections

Die Sammlung ist kein Dienst; überwacht wird, was einzelne Skripte **dauerhaft** tun. Das sind drei Fälle:
PRTG-Sensoren (laufen in jedem PRTG-Intervall), geplante Aufgaben (Schattenkopien) und der Ping-Monitor. Alle
anderen Skripte laufen interaktiv — ihr „Monitoring" ist die Ausgabe des Laufs.

---

## Erfolgsindikatoren

| Indikator | Erwarteter Wert | Prüfung |
|-----------|----------------|---------|
| Exit-Code geplanter Aufgaben | `0` | Task Scheduler „Letztes Ausführungsergebnis": `0x0` |
| PRTG-Sensor | Kanalwerte, kein `<error>1</error>` | Sensorstatus in PRTG; Skript lokal auf der Probe ausführen und stdout lesen |
| Schattenkopien vorhanden und aktuell | jüngste Kopie vom Laufdatum | `.\scripts\windows\shadow-copy\Get-ShadowStorage.ps1` |
| Aufgaben-Log | neue Zeile je Lauf mit `Return: 0` | `Get-Content C:\Install\shadowcopy_task.log -Tail 10` |
| Ping-Monitor | Benachrichtigung bei Ausfall, Testmail kommt an | `Test-SMTPConfiguration` (Modul `Win10PingMonitor.psm1`) |
| Repo-Zustand (Maintainer) | `ungedeckt: 0`, `0 Datei(en) betroffen`, 0 `ParseError` | Pflegewerkzeuge, `Invoke-ScriptAnalyzer -Severity ParseError` |

---

## Exit-Codes

| Code | Bedeutung |
|------|-----------|
| `0` (`0x0`) | Vollständiger Durchlauf ohne Fehler |
| `1` (`0x1`) | Skript-Fehler (unbehandelte Exception) |
| `4294770688` (`0xC000013A`) | CTRL+C / Prozess-Kill |

> In Task Scheduler: Letztes Ausführungsergebnis `0x0` = Erfolg. Alles andere = Fehler untersuchen.
> PRTG-Sensoren werten **keinen** Exit-Code aus — Fehler müssen als `<error>` im XML stehen
> (`scripts/monitoring/prtg/README.md`).

---

## Manuelle Checks

```powershell
# Geplante Aufgaben der Schattenkopien
Get-ScheduledTaskInfo -TaskName 'Snapshot_C_Täglich' | Select-Object LastRunTime, LastTaskResult, NextRunTime

# Task-Scheduler-Fehler
Get-WinEvent -LogName 'Microsoft-Windows-TaskScheduler/Operational' -MaxEvents 20

# Log der Aufgabe
Get-Content C:\Install\shadowcopy_task.log -Tail 20

# PRTG-Sensor lokal auf der Probe prüfen (Ausgabe muss genau ein <prtg>-Dokument sein)
& "C:\Program Files (x86)\PRTG Network Monitor\Custom Sensors\EXEXML\dsls\Get-DslsLogError.ps1"
```

---

## Bekannte Warnsignale

| Signal | Mögliche Ursache | Maßnahme |
|--------|-----------------|---------|
| Task-Ergebnis `0x1` | Unbehandelte Exception im Skript | Log und Ereignisanzeige prüfen |
| Aufgabe lässt sich nicht registrieren | XML beim Checkout beschädigt (`KNOWN_ISSUES.md` K2) | XML aus dem Git-Blob schreiben (`operations/RUNBOOK.md`) |
| Task startet nicht (0x80070005) | Fehlende Berechtigungen | Konto/Rechte der Aufgabe prüfen |
| PRTG zeigt „keine Daten" ohne Text | Sensor wirft eine Exception statt `<error>`, oder Hilfsmodul fehlt (Unterordner unvollständig kopiert) | Unterordner komplett kopieren; Sensor lokal ausführen |
| Schattenkopien fehlen trotz Aufgabe | Schattenspeicher voll oder deaktiviert | `Get-ShadowStorage.ps1`, `vssadmin list shadowstorage` |
| Ping-Monitor schweigt | SMTP-Zugangsdaten nur im Speicher; nach Neustart der Sitzung weg | Sitzung neu starten und `Get-Credential` erneut eingeben |

---

## Scheduling

```
Trigger:       täglich (Schattenkopie C: und Wiederherstellungspunkt, laut XML-Definition)
Ausführung:    Unabhängig von Benutzeranmeldung
Konto:         SYSTEM (S-1-5-18), höchste Privilegien
Protokollierung: C:\Install\shadowcopy_task.log (Add-Content je Lauf)
```

PRTG-Sensoren laufen im Intervall der jeweiligen PRTG-Sensorkonfiguration unter dem Konto der PRTG-Probe; der
Ping-Monitor läuft in einer interaktiv gestarteten Sitzung.

> **Wichtig:** Braucht eine künftige Aufgabe ein anderes Konto als `SYSTEM`, werden die Zugangsdaten beim Anlegen im
> Task Scheduler hinterlegt — **nicht** in `config.ps1` oder im Skript (`architecture/CREDENTIAL_STRATEGY.md`).
