# Herkunft

Fremder Code - nicht in diesem Repository entstanden.

| Feld    | Wert                                                              |
| ------- | ----------------------------------------------------------------- |
| Projekt | Get-TokenSizeReport.ps1                                            |
| Autor   | Jeremy Saunders (jhouseconsulting.com)                             |
| Quelle  | https://github.com/jeremyts/ActiveDirectoryDomainServices          |
| Version | Release 1.8, zuletzt geaendert 31.12.2013                          |
| Basiert auf | CheckMaxTokenSize.ps1 von Tim Springston (Microsoft), 19.07.2013 |
| Lizenz  | siehe Upstream-Repository                                          |

## Was es tut

Zaehlt je Domaenenbenutzer die rekursiven Gruppenmitgliedschaften, unterscheidet
domaenenlokale, globale und universelle Gruppen sowie SID-History, und rechnet
daraus die zu erwartende Kerberos-Tokengroesse aus. Ergebnis ist ein CSV-Report
der groessten Konten.

Zu grosse Tokens aeussern sich als Anmeldefehler oder als HTTP 400 an
IIS-Anwendungen, weil der Kerberos-Ticket-Header die Puffergroesse
ueberschreitet.

## Lizenzlage - ungeklaert

Das Upstream-Repository enthaelt **keine LICENSE-Datei**, und im Skript selbst
steht kein Lizenzhinweis. Damit gilt das gesetzliche Urheberrecht: alle Rechte
beim Autor. Die GitHub-Nutzungsbedingungen erlauben anderen Nutzern das
Ansehen und Forken eines oeffentlichen Repositorys - eine Kopie in ein
fremdes Repository zu legen, ist davon nicht gedeckt.

Sauber waere: als Git-Submodul einbinden (ein Verweis, keine Kopie) oder den
Autor um Erlaubnis fragen. Siehe docs/BACKLOG.md.

## Abgrenzung

Ein zweites Skript zur selben Aufgabe lag frueher unter
`scripts/active-directory/token-size/Export-KerberosTokenSize.ps1`. Es
stammt von msxfaq.de (Frank Carius), dessen Nutzungsbedingungen eine
Weiterveroeffentlichung ohne vorherige Zustimmung ausschliessen - es wurde
deshalb entfernt.

## Aenderungen

Keine. Hier nichts anpassen - Aenderungen gehoeren upstream oder in einen
eigenen Wrapper unter `scripts/active-directory/token-size/`.
