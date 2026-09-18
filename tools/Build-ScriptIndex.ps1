<#
.SYNOPSIS
    Erzeugt INDEX.md - eine durchsuchbare Uebersicht aller Skripte im Repo.

.DESCRIPTION
    Liest jede .ps1/.psm1 mit dem PowerShell-Parser ein und erzeugt eine nach
    Ordner gruppierte Markdown-Tabelle.

    Je Skript werden ermittelt:

    - die .SYNOPSIS aus der Comment-Based Help; fehlt sie, ersatzweise die
      erste Kommentarzeile, gekennzeichnet mit "(aus Kommentar)"
    - ob die Datei ausser Funktionsdefinitionen nichts ausfuehrt und damit
      gefahrlos per Dot-Sourcing geladen werden kann
    - Syntaxfehler

    Der Parser wird bewusst statt Get-Help benutzt: Get-Help wuerde das Skript
    in die Session laden (Dot-Sourcing, Modul-Importe, Code auf oberster
    Ebene). Der AST liest nur, ohne auszufuehren - bei fremdem oder altem
    Code der einzig vertretbare Weg.

.PARAMETER Path
    Wurzelverzeichnis. Standard: das Repo-Wurzelverzeichnis.

.PARAMETER OutputPath
    Zieldatei. Standard: INDEX.md im Wurzelverzeichnis.

.PARAMETER ExcludeDirectory
    Ordnernamen, die uebersprungen werden.

.PARAMETER PassThru
    Gibt die eingelesenen Skriptdaten zusaetzlich als Objekte zurueck.

.EXAMPLE
    .\tools\Build-ScriptIndex.ps1

.EXAMPLE
    .\tools\Build-ScriptIndex.ps1 -PassThru |
        Where-Object { -not $_.Synopsis } |
        Select-Object RelativePath

    Arbeitsliste: Skripte ohne Comment-Based Help.

.EXAMPLE
    .\tools\Build-ScriptIndex.ps1 -PassThru |
        Where-Object DefinitionsOnly |
        Select-Object RelativePath

    Dateien, die gefahrlos per Dot-Sourcing geladen werden koennen.

.NOTES
    Autor: IT-Administration
