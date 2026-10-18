# Coding Conventions – PowerShellCollections

Stack: Windows PowerShell 5.1 und PowerShell 7.x (je Skript, siehe `#Requires`) | Module je Skript
(`ActiveDirectory`, `GroupPolicy`, VMware PowerCLI, Microsoft Graph, PSPKI, …; Liste in
`architecture/DEPENDENCIES.md`) | Windows 10/11 und Windows Server als Verwaltungs- und Zielsysteme

> Gilt **zusammen mit** `docs/CONVENTIONS_COMMON.md` (stack-übergreifend: Commit-Format, Encoding,
> öffentliche Repos/Interna, Quality Gates, parallele Agenten). Diese Datei regelt die
> Stack-Spezifika und hat dort Vorrang.

**Geltungsbereich in diesem Projekt:** Die Sammlung ist über Jahre gewachsen (146 Skripte, ein Autor). Die
Code-Richtlinien in §2–§6 gelten für **neue und wesentlich geänderte** Skripte. Der Bestand wird nicht
flächendeckend nachgezogen; die Zahl der Altbefunde darf nur sinken (Ratchet, `TODO.md` I4).
`third-party/` ist ausgenommen (Fremdcode, unverändert).

Die Projektregeln aus der vorhandenen `CLAUDE.md` (Ablage, Kodierung, Namen, Interna, Pflege) stehen hier in
§3, §10, §11 und §12. Bis der Eigentümer `CLAUDE.md` auf einen Zeiger reduziert, existieren sie doppelt
(`KNOWN_ISSUES.md` K5); bei Widerspruch gilt `docs/`.

---

## 1. Git & Versionierung

Commit-Format, Scope-Wahl, `git add`-Regeln und Zeilenenden: `docs/CONVENTIONS_COMMON.md` §1–§2;
Commit-Pflicht pro Inkrement: `docs/KICKOFF.md` Phase 3b. Stack-spezifisch nur:

- Scope-Beispiele: `fix(I2): teamviewer begin block`, `feat(prtg): dsls offline license sensor`,
  `refactor(connectivity): pipeline input`. Ohne Inkrement ist der Scope der Themenordner (`prtg`, `zammad`,
  `hooks`, `index`) — so hält es auch die bisherige History.
- Commit-Messages sind öffentlich (§11): keine internen Namen, auch nicht in der Begründung.

## 2. PowerShell Code-Richtlinien

- **CmdletBinding + Param:** Jede Funktion und jedes neue Skript mit `[CmdletBinding()]` und `param()` Block.
- **Approved Verbs:** Nur [genehmigte PowerShell-Verben](https://docs.microsoft.com/powershell/scripting/developer/cmdlet/approved-verbs-for-windows-powershell-commands) für Funktions- und Skriptnamen (`Get-Verb`). `Check-` heißt `Test-`, `Create-` heißt `New-`, `Manage-` heißt `Set-`/`Update-` (§12).
- **Fehlerbehandlung:** Abbruchfehler gezielt behandeln, nicht verschlucken. Kein leeres `catch {}` ohne Logging
  (Altbestand: 38 Fundstellen). Skripte, die viele Zielrechner abarbeiten, brechen beim Ausfall **eines** Ziels
  nicht ab, sondern melden das Ziel als Ergebnis mit Status — `$ErrorActionPreference = 'Stop'` nur dort, wo ein
  Fehler den ganzen Lauf ungültig macht.
- **Eingabevalidierung:** `[ValidateNotNullOrEmpty()]`, `[ValidateRange()]`, `[ValidateSet()]` in `param()` Blöcken. Fail-Fast vor Business-Logik.
- **Keine Konfiguration im Skriptkopf als Variable**, die man vor dem Lauf „von Hand anpasst" (Altbestand, z. B.
  `Test-ADUserWeakPassword.ps1`): Werte als Parameter mit Default; Konstanten als `$script:CONSTANT_NAME = ...`.
- **Zustandsändernde Skripte** (`Set-`, `Remove-`, `New-`, `Clear-`) bekommen `SupportsShouldProcess` und
  respektieren `-WhatIf`.
