# PROGRESS – testeingabe.csv Entwicklung

## Ziel
Vollständige Test-CSV für alle Parameter der LANCOM `cmdpbspotuser`-API,
um alle Kombinationen und Abhängigkeiten abzudecken.

---

## Analysierte Quellen
- `Create-PublicSpotUsers.ps1` v1.4
- `README.md`
- LANCOM API-Dokumentation (vom Nutzer bereitgestellt)

---

## CSV-Parameter (Pflichtfelder des Skripts)

| CSV-Spalte       | Typ     | Gültige Werte / Hinweise |
|------------------|---------|--------------------------|
| `Comment`        | String  | Kein Umlaut, max 191 Zeichen |
| `Unit`           | String  | `Day`, `Hour`, `Minute` (nur englisch!) |
| `Runtime`        | Integer | Laufzeit in gewählter Einheit |
| `ExpiryType`     | String  | `absolute`, `relative`, `both`, `none` |
| `ValidPer`       | Integer | Tage; nur bei `both` relevant als absolutes Maximaldatum |
| `SSID`           | String  | Netzwerkname, Sonderzeichen werden URL-kodiert |
| `MaxConcLogins`  | Integer | 0 = unbegrenzt; erfordert intern `multilogin` (ist immer gesetzt) |
| `BandwidthProfile` | Integer | Zeilennummer in LANCOM-Tabelle; 0 = keine Begrenzung |
| `TimeBudget`     | Integer | Minuten; 0 = LANCOM-Default |
| `VolumeBudget`   | Integer | Byte; 0 = LANCOM-Default (**Suffix k/m/g funktioniert NICHT**, da [int]-Cast im Skript!) |
| `Active`         | Integer | 1 = aktiv, 0 = gesperrt |

---

## Hardcoded-Werte im Skript (nicht konfigurierbar per CSV)

| Parameter      | Wert             | Bemerkung |
|----------------|------------------|-----------|
| `action`       | `addpbspotuser`  | Nur Erstellen unterstützt |
| `multilogin`   | immer gesetzt    | Flag ohne Wert; ermöglicht MaxConcLogins > 1 |
| `print`        | immer gesetzt    | Automatischer Voucher-Ausdruck |
| `printcomment` | immer gesetzt    | Kommentar erscheint auf Voucher |
| `casesensitive`| `0`              | Benutzername NICHT case-sensitive |
| `NbGuests`     | `1`              | Nur ein Benutzer pro Zeile; bekannte Einschränkung (README) |

---

## Parameter-Abhängigkeiten

### ExpiryType ↔ ValidPer
| ExpiryType  | ValidPer-Bedeutung                            | Empfohlener Testwert |
|-------------|-----------------------------------------------|----------------------|
| `absolute`  | Wird übergeben, aber bedeutungslos laut Doku  | 0 oder identisch zu Runtime |
| `relative`  | Wird übergeben, aber bedeutungslos laut Doku  | 0 |
| `both`      | **Pflicht**: maximale Gültigkeit in Tagen (absolutes Enddatum) | > 0 |
| `none`      | Wird übergeben, bedeutungslos                 | 0 |

### MaxConcLogins ↔ multilogin
- `multilogin` ist im Skript **immer** gesetzt → MaxConcLogins wirkt immer
- `MaxConcLogins=0` = unbegrenzte gleichzeitige Logins
- `MaxConcLogins=1` = Gerät exklusiv, kein Mehrfach-Login de facto

### Unit ↔ Runtime
- Werden als `unit=Day+runtime=7` kombiniert (LANCOM Sub-Parameter-Syntax)
- Unit-Werte **müssen englisch** sein: falscher Wert → FAILED (Format)

---

## Bekannte Inkonsistenz / offene Fragen

1. ~~**VolumeBudget-Suffix:** `[int]`-Cast verhinderte Suffix-Werte.~~
   **Behoben:** `VolumeBudget` ist nun `[string]` in Funktion und Aufruf.
   Werte wie `1m`, `500k`, `2g` werden direkt an die API weitergereicht.

