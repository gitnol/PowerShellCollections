# Aktueller Projektstatus – PowerShellCollections

Zuletzt aktualisiert: 2026-10-11
**Initialisiert mit:** docs_template v27@5ce0f84
**Stack / Overlays:** powershell-automation / keine
**Letztes abgeschlossenes Inkrement:** I1 docs_template-Baseline eingeführt (Bestand übernommen) (2026-10-11)
**Nächster Schritt:** I2 – Defekte Bestandsdateien reparieren (`docs/TODO.md`)
**Nächste Reflexion:** bei Abschluss von I3 (siehe `KICKOFF.md` Phase 1c → `docs/REFLECTION.md` — `docs/`-Drift prüfen + Template-Backport prüfen; danach Marker um 3 erhöhen)
**Nächster Security-Sweep:** 2026-10-25 (Intervall 14 Tage; siehe `KICKOFF.md` Phase 1 Punkt 4a → `docs/principles/SECURITY_CURRENCY.md` — fällig, sobald heute ≥ diesem Datum; nach dem Sweep Marker = Sweep-Datum + Intervall)

---

## Nächster Schritt

I2 aus `docs/TODO.md`: `Set-TeamViewerAccess.ps1` wieder lauffähig machen (Modulimport in den `begin`-Block), die
`.gitattributes` so korrigieren, dass UTF-16-Dateien beim Checkout nicht mehr beschädigt werden, und die
Syntaxprüfung von `tools/Build-ScriptIndex.ps1` um die Strukturfehler erweitern, die PSScriptAnalyzer meldet.
Vorher KICKOFF Phase 1 Punkt 2a (Überschneidungen mit `KNOWN_ISSUES.md` K1–K3) prüfen.

---

## Abgeschlossene Inkremente

| # | Titel | Datum | Commit |
|---|-------|-------|--------|
| I1 | docs_template-Baseline eingeführt (Bestand übernommen) | 2026-10-11 | Nachtrag folgt (`docs: record I1 commit hash`) |

---

## Offene Punkte

| # | Beschreibung | Priorität |
|---|-------------|-----------|
| I2 | Defekte Bestandsdateien reparieren (TeamViewer-Skript, `.gitattributes`, Index-Syntaxprüfung) | Hoch |
| I3 | Zugangsdaten nur geprüft verschlüsselt übertragen (OSBiz, LANCOM Public Spot, Zertifikats-Export) | Hoch |
| I4 | Quality-Gate-Fundament: PSScriptAnalyzer-Gate und erste Pester-Tests | Hoch |
| I5 | Pre-commit-Hook um Commit-Message- und Dateinamen-Prüfung ergänzen | Mittel |
| I6 | Gefährliche Voreinstellungen entschärfen (Passwortprüfung, automatische Modulinstallation) | Mittel |

---

## Risiken & Blocker

| Risiko / Blocker | Auswirkung | Mitigation / Nächster Schritt | Owner | Status |
|---|---|---|---|---|
| Git-History enthält firmenspezifische Daten (11 Dateien, keine Zugangsdaten) | Interne Bezeichner bleiben über alte Commits auffindbar (Social Engineering) | Entscheidungsvorlage `docs/HISTORY-OPTIONS.md` (Empfehlung Option 3); Entscheidung steht aus | Repo-Eigentümer | offen |
| Zwei Fremdcode-Projekte ohne Lizenzdatei im öffentlichen Repo (`docs/BACKLOG.md` Abschnitt 5) | Weiterveröffentlichung urheberrechtlich nicht gedeckt | Autoren fragen, als Submodul einbinden oder entfernen; Entscheidung steht aus | Repo-Eigentümer | offen |
| Keine automatisierten Tests, kein Linter-Gate (PSScriptAnalyzer-Basislinie 2026-10-11: 1107 Befunde, davon 12 Error, 1 ParseError) | Regressionen wie `KNOWN_ISSUES.md` K1 bleiben unbemerkt | I4 | Maintainer | offen |
| Die meisten Skripte führen beim Laden Code aus (nur 34 von 146 sind `def`) | Dot-Sourcing zum Erkunden kann AD-/Remote-Zugriffe auslösen | Lesen statt laden; `INDEX.md`-Markierung `def` beachten (`KNOWN_ISSUES.md` K6) | alle Nutzer | akzeptiert |
| Advocatus-Diaboli-Hook (`.claude/settings.json`) nicht eingerichtet; `.claude` ist im Projekt gitignoriert | Gate vor dem Commit hängt an der Disziplin des Agenten | Eigentümer entscheidet, ob `.claude/settings.json` versioniert wird (`.gitignore`-Ausnahme); bis dahin Gate von Hand (`KICKOFF.md` Phase 3b Punkt 5) | Repo-Eigentümer | offen |
| `CLAUDE.md` enthält eigene Regeln, die jetzt auch in `docs/CONVENTIONS.md` stehen; Zeiger auf `AGENTS.md` fehlt | Doppelte Regeltexte driften auseinander | Eigentümer ergänzt `@AGENTS.md` als erste Zeile und entscheidet über das Kürzen (`KNOWN_ISSUES.md` K5) | Repo-Eigentümer | offen |
