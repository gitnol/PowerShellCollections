#requires -modules ActiveDirectory

<#
.SYNOPSIS
    Automatisiert temporäre und permanente Active Directory-Gruppenmitgliedschaften basierend auf CSV-Dateien.

.DESCRIPTION
    Version 3.0: Refactored mit externer Konfiguration, Datei-Logging und Entfernungsfunktion.

    Dieses PowerShell-Script verwaltet zeitlich begrenzte AD-Gruppenmitgliedschaften. Es liest eine Konfigurationsdatei (config.json)
    und CSV-Dateien mit Benutzerzuordnungen ein, validiert die Daten und fügt Benutzer zu AD-Gruppen hinzu oder entfernt sie.
    
    Das Script unterstützt:
    - Externe Konfiguration via config.json
    - Zeitgesteuerte Gruppenmitgliedschaften (Von-/Bis-Datum) mittels PAM-Feature (-MemberTimeToLive)
    - Gezieltes Entfernen von Gruppenmitgliedschaften
    - Detailliertes Logging in Konsole UND eine Log-Datei
    - Status-Tracking in der CSV-Datei

.NOTES
    Autor: IT-Administration / Überarbeitet durch Gemini
    Version: 3.0
    Voraussetzungen:
    - PowerShell 5.1 oder höher
    - ActiveDirectory PowerShell-Modul
    - Ausführung auf einem System mit AD-Verwaltungstools
    - Ein Service-Account mit delegierten Rechten zum Ändern von Gruppenmitgliedschaften wird empfohlen.

.INPUTS
    1. config.json - NEU: Zentrale Konfigurationsdatei. Wird beim ersten Start automatisch erstellt.
    
    2. test_ad_user_gruppen.csv - Hauptdatei mit Benutzerzuordnungen.
    Format: Username;Action;VonDatum;BisDatum;Abteilung;Erledigt;DatumErledigung;MeldungStatus
    
    Beispiel:
    "Username";"Action";"VonDatum";"BisDatum";"Abteilung";"Erledigt";"DatumErledigung";"MeldungStatus"
    "m.mustermann";"Add";"01.10.2025";"30.11.2025";"IT";"";"";""
    "s.beispiel";"Remove";"";"";"Buchhaltung";"";"";""
    
    Die Spalte "Action" ist optional. Wenn sie fehlt oder leer ist, wird "Add" angenommen.
    
    3. Abteilung_zu_Gruppen_Zuordnung.csv - Mapping Abteilung zu AD-Gruppen (ohne Header).
    
    4. Azubi_Accounts_Gueltig.csv - Liste gültiger Benutzerkonten (ohne Header).

.OUTPUTS
    - Aktualisierte CSV-Datei mit Status-Updates.
    - Log-Datei mit allen Ausgaben.
    - Generierte Abteilungsliste (Abteilungsliste_gueltig.txt).
#>

#region Konfiguration & Initialisierung
# Globale Variable für die Konfiguration
$Global:Config = $null

