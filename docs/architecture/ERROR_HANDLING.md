# Fehlerbehandlung – PowerShellCollections

Wo und wie Fehler erkannt, propagiert, behandelt und gemeldet werden.
Konsolidiert Regeln, die sonst in `CONVENTIONS.md`, `principles/FAIL_FAST.md`,
`principles/CONTRACTS.md` und `principles/LOGGING.md` verstreut sind.

---

## Exception-/Fehler-Hierarchie

Die Sammlung hat keine gemeinsame Exception-Hierarchie und braucht keine: Skripte sind eigenständig, eine
projektweite Basis-Exception hätte keinen gemeinsamen Fänger. Stattdessen:

- **Abbruchfehler** per `throw` mit klarer `Message`; wo ein Aufrufer gezielt unterscheiden soll, als `ErrorRecord`
  mit passender `ErrorCategory` (`InvalidArgument`, `ObjectNotFound`, `PermissionDenied`, `ConnectionError`,
  `InvalidData`) — `$PSCmdlet.ThrowTerminatingError()` in Advanced Functions.
- **Nicht-abbrechende Fehler** (`Write-Error`) für Einzelziele in Mehrrechner-Läufen; das Ziel erscheint zusätzlich
  im Ergebnis mit Status (siehe unten).
- **Niemals nackte Strings ohne Kontext werfen** (`throw "Fehler"`): Ziel, Operation und Ursache gehören in die
  Meldung.

---

## Boundary vs. interne Fehler

| Ebene | Verhalten |
|---|---|
| **Interaktiver Aufruf** (Admin startet Skript) | Fehler als lesbare Meldung; keine Zugangsdaten oder Tokens in Meldungen. Stacktrace nur mit `-Verbose`/`$Error[0]`. |
| **Mehrrechner-Lauf** (`Invoke-Command`, `ForEach-Object -Parallel`, Jobs) | Ausfall eines Ziels bricht den Lauf nicht ab; das Ziel wird im Ergebnisobjekt mit Status/Fehlertext geführt (Muster: `Get-BitLockerStatus.ps1`, `Set-TeamViewerAccess.ps1`). |
| **PRTG-Sensor** (`scripts/monitoring/prtg/`) | Fehler nie als Exception, sondern als `<prtg><error>1</error><text>…</text></prtg>` auf stdout — PRTG wertet nur stdout aus (Vertrag: `scripts/monitoring/prtg/README.md`). |
| **Geplante Aufgabe** (Task Scheduler) | Ergebnis über Exit-Code und Log-Datei; ein unbehandelter Fehler muss als Exit-Code ≠ 0 sichtbar werden (`operations/TASK_SCHEDULER.md`). |
| **Scriptblock auf dem Zielrechner** | Fehler im Scriptblock fangen und als Rückgabeobjekt an den Verwaltungs-PC zurückgeben; lokal loggen erst nach `Invoke-Command` (`architecture/REMOTE_EXECUTION.md`). |
| **Funktionen in Bibliotheken/Modulen** | Fehler **werfen**, nicht abfangen und nicht selbst ausgeben; die Entscheidung trifft das aufrufende Skript. |

---

## Was geloggt und was gerethrowt wird

- **Boundary** fängt → loggt → konvertiert in Antwortformat. Das Level richtet sich nach der Art des Fehlers
  (Level-Semantik: `docs/principles/LOGGING.md`):
  - **unerwartet** (Programmierfehler, Sicherheitsnetz, Infrastruktur ausgefallen) → `ERROR` mit vollem Stacktrace
    (`exc_info=True` / `_logger.LogError(ex, …)`);
  - **erwartet, fachlich** (ungültige Eingabe, Ressource nicht gefunden, Rechte fehlen) → `WARNING` ohne
    Stacktrace — sonst erzeugt jeder Robustheitstest ein `ERROR`.
- **Mittelschichten** lassen Fehler durch — **kein doppeltes Logging** desselben Fehlers.
- **Niemals `except: pass` / leeres `catch {}` ohne Logging.** Wird ein Fehler bewusst
  ignoriert, wird er auf `DEBUG` (reine Information) bzw. `WARNING` (Zustand ist auffällig) geloggt und der
  Grund kommentiert (`LOGGING.md`).

---

## Retry-Strategien

- Nur retryen, wenn die Operation **idempotent** ist (oder das System sie idempotent macht).
- Klare Obergrenze: `MAX_RETRIES = N`, exponentielles Backoff mit Jitter.
- **Keine geschachtelten Retry-Schleifen** auf derselben Operation (z. B. Token-Abruf mit eigenem
  Retry innerhalb eines Request-Retrys: der Token-Fehler darf nicht vom äußeren Retry aufgefangen werden).
- Authentifizierungsfehler **niemals retryen** ohne Token-Invalidierung dazwischen.
- Tritt ein nicht-retryable Fehler auf (z.B. HTTP 400, `ValidationError`) → sofort propagieren.

---

## Feindliche Eingaben — kein Absturz an Systemgrenzen

Alles, was von außen kommt, ist feindlich: Dateien und Fremdformate, CLI-Parameter,
Konfiguration, API- und DB-Antworten, Aufrufe durch Agenten/Tools. Ergebnis ist **immer
ein behandelbarer Fehler** (projektspezifische Exception → Boundary-Konvertierung), nie
ein Prozessabsturz, ein hängender Prozess oder verlorene Nutzerdaten.

