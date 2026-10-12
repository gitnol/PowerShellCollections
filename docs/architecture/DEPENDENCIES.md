# Externe Abhängigkeiten – PowerShellCollections

Abhängigkeiten gelten **je Skript**, nicht für die Sammlung als Ganzes: Wer ein Skript startet, braucht nur dessen
Module und Dienste. Diese Datei listet, was im Bestand vorkommt (Stand der Analyse 2026-10-11: `Import-Module`-,
`#Requires`- und Cmdlet-Suche über `scripts/`, `modules/`, `tools/`; `third-party/` ausgenommen). Es gibt keine
Lock-Datei und kein Manifest mit Versionen — Mindestversionen sind nur angegeben, wo ein Skript sie prüft.

---

## PSGallery-Module (Install-Module)

| Modul | Mindestversion | Zweck | Risiko bei Ausfall |
|-------|----------------|-------|-------------------|
| `VMware.PowerCLI` / `VMware.VimAutomation.Core` | nicht gepinnt | vSphere-Abfragen und Zertifikatsverteilung (`scripts/virtualization/vmware/`, `Set-VMwareCertificate.ps1`) | VMware-Skripte laufen nicht. Nachfolger heißt seit 9.0 `VCF.PowerCLI` (Cmdlets kompatibel laut Hersteller) — beim nächsten Anfassen umstellen |
| `PSPKI` | nicht gepinnt | PFX → PEM (`New-Certificate.ps1`); wird zur Laufzeit per `Install-Module -Force` nachinstalliert (`TODO.md` I6) | Zertifikatsexport scheitert |
| `Microsoft.Graph.Users` (+ `Microsoft.Graph.Authentication`) | nicht gepinnt | Benutzerfoto in Entra ID/Teams (`Set-UserPhotoHybrid.ps1`); wird zur Laufzeit mit `-Force -AllowClobber` nachinstalliert (`TODO.md` I6) | Foto nur im lokalen AD gesetzt |
| `ExchangeOnlineManagement` | nicht gepinnt | optional für Exchange Online (`Get-ExchangeEmailAddressInventory.ps1`) | nur On-Prem-Abfrage möglich |
| `PowerArubaSW` | nicht gepinnt | MAC-Tabellen der Aruba-Switches (`Get-ArubaMacTable.ps1`) | Skript läuft nicht |
| `SNMP` | nicht gepinnt | SNMP-Abfrage am Drucker (`Get-PrinterSnmpOid.ps1`) | Skript läuft nicht |
| `PS2EXE` | nicht gepinnt | optional: `Set-ProcessPriority.ps1` als EXE kompilieren (Hinweis in der Hilfe) | keiner für den Skriptlauf |
| `PSScriptAnalyzer` | 1.25.0 (Basislinie) | Entwicklungswerkzeug: Gate 1 (`docs/CONVENTIONS.md` §9) | kein Linter-Gate |
| `Pester` | 5.7.1 (geplant, `TODO.md` I4) | Entwicklungswerkzeug: Gate 4 | keine Unit-Tests |

Scope: Die Skripte laufen interaktiv unter dem Konto des Administrators → `-Scope CurrentUser` genügt.
Ausnahme sind geplante Aufgaben unter einem Dienstkonto (`operations/TASK_SCHEDULER.md`) → `-Scope AllUsers`.

**Installationsbefehl (Erstinstallation, einmalig, Version bewusst wählen):**
```powershell
# Interaktiver Administrator: -Scope CurrentUser
Install-Module -Name PSPKI -Scope CurrentUser -RequiredVersion <geprüfte Version>

# Installation prüfen
Get-Module -Name PSPKI -ListAvailable | Select-Object Name, Version, Path
```

---

## Windows-Systemmodule (kein Install-Module nötig)

| Modul | Zweck | Verfügbarkeit |
|-------|-------|--------------|
| `ActiveDirectory` | AD-Abfragen und -Änderungen (39 Skripte nutzen AD-Cmdlets, 13 laden das Modul ausdrücklich) | RSAT „AD DS-Tools" bzw. auf Domänencontrollern |
| `GroupPolicy` | GPO-Berichte und -Links (`scripts/active-directory/gpo/`) | RSAT „Gruppenrichtlinienverwaltung" |
| `DhcpServer` | DHCP-Leases (`Get-DhcpServerLease.ps1`) | RSAT „DHCP-Server-Tools" |
| `DnsServer` | DNS-Duplikate (`Find-DNSDuplicates.ps1`) | RSAT „DNS-Server-Tools" |
| Exchange-Remote-Session | Postfachabfragen (`scripts/messaging/exchange/`) | Exchange-Server mit PowerShell-Virtual-Directory; Verbindung per `New-PSSession -ConfigurationName Microsoft.Exchange` |
| `PSCollections.Connectivity` (Repo) | Erreichbarkeit vieler Rechner parallel | `modules/`, PS 5.1+; nur auf dem Verwaltungs-PC |

