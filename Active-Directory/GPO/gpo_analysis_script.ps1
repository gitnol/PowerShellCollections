# GPO Settings Analysis Script
# Analysiert alle GPOs und vergleicht den Status mit tatsächlichen Einstellungen

# Import GroupPolicy Module
Import-Module GroupPolicy -ErrorAction Stop

# Funktion zum Analysieren der XML-Inhalte
function Test-GPOXmlSettings {
    param(
        [xml]$XmlContent
    )
    
    $result = @{
        HasUserSettings     = $false
        HasComputerSettings = $false
    }
    
    # Prüfe User-Einstellungen
    if ($XmlContent.GPO.User) {
        # Prüfe auf Extensions (Administrative Templates, Registry, etc.)
        if ($XmlContent.GPO.User.ExtensionData) {
            $result.HasUserSettings = $true
        }
        # Prüfe auf Security Settings
        if ($XmlContent.GPO.User.SecuritySettings) {
            $result.HasUserSettings = $true
        }
    }
    
    # Prüfe Computer-Einstellungen
    if ($XmlContent.GPO.Computer) {
        # Prüfe auf Extensions (Administrative Templates, Registry, etc.)
        if ($XmlContent.GPO.Computer.ExtensionData) {
            $result.HasComputerSettings = $true
        }
        # Prüfe auf Security Settings
        if ($XmlContent.GPO.Computer.SecuritySettings) {
            $result.HasComputerSettings = $true
        }
    }
    
    return $result
}

# Funktion zum Vergleichen der Status
function Compare-GPOStatus {
    param(
        $GPOStatus,
        $XmlHasUserSettings,
        $XmlHasComputerSettings
    )
    
    $comparison = @{
        StatusMatch    = $false
        ExpectedStatus = ""
        ActualStatus   = $GPOStatus
        Recommendation = ""
    }
    
    # Bestimme erwarteten Status basierend auf XML-Inhalt
    if ($XmlHasUserSettings -and $XmlHasComputerSettings) {
        $comparison.ExpectedStatus = "AllSettingsEnabled"
    }
    elseif ($XmlHasUserSettings -and -not $XmlHasComputerSettings) {
        $comparison.ExpectedStatus = "ComputerSettingsDisabled"
    }
    elseif (-not $XmlHasUserSettings -and $XmlHasComputerSettings) {
        $comparison.ExpectedStatus = "UserSettingsDisabled"
    }
    else {
        $comparison.ExpectedStatus = "AllSettingsDisabled"
    }
    
    # Vergleiche Status
    $comparison.StatusMatch = ($comparison.ExpectedStatus -eq $GPOStatus)
    
    # Empfehlung bei Mismatch
    if (-not $comparison.StatusMatch) {
        $comparison.Recommendation = "Status sollte auf '$($comparison.ExpectedStatus)' gesetzt werden"
    }
    else {
        $comparison.Recommendation = "Status ist korrekt konfiguriert"
    }
    
    return $comparison
}

# Hauptschleife - Alle GPOs durchlaufen
Write-Host "Starte GPO-Analyse..." -ForegroundColor Green
Write-Host "=" * 80

$allGPOs = Get-GPO -All
$results = @()

