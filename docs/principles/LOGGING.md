# Logging Strategy

## Regel

Logs sind das einzige Fenster in den Systemzustand eines laufenden Prozesses.
Jeder Log-Eintrag muss ohne Kontextwissen verständlich und filterbar sein.

## Konkrete Vorgaben

- **Level DEBUG:** Detaillierter Datenfluss (z.B. "Datei X gelesen, Hash: Y")
- **Level INFO:** Fachliche Meilensteine (z.B. "Dokument X erfolgreich verarbeitet")
- **Level WARNING:** Erwartete, aber behandelte Probleme (z.B. "Service Timeout, Versuch 1/3")
- **Level ERROR:** Unerwartete Fehler – muss zwingend den Stacktrace enthalten (z. B. Python `exc_info=True`,
  .NET `LogError(ex, …)`)
- **Kontext:** Jeder Eintrag muss IDs, Dateinamen oder Bezeichner enthalten.
  "Verarbeitung fehlgeschlagen" ist verboten.
  "Verarbeitung für Datei 'X.pdf' fehlgeschlagen" ist korrekt.
- Konsolenausgaben über `print()` sind für interaktive CLI-Tools akzeptabel.
  Bei automatisiertem Betrieb (Scheduler, Service) muss das Logging-Framework verwendet werden.

## Verwandt

- [[FAIL_FAST]]
- [[UNTRUSTED_DOCUMENT_CONTENT]]

## Projektspezifisch

<!-- Hier beim Befüllen ersetzen. Maßgeblich für die Update-Klassifizierung ist
     der Vergleich gegen die alte Template-Version (ALTES_PROJECT_AKTUALISIEREN.md,
     Schritt 2c/3): LOGGING.md ist konstruktionsbedingt immer Kategorie C. -->


- **Mittel:** Kein gemeinsames Logging-Framework. Interaktive Skripte schreiben auf die Konsole (`Write-Host` für
  Hinweise, Objekte in die Pipeline); fünf Skripte definieren eine eigene `Write-Log` mit drei verschiedenen
  Verhaltensweisen — bewusst nicht zusammengeführt, weil zwei davon als Scriptblock auf Zielrechnern ohne
  `modules/` laufen (`docs/BACKLOG.md` Abschnitt 4). PRTG-Sensoren „loggen" ausschließlich über das
  `<prtg>`-Dokument auf stdout. `New-EventLogSource*.ps1` legen eine Eventlog-Quelle für ein anderes Projekt an (eines
  schreibt dabei einen Testeintrag); ansonsten schreibt die Sammlung nicht ins Eventlog.
- **DEBUG-Modus:** `-Verbose` (`Write-Verbose`) bei Skripten mit `[CmdletBinding()]`; kein eigener Schalter.
- **Nicht loggen:** Passwörter, Tokens, BitLocker-Wiederherstellungskennwörter, Ergebnisse der Passwortprüfung,
  vollständige Anmelde-/Aktivitätsdaten von Personen (`security/DATA_HANDLING.md`).
- **Ziele:** Konsole bzw. `Out-GridView` (interaktiv); Dateien unter `C:\Install\` (Schattenkopien, Altbestand mit
  festem Pfad); Exportdateien, deren Pfad der Aufrufer wählt; PRTG-stdout. Logdateien werden fortgeschrieben, nicht
  rotiert.
