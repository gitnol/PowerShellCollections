# Projektregeln

## Keine firmenspezifischen Details im Repo

Dieses Repository ist oeffentlich. Vor **jedem** Commit gilt: Skripte, Kommentare,
Beispiele und `.EXAMPLE`-Bloecke duerfen keine internen Bezeichner enthalten.

Verboten sind u.a.:

- Firmen- und Standortnamen sowie interne AD-/DNS-Domaenen
- Echte Benutzernamen, E-Mail-Adressen, Personennamen
- Echte Server-/DC-/Host-Namen und interne IP-Adressen
- Interne Freigaben, UNC-Pfade, Seriennummern
- Passwoerter, API-Keys, Tokens, private Schluessel

Stattdessen neutrale Platzhalter verwenden:

| Typ      | Beispielwert                                           |
| -------- | ------------------------------------------------------ |
| Domaene  | `contoso.local`, `example.com`                         |
| Server   | `DC01`, `DC02`, `SRV01`, `FS01`                        |
| Benutzer | `m.mustermann`, `m.mueller`, `j.doe`                   |
| E-Mail   | `max.mustermann@example.com`                           |
| IP       | `192.0.2.10`, `198.51.100.5`, `203.0.113.7` (RFC 5737) |
| Netz     | `192.0.2.0/24`                                         |

### Durchsetzung

Ein versionierter Git-Hook prueft das bei jedem Commit:

| Datei                                        | Versioniert | Inhalt                                          |
| -------------------------------------------- | ----------- | ----------------------------------------------- |
| `.githooks/pre-commit`                       | ja          | der Hook selbst                                 |
| `.githooks/forbidden-patterns.txt`           | ja          | generische Muster (Secrets, Tokens, Keys)       |
| `.githooks/forbidden-patterns.local.txt`     | **nein**    | die konkreten Firmen-, Personen- und Hostnamen  |
| `.githooks/forbidden-patterns.local.txt.example` | ja      | Vorlage fuer die lokale Datei                   |

Die lokale Liste ist bewusst per `.gitignore` ausgeschlossen: sie enthaelt genau
die Begriffe, die nicht ins oeffentliche Repo sollen. Waere sie versioniert,
wuerde der Schutzmechanismus selbst zum Leck.

Einrichtung einmalig pro Clone:

```sh
git config core.hooksPath .githooks
cp .githooks/forbidden-patterns.local.txt.example \
   .githooks/forbidden-patterns.local.txt
# lokale Datei um die eigenen Begriffe ergaenzen
```

Fehlt die lokale Datei, warnt der Hook sichtbar und prueft nur die generischen
Muster. Der Commit wird abgebrochen und mit Datei + Zeilennummer aufgelistet.
Bypass nur bewusst mit `git commit --no-verify`.
