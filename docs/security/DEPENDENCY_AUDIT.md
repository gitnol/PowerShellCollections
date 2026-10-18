# Dependency-Audit – PowerShellCollections

Wann und wie Abhängigkeiten auf bekannte Schwachstellen geprüft werden.
Verbindet sich mit `architecture/DEPENDENCIES.md` (Was ist drin?) und
`security/THREAT_MODEL.md` (Bedrohung: Vulnerable Dependencies).

---

## Wann auditieren

| Auslöser | Pflicht? |
|---|---|
| Vor jedem Release | Ja |
| Bei neuer oder aktualisierter Dependency | Ja, die betroffene + Transitive |
| Nach Sicherheitsmeldung (CVE) für eine genutzte Dep | Ja, sofort |
| Kadenz-Sweep (Scanner **und** Web-Advisory-/Best-Practice-Recherche für Base+Stack) | Default 14 Tage, Marker `**Nächster Security-Sweep:**` im `STATE.md`-Kopf — `principles/SECURITY_CURRENCY.md` |

---

## Audit-Befehle pro Stack

| Stack | Befehl | Output | Bemerkung |
|---|---|---|---|
| Python | `pip-audit -r requirements.txt` | CVE-Liste mit Fix-Version | Alternativ: `safety check` |
| Python (pyproject) | `pip-audit` (im aktivierten venv) | Wie oben | Erfasst auch lock-File |
| .NET | `dotnet list package --vulnerable --include-transitive` | Pakete + Severity | NuGet-Audit-API |
| PowerShell | `Get-Module ... | Find-Module -AllowPrerelease` + manueller Abgleich gegen `MSRC` | begrenzt | PSGallery hat keine integrierte CVE-DB — manuell prüfen |
| Node | `npm audit` / `yarn audit` | CVE-Bericht | `npm audit fix` zum Patchen |
| Rust | `cargo deny check advisories` (bzw. `cargo audit`) | RustSec-Advisories mit Fix-Version | `cargo deny check` prüft zusätzlich Lizenzen/Quellen; liest `Cargo.lock` |

> Ergebnis als Artefakt sichern (`docs/audits/<JJJJ-MM-TT>-deps.txt` oder
> CI-Artefakt), damit Historie nachvollziehbar bleibt.

**In diesem Projekt:** Es gibt keine Lock-Datei und keinen Scanner. Der Bestand (Module, Binaries, Dienste) steht in
`architecture/DEPENDENCIES.md`; das Audit ist eine Web-Recherche je Kadenz-Sweep (MSRC-Update-Guide, Advisories
der Modulhersteller, GitHub-Advisories der Modul-Repos) für PowerShell 5.1/7, die genutzten PSGallery-Module und
den Fremdcode unter `third-party/`. Ergebnisse direkt in die Befunde-Tabelle unten (kein eigenes `docs/audits/`,
solange die Tabelle ausreicht). Ob ein konkreter interner Rechner betroffen ist, gehört nach `docs/local/`.

---

## Schweregrad-Politik

| Severity | Reaktion |
|---|---|
| Critical | Sofort patchen (innerhalb 24h) oder Mitigation (Feature deaktivieren); blockiert das Inkrement |
| High | Blockiert das aktuelle Inkrement, bis gepatcht oder mitigiert (`principles/SECURITY_CURRENCY.md`) |
| Medium | Im nächsten regulären Inkrement |
| Low | Backlog; bei nächstem Major-Upgrade mitziehen |

Mitigation kann auch sein: Nutzung der verwundbaren Funktion entfernen,
falls Update nicht möglich ist.

---

## Befunde (datiert)

Ablage für Scanner- und Recherche-Ergebnisse (`principles/SECURITY_CURRENCY.md` → Artefakt). Neueste oben.
Öffentliches oder potenziell öffentliches Repo: die Betroffenheit **konkreter interner Hosts** nur in `docs/local/`,
hier nur generisch (`CONVENTIONS_COMMON.md` 3.1).

