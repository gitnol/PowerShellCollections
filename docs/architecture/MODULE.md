# PowerShell-Modul – PowerShellCollections

Aufbau, Manifest, Tests und Verteilung des gemeinsamen Moduls `PSCollections.Connectivity` (Erreichbarkeitsprüfung
für viele Rechner). Gilt zusammen mit `CONVENTIONS.md` (Exportliste und Modulablage: §3 „Dateiorganisation";
Seiteneffekte beim Import: §4 „Prozessweite Side-Effects"), `docs/STRUCTURE.md` („Module liegen bei ihrer
Fachdomaene") und `architecture/DEPENDENCIES.md`.

Nur dieses Modul liegt unter `modules/` und hat ein Manifest. Die übrigen `.psm1` der Sammlung
(`OSBiz.psm1`, `PRTG.Dsls.psm1`, `Win10PingMonitor.psm1`) liegen bei ihrer Fachdomäne, haben kein Manifest und
fallen nicht unter diese Datei; `third-party/` ist ausgenommen (Fremdcode).

Abweichungen des Codes von den Regeln unten sind mit **offen (I7)** markiert (`docs/TODO.md` I7).

---

## Aufbau

```text
modules/PSCollections.Connectivity/
├── PSCollections.Connectivity.psd1   # Manifest: Version, Mindestversion, Exportliste
└── PSCollections.Connectivity.psm1   # Strict Mode, beide Funktionen, Export-ModuleMember (offen, I7)
```

| Funktion | Laufzeit | Arbeitsweise |
|---|---|---|
| `Test-ConnectionInParallel` | PowerShell 7 (`ForEach-Object -Parallel`) | ein `Test-Connection` je Ziel, Ergebnis `ComputerName`, `Online`, `IP`, `LatencyMs`, `Status` |
| `Get-ComputerOnlineStatus` | Windows PowerShell 5.1 und PowerShell 7 (Hintergrundjobs) | eigene Jobs mit Zeitlimit, bricht nur eigene Jobs ab, räumt sie in `finally` weg; Ergebnis `ComputerName`, `Online`, `IP` |

Abweichung von der Template-Vorlage: keine Ordner `Public/`/`Private/` — beide Funktionen sind öffentlich, private
Helfer gibt es nicht. Kommen Helfer hinzu, gilt die Vorlage (`Public/` eine Funktion je Datei, `Private/` nie
exportiert, die `.psm1` lädt beide per Schleife).

- **Strict Mode:** `Set-StrictMode -Version 3.0` am Anfang der `.psm1` (`CONVENTIONS.md` §2). Der Code setzt heute
  `-Version Latest` — **offen (I7)**.
- Der Import hat keine Wirkung außerhalb des Moduls: kein `$env:PATH`, keine TLS-Einstellung, keine Ausgabe
  (`CONVENTIONS.md` §4). Heute eingehalten — die `.psm1` definiert beim Import nur die beiden Funktionen.
- **Importiert wird immer das Manifest.** Nur das Manifest filtert die Exporte und prüft die Mindestversion; wer die
  `.psm1` direkt importiert, umgeht beides. Alle vier Aufrufer laden das Manifest über den Suchlauf nach oben
  (Muster: `docs/STRUCTURE.md`):
  `scripts/applications/excel/ConvertFrom-ExcelClipboard.ps1`, `scripts/applications/teamviewer/Set-TeamViewerAccess.ps1`,
  `scripts/security/bitlocker/Get-BitLockerStatus.ps1`, `scripts/security/secure-boot/Test-MultipleHostsSecureBoot.ps1`.
- Code, der als Scriptblock auf dem Zielrechner läuft, darf das Modul nicht voraussetzen
  (`architecture/REMOTE_EXECUTION.md`).

---

## Manifest

| Schlüssel | Regel | Stand im Code |
|---|---|---|
| `ModuleVersion` | Drei Stellen nach SemVer: Major bei Bruch (Funktion entfernt oder umbenannt, Pflichtparameter oder Rückgabe geändert), Minor bei neuer Funktion, Patch sonst. **Einzige Quelle der Version.** | `1.0.0` |
| `GUID` | Einmal erzeugt, nie ändern. | gesetzt |
| `RootModule` | `'PSCollections.Connectivity.psm1'` | eingehalten |
| `PowerShellVersion` | Mindestversion; der Import bricht darunter mit klarer Meldung ab. | `5.1` — passt zu `Get-ComputerOnlineStatus`; `Test-ConnectionInParallel` braucht PowerShell 7 und scheitert unter 5.1 erst beim Aufruf (Parameter `-Parallel` unbekannt) |
| `CompatiblePSEditions` | `@('Desktop', 'Core')` (beide Editionen werden unterstützt). | fehlt — **offen (I7)** |
| `FunctionsToExport` | Explizite Liste, **nur hier** (`CONVENTIONS.md` §3). | explizit; zusätzlich `Export-ModuleMember` mit eigener Liste in der `.psm1` — **offen (I7)** |
| `CmdletsToExport`, `VariablesToExport`, `AliasesToExport` | `@()` — nicht weglassen und nicht `'*'`. | eingehalten |
| `RequiredModules` | Mit Version, zugleich in `architecture/DEPENDENCIES.md`. | keine (nur eingebaute Cmdlets) |
| `PrivateData.PSData.ReleaseNotes` | Kurz, mit Verweis auf `docs/CHANGELOG.md`. | fehlt — **offen (I7)** |

`Author`, `Description` und `PrivateData` sind öffentliche Metadaten: Es gelten die Interna-Regeln aus
`docs/CONVENTIONS.md` §11 (heute eingehalten).

---

## Modultests

Gehören zu Gate 4 (`CONVENTIONS.md` §9) und laufen ohne externe Dienste. Heute gibt es keinen Modultest —
**offen (I7)**; die Verhaltenstests (Pipeline-Eingabe, fremde Jobs) plant `docs/TODO.md` I4. Ablage nach
`testing/UNIT_TESTS.md` (Spiegel des Codepfads):

```powershell
# tests/modules/PSCollections.Connectivity/PSCollections.Connectivity.Module.Tests.ps1
BeforeAll {
    $script:Manifest = Join-Path $PSScriptRoot '..\..\..\modules\PSCollections.Connectivity\PSCollections.Connectivity.psd1'
    $script:ModulName = [System.IO.Path]::GetFileNameWithoutExtension($script:Manifest)
}

Describe 'Modulvertrag' {
    It 'Manifest ist gueltig' {
        { Test-ModuleManifest -Path $script:Manifest -ErrorAction Stop } | Should -Not -Throw
    }
    It 'exportiert genau die vereinbarten Funktionen' {
        $modul = Import-Module $script:Manifest -PassThru -Force
        try {
            @($modul.ExportedFunctions.Keys | Sort-Object) |
                Should -Be @('Get-ComputerOnlineStatus', 'Test-ConnectionInParallel')
        } finally {
            Remove-Module $modul
        }
    }
    It 'filtert jede Exportart ausdruecklich und ohne Platzhalter' {
        $daten = Import-PowerShellDataFile $script:Manifest
        foreach ($schluessel in 'FunctionsToExport', 'CmdletsToExport', 'VariablesToExport', 'AliasesToExport') {
            $daten.ContainsKey($schluessel) | Should -BeTrue -Because "ohne $schluessel filtert das Manifest nicht"
            @($daten[$schluessel]) -contains '*' | Should -BeFalse -Because "$schluessel enthaelt '*'"
        }
    }
    It 'Import aendert PATH nicht' {
        $vorher = $env:PATH
        Import-Module $script:Manifest -Force
        Remove-Module $script:ModulName
        $env:PATH | Should -BeExactly $vorher
    }
}
```

Weitere Zustände, die das Modul beim Import nicht verändern darf, als eigene Fälle ergänzen (Liste in
`CONVENTIONS.md` §4).

---

## Installation und Verteilung

Das Modul wird heute nicht installiert: Die Aufrufer laden es aus dem Repo-Klon (Suchlauf nach oben,
`docs/STRUCTURE.md`). Wer es doch in einen Modulpfad installiert:

- **Versionierter Ordner:** `<Modulpfad>\PSCollections.Connectivity\<ModuleVersion>\`. Eine unversionierte Kopie
  veraltet unbemerkt; liegt daneben ein Versionsordner, lädt PowerShell den Versionsordner.
- **Aus einem Commit installieren**, nicht aus dem Arbeitsverzeichnis
  (`git archive <ref> modules/PSCollections.Connectivity/`), danach prüfen:
  `Get-Module PSCollections.Connectivity -ListAvailable | Select-Object Name, Version, ModuleBase`.
- **Ort nach Rechten wählen:** Läuft das Modul mit Adminrechten (typisch für die Aufrufer, z. B. BitLocker- und
  Secure-Boot-Abfragen), gehört es in den Modulpfad für alle Benutzer, den nur Administratoren schreiben. In den
  Modulpfad des Benutzers schreibt jeder Prozess dieses Benutzers — eine dort ausgetauschte `.psm1` läuft beim
  nächsten Import mit den Rechten des Aufrufers. Pfade per `$env:PSModulePath -split ';'` ermitteln.

Nicht veröffentlicht (keine PowerShell Gallery, kein internes Repository); keine nativen Binärdateien.

---

## Typische Fallen

| Symptom | Ursache | Fix |
|---|---|---|
| Neue Funktion fehlt nach dem Import, ohne Fehler | Name steht im Manifest, aber nicht im zusätzlichen `Export-ModuleMember` der `.psm1` (wirksam ist die Schnittmenge) — hier heute möglich (I7) | Liste nur im Manifest |
| Interne Helfer öffentlich sichtbar | `.psm1` direkt importiert oder `'*'` im Manifest | Manifest importieren; Modultest „exportiert genau …" |
| Nach einer Änderung weiter altes Verhalten | die Sitzung hält das alte Modul | `Import-Module … -Force` (so in allen Aufrufern) oder neue Sitzung |
| `Test-ConnectionInParallel` scheitert unter Windows PowerShell 5.1 | `ForEach-Object -Parallel` gibt es erst ab PowerShell 7 | dort `Get-ComputerOnlineStatus` verwenden |

---

## Pflege

Trigger: neue oder entfernte öffentliche Funktion, Versionswechsel, geänderter Installationsweg, neuer Aufrufer →
diese Datei + `PSCollections.Connectivity.psd1` + ggf. `docs/STRUCTURE.md` (Tabelle „gebraucht von"),
`architecture/DEPENDENCIES.md` und `docs/CHANGELOG.md`.
