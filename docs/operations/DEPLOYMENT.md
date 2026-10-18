# Deployment – PowerShellCollections

Die Sammlung hat **kein Build und kein Release**. „Deployment" heißt hier: ein Skript aus einem Klon des
Repositorys auf den Rechner bringen, auf dem es laufen soll. Stack-spezifische Setup- und Betriebsdetails stehen in
`operations/SETUP.md` und `operations/RUNBOOK.md`.

Verbindet sich mit `operations/SETUP.md` (Erst-Setup), `operations/RUNBOOK.md`
(Betrieb) und `operations/SECRETS_MANAGEMENT.md`.

> Template-Abschnitte zu Build-Artefakten, staging/prod-Pipeline, Health-Endpoints und Datenbank-Migrationen treffen
> auf eine Skriptsammlung nicht zu und sind gestrichen (`docs/BACKLOG.md` → Stack-Lücken).

---

## Umgebungen

| Umgebung | Zweck | Datenquelle | Wer darf deployen |
|---|---|---|---|
| Arbeitskopie des Maintainers | Entwicklung, Pflegewerkzeuge, Gates | keine Echtdaten nötig (Tests mit Mocks) | Maintainer |
| Testumgebung der betreibenden Organisation | Ausprobieren vor dem Produktiveinsatz (`README.md`: „vor dem Produktiveinsatz lesen und in einer Testumgebung ausprobieren") | Testdomäne / Testrechner | Administrator |
| Produktiv: Verwaltungs-PC | interaktiver Einsatz | Echtdaten der Domäne | Administrator |
| Produktiv: Sonderorte | PRTG-Probe (Custom Sensors), Zielrechner (Schattenkopie-Aufgaben, Secure-Boot-Update) | Echtdaten | Administrator |

Unterschiede zwischen Umgebungen werden ausschließlich über Parameter bzw. lokale Konfigurationsdateien gesteuert
(siehe `architecture/CONFIGURATION.md`), nicht über Code-Branches.

---

## Build

```
(kein Build — Skripte laufen aus dem Arbeitsverzeichnis)
.\tools\Build-ScriptIndex.ps1     # erzeugt nur INDEX.md, kein Artefakt
```

Einzige Ausnahme im Bestand: `Set-ProcessPriority.ps1` lässt sich laut Hilfe mit `PS2EXE` zu einer EXE kompilieren —
das ist ein lokaler Schritt des Betreibers, kein Teil des Repos.

**Reproduzierbar:**
- [ ] Bezug immer aus einem Git-Commit (Klon/Pull), nicht aus kopierten Einzeldateien unbekannter Herkunft
- [ ] Benötigte Module mit geprüfter Version vorab installiert (`architecture/DEPENDENCIES.md`), nicht zur Laufzeit

---

## Release

Es gibt keine Versionen; `main` ist der aktuelle Stand. Vor dem Einsatz eines geänderten Skripts:

| Schritt | Verantwortung | Verifikation |
|---|---|---|
| Dependency-Audit + Security-Currency-Abgleich (Kadenz-Sweep) | Maintainer | datierter Eintrag in `security/DEPENDENCY_AUDIT.md` → Befunde (`principles/SECURITY_CURRENCY.md`) |
| Gates für die geänderten Dateien | Maintainer | `docs/CONVENTIONS.md` §9 (PSScriptAnalyzer, Pester) |
| Pflegewerkzeuge | Maintainer | `docs/CONVENTIONS.md` §10 (`ungedeckt: 0`, `0 Datei(en) betroffen`, `INDEX.md` aktuell) |
| Test in einer Testumgebung | Administrator der betreibenden Organisation | Ergebnis gegen Erwartung, `-WhatIf` wo vorhanden |
| Einsatz | Administrator | Ausgabe/Log des Laufs |

---

## Sonderorte

- **PRTG-Sensoren:** den **ganzen Unterordner** nach `…\PRTG Network Monitor\Custom Sensors\EXEXML\` kopieren — die
  Sensoren importieren ihr Hilfsmodul relativ über `$PSScriptRoot` (`scripts/monitoring/prtg/README.md`).
- **Schattenkopie-Aufgaben:** `Enable-ShadowCopy.ps1` bzw. `New-ScheduledTaskFromXml.ps1` auf dem Zielrechner
  ausführen; die beiden XML-Dateien müssen unbeschädigt sein (`KNOWN_ISSUES.md` K2, `operations/TASK_SCHEDULER.md`).
- **Secure-Boot-Update:** wird vom Verwaltungs-PC aus per `Invoke-Command` verteilt
  (`scripts/security/secure-boot/README.md`).

---

## Rollback

**Bedingung:** Ein geändertes Skript verhält sich im Einsatz falsch.

| Schritt | Befehl / Aktion |
|---|---|
| 1. Letzten funktionierenden Stand identifizieren | `git log --oneline -- <pfad>` |
| 2. Skript dieses Stands verwenden | `git show <commit>:<pfad> > <ziel>` bzw. `git restore --source <commit> -- <pfad>` |
| 3. Verifikation | erneuter Lauf in der Testumgebung |
| 4. Bereits ausgeführte Änderungen zurücknehmen | je Skript von Hand (AD-Attribute, Registry, Dienste, Aufgaben) — es gibt keine automatische Rücknahme |

> **Wichtig:** Zustandsändernde Skripte sind nicht automatisch umkehrbar (gelöschte Profile, geleerte Eventlogs,
> geänderte Kontoattribute). Vor dem Lauf deshalb `-WhatIf` bzw. ein Export des Ausgangszustands.

---

## Post-Deploy-Verifikation

- [ ] Lauf ohne Fehler, Ergebnis plausibel (Stichprobe)
- [ ] Bei Mehrrechner-Läufen: Anteil „offline/Fehler" im Ergebnis geprüft
- [ ] PRTG-Sensoren: Kanal liefert Werte, kein `<error>`
- [ ] Geplante Aufgaben: `LastTaskResult` = 0 (`operations/MONITORING.md`)

---

## Pflege

Trigger: neuer Sonderort / geänderter Bezugsweg / geänderter Rollback-Pfad → hier eintragen.
