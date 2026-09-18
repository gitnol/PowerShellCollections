function Compress-FilesByMonth {
    param (
        [Parameter(Mandatory = $true)]
        [bool]$Confirm,

        [Parameter(Mandatory = $true)]
        [string]$SourceDir,

        [Parameter(Mandatory = $true)]
        [string]$DestDir,

        [Parameter(Mandatory = $true)]
        [string]$Filter
    )

    # Überprüfen, ob das Quellverzeichnis existiert
    if (-not (Test-Path $SourceDir)) {
        Write-Host "Fehler: Das Quellverzeichnis '$SourceDir' existiert nicht." -ForegroundColor Red
        return
    }

    # Zielverzeichnis erstellen, falls es nicht existiert
    if (-not (Test-Path $DestDir)) {
        New-Item -ItemType Directory -Path $DestDir | Out-Null
    }

    # Alle passenden Dateien abrufen
    $files = Get-ChildItem -Path $SourceDir -Filter $Filter -File

    # Prüfen, ob Dateien vorhanden sind
    if ($files.Count -eq 0) {
        Write-Host "Keine passenden Dateien mit dem Filter '$Filter' gefunden im Verzeichnis '$SourceDir'." -ForegroundColor Yellow
        return
    }

    # Dateien nach Monat gruppieren
    $groups = $files | Group-Object { $_.LastWriteTime.ToString("yyyy-MM") }

    foreach ($group in $groups) {
        $month = $group.Name
        $archiveName = Join-Path $DestDir "$month.zip"
        $filesToCompress = $group.Group.FullName

        try {
            # Dateien komprimieren (mit Update-Option)
            Compress-Archive -Path $filesToCompress -DestinationPath $archiveName -Update
            Start-Sleep -Seconds 2  # Kurze Verzögerung, um sicherzustellen, dass das Archiv erstellt wurde

            # Überprüfen, ob das Archiv erfolgreich erstellt wurde
            if (Test-Path $archiveName) {
                Write-Host "Archiv '$archiveName' erfolgreich erstellt." -ForegroundColor Green

                # Dateien nach der Archivierung löschen (wenn bestätigt)
                if ($Confirm) {
                    Remove-Item -Path $filesToCompress -Force -Confirm:$Confirm
                } else {
                    Remove-Item -Path $filesToCompress -Force
                }
                Write-Host "Dateien erfolgreich gelöscht." -ForegroundColor Cyan
            } else {
                Write-Host "Fehler: Archiv '$archiveName' wurde nicht erstellt. Dateien werden nicht gelöscht!" -ForegroundColor Red
            }
        } catch {
            Write-Host "Fehler beim Verarbeiten von '$month': $_" -ForegroundColor Red
        }
    }
}

# Beispielaufruf der Funktion
Compress-FilesByMonth -Confirm $false -SourceDir "D:\XML_TEST" -DestDir "D:\XML_TEST\gepackt" -Filter "*.bak"
