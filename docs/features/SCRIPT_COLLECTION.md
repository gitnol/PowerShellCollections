# Feature: Skriptsammlung und Pflegewerkzeuge

Hauptfeature des Projekts. Einzelne Skripte beschreibt ihre Comment-Based Help (Übersicht: `INDEX.md`) bzw. die
README ihres Themenordners; diese Datei beschreibt, was für die Sammlung als Ganzes gilt.

---

## Zweck

Administratoren finden für eine wiederkehrende Windows-/AD-Betriebsaufgabe ein lesbares, eigenständiges Skript —
schnell auffindbar (`INDEX.md`), einheitlich abgelegt (`docs/STRUCTURE.md`) und ohne firmenspezifische Daten.

---

## Technologie / Abhängigkeiten

- Windows PowerShell 5.1 / PowerShell 7; Module je Skript (`architecture/DEPENDENCIES.md`)
- Zielsysteme: AD, Windows-Rechner per WinRM/CIM, Exchange, vSphere, Netzgeräte, Fachanwendungen per REST
- Repo-Werkzeuge: `tools/Build-ScriptIndex.ps1`, `tools/Find-ScriptDependency.ps1`, `tools/Repair-ScriptEncoding.ps1`
- Git-Hook: `.githooks/pre-commit`

---

## Parameter

Parameter der drei Pflegewerkzeuge, soweit in `CLAUDE.md`, `README.md` und `docs/` dokumentiert (vollständig:
`Get-Help .\tools\<Werkzeug>.ps1 -Full`). Die Parameter der Betriebsskripte stehen in deren Comment-Based Help.

| Parameter | Typ | Pflicht | Default | Validierung | Beschreibung |
|-----------|-----|---------|---------|-------------|-------------|
| `Build-ScriptIndex -PassThru` | Switch | Nein | `$false` | — | Indexzeilen zusätzlich als Objekte ausgeben (z. B. Skripte ohne `.SYNOPSIS` finden) |
| `Find-ScriptDependency -CrossFolderOnly` | Switch | Nein | `$false` | — | nur Aufrufe über Ordnergrenzen melden; Soll-Ergebnis `ungedeckt: 0` |
| `Repair-ScriptEncoding -WhatIf` | Switch | Nein | `$false` | — | Dry-Run: betroffene Dateien (Nicht-ASCII ohne BOM) nur melden |

---

## Kritische Patterns

- Ein Skript je Aufgabe, abgelegt unter dem System, gegen das es läuft (`docs/STRUCTURE.md`)
- Comment-Based Help mit `.SYNOPSIS` — Quelle für `INDEX.md`; `INDEX.md` nie von Hand bearbeiten
- UTF-8-BOM bei Nicht-ASCII-Inhalt; Zeilenenden per `.gitattributes`
- Gemeinsamer Code nur unter `modules/` (Drei-Domänen-Regel), Import über Suchlauf nach oben
- Keine Interna; Platzhalterwerte (`docs/CONVENTIONS.md` §11)

---

## Bekannte Einschränkungen

| Einschränkung | Ursache | Status |
|---------------|---------|--------|
| Qualität und Aktualität der Skripte schwanken | über Jahre gewachsen, ein Autor (`README.md` „Zustand der Skripte") | akzeptiert; Ratchet über Gates (`TODO.md` I4) |
| Index meldet Strukturfehler um `begin`/`process` nicht | Prüfung nur mit dem PowerShell-Parser (`KNOWN_ISSUES.md` K3) | geplant in `TODO.md` I2 |
| Die meisten Skripte führen beim Laden Code aus | gewachsener Stil (`KNOWN_ISSUES.md` K6) | akzeptiert |
| UTF-16-Dateien im Arbeitsverzeichnis beschädigt | `.gitattributes` (`KNOWN_ISSUES.md` K2) | geplant in `TODO.md` I2 |

---

## Bekannte Fallstricke

- Dot-Sourcing zum Erkunden kann AD-, Remote- oder Webzugriffe auslösen — lesen statt laden
- Generierter Code (`New-MailStoreApiFunctionReference.ps1`) kann kaputt sein; der Generator prüft seine Ausgabe
  inzwischen selbst, der Index markiert Syntaxfehler
- Der Hook prüft nur neu hinzukommenden Inhalt — eine reine Verschiebung löst ihn nicht aus; Altbestand bereinigt
  man getrennt (`docs/HISTORY-OPTIONS.md`)
- `third-party/` nicht anfassen; Änderungen upstream oder als Wrapper

---

## Teststrategie

- Zugehörige Testdateien (ab `TODO.md` I4): `tests/modules/PSCollections.Connectivity.Tests.ps1`,
  Regressionstests unter `tests/scripts/…`, später `tests/tools/…` für die Pflegewerkzeuge
- Pester-Beschreibung: `Describe 'Test-ConnectionInParallel' { ... }` bzw. je Werkzeug `Describe 'Build-ScriptIndex' { ... }`
- Kritische Testfälle: Pipeline-Eingabe vollständig verarbeitet; `Build-ScriptIndex` markiert eine Datei mit Code vor
  `begin`/`process` als Syntaxfehler; `Find-ScriptDependency` meldet eine verbotene ordnerübergreifende Kante;
  `Repair-ScriptEncoding -WhatIf` ändert keine Datei