Prüfen mit `Get-Module -ListAvailable -Name <Modul>`; fehlt es, ist das RSAT-Feature nicht installiert
(`operations/SETUP.md`).

---

## Externe Binaries

| Binary | Pfad | Zweck | Fehler-Verhalten |
|--------|------|-------|-----------------|
| `autorunsc64.exe` (Sysinternals) | Parameter `$PathToSysinternals` | Autostart-Einträge lesen/schalten (`Set-AutorunEntry.ps1`) | Skript prüft `Test-Path` und bricht ab |
| `certreq.exe` | Windows | Zertifikatsanforderung an die Unternehmens-CA (`Request-Certificate.ps1`) | Exit-Code ≠ 0 → Abbruch |
| `schtasks.exe` | Windows | Aufgaben registrieren/schalten (`New-ScheduledTaskFromXml.ps1`, `Enable-ShadowCopy.ps1`, `Set-AutorunEntry.ps1`) | `Set-AutorunEntry.ps1` wirft bei `$LASTEXITCODE` ≠ 0; die Schattenkopie-Skripte prüfen nicht |
| `vssadmin.exe`, `wevtutil.exe`, `dism.exe`, `sysprep.exe`, `reg.exe`, `sc.exe` | Windows | Schattenkopien, Eventlog, Template-Vorbereitung, Registry, Dienste | je Skript; meist ohne Exit-Code-Prüfung (Altbestand) |
| `7z.exe` | Parameter `-PfadZu7z`, Default neben dem Skript | verschachtelte Archive in `Find-Log4jFile.ps1` | fehlt → Archivsuche unvollständig |
| `nmap.exe` | fest `C:\Program Files (x86)\Nmap\` | Portprüfung in `Test-LdapPorts.ps1` | ohne nmap läuft nur der LDAPS-Bind-Test |
| FalconSensor-Installer | vom Aufrufer übergeben | EDR-Verteilung (`Install-FalconSensor.ps1`) | Remote-Installation scheitert |
| `SecureBootEncodeUEFI.exe` | Fremdcode `third-party/Check-UEFISecureBootVariables/` | Secure-Boot-Variablen kodieren | nur über die Fremdskripte |

---

## Externe Services / APIs

Hosts sind in diesem öffentlichen Repo immer Parameter oder Platzhalter; konkrete Adressen nur in
`docs/local/` (`docs/CONVENTIONS.md` §11).

| Service | URL / Endpunkt | Zweck | Fallback bei Ausfall |
|---------|---------------|-------|---------------------|
| Active Directory / Domain Controller | LDAP 389/636, ADWS | Benutzer, Computer, Gruppen, Events | Fehlermeldung, Skript bricht ab |
| Windows-Zielrechner | WinRM (5985/5986), CIM/DCOM, Remote-Registry, RPC | Remote-Abfragen und -Änderungen (`architecture/REMOTE_EXECUTION.md`) | Ziel im Ergebnis als offline/fehlerhaft |
| Exchange Server (On-Prem) | `http://<server>/PowerShell/` (Kerberos) | Postfächer, Berechtigungen, Weiterleitungen | Abbruch |
| Microsoft Graph | `graph.microsoft.com` (interaktive Anmeldung, Scope `User.ReadWrite.All`) | Benutzerfoto in Entra ID | Foto nur lokal |
| vCenter / ESXi | HTTPS-API über PowerCLI | VM-Abfragen, Zertifikate | Abbruch |
| Unternehmens-CA (ADCS) | RPC/DCOM über `certreq` | Zertifikate ausstellen | Abbruch |
| Zammad | REST `https://<zammad>/api/v1/` (Token) | Tickets lesen (`scripts/applications/zammad/`) | Fehler je Ticket |
| MailStore Server | Administration API (HTTPS, Port 8463) über den Fremd-Wrapper `MS.PS.Lib` | Archivverwaltung (`scripts/messaging/mailstore/`); `-IgnoreInvalidSSLCerts` setzt den Zertifikats-Callback prozessweit (`docs/CONVENTIONS.md` §4) | Abbruch |
| MailStore-Online-Doku | `https://help.mailstore.com/…` | Quelle für generierten Code (`New-MailStoreApiFunctionReference.ps1`) | Generator bricht ab; generierter Code wird selbst geprüft (`Test-GeneratedScript`) |
| OpenScape Business WSI | `https://<anlage>:8802/cgi-bin/gadgetapi` | Telefonie-Funktionen (`OSBiz.psm1`) — Zertifikatsprüfung aus, Zugangsdaten in der URL (`TODO.md` I3) | Exception |
| LANCOM Public Spot | REST auf Router/WLC (Basic Auth) | Gastbenutzer anlegen (`scripts/network/lancom/`) | Fehler je Benutzer |
| Aruba-Switches | REST über `PowerArubaSW` | MAC-Tabellen | Switch übersprungen |
| Dassault License Server (DSLS) | lokal/remote Kommandozeile `DSLicSrv.exe` | PRTG-Sensoren Lizenznutzung | `<error>` an PRTG |
| SMTP-Server | Port 587 mit TLS | Benachrichtigung des Ping-Monitors | Meldung im Log |
| Wireshark `manuf.json` | `https://www.wireshark.org/json/manuf.json` (manueller Download) | OUI-Herstellerliste für `Get-ArubaMacTable.ps1` | Herstellerauflösung fehlt |
| Beliebige Webseiten | Liste in `urls.txt` | Änderungsüberwachung (`Test-WebChange.ps1`) | Eintrag als Fehler im Ergebnis |

