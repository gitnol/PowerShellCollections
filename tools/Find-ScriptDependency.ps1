<#
.SYNOPSIS
    Findet Funktionsaufrufe, die ueber Dateigrenzen hinweg gehen.

.DESCRIPTION
    Skripte in dieser Sammlung sind ueberwiegend eigenstaendig - aber nicht
    alle. Ruft eine Datei eine Funktion auf, die nur in einer anderen Datei
    definiert ist, dann bricht sie, sobald diese andere Datei verschoben,
    umbenannt oder geloescht wird. Beim Laden faellt das nicht auf: der Fehler
    kommt erst zur Laufzeit an der Aufrufstelle.

    Das Werkzeug liest alle Dateien ueber den AST (fuehrt also nichts aus),
    sammelt je Datei die definierten und die aufgerufenen Namen und meldet
    jeden Aufruf, der

      - nicht in derselben Datei definiert ist,
      - kein in der Session bekanntes Cmdlet ist,
      - aber in einer anderen Datei des Repos definiert wird.

    Die Treffer werden in drei Gruppen ausgewiesen:

      UNGEDECKT   die Funktion kommt nirgendwoher - der Aufruf scheitert zur
                  Laufzeit. Das ist die Gruppe, die zaehlt.
      per Import  die Datei laedt das definierende Modul ausdruecklich per
                  Import-Module. Gewollt und in Ordnung.
      im Ordner   Aufrufer und Definition liegen nebeneinander; das
                  ueberlebt ein Verschieben, solange der Ordner als Ganzes
                  wandert.

.PARAMETER Path
    Wurzelverzeichnis. Standard: das Repo-Wurzelverzeichnis.

.PARAMETER ExcludeDirectory
    Ordnernamen, die uebersprungen werden.

.PARAMETER CrossFolderOnly
    Nur die ungedeckten Aufrufe ausgeben.

.PARAMETER PassThru
    Gibt Objekte statt Text zurueck.

.EXAMPLE
    .\tools\Find-ScriptDependency.ps1

.EXAMPLE
    .\tools\Find-ScriptDependency.ps1 -CrossFolderOnly

    Vor jedem Verschieben, Umbenennen oder Loeschen von Skripten ausfuehren.

.NOTES
    Definieren mehrere Dateien denselben Namen unabhaengig voneinander, meldet
    das Werkzeug alle Definitionsorte - welcher gemeint war, muss man lesen.
    Ein Import wird ueber den Dateinamen im Import-Module-Aufruf erkannt,
    nicht ueber den aufgeloesten Pfad.

    Nicht erkannt werden Aufrufe ueber Variablen (`& $befehl`) und
    Aliasse.

    Autor: IT-Administration
