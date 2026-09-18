<#
.SYNOPSIS
    Entfernt den Blattschutz (Worksheet Protection) aus einer oder mehreren
    Tabellen einer .xlsx-Datei durch direkte XML-Manipulation.

.DESCRIPTION
    Das Skript behandelt die .xlsx-Datei als ZIP-Archiv, entpackt sie in einen
    GUID-basierten temporären Ordner, analysiert die interne XML-Struktur
    (workbook.xml + workbook.xml.rels) und entfernt das <sheetProtection>-Element
    aus den gewählten Arbeitsblatt-XMLs.

    Die XML-Dateien werden encoding-sicher (UTF-8 ohne BOM) gespeichert.
    Das Zusammenpacken erfolgt direkt über die .NET-Klasse
    [System.IO.Compression.ZipFile], um den fragilen Set-Location/*-Trick
    zu vermeiden.

    Der temporäre Ordner wird im finally-Block stets restlos bereinigt.

.PARAMETER ExcelFilePath
    Pflichtparameter. Vollständiger oder relativer Pfad zur .xlsx-Quelldatei.

.PARAMETER OutputFolder
    Optionaler Zielordner für die neue Ausgabedatei.
    Wird dieser nicht angegeben, wird der Ordner der Quelldatei verwendet.
    Existiert der Ordner nicht, wird eine Rückfrage gestellt.

.PARAMETER UnlockAll
    Switch-Parameter. Falls gesetzt, werden alle Arbeitsblätter ohne
    grafische Auswahl automatisch entsperrt.

.EXAMPLE
    .\Remove-ExcelSheetProtection_v4.ps1 -ExcelFilePath "C:\Daten\Analyse.xlsx"

.EXAMPLE
    .\Remove-ExcelSheetProtection_v4.ps1 -ExcelFilePath "C:\Daten\Analyse.xlsx" -UnlockAll

.EXAMPLE
    .\Remove-ExcelSheetProtection_v4.ps1 -ExcelFilePath "C:\Daten\Analyse.xlsx" -OutputFolder "C:\Export"
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, HelpMessage = "Pfad zur .xlsx-Quelldatei")]
    [string]$ExcelFilePath,

    [Parameter(Mandatory = $false, HelpMessage = "Optionaler Zielordner (Standard: Ordner der Quelldatei)")]
    [string]$OutputFolder,

    [Parameter(Mandatory = $false, HelpMessage = "Alle Blätter automatisch ohne Auswahl entsperren")]
    [switch]$UnlockAll
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

Add-Type -AssemblyName System.IO.Compression.FileSystem

# ============================================================
# Hilfsfunktion: XML encoding-sicher als UTF-8 ohne BOM speichern
# ============================================================
function Save-XmlUtf8NoBom {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [System.Xml.XmlDocument]$XmlDoc,

        [Parameter(Mandatory = $true)]
        [string]$FilePath
    )

    $writerSettings = New-Object System.Xml.XmlWriterSettings
    $writerSettings.Encoding = New-Object System.Text.UTF8Encoding($false) # $false = kein BOM
    $writerSettings.Indent   = $false

    $xmlWriter = [System.Xml.XmlWriter]::Create($FilePath, $writerSettings)
    try {
        $XmlDoc.Save($xmlWriter)
    }
    finally {
        $xmlWriter.Close()
    }
}

# ============================================================
# Region 1: Quelldatei validieren
# ============================================================

if (-not (Test-Path -LiteralPath $ExcelFilePath)) {
    Write-Error "Quelldatei nicht gefunden: $($ExcelFilePath)"
    return
}

$sourceFile = Get-Item -LiteralPath $ExcelFilePath

if ($sourceFile.Extension -ine '.xlsx') {
    Write-Error "Die angegebene Datei ist keine .xlsx-Datei: $($sourceFile.Name)"
    return
}

Write-Host "Quelldatei: $($sourceFile.FullName)" -ForegroundColor Cyan

# ============================================================
# Region 2: Zielordner bestimmen und Schreibrechte prüfen
# ============================================================

if ([string]::IsNullOrWhiteSpace($OutputFolder)) {
    $targetDir = $sourceFile.DirectoryName
}
else {
    $targetDir = $OutputFolder
}

if (-not (Test-Path -LiteralPath $targetDir)) {
    Write-Host "Zielordner existiert nicht: $($targetDir)" -ForegroundColor Yellow
    $answer = Read-Host "Ordner jetzt erstellen? (J/N)"
    if ($answer -match '^[Jj]') {
        $null = New-Item -ItemType Directory -Path $targetDir -ErrorAction Stop
        Write-Host "Ordner erstellt: $($targetDir)" -ForegroundColor Green
    }
    else {
        Write-Host "Abgebrochen." -ForegroundColor Red
        return
    }
}

$testFilePath = Join-Path $targetDir "$([Guid]::NewGuid().ToString()).tmp"
try {
    $null = New-Item -Path $testFilePath -ItemType File -ErrorAction Stop
    Remove-Item -LiteralPath $testFilePath -Force -ErrorAction Stop
}
catch {
    Write-Host "FEHLER: Keine Schreibrechte im Zielordner: $($targetDir)" -ForegroundColor Red
    return
}

# ============================================================
# Region 3: Temporären Ordner anlegen
#           (wird VOR dem try-Block deklariert, damit finally
#            ihn immer kennt, auch bei frühen Fehlern)
# ============================================================

$guid       = [Guid]::NewGuid().ToString()
$tempFolder = Join-Path ([System.IO.Path]::GetTempPath()) "ExcelUnprotect_$($guid)"
$null = New-Item -ItemType Directory -Path $tempFolder

Write-Host "Temporärer Arbeitsordner: $($tempFolder)" -ForegroundColor DarkGray

# ============================================================
# Aktuellen Pfad VOR dem try-Block sichern, damit der
# finally-Block ihn stets wiederherstellen kann
# ============================================================
$savedLocation = Get-Location

try {

    # ----------------------------------------------------------
    # Region 4: Entpacken
    # ----------------------------------------------------------

    Write-Host "Entpacke '$($sourceFile.Name)'..." -ForegroundColor Cyan
    Expand-Archive -LiteralPath $sourceFile.FullName -DestinationPath $tempFolder -Force

    # ----------------------------------------------------------
    # Region 5: Interne XML-Pfade bestimmen und validieren
    # ----------------------------------------------------------

    $xlFolder        = Join-Path $tempFolder "xl"
    $workbookXmlPath = Join-Path $xlFolder "workbook.xml"
    $relsXmlPath     = Join-Path $xlFolder (Join-Path "_rels" "workbook.xml.rels")

    if (-not (Test-Path -LiteralPath $workbookXmlPath)) {
        throw "Ungültige Excel-Struktur: workbook.xml nicht gefunden."
    }
    if (-not (Test-Path -LiteralPath $relsXmlPath)) {
        throw "Ungültige Excel-Struktur: workbook.xml.rels nicht gefunden."
    }

    # ----------------------------------------------------------
    # Region 6: Sheet-Mapping aufbauen
    #           Anzeigename → physische XML-Datei
    #
    # WICHTIG: Das r:id-Attribut liegt im Relationships-Namespace.
    #          Direktzugriff über $sheet.id ist zufällig und falsch.
    #          Korrekt: GetAttribute("id", $rNs)
    # ----------------------------------------------------------

    [xml]$wbDoc  = Get-Content -LiteralPath $workbookXmlPath -Encoding UTF8
    [xml]$relDoc = Get-Content -LiteralPath $relsXmlPath     -Encoding UTF8

    $mainNs = "http://schemas.openxmlformats.org/spreadsheetml/2006/main"
    $rNs    = "http://schemas.openxmlformats.org/officeDocument/2006/relationships"

    $nsManager = New-Object System.Xml.XmlNamespaceManager($wbDoc.NameTable)
    $nsManager.AddNamespace("main", $mainNs)
    $nsManager.AddNamespace("r",    $rNs)

    $sheetMapping = New-Object System.Collections.Generic.List[PSCustomObject]

    foreach ($sheetNode in $wbDoc.SelectNodes("//main:sheet", $nsManager)) {
        # r:id korrekt über den Relationships-Namespace abfragen
        $rId     = $sheetNode.GetAttribute("id", $rNs)
        $relNode = $relDoc.Relationships.Relationship | Where-Object { $_.Id -eq $rId }

        if ($null -ne $relNode) {
            $target = $relNode.Target

            # Target kann relativ ("worksheets/sheet1.xml") oder absolut sein
            if ([System.IO.Path]::IsPathRooted($target)) {
                $xmlPath = $target
            }
            else {
                $xmlPath = Join-Path $xlFolder $target
            }

            $sheetMapping.Add([PSCustomObject]@{
                Blattname = $sheetNode.name
                XmlPfad   = $xmlPath
            })
        }
    }

    Write-Host "$($sheetMapping.Count) Arbeitsblatt/Arbeitsblätter erkannt." -ForegroundColor Cyan

    if ($sheetMapping.Count -eq 0) {
        throw "Es wurden keine Arbeitsblätter in der Datei gefunden."
    }

    # ----------------------------------------------------------
    # Region 7: Blattauswahl
    # ----------------------------------------------------------

    if ($UnlockAll.IsPresent) {
        Write-Host "Modus: Alle Blätter automatisch entsperren." -ForegroundColor Yellow
        $selectedSheets = $sheetMapping
    }
    else {
        Write-Host "Modus: Manuelle Auswahl via Out-GridView." -ForegroundColor Yellow
        $selectedSheets = $sheetMapping | Out-GridView -Title "Blätter zum Entsperren auswählen (Mehrfachauswahl möglich)" -PassThru

        if ($null -eq $selectedSheets -or @($selectedSheets).Count -eq 0) {
            Write-Host "Keine Blätter ausgewählt. Vorgang wird abgebrochen." -ForegroundColor Yellow
            return
        }
    }

    # ----------------------------------------------------------
    # Region 8: sheetProtection-Tag aus den gewählten XMLs entfernen
    # ----------------------------------------------------------

    $removedCount = 0
    $skippedCount = 0

    foreach ($sheet in $selectedSheets) {
        if (-not (Test-Path -LiteralPath $sheet.XmlPfad)) {
            Write-Host "  [WARNUNG] XML-Datei nicht gefunden: $($sheet.XmlPfad)" -ForegroundColor Yellow
            continue
        }

        [xml]$sheetXml = Get-Content -LiteralPath $sheet.XmlPfad -Encoding UTF8
        $protNode = $sheetXml.SelectSingleNode("//*[local-name()='sheetProtection']")

        if ($null -ne $protNode) {
            $null = $protNode.ParentNode.RemoveChild($protNode)
            Save-XmlUtf8NoBom -XmlDoc $sheetXml -FilePath $sheet.XmlPfad
            Write-Host "  [OK]   Schutz entfernt: '$($sheet.Blattname)'" -ForegroundColor Green
            $removedCount++
        }
        else {
            Write-Host "  [INFO] Kein Schutz vorhanden: '$($sheet.Blattname)'" -ForegroundColor DarkGray
            $skippedCount++
        }
    }

    Write-Host "Zusammenfassung: $($removedCount) Blatt/Blätter entsperrt, $($skippedCount) ohne Schutz übersprungen." -ForegroundColor Cyan

    # ----------------------------------------------------------
    # Region 9: Zusammenpacken mit ZipFile (kein Set-Location-Trick)
    #           ZipFile::CreateFromDirectory ist LiteralPath-sicher
    #           und benötigt keine Änderung des aktuellen Verzeichnisses.
    # ----------------------------------------------------------

    $newFileName = "$($sourceFile.BaseName)_unprotected.xlsx"
    $finalPath   = Join-Path $targetDir $newFileName

    if (Test-Path -LiteralPath $finalPath) {
        Write-Host "Bestehende Ausgabedatei wird überschrieben: $($finalPath)" -ForegroundColor Yellow
        Remove-Item -LiteralPath $finalPath -Force
    }

    Write-Host "Erstelle Ausgabedatei..." -ForegroundColor Cyan

    # $false = Basisordnernamen NICHT in das Archiv einschließen
    [System.IO.Compression.ZipFile]::CreateFromDirectory(
        $tempFolder,
        $finalPath,
        [System.IO.Compression.CompressionLevel]::Optimal,
        $false
    )

    Write-Host "Erfolgreich erstellt: $($finalPath)" -ForegroundColor Green

}
catch {
    Write-Error "Fehler während der Verarbeitung: $($_.Exception.Message)"
}
finally {
    # Ursprüngliches Verzeichnis wiederherstellen
    Set-Location -LiteralPath $savedLocation

    # Temporären Ordner restlos bereinigen
    if (Test-Path -LiteralPath $tempFolder) {
        Write-Host "Bereinige temporären Ordner..." -ForegroundColor DarkGray
        Remove-Item -LiteralPath $tempFolder -Recurse -Force -ErrorAction SilentlyContinue
        Write-Host "Temporärer Ordner entfernt." -ForegroundColor DarkGray
    }
}
