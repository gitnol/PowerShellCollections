# Backlog

Offene Punkte. Stand: 2026-09-21.

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
| Comment-Based Help             | jedes Skript hat eine `.SYNOPSIS`                                         |
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

Pruefen mit `tools/Find-ScriptDependency.ps1`. Die Ausgabe trennt ungedeckte
Aufrufe von solchen, die per `Import-Module` aufgeloest sind.

---

## 4. `Write-Log` bleibt fuenfmal - mit Absicht

Geprueft und **bewusst nicht zusammengefuehrt**. Der Grund ist nicht Aufwand,
sondern dass es die betroffenen Skripte kaputtmachen wuerde.

Es gibt drei verschiedene Verhalten, nicht fuenf Varianten desselben:

| Datei                                                   | Signatur                            | Ausgabe                          |
| ------------------------------------------------------- | ----------------------------------- | -------------------------------- |
| `active-directory/inventory/Get-ADComputerInventory.ps1` | `-Message -Level(Info/Success/...)` | Konsole, Farbe aus interner Map  |
| `messaging/exchange/New-SharedMailboxWorkflow.ps1`       | `-Message -Level(INFO/WARN/...) -ConsoleColor` | Konsole             |
| `messaging/exchange/Sync-SharedMailboxPermission.ps1`    | wie oben, plus `REMOVE`, `SUMMARY`  | Konsole                          |
| `security/secure-boot/Invoke-SecureBootCertUpdate.ps1`   | nur `-Message`                      | Datei aus `$LOG_FILE`, Format mit Rechnername |
| `windows/shadow-copy/Enable-ShadowCopy.ps1`              | nur `-Message`                      | Datei `C:\Install\shadowcopy.log` |

**Der Ausschlussgrund: zwei dieser Skripte laufen nicht dort, wo das Repo
liegt.** `Invoke-SecureBootCertUpdate.ps1` wird laut seiner eigenen
README als Text eingelesen und auf dem Zielrechner als Scriptblock neu
erzeugt:

```powershell
$ScriptContent = Get-Content ".\Invoke-SecureBootCertUpdate.ps1" -Raw
Invoke-Command -ComputerName $TargetHosts -ScriptBlock {
    $sbi = [scriptblock]::Create($using:ScriptContent)
    & $sbi -AutoConfirm
}
```

Auf dem Zielrechner gibt es keine Datei, kein `$PSScriptRoot` und kein
`modules/`. Ein `Import-Module` mit relativem Pfad ist dort unmoeglich.
`Enable-ShadowCopy.ps1` laeuft ebenfalls auf dem Zielsystem.

Der Unterschied zu `Test-ConnectionInParallel`: das lief ausschliesslich auf
dem Verwaltungs-PC, wo das Repository ausgecheckt ist. Genau deshalb liess
es sich zusammenfassen und `Write-Log` nicht.

Fuer die drei Konsolen-Varianten waere eine gemeinsame Funktion technisch
moeglich - eine `ValidateSet` als Vereinigungsmenge, `-ConsoleColor`
optional. Sie brauchen aber ohnehin nur vier Zeilen, und eine Haelfte
zusammenzufassen liesse die Duplikation bestehen und machte die Regel
unklar. Die Selbstgenuegsamkeit dieser Skripte ist hier ein Merkmal, kein
Mangel.

Behoben wurde nur der eine echte Fehler: `Get-MailboxForwardingRules.ps1`
rief `Write-Log` mit einem Parameter `-path` auf, den keine der fuenf
Fassungen kennt, und mit einer nie gesetzten Variablen. Ersetzt durch
`Write-Warning`.

---

## 5. Lizenzlage des Fremdcodes

Geprueft am 2026-09-21. Das Repository ist oeffentlich - Fremdcode darin
braucht eine Erlaubnis.

| Projekt                                        | Lizenz                                    | Bewertung |
| ---------------------------------------------- | ----------------------------------------- | --------- |
| MailStore PowerShell API Wrapper               | MIT-artig, Volltext in jeder Datei        | in Ordnung |
| `Check-UEFISecureBootVariables` (cjee21)       | **keine LICENSE-Datei**                   | ungeklaert |
| `Get-TokenSizeReport` (jeremyts)               | **keine LICENSE-Datei**                   | ungeklaert |
| Dump-Ticketsize (msxfaq.de)                    | **Weiterveroeffentlichung nur mit Zustimmung** | entfernt |

**Entfernt:** `Export-KerberosTokenSize.ps1` war Version 1.7 des Skripts
`dump-ticketsize` von Frank Carius (msxfaq.de). Nachgewiesen ueber den
CSV-Ausgabenamen `dump-ticketsize.<Zeitstempel>.result.csv` und die
Fortschrittsanzeige mit gruenem `H` - beides auf der Quellseite so
beschrieben; der urspruengliche Dateiname im Repo war
`_dump-ticketsize.1.7.ps1`, die Downloaddatei dort heisst
`dump-ticketsize.1.7.ps1.txt`. Die Nutzungsbedingungen von msxfaq.de lauten
woertlich: *"Jede weitere Veroeffentlichung nur mit meinem vorherigen
Einverstaendnis."* Damit hat das Skript in einem oeffentlichen Repository
nichts zu suchen.

Quelle: https://www.msxfaq.de/windows/kerberos/dumpticketsize.htm

**Zu klaeren:** die beiden GitHub-Projekte ohne LICENSE-Datei. Ohne Lizenz
gilt das gesetzliche Urheberrecht - alle Rechte beim Autor. Die
GitHub-Nutzungsbedingungen erlauben anderen Nutzern Ansehen und Forken;
eine Kopie in ein fremdes Repository zu legen, ist davon nicht gedeckt.

Das aendert die Bewertung aus Abschnitt 6: ein **Git-Submodul** ist kein
blosses Aufraeumen mehr, sondern die rechtlich saubere Form - es verweist
auf das Original, statt es zu kopieren. Alternativ die Autoren fragen.

**Anmerkung zur History:** `Export-KerberosTokenSize.ps1` ist aus dem
aktuellen Stand entfernt, liegt aber weiter in alten Commits. Das ist ein
zweiter, unabhaengiger Grund fuer die Entscheidung in
[HISTORY-OPTIONS.md](HISTORY-OPTIONS.md).

---

## 6. Kleinigkeiten

- `third-party/Check-UEFISecureBootVariables/` ist ein ZIP-Download. Ein
  Git-Submodul waere nachvollziehbarer **und** lizenzrechtlich sauberer
  (siehe Abschnitt 5); dagegen steht, dass Clones dann mit
  `--recurse-submodules` geholt werden muessen.

---

## 7. Nachweis: keine Abhaengigkeit ging bei der Umstellung verloren

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

## 8. History enthaelt firmenspezifische Daten

Elf Dateien in frueheren Commits enthalten interne Domaenennamen, Hostnamen,
eine interne IP, drei Benutzernamen und eine interne Helpdesk-URL. Keine
Zugangsdaten. Die aktuellen Staende sind sauber, die alten Commits liegen
weiter oeffentlich auf GitHub.

**Zurueckgestellt.** Optionen und Abwaegung: siehe
[HISTORY-OPTIONS.md](HISTORY-OPTIONS.md).