foreach ($gpo in $allGPOs) {
    Write-Host "Analysiere GPO: $($gpo.DisplayName)" -ForegroundColor Yellow
    
    try {
        # XML Report abrufen
        $xmlReport = Get-GPOReport -Guid $gpo.Id -ReportType Xml
        $xmlContent = [xml]$xmlReport
        
        # XML-Inhalte analysieren
        $xmlSettings = Test-GPOXmlSettings -XmlContent $xmlContent
        
        # Status vergleichen
        $statusComparison = Compare-GPOStatus -GPOStatus $gpo.GpoStatus -XmlHasUserSettings $xmlSettings.HasUserSettings -XmlHasComputerSettings $xmlSettings.HasComputerSettings
        
        # Ergebnis sammeln
        $result = [PSCustomObject]@{
            GPOName                  = $gpo.DisplayName
            GPOId                    = $gpo.Id
            CurrentStatus            = $gpo.GpoStatus
            HasUserSettingsInXML     = $xmlSettings.HasUserSettings
            HasComputerSettingsInXML = $xmlSettings.HasComputerSettings
            ExpectedStatus           = $statusComparison.ExpectedStatus
            StatusMatch              = $statusComparison.StatusMatch
            Recommendation           = $statusComparison.Recommendation
            CreationTime             = $gpo.CreationTime
            ModificationTime         = $gpo.ModificationTime
        }
        
        $results += $result
        
        # Fortschritt anzeigen
        if (-not $result.StatusMatch) {
            Write-Host "  ⚠️  Status-Mismatch gefunden!" -ForegroundColor Red
            Write-Host "     Aktuell: $($result.CurrentStatus), Erwartet: $($result.ExpectedStatus)" -ForegroundColor Red
        }
        else {
            Write-Host "  ✅ Status korrekt" -ForegroundColor Green
        }
    }
    catch {
        Write-Host "  ❌ Fehler beim Verarbeiten von GPO $($gpo.DisplayName): $($_.Exception.Message)" -ForegroundColor Red
        
        $result = [PSCustomObject]@{
            GPOName                  = $gpo.DisplayName
            GPOId                    = $gpo.Id
            CurrentStatus            = $gpo.GpoStatus
            HasUserSettingsInXML     = "ERROR"
            HasComputerSettingsInXML = "ERROR"
            ExpectedStatus           = "ERROR"
            StatusMatch              = "ERROR"
            Recommendation           = "Fehler beim Analysieren: $($_.Exception.Message)"
            CreationTime             = $gpo.CreationTime
            ModificationTime         = $gpo.ModificationTime
        }
        
        $results += $result
    }
}

Write-Host "" + "=" * 80
Write-Host "ZUSAMMENFASSUNG" -ForegroundColor Cyan
Write-Host "=" * 80

# Statistiken
$totalGPOs = $results.Count
$matchingGPOs = ($results | Where-Object { $_.StatusMatch -eq $true }).Count
$mismatchGPOs = ($results | Where-Object { $_.StatusMatch -eq $false }).Count
$errorGPOs = ($results | Where-Object { $_.StatusMatch -eq "ERROR" }).Count

Write-Host "Gesamt GPOs analysiert: $totalGPOs"
Write-Host "Status korrekt: $matchingGPOs" -ForegroundColor Green
Write-Host "Status-Mismatch: $mismatchGPOs" -ForegroundColor Red
Write-Host "Fehler bei Analyse: $errorGPOs" -ForegroundColor Yellow

# Detaillierte Ergebnisse anzeigen
Write-Host "DETAILLIERTE ERGEBNISSE:" -ForegroundColor Cyan
Write-Host "-" * 80

$results | Format-Table -Property GPOName, CurrentStatus, ExpectedStatus, StatusMatch, HasUserSettingsInXML, HasComputerSettingsInXML -AutoSize

# GPOs mit Problemen hervorheben
$problemGPOs = $results | Where-Object { $_.StatusMatch -eq $false -or $_.StatusMatch -eq "ERROR" }
if ($problemGPOs.Count -gt 0) {
    Write-Host "GPOs MIT PROBLEMEN:" -ForegroundColor Red
    Write-Host "-" * 80
    
    foreach ($problem in $problemGPOs) {
        Write-Host "GPO: $($problem.GPOName)" -ForegroundColor Yellow
        Write-Host "  Status: $($problem.CurrentStatus) -> Sollte sein: $($problem.ExpectedStatus)"
        Write-Host "  Empfehlung: $($problem.Recommendation)"
        Write-Host "  User Settings in XML: $($problem.HasUserSettingsInXML)"
        Write-Host "  Computer Settings in XML: $($problem.HasComputerSettingsInXML)"
        Write-Host ""
    }
}

# Ergebnisse in CSV exportieren (optional)
$exportPath = "GPO_Analysis_$(Get-Date -Format 'yyyyMMdd_HHmmss').csv"
$results | Export-Csv -LiteralPath $exportPath -NoTypeInformation -Encoding UTF8 -Delimiter ";" -
Write-Host "Ergebnisse exportiert nach: $exportPath" -ForegroundColor Green

Write-Host "Analyse abgeschlossen!" -ForegroundColor Green