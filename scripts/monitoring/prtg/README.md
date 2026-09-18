# PRTG Custom Sensors

Skripte, die PRTG-XML auf stdout ausgeben und als Sensortyp
**"EXE/Skript (Erweitert)"** eingebunden werden.

## Warum liegen sie hier und nicht beim abgefragten Produkt?

Ein Sensor, der den Dassault-Lizenzserver abfragt, koennte auch unter
`scripts/applications/dassault/` liegen. Die Entscheidungsregel aus
[docs/STRUCTURE.md](../../../docs/STRUCTURE.md) sagt: das Skript existiert
nur wegen des PRTG-Ausgabevertrags. Wiederverwendbar ist daran der
PRTG-Teil, nicht das DSLS-Wissen. Also PRTG.

## Ausrollen

PRTG erwartet die Skripte unter

```
C:\Program Files (x86)\PRTG Network Monitor\Custom Sensors\EXEXML\
```

Den jeweiligen **Unterordner komplett** kopieren, nicht nur die einzelne
`.ps1` - die Sensoren importieren ihr Hilfsmodul relativ ueber `$PSScriptRoot`.

## Vertrag, an den sich jeder Sensor hier haelt

| Regel | Grund |
| ----- | ----- |
| Ausgabe ausschliesslich auf stdout, genau ein `<prtg>`-Dokument | PRTG parst nur stdout |
| Fehler als `<error>1</error><text>...</text>`, nicht als Exception | PRTG wertet den Exitcode nicht aus; eine Exception erzeugt nur "keine Daten" ohne Begruendung |
| Kanalnamen und Texte durch `ConvertTo-PrtgText` maskieren | ein `&` oder `<` im Text macht die Antwort ungueltig |
| `<limitmode>1</limitmode>` nur, wenn tatsaechlich eine Grenze gesetzt ist | sonst zeigt PRTG "Limits aktiv" ohne Limits |
| Keine `Write-Host`-Diagnose | landet sonst mit im XML |

## Sensoren

### `dsls/` - Dassault Systemes License Server

| Skript | Kanaele | Abgesetzter DSLS-Befehl |
| ------ | ------- | ----------------------- |
| `Get-DslsLicenseUsage.ps1` | je Komponente: Tage bis Ablauf, In Use, Available | `gli; glu -all` |
| `Get-DslsLogError.ps1` | Fehlermeldungen der letzten 24h | `sl -from <gestern>` |
| `Get-DslsOfflineLicense.ps1` | aktive Offline-Lizenzen (Nomad) | `mns -l` |
| `PRTG.Dsls.psm1` | gemeinsame Hilfsfunktionen, kein Sensor | - |

Beispielparameter in PRTG:

```
-TargetServer "%host"
```

**Sprachabhaengigkeit:** die Ausgabe von `DSLicSrv.exe` ist lokalisiert. Die
Regex-Muster in den Sensoren sind auf die deutsche Ausgabe ausgelegt und
jeweils als benannte Variable am Skriptanfang herausgezogen
(`$inventoryPattern`, `$usagePattern`, `$errorPattern`, `$entryPattern`).
Auf einem englischsprachigen DSLS muessen sie angepasst werden.
