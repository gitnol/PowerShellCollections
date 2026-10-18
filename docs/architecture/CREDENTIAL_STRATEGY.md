# Credential-Strategie – PowerShellCollections

Wo und wie Credentials für PowerShell-Automatisierung gespeichert und benutzt werden.
Konkretisiert `docs/operations/SECRETS_MANAGEMENT.md` für Windows / PowerShell.

---

## Ist-Stand im Projekt (Analyse 2026-10-11)

Die Sammlung **speichert keine Zugangsdaten**. Im Repo liegen keine Credential-Dateien; der Pre-commit-Hook
(`.githooks/forbidden-patterns.txt`) weist Klartext-Passwörter, Token-Zuweisungen, `ConvertTo-SecureString` mit
Literal und private Schlüssel ab. Laut `docs/HISTORY-OPTIONS.md` sind auch alle passwortartigen Fundstellen der
History Platzhalter.

| Fall | Heutiges Verfahren | Bewertung |
|---|---|---|
| AD, WinRM, CIM, Exchange On-Prem | Kerberos im Kontext des angemeldeten Administrators | passend; kein Secret im Skript |
| REST-APIs (Zammad, MailStore, LANCOM, OSBiz) | Parameter `[SecureString]`/`[PSCredential]` bzw. interaktiv `Get-Credential` — **Ausnahmen:** `OSBiz.psm1` (`-User`/`-Pass` als `[string]`, Zugangsdaten in der URL), `New-PublicSpotUser.ps1` und die MailStore-Funktionen (Passwort-Parameter als `[string]`, PSScriptAnalyzer `PSAvoidUsingUsernameAndPasswordParams`), Zammad-Funktionen (`-Token` als `[string]`) | Ausnahmen in `TODO.md` I3 bzw. Mittlere Priorität |
| SMTP (Ping-Monitor) | `Get-Credential` beim Start, nur im Speicher | passend |
| Microsoft Graph | interaktive Anmeldung `Connect-MgGraph` (delegiert) | passend |
| PFX-Export (`New-Certificate.ps1`) | `-ExportPassword` als `[string]`, optional aus lokaler `config.json` | Klartext; `TODO.md` I3 |
| Geplante Aufgaben (Schattenkopien) | Konto `SYSTEM` (SID `S-1-5-18`), kein Secret | passend |

Die folgenden Abschnitte sind die Vorgaben für **neue** Skripte und für den Umbau der Ausnahmen.

---

## Erlaubte Speicherorte

| Credential-Typ | Empfohlener Store | Bemerkung |
|---|---|---|
| Service-Account-Passwort (Task Scheduler) | Task-Scheduler (verschlüsselt) | Einmal beim Erstellen eingeben |
| API-Token / OAuth-Secret | Windows Credential Manager / `SecretManagement`-Modul | Nicht in `config.ps1` |
| DB-Passwort | `SecretManagement` mit Vault-Backend | — |
| SSH-Key (privat) | `~/.ssh/` mit ACL, oder OpenSSH-Agent | — |
| DPAPI-Secret-File | `[file].dpapi` per `ConvertFrom-SecureString` | Nur dieser User/Account kann entschlüsseln |

---

## DPAPI-Pattern (User-bound)

```powershell
# Speichern (einmal, als Service-Account ausgeführt)
$secure = Read-Host "API-Token" -AsSecureString
$secure | ConvertFrom-SecureString | Out-File "$PSScriptRoot\secrets\api-token.dpapi"

# Lesen (zur Laufzeit)
$secure = Get-Content "$PSScriptRoot\secrets\api-token.dpapi" | ConvertTo-SecureString
$token = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto(
    [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($secure))
```

**Wichtig:** DPAPI verschlüsselt mit dem User-Profil. Wenn der Task auf einem
anderen Account laufen soll, muss der Encrypt-Schritt auf dem Ziel-Account
ausgeführt werden.

`.dpapi`-Dateien gehören in `.gitignore`.

---

## `SecretManagement` (Modul, plattformübergreifend)

```powershell
Install-Module Microsoft.PowerShell.SecretManagement -Scope CurrentUser
Install-Module Microsoft.PowerShell.SecretStore -Scope CurrentUser

Register-SecretVault -Name LocalStore -ModuleName Microsoft.PowerShell.SecretStore -DefaultVault

Set-Secret -Name "ApiToken" -Secret "..."
$token = Get-Secret -Name "ApiToken" -AsPlainText
```

Vault-Master-Passwort selbst kann via DPAPI gespeichert werden → ein
Layer-Wechsel pro Boot.

---

## Service-Account-Strategie

| Szenario | Service-Account | Hinweis |
|---|---|---|
| Lokales Skript, kein Netzwerk | Aktueller Benutzer | DPAPI ausreichend |
| Task Scheduler, lokales System | gMSA (Group Managed Service Account) | Passwort vom AD verwaltet |
| Task Scheduler, Netzwerk-Ressourcen | gMSA / dedizierter Service-User | Niemals Domänen-Admin |
| WinRM / SSH | Eigenes Service-Konto mit Least Privilege | — |

---

## Anti-Pattern

```powershell
# Verboten: Klartext-Passwort im Skript
$password = "Geheim123"   # allowlist secret (Anti-Beispiel)

# Verboten: Klartext in config.ps1, das in git landet
$cred = @{ Username = "svc-app"; Password = "Geheim123" }   # allowlist secret (Anti-Beispiel)

# Verboten: Credential als Plain-String an Cmdlets weiterreichen
Invoke-RestMethod -Headers @{ Authorization = "Bearer Geheim123" }
```

---

## Pattern: `[PSCredential]` durchreichen

```powershell
function Connect-Api {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [pscredential]$Credential
    )
    # nutze $Credential.UserName und $Credential.GetNetworkCredential().Password
}

# Verwendung
$secure = Get-Secret -Name "ApiToken"
$cred = [pscredential]::new("ignored", $secure)
Connect-Api -Credential $cred
```

`[pscredential]` hält Passwort als `SecureString` im Speicher und im
Aufruf-Stack — niemals als Klartext-String herumreichen.

---

## Logging-Regeln

- Niemals `Write-Log "Token: $token"` — auch nicht „nur die ersten Zeichen".
- Bei Fehlern: Auth-Failure als Event („401 Unauthorized") loggen, nicht den
  konkreten Token-Wert oder Header-Inhalt.

---

## Rotation

| Credential | Intervall | Trigger außerplanmäßig |
|---|---|---|
| API-Token | 90 Tage | Leak-Verdacht, Mitarbeiterwechsel |
| Service-Account-Passwort | gMSA: AD-managed; sonst jährlich | Verdacht auf Kompromittierung |
| SSH-Key | 6–12 Monate | Compute-Wechsel |

---

## Pflege

Trigger: neuer Service / neue Credential-Quelle / Rotation durchgeführt →
hier eintragen und in `docs/operations/SECRETS_MANAGEMENT.md` referenzieren.
