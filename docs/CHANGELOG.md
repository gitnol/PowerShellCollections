# Changelog – PowerShellCollections

Format orientiert sich an [Keep a Changelog](https://keepachangelog.com/).
Einträge chronologisch absteigend (neueste oben). Jeder Eintrag entspricht
genau einem Inkrement (= einem Commit oder einer eng zusammengehörigen
Commit-Serie). Roadmap-Änderungen (KICKOFF Phase 1 Punkt 2a), Reflexions-Refreshs und
Post-Mortems erhalten einen kurzen Eintrag ohne I#.

Nicht alle Sektionen sind in jedem Eintrag nötig — leere Sektionen weglassen.

Die Entwicklung vor der docs_template-Baseline steht in der Git-History (`git log`) und in `docs/BACKLOG.md`
Abschnitt 1.

---

## 2026-10-11 I1 – docs_template-Baseline eingeführt (Bestand übernommen)

Template-Stand: docs_template v27@5ce0f84, Stack `powershell-automation`, keine Overlays. Vorgehen nach
`NEUES_PROJECT_INITIALISIEREN.md` Abschnitt 3d (vorhandenes `docs/` ohne Template-Herkunft). Diff-Anker:
Commit `22da6c2` („docs: snapshot before docs_template baseline"); `.gitignore`-Ergänzung als eigener Commit
`a1d2d09`.

### Added
- Basis-Layer: `KICKOFF.md`, `REFLECTION.md`, `CONVENTIONS_COMMON.md`, `STATE.md`, `TODO.md`, `CHANGELOG.md`,
  `BOOTSTRAP.md`, `GLOSSARY.md`, `KNOWN_ISSUES.md`, `LESSONS_LEARNED.md`, `architecture/` (OVERVIEW, PROJECT_LAYOUT,
  CONFIGURATION, ERROR_HANDLING, ADR-000-template), `security/` (THREAT_MODEL, THREAT_MODEL_GUIDE, DATA_HANDLING,
  DEPENDENCY_AUDIT), `operations/` (SECRETS_MANAGEMENT, INCIDENT_RESPONSE, DEPLOYMENT), `principles/` (21 Dateien)
- Stack `powershell-automation`: `CONVENTIONS.md`, `architecture/DEPENDENCIES.md`, `architecture/CREDENTIAL_STRATEGY.md`,
  `architecture/REMOTE_EXECUTION.md` (bedingt: rund 30 Skripte nutzen `Invoke-Command`, PSSession oder CIM-Sessions),
  `operations/TASK_SCHEDULER.md` (bedingt: Schattenkopie-Aufgaben per `schtasks /xml`), `features/FEATURE-template.md`,
  `security/AUTHENTICATION.md`, `operations/SETUP.md`, `operations/RUNBOOK.md`, `operations/MONITORING.md`,
  `testing/UNIT_TESTS.md`
- `features/SCRIPT_COLLECTION.md` (Hauptfeature: die Skriptsammlung und ihre Pflegewerkzeuge)
- `AGENTS.md` im Repo-Root (reiner Zeiger auf `docs/KICKOFF.md`)
- Inkrementplan I2–I6 in `TODO.md`, bekannte Probleme K1–K7 in `KNOWN_ISSUES.md`

### Changed
- `docs/BACKLOG.md`: Template-Struktur vorangestellt (Ideen, Refactoring, Technische Schuld, Stack-Lücken,
  Verworfen); der bisherige Inhalt (Abschnitte 1–9) steht unverändert darunter
- `.gitignore` (eigener Commit `a1d2d09`): Stack-Einträge (`*.log`, `config.ps1`, `*.tmp`, `*.secret`, `*.pfx`,
  `*.pem`, `*.key`) und `/docs/local/`

### Removed
- Bedingte Template-Dateien ohne zutreffende Bedingung nicht übernommen: `architecture/DOMAIN_MODEL.md` (keine
  fachlichen Entities), `testing/INTEGRATION_TESTS.md` (es gibt keine Tests gegen echte Dienste)

### Security
- Security-Currency-Abgleich beim Init (2026-10-11), Ergebnis in `security/DEPENDENCY_AUDIT.md` → Befunde und
  `security/THREAT_MODEL.md`: PowerShell 7 hatte im Juli/August 2026 mehrere Advisories (u. a. CVE-2026-40400,
  CVE-2026-70337, CVE-2026-70338); Verwaltungs-PCs brauchen den aktuellen Servicing-Stand.
- Codebefunde ohne Fix in diesem Inkrement (Fix in I3/I6): Zugangsdaten in URL-Query und ohne
  Zertifikatsprüfung (`OSBiz.psm1`), TLS-Prüfung per Default aus (`New-PublicSpotUserBulk.ps1`), Laufzeit-
  `Install-Module -Force`.

### Confidence / Ungeprüft
- (a) Kein Skript der Sammlung wurde ausgeführt. K1 ist über PSScriptAnalyzer und ein synthetisches Nachbau-Skript
  belegt, nicht durch einen Lauf von `Set-TeamViewerAccess.ps1`. K2 ist über `git check-attr` und
  Byte-Vergleich Blob/Arbeitskopie belegt; dass `schtasks /xml` an den beschädigten Dateien scheitert, ist nicht
  getestet.
- (b) Annahmen: Das Repository ist öffentlich (laut `README.md`/`CLAUDE.md`; der Klon hat kein Remote). Die
  OSBiz-WSI-API verlangt die Zugangsdaten eventuell zwingend als Query-Parameter — nicht geprüft (Aufgabe in I3).
  Die Versionsangaben der CVE-Quellen widersprechen sich teilweise; maßgeblich ist der MSRC-Update-Guide.
- (c) Nicht vollständig gelesen: die 146 Skripte einzeln (Analyse über `INDEX.md`, gezielte Greps und
  PSScriptAnalyzer); vollständig gelesen: `README.md`, `CLAUDE.md`, `docs/*.md` (Bestand), `.githooks/*`,
  `.gitattributes`, `.gitignore`, zwei der drei `ORIGIN.md` (MailStore nur der Kopf). Die übernommenen
  Template-Dateien unter `principles/` und die generischen Teile von `REFLECTION.md`, `BOOTSTRAP.md`,
  `CONVENTIONS_COMMON.md` sind unverändert übernommen und nur auf Projektbezug überflogen.
- Struktur-Check `validate_project_docs.sh docs --stack powershell-automation` (Template v27@5ce0f84): Exit 0 vor dem
  Commit. Advocatus-Diaboli-Gate von Hand (kein `.claude`-Hook, `STATE.md` Risiken).
- Gegenüber dem Template-Text geändert, damit Prüfungen grün werden: `KICKOFF.md` Phase 3b Punkt 6 (die
  `grep`-Zeile enthielt selbst den Suchbegriff von Prüfung 5), `GLOSSARY.md` „Pflege" (Hinweistext mit
  den Großbuchstaben-Wörtern NEU und DATUM in eckigen Klammern), drei Code-Beispiele mit `# allowlist secret` für den Projekt-Hook
  (`architecture/CREDENTIAL_STRATEGY.md` Anti-Beispiele, `testing/UNIT_TESTS.md` 7.9).

### Lessons Learned
- PSScriptAnalyzer statt Parser für Syntaxprüfungen — Scope: generisch-stack
  Backport-Ziel: `stacks/powershell-automation/CONVENTIONS.md` | Status: offen
  `[Parser]::ParseFile` meldet Code vor `begin`/`process` nicht als Fehler; erst PSScriptAnalyzer
  (`InvalidSyntaxAroundProcessBlock`) zeigt, dass `process {…}` zu `Get-Process` wird. Eine selbstgebaute
  Syntaxprüfung über den Parser allein ist für PowerShell zu schwach.
  → Spiegel-Eintrag in `LESSONS_LEARNED.md` als `## L1:`.
- `.gitattributes`-Ausnahmen mit Pfad brechen still beim Verschieben — Scope: generisch-base
  Backport-Ziel: `base/BOOTSTRAP.md` (Abschnitt `.gitattributes`) | Status: offen
  Pfadgebundene Attribute (`<pfad> binary`) wandern beim `git mv` nicht mit; danach gilt wieder die Muster-Regel
  (hier `text eol=crlf`) und beschädigt UTF-16-Dateien. Besser Muster je Encoding statt Einzelpfade, und nach
  jedem Umzug `git check-attr` prüfen.
  → Spiegel-Eintrag in `LESSONS_LEARNED.md` als `## L2:`.
