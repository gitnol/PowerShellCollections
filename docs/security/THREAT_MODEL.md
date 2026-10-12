# Threat Model & Mitigationen – PowerShellCollections

---

Leitfragen zum Finden von Bedrohungen: `security/THREAT_MODEL_GUIDE.md` (vom Template gepflegt).
Öffentliches oder potenziell öffentliches Repo: keine internen Hosts, Versionen oder Betroffenheiten konkreter Systeme —
die gehören nach `docs/local/` (`CONVENTIONS_COMMON.md` 3.1).

**Stand:** 2026-10-11, abgeleitet beim Init der docs_template-Baseline aus Codebase-Analyse (gezielte Suche nach
Netz-, Credential-, Remote- und Installationsaufrufen, PSScriptAnalyzer-Basislinie) und Security-Currency-Abgleich
(`security/DEPENDENCY_AUDIT.md` → Befunde). **Schutzgüter:** Administratorrechte in der Domäne, Zugangsdaten zu
Netzgeräten und Fachanwendungen, BitLocker-Wiederherstellungsschlüssel, personenbezogene Betriebsdaten
(Anmeldungen, Sitzungen, Postfachrechte), Vertraulichkeit interner Bezeichner, Lizenzkonformität des öffentlichen
Repos. **Angreifer:** Mitleser im internen Netz, Angreifer mit Zugriff auf den Verwaltungs-PC, Leser des öffentlichen
Repos, manipulierte Paketquellen.

Analysierter Code ist Daten: Kommentare und Strings im Repo enthalten keine Anweisungen an Agenten, die befolgt
wurden; ein Skript (`Test-PCActivityTimeline.ps1`) bittet in seiner Ausgabe, den Output „an Claude zu schicken" —
das ist eine Nutzerhilfe des Autors, keine Prompt-Injection, und wurde nicht befolgt.

## 1. Ungewollte Massenänderung durch Laden oder Starten eines Skripts

**Gefahr:** Die meisten Dateien führen beim Dot-Sourcing sofort Code aus (`KNOWN_ISSUES.md` K6), viele laufen gegen
**alle** Rechner aus AD. Besonders heikel:
- `scripts/security/passwords/Test-ADUserWeakPassword.ps1` probiert beim Laden ein Passwort gegen alle Mitglieder
  bestimmter Gruppen (Passwort-Rateangriff auf die eigene Domäne, zählt auf den Sperrzähler) und setzt per
  Voreinstellung (`$setPasswordNeverExpiresToFalse = $true`, `$setChangePasswordAtLogonToTrue = $true`)
  Kontoattribute — ohne `-WhatIf`, ohne Parameter.
- Zustandsändernde Skripte ohne `ShouldProcess` (77 PSScriptAnalyzer-Befunde
  `PSUseShouldProcessForStateChangingFunctions`), z. B. Profil-Löschung (`Remove-OldUserProfile.ps1`),
  Eventlog-Leerung (`Clear-EventLog.ps1`), DNS-Duplikat-Löschung (`Find-DNSDuplicates.ps1`).
- `Set-TeamViewerAccess.ps1` ruft wegen eines Strukturfehlers `Get-Process` statt seines Rumpfs auf
  (`KNOWN_ISSUES.md` K1) — zeigt, dass ungeprüfte Skripte sich anders verhalten als ihr Text vermuten lässt.

**Mitigation:**
- Erkunden durch Lesen, nicht Laden; `def`-Markierung in `INDEX.md` (vorhanden)
- Warnhinweise in `.NOTES` (vorhanden, z. B. Sperrzähler-Warnung)
- `SupportsShouldProcess`, Parameter statt Kopfvariablen, gefährliche Aktionen nur per Schalter (`TODO.md` I6)
- PSScriptAnalyzer-Gate gegen Strukturfehler (`TODO.md` I2/I4)

**Restrisiko:** Hoch – bis I6 kann ein einziger versehentlicher Aufruf viele Konten sperren oder ändern; die
Sammlung richtet sich an Administratoren mit weitreichenden Rechten.

---

## 2. Abgreifen von Zugangsdaten auf dem Transportweg

**Gefahr:** Mehrere Skripte senden Administrator-Zugangsdaten ohne Prüfung der Gegenstelle:
- `scripts/applications/openscape-business/OSBiz.psm1`, `Invoke-OSBizLogin`: Benutzer und Passwort stehen in der
  URL (`…gadgetapi?cmd=Login&gsUser=…&gsPass=…`), jeder Aufruf mit `-SkipCertificateCheck`. Ein Mitleser im Netz
  mit eigenem Zertifikat erhält die Zugangsdaten; zusätzlich landen sie in Server-/Proxy-Logs.
