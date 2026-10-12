# Authentication – PowerShellCollections

Wer sich wo mit welchem Verfahren anmeldet. Die Sammlung läuft fast ausschließlich **interaktiv im Kontext des
angemeldeten Administrators**; gespeicherte Zugangsdaten gibt es nicht (Ist-Stand und Bewertung:
`architecture/CREDENTIAL_STRATEGY.md`). Konkrete Hosts, Konten und Domänen stehen nie hier, sondern höchstens in
`docs/local/`.

---

## Auth-Übersicht

| Ziel | Verfahren | Secret-Ablageort | Anlage |
|------|-----------|-----------------|--------|
| Active Directory, Domänenrechner (WinRM, CIM, Remote-Registry, Eventlog) | Kerberos (Windows-integriert) | keiner — Anmeldesitzung des Administrators | entfällt |
| Exchange Server (On-Prem) | Kerberos über `http://<server>/PowerShell/` | keiner | entfällt |
| vCenter / ESXi | PowerCLI-Anmeldung (`Connect-VIServer`), interaktiv | keiner (Eingabe zur Laufzeit) | Erstlauf interaktiv |
| Microsoft Graph / Entra ID | `Connect-MgGraph` delegiert, Scope `User.ReadWrite.All` | Token-Cache des Graph-Moduls im Benutzerprofil | Erstlauf interaktiv |
| Zammad | API-Token als `[string]`-Parameter (`-Token`), im Anwendungsbeispiel per `Read-Host -AsSecureString` eingelesen; Header `Authorization: Token token=…` | keiner im Repo; Aufrufer übergibt den Token | Erstlauf interaktiv |
| MailStore Server | `[PSCredential]` an `New-MSApiClient` (Fremd-Wrapper), HTTPS 8463 | keiner | Erstlauf interaktiv |
| LANCOM Public Spot | HTTP Basic Auth (Admin-Konto des Routers) über HTTPS | keiner; Bulk-Skript nimmt `[SecureString]`, Einzel-Skript `[string]` | Erstlauf interaktiv |
| OpenScape Business WSI | Benutzer/Passwort als Query-Parameter der Login-URL, Session-ID danach | keiner | Erstlauf interaktiv |
| Aruba-Switches | `Connect-ArubaSW -Credentials` (`PowerArubaSW`) | keiner | Erstlauf interaktiv |
| SMTP (Ping-Monitor) | SMTP-Auth mit STARTTLS (Port 587), `Get-Credential` | nur im Speicher der Sitzung | Erstlauf interaktiv |
| Geplante Aufgaben (Schattenkopien) | Konto `SYSTEM` | keiner | einmalig beim Registrieren |

---

## 1. Windows-integrierte Authentifizierung (Kerberos)

Standardfall der Sammlung.

```powershell
# Kerberos läuft implizit – kein explizites Credential-Objekt nötig
Invoke-Command -ComputerName SRV01 -ScriptBlock { ... }
New-PSSession -ComputerName SRV01
```

**Voraussetzungen:**
- Verwaltungs-PC und Zielrechner gehören derselben AD-Domäne an (Beispielwert `contoso.local`)
- Das Konto hat lokale Administratorrechte auf dem Ziel (oder delegierte WinRM-Rechte); für AD-Änderungen die
  passenden delegierten Rechte — **nicht** pauschal Domänen-Admin
- WinRM-Dienst auf dem Ziel aktiv: `Test-WSMan -ComputerName SRV01`

**Abweichendes Konto:** `scripts/windows/elevation/Invoke-RunAsElevated.ps1` startet eine Sitzung unter einem
anderen Konto; Zugangsdaten werden dabei interaktiv abgefragt.

---

## 2. Interaktive Zugangsdaten für REST-APIs und Geräte

```powershell
# Bevorzugt: PSCredential bzw. SecureString durchreichen
$cred = Get-Credential -Message "Router-Admin für Public Spot"
.\New-PublicSpotUserBulk.ps1 -AdminUser $cred.UserName -AdminPass $cred.Password -InputCsv .\users.csv -RouterIP 192.0.2.1
```

- Regel: In Klartext umwandeln erst unmittelbar vor dem HTTP-Aufruf (Basic Auth, Token-Header); die
  Klartextvariable lebt nur in der Funktion. Die Zammad-Funktionen nehmen den Token heute schon als Klartext entgegen.
- Zugangsdaten nie in URL-Query-Strings — sie landen in Server- und Proxy-Logs. Einzige Ausnahme im Bestand:
  `OSBiz.psm1` (`TODO.md` I3; ob die WSI-API einen anderen Weg erlaubt, ist dort zu klären).
- Gegenstelle **mit** Zertifikatsprüfung ansprechen. `-SkipCertificateCheck`/`-IgnoreInvalidSSLCerts` nur mit
  ausdrücklicher Bestätigung (`docs/CONVENTIONS.md` §6.1.2) — heute bei OSBiz fest an, bei LANCOM-Bulk per Default an
  (`TODO.md` I3).

---

## 3. Gespeicherte Zugangsdaten (nur falls künftig nötig)

Heute nicht im Einsatz. Wird ein Skript als geplante Aufgabe unter einem Dienstkonto betrieben und braucht ein
Secret, gilt `architecture/CREDENTIAL_STRATEGY.md` (DPAPI-Datei unter dem Dienstkonto angelegt, `SecretManagement`
oder Credential Manager; Dateien gitignored, ACL nur für das ausführende Konto). Den Fall dann hier in der
Auth-Übersicht eintragen.

---

## Security-Checkliste

- [ ] Kein Plaintext-Passwort im Quellcode oder in `*.ps1`-Konfigurationsdateien (Hook prüft Zuweisungen)
- [ ] Passwort-/Token-Parameter als `[SecureString]` bzw. `[PSCredential]`, nicht `[string]`
- [ ] Keine Zugangsdaten in URLs; Zertifikatsprüfung nur mit `-Force`-Bestätigung abschaltbar
- [ ] AD-Änderungen mit minimal nötigen delegierten Rechten, nicht als Domänen-Admin
- [ ] Task Scheduler: `SYSTEM` oder dediziertes Dienstkonto mit minimalen Rechten — kein interaktives Admin-Konto
- [ ] Bei künftig gespeicherten Credentials: Dateien gitignored, ACL restriktiv, Neuanlage bei Kontowechsel
