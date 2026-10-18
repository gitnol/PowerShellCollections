# Datenschutz & Compliance – PowerShellCollections

**Rahmen:** Für das Repository selbst kein formaler Rahmen — es ist öffentlich und enthält nur Code, Doku und
fiktive Beispielwerte. Die **Ausführung** der Skripte verarbeitet dagegen personenbezogene und vertrauliche
Betriebsdaten der jeweiligen Organisation; dort gelten DSGVO und deren interne Regeln (z. B. ISMS/TISAX). Diese
Datei beschreibt, welche Daten die Skripte berühren und wie damit umzugehen ist.

---

## Datenklassen (kanonisch)

Alle Overlays (`llm-integration`, `document-intelligence`, `compliance-tisax`) verwenden diese vier Klassen und
ergänzen nur ihre Erlaubnis-Matrix bzw. das TISAX-Mapping.

| Klasse | EN | Beispiele | An externe Dienste / Cloud-Modelle |
|---|---|---|---|
| Öffentlich | public | veröffentlichte Texte, Demo-Daten | erlaubt |
| Intern | internal | allgemeine Geschäftskommunikation, interne Prozessdokumente | nach Prüfung des Dienstes (Checkliste unten) |
| Vertraulich | confidential | Kunden- und Lieferantendaten, Verträge, Preise, Strategie | **nur mit dokumentierter Freigabe und Auftragsverarbeitungsvertrag (AVV)** |
| Streng vertraulich | restricted | Personalakten, besondere Kategorien personenbezogener Daten, Konstruktions-/Tarifgeheimnisse | **nein** — nur lokal/On-Prem; Ausnahme nur mit ausdrücklichem DSGVO-/TISAX-Sign-off |

Zuordnung im Projekt:

| Daten | Klasse |
|---|---|
| Code, `docs/` (ohne `docs/local/`), Beispielwerte | Öffentlich |
| Interne Hostnamen, Domänen, Pfade, Versionsstände (`docs/local/`, `forbidden-patterns.local.txt`) | Intern |
| AD-Inventar, Gruppenmitgliedschaften, Postfachrechte, Software-/Hardware-Inventar, Lizenznutzung | Vertraulich |
| Anmelde-/Sperr-Events mit Quell-IP, Aktivitäts-Timelines, Sitzungs- und Leerlaufzeiten, Ergebnisse der Passwortprüfung | Streng vertraulich (Verhaltens-/Leistungsdaten von Beschäftigten bzw. Sicherheitsschwächen einzelner Konten) |
| BitLocker-Wiederherstellungskennwörter, Zugangsdaten, PFX-/Schlüsselmaterial | Streng vertraulich |

---

## 1. Lokale Verarbeitung / Datenisolation

- Die Skripte verarbeiten Daten **lokal** auf dem Verwaltungs-PC bzw. auf den Zielrechnern der eigenen Domäne.
- Datenabflüsse nach außen gibt es nur gezielt: Microsoft Graph (Benutzerfoto nach Entra ID), Exchange Online
  (optional), Abruf öffentlicher Webseiten (`Test-WebChange.ps1`, MailStore-Online-Hilfe, Wireshark-OUI-Liste),
  E-Mail-Versand des Ping-Monitors über den konfigurierten SMTP-Server.
- Keine Air-Gap-Anforderung. Kein Skript sendet Ergebnisdaten an Cloud-Modelle oder Dritte.

---

## 2. Minimalprinzip (Data Minimization)

- AD-Abfragen nur mit den benötigten Attributen (`-Properties Description` statt `-Properties *`; Vorbild
  `Get-BitLockerStatus.ps1`, `docs/BACKLOG.md` Abschnitt 2).
- Anmelde- und Aktivitätsauswertungen nur anlassbezogen (Störung, Sicherheitsvorfall), nicht zur
  Leistungskontrolle; Zeitraum und Personenkreis eng wählen.
- Wiederherstellungskennwörter und Passwortprüf-Ergebnisse nicht exportieren; Anzeige nur auf ausdrücklichen
  Wunsch (`docs/BACKLOG.md` → Technische Schuld).
