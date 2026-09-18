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

## 2. BitLocker - entschieden

`Get-BitLockerStatus.ps1` ist jetzt der einzige Stand. Der Vorgaenger ist
geloescht (in der History vorhanden).

Der Nachfolger war vom Autor als Beta gekennzeichnet. Der Vergleich beider
Staende ergab, dass die Beta in genau den Punkten besser ist, die im Betrieb
zaehlen:

| Punkt                | Vorgaenger                                        | Nachfolger                                         |
| -------------------- | -------------------------------------------------- | -------------------------------------------------- |
| AD-Abfrage           | `Get-ADComputer -Properties *` - alle Attribute     | `-Properties Description` - nur das Benoetigte      |
| Abruf der Clients    | zwei `Invoke-Command` je Rechner in einer Parallelschleife | ein `Invoke-Command` ueber alle Rechner mit `-ThrottleLimit 50` |
| unverschluesselt     | faellt stillschweigend raus                         | wird als eigener Zustand ausgewiesen                |
| Datumsauswertung     | ungeprueft `[DateTime]::Parse`                      | gegen leere Werte abgesichert                       |

Der einzige echte Schwachpunkt der Beta war ihre eingebettete Kopie von
`Get-ComputerOnlineStatus` mit der globalen `Get-Job`-Verwaltung. Die ist
durch die korrigierte Fassung aus `modules/PSCollections.Connectivity`
ersetzt.

Zusaetzlich korrigiert: `BitlockerKeyCount` zaehlte das einzelne
Recovery-Objekt und war damit immer 1. Jetzt ist es die Anzahl der
Recovery-Objekte des Rechners - mehrere entstehen bei jeder
Neuverschluesselung.

---

## 3. Mehrfach definierte Hilfsfunktionen - erledigt fuer Connectivity

`Test-ConnectionInParallel` lag viermal im Repo: dreimal identisch definiert,
einmal nur aufgerufen. Alle vier nutzen jetzt
`modules/PSCollections.Connectivity`.

Die drei Kopien waren inhaltlich gleich und teilten zwei Fehler:

1. **Pipeline-Eingabe ging verloren.** `ValueFromPipeline` war deklariert,
   aber es gab keinen `process`-Block - nur das letzte Element wurde
   verarbeitet. Nachgemessen: drei Eingaben, ein Ergebnis. Ohne
   Fehlermeldung.
2. **`Test-Connection` wurde je Ziel zweimal aufgerufen** - einmal mit
   `-Quiet` fuer den Status, einmal ohne fuer die IP. Ein Aufruf liefert
   beides.

Bei `Get-ComputerOnlineStatus` kam ein dritter Fehler dazu: Drosselung und
Zeitueberwachung liefen ueber `Get-Job -State Running` und betrachteten damit
**alle** Jobs der Sitzung - eigene Hintergrundjobs des Aufrufers wurden
mitgezaehlt und nach zwei Minuten per `Stop-Job` beendet.

**Offen bleibt `Write-Log`:** fuenf Dateien definieren je eine eigene Fassung
mit unterschiedlichen Signaturen (eine mit `-Level`, eine mit Dateiausgabe).
Das ist kein Fehler, solange jede Datei ihre eigene benutzt. Der eine Aufruf
ins Leere - in `Get-MailboxForwardingRules.ps1`, mit einem Parameter `-path`,
den keine der Fassungen kennt, und einer nie gesetzten Variablen - ist durch
ein `Write-Warning` ersetzt.

Pruefen mit `tools/Find-ScriptDependency.ps1`. Die Ausgabe trennt ungedeckte
Aufrufe von solchen, die per `Import-Module` aufgeloest sind.

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