- **JSON-Body immer mit `ConvertTo-Json`:** API-Request-Bodies nie per String-Konkatenation aufbauen. Sonderzeichen (Klammern, Backslashes, Anführungszeichen) erfordern manuelles Escaping — fehleranfällig und schwer testbar. Stattdessen:
  ```powershell
  # ✓ Richtig
  $body = @{ Field = $value; Items = @($item1, $item2) } | ConvertTo-Json -Depth 10
  # ✗ Falsch – bricht bei Sonderzeichen in $value
  $body = '{"Field":"' + $value + '"}'
  ```
- **Ausgabe:** Daten als Objekte in die Pipeline (`[PSCustomObject]`), nicht als formatierter Text. `Write-Host`
  nur für interaktive Konsolenhinweise und Fortschritt; Debug-Ausgabe über `Write-Verbose`. Die Sammlung besteht
  überwiegend aus interaktiven Admin-Werkzeugen — `Write-Host` ist dort üblich (599 Altbefunde
  `PSAvoidUsingWriteHost`), aber kein Ersatz für Rückgabeobjekte.
- **Logging bleibt je Skript lokal:** Eine gemeinsame `Write-Log`-Funktion gibt es bewusst nicht — zwei Skripte
  laufen als Scriptblock auf dem Zielrechner, wo kein `modules/` existiert (Begründung: `docs/BACKLOG.md`
  Abschnitt 4). Wer eine eigene `Write-Log` definiert, vermerkt das in `.NOTES`.
- **Bare-Aufruf einer wertrückgebenden Funktion leckt in den Output-Stream:** PowerShell
  schreibt **jeden** nicht zugewiesenen Ausdruck in die Pipeline. Wird eine Funktion, die
  einen Wert zurückgibt, nur zur Seitenwirkung/Validierung aufgerufen (typisch: ein
  Session-/Precondition-Guard, der das geprüfte Objekt zurückgibt), leckt deren Rückgabe in
  die Ausgabe der aufrufenden Funktion — `return $x`-Funktionen liefern dann `[guard, $x]`,
  void-Funktionen geben das Guard-Objekt aus statt nichts. Rückgabe explizit verwerfen:
  ```powershell
  $null = Assert-Precondition   # ✓ Rückgabe verworfen ( oder | Out-Null / [void](…) )
  Assert-Precondition           # ✗ Rückgabe leckt in den Output-Stream der Funktion
  ```
  Tests, die nur „Output ist nicht null" prüfen, **maskieren** diesen Bug (das geleakte
  Objekt macht den Output non-null) — exakt prüfen (`Count`, erwarteter Typ/Wert).
- **Kein Code vor `begin`/`process`/`end`:** Steht in einem Skript mit `param()` irgendein Befehl vor den
  benannten Blöcken, sind `begin {}`/`process {}` keine Blöcke mehr, sondern Befehlsaufrufe (`process {…}` wird zu
  `Get-Process`). Der PowerShell-Parser meldet das nicht, nur PSScriptAnalyzer (`InvalidSyntaxAroundProcessBlock`).
  Modulimporte gehören in den `begin`-Block (`KNOWN_ISSUES.md` K1).

## 3. Dateiorganisation

- **Ablage:** Ein Skript liegt unter dem System, gegen das es läuft; existiert es nur wegen des Ausgabe-Vertrags
  einer Plattform (PRTG-XML, Nagios-Exitcode), ist die Plattform das System. Vollständige Regel, Verzeichnisbaum
  und Begründung: `docs/STRUCTURE.md`. Kein passender Ort → `_inbox/` (30-Tage-Regel).
- **Ein Skript je Aufgabe:** keine Versionssuffixe (`_v2`, `_old`). Alte Stände löscht man, die History hat sie.
  Bewusste Ausnahme mit Begründung: `scripts/windows/desktop/window-cascade/` (`docs/BACKLOG.md` Abschnitt 9).
