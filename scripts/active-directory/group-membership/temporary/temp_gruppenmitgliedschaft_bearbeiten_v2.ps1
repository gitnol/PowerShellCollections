#requires -modules ActiveDirectory

<#
.SYNOPSIS
    Automatisiert temporäre Active Directory-Gruppenmitgliedschaften für Auszubildende und andere Benutzer basierend auf Abteilungszuordnungen.

.DESCRIPTION
    Dieses PowerShell-Script verwaltet zeitlich begrenzte AD-Gruppenmitgliedschaften für Benutzer (hauptsächlich Auszubildende) 
    während deren Rotation durch verschiedene Abteilungen. Es liest CSV-Dateien mit Benutzerzuordnungen ein, überprüft die 
    Gültigkeit der Daten und fügt Benutzer automatisch zu den entsprechenden Active Directory-Gruppen hinzu.
    
    Das Script kann über die Windows-Aufgabenplanung auf einem Domain-Controller ausgeführt werden und unterstützt:
    - Zeitgesteuerte Gruppenmitgliedschaften (Von-/Bis-Datum)
    - Mehrfache Gruppenzuordnungen pro Abteilung
    - Automatische Validierung von Benutzern und Gruppen
    - Detailliertes Logging und Fehlerbehandlung
    - Status-Tracking in der CSV-Datei

.PARAMETER ConfigPath
    Pfad zum Verzeichnis mit den CSV-Konfigurationsdateien.
    Standard: Script-Verzeichnis ($PSScriptRoot)

.NOTES
    Autor: IT-Administration
    Version: 2.0 (Refactored)
    Voraussetzungen:
    - PowerShell 5.1 oder höher
    - ActiveDirectory PowerShell-Modul
    - Ausführung auf Domain-Controller oder Computer mit AD-Verwaltungstools
    - Berechtigung zum Verwalten von AD-Gruppenmitgliedschaften
    
    Aufgabenplanung:
    C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe -File "Pfad\zum\Script\temp_gruppen_verarbeiten.ps1"

.INPUTS
    CSV-Dateien (siehe Beispiele für Format):
    
    1. test_ad_user_gruppen.csv - Hauptdatei mit Benutzerzuordnungen
    Format: Username;VonDatum;BisDatum;Abteilung;Erledigt;DatumErledigung;MeldungStatus
    
    Beispiel:
    "Username";"VonDatum";"BisDatum";"Abteilung";"Erledigt";"DatumErledigung";"MeldungStatus"
    "m.mustermann";"01.10.2025";"30.11.2025";"IT";"";"";"VonDatum noch nicht erreicht!"
    "s.beispiel";"15.09.2025";"15.12.2025";"Buchhaltung";"X";"02.09.2025 10:45:22";"ERFOLG! (s.beispiel zur AD-Gruppe BH_Azubis mit Gültigkeit bis 16.12.2025)"
    "a.test";"01.11.2025";"28.02.2026";"Einkauf";"";"";"VonDatum noch nicht erreicht!"
    
    2. Abteilung_zu_Gruppen_Zuordnung.csv - Mapping Abteilung zu AD-Gruppen
    Format: Abteilung;ADGruppe (ohne Header)
    
    Beispiel:
    IT;Azubis_IT_Verwaltung
    IT;ERP_IT_Benutzer
    Buchhaltung;BH_Azubis
    Buchhaltung;ERP_BH_Benutzer
    Buchhaltung;DocuWare_Benutzer
    Einkauf;EK_Azubis
    Einkauf;ERP_EK_Benutzer
    Personal;HR_Azubis
    Personal;ERP_HR_Benutzer
    Lager;LG_Azubis
    Lager;ERP_LG_Benutzer
    Produktion;PROD_Azubis
    Produktion;ERP_PROD_Benutzer
    Qualität;QM_Azubis
    Vertrieb;VK_Azubis
    Vertrieb;ERP_VK_Benutzer
    
    3. Azubi_Accounts_Gueltig.csv - Liste gültiger Benutzerkonten
    Format: Username (ohne Header, ein Username pro Zeile)
    
    Beispiel:
    m.mustermann
    s.beispiel
    a.test
    l.probe
    k.demo
    j.vorlage
    t.sample

.OUTPUTS
    - Aktualisierte CSV-Datei mit Status-Updates
    - Generierte Abteilungsliste (Abteilungsliste_gueltig.txt)
    - Konsolen-Ausgabe mit detailliertem Logging
    - Exit-Codes für Fehlerbehandlung (1-99)