> Abgrenzung zu [[FAIL_FAST]]: Fail Fast bricht die **Operation** früh und laut ab.
> Diese Regel sorgt dafür, dass dabei nicht der **Prozess** oder die Arbeit des Nutzers
> mitgerissen wird. Abgrenzung zu [[UNTRUSTED_DOCUMENT_CONTENT]]: dort geht es um fremden
> Inhalt im LLM-Prompt (Injection/Fälschung), hier um die Robustheit des Prozesses.

- **Eingabe-abgeleitete Zahlen prüfen:** Indizes und Längen vor dem Zugriff, Größen vor
  der Allokation begrenzen, Division durch null und NaN/Unendlich abfangen, Überläufe
  vermeiden.
- **Rekursion und Schleifen begrenzen** (Tiefenlimit oder Besucht-Menge) — Eingaben
  können tief verschachtelt oder zyklisch sein.
- **Schreiben atomar:** in eine Temp-Datei **im selben Verzeichnis** schreiben, dann
  umbenennen (`os.replace` / `File.Replace` / `Move-Item -Force`). Scheitert der
  Schreibvorgang, bleibt die Originaldatei unverändert.
- **Letztes Sicherheitsnetz** an der äußersten Boundary (Befehls-Dispatch, Import/Export):
  fängt einen entkommenen Fehler, loggt ihn mit Stacktrace, meldet ihn verständlich und
  erhält den Arbeitsstand. Ein Netz, kein Freibrief für unbehandelte Fehlerpfade.
- **Jeder Crash-Fix bringt einen kleinen synthetischen Regressionstest mit**, der vor dem
  Fix nachweislich abgestürzt ist (behaviorales Rot, `KICKOFF.md` Phase 2).
- **Robustheitstest über alle Einstiegspunkte**, sobald es eine zentrale Eingangsschicht
  gibt (CLI-Befehle, Endpunkte, exportierte Cmdlets): jeden Einstiegspunkt mit feindlichen
  Parametern aufrufen (leer, falscher Typ, außerhalb des Bereichs, riesig) und nur einen
  Fehler — keinen Absturz, keinen Hänger (Timeout) — akzeptieren. Die Liste der
  Einstiegspunkte wird **automatisch ermittelt** (Registry, Reflection, Modul-Export),
  damit neue Einstiegspunkte ohne Zutun mitgeprüft werden.

---

## Konvertierungstabelle (Pflicht ausfüllen)

HTTP-Status entfällt (die Sammlung stellt keine HTTP-Schnittstelle bereit). Maßgeblich sind die Ausgabewege aus
„Boundary vs. interne Fehler".

| Fehlerart (`ErrorCategory`) | Interaktiv | Mehrrechner-Lauf | PRTG-Sensor | Geplante Aufgabe | Bemerkung |
|---|---|---|---|---|---|
| Ungültige Eingabe (`InvalidArgument`) | Abbruch vor jedem Zugriff, Meldung | Abbruch des ganzen Laufs | `<error>1</error>` + Text | Exit-Code `1` | Validierungsattribute in `param()` |
| Ziel nicht erreichbar (`ConnectionError`) | Warnung | Ziel mit Status „offline" im Ergebnis, Lauf geht weiter | `<error>1</error>` + Text | Exit-Code `1`, Log | Vorab-Prüfung über `PSCollections.Connectivity` |
| Rechte fehlen (`PermissionDenied`) | Abbruch, Hinweis auf benötigte Rechte | Ziel mit Status im Ergebnis | `<error>1</error>` + Text | Exit-Code `1`, Log | `#Requires -RunAsAdministrator`, wo nötig |
| Objekt nicht gefunden (`ObjectNotFound`) | Warnung | Ziel mit Status im Ergebnis | Kanal mit Wert/Warnung | Log | z. B. AD-Objekt, Datei, Registry-Schlüssel |
| Konfiguration fehlt/ungültig (`InvalidData`) | Abbruch beim Start | Abbruch beim Start | `<error>1</error>` + Text | Exit-Code `1` | Konfigurationsdatei, Modul fehlt |
| Unerwarteter Fehler | Abbruch, `$Error[0]` | Ziel mit Fehlertext im Ergebnis | `<error>1</error>` + Text | Exit-Code `1`, Log mit Stacktrace | Fallback |

---

## Anti-Pattern

- **`throw "Fehler"`** ohne Ziel, Operation und Ursache.
- **Catch-and-rethrow ohne Mehrwert** (`catch { throw $_ }`) — entfernen.
- **Exception im PRTG-Sensor** statt `<error>`-Element: PRTG zeigt dann nur „keine Daten" ohne Begründung.
- **Stilles Wegfangen** (`catch {}` ohne Logging; Altbestand: 38 Fundstellen `PSAvoidUsingEmptyCatchBlock`) —
  Fail-Fast wird ausgehebelt.
- **Ein unerreichbarer Rechner bricht einen Lauf über hunderte Rechner ab.**

---

## Pflege

Trigger (siehe `KICKOFF.md` Phase 3a): neue Exception-Klasse / neue Boundary
/ neue Retry-Stelle → diese Datei + Konvertierungstabelle aktualisieren.
