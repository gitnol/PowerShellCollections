# Firmenspezifische Daten in der Git-History

Entscheidungsvorlage. Stand: 2026-09-18.

## Befund

Elf Dateien in frueheren Commits enthalten Angaben, die nach der heutigen
Regel (siehe [../CLAUDE.md](../CLAUDE.md)) nicht ins oeffentliche Repository
gehoeren:

| Art                    | Beispiel                              |
| ---------------------- | ------------------------------------- |
| interne AD-Domaene     | `*.<firma>.local`                     |
| Hostnamen              | Arbeitsplatzname aus dem Inventarschema |
| interne IP             | eine Adresse aus dem 10er-Netz        |
| Benutzernamen          | drei, im Schema `vorname.nachname`    |
| interne URL            | Helpdesk-Adresse samt Ticketnummer    |
| Datenbank- und Ablagepfade | Laufwerksbuchstaben und Freigaben |

**Keine Zugangsdaten.** Alle passwortartigen Fundstellen sind Platzhalter
(`your-api-token`, `mypassword`, `SecurePassword123!`) oder Variablen. Das ist
die wichtigste Zahl in dieser Vorlage: es gibt nichts zu rotieren.

**Commit-Metadaten sind sauber.** Alle 475 Commits tragen das Pseudonym
`Gitnol <git@noldi.de>`, keine Firmen-Mailadresse.

Aktueller Stand (`HEAD`) ist sauber; der pre-commit-Hook haelt das so.

## Ausgangslage fuer die Entscheidung

| Kennzahl        | Wert                        | Bedeutung                                   |
| --------------- | --------------------------- | ------------------------------------------- |
| Forks           | 0                           | niemand hat eine Kopie mit der alten History |
| Stars           | 0                           | keine Sichtbarkeit, die verlorenginge        |
| Watcher         | 1 (der Eigentuemer)         | keine Benachrichtigungen an Dritte           |
| Issues / PRs    | keine                       | nichts, was an Commit-Links haengt           |
| Oeffentlich seit | 2024-07-25                  | rund zwei Jahre indexierbar                  |
| Commits         | 475                         | Umfang einer Umschreibung                    |
| Zweige remote   | `main`, `gitnol-patch-1`    | beide muessten mit                           |

Das ist die guenstigste Lage, die es fuer so eine Bereinigung gibt: es gibt
praktisch keinen Kollateralschaden.

## Was keine der Optionen leistet

Nichts davon macht die Veroeffentlichung rueckgaengig. Seit 2024 koennen
Suchmaschinen-Caches, GHArchive und Software Heritage Kopien haben. Die
Bezeichner sind als bekannt zu behandeln - unabhaengig davon, wofuer du dich
entscheidest. Der Nutzen einer Bereinigung liegt darin, dass sie kuenftig
nicht mehr *auffindbar* sind, nicht darin, dass sie nie existiert haetten.

---

## Option 1 - Nichts tun, Entscheidung dokumentieren

Die History bleibt, wie sie ist. In `docs/` wird festgehalten, dass der Fund
bekannt ist und bewusst akzeptiert wurde.

**Dafuer:** kein Aufwand, kein Risiko, keine kaputten Links.
**Dagegen:** die Angaben bleiben ueber die GitHub-Suche und ueber
`git log -S` in jedem Clone auffindbar. Interne Domaenen- und Hostnamen sind
brauchbares Material fuer Phishing- und Social-Engineering-Versuche.

**Sinnvoll, wenn** der Aufwand in keinem Verhaeltnis steht und die Angaben als
ohnehin bekannt gelten - die oeffentliche Mailadress-Domaene der Firma verraet
das Benutzernamensschema bereits.

---

## Option 2 - `git filter-repo` und Force-Push

Alle 475 Commits werden umgeschrieben, die Begriffe durch Platzhalter ersetzt,
das Ergebnis mit `--force` gepusht.

**Dafuer:** Repository bleibt bestehen, History bleibt in Struktur und Anzahl
erhalten.
**Dagegen:** der entscheidende Haken - nach einem Force-Push bleiben die alten
Commits auf GitHub **weiterhin ueber ihre SHA-URL abrufbar**. GitHub raeumt
unerreichbare Objekte nicht von selbst auf. Dafuer braucht es ein Ticket beim
GitHub-Support. Bis das bearbeitet ist, hat die Umschreibung nichts bewirkt,
wer die alte SHA kennt.