.EXAMPLE
    .\temp_gruppen_verarbeiten.ps1
    
    Führt das Script mit Standard-Konfigurationspfad aus (Script-Verzeichnis).

.EXAMPLE
    .\temp_gruppen_verarbeiten.ps1 -ConfigPath "C:\Config\AD-Management"
    
    Führt das Script mit spezifischem Konfigurationspfad aus.

.EXAMPLE
    # Aufgabenplanung - Täglich um 08:00 Uhr
    Programm: C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe
    Argumente: -File "C:\Scripts\temp_gruppen_verarbeiten.ps1"
    
.LINK
    https://docs.microsoft.com/en-us/powershell/module/activedirectory/
#>

param(
    [string]$ConfigPath = $PSScriptRoot
)

#region Konfiguration
$Config = @{
    MaxDaysForTempGroup = 365
    DateFormat          = "dd.MM.yyyy"
    CSVDelimiter        = ";"
    Encoding            = "UTF8"
    DebugMode           = $true  # Für detaillierte Debug-Ausgaben
    
    # Dateipfade
    Files               = @{
        UserAssignments   = Join-Path $ConfigPath "test_ad_user_gruppen.csv"
        DepartmentMapping = Join-Path $ConfigPath "Abteilung_zu_Gruppen_Zuordnung.csv"
        ValidAccounts     = Join-Path $ConfigPath "Azubi_Accounts_Gueltig.csv"
        DepartmentList    = Join-Path $ConfigPath "Abteilungsliste_gueltig.txt"
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
    
    # Debug-Nachrichten nur anzeigen wenn DebugMode aktiviert ist
    if ($Level -eq "Debug" -and -not $Config.DebugMode) {
        return
    }
    
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logMessage = "[$timestamp] [$Level] $Message"
    
    switch ($Level) {
        "Error" { Write-Host $logMessage -ForegroundColor Red }
        "Warning" { Write-Host $logMessage -ForegroundColor Yellow }
        "Success" { Write-Host $logMessage -ForegroundColor Green }
        "Info" { Write-Host $logMessage -ForegroundColor Cyan }
        "Debug" { Write-Host $logMessage -ForegroundColor Gray }
        default { Write-Host $logMessage }
    }
}

function Write-Separator {
    Write-Host ("-" * 50) -ForegroundColor Gray
}
#endregion

#region Validierungs-Funktionen
function Test-Prerequisites {
    param([hashtable]$Files)
    
    Write-ProcessLog "Überprüfe Voraussetzungen..." -Level Info
    
    # Pflichtdateien prüfen (dürfen nicht verschoben werden)
    $mandatoryFiles = @("DepartmentMapping", "ValidAccounts")
    
    foreach ($fileKey in $mandatoryFiles) {
        $filePath = $Files[$fileKey]
        if (-not (Test-Path -LiteralPath $filePath -PathType Leaf)) {
            Write-ProcessLog "Pflichtdatei nicht gefunden: $filePath" -Level Error
            exit ($mandatoryFiles.IndexOf($fileKey) + 2)
        }
    }
    
    # User-Assignments-Datei prüfen (darf überall liegen)
    if (-not (Test-Path -LiteralPath $Files.UserAssignments -PathType Leaf)) {
        Write-ProcessLog "Benutzerzuordnungsdatei nicht gefunden: $($Files.UserAssignments)" -Level Error
        exit 1
    }
    
    Write-ProcessLog "Alle erforderlichen Dateien gefunden" -Level Success
}

function Test-DateString {
    param([string]$DateString)
    
    if ([string]::IsNullOrWhiteSpace($DateString)) {
        return $false
    }
    
    try {
        $parsedDate = [DateTime]::ParseExact($DateString, $Config.DateFormat, $null)
        return $true
    }
    catch {
        return $false
    }
}

function Test-DateRange {
    param(
        [string]$StartDateString,
        [string]$EndDateString
    )
    
    if (-not (Test-DateString $StartDateString)) {
        return $false, "Ungültiges Von-Datum: ${StartDateString}"
    }
    
    if (-not (Test-DateString $EndDateString)) {
        return $false, "Ungültiges Bis-Datum: ${EndDateString}"
    }
    
    try {
        $startDate = [DateTime]::ParseExact($StartDateString, $Config.DateFormat, $null)
        $endDate = [DateTime]::ParseExact($EndDateString, $Config.DateFormat, $null)
        
        if ($startDate -ge $endDate) {
            return $false, "Von-Datum muss vor Bis-Datum liegen"
        }
        
        $duration = ($endDate - $startDate).Days
        if ($duration -gt $Config.MaxDaysForTempGroup) {
            return $false, "Zeitraum überschreitet Maximum von $($Config.MaxDaysForTempGroup) Tagen"
        }
        
        return $true, ""
    }
    catch {
        return $false, "Fehler beim Verarbeiten der Datumswerte: $($_.Exception.Message)"
    }
}

function Test-ADUserOrGroup {
    param(
        [Parameter(Mandatory)]
        [string]$SamAccountName
    )
    
    try {
        $result = ([ADSISearcher]"(sAMAccountName=$SamAccountName)").FindOne()
        return $null -ne $result
    }
    catch {
        Write-ProcessLog "Fehler bei AD-Suche für '${SamAccountName}': $($_.Exception.Message)" -Level Warning
        return $false
    }
}
#endregion

#region Daten-Import-Funktionen
function Import-ConfigurationData {
    param([hashtable]$Files)
    
    Write-ProcessLog "Importiere Konfigurationsdaten..." -Level Info
    
    try {
        # Abteilungs-zu-Gruppen-Zuordnung importieren und als Hashtable gruppieren
        $departmentData = Import-Csv -Delimiter $Config.CSVDelimiter -Path $Files.DepartmentMapping -Header "Abteilung", "ADGruppe"
        $departmentMapping = $departmentData | Group-Object -Property Abteilung -AsHashTable
        
        # Gültige Benutzerkonten importieren
        $validAccountsData = Import-Csv -Delimiter $Config.CSVDelimiter -Path $Files.ValidAccounts -Header "Username"
        $validAccounts = @($validAccountsData.Username)
        
        # Abteilungsliste für externe Nutzung generieren
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
    
    Write-ProcessLog "Importiere Benutzerzuordnungen..." -Level Info
    Write-ProcessLog "Dateipfad: ${FilePath}" -Level Info
    
    try {
        # Erst mal schauen was in der Datei steht
        $fileContent = Get-Content -Path $FilePath -Encoding $Config.Encoding -ErrorAction Stop
        Write-ProcessLog "Datei enthält $($fileContent.Count) Zeilen" -Level Info
        Write-ProcessLog "Erste Zeile: $($fileContent[0])" -Level Info
        if ($fileContent.Count -gt 1) {
            Write-ProcessLog "Zweite Zeile: $($fileContent[1])" -Level Info
        }
        
        # CSV direkt importieren - PowerShell erkennt automatisch die Header
        $userData = Import-Csv -Path $FilePath -Delimiter $Config.CSVDelimiter -Encoding $Config.Encoding -ErrorAction Stop
        
        Write-ProcessLog "Import-Csv Ergebnis-Typ: $($userData.GetType().FullName)" -Level Info
        if ($userData) {
            Write-ProcessLog "Erstes Element: Username='$($userData[0].Username)', VonDatum='$($userData[0].VonDatum)'" -Level Info
        }
        
        $count = if ($userData -is [array]) { $userData.Count } elseif ($userData) { 1 } else { 0 }
        Write-ProcessLog "Benutzerzuordnungen erfolgreich importiert: ${count} Einträge" -Level Success
        return $userData
    }
    catch {
        Write-ProcessLog "Fehler beim Importieren der Benutzerzuordnungen: $($_.Exception.Message)" -Level Error
        Write-ProcessLog "Fehlerdetails: $($_.Exception.GetType().FullName)" -Level Error
        throw
    }
}
#endregion

#region Gruppenmitgliedschafts-Funktionen
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

function Add-TempGroupMembership {
    param(
        [Parameter(Mandatory)]
        [string]$Username,
        
        [Parameter(Mandatory)]
        [string]$GroupName,
        
        [Parameter(Mandatory)]
        [DateTime]$EndDate
    )
    
    $now = Get-Date
    
    Write-ProcessLog "Debug: Add-TempGroupMembership aufgerufen - User: ${Username}, Gruppe: ${GroupName}, EndDate: $EndDate" -Level Debug
    
    if ($EndDate -le $now) {
        Write-ProcessLog "End-Datum $EndDate liegt in der Vergangenheit für User ${Username}" -Level Warning
        return $false, "End-Datum liegt in der Vergangenheit"
    }
    
    try {
        # Prüfen ob PAM Feature verfügbar ist - KRITISCH!
        $pamAvailable = Test-PAMFeature
        Write-ProcessLog "Debug: PAM verfügbar: ${pamAvailable}" -Level Info
        
        if (-not $pamAvailable) {
            Write-ProcessLog "KRITISCHER FEHLER: PAM Feature nicht verfügbar - Gruppenmitgliedschaft wird NICHT erstellt!" -Level Error
            return $false, "PAM Feature nicht verfügbar - Sicherheitsrichtlinie verhindert normale Gruppenmitgliedschaften"
        }
        
        # TimeSpan berechnen und Details loggen
        $timeSpan = $EndDate - $now
        Write-ProcessLog "Debug: TimeSpan berechnet - Tage: $($timeSpan.Days), Stunden: $($timeSpan.Hours), Minuten: $($timeSpan.Minutes), Gesamtminuten: $($timeSpan.TotalMinutes)" -Level Info
        $timeSpanOhneMs = New-TimeSpan -Days $timeSpan.Days -Hours $timeSpan.Hours -Minutes $timeSpan.Minutes -Seconds $timeSpan.Seconds
        
        # Prüfen ob Benutzer bereits in Gruppe ist
        try {
            $currentMembers = Get-ADGroupMember -Identity $GroupName -ErrorAction Stop
            $isAlreadyMember = $currentMembers | Where-Object { $_.SamAccountName -eq $Username }
            if ($isAlreadyMember) {
                Write-ProcessLog "WARNUNG: User ${Username} ist bereits Mitglied der Gruppe ${GroupName}" -Level Warning
                return $false, "Benutzer ist bereits Mitglied der Gruppe"
            }
        }
        catch {
            Write-ProcessLog "Fehler beim Prüfen der aktuellen Gruppenmitglieder: $($_.Exception.Message)" -Level Warning
        }
        
        # Versuch mit detailliertem Logging
        Write-ProcessLog "Debug: Führe Add-ADGroupMember aus mit Parameters:" -Level Debug
        Write-ProcessLog "  -Identity: ${GroupName}" -Level Debug
        Write-ProcessLog "  -Members: ${Username}" -Level Debug
        # Write-ProcessLog "  -MemberTimeToLive: $timeSpan" -Level Debug
        Write-ProcessLog "  -MemberTimeToLive: $timeSpanOhneMs" -Level Debug # Logge den korrigierten Wert
        Add-ADGroupMember -Identity $GroupName -Members $Username -MemberTimeToLive $timeSpanOhneMs -ErrorAction Stop -Verbose
        
        Write-ProcessLog "Temporäre Mitgliedschaft erfolgreich hinzugefügt: ${Username} -> ${GroupName} (bis $EndDate)" -Level Success
        return $true, "Temporäre Mitgliedschaft bis $EndDate erfolgreich erstellt"
    }
    catch {
        Write-ProcessLog "Fehler beim Hinzufügen von ${Username} zu ${GroupName}: $($_.Exception.Message)" -Level Error
        Write-ProcessLog "Fehler-Typ: $($_.Exception.GetType().FullName)" -Level Error
        Write-ProcessLog "Fehler-Details: $($_.Exception.ToString())" -Level Error
        if ($_.Exception.InnerException) {
            Write-ProcessLog "Inner Exception: $($_.Exception.InnerException.Message)" -Level Error
        }
        return $false, "AD-Fehler: $($_.Exception.Message)"
    }
}

function Add-UserToAllDepartmentGroups {
    param(
        [Parameter(Mandatory)]
        [string]$Username,
        
        [Parameter(Mandatory)]
        [string]$Department,
        
        [Parameter(Mandatory)]
        [DateTime]$EndDate,
        
        [Parameter(Mandatory)]
        [hashtable]$DepartmentMapping
    )
    
    $results = @()
    $groups = $DepartmentMapping[$Department]
    
    if (-not $groups) {
        return @{
            Success = $false
            Message = "Abteilung '$Department' nicht in Stammdaten gefunden"
            Details = @()
        }
    }
    
    foreach ($groupInfo in $groups) {
        $groupName = $groupInfo.ADGruppe
        
        if ([string]::IsNullOrWhiteSpace($groupName)) {
            continue
        }
        
        if (-not (Test-ADUserOrGroup $groupName)) {
            Write-ProcessLog "AD-Gruppe existiert nicht: ${groupName}" -Level Warning
            $results += @{
                Group   = $groupName
                Success = $false
                Message = "Gruppe existiert nicht im AD"
            }
            continue
        }
        
        $success, $message = Add-TempGroupMembership -Username $Username -GroupName $groupName -EndDate $EndDate
        $results += @{
            Group   = $groupName
            Success = $success
            Message = $message
        }
    }
    
    $successfulItems = @($results | Where-Object { $_.Success })
    $successCount = $successfulItems.Count
	
    $totalCount = $results.Count
    
    return @{
        Success = $successCount -gt 0
        Message = if ($successCount -eq $totalCount) {
            "Alle Gruppenmitgliedschaften erfolgreich erstellt ($successCount/$totalCount)"
        }
        elseif ($successCount -gt 0) {
            "Teilweise erfolgreich: $successCount von $totalCount Gruppenmitgliedschaften erstellt"
        }
        else {
            "Keine Gruppenmitgliedschaften konnten erstellt werden"
        }
        Details = $results
    }
}
#endregion

#region Hauptverarbeitungs-Funktionen
function Test-UserAssignmentRow {
    param(
        [Parameter(Mandatory)]
        [psobject]$UserRow,
        
        [Parameter(Mandatory)]
        [array]$ValidAccounts,
        
        [Parameter(Mandatory)]
        [array]$ValidDepartments
    )
    
    # Bereits erledigt?
    if ($UserRow.Erledigt -eq "X") {
        return $false, "Bereits erledigt", "Info"
    }
    
    # Pflichtfelder prüfen
    if ([string]::IsNullOrWhiteSpace($UserRow.Username) -or 
        [string]::IsNullOrWhiteSpace($UserRow.Abteilung)) {
        return $false, "Benutzername oder Abteilung ist leer", "Error"
    }
    
    # Gültiger Account?
    if ($UserRow.Username -notin $ValidAccounts) {
        return $false, "Benutzername '$($UserRow.Username)' nicht in gültigen Accounts", "Error"
    }
    
    # AD-User existiert?
    if (-not (Test-ADUserOrGroup $UserRow.Username)) {
        return $false, "AD-User '$($UserRow.Username)' existiert nicht", "Error"
    }
    
    # Abteilung gültig?
    if ($UserRow.Abteilung -notin $ValidDepartments) {
        return $false, "Abteilung '$($UserRow.Abteilung)' nicht in Stammdaten", "Error"
    }
    
    # Datumsbereich prüfen
    $dateValid, $dateMessage = Test-DateRange -StartDateString $UserRow.VonDatum -EndDateString $UserRow.BisDatum
    if (-not $dateValid) {
        return $false, $dateMessage, "Error"
    }
    
    # Startzeitpunkt erreicht?
    try {
        $startDate = [DateTime]::ParseExact($UserRow.VonDatum, $Config.DateFormat, $null)
        $today = Get-Date
        
        if ($startDate -gt $today) {
            return $false, "Von-Datum noch nicht erreicht ($($UserRow.VonDatum))", "Info"
        }
    }
    catch {
        return $false, "Fehler beim Parsen des Von-Datums: $($_.Exception.Message)", "Error"
    }
    
    return $true, "Validation erfolgreich", "Success"
}

function Process-UserAssignmentRow {
    param(
        [Parameter(Mandatory)]
        [psobject]$UserRow,
        
        [Parameter(Mandatory)]
        [hashtable]$ConfigData,
        
        [Parameter(Mandatory)]
        [int]$RowNumber
    )
    
    Write-ProcessLog "Verarbeite Zeile $RowNumber - User: $($UserRow.Username), Abteilung: $($UserRow.Abteilung)" -Level Info
    
    # Validierung
    $isValid, $validationMessage, $validationLevel = Test-UserAssignmentRow -UserRow $UserRow -ValidAccounts $ConfigData.ValidAccounts -ValidDepartments $ConfigData.DepartmentList
    
    if (-not $isValid) {
        Write-ProcessLog $validationMessage -Level $validationLevel
        
        if ($validationLevel -eq "Error") {
            $UserRow.MeldungStatus = $validationMessage
            $UserRow.DatumErledigung = Get-Date -Format "dd.MM.yyyy HH:mm:ss"
        }
        else {
            $UserRow.MeldungStatus = $validationMessage
        }
        
        return
    }
    
    # Gruppenmitgliedschaften hinzufügen
    try {
        $endDate = [DateTime]::ParseExact($UserRow.BisDatum, $Config.DateFormat, $null).AddDays(1)
        $result = Add-UserToAllDepartmentGroups -Username $UserRow.Username -Department $UserRow.Abteilung -EndDate $endDate -DepartmentMapping $ConfigData.DepartmentMapping
        
        if ($result.Success) {
            Write-ProcessLog $result.Message -Level Success
            $UserRow.Erledigt = "X"
            $UserRow.MeldungStatus = $result.Message
            $UserRow.DatumErledigung = Get-Date -Format "dd.MM.yyyy HH:mm:ss"
        }
        else {
            Write-ProcessLog $result.Message -Level Error
            $UserRow.MeldungStatus = $result.Message
            $UserRow.DatumErledigung = Get-Date -Format "dd.MM.yyyy HH:mm:ss"
        }
    }
    catch {
        Write-ProcessLog "Fehler beim Parsen des Bis-Datums: $($_.Exception.Message)" -Level Error
        $UserRow.MeldungStatus = "Fehler beim Parsen des Bis-Datums: $($_.Exception.Message)"
        $UserRow.DatumErledigung = Get-Date -Format "dd.MM.yyyy HH:mm:ss"
    }
}

function Export-UserAssignments {
    param(
        [Parameter(Mandatory)]
        [array]$UserData,
        
        [Parameter(Mandatory)]
        [string]$FilePath
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
        Write-ProcessLog "=== Temporäre AD-Gruppenmitgliedschaften - Start ===" -Level Info
        
        # Voraussetzungen prüfen
        Test-Prerequisites -Files $Config.Files
        
        # Konfigurationsdaten laden
        $configData = Import-ConfigurationData -Files $Config.Files
        
        # PAM Feature Status prüfen - KRITISCH für Script-Funktionalität
        $pamAvailable = Test-PAMFeature
        if ($pamAvailable) {
            Write-ProcessLog "Privileged Access Management (PAM) Feature ist verfügbar - Script kann fortfahren" -Level Success
        }
        else {
            Write-ProcessLog "KRITISCHER FEHLER: PAM Feature nicht verfügbar!" -Level Error
            Write-ProcessLog "Dieses Script erstellt AUSSCHLIESSLICH temporäre Gruppenmitgliedschaften." -Level Error
            Write-ProcessLog "Ohne PAM können keine temporären Mitgliedschaften erstellt werden." -Level Error
            Write-ProcessLog "LÖSUNG: Aktivieren Sie PAM mit: Enable-ADOptionalFeature 'Privileged Access Management Feature' -Scope ForestOrConfigurationSet -Target IhreDomain.com" -Level Error
            Write-ProcessLog "Script wird beendet." -Level Error
            exit 10
        }
        
        # Benutzerzuordnungen laden
        $userData = Import-UserAssignments -FilePath $Config.Files.UserAssignments
        
        # Korrekte Anzahl bestimmen
        $totalCount = if ($userData -is [array]) { $userData.Count } elseif ($userData) { 1 } else { 0 }
        
        Write-Separator
        Write-ProcessLog "Beginne Verarbeitung von ${totalCount} Einträgen..." -Level Info
        Write-Separator
        
        # Jede Zeile verarbeiten
        if ($totalCount -gt 0) {
            if ($userData -is [array]) {
                for ($i = 0; $i -lt $userData.Count; $i++) {
                    Process-UserAssignmentRow -UserRow $userData[$i] -ConfigData $configData -RowNumber ($i + 1)
                    Write-Separator
                }
            }
            else {
                # Nur ein Element
                Process-UserAssignmentRow -UserRow $userData -ConfigData $configData -RowNumber 1
                Write-Separator
            }
        }
        else {
            Write-ProcessLog "Keine Daten zu verarbeiten gefunden!" -Level Warning
        }
        
        # Ergebnisse exportieren
        Export-UserAssignments -UserData $userData -FilePath $Config.Files.UserAssignments
        
        Write-ProcessLog "=== Verarbeitung erfolgreich abgeschlossen ===" -Level Success
        
        # Zusammenfassung ausgeben
        $processedCount = if ($userData -is [array]) { 
            ($userData | Where-Object { $_.Erledigt -eq "X" }).Count 
        }
        elseif ($userData -and $userData.Erledigt -eq "X") { 
            1 
        }
        else { 
            0 
        }
        Write-ProcessLog "Verarbeitete Einträge: ${processedCount} von ${totalCount}" -Level Info
        
    }
    catch {
        Write-ProcessLog "Kritischer Fehler: $($_.Exception.Message)" -Level Error
        Write-ProcessLog "Stack Trace: $($_.ScriptStackTrace)" -Level Error
        exit 99
    }
}
#endregion

# Script ausführen
if ($MyInvocation.InvocationName -ne '.') {
    Main
}