# Backlog

Offene Punkte. Stand: 2026-09-18.

Die urspruenglichen Punkte 1 bis 3 - konkurrierende Versionsstaende, fehlende
Comment-Based Help, falsch abgelegter Fremdcode, `_inbox/`, nummerierte
Beispiele, ungepruefte Generator-Ausgabe - sind abgearbeitet. Was dabei
gelernt wurde, steht in [../CLAUDE.md](../CLAUDE.md) und
[STRUCTURE.md](STRUCTURE.md).

---

## 1. Erledigt - zur Nachvollziehbarkeit

| Punkt                          | Ergebnis                                                                 |
| ------------------------------ | ------------------------------------------------------------------------ |
| Konkurrierende Versionsstaende | aufgeloest, je Aufgabe eine kanonische Datei                              |
| Comment-Based Help             | 146 von 146 Skripten haben eine `.SYNOPSIS`                               |
| Fremdcode unter `scripts/`     | `Get-TokenSizeReport` und der MailStore-Wrapper nach `third-party/`, je mit `ORIGIN.md` |
| `_inbox/playground/`           | aufgeloest                                                                |
| Nummerierte Beispieldateien    | nach Inhalt benannt                                                       |
| Generator ohne Ausgabepruefung | `Test-GeneratedScript` ergaenzt                                           |

Zwei Faelle brauchten vor dem Loeschen eine Zusammenfuehrung, weil der
juengere Stand **kein** Superset war: bei Zammad fehlten `_v2` drei
Funktionen aus `_v1`, bei MailStore rief `_v2` eine Funktion auf, die nur in
`_v1` stand. Zwei weitere Paare waren gar keine Versionen, sondern jeweils
Funktionsbibliothek plus fertiges Skript.

Nebenbei repariert: ein Modulimport auf eine nicht existierende Datei
(`Win10Monitor.psm1` statt `Win10PingMonitor.psm1`), die Importpfade der
MailStore-Beispiele nach deren Umzug, und Steuerzeichen, die bei einer
frueheren Pfadanpassung in fuenf Dateien geraten waren.

---

## 2. BitLocker - Entscheidung steht aus

`scripts/security/bitlocker/`

`Get-BitLockerStatus.ps1` ist der vom Autor erklaerte Nachfolger, in der
Commit-Nachricht aber ausdruecklich als **Beta** gekennzeichnet. Deshalb liegt
der bewaehrte Vorgaenger weiter unter `archive/Get-BitLockerStatus_legacy.ps1`.

**Offen:** sobald der Nachfolger im Betrieb bestaetigt ist, `archive/`
loeschen. Die frueher daneben liegende englische Fassung war eine reine
Uebersetzung des Vorgaengers und ist bereits entfernt.

---

## 3. Mehrfach definierte Hilfsfunktionen

`Test-ConnectionInParallel` ist in drei Dateien unabhaengig voneinander
definiert und wird in einer vierten aufgerufen, ohne dort definiert oder
importiert zu sein:

| Datei                                                            | Rolle            |
| ---------------------------------------------------------------- | ---------------- |
| `scripts/windows/availability/ComputerAvailabilityFunctions.ps1` | definiert        |
| `scripts/applications/teamviewer/Set-TeamViewerAccess.ps1`       | definiert        |
| `scripts/security/secure-boot/Test-MultipleHostsSecureBoot.ps1`  | definiert        |
| `scripts/applications/excel/ConvertFrom-ExcelClipboard.ps1`      | **ruft nur auf** |

Dasselbe Muster bei `Write-Log`: fuenf Dateien definieren je eine eigene
Fassung, `scripts/messaging/exchange/Get-MailboxForwardingRules.ps1` ruft es
auf, ohne eine zu haben.

Ein gemeinsames Hilfsmodul waere die saubere Loesung. Bis dahin sind die
beiden aufrufenden Dateien nicht eigenstaendig lauffaehig - in ihrer
`.NOTES` steht das jeweils.

Pruefen mit `tools/Find-ScriptDependency.ps1`.

---

## 4. Kleinigkeiten

- `scripts/active-directory/token-size/Export-KerberosTokenSize.ps1` traegt
  keine Herkunftsangabe (Versionshinweise ab 2012). Ob eigene Entwicklung
  oder uebernommen, liess sich nicht klaeren. Es loest dieselbe Aufgabe wie
  `third-party/Get-TokenSizeReport/`.
- `third-party/Check-UEFISecureBootVariables/` ist ein ZIP-Download. Als
  Git-Submodul waeren Updates nachvollziehbar - dafuer muessten Clones mit
  `--recurse-submodules` geholt werden, was fuer eine Sammlung zum
  Durchstoebern ein Nachteil ist. Bewusst nicht umgestellt.
- In `scripts/applications/zammad/` definieren `Get-ZammadTicket.ps1` und
  `ZammadApiFunctions.ps1` beide ein `Get-ZammadTickets`. Beim gleichzeitigen
  Dot-Sourcing gewinnt die zuletzt geladene Fassung.

---

## 5. Nachweis: keine Abhaengigkeit ging bei der Umstellung verloren

Geprueft am 2026-09-18 durch Vergleich des Abhaengigkeitsgraphen vor der
Umstellung (Commit `9d20efa`, ueber einen temporaeren Worktree) mit dem
danach, ueber eine Namensabbildung fuer die Umbenennungen:

| Kennzahl                                | Wert                                                       |
| --------------------------------------- | ---------------------------------------------------------- |
| Abhaengigkeiten vorher (ohne Fremdcode) | 21                                                          |
| davon verloren                          | **0**                                                       |
| neu hinzugekommen                       | 12 (die PRTG-DSLS-Sensoren zu ihrem Modul, gleicher Ordner) |

Die zwoelf Abhaengigkeiten innerhalb von
`third-party/Check-UEFISecureBootVariables/` sind ebenfalls intakt: der
Ordner wurde als Ganzes verschoben, die Blob-Hashes aller Dateien sind
unveraendert.

Die einzige tatsaechlich gebrochene Abhaengigkeit entstand nicht durch das
Verschieben, sondern durch die Umbenennung des Ordners `API-Wrapper` zu
`api-wrapper`: die MailStore-Beispiele importierten den alten Pfad. Unter
Windows folgenlos, unter Linux ein harter Fehler. Behoben.

Wiederholbar mit `tools/Find-ScriptDependency.ps1`.

---

## 6. History enthaelt firmenspezifische Daten

Elf Dateien in frueheren Commits enthalten interne Domaenennamen, Hostnamen,
eine interne IP, drei Benutzernamen und eine interne Helpdesk-URL. Keine
Zugangsdaten. Die aktuellen Staende sind sauber, die alten Commits liegen
weiter oeffentlich auf GitHub.

**Zurueckgestellt.** Optionen und Abwaegung: siehe
[HISTORY-OPTIONS.md](HISTORY-OPTIONS.md).
