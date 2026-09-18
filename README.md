# PowerShellCollections

Eine gewachsene Sammlung von PowerShell-Skripten aus dem Windows-/AD-Betrieb:
Active Directory, Client- und Serververwaltung, Zertifikate, Monitoring,
Netzwerk-Hardware und diverse Fachanwendungen.

## Einstieg

| Datei                                  | Inhalt                                                    |
| -------------------------------------- | --------------------------------------------------------- |
| [INDEX.md](INDEX.md)                   | durchsuchbare Liste aller Skripte mit Kurzbeschreibung     |
| [docs/STRUCTURE.md](docs/STRUCTURE.md) | Ablageregeln, Namenskonventionen, Migrationsplan           |
| [CLAUDE.md](CLAUDE.md)                 | Arbeitsregeln: Ablage, Kodierung, Namen, Secrets           |
| [docs/BACKLOG.md](docs/BACKLOG.md)     | bekannte offene Punkte, u.a. konkurrierende Versionsstaende |

Ein Skript suchen:

```sh
grep -i "lockout" INDEX.md
```

Den Index nach einer Aenderung neu erzeugen:

```powershell
.\tools\Build-ScriptIndex.ps1
```

## Einrichtung nach dem Klonen

Das Repo ist oeffentlich. Ein Git-Hook verhindert, dass interne Bezeichner
oder Zugangsdaten hineinrutschen - er muss pro Clone einmal aktiviert werden:

```sh
git config core.hooksPath .githooks
cp .githooks/forbidden-patterns.local.txt.example \
   .githooks/forbidden-patterns.local.txt
# lokale Datei um die eigenen Firmen-, Personen- und Hostnamen ergaenzen
```

Details in [CLAUDE.md](CLAUDE.md).

## Struktur

Ein Skript liegt unter dem System, gegen das es laeuft. Die vollstaendige
Regel samt Begruendung steht in [docs/STRUCTURE.md](docs/STRUCTURE.md).

| Verzeichnis                                       | Inhalt                                              |
| ------------------------------------------------- | --------------------------------------------------- |
| [scripts/active-directory/](scripts/active-directory/) | AD-Objekte, GPO, DNS, LDAP, Anmelde-Events      |
| [scripts/windows/](scripts/windows/)              | Sessions, Prozesse, Dienste, Tasks, WMI, Eventlog   |
| [scripts/security/](scripts/security/)            | Zertifikate, SecureBoot, BitLocker, Passwoerter     |
| [scripts/network/](scripts/network/)              | LANCOM, Aruba, DHCP, Firewall, WOL, Diagnose        |
| [scripts/monitoring/](scripts/monitoring/)        | PRTG-Sensoren, Ping-Monitor, Web-Aenderungen        |
| [scripts/messaging/](scripts/messaging/)          | Exchange, Outlook, Mailstore, NoSpamProxy           |
| [scripts/databases/](scripts/databases/)          | MSSQL, Firebird                                     |
| [scripts/applications/](scripts/applications/)    | DocuWare, Zammad, TeamViewer, Kyocera, FileZilla    |
| [scripts/filesystem/](scripts/filesystem/)        | Berechtigungen, Suche, Links                        |
| [scripts/virtualization/](scripts/virtualization/) | VMware                                             |
| [snippets/](snippets/)                            | Code-Beispiele ohne Betriebszweck                   |
| [third-party/](third-party/)                      | fremder, unveraenderter Code                        |
| [_inbox/](_inbox/)                                | Zwischenablage, 30-Tage-Regel                       |

Referenzbeispiel fuer den Zuschnitt eines Themas:
[scripts/monitoring/prtg/](scripts/monitoring/prtg/)

## Zustand der Skripte

Die Sammlung ist ueber Jahre entstanden und nicht durchgaengig gepflegt.
Qualitaet und Aktualitaet schwanken, mehrere Aufgaben liegen in konkurrierenden
Versionsstaenden nebeneinander (`_v2`, `_v3`, `_old`). Vor dem Produktiveinsatz
lesen und in einer Testumgebung ausprobieren.

## Lizenz

Siehe [LICENSE](LICENSE).
