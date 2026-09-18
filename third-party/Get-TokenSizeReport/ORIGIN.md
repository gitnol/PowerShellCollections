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

## Abgrenzung

`scripts/active-directory/token-size/Export-KerberosTokenSize.ps1` loest
dieselbe Aufgabe, traegt aber keine Herkunftsangabe (Versionshinweise von
2012, Release 1.1 bis 1.5). Ob es eine eigene Entwicklung oder ebenfalls
uebernommen ist, liess sich nicht klaeren - deshalb liegt es weiter unter
`scripts/`.

## Aenderungen

Keine. Hier nichts anpassen - Aenderungen gehoeren upstream oder in einen
eigenen Wrapper unter `scripts/active-directory/token-size/`.
