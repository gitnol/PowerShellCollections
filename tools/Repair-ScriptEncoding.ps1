<#
.SYNOPSIS
    Ergaenzt fehlende UTF-8-BOMs in Skripten, die Nicht-ASCII-Zeichen enthalten.

.DESCRIPTION
    Windows PowerShell 5.1 liest eine .ps1 ohne Byte Order Mark nicht als UTF-8,
    sondern in der ANSI-Codepage des Systems. Aus 'Prüfe' wird dann 'PrÃ¼fe'.

    Das ist nicht nur kosmetisch: Vergleiche und regulaere Ausdruecke mit
    Umlauten schlagen fehl. Betroffen sind hier unter anderem die Auswertung
    deutschsprachiger Eventlog-Texte und die Parser fuer lokalisierte
    Programmausgaben - dort matcht das Muster dann schlicht nicht mehr, ohne
    dass ein Fehler auftritt.

    PowerShell 7 liest UTF-8 auch ohne BOM korrekt; das BOM stoert dort nicht.
    Solange im Repo Skripte mit '#Requires -Version 5.1' liegen, ist das BOM
    die sichere Variante.

    Reine ASCII-Dateien bleiben unangetastet - dort gibt es nichts zu
    verwechseln.

.PARAMETER Path
    Wurzelverzeichnis. Standard: das Repo-Wurzelverzeichnis.

.PARAMETER ExcludeDirectory
    Ordnernamen, die uebersprungen werden. Fremdcode bleibt per Default aussen
    vor - dort wird nichts veraendert.

.PARAMETER WhatIf
    Zeigt nur an, welche Dateien geaendert wuerden.

.EXAMPLE
    .\tools\Repair-ScriptEncoding.ps1 -WhatIf

    Listet die betroffenen Dateien auf, ohne etwas zu schreiben.

.EXAMPLE
    .\tools\Repair-ScriptEncoding.ps1

.NOTES
    Der Dateiinhalt bleibt byteweise identisch - es werden ausschliesslich die
    drei BOM-Bytes EF BB BF vorangestellt.

    Autor: IT-Administration
#>
[CmdletBinding(SupportsShouldProcess)]
param(
    [string]$Path,

    [string[]]$ExcludeDirectory = @('.git', 'third-party', 'node_modules')
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if (-not $Path) { $Path = Split-Path -Parent $PSScriptRoot }
$Path = (Resolve-Path -LiteralPath $Path).Path

$excluded = [System.Collections.Generic.HashSet[string]]::new(
    [string[]]$ExcludeDirectory, [System.StringComparer]::OrdinalIgnoreCase)

$separators = [char[]]@([System.IO.Path]::DirectorySeparatorChar,
    [System.IO.Path]::AltDirectorySeparatorChar)

$bomBytes = [byte[]]@(0xEF, 0xBB, 0xBF)

$changed = 0
$skipped = 0

Get-ChildItem -LiteralPath $Path -Recurse -File -Include '*.ps1', '*.psm1', '*.psd1' |
    Where-Object {
        $relative = $_.FullName.Substring($Path.Length).Trim($separators)
        -not ($relative.Split($separators) | Where-Object { $excluded.Contains($_) })
    } |
    ForEach-Object {
        $bytes = [System.IO.File]::ReadAllBytes($_.FullName)

        $hasBom = $bytes.Length -ge 3 -and
        $bytes[0] -eq $bomBytes[0] -and
        $bytes[1] -eq $bomBytes[1] -and
        $bytes[2] -eq $bomBytes[2]

        if ($hasBom) { $skipped++; return }

        # UTF-16/UTF-32 erkennen und in Ruhe lassen. Ohne diese Pruefung wuerde
        # ein UTF-8-BOM vor das vorhandene UTF-16-BOM geschrieben - die Datei
        # ist damit unlesbar. Im Repo betrifft das MS.PS.Lib.psd1, das als
        # UTF-16 LE vorliegt.
        $utf16 = $bytes.Length -ge 2 -and (
            ($bytes[0] -eq 0xFF -and $bytes[1] -eq 0xFE) -or
            ($bytes[0] -eq 0xFE -and $bytes[1] -eq 0xFF))

        if ($utf16) {
            Write-Warning "Uebersprungen (UTF-16, kein UTF-8): $($_.FullName.Substring($Path.Length + 1))"
            $skipped++
            return
        }

        # Nur Dateien mit Nicht-ASCII-Bytes sind ueberhaupt gefaehrdet
        $hasNonAscii = $false
        foreach ($b in $bytes) {
            if ($b -ge 0x80) { $hasNonAscii = $true; break }
        }
        if (-not $hasNonAscii) { $skipped++; return }

        $relative = $_.FullName.Substring($Path.Length + 1)

        if ($PSCmdlet.ShouldProcess($relative, 'UTF-8 BOM ergaenzen')) {
            [System.IO.File]::WriteAllBytes($_.FullName, $bomBytes + $bytes)
            $changed++
        }
        else {
            $changed++
        }

        [pscustomobject]@{
            Path  = $relative -replace '\\', '/'
            Bytes = $bytes.Length
        }
    }

Write-Verbose "$changed Datei(en) betroffen, $skipped unveraendert."