- An Graph wird nur das Foto übertragen.

---

## 3. Output-Dateien und Speicherorte

| Datei | Inhalt | Sensitivität |
|-------|--------|-------------|
| CSV/JSON-Exporte der Inventar-, Gruppen- und Postfachskripte (Pfad vom Aufrufer) | Benutzer, Rechner, Rechte | Vertraulich |
| Exporte der Anmelde-/Aktivitätsskripte (`logon-events/`, `activity-timeline/`, `Trace-ProcessStartStop.ps1` → JSON) | personenbezogene Zeitstempel, Quell-IPs, Prozessstarts | Streng vertraulich |
| `Out-GridView` von `Get-BitLockerStatus.ps1` | Wiederherstellungskennwörter | Streng vertraulich |
| `C:\Install\shadowcopy.log`, `C:\Install\shadowcopy_task.log` | Laufprotokoll der Schattenkopien | Intern |
| `state.json` (`Test-WebChange.ps1`) | Hashes überwachter Seiten | Intern |
| Zertifikats-Exporte (`exportPath`, z. B. PFX/PEM) | privater Schlüssel | Streng vertraulich |
| `INDEX.md` | Skriptliste | Öffentlich |

- Exporte nur in Verzeichnisse mit restriktiven Rechten (nur Administratoren), nie in Freigaben für alle und nie
  ins Repo-Arbeitsverzeichnis ohne `.gitignore`-Eintrag.
- `.gitignore`: global `*.log`, `*.pfx`, `*.pem`, `*.key`, `config.ps1`, `*.secret`, `/docs/local/`; je Themenordner
  CSV-/JSON-Ausgaben (`scripts/network/lancom/`, `scripts/security/certificates/`, `scripts/monitoring/web-changes/`).

---

## 4. Zugriffsschutz

- Ausführen dürfen die Skripte nur Administratoren mit den für die jeweilige Aufgabe delegierten Rechten
  (`security/AUTHENTICATION.md`).
- Least Privilege: Leseskripte unter einem Konto ohne Domänen-Admin-Rechte ausführen; nur zustandsändernde Skripte
  brauchen erhöhte Rechte (`#Requires -RunAsAdministrator` wo nötig).
- Der Repo-Klon auf dem Verwaltungs-PC ist nur für Administratoren beschreibbar (`security/THREAT_MODEL.md`
  Bedrohung 4).
- Secret-Speicherung und Rotation: siehe `docs/operations/SECRETS_MANAGEMENT.md`

---

## 5. Datenhaltung / Retention

- Die Skripte selbst halten keine Daten; Exporte entstehen auf Anforderung und werden **vom Aufrufer** gelöscht,
  sobald der Anlass erledigt ist (Richtwert: Auswertungen mit Personenbezug nach Abschluss des Vorgangs, spätestens
  nach 30 Tagen; abweichende interne Fristen haben Vorrang).
- Logdateien unter `C:\Install\` werden fortgeschrieben (`Add-Content`/`-Append`), nicht rotiert — bei Bedarf
  manuell kürzen.
- `Test-WebChange.ps1` überschreibt `state.json` bei jedem Lauf.
- Verantwortlich für das Aufräumen ist, wer das Skript ausführt.

---

## 6. Compliance-Checkliste für neue Features

- [ ] Keine neuen persistenten Speicher ohne Retention-Konzept
- [ ] Kein Logging von sensiblen Inhalten (Passwörter, Nutzdaten, PII)
- [ ] Externe Services nur nach Compliance-Prüfung einführen
- [ ] Personenbezogene Auswertungen (Anmeldungen, Aktivität, Sitzungen): Zweck in `.DESCRIPTION`, Zeitraum und
      Personenkreis als Parameter, keine Vollabfrage als Default
- [ ] Wiederherstellungskennwörter, Passwortprüf-Ergebnisse und Schlüsselmaterial nie in Dateien oder Logs
- [ ] Beispielwerte nur fiktiv (`docs/CONVENTIONS.md` §11)