**Sinnvoll, wenn** das Repository aus anderen Gruenden erhalten bleiben muss
(Stars, Issues, eingehende Links) - was hier nicht der Fall ist.

---

## Option 3 - Repository loeschen und neu anlegen (Empfehlung)

Lokal umschreiben, Repository auf GitHub loeschen, unter demselben Namen neu
anlegen, den bereinigten Stand pushen.

**Dafuer:** die alten Objekte sind damit tatsaechlich weg, ohne Support-Ticket.
Bei 0 Forks, 0 Stars, 0 Issues geht dabei nichts verloren.
**Dagegen:** das Erstellungsdatum wird neu gesetzt, und Links auf alte Commits
brechen - was sie bei jeder Umschreibung tun.

### Ablauf

```sh
# 1. Sicherung ZUERST, auf ein externes Medium
git clone --mirror https://github.com/gitnol/PowerShellCollections.git backup.git

# 2. Werkzeug
pip install git-filter-repo

# 3. Ersetzungsliste AUSSERHALB des Repos anlegen.
#    Sie enthaelt per Definition genau die zu schuetzenden Begriffe -
#    dieselbe Logik wie bei .githooks/forbidden-patterns.local.txt.
cat > ../replacements.txt <<'EOF'
<firma>-<ort>.local==>contoso.local
<firma>-<ort>==>contoso
<hostname>==>WS01
10.0.185.82==>192.0.2.82
m.<nachname>==>m.mustermann
EOF

# 4. Umschreiben (frischer Clone, filter-repo verlangt das)
git clone https://github.com/gitnol/PowerShellCollections.git clean
cd clean
git filter-repo --replace-text ../replacements.txt

# 5. Gegenprobe ueber ALLE Objekte, nicht nur HEAD
git grep -i -l -E '<firma>|<ort>|<nachname>' $(git rev-list --all)
#    -> muss leer sein

# 6. Repository auf GitHub loeschen, gleichnamig neu anlegen, dann
git remote add origin https://github.com/gitnol/PowerShellCollections.git
git push --all
git push --tags
```

Schritt 5 ist der wichtigste. `git grep` nur auf `HEAD` uebersieht genau das,
worum es geht.

Den Zweig `gitnol-patch-1` nicht vergessen - haengt ein alter Commit noch an
einem Zweig, war die Umschreibung umsonst.

---

## Option 4 - History auf einen Commit zusammenfassen

Statt umzuschreiben: den aktuellen, sauberen Stand als einzigen Commit
veroeffentlichen. Die vollstaendige History bleibt lokal und in der Sicherung.

**Dafuer:** einfachster Weg, garantiert sauber, keine Werkzeuge noetig.
**Dagegen:** die Entwicklungsgeschichte ist oeffentlich weg - bei einer
Skriptsammlung weniger schmerzhaft als bei einem Produkt, aber `git log`
verliert jeden Wert. Auch hier bleiben alte Objekte bis zur GC erreichbar,
sofern nicht ebenfalls geloescht und neu angelegt wird.

**Sinnvoll, wenn** die History ohnehin niemand liest und Aufwand zaehlt.

---

## Empfehlung

**Option 3.** Die Kennzahlen sprechen dafuer: null Forks, null Stars, null
Issues - der uebliche Grund, eine Umschreibung zu scheuen, entfaellt hier
vollstaendig. Der Aufwand liegt bei einer knappen Stunde, und im Gegensatz zu
Option 2 sind die alten Objekte danach wirklich weg.

**Option 1 ist aber vertretbar** und keine Nachlaessigkeit - es sind keine
Zugangsdaten betroffen, und das Benutzernamensschema ergibt sich ohnehin aus
jeder Firmen-Mailadresse. Wenn du dich dafuer entscheidest, halte es hier
schriftlich fest, damit die Frage nicht in einem Jahr erneut aufgemacht wird.

Wovon abzuraten ist: Option 2 ohne anschliessendes Support-Ticket. Das sieht
erledigt aus und ist es nicht.
