# Arbeiten in diesem Repository

Sammlung von PowerShell-Skripten aus dem Windows-/AD-Betrieb. Oeffentliches
Repository, ueber Jahre gewachsen, ein Autor.

## Zuerst lesen

| Frage                                  | Antwort steht in                         |
| -------------------------------------- | ---------------------------------------- |
| Welches Skript macht was?              | [INDEX.md](INDEX.md) - generiert          |
| Wohin gehoert eine neue Datei?         | [docs/STRUCTURE.md](docs/STRUCTURE.md)    |
| Wie ist ein Thema zugeschnitten?       | [scripts/monitoring/prtg/](scripts/monitoring/prtg/) als Referenz |

`INDEX.md` ist der schnellste Einstieg: eine Zeile pro Skript mit Pfad und
Kurzbeschreibung. `grep -i "lockout" INDEX.md` beantwortet die meisten
Suchfragen, ohne Dateien zu oeffnen.

## Ablage

> **Ein Skript liegt unter dem System, gegen das es laeuft.**
>
> Existiert es nur wegen des Ausgabe-Vertrags einer Plattform (PRTG-XML,
> Nagios-Exitcode), ist **die Plattform** das System - nicht das abgefragte
> Produkt.

Ein Skript, das per `Get-ADComputer` nur die Rechnerliste holt, gehoert nicht
unter `active-directory/` - AD ist dort die Bezugsquelle, nicht das Thema.

Nie gefunden, wohin damit? Nach `_inbox/`, nicht irgendwohin. Dort gilt die
30-Tage-Regel.

## Konventionen

### Kodierung - wichtig

Enthaelt eine `.ps1`/`.psm1` Nicht-ASCII-Zeichen (Umlaute), **muss** sie ein
UTF-8-BOM haben. Windows PowerShell 5.1 liest sonst in der ANSI-Codepage:
aus `Prüfe` wird `PrÃ¼fe`, und regulaere Ausdruecke mit Umlauten matchen
nicht mehr - ohne Fehlermeldung. Mehrere Skripte hier werten
deutschsprachige Eventlog- und Programmausgaben aus und waeren davon
betroffen. Im Repo liegen Skripte mit `#Requires -Version 5.1`, die Annahme
"alles laeuft unter PS7" traegt also nicht.

```powershell
# Pruefen und reparieren
.\tools\Repair-ScriptEncoding.ps1 -WhatIf
.\tools\Repair-ScriptEncoding.ps1
```

Reine ASCII-Dateien brauchen kein BOM.
`scripts/messaging/mailstore/api-wrapper/MS.PS.Lib.psd1` liegt als UTF-16 LE
vor und ist in `.gitattributes` als `binary` markiert - nicht konvertieren.

### Zeilenenden

Festgelegt in [.gitattributes](.gitattributes): im Repository LF, im
Arbeitsverzeichnis CRLF fuer `.ps1`/`.psm1`/`.psd1`/`.bat`/`.cmd`/`.xml`,
LF fuer `.sh` und `.githooks/*` (ein Hook mit CRLF scheitert an
`bad interpreter`). Nicht von Hand umstellen.

### Namensgebung

| Regel                   | Ja                         | Nein                             |
| ----------------------- | -------------------------- | -------------------------------- |
| Verb-Noun               | `Get-ADUserLastLogon.ps1`  | `check-for-bad-passwords.ps1` (alt) |
| Freigegebene Verben     | `Get-`, `Set-`, `Test-`    | `Check-`, `Create-`, `Manage-`   |
| Englisch                | `Set-FolderPermission.ps1` | `Fileserver-Einzelberechtigungen-fuer-User.ps1` (alt) |
| ASCII in Pfaden         | `temporary/`               | `Temporäre-.../`                 |
| Ordner kebab-case       | `active-directory/`        | `Server-Client-Helper-Stuff/`    |

`Get-Verb` listet die zulaessigen Verben. `Check-` gibt es nicht - das heisst
`Test-`.

Die mit "(alt)" markierten Beispiele sind Namen, die es hier tatsaechlich gab -
sie sind inzwischen umbenannt. Ein Suffix `_v1`/`_v2`/`_old` ist nur dort
zulaessig, wo mehrere Staende derselben Aufgabe nebeneinanderliegen und noch
nicht entschieden ist, welcher gilt: [docs/BACKLOG.md](docs/BACKLOG.md).

Verb-Noun gilt fuer **ausfuehrbare Skripte**. Ausgenommen sind:

| Art                   | Benennung                  | Beispiele                                 |
| --------------------- | -------------------------- | ----------------------------------------- |
| Module                | nach dem Modul             | `OSBiz.psm1`, `PRTG.Dsls.psm1`, `MS.PS.Lib.psm1` |
| Funktionsbibliotheken | nach dem Inhalt            | `MailStoreApiFunctions.ps1`, `UserSessionFunctions.ps1` |
| Nummerierte Beispiele | fortlaufend                | `examples/Example1.ps1`                   |

