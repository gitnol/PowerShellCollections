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

    Aufrufe innerhalb desselben Ordners werden getrennt ausgewiesen: sie sind
    in der Regel gewollt (Skript plus Modul daneben) und ueberstehen ein
    Verschieben, solange der ganze Ordner wandert. Alles darueber hinaus ist
    ein Kandidat fuer einen Bruch.

.PARAMETER Path
    Wurzelverzeichnis. Standard: das Repo-Wurzelverzeichnis.

.PARAMETER ExcludeDirectory
    Ordnernamen, die uebersprungen werden.

.PARAMETER CrossFolderOnly
    Nur die kritischen Faelle ueber Ordnergrenzen ausgeben.

.PARAMETER PassThru
    Gibt Objekte statt Text zurueck.

.EXAMPLE
    .\tools\Find-ScriptDependency.ps1

.EXAMPLE
    .\tools\Find-ScriptDependency.ps1 -CrossFolderOnly

    Vor jedem Verschieben, Umbenennen oder Loeschen von Skripten ausfuehren.

.NOTES
    Falsch positiv sind Namen, die mehrere Dateien unabhaengig voneinander
    definieren - `Write-Log` ist hier das Beispiel. Das Werkzeug meldet dann
    alle Definitionsorte; welcher gemeint war, muss man lesen.

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

    $perFile[$relative] = @{ Own = $own; Used = $used }
}

$results = foreach ($relative in $perFile.Keys) {
    foreach ($name in $perFile[$relative].Used) {
        if ($perFile[$relative].Own.Contains($name)) { continue }
        if ($known.Contains($name)) { continue }
        if (-not $definedIn.ContainsKey($name)) { continue }

        foreach ($source in ($definedIn[$name] |
                    Where-Object { $_ -ne $relative } | Select-Object -Unique)) {
            [pscustomobject]@{
                Caller        = $relative
                Function      = $name
                DefinedIn     = $source
                SameDirectory = (Split-Path $relative -Parent) -eq (Split-Path $source -Parent)
            }
        }
    }
}

$results = @($results | Sort-Object Caller, Function)

if ($PassThru) {
    if ($CrossFolderOnly) { return $results | Where-Object { -not $_.SameDirectory } }
    return $results
}

$cross = @($results | Where-Object { -not $_.SameDirectory })
$inside = @($results | Where-Object { $_.SameDirectory })

Write-Host ''
Write-Host 'Ueber Ordnergrenzen - bricht beim Verschieben:' -ForegroundColor Yellow
if ($cross.Count -eq 0) {
    Write-Host '  keine'
}
foreach ($row in $cross) {
    Write-Host ('  {0}' -f $row.Caller)
    Write-Host ('      {0}()  definiert in  {1}' -f $row.Function, $row.DefinedIn) -ForegroundColor DarkGray
}

if (-not $CrossFolderOnly) {
    Write-Host ''
    Write-Host 'Innerhalb eines Ordners - in der Regel gewollt:' -ForegroundColor Green
    if ($inside.Count -eq 0) { Write-Host '  keine' }
    foreach ($row in $inside) {
        Write-Host ('  {0}  ->  {1}()  aus  {2}' -f
            (Split-Path $row.Caller -Leaf), $row.Function, (Split-Path $row.DefinedIn -Leaf))
    }
}

Write-Host ''
Write-Host ('ueber Ordnergrenzen: {0}   innerhalb: {1}' -f $cross.Count, $inside.Count)