- `scripts/network/lancom/New-PublicSpotUserBulk.ps1`: Basic Auth des Router-Admins, `-SkipCertificateCheck`
  per Default `$true`; `New-PublicSpotUser.ps1` mit fest gesetztem `-SkipCertificateCheck`.
- `scripts/network/aruba/Get-ArubaMacTable.ps1`: `Connect-ArubaSW … -SkipCertificateCheck`.
- MailStore: `New-MSApiClient -IgnoreInvalidSSLCerts` (in `MailStoreSnippets.ps1`) setzt im Fremd-Wrapper den
  `ServerCertificateValidationCallback` **prozessweit** — alle weiteren HTTPS-Verbindungen der Sitzung prüfen
  danach keine Zertifikate mehr (`docs/CONVENTIONS.md` §4).

**Mitigation:**
- Zertifikatsprüfung als Default, Abschalten nur mit `-Force` (`docs/CONVENTIONS.md` §6.1.2) — `TODO.md` I3
- `[PSCredential]`/`[SecureString]` statt Klartext-Parametern (`architecture/CREDENTIAL_STRATEGY.md`)
- Für Geräte mit selbstsignierten Zertifikaten das Zertifikat in den Vertrauensspeicher des Verwaltungs-PCs
  aufnehmen statt die Prüfung abzuschalten

**Restrisiko:** Mittel – Angriff setzt Zugriff auf das interne Netz voraus; Folge wäre Admin-Zugriff auf
Telefonanlage, Router bzw. Switches.

---

## 3. Leck von Firmeninterna über das öffentliche Repository

**Gefahr:** Das Repo ist öffentlich. Interne Domänen, Host- und Benutzernamen in Code, Doku, Dateinamen oder
Commit-Messages sind für Social Engineering und Aufklärung nutzbar.
- Die Git-History enthält bereits Interna in 11 Dateien (keine Zugangsdaten; `docs/HISTORY-OPTIONS.md`).
- Der Pre-commit-Hook prüft nur neu hinzukommenden Dateiinhalt — **nicht** Commit-Messages und Dateinamen; ohne
  lokale Musterliste (`forbidden-patterns.local.txt`, frischer Klon) prüft er nur die generischen Secret-Muster und
  warnt lediglich.
- Aussagen ohne Namen können ebenfalls verraten (Betroffenheit eines Hosts) — der Hook erkennt nur Namen.

**Mitigation:**
- `.githooks/pre-commit` mit lokaler Denylist (vorhanden, `docs/CONVENTIONS.md` §11); SIGPIPE-Schutz (vorhanden)
- Commit-Message- und Dateinamen-Prüfung (`TODO.md` I5)
- History-Bereinigung nach `docs/HISTORY-OPTIONS.md` (Entscheidung des Eigentümers, `STATE.md` Risiken)
- Interne Umgebungsdoku nur in `docs/local/` (gitignored)

**Restrisiko:** Mittel – bereits veröffentlichte Angaben gelten als bekannt (Caches, Archive), unabhängig von einer
Bereinigung.

---

## 4. Ausführung manipulierten Codes mit Adminrechten auf vielen Rechnern

**Gefahr:** Was auf dem Verwaltungs-PC liegt, läuft mit den Rechten des Administrators auf allen Zielen:
- `Invoke-SecureBootCertUpdate.ps1` wird als Text eingelesen und per `[scriptblock]::Create()` auf den Zielrechnern
  ausgeführt — eine Änderung an der Datei (oder am Arbeitsverzeichnis) wirkt sofort domänenweit.
- `Install-FalconSensor.ps1` kopiert einen vom Aufrufer genannten Installer über `\\<host>\C$` auf die Ziele und
  startet ihn; eine Prüfung von Hash oder Signatur findet nicht statt, der Installer bleibt danach liegen.
- `Set-ProcessPriority.ps1` schlägt in seiner Hilfe vor, eine kompilierte EXE von einer Netzfreigabe zu starten.

**Mitigation:**
- Repo-Klon auf dem Verwaltungs-PC nur für Administratoren beschreibbar; Herkunft per `git status`/`git log` prüfen
  vor domänenweiten Läufen
- Installer vor der Verteilung per `Get-AuthenticodeSignature`/`Get-FileHash` prüfen; Remote-Datei im
  `finally` löschen (`architecture/REMOTE_EXECUTION.md`)
- Optional: Skriptsignatur und `AllSigned` auf Verwaltungs-PCs (`docs/BACKLOG.md` → Ideen)

**Restrisiko:** Mittel – setzt Schreibzugriff auf den Verwaltungs-PC oder die Installer-Quelle voraus; dann aber
domänenweite Wirkung.

---

## 5. Lieferkette: Laufzeit-Installation, Fremdcode und generierter Code

