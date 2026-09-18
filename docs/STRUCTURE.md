# Repository-Struktur

## Das Problem, das diese Struktur loest

Die gewachsene Ablage mischt drei verschiedene Ordnungsachsen auf derselben
Ebene:

| Achse            | Beispiele                                      |
| ---------------- | ---------------------------------------------- |
| Fachdomaene      | `Active-Directory`, `Exchange_Outlook`         |
| Hersteller       | `Aruba`, `LANCOM`, `Kyocera`, `VMware`         |
| Restekiste       | `unsorted-stuff`, `LOST+FOUND+UNTESTED`, `Server-Client-Helper-Stuff` |

Solange mehrere Achsen gleichberechtigt nebeneinander stehen, hat jede neue
Datei mehrere gleich plausible Ablageorte - und landet deshalb in der
Restekiste. `unsorted-stuff` (42 Dateien) und `Server-Client-Helper-Stuff`
(92 Dateien) sind nicht die Ursache, sondern das Symptom.

## Die Entscheidungsregel

> **Ein Skript liegt unter dem System, gegen das es laeuft.**
>
> Existiert das Skript nur wegen des Ausgabe-Vertrags einer Plattform
> (PRTG-XML, Nagios-Exitcode, Icinga), dann ist **die Plattform** das System -
> nicht das abgefragte Produkt.

Konkretes Beispiel: ein Sensor, der den Dassault-Lizenzserver abfragt und
PRTG-XML ausgibt, liegt unter `scripts/monitoring/prtg/dsls/` - nicht unter
`scripts/applications/dassault/`. Begruendung: wiederverwendbar ist an dem
Skript der PRTG-Vertrag, nicht das DSLS-Wissen. Wer einen weiteren Sensor
baut, sucht bei PRTG.

Zweite Regel fuer den Zweifelsfall:

> **Wonach wuerdest du in sechs Monaten suchen?** Danach wird abgelegt.

## Zielstruktur

```
scripts/
  active-directory/       AD, GPO, DNS, DHCP, LDAP
  windows-client/         Arbeitsplatz: Profile, Temp, Telemetrie, Fenster
  windows-server/         Serverdienste: Tasks, Shadow Copy, WMI, Firewall
  security/               Zertifikate, SecureBoot, BitLocker, Schwachstellensuche
  network/                LANCOM, Aruba, Ports, Verbindungen, WOL
  virtualization/         VMware
  databases/              MSSQL, Firebird, Sync
  messaging/              Exchange, Outlook, Mailstore, NoSpamProxy
  monitoring/             PRTG und andere Monitoring-Plattformen
  applications/           DocuWare, Zammad, TeamViewer, Kyocera, FileZilla, ...
modules/                  wiederverwendbare .psm1/.psd1
tools/                    Werkzeuge fuer dieses Repo selbst (Index-Generator)
third-party/              fremder, unveraenderter Code
docs/                     Doku zum Repo
_inbox/                   Zwischenablage, siehe unten
```

### `_inbox/` statt `unsorted-stuff/`

Eine Restekiste laesst sich nicht wegdefinieren - aber begrenzen. `_inbox/`
ist explizit als Durchgangsstation benannt und hat eine Regel:

> Was laenger als 30 Tage in `_inbox/` liegt, wird einsortiert oder geloescht.

Der Unterschied zu `unsorted-stuff` ist nicht der Name, sondern dass der
Zustand "unsortiert" damit sichtbar und befristet ist.

### `third-party/`

`Server-Client-Helper-Stuff/SecureBoot/Check-UEFISecureBootVariables-main/`
sind ~40 Dateien fremder Code, einmal als ZIP hineinkopiert. Sie stellen
damit rund ein Sechstel aller Dateien im Repo, ohne eigene Arbeit zu sein.
Fremdcode gehoert nach `third-party/<projekt>/` mit einer `ORIGIN.md`
(Quelle, Version, Abrufdatum, Lizenz) - oder besser als Git-Submodul, damit
Updates nachvollziehbar bleiben.

## Namenskonventionen

| Regel                         | Ja                          | Nein                                    |
| ----------------------------- | --------------------------- | --------------------------------------- |
| PowerShell Verb-Noun          | `Get-ADUserLastLogon.ps1`   | `check-for-bad-passwords.ps1`           |
| Nur freigegebene Verben       | `Get-`, `Set-`, `Test-`     | `Check-`, `Create-`, `Manage-`          |
| Englisch                      | `Set-FolderPermission.ps1`  | `Fileserver-Einzelberechtigungen-fuer-User.ps1` |
| ASCII in Pfaden               | `temporary-group-membership/` | `Temporäre-Gruppenmitgliedschaften-Verwalten/` |
| Ordner: kebab-case            | `active-directory/`         | `Server-Client-Helper-Stuff/`           |

`Check-` ist kein freigegebenes PowerShell-Verb - das Gegenstueck heisst
`Test-`. Ebenso `Create-` -> `New-`, `Manage-` -> `Set-`/`Update-`.

Umlaute in Pfaden sind nicht nur Geschmack: Git gibt sie als
`Tempor\303\244re-...` aus, und diverse Werkzeugketten (Tab-Completion ueber
SSH, Archive, CI-Runner) stolpern darueber.

### Versionsstaende

`Clear-OldTempFiles_v2/_v3/_v4`, `temporary-groupmembership_v2/_v3`,
`Elevate(Old).ps1` - vier Varianten nebeneinander beantworten nicht die
Frage, welche man nehmen soll.

> Es gibt genau **eine** kanonische Datei pro Aufgabe. Alte Staende loescht
> man - die History hat sie. Ist ein alter Stand bewusst als Referenz
> gewollt, kommt er nach `archive/` mit einer Zeile Begruendung im Header.

## Auffindbarkeit

Jedes Skript bekommt Comment-Based Help mit mindestens `.SYNOPSIS`.
`tools/Build-ScriptIndex.ps1` liest diese aus und erzeugt `INDEX.md` -
eine durchsuchbare Tabelle aller Skripte mit Pfad und Kurzbeschreibung.
Damit wird das Repo per Volltextsuche im Browser oder per `grep INDEX.md`
erschliessbar, ohne 156 Dateien zu oeffnen.

## Migrationspfad

Die Umstellung muss nicht auf einmal passieren. Sinnvolle Reihenfolge:

1. `third-party/` herausloesen - groesster Effekt, kein inhaltliches Risiko
2. `scripts/monitoring/` als erstes neues Zuhause (siehe PRTG-Beispiel)
3. `Active-Directory/` -> `scripts/active-directory/` mit Umbenennungen
4. `Server-Client-Helper-Stuff/` auf `windows-client` / `windows-server` /
   `security` / `network` aufteilen
5. `unsorted-stuff/` -> `_inbox/`, dann die 30-Tage-Regel anwenden

Verschiebungen mit `git mv` ausfuehren, damit die History der Dateien
erhalten bleibt.
