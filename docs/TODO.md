# TODO – PowerShellCollections

Einzige Quelle des Inkrementplans (KICKOFF verweist nur hierher). Pro Inkrement: Aufgaben und — falls über die
Standard-DoD hinaus nötig — zusätzliche Kriterien. Ein Inkrement gilt erst als erledigt, wenn die Standard-DoD
**und** seine eigenen Kriterien erfüllt sind.

Parkplatz für noch unspezifizierte Ideen: `BACKLOG.md`.
Bekannte Bugs ohne aktiven Fix: `KNOWN_ISSUES.md`.

Grundlage der Priorisierung ist die Codebase-Analyse beim Init (2026-10-11): PSScriptAnalyzer-Basislinie,
Durchsicht der Skripte mit Netz-, Credential- und Remote-Zugriffen sowie der vorhandenen Doku
(`docs/BACKLOG.md`, `docs/STRUCTURE.md`, `docs/HISTORY-OPTIONS.md`). Entscheidungen, die nur der
Repo-Eigentümer treffen kann (History-Bereinigung, Lizenzlage Fremdcode, `CLAUDE.md`), stehen in `STATE.md`
„Risiken & Blocker" und sind bewusst keine Agenten-Inkremente.

---

## Standard-Definition of Done (gilt für jedes Inkrement — nicht abhaken, sie bleibt stehen)

- Code-Änderungen abgeschlossen, kein TODO-/FIXME-Kommentar offen
- Quality Gates grün (`CONVENTIONS_COMMON.md` §5; Befehle in `CONVENTIONS.md`)
- Integration-Tests grün, falls relevant
- Security-Checkliste aus `CONVENTIONS.md` durchgegangen (falls der Stack eine liefert)
- Trigger-Matrix in `KICKOFF.md` Phase 3a geprüft → alle relevanten Docs aktualisiert
  (`architecture/OVERVIEW.md`, `features/`, `architecture/`, `security/`, `GLOSSARY.md`, `KNOWN_ISSUES.md`, `LESSONS_LEARNED.md`)
- `STATE.md`: Tabellenzeile + „Nächster Schritt"-Abschnitt aktualisiert
- `CHANGELOG.md`: neuer Abschnitt mit Datum + Inkrement-Titel + Sections
  (Added / Changed / Fixed / Removed / Security / Confidence / Ungeprüft / Lessons Learned)
- KICKOFF Phase 3b vollständig (Struktur-Check, TODO-Verschiebung, Advocatus-Diaboli-Gate)
- Commit erstellt (`<type>(<scope>): <desc>`); Commit-Hash in `STATE.md` eingetragen
- Projektpflege aus `CONVENTIONS.md` §10 gelaufen (`Build-ScriptIndex`, `Find-ScriptDependency -CrossFolderOnly`,
  `Repair-ScriptEncoding -WhatIf`), sobald Skripte angelegt, verschoben, umbenannt oder gelöscht wurden

---

## Aktuell (Hohe Priorität)

### I3: Zugangsdaten nur geprüft verschlüsselt übertragen

Drei Stellen schicken Zugangsdaten ohne Zertifikatsprüfung bzw. als Klartext-String (`security/THREAT_MODEL.md`
Bedrohung 2). Muster: `CONVENTIONS.md` §6.1.2 (`-Force` für gefährliche Schalter) und
`architecture/CREDENTIAL_STRATEGY.md` (`[PSCredential]` durchreichen).

**Aufgaben:**

- [ ] `scripts/applications/openscape-business/OSBiz.psm1`: `-SkipCertificateCheck` nicht mehr fest, sondern als Schalter
      mit `-Force`-Bestätigung; Login nimmt `[PSCredential]` statt `-User`/`-Pass`-Strings. Prüfen (Herstellerdoku), ob
      die WSI-API den Login auch ohne Zugangsdaten in der URL akzeptiert; sonst die Einschränkung in
      `KNOWN_ISSUES.md` festhalten