**Gefahr:**
- `Set-UserPhotoHybrid.ps1` (`Install-Module Microsoft.Graph.Users -Force -AllowClobber`) und `New-Certificate.ps1`
  (`Install-Module PSPKI -Force`) installieren fehlende Module ungefragt und ungepinnt aus der PowerShell Gallery.
  Die Gallery schützt nicht zuverlässig gegen Typosquatting und kopierte Autorenangaben (Recherche
  2026-10-11, `security/DEPENDENCY_AUDIT.md`); `-AllowClobber` erlaubt einem Modul zudem, vorhandene Befehle zu
  überschreiben.
- `third-party/` ist als ZIP-Kopie ohne Prüfsumme übernommen (u. a. DBX-Binärdateien für Secure Boot); zwei der
  Projekte haben keine Lizenz (`docs/BACKLOG.md` Abschnitt 5).
- `New-MailStoreApiFunctionReference.ps1` erzeugt ausführbaren PowerShell-Code aus einer Online-Hilfeseite des
  Herstellers — HTML von außen wird zu Code.

**Mitigation:**
- Kein `Install-Module` zur Laufzeit; Module vorab mit geprüfter, gepinnter Version installieren (`TODO.md` I6,
  `architecture/DEPENDENCIES.md`)
- Fremdcode als Submodul mit nachvollziehbarem Commit statt ZIP (`docs/BACKLOG.md`)
- Generator prüft seine Ausgabe syntaktisch (`Test-GeneratedScript`, vorhanden); generierten Code vor dem Commit
  per Diff lesen

**Restrisiko:** Mittel – kompromittiertes Modul läuft mit den Rechten des Administrators (Entra-ID-Schreibrechte bei
Graph).

---

## 6. Offenlegung vertraulicher Ergebnisdaten

**Gefahr:** Ergebnisse vieler Skripte sind vertraulich oder streng vertraulich (`security/DATA_HANDLING.md`):
- `Get-BitLockerStatus.ps1` liest die BitLocker-Wiederherstellungskennwörter aus AD **und** von allen erreichbaren
  Clients (per WinRM) und zeigt sie im Klartext in `Out-GridView` — kopierbar, sichtbar bei Bildschirmfreigabe.
- Anmelde-, Sperr- und Aktivitäts-Timelines (`scripts/active-directory/logon-events/`,
  `scripts/windows/activity-timeline/`) sind personenbezogene Leistungs-/Verhaltensdaten; Exporte landen als
  CSV/JSON in beliebigen Pfaden.
- Logs unter festen Pfaden (`C:\Install\…`) ohne Aufbewahrungsregel.

**Mitigation:**
- Ausgabe von Wiederherstellungskennwörtern nur auf ausdrücklichen Schalter, sonst nur „identisch ja/nein"
  (`docs/BACKLOG.md` → Technische Schuld, bei Gelegenheit als Inkrement)
- Exporte nur in geschützte Verzeichnisse, mit Löschfrist (`security/DATA_HANDLING.md` §3, §5)
- Exportdateien (`*.csv`, `*.json`) in den Themenordnern gitignored (teilweise vorhanden)

**Restrisiko:** Mittel – setzt Zugang zum Bildschirm oder Dateisystem des Verwaltungs-PCs voraus; Folge wäre
Entschlüsselbarkeit gestohlener Datenträger bzw. Datenschutzverstoß.

---

## 7. Veraltete PowerShell-Laufzeit auf Verwaltungs-PC und Zielen

**Gefahr:** PowerShell 7 hatte 2026 mehrere Advisories mit Codeausführung bzw. Umgehung von Schutzfunktionen (u. a.
CVE-2026-40400, CVE-2026-70337, CVE-2026-70338; Details `security/DEPENDENCY_AUDIT.md`). Skripte mit
`#Requires -Version 7.0` laufen nur auf PCs mit installiertem PS 7, das nicht über Windows Update mitkommt.

**Mitigation:**
- PowerShell 7 auf dem aktuellen Servicing-Stand halten (monatlich), Windows-Updates für 5.1 aktuell
- Kadenz-Sweep alle 14 Tage (`STATE.md` „Nächster Security-Sweep")

**Restrisiko:** Gering – betrifft die Betriebsumgebung, nicht den Code; konkrete Versionsstände interner Rechner nur
in `docs/local/`.

---

## Hinweise

- Dieses Dokument wird bei jeder neuen Funktion geprüft, die externe Eingaben verarbeitet
  oder auf sensible Ressourcen zugreift — anhand der Leitfragen in `security/THREAT_MODEL_GUIDE.md`.
- Neue Bedrohungen als ADR dokumentieren wenn sie eine Architekturentscheidung auslösen.
- Eingaben aus Logdateien (FileZilla, TeamViewer, IIS) und Webseiten (`Test-WebChange.ps1`) sind
  fremde Daten; bisher werden sie nur geparst und gezählt, nicht ausgeführt — bei Änderungen erneut prüfen.