- **Skripte sind eigenständig.** Eine Funktion wird erst dann zum Modul unter `modules/`, wenn dieselbe Funktion in
  **drei** Fachdomänen kopiert wurde (Herleitung: `docs/STRUCTURE.md` „Module liegen bei ihrer Fachdomaene").
  Module mit klarer Fachdomäne liegen bei ihr (z. B. `scripts/monitoring/prtg/dsls/PRTG.Dsls.psm1`).
- **Modulimport aus `modules/`** nur über den Suchlauf nach oben (Muster in `docs/STRUCTURE.md`), nie über
  einen festen relativen Pfad. Skripte, die als Scriptblock auf dem Zielrechner laufen, dürfen **kein**
  `modules/` voraussetzen.
- **Funktionsbibliotheken** (nur Funktionsdefinitionen, werden dot-gesourct) heißen nach dem Inhalt
  (`ZammadApiFunctions.ps1`), nicht Verb-Noun.
- **Comment-Based Help:** Jedes Skript hat mindestens `.SYNOPSIS`; `tools/Build-ScriptIndex.ps1` liest sie für
  `INDEX.md` aus.
- **`FunctionsToExport` in der `.psd1` immer EXPLIZIT, niemals `'*'`.** Auch dann
  nicht, wenn der PSScriptAnalyzer-Check `PSUseToExportFieldsInManifest` exkludiert
  ist. Sonst werden private Helfer automatisch öffentliche API —
  inklusive Funktionen, die globalen State (TLS, Registry, Env) mutieren.
  (`modules/PSCollections.Connectivity/PSCollections.Connectivity.psd1` hält das ein.)
- **Fremdcode** liegt unverändert unter `third-party/<projekt>/` mit `ORIGIN.md` (Quelle, Stand, Lizenz);
  eigene Ergänzungen als Wrapper unter `scripts/`.
- **Encoding-Ausnahmen** (Vorrang vor `CONVENTIONS_COMMON.md` §2, sonst gilt UTF-8 ohne BOM):
  - **`.ps1`/`.psm1`/`.psd1` mit Nicht-ASCII-Zeichen (Umlaute) als UTF-8 mit BOM.** Windows PowerShell 5.1 liest
    BOM-lose Dateien in der ANSI-Codepage; aus `Prüfe` wird `PrÃ¼fe`, Regex mit Umlauten matchen still nicht
    mehr. Mehrere Skripte werten deutschsprachige Eventlog- und Programmausgaben aus, und es gibt Skripte mit
    `#Requires -Version 5.1`. Reine ASCII-Dateien brauchen kein BOM. Prüfen/reparieren mit
    `tools/Repair-ScriptEncoding.ps1` (§10).
  - **Testdateien mit Nicht-ASCII-Zeichen** (deutsche `It`-Texte) ebenfalls UTF-8 **mit BOM** — sonst meldet
    PSScriptAnalyzer `PSUseBOMForUnicodeEncodedFile`. Details: `testing/UNIT_TESTS.md` 7.6.
  - **Aufgabenplanungs-XML** als UTF-16 LE mit BOM, wie Windows sie exportiert; die Deklaration
    `encoding="UTF-16"` passt dazu. Git muss die Datei als `binary` behandeln (keine Zeilenend-Umwandlung) — im
    Projekt heute noch nicht der Fall (`KNOWN_ISSUES.md` K2). Details: `operations/TASK_SCHEDULER.md`.
  - **UTF-16-Fremddateien** (`third-party/MailStore-PowerShell-API-Wrapper/api-wrapper/MS.PS.Lib.psd1`) nicht
    konvertieren; `binary` in `.gitattributes`.
- **Zeilenenden:** festgelegt in `.gitattributes` — im Repository LF; im Arbeitsverzeichnis CRLF für
  `.ps1`/`.psm1`/`.psd1`/`.bat`/`.cmd`/`.xml`, LF für `.sh` und `.githooks/*` (ein Hook mit CRLF scheitert an
  `bad interpreter`). Nicht von Hand umstellen.

## 4. Prozessweite Side-Effects — Save/Restore-Pflicht

PowerShell-Skripte/Module mutieren häufig **prozessweite** Zustände, die die
gesamte Session überleben. Folgende Stellen sind besonders heimtückisch, weil
ein logischer „Logout"/`Disconnect`/Skript-Ende den Zustand **nicht** automatisch
zurücksetzt:

- `[System.Net.ServicePointManager]::CertificatePolicy` / `SecurityProtocol`
  (TLS-Vertrauen und Protokoll-Set — wirken auf **jede** HTTPS-Verbindung der Session)
- `$env:*` und `[Environment]::SetEnvironmentVariable(... 'Process')`
- `Set-Location` (CWD) ohne `Push-Location`/`Pop-Location`
- Registry (`HKCU:`, `HKLM:`)
- `$ErrorActionPreference`, `$ProgressPreference`, `$VerbosePreference` global statt lokal
- `$global:`-Variablen (Altbestand: 33 Befunde `PSAvoidGlobalVars`, z. B. die OUI-Liste in
  `Get-ArubaMacTable.ps1`)
- `Add-Type` für anonyme Typen (lassen sich nicht entfernen — beim zweiten Lauf nur
  noch über Typ-Existenz-Check schützen)

**Pflicht-Pattern:** vor der Mutation den alten Wert einmalig in einem
modul-/skript-skopierten `$script:`-Slot sichern, am Ende (Disconnect, Cleanup,
`finally`) restaurieren. Mehrfach-Aufrufe nicht den bereits mutierten Wert
sichern lassen (Flag-Guard).

```powershell
if (-not $script:__OldCertPolicy_saved) {
    $script:__OldCertPolicy = [System.Net.ServicePointManager]::CertificatePolicy
    $script:__OldCertPolicy_saved = $true
}
# … Mutation hier …
# Im Teardown:
if ($script:__OldCertPolicy_saved) {
    [System.Net.ServicePointManager]::CertificatePolicy = $script:__OldCertPolicy
    $script:__OldCertPolicy_saved = $false
}
```

Bevorzugt **per-Request**-Mechanismen verwenden, wenn die Plattform sie bietet
(z.B. `Invoke-WebRequest -SkipCertificateCheck` ab PowerShell 6/Core ersetzt den
prozessweiten `ServicePointManager`-Hack auf Desktop) — und auch diese nur mit `-Force`-Bestätigung (§6.1.2).

## 5. Pfade & Dateisystem

- **Pfade immer als `[System.IO.Path]`-Methoden** oder `Join-Path` — nie String-Konkatenation mit `\`
- **Test-NetConnection / Test-Path vor Zugriff:** Externe Ressourcen (Netzwerk, UNC-Pfade) vor Verwendung prüfen
- **Keine festen Ablagepfade im Code** (Altbestand: `C:\Install\…` für Logs und die OUI-Liste): Pfad als Parameter
  mit Default; Ausgabedateien mit Personenbezug nach `security/DATA_HANDLING.md`
- **Credentials niemals in Variablen für $env:** Nur `Get-Credential` oder Secrets-Manager
- **ASCII in Pfaden und Dateinamen** (§12)

## 6. Security-Checkliste vor jedem Commit

- [ ] Keine Hardcoded-Credentials — interaktiv per `Get-Credential` bzw. Credential Store
      (`architecture/CREDENTIAL_STRATEGY.md`); Platzhalter in Beispielcode, die der Hook nicht von Secrets
      unterscheiden kann, tragen `allowlist secret` im Kommentar derselben Zeile (§11)
- [ ] `.ps1`-Config-Dateien mit Credentials in `.gitignore`
- [ ] Kein `Invoke-Expression` mit nicht-validierten Strings (Command-Injection)
- [ ] `-ExecutionPolicy Bypass` nur in dedizierten Task-Scheduler-Aufrufen — nie in Quellcode
- [ ] Logging: Keine Passwörter / Tokens in `Write-Log`-Aufrufen
- [ ] Zugangsdaten nie in URL-Query-Strings (Altbestand: `OSBiz.psm1`, `TODO.md` I3)
- [ ] Prozessweite State-Mutationen (TLS, `$env:`, Registry, `Set-Location`) haben
      Save/Restore am Teardown — keine Leaks in die Folge-Session (siehe Sektion 4)
- [ ] `FunctionsToExport` ist eine **explizite Liste** (kein `'*'`); keine privaten
      Helfer in der öffentlichen API (siehe Sektion 3)
- [ ] **Defense-in-Depth für Test-/Konfig-Credentials**: gitignore + Runtime-
      Existenz-Guard + CI-`git ls-files`-Test (siehe Sektion 6.1.1 unten)
- [ ] **Gefährliche Schalter** (`-httpOnly`, `-SkipCertificateCheck` o. Ä.)
      verlangen `-Force`-Bestätigung; sonst `Write-Warning` + `throw` **vor**
      teurem/interaktivem Code (siehe Sektion 6.1.2 unten)
- [ ] Single-Command-API-Cmdlets lehnen Newlines im Befehl-Argument per
      `[ValidateScript]` ab (Multi-Command-Injection-Schranke; siehe Sektion 6.1.3)
- [ ] Kein `Install-Module` zur Laufzeit (Supply Chain, `security/THREAT_MODEL.md` Bedrohung 5)
- [ ] Keine Firmeninterna in Code, Doku oder Commit-Message (§11)

## 6.1 Sicherheits-Patterns (mit Code-Skeletten)

Wiederkehrende Sicherheits-Muster aus realen Projekten. Backport-Inkrement aus
I12 (PowerArubaSW). Jedes Pattern hat einen klaren Anwendungsbereich — nicht
jedes ist in jedem Projekt sinnvoll, aber wenn der Anwendungsfall passt, ist
die Implementierung typischerweise klein und der Nutzen hoch.

### 6.1.1 Defense-in-Depth für Test-/Konfig-Credentials (3 Schichten)

Wenn `Tests/credential.ps1`, `config.ps1` oder eine andere Datei *im Repo*
Klartext-Credentials enthalten (etwa für lokale Integrations-Tests), reicht ein
`.gitignore`-Eintrag allein nicht. Drei Schichten zusammen machen versehentliche
Commits praktisch unmöglich:

1. **Statisch (Prevention):** `.gitignore` enthält `Tests/credential.ps1` /
   `*.secret` / `config.ps1` und ist als **erster** Commit im Repo committet
   (vor allen anderen Dateien — siehe `BOOTSTRAP.md`).
2. **Runtime (Fail-Fast):** `Tests/common.ps1` (oder analoger Bootstrap-Skript)
   prüft die Existenz **vor** dem Dot-Source und bricht mit klarer Fehlermeldung
   + Hinweis auf `credential.example.ps1` ab. Pattern:
   ```powershell
   $credPath = Join-Path $here 'credential.ps1'
   if (-not (Test-Path -LiteralPath $credPath)) {
       throw "Credentials fehlen: '$credPath' wurde nicht gefunden. Kopiere credential.example.ps1 ..."
   }
   . $credPath
   ```
3. **CI-Regression:** Pester-Test (Tag `Unit`) prüft `git ls-files`:
   ```powershell
   It 'Tests/credential.ps1 ist NICHT in git getrackt' {
       (& git ls-files 'Tests/credential.ps1') | Should -BeNullOrEmpty
   }
   ```

Wenn das Repo schon mal versehentlich committed wurde, fängt diese Schicht den
Re-Add nach `git rm --cached`.

### 6.1.2 `-Force`-Pattern für gefährliche Schalter

Wenn ein Cmdlet eine sichere Default-Option und eine unsichere Komfort-Option
hat (z.B. `-httpOnly` = Klartext-Login, `-SkipCertificateCheck` = TLS-Bypass),
soll die unsichere Variante **bewusst** bestätigt werden müssen. Pattern:

```powershell
Param(
    [switch]$Unsafe,   # die gefährliche Option
    [switch]$Force     # Bestätigung
)
Process {
    if ($Unsafe -and -not $Force) {
        Write-Warning "Diese Option sendet Credentials im Klartext über HTTP."
        Write-Warning "Wer das Netz mitliest, kann sie lesen."
        Write-Warning "Bestätige explizit mit -Force oder nutze HTTPS."
        throw "Refused -Unsafe without -Force: explicit confirmation required."
    }
    # ... rest, inkl. evtl. interaktivem Get-Credential
}
```

Der Throw passiert **vor** Get-Credential-Prompts oder anderem teurem Setup —
sonst tippt der User erst sein Passwort ein und erfährt dann, dass abgebrochen
wird. Kandidaten im Bestand: `OSBiz.psm1`, `New-PublicSpotUser*.ps1`, `Get-ArubaMacTable.ps1` (`TODO.md` I3).

### 6.1.3 Newline-Validierung als billige Injection-Schranke

Cmdlets, die nur ein Single-Command-API darstellen (z.B. `Get-ArubaSWCli -cmd`),
sollen eingebettete Newlines im Eingabe-String ablehnen. Verhindert die
simpelste Form von Multi-Command-Injection, ohne legitime Use-Cases zu
beschneiden (Multi-Line gehört in eine getrennte `*-Batch`-Variante):

```powershell
Param(
    [ValidateScript({
        if ($_ -match '[\r\n]') {
            throw 'Newlines im Befehl sehen wie Multi-Command-Injection aus. Nutze die Batch-Variante für Mehrzeiler.'
        }
        $true
    })]
    [string]$cmd
)
```

Zusätzlich `.NOTES`-Sicherheits-Hinweis in der Comment-based Help: „nie aus
untrusted Input zusammenbauen — Allow-List-Validierung beim Aufrufer ist Pflicht".

---

## 7. Autonomes Arbeiten & Fehlerbehebung

- Bei Fehlern: nicht sofort abbrechen. `$Error[0]` und Stack-Trace lesen.
- Nur Dateien verändern, die für das aktuelle Inkrement relevant sind.
- **Skripte zum Erkunden lesen, nicht laden.** Die meisten Dateien führen beim Dot-Sourcing sofort Code aus (AD-,
  Remote- oder Webzugriffe). Gefahrlos ladbar sind nur die in `INDEX.md` mit `def` markierten Dateien.
- **Keine Skripte gegen echte Systeme ausführen**, um eine Änderung zu prüfen — Verhalten über Pester-Mocks
  belegen; Live-Lauf ist Sache des Betreibers und wird im Confidence-Block als „ungeprüft" vermerkt.
- `third-party/` nicht anfassen.
- Am Ende jedes Inkrements: `docs/TODO.md`, `docs/CHANGELOG.md`, `docs/STATE.md` aktualisieren.

---

## 8. Dokumentationspflichten (Trigger-Regeln)

### Neues, umbenanntes oder gelöschtes Skript
→ `INDEX.md` per `tools/Build-ScriptIndex.ps1` neu erzeugen (nie von Hand bearbeiten); vorher
`tools/Find-ScriptDependency.ps1 -CrossFolderOnly` (§10)

### Neuer Parameter / Konfigurationsoption
→ Comment-Based Help des Skripts + ggf. README des Themenordners + `docs/features/` (falls das Skript dort
beschrieben ist)

### Neue externe Abhängigkeit (Modul, Binary, API)
→ `docs/architecture/DEPENDENCIES.md`

### STATE.md (immer nach jedem Inkrement)
1. Freitext "Letztes abgeschlossenes Inkrement: …"
2. Tabelle: neue Zeile `| I# | Titel | Datum | Commit-Hash |`

---

## 9. Quality Gates — pre-commit (Definition of Done)

Für PowerShell greifen zwei der vier Gates der Definition of Done. **Stand beim Init:** es gibt weder eine
PSScriptAnalyzer-Konfiguration noch Pester-Tests (`TODO.md` I4). Bis dahin gilt:

```powershell
# Gate 1 — Linter (PSScriptAnalyzer 1.25+): für jede geänderte Datei 0 Befunde der Stufe Error/ParseError
Invoke-ScriptAnalyzer -Path <geänderte-Datei> -Severity Error, ParseError

# Gate 4 — Unit-Tests (Pester 5.x), sobald tests/ existiert (I4)
Invoke-Pester tests/ -ExcludeTag Integration -Output Detailed
```

Warnings werden vorerst nicht als Gate gewertet (Basislinie 2026-10-11: 1094 Warnings); ein geändertes Skript
soll aber nicht mehr Warnings haben als vorher.

Gate 2 (Formatter) und Gate 3 (statische Typanalyse) haben in PowerShell kein
eigenständiges Standard-Werkzeug; PSScriptAnalyzer-Regeln decken Stilfragen mit ab.

---

## 10. Projektpflege — drei Werkzeuge, drei Anlässe

Keines verändert etwas ohne Aufforderung.

| Wann | Befehl | Erwartetes Ergebnis |
|---|---|---|
| Skript angelegt, umbenannt, gelöscht | `.\tools\Build-ScriptIndex.ps1` | `INDEX.md` neu geschrieben |
| **vor** dem Verschieben, Umbenennen, Löschen | `.\tools\Find-ScriptDependency.ps1 -CrossFolderOnly` | `ungedeckt: 0` |
| Datei mit Umlauten angelegt oder eingefügt | `.\tools\Repair-ScriptEncoding.ps1 -WhatIf` | `0 Datei(en) betroffen` |

Meldet `Repair-ScriptEncoding` betroffene Dateien, denselben Aufruf ohne `-WhatIf` wiederholen. Meldet
`Find-ScriptDependency` etwas unter `UNGEDECKT`, läuft dort ein Aufruf ins Leere — das muss vor dem Push weg.

## 11. Öffentliches Repository — keine Firmeninterna

Das Repository ist öffentlich (`CONVENTIONS_COMMON.md` §3.1). Verboten in Code, Doku und Commit-Messages:
Firmen- und Standortnamen, interne AD-/DNS-Domänen, echte Benutzer-, Personen-, Server- und Hostnamen, interne
IP-Adressen und UNC-Pfade, Passwörter, API-Keys, Tokens, private Schlüssel. Interne Umgebungsangaben gehören nach
`docs/local/` (gitignored).

Platzhalter stattdessen:

| Typ | Wert |
|---|---|
| Domäne | `contoso.local`, `example.com` |
| Server | `DC01`, `DC02`, `SRV01`, `FS01` |
| Benutzer | `m.mustermann`, `m.mueller`, `j.doe` |
| E-Mail | `max.mustermann@example.com` |
| IP | `192.0.2.10`, `198.51.100.5`, `203.0.113.7` (RFC 5737) |

**Durchsetzung:** Der Interna-Hook im Sinne von `CONVENTIONS_COMMON.md` §3.1 ist in diesem Projekt der
vorhandene `.githooks/pre-commit` (statt der Template-Vorlage unter `tools/git-hooks/`):

| Datei | Versioniert | Inhalt |
|---|---|---|
| `.githooks/pre-commit` | ja | der Hook (prüft neu hinzukommenden Inhalt gestageter Dateien) |
| `.githooks/forbidden-patterns.txt` | ja | generische Muster (Secrets) |
| `.githooks/forbidden-patterns.local.txt` | **nein** | die konkreten Firmen-, Personen- und Hostnamen (ERE, case-insensitive) |
| `.githooks/forbidden-patterns.local.txt.example` | ja | Vorlage |

Aktivieren pro Klon:

```sh
git config core.hooksPath .githooks
cp .githooks/forbidden-patterns.local.txt.example .githooks/forbidden-patterns.local.txt
# lokale Datei um die eigenen Firmen-, Personen- und Hostnamen ergaenzen
```

Lücken gegenüber §3.1: Commit-Message und Dateinamen werden noch nicht geprüft (`TODO.md` I5). Bypass nur bewusst
mit `git commit --no-verify`. Der Hook ignoriert SIGPIPE, damit `git commit … | head` ihn nicht aushebelt.

## 12. Namensgebung

| Regel | Ja | Nein |
|---|---|---|
| Verb-Noun | `Get-ADUserLastLogon.ps1` | `check-for-bad-passwords.ps1` (alt) |
| Freigegebene Verben | `Get-`, `Set-`, `Test-` | `Check-`, `Create-`, `Manage-` |
| Englisch | `Set-FolderPermission.ps1` | `Fileserver-Einzelberechtigungen-fuer-User.ps1` (alt) |
| ASCII in Pfaden | `temporary/` | `Temporäre-.../` |
| Ordner kebab-case | `active-directory/` | `Server-Client-Helper-Stuff/` |

Verb-Noun gilt für **ausführbare Skripte**. Ausgenommen sind Module (`OSBiz.psm1`, `PRTG.Dsls.psm1`,
`PSCollections.Connectivity.psm1` — nach dem Modul benannt) und Funktionsbibliotheken
(`MailStoreApiFunctions.ps1`, `UserSessionFunctions.ps1` — nach dem Inhalt benannt).
