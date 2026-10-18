# Entwicklungsumgebung Setup – PowerShellCollections

Zwei Rollen: der **Maintainer** pflegt das Repo (Werkzeuge, Gates, Hook); der **Administrator** setzt einzelne
Skripte ein. Beide arbeiten auf Windows.

---

## Voraussetzungen

- PowerShell ≥ 5.1 (`$PSVersionTable.PSVersion` prüfen)
  - Windows PowerShell 5.1 (vorinstalliert) **und** PowerShell 7 auf aktuellem Servicing-Stand — Skripte mit
    `#Requires -Version 7.0` laufen nur dort, alle anderen müssen unter 5.1 laufen
- Git for Windows (bringt die `sh`-Umgebung für den Pre-commit-Hook mit)
- Für den Einsatz: die RSAT-Features und Module des jeweiligen Skripts (`architecture/DEPENDENCIES.md`) und
  passende Rechte in der Domäne (`security/AUTHENTICATION.md`)
- Für die Pflege: `PSScriptAnalyzer` (Gate 1), `Pester` 5.x (Gate 4, ab `TODO.md` I4)

---

## Installation

### PowerShell 7 (empfohlen)

```powershell
# PowerShell 7 installieren bzw. aktualisieren (Windows, benötigt Adminrechte einmalig)
winget install Microsoft.PowerShell
# oder: https://github.com/PowerShell/PowerShell/releases
```

### Execution Policy (einmalig, aktueller Benutzer)

```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

### Repo klonen und Hook aktivieren (pro Klon)

```sh
git clone https://github.com/gitnol/PowerShellCollections.git
cd PowerShellCollections
git config core.hooksPath .githooks
cp .githooks/forbidden-patterns.local.txt.example .githooks/forbidden-patterns.local.txt
# lokale Datei um die eigenen Firmen-, Personen- und Hostnamen ergaenzen (bleibt gitignored)
```

Ohne lokale Musterliste prüft der Hook nur die generischen Secret-Muster und meldet einen Hinweis
(`docs/CONVENTIONS.md` §11).

### Werkzeuge für die Pflege

```powershell
Install-Module -Name PSScriptAnalyzer -Scope CurrentUser
Install-Module -Name Pester -RequiredVersion 5.7.1 -Scope CurrentUser -SkipPublisherCheck   # ab I4
```

### Module für den Einsatz

Nur die Module des Skripts, das eingesetzt werden soll — Liste und Hinweise in `architecture/DEPENDENCIES.md`.
RSAT unter Windows 10/11:

```powershell
Get-WindowsCapability -Online -Name 'Rsat.ActiveDirectory*' | Add-WindowsCapability -Online
```

### Lokale Konfiguration

Nur einzelne Themenordner haben Konfigurationsdateien (`architecture/CONFIGURATION.md`); Vorlage kopieren, die
Kopie ist dort gitignored:

```powershell
Copy-Item scripts\security\certificates\config.example.json scripts\security\certificates\config.json
```

Interne Umgebungsangaben (Hosts, Versionen, Pfade) für die eigene Arbeit gehören nach `docs/local/` (gitignored).

---

## Wichtige Commands

```powershell
# Skript suchen (ohne Dateien zu laden)
Select-String -Path .\INDEX.md -Pattern 'lockout'

# Hilfe eines Skripts lesen, ohne es auszuführen
Get-Help .\scripts\windows\sessions\Get-LoggedInUsersCim.ps1 -Full

# Testlauf (keine Änderungen), wo das Skript -WhatIf unterstützt
.\scripts\<system>\<thema>\<Skript>.ps1 -WhatIf

# Pflege vor dem Push (docs/CONVENTIONS.md §10)
.\tools\Build-ScriptIndex.ps1
.\tools\Find-ScriptDependency.ps1 -CrossFolderOnly
.\tools\Repair-ScriptEncoding.ps1 -WhatIf

# Gate 1 für geänderte Dateien
Invoke-ScriptAnalyzer -Path <datei> -Severity Error, ParseError
```

---

## Credentials / Konfiguration

| Variable / Parameter | Beschreibung | Fundort |
|---------------------|-------------|---------|
| Kerberos-Anmeldung | AD, WinRM, Exchange On-Prem | Anmeldesitzung des Administrators |
| `Get-Credential` beim Lauf | REST-APIs, vCenter, Router, SMTP | Passwortverwaltung der betreibenden Organisation |
| `-Token` (Zammad) | API-Token als Klartext-`[string]`; interaktiv per `Read-Host -AsSecureString` einlesen (Beispiel in `Get-ZammadTicket.ps1`) | Zammad-Profil des Benutzers → Token-Zugriff |

> **Niemals Credentials in `config.ps1` oder lokale JSON-Konfigurationen schreiben.** `config.ps1` steht in der
> `.gitignore`; Details `architecture/CREDENTIAL_STRATEGY.md`.
