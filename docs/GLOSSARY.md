# Glossar – PowerShellCollections

Ubiquitous Language für dieses Projekt. Jeder Begriff hat genau eine Bedeutung.
Synonyme oder doppelt belegte Begriffe schaffen Drift und werden vermieden.

LLM-Agenten konsultieren dieses Glossar, **bevor** sie Begriffe im Code, in
Commit-Messages oder in Doku verwenden.

---

## Begriffe

| Begriff | Bedeutung | Wo verwendet | Nicht zu verwechseln mit |
|---|---|---|---|
| Skript | Ausführbare `.ps1`-Datei mit Verb-Noun-Namen, die beim Aufruf eine Betriebsaufgabe erledigt. | `scripts/**` | Funktionsbibliothek, Modul |
| Funktionsbibliothek | `.ps1`-Datei, die nur Funktionen definiert und dot-gesourct wird; heißt nach dem Inhalt. | z. B. `ZammadApiFunctions.ps1`, `UserSessionFunctions.ps1` | Skript (Verb-Noun), Modul |
| Modul | `.psm1`/`.psd1`, per `Import-Module` geladen. Bei einer Fachdomäne abgelegt, oder unter `modules/`, wenn mehrere Fachdomänen es brauchen. | `modules/PSCollections.Connectivity/`, `OSBiz.psm1`, `PRTG.Dsls.psm1` | Funktionsbibliothek |
| System (Ablageregel) | Das System, gegen das ein Skript läuft; bestimmt den Ablageort. Bei Plattform-Ausgabeverträgen ist die Plattform das System. | `docs/STRUCTURE.md`, `docs/CONVENTIONS.md` §3 | Bezugsquelle (z. B. AD nur als Rechnerliste) |
| Bezugsquelle | System, aus dem ein Skript nur Eingangsdaten holt (etwa die Rechnerliste per `Get-ADComputer`); bestimmt **nicht** den Ablageort. | `docs/STRUCTURE.md` | System |
| Plattform-Ausgabevertrag | Fest vorgegebenes Ausgabeformat einer Überwachungsplattform (PRTG-XML auf stdout, Fehler als `<error>`). | `scripts/monitoring/prtg/` | — |
| `def`-Datei | Datei, die außer Funktionsdefinitionen keinen ausführbaren Code enthält und deshalb gefahrlos dot-gesourct werden kann; in `INDEX.md` markiert. | `INDEX.md`, `tools/Build-ScriptIndex.ps1` | „Bibliothek" im Allgemeinen |
| Kanonische Datei | Die eine gültige Datei je Aufgabe; ältere Stände liegen nur in der History. | `docs/STRUCTURE.md`, `docs/BACKLOG.md` | Versionsstand (`_v2`, `_old`) |
| Fremdcode | Unverändert übernommener Code anderer Autoren unter `third-party/<projekt>/` mit `ORIGIN.md`. | `third-party/` | eigener Wrapper unter `scripts/` |
| `_inbox` | Befristete Zwischenablage für Dateien ohne Platz in der Struktur; 30-Tage-Regel. | `_inbox/README.md` | Ablageort |
| Ungedeckter Aufruf | Funktionsaufruf über Dateigrenzen, der weder in derselben Datei definiert noch per `Import-Module` aufgelöst ist — läuft ins Leere. | `tools/Find-ScriptDependency.ps1` | gedeckter Aufruf (per Import aufgelöst) |
| Verwaltungs-PC | Rechner, auf dem das Repository ausgecheckt ist und von dem aus Skripte gestartet werden; nur dort existiert `modules/`. | `docs/BACKLOG.md` Abschnitt 4, `architecture/REMOTE_EXECUTION.md` | Zielrechner |
| Zielrechner | Rechner, auf dem ein Skriptteil per `Invoke-Command`/CIM ausgeführt wird oder dessen Daten abgefragt werden. | `architecture/REMOTE_EXECUTION.md` | Verwaltungs-PC |
| Interna | Firmenspezifische Angaben (Firmen-/Standortnamen, interne Domänen, Host- und Benutzernamen, interne IPs, UNC-Pfade), die nicht ins öffentliche Repo gehören. | `docs/CONVENTIONS.md` §11, `.githooks/` | Secrets (Zugangsdaten) |
| Platzhalterwert | Fiktiver Beispielwert (`contoso.local`, `DC01`, `m.mustermann`, RFC-5737-IP) anstelle echter Interna. | Beispielcode, Doku | echter Wert |
| BOM-Pflicht | Regel: `.ps1`/`.psm1`/`.psd1` mit Nicht-ASCII-Zeichen tragen ein UTF-8-BOM (Windows PowerShell 5.1). | `docs/CONVENTIONS.md` §3, `tools/Repair-ScriptEncoding.ps1` | — |

---

## Verbotene Synonyme

Begriffe, die im Projekt-Kontext **nicht** mehr verwendet werden dürfen,
auch wenn sie umgangssprachlich gleichbedeutend wirken:

| Verbotener Begriff | Korrekt | Grund |
|---|---|---|
| „unsorted", „Restekiste", „Helper-Stuff" | `_inbox` | Die alte Restekiste war ein Dauerzustand; `_inbox` ist befristet (`docs/STRUCTURE.md`) |
| `Check-` (Verb) | `Test-` | Kein freigegebenes PowerShell-Verb |
| „neue Version" / `_v2` einer Datei | kanonische Datei | Je Aufgabe genau eine Datei; Stände liegen in der History |
| „Library" für ausführbare Skripte | Skript | Bibliothek heißt hier nur eine Datei ohne ausführbaren Code |

---

## Pflege

- Neuer Domänenbegriff im Code → **vor dem Commit** hier ergänzen.
- Begriff wird umbenannt → alter Eintrag bleibt mit Vermerk „ersetzt durch NEU"
  stehen (mindestens eine Inkrement-Generation als Übergangsphase).
- Begriff entfällt → Eintrag mit „deprecated YYYY-MM-DD" markieren, nicht löschen.
- Diese Datei steht in der Trigger-Matrix in `KICKOFF.md` Phase 3a.
