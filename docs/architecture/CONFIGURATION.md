# Konfiguration – PowerShellCollections

Wo Werte herkommen, in welcher Reihenfolge sie überschreiben, und wie sie
validiert werden. Verbindet sich mit den Prinzipien [[EXPLICIT_OVER_IMPLICIT]]
und [[FAIL_FAST]].

Die Sammlung hat **keine zentrale Konfiguration**. Jedes Skript bekommt seine Werte selbst; diese Datei
beschreibt die erlaubten Quellen und die wenigen Skripte mit Konfigurationsdatei.

---

## Quellen-Hierarchie (Präzedenz, höchste zuerst)

1. **Parameter** des Skripts bzw. der Funktion (`-ComputerName`, `-ConfigPath`, …)
2. **Konfigurationsdatei des Themenordners**, wo ein Skript eine vorsieht (JSON/TXT neben dem Skript, lokal,
   per `.gitignore` des Themenordners ausgeschlossen; versioniert nur `*.example.json`)
3. **Code-Defaults** (Parameter-Defaults, `$script:`-Konstanten am Skriptbeginn)

Umgebungsvariablen sind keine vorgesehene Quelle. Altbestand mit „Konfiguration als Variable im Skriptkopf, vor dem
Lauf von Hand anpassen" (z. B. `scripts/security/passwords/Test-ADUserWeakPassword.ps1`) wird beim Anfassen auf
Parameter umgestellt (`docs/CONVENTIONS.md` §2, `TODO.md` I6).

Niedrigere Quelle wird durch höhere **überschrieben**, nicht ergänzt
(außer explizit dokumentiert für Listen/Mappings, z. B. `defaults` + Eintrag in `config.example.json` der
Zertifikatsskripte).

---

## Validierung beim Laden

- Parameter werden über Validierungsattribute geprüft (`[ValidateRange()]`, `[ValidateSet()]`,
  `[ValidateNotNullOrEmpty()]`) — vor jedem Zugriff auf AD, Netz oder Zielrechner.
- Konfigurationsdateien werden **einmal** zu Beginn gelesen; fehlt die Datei oder ist sie ungültig, bricht das
  Skript mit klarer Meldung ab (Beispiel: `New-Certificate.ps1` prüft `-ConfigPath` per `Test-Path`).
- PowerShell: `Set-Variable -Option ReadOnly` schützt nur die Variable — Inhalte zusätzlich
  unveränderlich halten (z. B. `[System.Collections.ObjectModel.ReadOnlyDictionary]`)
- **Nach dem Laden darf kein ungültiger Zustand mehr möglich sein** (Fail Fast).
- Typkonvertierung (str → int/bool/Path/Uri) findet **beim Laden** statt,
  nicht bei jedem Lesezugriff.

---

## Secrets gehören NICHT in normale Konfigurationsdateien

- Zugangsdaten kommen interaktiv (`Get-Credential`, `Read-Host -AsSecureString`) oder aus einem Credential Store
  (`architecture/CREDENTIAL_STRATEGY.md`, `docs/operations/SECRETS_MANAGEMENT.md`).
- Versionierte Konfigurationsdateien enthalten **nie** Secrets. Sonderfall Zertifikate: `config.example.json`
  hat ein Feld `exportPassword` (im Beispiel `null`); eine lokale `config.json` mit gesetztem Wert ist ein
  Klartext-Secret auf der Platte — besser leer lassen und interaktiv abfragen.
- `config.ps1`, `*.secret`, `*.pfx`, `*.pem`, `*.key` stehen in der Root-`.gitignore` (siehe `docs/BOOTSTRAP.md`).

---

## Konfigurationsobjekt — Verwendung

- Funktionen erhalten Konfigwerte als **Parameter** (Default-Argument),
  nicht über globalen Zugriff. Siehe [[EXPLICIT_OVER_IMPLICIT]].
- Keine `$global:`-Konfiguration (Altbestand: `$Global:ModuleConfig` im Ping-Monitor, `$global:ouilist` in
  `Get-ArubaMacTable.ps1`); neue Module halten Zustand `$script:`-skopiert.

---

## Konfigurations-Tabelle (Pflicht ausfüllen)

Nur Skripte mit Konfigurationsdatei oder Zustandsdatei; alle übrigen Werte sind Parameter (siehe
Comment-Based Help bzw. `INDEX.md`).

| Schlüssel | Typ | Default | Quelle(n) | Beschreibung |
|---|---|---|---|---|
| `-ConfigPath` (`New-Certificate.ps1`) | `string` | `config.json` im Skriptordner | Parameter / FILE | Zertifikatsdefinitionen (`defaults` + `certificates[]`), Format laut `config.example.json` |
| `-ConfigPath` (`Set-VMwareCertificate.ps1`) | `string` | `vmware-config.json` im Skriptordner | Parameter / FILE | vCenter-/ESXi-Topologie für die Zertifikatsverteilung, Format laut `vmware-config.example.json` |
| `-EingabeDatei` (`Test-WebChange.ps1`) | `string` | `urls.txt` | Parameter / FILE | Liste der zu überwachenden Webadressen |
| `-StateDatei` (`Test-WebChange.ps1`) | `string` | `state.json` | Parameter / FILE (gitignored) | Hash-Stand des letzten Laufs |
| SMTP-Einstellungen (`Win10PingMonitor.psm1`) | Hashtable | Platzhalter im Modul | `Set-MonitoringConfiguration` | Mailserver, Port, Absender/Empfänger; Zugangsdaten interaktiv per `Get-Credential` |
| OUI-Liste (`Get-ArubaMacTable.ps1`) | JSON-Datei | fester Pfad unter `C:\install\` | FILE | Herstellerliste (Wireshark `manuf.json`), vorab manuell herunterzuladen |

---

## Anti-Pattern

- **Werte direkt aus `$env:VAR` mitten in der Logik lesen.** Versteckte Abhängigkeit.
- **Konfiguration zur Laufzeit mutieren** oder als `$global:` ablegen. Immutabilität bricht.
- **Magic Defaults im Code** (fester Pfad wie `C:\Install\…` an mehreren Stellen) statt eines Parameters mit
  Default.
- **„Vor dem Lauf diese Variablen anpassen"** im Skriptkopf — wird beim nächsten `git pull` überschrieben oder
  versehentlich mit echten Werten committet.

---

## Pflege

Trigger (siehe `KICKOFF.md` Phase 3a): neue Konfig-Quelle / neuer Schlüssel /
geänderte Präzedenz → diese Datei eintragen, Validierung implementieren,
Tabelle aktualisieren.
