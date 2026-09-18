# Backlog

Offene Punkte, die bekannt sind und bewusst nicht sofort erledigt wurden.
Stand: 2026-09-18.

---

## 1. Konkurrierende Versionsstaende

Zwoelf Aufgaben liegen in mehreren Staenden nebeneinander. Die Benennung ist
seit der Umstellung einheitlich (`_v1`/`_v2`/`_old`), damit die Lage sichtbar
ist - aufgeloest ist sie damit nicht.

Die Empfehlung ist aus Datum, Umfang und Inhalt abgeleitet. **Sie ersetzt
keine Entscheidung**: welcher Stand produktiv im Einsatz ist, steht nirgends
im Repository.

### 1.1 Windows-Bereinigung - vier Staende

`scripts/windows/cleanup/`

| Datei                     | Datum      | Zeilen | Inhalt                                                     |
| ------------------------- | ---------- | ------ | ---------------------------------------------------------- |
| `Clear-OldTempFiles_v1.ps1` | 2025-06-05 | 122    | Funktionsbibliothek (`Get-CleanupPaths`, `Clear-OldFiles`)  |
| `Clear-OldTempFiles_v2.ps1` | 2025-10-28 | 389    | eigenstaendiges Skript, parallele Verarbeitung, Eventlogs   |
| `Clear-OldTempFiles_v3.ps1` | 2025-10-28 | 588    | v2 + Browser-Caches, Delivery Optimization, leere Ordner    |
| `Clear-OldTempFiles_v4.ps1` | 2025-10-28 | 667    | v3 + Modi QuickClean/DeepClean/SafeMode, `-DryRun`          |

v2 bis v4 sind eine echte Kette, jede Stufe enthaelt die vorige. v1 ist etwas
anderes: eine Sammlung dot-sourcebarer Funktionen, kein Skript.

**Empfehlung:** `_v4` als kanonisch setzen (der Kopf nennt sich selbst
"Fixed - Stabile Version"), `_v2` und `_v3` loeschen. Bei `_v1` zuerst
pruefen, ob irgendwo `Clear-OldFiles` dot-gesourct wird.

### 1.2 Temporaere Gruppenmitgliedschaften - zwei Werkzeuge, nicht vier Versionen

`scripts/active-directory/group-membership/temporary/`

Das ist der irrefuehrendste Fall: die vier Dateien lagen unter einem
gemeinsamen Ordnernamen, sind aber **zwei verschiedene Werkzeuge**.

| Datei                                         | Art                                    |
| --------------------------------------------- | -------------------------------------- |
| `Show-TemporaryGroupMembershipGui_v1.ps1`     | interaktive WinForms-GUI, PAM-Feature  |
| `Show-TemporaryGroupMembershipGui_v2.ps1`     | dieselbe GUI, ueberarbeitet            |
| `Sync-TemporaryGroupMembershipFromCsv_v2.ps1` | unbeaufsichtigter CSV-Lauf (Aufgabenplanung) |
| `Sync-TemporaryGroupMembershipFromCsv_v3.ps1` | + config.json, Datei-Logging, Entfernen |

**Empfehlung:** je Werkzeug den hoechsten Stand behalten
(`Show-...Gui_v2`, `Sync-...FromCsv_v3`), die beiden anderen loeschen. Die
Namen sagen jetzt, was was ist - das war vorher nicht erkennbar.

### 1.3 Weitere Paare

| Ort                          | Staende                                                        | Unterschied                                                                 | Empfehlung |
| ---------------------------- | -------------------------------------------------------------- | --------------------------------------------------------------------------- | ---------- |
| `windows/elevation/`         | `Invoke-RunAsElevated.ps1` (2025-06-30) / `_old.ps1` (2025-06-28) | neu: EncodedCommand + `runas`. alt: temporaere Batchdatei im ProgramData     | neu        |
| `network/lancom/`            | `New-PublicSpotUserBulk.ps1` (2026-05-13) / `_old.ps1` (2026-05-12) | neu 318 Zeilen gegen 195, gleiche Aufgabe                                    | neu        |
| `network/dhcp/`              | `Get-DhcpServerLease_v1` (2024-08) / `_v2` (2025-08)            | v1 mit fest eingetragener Serverliste, v2 fragt alle autorisierten DHCP-Server der Domaene ab | `_v2` |
| `windows/desktop/window-cascade/` | `Set-CascadedWindow_v1` / `_v2`                            | v2 gruppiert nach Prozess und laesst den Zielmonitor waehlen                 | `_v2`      |
| `network/aruba/`             | `Get-ArubaMacTable_v1` / `_v2`                                  | v2 korrigiert die OUI-Suche (klein geschrieben, drei Praefixlaengen) und die Wireshark-URL | `_v2` |
| `security/log4j/`            | `Find-Log4jFile_v1` / `_v2`                                     | v2 mit Parametern, Allow-/Denylist, `-Loeschen`, 7z-Aufruf                   | `_v2`      |
| `security/secure-boot/`      | `Test-MultipleHostsSecureBoot_v1` (29 Z) / `_v2` (48 Z)         | v2 ruft zusaetzlich `Invoke-SecureBootCertUpdate` auf                        | `_v2`      |
| `windows/availability/`      | `Get-ComputerOnlineStatus_v1` / `_v2`                           | **unklar.** v1: 13 Commits ueber ein Jahr, laeuft ueber Jobs auch unter PS 5.1. v2: 3 Commits, neuer. Hier ist nicht der neuere automatisch der bessere. | pruefen |
| `messaging/mailstore/`       | `MailStoreApiFunctions.ps1` / `MailStoreSnippets_v1` / `_v2`    | Snippets_v2 ist Obermenge von _v1 (19 der 20 Funktionen). `MailStoreApiFunctions` ist generiert und am vollstaendigsten | ApiFunctions + `_v2` behalten, `_v1` loeschen |
| `applications/zammad/`       | `Get-ZammadTicket` / `Invoke-ZammadApi_v1` / `_v2`              | drei parallele API-Experimente vom selben Tag; nur `Get-ZammadTicket` wurde spaeter (2026-02) noch gepflegt | zusammenfuehren |