- [ ] `scripts/network/lancom/New-PublicSpotUserBulk.ps1`: Default `-SkipCertificateCheck $true` → `$false`, unsichere
      Variante nur mit `-Force`; `New-PublicSpotUser.ps1`: fest verdrahtetes `-SkipCertificateCheck` ebenso
- [ ] `scripts/security/certificates/New-Certificate.ps1`: `-ExportPassword` als `[SecureString]` statt `[string]`
      (PSScriptAnalyzer-Error `PSAvoidUsingConvertToSecureStringWithPlainText`)
- [ ] READMEs der drei Bereiche an die geänderten Parameter anpassen

**Zusätzliche DoD** (nur, was über die Standard-DoD hinausgeht):

- [ ] Pester-Tests mit `Mock Invoke-RestMethod`: ohne `-Force` wird bei unsicherer Option vor jedem Netzaufruf geworfen
- [ ] Keine Ausführung gegen echte Telefonanlage/Router/CA — Verhalten nur über Mocks belegt; Live-Test als
      „ungeprüft" im Confidence-Block

### I4: Quality-Gate-Fundament: PSScriptAnalyzer-Gate und erste Pester-Tests

Ohne Gate fallen Fehler wie K1 erst im Einsatz auf. Ziel ist ein kleines, sofort grünes Fundament mit Ratchet,
nicht das Abarbeiten aller 1107 Altbefunde.

**Aufgaben:**

- [ ] `PSScriptAnalyzerSettings.psd1` im Repo-Root: Severity Error + ParseError als Gate; Warnings vorerst nur als
      Ratchet (Anzahl darf nicht steigen)
- [ ] `tests/` existiert bereits seit I2 (ein Regressionstest für K1); `RequiredModules.psd1` ergänzen und
      Pester 5.7.1 formal pinnen (`testing/UNIT_TESTS.md`)
- [ ] Erste Unit-Tests für `modules/PSCollections.Connectivity` (Pipeline-Eingabe: drei Eingaben → drei Ergebnisse;
      eigene Hintergrundjobs des Aufrufers bleiben unberührt) — beides Fehler, die `docs/BACKLOG.md` Abschnitt 3
      als behoben beschreibt
- [ ] Gate-Befehle in `CONVENTIONS.md` §9 auf die echten Pfade setzen

**Zusätzliche DoD** (nur, was über die Standard-DoD hinausgeht):

- [ ] Mutationsnachweis für die Charakterisierungstests (KICKOFF Phase 2: gezielter Fehler im Modul → Test rot)
- [ ] Basislinie und Ratchet-Wert in `STATE.md` „Kennzahlen (gemessen)" mit Messbefehl

---

## Mittlere Priorität

### I5: Pre-commit-Hook um Commit-Message- und Dateinamen-Prüfung ergänzen

`CONVENTIONS_COMMON.md` §3.1 verlangt die Interna-Prüfung auch für Dateinamen und Commit-Messages; der
vorhandene Projekt-Hook (`.githooks/pre-commit`) prüft nur neu hinzukommenden Dateiinhalt.

**Aufgaben:**

- [ ] `.githooks/commit-msg` anlegen: Commit-Message gegen dieselben beiden Musterlisten prüfen
- [ ] `.githooks/pre-commit`: Pfade der Kandidaten zusätzlich gegen die Musterlisten prüfen
- [ ] `CLAUDE.md`-Abschnitt „Durchsetzung" bzw. `docs/CONVENTIONS.md` §11 nachziehen (Eigentümer-Freigabe für `CLAUDE.md`)

**Zusätzliche DoD** (nur, was über die Standard-DoD hinausgeht):

- [ ] Test mit einem Wegwerf-Begriff in einer temporären lokalen Musterliste: Commit-Message und Dateiname werden
      abgewiesen; SIGPIPE-Schutz (`| head -3`) bleibt wirksam

### I6: Gefährliche Voreinstellungen entschärfen

**Aufgaben:**

- [ ] `scripts/security/passwords/Test-ADUserWeakPassword.ps1`: Konfiguration als Parameter statt Variablen im
      Skriptkopf; `SupportsShouldProcess`; Kontenänderungen (`PasswordNeverExpires`, `ChangePasswordAtLogon`)
      nur mit ausdrücklichem Schalter (heute Voreinstellung `$true`)
