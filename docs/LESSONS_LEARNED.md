# Lessons Learned – PowerShellCollections

Strukturierter Index für gelernte Patterns. Jeder Eintrag benennt Scope und
Backport-Ziel, damit die Reflexions-Phase (REFLECTION.md Schritt 3) offene
generische Patterns als Backport-Vorschlag melden kann; eingespielt wird erst nach Freigabe
des Prompters (REFLECTION.md Schritt 3, Freigabe-Disziplin).

Neue Einträge entstehen aus dem „Lessons Learned"-Abschnitt der `CHANGELOG.md` —
dort kurze Beschreibung, hier der strukturierte Steckbrief.

Lehren aus der Zeit vor der Baseline stehen als Fließtext in `CLAUDE.md` („Fallstricke in diesem Bestand") und
`docs/BACKLOG.md` (Abschnitte 1, 3, 4, 7, 9); sie werden hier nicht nachträglich nummeriert.

---

## L1: PSScriptAnalyzer statt Parser für Syntaxprüfungen
- Inkrement: I1
- Scope: generisch-stack
- Backport-Ziel: `stacks/powershell-automation/CONVENTIONS.md` (§2 bzw. §9)
- Status: offen

`[System.Management.Automation.Language.Parser]::ParseFile` meldet Code vor `begin`/`process` nicht als Fehler;
erst PSScriptAnalyzer (`InvalidSyntaxAroundProcessBlock`) zeigt, dass `process {…}` dann zu `Get-Process` wird.
Syntaxprüfungen in eigenen Werkzeugen (hier `Build-ScriptIndex.ps1`) brauchen deshalb PSScriptAnalyzer.

---

## L2: Pfadgebundene `.gitattributes`-Ausnahmen brechen still beim Verschieben
- Inkrement: I1
- Scope: generisch-base
- Backport-Ziel: `base/BOOTSTRAP.md` (Abschnitt `.gitattributes`)
- Status: offen

Eine Ausnahme wie `<pfad> binary` wandert bei `git mv` nicht mit; danach gilt wieder die Muster-Regel
(`*.xml text eol=crlf`) und beschädigt UTF-16-Dateien beim Checkout, ohne dass `git status` etwas zeigt.
Besser Muster je Dateityp/Encoding statt Einzelpfade, und nach jedem Umzug `git check-attr -a -- <pfad>` prüfen.

---

## Pflege

- Neuer „Lessons Learned"-Block im `CHANGELOG.md` → Eintrag `## L<N>:` hier anlegen.
- Mehrere Patterns aus einem Inkrement → mehrere `## L<N>:`-Einträge.
- Scope-Werte:
  - `projekt-spezifisch` — nur für dieses Projekt relevant, kein Backport nötig.
  - `generisch-stack` — gehört in `docs_template/stacks/<stack>/CONVENTIONS.md` o.ä.
  - `generisch-base` — gehört in `docs_template/base/` (Prinzip, Basis-Convention, MANIFEST).
- Status `offen` → wird bei der nächsten Reflexion (REFLECTION.md Schritt 3) als Backport-Vorschlag gemeldet;
  bleibt `offen` bis zur Freigabe.
- Status `backported vN@<commit>` → Backport-Commit ins Template-Repo durchgeführt (Template-Stand
  Version + Commit, z. B. `v26@0a4c8f1`); der Tag `vN` folgt erst nach dem Pre-Tag-Gate (REFLECTION.md Schritt 3b).
- Status `projekt-intern` → Endzustand für `Scope: projekt-spezifisch` (kein Backport vorgesehen; die Lesson gilt
  im Projekt weiter). Wird in der Reflexion nicht als Backport-Kandidat gemeldet.
- Niemals Patterns löschen, auch wenn überholt — `Status: verworfen (<grund>)` setzen.
- Diese Datei steht in der Trigger-Matrix in `KICKOFF.md` Phase 3a.