#>
[CmdletBinding()]
param(
    [string]$Path,

    [string]$OutputPath,

    [string[]]$ExcludeDirectory = @('.git', 'third-party', 'node_modules'),

    [switch]$PassThru
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if (-not $Path) { $Path = Split-Path -Parent $PSScriptRoot }
$Path = (Resolve-Path -LiteralPath $Path).Path
if (-not $OutputPath) { $OutputPath = Join-Path $Path 'INDEX.md' }

# Befehle, die auf oberster Ebene nur die Ausfuehrungsumgebung herrichten und
# keine Arbeit verrichten. Ohne diese Ausnahme gilt praktisch jede Datei als
# "fuehrt Code aus" und die Angabe verliert ihren Wert.
$setupCommands = @(
    'Set-StrictMode', 'Import-Module', 'Add-Type', 'Set-Alias', 'New-Alias',
    'Export-ModuleMember', 'Join-Path', 'Split-Path'
)

function Get-ScriptFacts {
    <#
    .SYNOPSIS
        Liest Synopsis, Nebenwirkungsfreiheit und Syntaxfehler einer Datei
        ueber den AST, ohne sie auszufuehren.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$FilePath
    )

    $tokens = $null
    $errors = $null
    $ast = [System.Management.Automation.Language.Parser]::ParseFile(
        $FilePath, [ref]$tokens, [ref]$errors)

    # --- Synopsis: erst Skript-Ebene, dann erste Funktion ---
    $help = $ast.GetHelpContent()
    if (-not $help -or -not $help.Synopsis) {
        $firstFunction = $ast.FindAll(
            { $args[0] -is [System.Management.Automation.Language.FunctionDefinitionAst] },
            $false) | Select-Object -First 1
        if ($firstFunction) { $help = $firstFunction.GetHelpContent() }
    }

    $synopsis = $null
    if ($help -and $help.Synopsis) {
        $synopsis = ($help.Synopsis -replace '\s+', ' ').Trim()
    }

    # GetHelpContent() findet Comment-Based Help nur an den dafuer vorgesehenen
    # Stellen: direkt vor oder direkt nach dem Funktionskopf bzw. am
    # Skriptanfang. Steht der Hilfeblock woanders - etwa nach einem
    # #Requires-Block, hinter Code oder vor der zweiten von mehreren Funktionen -
    # liefert die API nichts zurueck, obwohl eine .SYNOPSIS da ist. Das betraf
    # hier 15 Dateien. Deshalb zusaetzlich ein textueller Durchgang durch die
    # Kommentar-Token.
    if (-not $synopsis) {
        foreach ($token in $tokens) {
            if ($token.Kind -ne 'Comment') { continue }
            if ($token.Text -notmatch '(?im)^\s*[#\s]*\.SYNOPSIS\s*$') { continue }

            $lines = $token.Text -split "`r?`n"
            $index = 0
            while ($index -lt $lines.Count -and $lines[$index] -notmatch '(?i)^\s*[#\s]*\.SYNOPSIS\s*$') {
                $index++
            }

            # Alles bis zur naechsten Hilfe-Direktive oder zum Blockende sammeln
            $collected = [System.Collections.Generic.List[string]]::new()
            for ($i = $index + 1; $i -lt $lines.Count; $i++) {
                $line = ($lines[$i] -replace '^\s*#*', '').Trim()
                if ($line -match '^\.[A-Z]+' -or $line -match '^#>') { break }
                if ($line) { $collected.Add($line) }
                elseif ($collected.Count -gt 0) { break }
            }

            if ($collected.Count -gt 0) {
                $synopsis = ($collected -join ' ' -replace '\s+', ' ').Trim()
                break
            }
        }
    }

    # --- Ersatz: erste brauchbare Kommentarzeile ---
    $commentHint = $null
    if (-not $synopsis) {
        foreach ($token in $tokens) {
            if ($token.Kind -ne 'Comment') { continue }

            $text = $token.Text -replace '^<#', '' -replace '#>$', ''
            foreach ($line in ($text -split "`r?`n")) {
                $clean = ($line -replace '^\s*#+', '').Trim()
                # Requires-Direktiven und Trennlinien taugen nicht als Beschreibung
                if ($clean -match '^(requires\b|[-=*_#\s]*$)') { continue }
                if ($clean.Length -lt 8) { continue }
                $commentHint = $clean
                break
            }
            if ($commentHint) { break }
        }
    }

    # --- Nebenwirkungsfrei? ---
    $topLevel = @()
    if ($ast.EndBlock -and $ast.EndBlock.Statements) {
        $topLevel = $ast.EndBlock.Statements | Where-Object {
            $_ -isnot [System.Management.Automation.Language.FunctionDefinitionAst]
        }
    }

    $realCommands = foreach ($statement in $topLevel) {
        $found = $statement.FindAll(
            { $args[0] -is [System.Management.Automation.Language.CommandAst] }, $true)
        foreach ($command in $found) {
            $name = $command.GetCommandName()
            if ($name -and $setupCommands -notcontains $name) { $name }
        }
    }

    [pscustomobject]@{
        Synopsis        = $synopsis
        CommentHint     = $commentHint
        DefinitionsOnly = -not @($realCommands).Count
        ParseErrors     = @($errors).Count
    }
}

# Ausschluss ueber Pfadsegmente statt Regex: auf Windows muesste man dafuer
# Backslashes doppelt maskieren, was genau die Art Fehler erzeugt, die erst
# auffaellt, wenn der Index zu viel oder zu wenig enthaelt.
$excluded = [System.Collections.Generic.HashSet[string]]::new(
    [string[]]$ExcludeDirectory, [System.StringComparer]::OrdinalIgnoreCase)

$separators = [char[]]@([System.IO.Path]::DirectorySeparatorChar,
    [System.IO.Path]::AltDirectorySeparatorChar)

function Test-IsExcluded {
    <#
    .SYNOPSIS
        Prueft, ob ein Pfad unterhalb eines ausgeschlossenen Ordners liegt.
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory)]
        [string]$FullName,

        [Parameter(Mandatory)]
        [string]$Root
    )

    $relative = $FullName.Substring($Root.Length).Trim($separators)
    foreach ($segment in $relative.Split($separators)) {
        if ($excluded.Contains($segment)) { return $true }
    }
    return $false
}

