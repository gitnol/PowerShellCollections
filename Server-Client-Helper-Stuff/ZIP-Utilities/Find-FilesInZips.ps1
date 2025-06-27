<#
.SYNOPSIS
    Durchsucht ZIP-Archive nach Dateien basierend auf einem Suchmuster.

.DESCRIPTION
    Die Funktion Find-FileInZips durchsucht alle ZIP-Dateien in einem angegebenen Verzeichnis nach Dateien,
    die einem bestimmten Suchmuster entsprechen. Verwendet 7-Zip für die Archivanalyse und gibt detaillierte
    Informationen über gefundene Dateien zurück, einschließlich Größe, Datum und Komprimierungsgrad.

.PARAMETER Suchbegriff
    Das Suchmuster für Dateinamen. Unterstützt Wildcards wie * und ?.
    Beispiele: "*.txt", "config*", "readme.md"

.PARAMETER Pfad
    Das Verzeichnis, in dem nach ZIP-Dateien gesucht werden soll.
    Standard: "C:\Zips"

.PARAMETER TrefferLimit
    Maximale Anzahl der zurückzugebenden Treffer. Stoppt die Suche nach Erreichen des Limits.
    Standard: 1, Minimum: 1

.PARAMETER ZipExePath
    Pfad zur 7-Zip-Executable (7z.exe).
    Standard: "C:\Program Files\7-Zip\7z.exe"

.OUTPUTS
    PSCustomObject mit folgenden Eigenschaften:
    - ZipDatei: Vollständiger Pfad zur ZIP-Datei
    - ZipName: Name der ZIP-Datei
    - Datum: Datum der Datei im Archiv
    - Attribut: Dateiattribute
    - Größe: Unkomprimierte Dateigröße in Bytes
    - Komprimiert: Komprimierte Dateigröße in Bytes
    - Dateiname: Name der gefundenen Datei

.EXAMPLE
    Find-FileInZips -Suchbegriff "*.txt"
    
    Sucht nach allen TXT-Dateien in den ZIP-Archiven im Standardverzeichnis.

.EXAMPLE
    Find-FileInZips -Suchbegriff "config*" -Pfad "C:\Archive" -TrefferLimit 5
    
    Sucht nach Dateien, die mit "config" beginnen, in ZIP-Dateien unter C:\Archive 
    und gibt maximal 5 Treffer zurück.

.EXAMPLE
    Find-FileInZips -Suchbegriff "readme.md" -Verbose
    
    Sucht nach einer spezifischen readme.md Datei mit detaillierter Ausgabe des Suchfortschritts.

.NOTES
    Autor: [Ihr Name]
    Version: 2.0
    Voraussetzungen: 7-Zip muss installiert sein
    
    Performance-Optimierungen:
    - Kompiliertes Regex für bessere Geschwindigkeit
    - Direkte Array-Verarbeitung statt Pipeline
    - Früher Ausstieg bei Erreichen des Trefferlimits
#>
function Find-FileInZips {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Suchbegriff,
        
        [string]$Pfad = "C:\Zips",
        
        [ValidateRange(1, [int]::MaxValue)]
        [int]$TrefferLimit = 1,
        
        [string]$ZipExePath = "C:\Program Files\7-Zip\7z.exe"
    )
    
    # Eingabevalidierung
    if (-not (Test-Path -Path $Pfad -PathType Container)) {
        Write-Error "Pfad nicht gefunden: $Pfad"
        return
    }
    
    if (-not (Test-Path -Path $ZipExePath -PathType Leaf)) {
        Write-Error "7-Zip nicht gefunden: $ZipExePath"
        return
    }
    
    # Optimiertes Regex-Pattern (kompiliert für bessere Performance)
    $regexPattern = [regex]::new('^(?<Date>[\d-]+\s[\d:]+)\s+(?<Attr>\S+)\s+(?<Size>\d+)\s+(?<Compressed>\d+)\s+(?<Name>.+)$', 'Compiled')
    
    $treffer = 0
    $zipDateien = Get-ChildItem -Path $Pfad -Filter "*.zip" -File
    
    if (-not $zipDateien) {
        Write-Warning "Keine ZIP-Dateien in $Pfad gefunden"
        return
    }
    
    Write-Verbose "Durchsuche $($zipDateien.Count) ZIP-Dateien nach '$Suchbegriff'"
    
    :ZipLoop foreach ($zipDatei in $zipDateien) {
        Write-Verbose "Analysiere: $($zipDatei.Name)"
        
        try {
            # Direkte Ausgabe in Variable statt Pipeline
            $output = & $ZipExePath l $zipDatei.FullName 2>$null
            
            if ($LASTEXITCODE -ne 0) {
                Write-Warning "Fehler beim Lesen von $($zipDatei.Name)"
                continue
            }
            
            # Optimierte Schleife ohne ForEach-Object Pipeline
            for ($i = 0; $i -lt $output.Length; $i++) {
                $line = $output[$i]
                $match = $regexPattern.Match($line)
                
                if ($match.Success -and $match.Groups['Name'].Value -like $Suchbegriff) {
                    [PSCustomObject]@{
                        ZipDatei    = $zipDatei.FullName
                        ZipName     = $zipDatei.Name
                        Datum       = $match.Groups['Date'].Value
                        Attribut    = $match.Groups['Attr'].Value
                        Größe       = [long]$match.Groups['Size'].Value
                        Komprimiert = [long]$match.Groups['Compressed'].Value
                        Dateiname   = $match.Groups['Name'].Value
                    }
                    
                    if (++$treffer -ge $TrefferLimit) {
                        break ZipLoop
                    }
                }
            }
        }
        catch {
            Write-Warning "Fehler beim Verarbeiten von $($zipDatei.Name): $($_.Exception.Message)"
        }
    }
    
    if ($treffer -eq 0) {
        Write-Information "Keine Treffer für '$Suchbegriff' gefunden" -InformationAction Continue
    }
}