# Create-PublicSpotUsers.ps1

PowerShell-Skript zur automatisierten Massenanlage von **Public Spot Benutzern** auf LANCOM WLC/Routern via REST-API, gesteuert über eine CSV-Eingabedatei.

---

## Inhaltsverzeichnis

- [Create-PublicSpotUsers.ps1](#create-publicspotusersps1)
  - [Inhaltsverzeichnis](#inhaltsverzeichnis)
  - [Voraussetzungen](#voraussetzungen)
  - [Funktionsweise](#funktionsweise)
    - [Hinweis zur LANCOM-API-Syntax](#hinweis-zur-lancom-api-syntax)
  - [Parameter](#parameter)
  - [CSV-Eingabeformat](#csv-eingabeformat)
  - [CSV-Ausgabeformat](#csv-ausgabeformat)
  - [Verwendung](#verwendung)
    - [Interaktive Eingabe des Passworts (empfohlen)](#interaktive-eingabe-des-passworts-empfohlen)
    - [Mit alternativer Router-IP und abweichender Ausgabedatei](#mit-alternativer-router-ip-und-abweichender-ausgabedatei)
    - [Mit aktivierter Zertifikatsprüfung (für CA-signierte Zertifikate)](#mit-aktivierter-zertifikatsprüfung-für-ca-signierte-zertifikate)
    - [Beispielausgabe](#beispielausgabe)
  - [Dateinamen-Konventionen](#dateinamen-konventionen)
  - [Fehlerbehandlung](#fehlerbehandlung)
  - [Bekannte Einschränkungen](#bekannte-einschränkungen)
  - [Changelog](#changelog)
    - [v1.4](#v14)
    - [v1.2](#v12)
    - [v1.1](#v11)
    - [v1.0](#v10)

---

## Voraussetzungen

| Anforderung | Details |
|---|---|
| PowerShell | Version 7.x empfohlen (`-SkipCertificateCheck` als Parameter erfordert PS 6+) |
| LANCOM-Gerät | WLC oder Router mit aktivierter REST-API und Public Spot Modul |
| Netzwerkzugang | HTTPS-Erreichbarkeit des LANCOM-Geräts (Port 443) |
| Berechtigungen | Admin-Konto auf dem LANCOM-Gerät mit Recht zur Nutzerverwaltung |

---

## Funktionsweise

```
Start
  │
  ├─► InputCsv existiert nicht?
  │     └─► Beispiel-CSV erstellen → Skript beendet sich
  │
  ├─► CSV einlesen & Pflichtfelder validieren
  │
  ├─► Pro Zeile:
  │     ├─► REST-API aufrufen (cmdpbspotuser)
  │     ├─► Antwort per RegEx parsen
  │     └─► Ergebnis (OK / Fehler) in Ergebnis-Liste speichern
  │
  ├─► Ergebnis-CSV mit Zeitstempel schreiben
  ├─► Abschlusszusammenfassung ausgeben
  └─► Eingabe-CSV mit Zeitstempel umbenennen (Archivierung)
```

Die Funktion `Invoke-CmdPbSpotUser` kapselt den HTTPS-Aufruf vollständig. Das Passwort wird intern aus dem `SecureString` in Klartext gewandelt, ausschließlich für den Base64-kodierten Basic-Auth-Header, und nicht persistiert.

### Hinweis zur LANCOM-API-Syntax

Die LANCOM `cmdpbspotuser`-API verwendet `+` als **internen Combiner** für zusammengehörige Sub-Parameter, nicht als URL-Trennzeichen:

```
&unit=Day+runtime=7
&expirytype=absolute+validper=3
```

Dies ist die dokumentierte und vom LANCOM-Gerät erwartete Syntax. Standard-URL-Trennzeichen (`&`) würden diese kombinierten Parameter aufbrechen. Leerzeichen und Sonderzeichen im `comment`-Feld werden deshalb mit `[System.Uri]::EscapeDataString()` als `%20` kodiert, um Kollisionen mit dem `+`-Combiner zu vermeiden.

---

## Parameter

| Parameter | Pflicht | Standard | Beschreibung |
|---|---|---|---|
| `-RouterIP` | Nein | `10.0.8.240` | IP-Adresse oder Hostname des LANCOM-Geräts |
| `-AdminUser` | **Ja** | — | Admin-Benutzername für die LANCOM REST-API |
| `-AdminPass` | **Ja** | — | Admin-Passwort als `SecureString` |
| `-InputCsv` | **Ja** | — | Pfad zur Eingabe-CSV-Datei |
| `-OutputCsv` | Nein | `.\Ausgabe_Zugangsdaten.csv` | Basispfad der Ergebnis-CSV (Zeitstempel wird automatisch angehängt) |
| `-SkipCertificateCheck` | Nein | `$true` | HTTPS-Zertifikatsprüfung überspringen (Standard `$true` für selbstsignierte LANCOM-Zertifikate) |

---

## CSV-Eingabeformat

Trennzeichen: **Semikolon** (`;`)  
Kodierung: **UTF-8**

| Spalte | Typ | Beschreibung | Beispielwerte |
|---|---|---|---|
| `Comment` | String | Anzeigename / Beschreibung des Benutzers. **Keine Umlaute** (LANCOM-Einschränkung). Max. 191 Zeichen. | `Max Mustermann`, `Besprechungsraum A` |
| `Unit` | String | Zeiteinheit für die Laufzeit. **Muss englisch sein:** `Day`, `Hour`, `Minute` | `Day`, `Minute` |
| `Runtime` | Integer | Laufzeit in der gewählten Einheit | `1`, `7`, `240` |
| `ExpiryType` | String | Ablaufmodus | `absolute`, `relative`, `both`, `none` |
| `ValidPer` | Integer | Verfallsdauer in Tagen (wird immer an die API übergeben) | `0`, `3`, `7` |
| `SSID` | String | Ziel-SSID für den Public Spot | `LVISITOR` |
| `MaxConcLogins` | Integer | Max. gleichzeitige Anmeldungen (erfordert `multilogin`-Flag, der intern immer gesetzt wird) | `1`, `2`, `5` |
| `BandwidthProfile` | Integer | Zeilennummer des Bandbreitenprofils in der LANCOM-Konfiguration | `1`, `2` |
| `TimeBudget` | Integer | Zeitbudget in Minuten (`0` = LANCOM-Default) | `0`, `60` |
| `VolumeBudget` | String | Volumenbudget (`0` = LANCOM-Default). Suffix `k/m/g` möglich (z.B. `1m`, `500k`, `2g`). Ohne Suffix = Byte. | `0`, `1m`, `500k`, `2g` |
| `Active` | Integer | Konto aktiv (`1`) oder gesperrt (`0`) | `0`, `1` |

**Beispieldatei** (wird automatisch erstellt, wenn `InputCsv` nicht existiert):

```csv
Comment;Unit;Runtime;ExpiryType;ValidPer;SSID;MaxConcLogins;BandwidthProfile;TimeBudget;VolumeBudget;Active
Max Mustermann;Day;1;absolute;1;LVISITOR;1;1;0;0;1
Techniker Firma X;Day;7;absolute;7;LVISITOR;2;1;0;0;1
Besprechungsraum A;Minute;240;relative;0;LVISITOR;5;2;0;0;1
```

> **Hinweis zu `ExpiryType`:**
>
> | Wert | Verhalten |
> |---|---|
> | `absolute` | Konto läuft zu einem festen Datum ab (Erstellungsdatum + Laufzeit) |
> | `relative` | Konto läuft ab der **ersten Anmeldung** für die definierte Laufzeit |
> | `both` | Kombiniert: `ValidPer` legt zusätzlich ein absolutes Maximaldatum fest |
> | `none` | Kein Ablauf |

---

## CSV-Ausgabeformat

Trennzeichen: **Semikolon** (`;`)  
Kodierung: **UTF-8**

| Spalte | Beschreibung |
|---|---|
| `Comment` | Übernahme aus der Eingabe-CSV |
| `Username` | Vom LANCOM generierter Benutzername |
| `Password` | Vom LANCOM generiertes Passwort |
| `SSID` | SSID, für die der Account gilt |
| `AccountEnd` | Ablaufdatum des Kontos (leer bei relativer Gültigkeit) |
| `Lifetime` | Gültigkeitsdauer |
| `Status` | `Erfolgreich`, `Fehler: API-Aufruf fehlgeschlagen`, `Fehler: Antwortformat unbekannt` |

---

## Verwendung

### Interaktive Eingabe des Passworts (empfohlen)

```powershell
$SecurePass = Read-Host -Prompt "LANCOM Admin-Passwort" -AsSecureString
.\Create-PublicSpotUsers.ps1 -AdminUser "admin" -AdminPass $SecurePass -InputCsv ".\Eingabe_Benutzer.csv"
```

### Mit alternativer Router-IP und abweichender Ausgabedatei

```powershell
$SecurePass = Read-Host -Prompt "LANCOM Admin-Passwort" -AsSecureString
.\Create-PublicSpotUsers.ps1 `
    -RouterIP "192.168.1.1" `
    -AdminUser "root" `
    -AdminPass $SecurePass `
    -InputCsv ".\Gaeste_Juni.csv" `
    -OutputCsv ".\Ergebnisse\Gaeste_Zugangsdaten.csv"
```

### Mit aktivierter Zertifikatsprüfung (für CA-signierte Zertifikate)

```powershell
$SecurePass = Read-Host -Prompt "LANCOM Admin-Passwort" -AsSecureString
.\Create-PublicSpotUsers.ps1 -AdminUser "admin" -AdminPass $SecurePass -InputCsv ".\users.csv" -SkipCertificateCheck $false
```

### Beispielausgabe

```
Starte Verarbeitung von 3 Benutzern...
Erstelle Benutzer fuer: Max Mustermann... OK
Erstelle Benutzer fuer: Techniker Firma X... OK
Erstelle Benutzer fuer: Besprechungsraum A... OK
Verarbeitung abgeschlossen. Ergebnisse gespeichert in: .\Ausgabe_Zugangsdaten_20250512_143022.csv
Zusammenfassung: 3 erfolgreich, 0 fehlgeschlagen (gesamt 3).
Eingabedatei wurde erfolgreich umbenannt zu: Eingabe_Benutzer_20250512_143022.csv
```

---

## Dateinamen-Konventionen

Nach erfolgreicher Verarbeitung werden Zeitstempel im Format `yyyyMMdd_HHmmss` angehängt:

| Datei | Vorher | Nachher |
|---|---|---|
| Eingabe-CSV | `Eingabe_Benutzer.csv` | `Eingabe_Benutzer_20250512_143022.csv` |
| Ausgabe-CSV | `Ausgabe_Zugangsdaten.csv` | `Ausgabe_Zugangsdaten_20250512_143022.csv` |

Beide Dateien erhalten **denselben Zeitstempel**, um Eingabe und Ergebnis eindeutig zuzuordnen.

---

## Fehlerbehandlung

| Situation | Verhalten |
|---|---|
| Eingabe-CSV nicht vorhanden | Beispieldatei wird erstellt, Skript beendet sich mit Hinweis |
| Eingabe-CSV leer | Skript bricht mit Hinweis ab, keine Ausgabe-CSV wird erstellt |
| Pflichtfelder fehlen in der CSV | Fehlermeldung mit Liste der fehlenden Spalten, Skript bricht ab |
| API-Aufruf schlägt fehl (Netzwerk, Auth, Timeout) | Fehlerzeile in Ergebnis-CSV, Verarbeitung der restlichen Zeilen wird fortgesetzt |
| API-Antwort hat unbekanntes Format | Fehlerzeile in Ergebnis-CSV, Verarbeitung der restlichen Zeilen wird fortgesetzt |

---

## Bekannte Einschränkungen

- **Umlaute im Comment-Feld** werden von der LANCOM-API grundsätzlich nicht unterstützt. Entsprechende Zeichen sollten in der Eingabe-CSV vermieden werden.
- **`Unit`-Werte müssen englisch sein:** `Day`, `Hour`, `Minute`. Deutsche Werte wie `Tag` oder `Stunde` werden vom LANCOM-Gerät nicht erkannt und führen zur Rückgabe einer interaktiven HTML-Eingabemaske statt des erwarteten Datenblocks (`FAILED (Format)`).
- **`NbGuests`** ist derzeit im Skript auf `1` hardcodiert und wird nicht aus der CSV gelesen. Für abweichende Werte muss der Aufruf in der Schleife angepasst werden.
- **`active`-Parameter** ist in der offiziellen LANCOM-Dokumentation nicht aufgeführt. Das LANCOM-Gerät ignoriert unbekannte Parameter laut Doku still, d.h. der Parameter hat möglicherweise keine Auswirkung.
- Das Skript unterstützt ausschließlich die Aktion `addpbspotuser`. Andere Aktionen (`delpbspotuser`, `editpbspotuser`) erfordern eine Erweiterung der Funktion `Invoke-CmdPbSpotUser`.
- Die API-Antwort des LANCOM-Geräts wird per RegEx geparst, da sie kein valides JSON zurückliefert. Änderungen am LANCOM-Firmware-Antwortformat können eine Anpassung der Patterns erfordern.

---

## Changelog

### v1.5

- **BUGFIX:** Die SSID in der Ausgabe-CSV wurde URL-kodiert zurückgegeben (z.B. `LANCOM%20VISITOR` statt `LANCOM VISITOR`). Behoben durch `[System.Uri]::UnescapeDataString()` nach dem Regex-Matching der API-Antwort.
- **`VolumeBudget`-Typ:** Von `[int]` auf `[string]` geändert. Dadurch können LANCOM-Suffixe (`k`, `m`, `g`) direkt in der CSV verwendet werden (z.B. `1m` für 1 MB, `500k` für 500 kB). Ohne Suffix entspricht die Angabe weiterhin Byte.

### v1.4

- **BUGFIX (Hauptursache für FAILED (Format)):** Der `Unit`-Wert in der CSV muss englisch sein (`Day`, `Hour`, `Minute`). Der deutsche Wert `Tag` wird vom LANCOM-Gerät nicht erkannt und führt zur Rückgabe einer interaktiven HTML-Eingabemaske statt des Datenblocks.
- **REVERT v1.3:** `validper` wird wieder für alle `ExpiryType`-Werte an die URL angehängt. Der v1.3-Fix war falsch — die tatsächliche Ursache war `Tag` statt `Day`, nicht der `validper`-Parameter.
- **REVERT v1.2 (Beispiel-CSV):** Beispiel-CSV-Wert `Unit` von `Tag` zurück auf `Day` korrigiert. Die Änderung in v1.2 war der eigentliche Auslöser des Problems.
- Regex-Pattern auf SingleLine-Modus (`(?s)`) umgestellt, damit mehrzeilige `{ SSID:... }`-Blöcke korrekt erkannt werden.

### v1.2

- **REVERT:** Das `+` zwischen `unit`/`runtime` und `expirytype`/`validper` in der URL ist laut LANCOM-Dokumentation die korrekte und erwartete Syntax.
- **BUGFIX:** Parametername `maxconclogins` korrigiert zu `maxconclogin` (ohne `s`) gemäß LANCOM-Dokumentation.
- **BUGFIX:** Parametername `bandwidthprofile` korrigiert zu `bandwidthprof` (ohne `ile`) gemäß LANCOM-Dokumentation.

### v1.1

- **BUGFIX:** Fehlende URL-Kodierung für Sonderzeichen und Leerzeichen in `Comment` und `SSID`. Behoben mit `[System.Uri]::EscapeDataString()`.
- **BUGFIX:** Schlägt ein API-Aufruf fehl (`$null`-Rückgabe), wurde bisher keine Fehlerzeile in die Ergebnis-CSV geschrieben. Behoben durch explizite Fehlererfassung nach jedem API-Aufruf.
- Explizite `[int]`-Konvertierung der Integer-Felder aus der CSV (CSV liefert grundsätzlich Strings).
- `Write-Progress` für Fortschrittsanzeige bei großen Benutzerlisten hinzugefügt.
- Abschlusszusammenfassung (Erfolge / Fehler / Gesamt) am Ende der Verarbeitung.
- Validierung der Pflichtfelder der CSV vor dem Start der Verarbeitung.
- Leere CSV wird sauber abgefangen.
- Parameter `-SkipCertificateCheck` ist nun konfigurierbar statt intern hardcodiert (`$true`).

### v1.0

- Initiale Version mit Basis-Funktionalität: CSV-Einlesen, API-Aufruf, Ergebnis-CSV, Umbenennung der Eingabedatei.
