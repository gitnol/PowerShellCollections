# Repository-Struktur

## Das Problem, das diese Struktur geloest hat

Die gewachsene Ablage mischte drei Ordnungsachsen auf derselben Ebene:

| Achse       | Beispiele                                                             |
| ----------- | --------------------------------------------------------------------- |
| Fachdomaene | `Active-Directory`, `Exchange_Outlook`                                |
| Hersteller  | `Aruba`, `LANCOM`, `Kyocera`, `VMware`                                |
| Restekiste  | `unsorted-stuff`, `LOST+FOUND+UNTESTED`, `Server-Client-Helper-Stuff` |

Solange mehrere Achsen gleichberechtigt nebeneinanderstehen, hat jede neue
Datei mehrere gleich plausible Ablageorte - und landet deshalb in der
Restekiste. `unsorted-stuff` (42 Dateien) und `Server-Client-Helper-Stuff`
(92 Dateien) waren nicht die Ursache, sondern das Symptom.

## Die Entscheidungsregel

> **Ein Skript liegt unter dem System, gegen das es laeuft.**
>
> Existiert das Skript nur wegen des Ausgabe-Vertrags einer Plattform
> (PRTG-XML, Nagios-Exitcode, Icinga), dann ist **die Plattform** das System -
> nicht das abgefragte Produkt.

Zwei Faelle aus der Umstellung, an denen sich die Regel zeigt:

- `Check-ADGroupIntegrity.ps1` (heute `Test-ADGroupIntegrity.ps1`) lag unter
  `Active-Directory/`, gibt aber
  PRTG-XML aus und pflegt `PRTG_Baseline_*`-Dateien. Es liegt jetzt unter
  `scripts/monitoring/prtg/ad-group-integrity/`. Wer den naechsten Sensor
  baut, sucht bei PRTG - nicht bei AD.
- `bitlocker-status-de.ps1` (heute `Get-BitLockerStatus_de.ps1`) lag ebenfalls
  unter `Active-Directory/`, weil es
  die Rechnerliste per `Get-ADComputer` holt. Das Thema ist aber BitLocker,
  nicht AD - AD ist nur die Bezugsquelle. Es liegt jetzt unter
  `scripts/security/bitlocker/`.

Fuer den Zweifelsfall:

> **Wonach wuerdest du in sechs Monaten suchen?** Danach wird abgelegt.

## Struktur

```
scripts/
  active-directory/    AD-Objekte, GPO, DNS, LDAP, Anmelde-Events, Zeitsync
  windows/             Betriebssystem: Sessions, Prozesse, Dienste, Tasks,
                       WMI, Eventlog, Bereinigung, Inventar, Desktop
  security/            Zertifikate, SecureBoot, BitLocker, Passwoerter, EDR
  network/             LANCOM, Aruba, DHCP, Firewall, WOL, Diagnose
  virtualization/      VMware
  databases/           MSSQL, Firebird, Sync
  messaging/           Exchange, Outlook, Mailstore, NoSpamProxy
  monitoring/          PRTG, Ping-Monitor, Web-Aenderungen
  applications/        DocuWare, Zammad, TeamViewer, Kyocera, FileZilla,
                       OpenScape, Excel, Teams
  filesystem/          Berechtigungen, Suche, Links, Archivierung
snippets/              Code-Beispiele ohne Betriebszweck
third-party/           fremder, unveraenderter Code
tools/                 Werkzeuge fuer dieses Repo selbst
docs/                  Doku zum Repo
_inbox/                Zwischenablage, siehe unten
```

### Warum `windows/` statt `windows-client/` und `windows-server/`

Die naheliegende Trennung nach Client und Server haette das Ausgangsproblem
reproduziert: ein Grossteil der Skripte laeuft per `Invoke-Command` gegen
beliebige Domaenenrechner und ist damit weder das eine noch das andere.
`Get-LoggedInUsers*`, `Clear-OldTempFiles*` oder `Get-DomainWideProcessCpuUsage`
haetten jeweils zwei plausible Orte gehabt - und genau daraus entsteht die
naechste Restekiste. Eine Achse weniger ist hier mehr wert als die feinere
Unterteilung.

### `_inbox/` statt `unsorted-stuff/`

Eine Restekiste laesst sich nicht wegdefinieren - aber befristen:

> Was laenger als 30 Tage in `_inbox/` liegt, wird einsortiert oder geloescht.

Der Unterschied zum Vorgaenger ist nicht der Name, sondern dass "unsortiert"
damit ein sichtbarer, befristeter Zustand ist.

### `third-party/`

`Check-UEFISecureBootVariables` waren ~40 Dateien fremder Code, einmal als ZIP
nach `Server-Client-Helper-Stuff/SecureBoot/` hineinkopiert - rund ein Sechstel
aller Dateien im Repo, ohne eigene Arbeit zu sein. Fremdcode liegt jetzt unter
`third-party/<projekt>/` mit einer `ORIGIN.md` (Quelle, Stand, Lizenz).