2. **active-Parameter:** Laut README in offizieller LANCOM-Doku nicht aufgeführt.
   LANCOM ignoriert unbekannte Parameter still → möglicherweise wirkungslos.

3. **NbGuests hardcoded=1:** Mehrfach-Benutzer-Anlage per CSV nicht möglich.
   Für Tests irrelevant, aber potenzielle Feature-Anforderung.

---

## Testfall-Matrix (testeingabe.csv)

| Zeile | Zweck | Besonderheit |
|-------|-------|--------------|
| 1 | Basis-Test | Day/1/absolute, alle Defaults |
| 2 | Unit=Hour | Stundenbasis, BandwidthProfile=0 |
| 3 | Unit=Minute + relative | Minutenbasis, relative Gültigkeit, TimeBudget gesetzt |
| 4 | ExpiryType=both | ValidPer>0 als absolutes Maximaldatum |
| 5 | ExpiryType=none | Kein Ablauf, MaxConcLogins=0 (unbegrenzt) |
| 6 | MaxConcLogins=0 | Unbegrenzte gleichzeitige Logins |
| 7 | TimeBudget=60 | Zeitbudget 60 Minuten |
| 8 | VolumeBudget=1048576 | ~1 MB in Byte (Suffix-Workaround) |
| 9 | Active=0 | Gesperrtes Konto |
| 10 | SSID mit Leerzeichen | URL-Kodierung testen |
| 11 | Kombination TimeBudget+VolumeBudget | Beide Budgets gleichzeitig |
| 12 | Langer Kommentar | Nahe 191-Zeichen-Limit |

---

## Status

- [x] Quellcode und README analysiert
- [x] Parameter-Abhängigkeiten ermittelt
- [x] testeingabe.csv erstellt
- [x] PROGRESS.md angelegt
- [x] VolumeBudget-Typ auf String geändert (Suffix k/m/g nun möglich)
- [x] testeingabe.csv Zeile 8 auf Suffix-Wert `1m` aktualisiert
- [x] Testlauf erfolgreich: alle 12 Testfälle `OK`, 0 Fehler
- [x] BUGFIX SSID-Dekodierung: API gibt `LANCOM%20VISITOR` zurück → UnescapeDataString() eingefügt
- [x] Skript auf v1.5 angehoben, README.md + PROGRESS.md aktualisiert

## Testergebnisse (Ausgabe_Zugangsdaten_20260513_105738.csv)

| Testfall | AccountEnd | Lifetime | Befund |
|---|---|---|---|
| Test_Day_1_Absolute | 05/14/2026 | 1 Day(s) | ✅ Korrekt |
| Test_Hour_4_Absolute_NoBWProfile | 05/13/2026 14:57 | 4 Hour(s) | ✅ Korrekt |
| Test_Minute_120_Relative_TimeBudget | FirstLogin + 2 Hour(s) | 2 Hour(s) | ✅ 120 min = 2h |
| Test_Both_ValidPer14 | 05/27/2026 | 30 Day(s) | ✅ Absolute Grenze = +14 Tage |
| Test_None_Expiry_Unlimited | unlimited | (leer) | ✅ Kein Ablauf |
| Test_MaxConcLogins_Zero | 05/20/2026 | 7 Day(s) | ✅ Korrekt |
| Test_TimeBudget_60min | FirstLogin + 1 Day(s) | 1 Day(s) | ✅ Budget nicht in Antwort |
| Test_VolumeBudget_1MB_Suffix | FirstLogin + 1 Day(s) | 1 Day(s) | ✅ Suffix `1m` akzeptiert |
| Test_Active_Zero_Gesperrt | 05/14/2026 | 1 Day(s) | ⚠️ `active=0` ohne Wirkung |
| Test_SSID_With Space | 05/14/2026 | 1 Day(s) | ⚠️ War BUGFIX-Auslöser (v1.5) |
| Test_Both_Budget_Kombi | 05/16/2026 | 2 Hour(s) | ✅ ValidPer=3 Tage korrekt |
| Test_Langer Kommentar… | 05/20/2026 | 7 Day(s) | ✅ Korrekt |