| Datum | Quelle (Scanner / URL) | Paket / Version | Befund | betrifft uns? (Begründung) | Maßnahme / Restrisiko |
|---|---|---|---|---|---|
| 2026-10-11 | [Tenable 335413](https://www.tenable.com/plugins/nessus/335413), [stack.watch CVE-2026-70337](https://stack.watch/vuln/CVE-2026-70337/) | PowerShell 7.4 < 7.4.19, 7.5 < 7.5.10, 7.6 < 7.6.5 | August 2026: CVE-2026-70337 (Path Traversal, Codeausführung über Netz), CVE-2026-70338 (Umgehung einer Schutzfunktion, CVSS 7.8), CVE-2026-58612 (SSRF) | ja, für Verwaltungs-PCs mit PS 7 (Skripte mit `#Requires -Version 7.0`) | PS 7 auf aktuellen Servicing-Stand heben; Restrisiko gering nach Update |
| 2026-10-11 | [stack.watch CVE-2026-40400](https://stack.watch/vuln/CVE-2026-40400/) | PowerShell 7.5 < 7.5.11, 7.6 < 7.6.6; Windows-Builds bis Juli-Update | Juli 2026: Relative Path Traversal in PowerShell, Codeausführung durch authentifizierten Angreifer | ja, PS 7 und Windows PowerShell 5.1 (über Windows-Builds) | aktueller Stand laut Recherche 7.6.6 / 7.5.11 / 7.4.20 (Sept. 2026); Windows-Updates. Versionsangaben der Quellen widersprechen sich teils — maßgeblich ist der [MSRC-Update-Guide](https://msrc.microsoft.com/update-guide/vulnerability/CVE-2026-40400) |
| 2026-10-11 | [Aqua Nautilus / Dark Reading](https://www.darkreading.com/application-security/powershell-gallery-prone-to-typosquatting-other-supply-chain-attacks) | PowerShell Gallery (Bezugsquelle) | Typosquatting und kopierte Autorenangaben möglich (Forschung 2023; kein Beleg für eine vollständige Behebung gefunden) | ja: `Set-UserPhotoHybrid.ps1` und `New-Certificate.ps1` installieren zur Laufzeit ungepinnt mit `-Force` | `TODO.md` I6 (vorab installieren, Version pinnen); `security/THREAT_MODEL.md` Bedrohung 5 |
| 2026-10-11 | [Broadcom: VCF PowerCLI 9.0](https://blogs.vmware.com/cloud-foundation/2025/06/24/introducing-vcf-powercli-9-0/) | `VMware.PowerCLI` | Modul heißt seit 9.0 `VCF.PowerCLI` (Nachfolger laut Hersteller, Cmdlets kompatibel) | ja: VMware- und Zertifikatsskripte | beim nächsten Anfassen umstellen (`architecture/DEPENDENCIES.md`); kein CVE-Befund |
| 2026-10-11 | [PSGallery Microsoft.Graph 2.41.1](https://www.powershellgallery.com/packages/Microsoft.Graph/2.41.1) | `Microsoft.Graph.Users` | aktuelle Version 2.41.1 (Okt. 2026); kein Advisory gefunden | ja: `Set-UserPhotoHybrid.ps1` | Version pinnen; Restrisiko gering |
| 2026-10-11 | [Exchange Remote PowerShell (Microsoft Learn, archiviert)](https://technet.microsoft.com/en-gb/library/dd335083) | Exchange-Remoting `http://…/PowerShell/` | Mit Kerberos ist `http` der dokumentierte Weg (Verschlüsselung auf WinRM-Ebene); `-SkipCACheck/-SkipCNCheck` schwächen nur `https` | teilweise: `New-SharedMailboxWorkflow.ps1` setzt `-SkipRevocationCheck`, `Sync-SharedMailboxPermission.ps1` zusätzlich `-SkipCACheck -SkipCNCheck` — bei `http` wirkungslos | Optionen entfernen (`TODO.md` Niedrige Priorität); kein aktueller Herstellerhinweis 2025/26 gefunden |

---

## SBOM (optional)

Software Bill of Materials für regulierte Projekte:

- Python: `cyclonedx-py` / `pip-licenses`
- .NET: `dotnet CycloneDX`
- Node: `npm sbom --sbom-format cyclonedx` (npm ≥ 9.5) bzw. `@cyclonedx/cyclonedx-npm`
- Rust: `cargo cyclonedx` (cargo-cyclonedx)
- Format: CycloneDX oder SPDX

SBOM gehört in `docs/audits/` oder als Build-Artefakt — nicht in den
Quellbaum als rotierende Datei.

---

## Was nicht ausreicht

- **„Wir nutzen nur populäre Bibliotheken"** — populär ≠ sicher (siehe
  `event-stream`, `colors.js`, `xz-utils`).
- **GitHub Dependabot allein** — gut für externe Repos, nicht ausreichend
  für private/interne Deps oder Binaries.
- **Einmaliger Audit beim Projektstart** — Audits müssen wiederholt werden,
  weil neue CVEs ständig erscheinen.
- **Scanner-Lauf allein** — `pip-audit`/`dotnet --vulnerable`/`npm audit` finden
  bekannte CVEs der Deps, aber keine Härtungs-Best-Practices und keine Advisories
  ohne CVE-Eintrag. Web-Recherche nach `principles/SECURITY_CURRENCY.md` ergänzt
  den Scanner, ersetzt ihn nicht (und umgekehrt).

---

## Pflege

Trigger (siehe `KICKOFF.md` Phase 3a): neue Dependency hinzugefügt /
CVE-Meldung erhalten / Audit-Tool geändert → diese Datei + Audit-Artefakt
aktualisieren.
