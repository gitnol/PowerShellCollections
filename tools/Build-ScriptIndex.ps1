<#
.SYNOPSIS
    Erzeugt INDEX.md - eine durchsuchbare Uebersicht aller Skripte im Repo.

.DESCRIPTION
    Liest jede .ps1/.psm1 mit dem PowerShell-Parser ein und zieht die
    .SYNOPSIS aus der Comment-Based Help. Das Ergebnis ist eine nach Ordner
    gruppierte Markdown-Tabelle.

    Der Parser wird bewusst statt Get-Help benutzt: Get-Help wuerde das Skript
    in die Session laden (Dot-Sourcing, Modul-Importe, Code auf oberster
    Ebene). Der AST liest nur, ohne auszufuehren - bei fremdem oder altem
    Code der einzig vertretbare Weg.

    Skripte ohne .SYNOPSIS werden mit einem Hinweis aufgefuehrt, damit der
    Index gleichzeitig als Arbeitsliste fuer fehlende Doku dient.

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

    Listet alle Skripte ohne Comment-Based Help auf - die Arbeitsliste fuer
    nachzudokumentierende Dateien.

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

function Get-ScriptSynopsis {
    <#
    .SYNOPSIS
        Liest die .SYNOPSIS einer Datei ueber den AST, ohne sie auszufuehren.
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

    # Erst die Skript-Ebene, sonst die erste enthaltene Funktion: viele Dateien
    # hier definieren nur eine Funktion und tragen die Hilfe dort.
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

    [pscustomobject]@{
        Synopsis    = $synopsis
        ParseErrors = @($errors).Count
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
        $info = Get-ScriptSynopsis -FilePath $_.FullName
        $relative = $_.FullName.Substring($Path.Length + 1).Replace(
            [System.IO.Path]::DirectorySeparatorChar, '/')

        [pscustomobject]@{
            Name         = $_.Name
            RelativePath = $relative
            Directory    = [System.IO.Path]::GetDirectoryName($relative).Replace(
                [System.IO.Path]::DirectorySeparatorChar, '/')
            Synopsis     = $info.Synopsis
            ParseErrors  = $info.ParseErrors
        }
    } | Sort-Object Directory, Name

$total = @($scripts).Count
$documented = @($scripts).Where({ $_.Synopsis }).Count
$percent = if ($total -gt 0) { [math]::Round(100 * $documented / $total) } else { 0 }

$md = [System.Collections.Generic.List[string]]::new()
$md.Add('# Skript-Index')
$md.Add('')
$md.Add('<!-- Automatisch erzeugt von tools/Build-ScriptIndex.ps1 - nicht von Hand bearbeiten. -->')
$md.Add('')
$md.Add("$total Skripte, davon $documented mit ``.SYNOPSIS`` ($percent%).")
$md.Add('')

foreach ($group in ($scripts | Group-Object Directory)) {
    $directory = if ($group.Name) { "``$($group.Name)/``" } else { '(Wurzelverzeichnis)' }

    $md.Add("## $directory")
    $md.Add('')
    $md.Add('| Skript | Beschreibung |')
    $md.Add('| ------ | ------------ |')

    foreach ($script in $group.Group) {
        # Pipes in der Beschreibung wuerden die Markdown-Tabelle zerlegen.
        $description = if ($script.Synopsis) {
            $script.Synopsis.Replace('|', '\|')
        }
        else {
            '_keine .SYNOPSIS_'
        }

        if ($script.ParseErrors -gt 0) {
            $description += " _(Achtung: $($script.ParseErrors) Parserfehler)_"
        }

        $md.Add("| [$($script.Name)]($($script.RelativePath)) | $description |")
    }

    $md.Add('')
}

Set-Content -LiteralPath $OutputPath -Value $md -Encoding UTF8
Write-Verbose "Index geschrieben: $OutputPath ($total Skripte, $documented dokumentiert)"

if ($PassThru) { $scripts }
