# Herkunft

Fremder Code - nicht in diesem Repository entstanden.

| Feld      | Wert                                                       |
| --------- | ---------------------------------------------------------- |
| Projekt   | MailStore Server PowerShell API Wrapper                     |
| Hersteller| MailStore Software GmbH                                     |
| Autor     | Bjoern Meyn (laut `MS.PS.Lib.psd1`)                         |
| Version   | Modulversion 12.0                                           |
| Copyright | (c) 2014 - 2019 MailStore Software GmbH                     |
| Lizenz    | MIT-artig, vollstaendiger Text im Kopf jeder Datei          |
| Quelle    | https://help.mailstore.com/de/server/PowerShell_API-Wrapper_Tutorial |

## Inhalt

| Verzeichnis           | Inhalt                                                   |
| --------------------- | -------------------------------------------------------- |
| `api-wrapper/`        | das Modul selbst (`MS.PS.Lib.psm1`, `MS.PS.Lib.psd1`)     |
| `examples/`           | die vier Beispielskripte aus dem Hersteller-Tutorial      |
| `python-api-wrapper/` | die Python-Entsprechung desselben Wrappers                |

Die Beispiele hiessen urspruenglich `Example1.ps1` bis `Example4.ps1` und
wurden nach ihrem Inhalt benannt (`Get-ServerInfo`, `Get-AllUserInfo`,
`Invoke-StoreVerification`, `Invoke-StoreVerificationAsync`). Das ist die
einzige Aenderung gegenueber dem Original.

## Hinweis zur Kodierung

`api-wrapper/MS.PS.Lib.psd1` liegt als UTF-16 LE vor und ist in
`.gitattributes` als `binary` markiert. Nicht konvertieren - weder Zeilenenden
noch Kodierung.

## Abgrenzung

Eigene Arbeit liegt unter `scripts/messaging/mailstore/`:

- `MailStoreApiFunctions.ps1` - aus der Online-Funktionsreferenz erzeugte
  PowerShell-Huellen fuer die Administrations-API
- `MailStoreSnippets.ps1` - Funktionssammlung samt konkreter Auswertungen
- `New-MailStoreApiFunctionReference.ps1` - der Generator dazu

Diese Skripte importieren das Modul von hier. Wird der Ordner verschoben,
brechen ihre Import-Pfade.

## Aenderungen

Ausser den Dateinamen der Beispiele keine. Hier nichts anpassen - eine neue
Version holt man beim Hersteller.
