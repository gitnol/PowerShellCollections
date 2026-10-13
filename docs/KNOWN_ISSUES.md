# Bekannte Probleme – PowerShellCollections

Bugs, Quirks und Einschränkungen, die **nicht** akut behoben werden, aber
dokumentiert sein müssen, damit niemand zweimal darüber stolpert.

**Abgrenzung:**

- `TODO.md` = Arbeit, die in einem priorisierten Inkrement aufgeräumt wird
- `KNOWN_ISSUES.md` = bekannt, akzeptiert oder verschoben; mit Workaround
- `BACKLOG.md` = noch unpriorisierte Ideen, keine konkreten Probleme

Die Einträge K1–K3 und K7 wurden beim Init der docs_template-Baseline (2026-10-11) gefunden; nach
`NEUES_PROJECT_INITIALISIEREN.md` 3d werden Fehler im Bestand dabei nicht still korrigiert, sondern hier erfasst.

---

## Aktive Probleme

| # | Beschreibung | Reproduktion | Workaround | Akzeptanzgrund | Geplant für |
|---|---|---|---|---|---|
| K4 | `Set-CascadedWindow_BETA.ps1` öffnet bei Menüpunkt 1 mit mehr als einem Bildschirm immer `Out-GridView`; Details `docs/BACKLOG.md` Abschnitt 9. | Mehr-Monitor-System, Option 1 wählen | `Set-ForegroundWindows.ps1` verwenden (wiederhergestellte, funktionierende Fassung) | Bewusst zwei Stände, bis die BETA behoben ist | offen (`TODO.md` Mittlere Priorität) |
| K5 | `CLAUDE.md` enthält eigene Regeln (Ablage, Kodierung, Namen, Interna, Pflege), die seit der Baseline auch in `docs/CONVENTIONS.md` stehen; der Zeiger auf `AGENTS.md` fehlt. | `CLAUDE.md` mit `docs/CONVENTIONS.md` §3, §10–§12 vergleichen | Bei Widerspruch gilt `docs/` | Änderungen an `CLAUDE.md` entscheidet der Eigentümer | offen |
| K6 | Die meisten Skripte führen beim Laden Code aus (Funktion definieren und am Dateiende aufrufen); nur 32 von 147 sind laut `INDEX.md` nebenwirkungsfrei (`def`). Dot-Sourcing zum Erkunden kann AD-, Remote- oder Webzugriffe auslösen. | beliebige nicht-`def`-Datei dot-sourcen | Lesen statt laden; `def`-Markierung in `INDEX.md` | Gewachsener Bestand; Umbau aller Skripte steht in keinem Verhältnis | nie |
| K7 | `docs/STRUCTURE.md` ist in zwei Abschnitten veraltet: „Versionsstaende" beschreibt `_v1`/`_v2`/`_old` als aktuellen Zustand, und „Was als Naechstes ansteht" listet die erledigten Punkte 1–3 und 5 als offen (erledigt laut `docs/BACKLOG.md` Abschnitt 1 und `CLAUDE.md`). | Abschnitte lesen, mit `docs/BACKLOG.md` Abschnitt 1 vergleichen | `docs/BACKLOG.md` ist der aktuellere Stand | Bestand bleibt beim Init unverändert (3d Punkt 5) | offen (`TODO.md` Niedrige Priorität) |

---

## Behobene Probleme

Letzte Einträge behalten bis zur nächsten Aufräum-Iteration (Spur für
Lessons Learned). Danach archivieren oder löschen.

| # | Beschreibung | Behoben in | Commit |
|---|---|---|---|
| K1 | `Set-TeamViewerAccess.ps1`: Modulimport in den `begin`-Block verschoben, damit `begin`/`process` wieder Namensbloecke sind statt Befehlsaufrufe | I2 | folgt |
| K2 | `.gitattributes`: `binary`-Ausnahme fuer `MS.PS.Lib.psd1` auf den aktuellen Pfad korrigiert, UTF-16-Aufgaben-XML in `scripts/windows/shadow-copy/` ebenfalls als `binary` gefuehrt | I2 | folgt |
| K3 | `tools/Build-ScriptIndex.ps1`: Orphane `begin`/`process`/`end`/`dynamicparam`-Bloecke werden jetzt als Syntaxfehler erkannt (AST-Muster statt teurem Invoke-ScriptAnalyzer pro Datei); dabei auch eine verwandte Luecke gefunden und mitbehoben - die Nebenwirkungspruefung las nur `EndBlock.Statements` und markierte zwei Skripte mit echten `begin`/`process`-Bloecken faelschlich als `def` (`LESSONS_LEARNED.md` L4) | I2 | folgt |

---

## Pflege

- Neuer Bug ohne sofortigen Fix → Eintrag hier; TODO-Punkt **nur**, wenn
  priorisiert wird.
- Eintrag wird behoben → in „Behobene Probleme" verschieben, in der nächsten
  Aufräum-Iteration löschen.
- Diese Datei steht in der Trigger-Matrix in `KICKOFF.md` Phase 3a.