Eine Bibliothek definiert nur Funktionen und wird dot-gesourct; ein Verb waere
dort irrefuehrend, weil die Datei selbst nichts tut.

### Comment-Based Help

Jedes neue Skript bekommt mindestens `.SYNOPSIS`. Der Index liest sie aus.
Nach dem Anlegen oder Umbenennen von Skripten:

```powershell
.\tools\Build-ScriptIndex.ps1
```

## Keine firmenspezifischen Details

Das Repository ist oeffentlich. Verboten sind:

- Firmen- und Standortnamen, interne AD-/DNS-Domaenen
- echte Benutzernamen, E-Mail-Adressen, Personennamen
- echte Server-/Host-Namen, interne IP-Adressen, UNC-Pfade
- Passwoerter, API-Keys, Tokens, private Schluessel

Platzhalter stattdessen:

| Typ      | Wert                                                   |
| -------- | ------------------------------------------------------ |
| Domaene  | `contoso.local`, `example.com`                         |
| Server   | `DC01`, `DC02`, `SRV01`, `FS01`                        |
| Benutzer | `m.mustermann`, `m.mueller`, `j.doe`                   |
| E-Mail   | `max.mustermann@example.com`                           |
| IP       | `192.0.2.10`, `198.51.100.5`, `203.0.113.7` (RFC 5737) |

### Durchsetzung

`.githooks/pre-commit` prueft das bei jedem Commit.

| Datei                                            | Versioniert | Inhalt                          |
| ------------------------------------------------ | ----------- | ------------------------------- |
| `.githooks/pre-commit`                           | ja          | der Hook                        |
| `.githooks/forbidden-patterns.txt`               | ja          | generische Muster (Secrets)     |
| `.githooks/forbidden-patterns.local.txt`         | **nein**    | die konkreten Namen             |
| `.githooks/forbidden-patterns.local.txt.example` | ja          | Vorlage                         |

Die lokale Liste ist bewusst per `.gitignore` ausgeschlossen: waere sie
versioniert, stuenden genau die zu schuetzenden Begriffe im oeffentlichen
Repo - der Schutz waere selbst das Leck.

Einrichtung pro Clone:

```sh
git config core.hooksPath .githooks
cp .githooks/forbidden-patterns.local.txt.example \
   .githooks/forbidden-patterns.local.txt
```

Der Hook prueft nur Inhalt, der neu ins Repository kommt - eine reine
Verschiebung loest ihn nicht aus. Altbestand bereinigt man getrennt, nicht
ueber einen Commit-Hook. Platzhalter in Beispielcode, die sich per Regex
nicht von echten Secrets trennen lassen, bekommen `allowlist secret` in
einen Kommentar auf derselben Zeile.

Bypass nur bewusst mit `git commit --no-verify`.

## Fallstricke in diesem Bestand

Wer hier arbeitet, sollte das wissen - es ist nicht offensichtlich:

- **Konkurrierende Versionsstaende.** Mehrere Aufgaben liegen in zwei bis vier
  Staenden nebeneinander, erkennbar am Suffix `_v1`/`_v2`/`_old`.
  [docs/BACKLOG.md](docs/BACKLOG.md) listet sie mit Datum, Umfang und einer
  begruendeten Empfehlung auf. Empfohlen heisst nicht entschieden - im
  Zweifel nachfragen statt raten.
- **Nur rund ein Drittel der Skripte hat eine `.SYNOPSIS`.** `INDEX.md` zeigt
  sonst ersatzweise die erste Kommentarzeile, gekennzeichnet mit
  `(aus Kommentar)`. Das ist ein Hinweis, keine Beschreibung - er kann auch
  danebenliegen.
- **Die meisten Dateien fuehren beim Laden Code aus.** Typisch: eine Funktion
  wird definiert und am Dateiende gleich aufgerufen. Dot-Sourcing zum
  Erkunden ist deshalb riskant - manche Skripte greifen dabei sofort auf AD
  oder Remote-Rechner zu. Nur die mit `def` markierten Dateien (35 von 164)
  enthalten ausser Definitionen nichts Ausfuehrbares. Im Zweifel lesen statt
  laden.
- **`scripts/messaging/mailstore/Invoke-MailStoreApiScratch.ps1` parst nicht**
  (6 Syntaxfehler, Altbestand). Index und Dateikopf weisen darauf hin.
- **`third-party/` nicht anfassen.** Fremdcode, unveraendert. Aenderungen
  gehoeren upstream oder in einen eigenen Wrapper.
- **`_inbox/` ist kein Ablageort**, sondern eine Durchgangsstation.