### 1.4 Was **keine** Versionskonflikte sind

Diese Paare sehen so aus, sind aber Absicht - nicht zusammenfuehren:

| Dateien                                                        | Grund                                                                 |
| -------------------------------------------------------------- | --------------------------------------------------------------------- |
| `Get-LoggedInUsersCim.ps1` / `Get-LoggedInUsersInvokeCommand.ps1` | zwei Wege wegen eines PowerShell-7.4-Bugs; der Dateikopf verlinkt ihn |
| `Get-BitLockerStatus_de.ps1` / `_en.ps1`                       | Sprachvarianten fuer lokalisierte Ausgaben                            |
| `Invoke-SecureBootCertUpdate.ps1` / `_simple.ps1`              | bewusst schlanke Variante (242 statt 923 Zeilen) fuer den Einzelfall  |
| `Test-ADGroupIntegrity.ps1` / `Test-ADGroupIntegrityMulti.ps1` | Einzelgruppe gegen alle privilegierten Gruppen, zwei PRTG-Sensoren    |

---

## 2. Comment-Based Help fehlt bei 90 Skripten

`INDEX.md` weist 74 von 164 Skripten mit `.SYNOPSIS` aus. Bei den uebrigen
zeigt der Index ersatzweise die erste Kommentarzeile - ein Hinweis, keine
Beschreibung.

Arbeitsliste erzeugen:

```powershell
.\tools\Build-ScriptIndex.ps1 -PassThru |
    Where-Object { -not $_.Synopsis } |
    Select-Object RelativePath
```

Die zehn groessten und riskantesten sind bereits nachgezogen. Sinnvolle
Reihenfolge fuer den Rest: erst alles, was schreibend oder loeschend arbeitet,
dann nach Dateigroesse.

---

## 3. Einzelne Fundstellen

### 3.1 Fremdcode liegt unter `scripts/`

`scripts/active-directory/token-size/Get-TokenSizeReport.ps1` stammt von
Jeremy Saunders (jhouseconsulting.com), Release 1.8. Es gehoert nach
`third-party/` mit einer `ORIGIN.md`, so wie
`third-party/Check-UEFISecureBootVariables/`.

Ob `_dump-ticketsize.1.7.ps1` (heute `Export-KerberosTokenSize.ps1`) im selben
Verzeichnis derselben Herkunft ist, wurde nicht geprueft.

### 3.2 Der MailStore-Generator ist zerbrechlich

`New-MailStoreApiFunctionReference.ps1` erzeugt PowerShell-Funktionen aus dem
HTML der Herstellerdokumentation. Er hat dabei einen leeren Parameter
ausgegeben

```powershell
[Parameter(Mandatory = $, ...)]
[]$,
```

und damit die Zieldatei unparsbar gemacht. Die Datei
(`Invoke-MailStoreApiScratch.ps1`, frueher `test.ps1`) ist repariert, der
Generator nicht. Mindestens sollte er seine Ausgabe nach dem Lauf gegen den
Parser pruefen:

```powershell
$errors = $null
[void][System.Management.Automation.Language.Parser]::ParseFile($ziel, [ref]$null, [ref]$errors)
```

### 3.3 `third-party/` als Submodul

`third-party/Check-UEFISecureBootVariables/` ist ein ZIP-Download, rund 40
Dateien. Als Git-Submodul waeren Updates nachvollziehbar und die Dateien
zaehlten nicht zu diesem Repo. Siehe `third-party/.../ORIGIN.md`.

### 3.4 `_inbox/playground/` aufloesen

Drei Dateien (`New-ADGroupInOU_with_some_stuff.ps1`,
`meeting_pipeline_setup.sh`, `requirements.txt`). Nach der 30-Tage-Regel
einsortieren oder loeschen.

### 3.5 Nummerierte Beispieldateien

`scripts/messaging/mailstore/examples/Example1.ps1` bis `Example4.ps1` sagen
nicht, was sie zeigen. Aussagekraeftige Namen waeren besser, erfordern aber,
jede Datei zu lesen.

---

## 4. History enthaelt firmenspezifische Daten

Elf Dateien in frueheren Commits enthalten interne Domaenennamen, Hostnamen,
eine interne IP, drei Benutzernamen und eine interne Helpdesk-URL. Keine
Zugangsdaten. Die aktuellen Staende sind sauber, die alten Commits liegen
weiter oeffentlich auf GitHub.

Entscheidung steht aus. Optionen und Abwaegung: siehe
[HISTORY-OPTIONS.md](HISTORY-OPTIONS.md).