---

## Systemabhängigkeiten

| Ressource | Mindestversion / Pfad | Zweck |
|-----------|----------------------|-------|
| Windows | Windows 10/11 bzw. Windows Server 2016+ (einzelne PRTG-Sensoren ausdrücklich für Server 2016/2019) | Verwaltungs-PC und Zielsysteme |
| PowerShell | 5.1 (Mindeststand, `PSCollections.Connectivity`) bzw. 7.0 für Skripte mit `#Requires -Version 7.0` | 5.1: BOM-Pflicht bei Umlauten; 7: `ForEach-Object -Parallel`, `-SkipCertificateCheck`, `ConvertFrom-Json -AsHashtable` |
| PowerShell 7 Servicing | aktueller Patchstand (Stand 2026-10-11: 7.6.6 bzw. 7.4.20 LTS) | Sicherheitsupdates, `security/DEPENDENCY_AUDIT.md` |
| RSAT | Features je Skript | AD-, GPO-, DHCP-, DNS-Module |
| Administratorrechte | `#Requires -RunAsAdministrator` (6 Skripte) bzw. lokale Admin-Rechte auf Zielrechnern | Registry, Dienste, Eventlog, Schattenkopien |
| Lokaler Ablagepfad | `C:\Install\` (Altbestand, fest im Code) | Logs der Schattenkopie-Skripte, OUI-Liste |

---

## Upgrade-Hinweise

- **VMware.PowerCLI → VCF.PowerCLI:** Broadcom hat das Modul mit 9.0 umbenannt; laut Hersteller laufen bestehende
  Cmdlets weiter. Beim Umstellen `#Requires`/`Import-Module`-Namen in den VMware- und Zertifikatsskripten anpassen
  und gegen eine Testumgebung prüfen.
- **Microsoft.Graph:** Module erscheinen im Wochenrhythmus; `Microsoft.Graph.Users` und
  `Microsoft.Graph.Authentication` müssen dieselbe Version haben, sonst scheitert `Connect-MgGraph` bzw. der
  Import. Version pinnen statt zur Laufzeit `-Force -AllowClobber`.
- **PowerShell 7:** monatliche Servicing-Releases; vor dem Wechsel der Minor-Version (7.4 LTS → 7.6 LTS) die
  Skripte mit `#Requires -Version 7.0` unter der neuen Version mit PSScriptAnalyzer prüfen.
- **Windows PowerShell 5.1:** wird über die Windows-Updates gepatcht; Skripte ohne `#Requires` müssen dort laufen
  (BOM-Pflicht, keine PS7-Syntax).
- **Externe Binaries** (`autorunsc64.exe`, `7z.exe`, `DSLicSrv.exe`): Ausgabeformat und Exit-Codes können sich bei
  Major-Updates ändern — die abhängigen Skripte parsen Textausgaben.