$scripts = Get-ChildItem -LiteralPath $Path -Recurse -File -Include '*.ps1', '*.psm1' |
    Where-Object { -not (Test-IsExcluded -FullName $_.FullName -Root $Path) } |
    ForEach-Object {
        $facts = Get-ScriptFacts -FilePath $_.FullName
        $relative = $_.FullName.Substring($Path.Length + 1).Replace(
            [System.IO.Path]::DirectorySeparatorChar, '/')

        [pscustomobject]@{
            Name            = $_.Name
            RelativePath    = $relative
            Directory       = [System.IO.Path]::GetDirectoryName($relative).Replace(
                [System.IO.Path]::DirectorySeparatorChar, '/')
            Synopsis        = $facts.Synopsis
            CommentHint     = $facts.CommentHint
            DefinitionsOnly = $facts.DefinitionsOnly
            ParseErrors     = $facts.ParseErrors
        }
    } | Sort-Object Directory, Name

$total = @($scripts).Count
$documented = @($scripts).Where({ $_.Synopsis }).Count
$hinted = @($scripts).Where({ -not $_.Synopsis -and $_.CommentHint }).Count
$safe = @($scripts).Where({ $_.DefinitionsOnly }).Count
$broken = @($scripts).Where({ $_.ParseErrors -gt 0 }).Count
$percent = if ($total -gt 0) { [math]::Round(100 * $documented / $total) } else { 0 }

$md = [System.Collections.Generic.List[string]]::new()
$md.Add('# Skript-Index')
$md.Add('')
$md.Add('<!-- Automatisch erzeugt von tools/Build-ScriptIndex.ps1 - nicht von Hand bearbeiten. -->')
$md.Add('')
$md.Add("$total Skripte. $documented mit ``.SYNOPSIS`` ($percent%), $hinted weitere mit einer Kurzbeschreibung aus dem ersten Kommentar.")
$md.Add('')
$md.Add('| Markierung | Bedeutung |')
$md.Add('| ---------- | --------- |')
$md.Add('| _(aus Kommentar)_ | keine `.SYNOPSIS` - Text stammt aus der ersten Kommentarzeile und ist ein Hinweis, keine Beschreibung |')
$md.Add('| `def` | enthaelt ausser Funktionsdefinitionen keinen ausfuehrbaren Code, laesst sich also gefahrlos per Dot-Sourcing laden |')
$md.Add('| **Syntaxfehler** | die Datei parst nicht |')
$md.Add('')
$md.Add("Davon $safe nebenwirkungsfrei, $broken mit Syntaxfehlern.")
$md.Add('')

foreach ($group in ($scripts | Group-Object Directory)) {
    $directory = if ($group.Name) { "``$($group.Name)/``" } else { '(Wurzelverzeichnis)' }

    $md.Add("## $directory")
    $md.Add('')
    $md.Add('| Skript | | Beschreibung |')
    $md.Add('| ------ | --- | ------------ |')

    foreach ($script in $group.Group) {
        # Pipes in der Beschreibung wuerden die Markdown-Tabelle zerlegen.
        $description = if ($script.Synopsis) {
            $script.Synopsis.Replace('|', '\|')
        }
        elseif ($script.CommentHint) {
            '_(aus Kommentar)_ ' + $script.CommentHint.Replace('|', '\|')
        }
        else {
            '_keine Beschreibung_'
        }

        if ($script.ParseErrors -gt 0) {
            $description = "**Syntaxfehler ($($script.ParseErrors))** - $description"
        }

        $flag = if ($script.DefinitionsOnly) { '`def`' } else { '' }

        $md.Add("| [$($script.Name)]($($script.RelativePath)) | $flag | $description |")
    }

    $md.Add('')
}

Set-Content -LiteralPath $OutputPath -Value $md -Encoding UTF8
Write-Verbose "Index geschrieben: $OutputPath ($total Skripte, $documented dokumentiert, $hinted mit Kommentar-Hinweis)"

if ($PassThru) { $scripts }