- [ ] `scripts/active-directory/user-photo/Set-UserPhotoHybrid.ps1` und
      `scripts/security/certificates/New-Certificate.ps1`: kein `Install-Module -Force` zur Laufzeit; stattdessen
      Prüfung mit klarer Fehlermeldung und Installationshinweis (Version pinnen, `architecture/DEPENDENCIES.md`)

**Zusätzliche DoD** (nur, was über die Standard-DoD hinausgeht):

- [ ] Pester-Test: ohne Schalter ruft `Test-ADUserWeakPassword` kein `Set-ADUser` auf (Mock)

### Weitere Punkte mittlerer Priorität (noch ohne Inkrement-Zuschnitt)

- [ ] window-cascade: BETA-Fehler beheben und eine Datei kanonisch machen (`docs/BACKLOG.md` Abschnitt 9, `KNOWN_ISSUES.md` K4)
- [ ] MailStore-Generator `New-MailStoreApiFunctionReference.ps1`: Passwort-Parameter als `[SecureString]` erzeugen
      (10 PSScriptAnalyzer-Errors `PSAvoidUsingUsernameAndPasswordParams` in generierten Dateien)

---

## Niedrige Priorität

- [ ] `docs/STRUCTURE.md`: veraltete Abschnitte „Versionsstaende" und „Was als Naechstes ansteht" auf den Stand von
      `docs/BACKLOG.md` bringen (`KNOWN_ISSUES.md` K7)
- [ ] Aufgaben-XML in `scripts/windows/shadow-copy/` auf ASCII-Dateinamen umbenennen (Namensregel), Aufrufer anpassen
- [ ] Exchange-Skripte: wirkungslose `-SkipCACheck`/`-SkipCNCheck`-Optionen bei `http://`-Kerberos-Verbindung entfernen
      (`security/THREAT_MODEL.md` Bedrohung 3)

### I7: Modulvertrag von PSCollections.Connectivity an architecture/MODULE.md angleichen

Beim Template-Update auf v28 aufgefallen (`docs/architecture/MODULE.md`, Stellen „offen (I7)"); der Code weicht von
den neuen Regeln in `CONVENTIONS.md` §2/§3 ab, ohne dass heute ein Fehler sichtbar ist.

**Aufgaben:**

- [ ] `PSCollections.Connectivity.psm1`: `Set-StrictMode -Version 3.0` statt `Latest`
- [ ] `PSCollections.Connectivity.psm1`: `Export-ModuleMember` entfernen — Exportliste nur im Manifest
- [ ] `PSCollections.Connectivity.psd1`: `CompatiblePSEditions = @('Desktop', 'Core')` und
      `PrivateData.PSData.ReleaseNotes` (Verweis auf `docs/CHANGELOG.md`) ergänzen; Patch-Version anheben
- [ ] Modultest `tests/modules/PSCollections.Connectivity/PSCollections.Connectivity.Module.Tests.ps1` nach
      `architecture/MODULE.md` „Modultests" (sinnvoll zusammen mit I4, das die ersten Verhaltenstests bringt)

**Zusätzliche DoD** (nur, was über die Standard-DoD hinausgeht):

- [ ] Alle vier Aufrufer (`architecture/MODULE.md` „Aufbau") laden das Modul nach der Änderung weiterhin; Modultest
      rot, wenn eine Funktion aus `FunctionsToExport` entfernt wird (Mutationsnachweis)
- [ ] Markierungen „offen (I7)" in `architecture/MODULE.md` und `CONVENTIONS.md` §2/§3 entfernt

---

## Abgeschlossen

- I1 docs_template-Baseline eingeführt (Bestand übernommen) — [ABGESCHLOSSEN 2026-10-11]
- I2 Defekte Bestandsdateien reparieren (TeamViewer-Skript, `.gitattributes`, Index-Syntaxprüfung) — [ABGESCHLOSSEN 2026-10-13]
