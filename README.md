# PowerShellCollections

Eine gewachsene Sammlung von PowerShell-Skripten aus dem Windows-/AD-Betrieb:
Active Directory, Client- und Serververwaltung, Zertifikate, Monitoring,
Netzwerk-Hardware und diverse Fachanwendungen.

## Einstieg

| Datei                                  | Inhalt                                                    |
| -------------------------------------- | --------------------------------------------------------- |
| [INDEX.md](INDEX.md)                   | durchsuchbare Liste aller Skripte mit Kurzbeschreibung     |
| [docs/STRUCTURE.md](docs/STRUCTURE.md) | Ablageregeln, Namenskonventionen, Migrationsplan           |
| [CLAUDE.md](CLAUDE.md)                 | Regel: keine firmenspezifischen Daten im Repo              |

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

Die Ablage wird gerade von einer flachen, gewachsenen Struktur auf die in
[docs/STRUCTURE.md](docs/STRUCTURE.md) beschriebene umgestellt. Neue Skripte
kommen bereits unter `scripts/<system>/`; die alten Ordner auf oberster Ebene
werden schrittweise dorthin ueberfuehrt.

Referenzbeispiel fuer die Zielstruktur:
[scripts/monitoring/prtg/](scripts/monitoring/prtg/)

## Zustand der Skripte

Die Sammlung ist ueber Jahre entstanden und nicht durchgaengig gepflegt.
Qualitaet und Aktualitaet schwanken; `LOST+FOUND+UNTESTED/` ist als solches
gekennzeichnet. Vor dem Produktiveinsatz lesen und in einer Testumgebung
ausprobieren.

## Lizenz

Siehe [LICENSE](LICENSE).