function Initialize-Configuration {
    param(
        [string]$ScriptRoot
    )
    
    $configPath = Join-Path $ScriptRoot "config.json"
    
    if (-not (Test-Path $configPath)) {
        Write-Host "[WARNUNG] Konfigurationsdatei 'config.json' nicht gefunden." -ForegroundColor Yellow
        Write-Host "[INFO] Erstelle eine neue Konfigurationsdatei mit Standardwerten..." -ForegroundColor Cyan
        
        $defaultConfig = @{
            MaxDaysForTempGroup = 365
            DateFormat          = "dd.MM.yyyy"
            CSVDelimiter        = ";"
            Encoding            = "UTF8"
            DebugMode           = $true
            LogFilePath         = ".\temp_groups.log"
            Files               = @{
                UserAssignments   = ".\test_ad_user_gruppen.csv"
                DepartmentMapping = ".\Abteilung_zu_Gruppen_Zuordnung.csv"
                ValidAccounts     = ".\Azubi_Accounts_Gueltig.csv"
                DepartmentList    = ".\Abteilungsliste_gueltig.txt"
            }
        }
        
        $defaultConfig | ConvertTo-Json -Depth 3 | Set-Content -Path $configPath -Encoding UTF8
        
        Write-Host "[ERFOLG] 'config.json' wurde erstellt. Bitte passe die Pfade bei Bedarf an und starte das Skript erneut." -ForegroundColor Green
        return $false
    }
    
    try {
        $configContent = Get-Content -Path $configPath -Raw | ConvertFrom-Json
        
        # Relative Pfade aus der Config-Datei immer relativ zum Skript-Verzeichnis auflösen
        $configContent.LogFilePath = if ([System.IO.Path]::IsPathRooted($configContent.LogFilePath)) { $configContent.LogFilePath } else { Join-Path $ScriptRoot $configContent.LogFilePath }
        foreach ($key in $configContent.Files.PSObject.Properties.Name) {
            $path = $configContent.Files.$key
            $configContent.Files.$key = if ([System.IO.Path]::IsPathRooted($path)) { $path } else { Join-Path $ScriptRoot $path }
        }
        
        $Global:Config = $configContent
        return $true
    }
    catch {
        Write-Host "[FEHLER] Die Konfigurationsdatei 'config.json' konnte nicht gelesen oder verarbeitet werden: $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
}
#endregion

#region Logging-Funktionen
function Write-ProcessLog {
    param(
        [Parameter(Mandatory)]
        [string]$Message,
        [ValidateSet("Info", "Success", "Warning", "Error", "Debug")]
        [string]$Level = "Info"
    )
    
    if ($Level -eq "Debug" -and ($null -eq $Config -or -not $Config.DebugMode)) {
        return
    }
    
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logMessage = "[$timestamp] [$Level] $Message"
    
    $colorMap = @{ "Error" = "Red"; "Warning" = "Yellow"; "Success" = "Green"; "Info" = "Cyan"; "Debug" = "Gray" }
    Write-Host $logMessage -ForegroundColor $colorMap[$Level]
    
    if ($null -ne $Config.LogFilePath) {
        try {
            Add-Content -Path $Config.LogFilePath -Value $logMessage
        }
        catch {
            Write-Host "[$timestamp] [FEHLER] Konnte nicht in die Log-Datei schreiben: $($_.Exception.Message)" -ForegroundColor Red
        }
    }
}

function Write-Separator {
    $separator = ("-" * 50)
    Write-Host $separator -ForegroundColor Gray
    if ($null -ne $Config.LogFilePath) {
        Add-Content -Path $Config.LogFilePath -Value $separator
    }
}
#endregion

#region Validierungs- & AD-Funktionen
function Test-Prerequisites {
    param([hashtable]$Files)
    
    Write-ProcessLog "Überprüfe Voraussetzungen..." -Level Info
    
    # Alle definierten Dateien müssen existieren
    foreach ($fileKey in $Files.Keys) {
        $filePath = $Files[$fileKey]
        # Die Abteilungsliste wird generiert, daher wird ihre Existenz nicht geprüft
        if ($fileKey -eq "DepartmentList") { continue }
        
        if (-not (Test-Path -LiteralPath $filePath -PathType Leaf)) {
            Write-ProcessLog "Erforderliche Datei nicht gefunden: $filePath" -Level Error
            exit 1
        }
    }
    
    Write-ProcessLog "Alle erforderlichen Dateien gefunden" -Level Success
}

function Test-ADPrincipalExists {
    param([string]$SamAccountName)
    try {
        Get-ADUser -Identity $SamAccountName -ErrorAction Stop | Out-Null
        return $true
    }
    catch [Microsoft.ActiveDirectory.Management.ADIdentityNotFoundException] {
        try {
            Get-ADGroup -Identity $SamAccountName -ErrorAction Stop | Out-Null
            return $true
        }
        catch { return $false }
    }
    catch {
        Write-ProcessLog "Fehler bei der AD-Suche für '$($SamAccountName)': $($_.Exception.Message)" -Level Warning
        return $false
    }
}

function Test-DateString {
    param([string]$DateString)
    if ([string]::IsNullOrWhiteSpace($DateString)) { return $false }
    try {
        [DateTime]::ParseExact($DateString, $Config.DateFormat, $null) | Out-Null
        return $true
    }
    catch { return $false }
}

function Test-DateRange {
    param(
        [string]$StartDateString,
        [string]$EndDateString
    )
    
    if (-not (Test-DateString $StartDateString)) { return $false, "Ungültiges Von-Datum: ${StartDateString}" }
    if (-not (Test-DateString $EndDateString)) { return $false, "Ungültiges Bis-Datum: ${EndDateString}" }
    
    try {
        $startDate = [DateTime]::ParseExact($StartDateString, $Config.DateFormat, $null)
        $endDate = [DateTime]::ParseExact($EndDateString, $Config.DateFormat, $null)
        
        if ($startDate -ge $endDate) { return $false, "Von-Datum muss vor Bis-Datum liegen" }
        
        $duration = ($endDate - $startDate).Days
        if ($duration -gt $Config.MaxDaysForTempGroup) { return $false, "Zeitraum überschreitet Maximum von $($Config.MaxDaysForTempGroup) Tagen" }
        
        return $true, ""
    }
    catch { return $false, "Fehler beim Verarbeiten der Datumswerte: $($_.Exception.Message)" }
}

function Test-PAMFeature {
    try {
        $pamFeature = Get-ADOptionalFeature -Filter "name -eq 'privileged access management feature'" -ErrorAction Stop
        return $pamFeature.EnabledScopes.Count -gt 0
    }
    catch {
        Write-ProcessLog "Fehler beim Prüfen der PAM-Feature: $($_.Exception.Message)" -Level Warning
        return $false
    }
}
#endregion

#region Daten-Import-Funktionen
function Import-ConfigurationData {
    param([hashtable]$Files)
    
    Write-ProcessLog "Importiere Konfigurationsdaten..." -Level Info
    try {
        $departmentData = Import-Csv -Delimiter $Config.CSVDelimiter -Path $Files.DepartmentMapping -Header "Abteilung", "ADGruppe"
        $departmentMapping = $departmentData | Group-Object -Property Abteilung -AsHashTable
        
        $validAccountsData = Import-Csv -Delimiter $Config.CSVDelimiter -Path $Files.ValidAccounts -Header "Username"
        $validAccounts = @($validAccountsData.Username)
        
        $departmentList = $departmentData.Abteilung | Sort-Object -Unique
        $departmentList | Out-File -FilePath $Files.DepartmentList -Encoding $Config.Encoding
        
        Write-ProcessLog "Konfigurationsdaten erfolgreich importiert" -Level Success
        Write-ProcessLog "Abteilungen: $($departmentList.Count), Gültige Accounts: $($validAccounts.Count)" -Level Info
        
        return @{
            DepartmentMapping = $departmentMapping
            ValidAccounts     = $validAccounts
            DepartmentList    = $departmentList
        }
    }
    catch {
        Write-ProcessLog "Fehler beim Importieren der Konfigurationsdaten: $($_.Exception.Message)" -Level Error
        throw
    }
}

function Import-UserAssignments {
    param([string]$FilePath)
    
    Write-ProcessLog "Importiere Benutzerzuordnungen aus: $FilePath" -Level Info
    try {
        $userData = Import-Csv -Path $FilePath -Delimiter $Config.CSVDelimiter -Encoding $Config.Encoding
        $count = if ($userData) { @($userData).Count } else { 0 }
        Write-ProcessLog "Benutzerzuordnungen erfolgreich importiert: ${count} Einträge" -Level Success
        return $userData
    }
    catch {
        Write-ProcessLog "Fehler beim Importieren der Benutzerzuordnungen: $($_.Exception.Message)" -Level Error
        throw
    }
}
#endregion

#region Gruppenmitgliedschafts-Funktionen
function Add-TempGroupMembership {
    param(
        [Parameter(Mandatory)][string]$Username,
        [Parameter(Mandatory)][string]$GroupName,
        [Parameter(Mandatory)][DateTime]$EndDate
    )
    
    $now = Get-Date
    Write-ProcessLog "Debug: Add-TempGroupMembership aufgerufen - User: ${Username}, Gruppe: ${GroupName}, EndDate: $EndDate" -Level Debug
    
    if ($EndDate -le $now) {
        return $false, "End-Datum liegt in der Vergangenheit"
    }
    
    try {
        $isAlreadyMember = (Get-ADGroupMember -Identity $GroupName).SamAccountName -contains $Username
        if ($isAlreadyMember) {
            Write-ProcessLog "Benutzer ${Username} ist bereits Mitglied der Gruppe ${GroupName}" -Level Warning
            return $false, "Benutzer ist bereits Mitglied der Gruppe"
        }
    }
    catch {
        Write-ProcessLog "Fehler beim Prüfen der Gruppenmitglieder von '${GroupName}': $($_.Exception.Message)" -Level Warning
    }
    
    try {
        $timeSpan = $EndDate - $now
        $timeSpanOhneMs = New-TimeSpan -Days $timeSpan.Days -Hours $timeSpan.Hours -Minutes $timeSpan.Minutes -Seconds $timeSpan.Seconds
        
        Write-ProcessLog "Debug: Führe Add-ADGroupMember für '${GroupName}' mit MemberTimeToLive '${timeSpanOhneMs}' aus" -Level Debug
        Add-ADGroupMember -Identity $GroupName -Members $Username -MemberTimeToLive $timeSpanOhneMs -ErrorAction Stop
        
        return $true, "Temporäre Mitgliedschaft bis $EndDate erfolgreich erstellt"
    }
    catch {
        Write-ProcessLog "Fehler beim Hinzufügen von ${Username} zu ${GroupName}: $($_.Exception.Message)" -Level Error
        return $false, "AD-Fehler: $($_.Exception.Message)"
    }
}

function Add-UserToAllDepartmentGroups {
    param(
        [Parameter(Mandatory)][string]$Username,
        [Parameter(Mandatory)][string]$Department,
        [Parameter(Mandatory)][DateTime]$EndDate,
        [Parameter(Mandatory)][hashtable]$DepartmentMapping
    )
    
    $results = @()
    $groups = $DepartmentMapping[$Department]
    
    if (-not $groups) {
        return @{ Success = $false; Message = "Abteilung '$Department' nicht in Stammdaten gefunden"; Details = @() }
    }
    
    foreach ($groupInfo in $groups) {
        $groupName = $groupInfo.ADGruppe
        if (-not (Test-ADPrincipalExists $groupName)) {
            Write-ProcessLog "AD-Gruppe existiert nicht: ${groupName}" -Level Warning
            $results += @{ Group = $groupName; Success = $false; Message = "Gruppe existiert nicht im AD" }
            continue
        }
        
        $success, $message = Add-TempGroupMembership -Username $Username -GroupName $groupName -EndDate $EndDate
        $results += @{ Group = $groupName; Success = $success; Message = $message }
    }
    
    $successfulItems = @($results | Where-Object { $_.Success })
    $successCount = $successfulItems.Count
    $totalCount = $results.Count
    
    $message = if ($successCount -eq $totalCount) { "Alle Gruppenmitgliedschaften erfolgreich erstellt ($successCount/$totalCount)" }
    elseif ($successCount -gt 0) { "Teilweise erfolgreich: $successCount von $totalCount Gruppenmitgliedschaften erstellt" }
    else { "Keine Gruppenmitgliedschaften konnten erstellt werden" }
    
    return @{ Success = ($successCount -gt 0); Message = $message; Details = $results }
}

function Remove-UserFromAllDepartmentGroups {
    param(
        [Parameter(Mandatory)][string]$Username,
        [Parameter(Mandatory)][string]$Department,
        [Parameter(Mandatory)][hashtable]$DepartmentMapping
    )
    
    $results = @()
    $groups = $DepartmentMapping[$Department]
    
    if (-not $groups) {
        return @{ Success = $false; Message = "Abteilung '$Department' nicht in Stammdaten gefunden" }
    }
    
    foreach ($groupInfo in $groups) {
        $groupName = $groupInfo.ADGruppe
        if (-not (Test-ADPrincipalExists $groupName)) {
            Write-ProcessLog "Gruppe '${groupName}' existiert nicht, überspringe Entfernen." -Level Warning
            continue
        }
        
        try {
            Remove-ADGroupMember -Identity $groupName -Members $Username -Confirm:$false -ErrorAction Stop
            Write-ProcessLog "Benutzer '$Username' erfolgreich aus Gruppe '$groupName' entfernt." -Level Success
            $results += @{ Group = $groupName; Success = $true; Message = "Erfolgreich entfernt" }
        }
        catch {
            Write-ProcessLog "Fehler beim Entfernen von '$Username' aus '$groupName': $($_.Exception.Message)" -Level Error
            $results += @{ Group = $groupName; Success = $false; Message = "Fehler: $($_.Exception.Message)" }
        }
    }
    
    $successfulItems = @($results | Where-Object { $_.Success })
    $successCount = $successfulItems.Count
    $totalCount = $groups.Count
    
    $message = if ($successCount -eq $totalCount) { "Alle Gruppenmitgliedschaften erfolgreich entfernt ($successCount/$totalCount)" }
    elseif ($successCount -gt 0) { "Gruppenmitgliedschaften teilweise entfernt ($successCount/$totalCount)" }
    else { "Keine Gruppenmitgliedschaften konnten entfernt werden" }
    
    return @{ Success = ($successCount -gt 0); Message = $message }
}
#endregion

#region Hauptverarbeitungs-Funktionen
function Test-UserAssignmentRow {
    param(
        [Parameter(Mandatory)][psobject]$UserRow,
        [Parameter(Mandatory)][array]$ValidAccounts,
        [Parameter(Mandatory)][array]$ValidDepartments,
        [string]$Action = "Add"
    )
    
    if ($UserRow.Erledigt -eq "X") { return $false, "Bereits erledigt", "Info" }
    if ([string]::IsNullOrWhiteSpace($UserRow.Username) -or [string]::IsNullOrWhiteSpace($UserRow.Abteilung)) { return $false, "Benutzername oder Abteilung ist leer", "Error" }
    if ($UserRow.Username -notin $ValidAccounts) { return $false, "Benutzername '$($UserRow.Username)' nicht in gültigen Accounts", "Error" }
    if (-not (Test-ADPrincipalExists $UserRow.Username)) { return $false, "AD-User '$($UserRow.Username)' existiert nicht", "Error" }
    if ($UserRow.Abteilung -notin $ValidDepartments) { return $false, "Abteilung '$($UserRow.Abteilung)' nicht in Stammdaten", "Error" }
    
    # Spezifische Tests für 'Add'-Aktion
    if ($Action -eq "Add") {
        $dateValid, $dateMessage = Test-DateRange -StartDateString $UserRow.VonDatum -EndDateString $UserRow.BisDatum
        if (-not $dateValid) { return $false, $dateMessage, "Error" }
        
        try {
            $startDate = [DateTime]::ParseExact($UserRow.VonDatum, $Config.DateFormat, $null)
            if ($startDate -gt (Get-Date)) {
                return $false, "Von-Datum noch nicht erreicht ($($UserRow.VonDatum))", "Info"
            }
        }
        catch { return $false, "Fehler beim Parsen des Von-Datums: $($_.Exception.Message)", "Error" }
    }
    
    return $true, "Validation erfolgreich", "Success"
}

function Process-UserAssignmentRow {
    param(
        [Parameter(Mandatory)][psobject]$UserRow,
        [Parameter(Mandatory)][hashtable]$ConfigData,
        [Parameter(Mandatory)][int]$RowNumber
    )
    
    $action = if ($UserRow.PSObject.Properties.Match('Action') -and -not [string]::IsNullOrWhiteSpace($UserRow.Action)) { $UserRow.Action.Trim() } else { "Add" }
    Write-ProcessLog "Verarbeite Zeile $RowNumber - User: $($UserRow.Username), Abteilung: $($UserRow.Abteilung), Aktion: $action" -Level Info
    
    $isValid, $validationMessage, $validationLevel = Test-UserAssignmentRow -UserRow $UserRow -ValidAccounts $ConfigData.ValidAccounts -ValidDepartments $ConfigData.DepartmentList -Action $action
    if (-not $isValid) {
        Write-ProcessLog $validationMessage -Level $validationLevel
        $UserRow.MeldungStatus = $validationMessage
        if ($validationLevel -ne "Info") { $UserRow.DatumErledigung = Get-Date -Format "dd.MM.yyyy HH:mm:ss" }
        return
    }
    
    $result = $null
    switch ($action) {
        "Add" {
            $endDate = [DateTime]::ParseExact($UserRow.BisDatum, $Config.DateFormat, $null).AddDays(1)
            $result = Add-UserToAllDepartmentGroups -Username $UserRow.Username -Department $UserRow.Abteilung -EndDate $endDate -DepartmentMapping $ConfigData.DepartmentMapping
        }
        "Remove" {
            $result = Remove-UserFromAllDepartmentGroups -Username $UserRow.Username -Department $UserRow.Abteilung -DepartmentMapping $ConfigData.DepartmentMapping
        }
        default {
            $result = @{ Success = $false; Message = "Ungültige Aktion: '$action'. Nur 'Add' oder 'Remove' erlaubt." }
        }
    }
    
    if ($result.Success) {
        Write-ProcessLog $result.Message -Level Success
        $UserRow.Erledigt = "X"
    }
    else {
        Write-ProcessLog $result.Message -Level Error
    }
    
    $UserRow.MeldungStatus = $result.Message
    $UserRow.DatumErledigung = Get-Date -Format "dd.MM.yyyy HH:mm:ss"
}

function Export-UserAssignments {
    param(
        [Parameter(Mandatory)][array]$UserData,
        [Parameter(Mandatory)][string]$FilePath
    )
    try {
        $UserData | Export-Csv -Path $FilePath -Delimiter $Config.CSVDelimiter -NoTypeInformation -Encoding $Config.Encoding
        Write-ProcessLog "Ergebnisse erfolgreich exportiert nach: $FilePath" -Level Success
    }
    catch {
        Write-ProcessLog "Fehler beim Export: $($_.Exception.Message)" -Level Error
        throw
    }
}
#endregion

#region Hauptfunktion
function Main {
    try {
        if (-not (Initialize-Configuration -ScriptRoot $PSScriptRoot)) { exit 1 }
        
        Write-ProcessLog "=== Temporäre AD-Gruppenmitgliedschaften v3.0 - Start ===" -Level Info
        
        Test-Prerequisites -Files $Config.Files
        $configData = Import-ConfigurationData -Files $Config.Files
        
        if (Test-PAMFeature) {
            Write-ProcessLog "Privileged Access Management (PAM) Feature ist verfügbar." -Level Success
        }
        else {
            Write-ProcessLog "KRITISCHER FEHLER: PAM Feature ist für temporäre Mitgliedschaften erforderlich, aber nicht verfügbar!" -Level Error
            exit 10
        }
        
        $userData = Import-UserAssignments -FilePath $Config.Files.UserAssignments
        if (-not $userData) {
            Write-ProcessLog "Keine Daten in der Benutzerzuordnungsdatei gefunden. Verarbeitung wird beendet." -Level Warning
            return
        }
        
        $totalCount = @($userData).Count
        Write-Separator
        Write-ProcessLog "Beginne Verarbeitung von ${totalCount} Einträgen..." -Level Info
        Write-Separator
        
        $userDataArray = @($userData)
        for ($i = 0; $i -lt $userDataArray.Count; $i++) {
            Process-UserAssignmentRow -UserRow $userDataArray[$i] -ConfigData $configData -RowNumber ($i + 1)
            Write-Separator
        }
        
        Export-UserAssignments -UserData $userDataArray -FilePath $Config.Files.UserAssignments
        
        Write-ProcessLog "=== Verarbeitung erfolgreich abgeschlossen ===" -Level Success
        
        $processedCount = (@($userDataArray) | Where-Object { $_.Erledigt -eq "X" }).Count
        Write-ProcessLog "Verarbeitete Einträge in diesem Durchlauf: ${processedCount} von ${totalCount}" -Level Info
    }
    catch {
        Write-ProcessLog "KRITISCHER FEHLER in Main: $($_.Exception.Message)" -Level Error
        Write-ProcessLog "Stack Trace: $($_.ScriptStackTrace)" -Level Error
        exit 99
    }
}
#endregion

# Skript ausführen
Main