#>
[CmdletBinding()]
param(
    [string]$Path,

    [string[]]$ExcludeDirectory = @('.git', 'third-party', 'node_modules'),

    [switch]$CrossFolderOnly,

    [switch]$PassThru
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if (-not $Path) { $Path = Split-Path -Parent $PSScriptRoot }
$Path = (Resolve-Path -LiteralPath $Path).Path

# Den Befehlsvorrat einmal einlesen. Ein Get-Command je Name kostet bei
# ueber tausend Aufrufnamen zweistellige Sekunden.
$known = [System.Collections.Generic.HashSet[string]]::new(
    [System.StringComparer]::OrdinalIgnoreCase)
Get-Command -All -ErrorAction SilentlyContinue |
    ForEach-Object { [void]$known.Add($_.Name) }

$excluded = [System.Collections.Generic.HashSet[string]]::new(
    [string[]]$ExcludeDirectory, [System.StringComparer]::OrdinalIgnoreCase)

$separators = [char[]]@([System.IO.Path]::DirectorySeparatorChar,
    [System.IO.Path]::AltDirectorySeparatorChar)

$files = Get-ChildItem -LiteralPath $Path -Recurse -File -Include '*.ps1', '*.psm1' |
    Where-Object {
        $relative = $_.FullName.Substring($Path.Length).Trim($separators)
        -not ($relative.Split($separators) | Where-Object { $excluded.Contains($_) })
    }

$definedIn = @{}
$perFile = @{}

foreach ($file in $files) {
    $relative = $file.FullName.Substring($Path.Length + 1).Replace(
        [System.IO.Path]::DirectorySeparatorChar, '/')

    $ast = [System.Management.Automation.Language.Parser]::ParseFile(
        $file.FullName, [ref]$null, [ref]$null)

    $own = [System.Collections.Generic.HashSet[string]]::new(
        [System.StringComparer]::OrdinalIgnoreCase)

    foreach ($fn in $ast.FindAll(
            { $args[0] -is [System.Management.Automation.Language.FunctionDefinitionAst] }, $true)) {
        [void]$own.Add($fn.Name)
        if (-not $definedIn.ContainsKey($fn.Name)) {
            $definedIn[$fn.Name] = New-Object System.Collections.Generic.List[string]
        }
        $definedIn[$fn.Name].Add($relative)
    }

    $used = [System.Collections.Generic.HashSet[string]]::new(
        [System.StringComparer]::OrdinalIgnoreCase)

    foreach ($command in $ast.FindAll(
            { $args[0] -is [System.Management.Automation.Language.CommandAst] }, $true)) {
        $name = $command.GetCommandName()
        if ($name) { [void]$used.Add($name) }
    }

    # Laedt die Datei ein Modul aus modules/ ausdruecklich per Import-Module,
    # dann ist eine Abhaengigkeit dorthin gewollt und kein Risiko. Ohne diese
    # Unterscheidung meldet das Werkzeug jeden sauberen Modulaufruf als
    # Problem - und was uebrig bleibt, geht im Rauschen unter.
    $imports = [System.Collections.Generic.HashSet[string]]::new(
        [System.StringComparer]::OrdinalIgnoreCase)

    foreach ($command in $ast.FindAll(
            { $args[0] -is [System.Management.Automation.Language.CommandAst] }, $true)) {
        if ($command.GetCommandName() -ne 'Import-Module') { continue }
        foreach ($element in $command.CommandElements) {
            foreach ($match in [regex]::Matches($element.Extent.Text, '[\w.]+(?=\.psd1|\.psm1)')) {
                [void]$imports.Add($match.Value)
            }
        }
    }

    $perFile[$relative] = @{ Own = $own; Used = $used; Imports = $imports }
}

$results = foreach ($relative in $perFile.Keys) {
    foreach ($name in $perFile[$relative].Used) {
        if ($perFile[$relative].Own.Contains($name)) { continue }
        if ($known.Contains($name)) { continue }
        if (-not $definedIn.ContainsKey($name)) { continue }

        foreach ($source in ($definedIn[$name] |
                    Where-Object { $_ -ne $relative } | Select-Object -Unique)) {

            $moduleName = [System.IO.Path]::GetFileNameWithoutExtension($source)
            $imported = $perFile[$relative].Imports.Contains($moduleName)

            [pscustomobject]@{
                Caller        = $relative
                Function      = $name
                DefinedIn     = $source
                Imported      = $imported
                SameDirectory = (Split-Path $relative -Parent) -eq (Split-Path $source -Parent)
            }
        }
    }
}

$results = @($results | Sort-Object Caller, Function)

if ($PassThru) {
    if ($CrossFolderOnly) { return $results | Where-Object { -not $_.SameDirectory -and -not $_.Imported } }
    return $results
}

$unresolved = @($results | Where-Object { -not $_.SameDirectory -and -not $_.Imported })
$viaImport = @($results | Where-Object { $_.Imported })
$inside = @($results | Where-Object { $_.SameDirectory -and -not $_.Imported })

Write-Host ''
Write-Host 'UNGEDECKT - die Funktion kommt nirgendwoher:' -ForegroundColor Red
if ($unresolved.Count -eq 0) {
    Write-Host '  keine'
}
foreach ($row in $unresolved) {
    Write-Host ('  {0}' -f $row.Caller)
    Write-Host ('      {0}()  nur definiert in  {1}' -f $row.Function, $row.DefinedIn) -ForegroundColor DarkGray
}

if (-not $CrossFolderOnly) {
    Write-Host ''
    Write-Host 'Per Import-Module aufgeloest - in Ordnung:' -ForegroundColor Green
    if ($viaImport.Count -eq 0) { Write-Host '  keine' }
    foreach ($row in $viaImport) {
        Write-Host ('  {0}  ->  {1}()  aus  {2}' -f
            (Split-Path $row.Caller -Leaf), $row.Function, (Split-Path $row.DefinedIn -Leaf))
    }

    Write-Host ''
    Write-Host 'Innerhalb eines Ordners - in der Regel gewollt:' -ForegroundColor Green
    if ($inside.Count -eq 0) { Write-Host '  keine' }
    foreach ($row in $inside) {
        Write-Host ('  {0}  ->  {1}()  aus  {2}' -f
            (Split-Path $row.Caller -Leaf), $row.Function, (Split-Path $row.DefinedIn -Leaf))
    }
}

Write-Host ''
Write-Host ('ungedeckt: {0}   per Import aufgeloest: {1}   im selben Ordner: {2}' -f
    $unresolved.Count, $viaImport.Count, $inside.Count)