Besser waere ein Git-Submodul, damit Updates nachvollziehbar bleiben. Solange
der Code kopiert vorliegt, gilt: dort nichts aendern, eigene Ergaenzungen
kommen als Wrapper nach `scripts/security/secure-boot/`.

### Keine eigene `modules/`-Ebene

Naheliegend waere, alle `.psm1`/`.psd1` zentral zu sammeln. Dagegen spricht die
Zusammengehoerigkeit: `MS.PS.Lib.psm1` ohne die Mailstore-Skripte, mit denen es
benutzt wird, ist schwerer zu finden und schwerer zu verstehen. Module liegen
deshalb bei ihrer Fachdomaene:

| Modul                  | Ort                                      |
| ---------------------- | ---------------------------------------- |
| `MS.PS.Lib.psm1`       | `scripts/messaging/mailstore/api-wrapper/` |
| `OSBiz.psm1`           | `scripts/applications/openscape-business/` |
| `Win10PingMonitor.psm1`| `scripts/monitoring/ping-monitor/`       |
| `PRTG.Dsls.psm1`       | `scripts/monitoring/prtg/dsls/`          |

## Namenskonventionen

Ordner und Dateinamen sind umgestellt. 104 Dateien wurden umbenannt; die
"Nein"-Spalte zeigt Namen, die es hier tatsaechlich gab.

| Regel                   | Ja                          | Nein                                            |
| ----------------------- | --------------------------- | ----------------------------------------------- |
| PowerShell Verb-Noun    | `Get-ADUserLastLogon.ps1`   | `check-for-bad-passwords.ps1`                   |
| Kein Umlaut/Kein Deutsch | `Find-Log4jFile_v2.ps1`    | `Suche_nach_log4j_Dateien_optimiert.ps1`        |
| Nur freigegebene Verben | `Get-`, `Set-`, `Test-`     | `Check-`, `Create-`, `Manage-`                  |
| Englisch                | `Set-FolderPermission.ps1`  | `Fileserver-Einzelberechtigungen-fuer-User.ps1` |
| ASCII in Pfaden         | `temporary/`                | `Temporäre-Gruppenmitgliedschaften-Verwalten/`  |
| Ordner: kebab-case      | `active-directory/`         | `Server-Client-Helper-Stuff/`                   |

`Check-` ist kein freigegebenes PowerShell-Verb - das Gegenstueck heisst
`Test-`. Ebenso `Create-` -> `New-`, `Manage-` -> `Set-`/`Update-`.
`Get-Verb` listet die zulaessigen Verben auf.

Umlaute in Pfaden sind nicht nur Geschmack: Git gibt sie als
`Tempor\303\244re-...` aus, und diverse Werkzeugketten (Tab-Completion ueber
SSH, Archive, CI-Runner) stolpern darueber. Die beiden Ordner mit Umlaut sind
bei der Umstellung verschwunden.

### Versionsstaende

Wo mehrere Staende derselben Aufgabe nebeneinanderliegen, tragen sie jetzt
einheitlich `_v1`/`_v2`/`_old` statt vier verschiedener Schreibweisen
(`_v4`, `(Old)`, `_old`, `_Alternative`, `aruba1`). Das macht die Lage
sichtbar, loest sie aber nicht auf.

[BACKLOG.md](BACKLOG.md) enthaelt die Gegenueberstellung: Datum, Umfang,
inhaltlicher Unterschied und eine begruendete Empfehlung je Paar.

> Ziel bleibt genau **eine** kanonische Datei pro Aufgabe. Alte Staende
> loescht man - die History hat sie. Ist ein alter Stand bewusst als Referenz
> gewollt, kommt er nach `archive/` mit einer Zeile Begruendung im Header.

## Auffindbarkeit

Jedes Skript bekommt Comment-Based Help mit mindestens `.SYNOPSIS`.
`tools/Build-ScriptIndex.ps1` liest diese aus und erzeugt `INDEX.md` -
eine durchsuchbare Tabelle aller Skripte mit Pfad und Kurzbeschreibung.

```powershell
# Index neu erzeugen
.\tools\Build-ScriptIndex.ps1

# Arbeitsliste: was hat noch keine .SYNOPSIS?
.\tools\Build-ScriptIndex.ps1 -PassThru |
    Where-Object { -not $_.Synopsis } |
    Select-Object RelativePath
```

## Was als Naechstes ansteht

1. Dateinamen auf Verb-Noun und Englisch umstellen (eigener Durchgang)
2. Versionsstaende zusammenfuehren: pro Aufgabe eine kanonische Datei
3. `.SYNOPSIS` nachziehen - der Index zeigt, wo sie fehlt
4. `third-party/Check-UEFISecureBootVariables` durch ein Submodul ersetzen
5. `_inbox/playground/` nach der 30-Tage-Regel aufloesen
