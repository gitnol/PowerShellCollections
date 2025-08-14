#Requires -Version 7.0
# Hinweis: Benötigt Domain-Zugriff, aber kein ActiveDirectory-Modul

<#
.SYNOPSIS
PowerShell-Modul zur Überwachung von Windows 10 Computern im Active Directory

.DESCRIPTION
Dieses Modul ermittelt Windows 10 Computer im AD, pingt sie parallel und sendet
eine E-Mail mit den Online-Computern.

.AUTHOR
PowerShell 7 AD Computer Monitor
#>

# Globale Konfiguration
$Global:ModuleConfig = @{
    SMTPServer      = "smtp.company.com"
    SMTPPort        = 587
    FromAddress     = "monitoring@company.com"
    ToAddress       = @("admin@company.com")
    UseSSL          = $true
    PingTimeout     = 2000
    MaxParallelJobs = 50
    LogPath         = "$env:TEMP\Win10Monitor.log"
}

function Write-LogMessage {
    <#
    .SYNOPSIS
    Schreibt Meldungen in eine Log-Datei
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Message,
        
        [ValidateSet('INFO', 'WARNING', 'ERROR')]
        [string]$Level = 'INFO'
    )
    
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logEntry = "[$timestamp] [$Level] $Message"
    
    Write-Host $logEntry -ForegroundColor $(
        switch ($Level) {
            'INFO' { 'Green' }
            'WARNING' { 'Yellow' }
            'ERROR' { 'Red' }
        }
    )
    
    Add-Content -Path $Global:ModuleConfig.LogPath -Value $logEntry -Encoding UTF8
}

function Get-Windows10Computers {
    <#
    .SYNOPSIS
    Ermittelt alle Windows 10 Computer aus dem Active Directory
    
    .DESCRIPTION
    Diese Funktion sucht im Active Directory nach Computern mit Windows 10
    Betriebssystem. Funktioniert mit oder ohne ActiveDirectory-Modul.
    
    .PARAMETER SearchBase
    Die Organisationseinheit, in der gesucht werden soll (optional)
    
    .PARAMETER IncludeDisabled
    Gibt auch deaktivierte Computer zurück
    
    .PARAMETER Domain
    Domain-Name (wird automatisch ermittelt wenn nicht angegeben)
    
    .EXAMPLE
    Get-Windows10Computers
    
    .EXAMPLE
    Get-Windows10Computers -SearchBase "OU=Workstations,DC=company,DC=com"
    #>
    [CmdletBinding()]
    param(
        [string]$SearchBase,
        [switch]$IncludeDisabled,
        [string]$Domain
    )
    
    try {
        Write-LogMessage "Starte Suche nach Windows 10 Computern im Active Directory..."
        
        # Versuche zuerst das ActiveDirectory-Modul
        if (Get-Module -ListAvailable -Name ActiveDirectory) {
            try {
                Import-Module ActiveDirectory -ErrorAction Stop
                return Get-Windows10ComputersWithADModule -SearchBase $SearchBase -IncludeDisabled:$IncludeDisabled
            }
            catch {
                Write-LogMessage "ActiveDirectory-Modul konnte nicht verwendet werden, verwende LDAP-Fallback..." -Level WARNING
            }
        }
        
        # Fallback zu DirectorySearcher
        return Get-Windows10ComputersWithLDAP -SearchBase $SearchBase -IncludeDisabled:$IncludeDisabled -Domain $Domain
        
    }
    catch {
        Write-LogMessage "Fehler beim Abrufen der AD-Computer: $($_.Exception.Message)" -Level ERROR
        throw
    }
}

function Get-Windows10ComputersWithADModule {
    [CmdletBinding()]
    param(
        [string]$SearchBase,
        [switch]$IncludeDisabled
    )
    
    $filter = "OperatingSystem -like '*Windows 10*'"
    if (-not $IncludeDisabled) {
        $filter += " -and Enabled -eq 'True'"
    }
    
    $params = @{
        Filter     = $filter
        Properties = @('Name', 'OperatingSystem', 'OperatingSystemVersion', 'LastLogonDate', 'IPv4Address', 'Enabled', 'Description')
    }
    
    if ($SearchBase) {
        $params.SearchBase = $SearchBase
    }
    
    $computers = Get-ADComputer @params
    Write-LogMessage "Gefunden: $($computers.Count) Windows 10 Computer (ActiveDirectory-Modul)"
    return $computers
}

function Get-Windows10ComputersWithLDAP {
    [CmdletBinding()]
    param(
        [string]$SearchBase,
        [switch]$IncludeDisabled,
        [string]$Domain
    )
    
    try {
        # Domain ermitteln wenn nicht angegeben
        if (-not $Domain) {
            $Domain = [System.DirectoryServices.ActiveDirectory.Domain]::GetCurrentDomain().Name
        }
        
        # LDAP-Pfad erstellen
        $domainDN = "DC=" + ($Domain -replace "\.", ",DC=")
        $ldapPath = "LDAP://$Domain"
        if ($SearchBase) {
            $ldapPath += "/$SearchBase"
        }
        else {
            $ldapPath += "/$domainDN"
        }
        
        Write-LogMessage "Verwende LDAP-Abfrage: $ldapPath"
        
        # DirectorySearcher erstellen
        $searcher = New-Object System.DirectoryServices.DirectorySearcher
        $searcher.SearchRoot = New-Object System.DirectoryServices.DirectoryEntry($ldapPath)
        
        # LDAP-Filter für Windows 10 Computer
        $filter = "(&(objectCategory=computer)(operatingSystem=*Windows 10*))"
        if (-not $IncludeDisabled) {
            $filter = "(&(objectCategory=computer)(operatingSystem=*Windows 10*)(!(userAccountControl:1.2.840.113556.1.4.803:=2)))"
        }
        
        $searcher.Filter = $filter
        $searcher.PropertiesToLoad.AddRange(@(
                "name", "operatingSystem", "operatingSystemVersion", 
                "lastLogonTimestamp", "dNSHostName", "userAccountControl", "description"
            ))
        
        $results = $searcher.FindAll()
        
        $computers = foreach ($result in $results) {
            $props = $result.Properties
            
            # LastLogonDate konvertieren
            $lastLogon = $null
            if ($props["lastLogonTimestamp"][0]) {
                $lastLogon = [DateTime]::FromFileTime($props["lastLogonTimestamp"][0])
            }
            
            # Enabled-Status ermitteln
            $enabled = $true
            if ($props["userAccountControl"][0]) {
                $uac = $props["userAccountControl"][0]
                $enabled = -not ($uac -band 2)  # ADS_UF_ACCOUNTDISABLE
            }
            
            # IPv4-Adresse über DNS-Lookup
            $ipv4 = $null
            try {
                if ($props["dNSHostName"][0]) {
                    $ipv4 = [System.Net.Dns]::GetHostAddresses($props["dNSHostName"][0]) | 
                    Where-Object { $_.AddressFamily -eq 'InterNetwork' } | 
                    Select-Object -First 1 -ExpandProperty IPAddressToString
                }
            }
            catch {
                # DNS-Lookup fehlgeschlagen
            }
            
            # PSCustomObject erstellen (kompatibel mit AD-Modul-Ausgabe)
            [PSCustomObject]@{
                Name                   = $props["name"][0]
                OperatingSystem        = $props["operatingSystem"][0]
                OperatingSystemVersion = $props["operatingSystemVersion"][0]
                LastLogonDate          = $lastLogon
                IPv4Address            = $ipv4
                Enabled                = $enabled
                Description            = $props["description"][0]
                DNSHostName            = $props["dNSHostName"][0]
            }
        }
        
        $results.Dispose()
        $searcher.Dispose()
        
        Write-LogMessage "Gefunden: $($computers.Count) Windows 10 Computer (LDAP-Abfrage)"
        return $computers
        
    }
    catch {
        Write-LogMessage "Fehler bei LDAP-Abfrage: $($_.Exception.Message)" -Level ERROR
        throw
    }
}

function Test-ComputerConnectivity {
    <#
    .SYNOPSIS
    Testet die Erreichbarkeit von Computern parallel
    
    .DESCRIPTION
    Diese Funktion pingt eine Liste von Computern parallel und gibt nur die
    erreichbaren Computer zurück.
    
    .PARAMETER Computers
    Array von Computer-Objekten (aus Get-Windows10Computers)
    
    .PARAMETER TimeoutMs
    Ping-Timeout in Millisekunden (Standard: 2000)
    
    .PARAMETER MaxParallelJobs
    Maximale Anzahl paralleler Jobs (Standard: 50)
    
    .EXAMPLE
    $adComputers = Get-Windows10Computers
    $onlineComputers = Test-ComputerConnectivity -Computers $adComputers
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [PSCustomObject[]]$Computers,
        
        [int]$TimeoutMs = $Global:ModuleConfig.PingTimeout,
        
        [int]$MaxParallelJobs = $Global:ModuleConfig.MaxParallelJobs
    )
    
    try {
        Write-LogMessage "Starte Konnektivitätstest für $($Computers.Count) Computer (parallel mit max. $MaxParallelJobs Jobs)..."
        
        $onlineComputers = $Computers | ForEach-Object -Parallel {
            $computer = $_
            $timeout = $using:TimeoutMs
            
            try {
                $ping = Test-Connection -ComputerName $computer.Name -Count 1 -TimeoutSeconds ($timeout / 1000) -Quiet -ErrorAction Stop
                
                if ($ping) {
                    # Zusätzliche Informationen sammeln
                    try {
                        $lastBootTime = $null
                        $osVersion = $null
                        
                        # WMI-Abfrage für zusätzliche Infos (optional, kann fehlschlagen)
                        $wmi = Get-CimInstance -ComputerName $computer.Name -ClassName Win32_OperatingSystem -ErrorAction SilentlyContinue
                        if ($wmi) {
                            $lastBootTime = $wmi.LastBootUpTime
                            $osVersion = $wmi.Version
                        }
                    }
                    catch {
                        # Ignoriere WMI-Fehler, Ping war erfolgreich
                    }
                    
                    [PSCustomObject]@{
                        ComputerName           = $computer.Name
                        OperatingSystem        = $computer.OperatingSystem
                        OperatingSystemVersion = $computer.OperatingSystemVersion
                        OSVersionDetailed      = $osVersion
                        LastLogonDate          = $computer.LastLogonDate
                        LastBootTime           = $lastBootTime
                        IPv4Address            = $computer.IPv4Address
                        Enabled                = $computer.Enabled
                        Description            = $computer.Description
                        PingSuccess            = $true
                        TestTimestamp          = Get-Date
                    }
                }
            }
            catch {
                # Computer nicht erreichbar - kein Objekt zurückgeben
            }
        } -ThrottleLimit $MaxParallelJobs
        
        $onlineCount = ($onlineComputers | Measure-Object).Count
        Write-LogMessage "Konnektivitätstest abgeschlossen. Online: $onlineCount von $($Computers.Count) Computern"
        
        return $onlineComputers
        
    }
    catch {
        Write-LogMessage "Fehler beim Konnektivitätstest: $($_.Exception.Message)" -Level ERROR
        throw
    }
}

function Send-ComputerStatusMail {
    <#
    .SYNOPSIS
    Sendet eine E-Mail mit dem Computer-Status
    
    .DESCRIPTION
    Diese Funktion sendet eine formatierte E-Mail mit den Online-Computer-Informationen.
    Verwendet moderne .NET-Klassen für sicheren SMTP-Versand.
    
    .PARAMETER ComputerData
    Array von PSCustomObject mit Computer-Informationen
    
    .PARAMETER SMTPConfig
    Hashtable mit SMTP-Konfiguration
    
    .PARAMETER Subject
    E-Mail-Betreff (optional)
    
    .PARAMETER IncludeCSVAttachment
    Fügt CSV-Datei als Anhang hinzu
    
    .EXAMPLE
    $config = @{
        SMTPServer = "smtp.company.com"
        SMTPPort = 587
        FromAddress = "monitoring@company.com"
        ToAddress = @("admin@company.com")
        UseSSL = $true
        Credential = $credential
    }
    Send-ComputerStatusMail -ComputerData $onlineComputers -SMTPConfig $config
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [PSCustomObject[]]$ComputerData,
        
        [hashtable]$SMTPConfig = $Global:ModuleConfig,
        
        [string]$Subject = "Windows 10 Computer Status Report - $(Get-Date -Format 'dd.MM.yyyy HH:mm')",
        
        [switch]$IncludeCSVAttachment
    )
    
    try {
        Write-LogMessage "Bereite E-Mail-Versand vor (moderne .NET-Methode)..."
        
        # HTML-Inhalt erstellen
        $htmlBody = @"
<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <title>Windows 10 Computer Status</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; }
        .header { background-color: #4472C4; color: white; padding: 15px; border-radius: 5px; }
        .summary { background-color: #E7F3FF; padding: 10px; margin: 15px 0; border-radius: 5px; }
        table { border-collapse: collapse; width: 100%; margin: 15px 0; }
        th, td { border: 1px solid #ddd; padding: 8px; text-align: left; }
        th { background-color: #4472C4; color: white; }
        tr:nth-child(even) { background-color: #f2f2f2; }
        .footer { margin-top: 20px; font-size: 0.9em; color: #666; }
    </style>
</head>
<body>
    <div class="header">
        <h2>Windows 10 Computer Status Report</h2>
        <p>Erstellt am: $(Get-Date -Format 'dd.MM.yyyy HH:mm:ss')</p>
    </div>
    
    <div class="summary">
        <h3>Zusammenfassung</h3>
        <ul>
            <li><strong>Online Computer:</strong> $($ComputerData.Count)</li>
            <li><strong>Letzter Scan:</strong> $(Get-Date -Format 'dd.MM.yyyy HH:mm:ss')</li>
        </ul>
    </div>
    
    <h3>Computer Details</h3>
    <table>
        <tr>
            <th>Computer Name</th>
            <th>Betriebssystem</th>
            <th>Letzte Anmeldung</th>
            <th>Letzter Neustart</th>
            <th>IP-Adresse</th>
            <th>Beschreibung</th>
        </tr>
"@
        
        foreach ($computer in $ComputerData) {
            $lastLogon = if ($computer.LastLogonDate) { $computer.LastLogonDate.ToString('dd.MM.yyyy HH:mm') } else { "Unbekannt" }
            $lastBoot = if ($computer.LastBootTime) { $computer.LastBootTime.ToString('dd.MM.yyyy HH:mm') } else { "Unbekannt" }
            $description = if ($computer.Description) { $computer.Description } else { "-" }
            
            $htmlBody += @"
        <tr>
            <td>$($computer.ComputerName)</td>
            <td>$($computer.OperatingSystem)</td>
            <td>$lastLogon</td>
            <td>$lastBoot</td>
            <td>$($computer.IPv4Address)</td>
            <td>$description</td>
        </tr>
"@
        }
        
        $htmlBody += @"
    </table>
    
    <div class="footer">
        <p>Dieser Report wurde automatisch generiert.</p>
    </div>
</body>
</html>
"@

        # CSV-Anhang erstellen (optional)
        $csvPath = $null
        if ($IncludeCSVAttachment -and $ComputerData.Count -gt 0) {
            $csvPath = "$env:TEMP\Win10Computers_$(Get-Date -Format 'yyyyMMdd_HHmm').csv"
            $ComputerData | Export-Csv -Path $csvPath -NoTypeInformation -Encoding UTF8 -Delimiter ";"
            Write-LogMessage "CSV-Anhang erstellt: $csvPath"
        }
        
        # Moderne .NET SMTP-Client verwenden
        Send-SecureEmail -SMTPConfig $SMTPConfig -Subject $Subject -HtmlBody $htmlBody -AttachmentPath $csvPath
        
        # Temporäre CSV-Datei löschen
        if ($csvPath -and (Test-Path $csvPath)) {
            Remove-Item $csvPath -Force
        }
        
    }
    catch {
        Write-LogMessage "Fehler beim E-Mail-Versand: $($_.Exception.Message)" -Level ERROR
        throw
    }
}

function Send-SecureEmail {
    <#
    .SYNOPSIS
    Sendet E-Mail mit moderner .NET SmtpClient-Klasse
    
    .DESCRIPTION
    Verwendet System.Net.Mail.SmtpClient für sicheren E-Mail-Versand mit
    korrekter Authentifizierung und SSL/TLS-Unterstützung.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [hashtable]$SMTPConfig,
        
        [Parameter(Mandatory)]
        [string]$Subject,
        
        [Parameter(Mandatory)]
        [string]$HtmlBody,
        
        [string]$AttachmentPath
    )
    
    try {
        # .NET SMTP-Client erstellen
        $smtpClient = New-Object System.Net.Mail.SmtpClient($SMTPConfig.SMTPServer, $SMTPConfig.SMTPPort)
        
        # SSL/TLS konfigurieren
        if ($SMTPConfig.UseSSL) {
            $smtpClient.EnableSsl = $true
            # Moderne TLS-Versionen erzwingen
            [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12 -bor [System.Net.SecurityProtocolType]::Tls13
        }
        
        # Authentifizierung
        if ($SMTPConfig.Credential) {
            $smtpClient.Credentials = $SMTPConfig.Credential.GetNetworkCredential()
        }
        
        # E-Mail-Nachricht erstellen
        $mailMessage = New-Object System.Net.Mail.MailMessage
        $mailMessage.From = New-Object System.Net.Mail.MailAddress($SMTPConfig.FromAddress)
        
        # Empfänger hinzufügen
        foreach ($recipient in $SMTPConfig.ToAddress) {
            $mailMessage.To.Add($recipient)
        }
        
        $mailMessage.Subject = $Subject
        $mailMessage.Body = $HtmlBody
        $mailMessage.IsBodyHtml = $true
        $mailMessage.BodyEncoding = [System.Text.Encoding]::UTF8
        $mailMessage.SubjectEncoding = [System.Text.Encoding]::UTF8
        
        # Anhang hinzufügen (optional)
        if ($AttachmentPath -and (Test-Path $AttachmentPath)) {
            $attachment = New-Object System.Net.Mail.Attachment($AttachmentPath)
            $mailMessage.Attachments.Add($attachment)
        }
        
        # E-Mail senden
        $smtpClient.Send($mailMessage)
        Write-LogMessage "E-Mail erfolgreich gesendet an: $($SMTPConfig.ToAddress -join ', ')"
        
        # Ressourcen freigeben
        if ($attachment) { $attachment.Dispose() }
        $mailMessage.Dispose()
        $smtpClient.Dispose()
        
    }
    catch {
        # Detaillierte Fehlermeldung
        $errorDetails = $_.Exception.Message
        if ($_.Exception.InnerException) {
            $errorDetails += " | Inner: $($_.Exception.InnerException.Message)"
        }
        
        Write-LogMessage "SMTP-Fehler: $errorDetails" -Level ERROR
        
        # Häufige Probleme und Lösungsvorschläge
        if ($errorDetails -match "authentication|authenticated") {
            Write-LogMessage "Tipp: Überprüfen Sie Benutzername/Passwort und App-Passwort (falls 2FA aktiviert)" -Level WARNING
        }
        if ($errorDetails -match "secure connection|SSL|TLS") {
            Write-LogMessage "Tipp: Überprüfen Sie SSL/TLS-Einstellungen und Port (587 für STARTTLS, 465 für SSL)" -Level WARNING
        }
        
        throw
    }
    finally {
        # Sicherstellen, dass Ressourcen freigegeben werden
        if ($attachment) { 
            try { $attachment.Dispose() } catch { }
        }
        if ($mailMessage) { 
            try { $mailMessage.Dispose() } catch { }
        }
        if ($smtpClient) { 
            try { $smtpClient.Dispose() } catch { }
        }
    }
}

function Invoke-Windows10ComputerMonitoring {
    <#
    .SYNOPSIS
    Führt den kompletten Monitoring-Prozess aus
    
    .DESCRIPTION
    Diese Hauptfunktion orchestriert den gesamten Prozess:
    1. AD-Computer ermitteln
    2. Konnektivität testen
    3. E-Mail senden
    
    .PARAMETER SearchBase
    AD-Suchbasis (optional)
    
    .PARAMETER SMTPCredential
    Anmeldedaten für SMTP-Server
    
    .PARAMETER IncludeDisabled
    Deaktivierte Computer einschließen
    
    .PARAMETER SendCSVAttachment
    CSV-Datei als Anhang senden
    
    .EXAMPLE
    # Einfache Ausführung
    Invoke-Windows10ComputerMonitoring
    
    .EXAMPLE
    # Mit Anmeldedaten und CSV-Anhang
    $cred = Get-Credential
    Invoke-Windows10ComputerMonitoring -SMTPCredential $cred -SendCSVAttachment
    
    .EXAMPLE
    # Spezifische OU und erweiterte Optionen
    Invoke-Windows10ComputerMonitoring -SearchBase "OU=Workstations,DC=company,DC=com" -IncludeDisabled -SendCSVAttachment
    #>
    [CmdletBinding()]
    param(
        [string]$SearchBase,
        [PSCredential]$SMTPCredential,
        [switch]$IncludeDisabled,
        [switch]$SendCSVAttachment
    )
    
    try {
        Write-LogMessage "=== Starte Windows 10 Computer Monitoring ==="
        
        # SMTP-Konfiguration aktualisieren
        if ($SMTPCredential) {
            $Global:ModuleConfig.Credential = $SMTPCredential
        }
        
        # 1. AD-Computer ermitteln
        $params = @{}
        if ($SearchBase) { $params.SearchBase = $SearchBase }
        if ($IncludeDisabled) { $params.IncludeDisabled = $true }
        
        $adComputers = Get-Windows10Computers @params
        
        if ($adComputers.Count -eq 0) {
            Write-LogMessage "Keine Windows 10 Computer gefunden. Prozess beendet." -Level WARNING
            return
        }
        
        # 2. Konnektivität testen
        $onlineComputers = Test-ComputerConnectivity -Computers $adComputers
        
        if ($onlineComputers.Count -eq 0) {
            Write-LogMessage "Keine Computer online. E-Mail wird trotzdem gesendet." -Level WARNING
            $onlineComputers = @()
        }
        
        # 3. E-Mail senden
        $mailParams = @{
            ComputerData = $onlineComputers
            SMTPConfig   = $Global:ModuleConfig
        }
        if ($SendCSVAttachment) { $mailParams.IncludeCSVAttachment = $true }
        
        Send-ComputerStatusMail @mailParams
        
        Write-LogMessage "=== Windows 10 Computer Monitoring erfolgreich abgeschlossen ==="
        Write-LogMessage "Ergebnis: $($onlineComputers.Count) von $($adComputers.Count) Computern online"
        
        # Rückgabe für weitere Verarbeitung
        return [PSCustomObject]@{
            TotalComputers   = $adComputers.Count
            OnlineComputers  = $onlineComputers.Count
            OfflineComputers = $adComputers.Count - $onlineComputers.Count
            ComputerData     = $onlineComputers
            Timestamp        = Get-Date
        }
        
    }
    catch {
        Write-LogMessage "Kritischer Fehler im Monitoring-Prozess: $($_.Exception.Message)" -Level ERROR
        throw
    }
}

function Set-MonitoringConfiguration {
    <#
    .SYNOPSIS
    Konfiguriert die Modul-Einstellungen
    
    .DESCRIPTION
    Ermöglicht die Anpassung der globalen Konfiguration
    
    .EXAMPLE
    Set-MonitoringConfiguration -SMTPServer "smtp.newserver.com" -FromAddress "newmonitoring@company.com"
    #>
    [CmdletBinding()]
    param(
        [string]$SMTPServer,
        [int]$SMTPPort,
        [string]$FromAddress,
        [string[]]$ToAddress,
        [switch]$UseSSL,
        [int]$PingTimeout,
        [int]$MaxParallelJobs,
        [string]$LogPath
    )
    
    if ($SMTPServer) { $Global:ModuleConfig.SMTPServer = $SMTPServer }
    if ($SMTPPort) { $Global:ModuleConfig.SMTPPort = $SMTPPort }
    if ($FromAddress) { $Global:ModuleConfig.FromAddress = $FromAddress }
    if ($ToAddress) { $Global:ModuleConfig.ToAddress = $ToAddress }
    if ($PSBoundParameters.ContainsKey('UseSSL')) { $Global:ModuleConfig.UseSSL = $UseSSL }
    if ($PingTimeout) { $Global:ModuleConfig.PingTimeout = $PingTimeout }
    if ($MaxParallelJobs) { $Global:ModuleConfig.MaxParallelJobs = $MaxParallelJobs }
    if ($LogPath) { $Global:ModuleConfig.LogPath = $LogPath }
    
    Write-LogMessage "Konfiguration aktualisiert"
}

function Test-SMTPConfiguration {
    <#
    .SYNOPSIS
    Testet die SMTP-Konfiguration
    
    .DESCRIPTION
    Sendet eine Test-E-Mail um die SMTP-Einstellungen zu überprüfen
    
    .PARAMETER SMTPConfig
    SMTP-Konfiguration zum Testen
    
    .EXAMPLE
    Test-SMTPConfiguration -SMTPConfig $Global:ModuleConfig
    #>
    [CmdletBinding()]
    param(
        [hashtable]$SMTPConfig = $Global:ModuleConfig
    )
    
    try {
        Write-Host "Teste SMTP-Konfiguration..." -ForegroundColor Yellow
        Write-Host "Server: $($SMTPConfig.SMTPServer):$($SMTPConfig.SMTPPort)" -ForegroundColor Gray
        Write-Host "SSL: $($SMTPConfig.UseSSL)" -ForegroundColor Gray
        Write-Host "Von: $($SMTPConfig.FromAddress)" -ForegroundColor Gray
        Write-Host "An: $($SMTPConfig.ToAddress -join ', ')" -ForegroundColor Gray
        
        $testBody = @"
<!DOCTYPE html>
<html>
<head><meta charset="UTF-8"><title>SMTP Test</title></head>
<body>
    <h2>SMTP-Konfiguration Test</h2>
    <p>Diese Test-E-Mail wurde am <strong>$(Get-Date -Format 'dd.MM.yyyy HH:mm:ss')</strong> gesendet.</p>
    <p>Ihre SMTP-Konfiguration funktioniert korrekt!</p>
    <hr>
    <small>Windows 10 Computer Monitor - PowerShell 7</small>
</body>
</html>
"@
        
        Send-SecureEmail -SMTPConfig $SMTPConfig -Subject "SMTP Test - $(Get-Date -Format 'HH:mm:ss')" -HtmlBody $testBody
        Write-Host "✓ SMTP-Test erfolgreich!" -ForegroundColor Green
        
    }
    catch {
        Write-Host "✗ SMTP-Test fehlgeschlagen: $($_.Exception.Message)" -ForegroundColor Red
        throw
    }
}

function Get-CommonSMTPSettings {
    <#
    .SYNOPSIS
    Zeigt häufige SMTP-Einstellungen für bekannte Provider
    
    .DESCRIPTION
    Hilft bei der Konfiguration für Gmail, Outlook, Exchange, etc.
    #>
    
    $providers = @{
        "Gmail"                        = @{
            SMTPServer = "smtp.gmail.com"
            SMTPPort   = 587
            UseSSL     = $true
            Note       = "App-Passwort erforderlich wenn 2FA aktiviert"
        }
        "Outlook/Hotmail"              = @{
            SMTPServer = "smtp-mail.outlook.com" 
            SMTPPort   = 587
            UseSSL     = $true
            Note       = "App-Passwort empfohlen"
        }
        "Exchange Online (Office 365)" = @{
            SMTPServer = "smtp.office365.com"
            SMTPPort   = 587  
            UseSSL     = $true
            Note       = "Modern Auth oder App-Passwort"
        }
        "Exchange On-Premises"         = @{
            SMTPServer = "mail.company.com"
            SMTPPort   = 587
            UseSSL     = $true
            Note       = "Interne Exchange-Adresse verwenden"
        }
        "Yahoo"                        = @{
            SMTPServer = "smtp.mail.yahoo.com"
            SMTPPort   = 587
            UseSSL     = $true
            Note       = "App-Passwort erforderlich"
        }
    }
    
    Write-Host "`nHäufige SMTP-Einstellungen:" -ForegroundColor Yellow
    Write-Host "=" * 50 -ForegroundColor Yellow
    
    foreach ($provider in $providers.GetEnumerator()) {
        Write-Host "`n$($provider.Key):" -ForegroundColor Cyan
        Write-Host "  Server: $($provider.Value.SMTPServer)" -ForegroundColor White
        Write-Host "  Port: $($provider.Value.SMTPPort)" -ForegroundColor White  
        Write-Host "  SSL: $($provider.Value.UseSSL)" -ForegroundColor White
        Write-Host "  Hinweis: $($provider.Value.Note)" -ForegroundColor Gray
    }
    
    Write-Host "`nBeispiel-Konfiguration:" -ForegroundColor Yellow
    Write-Host @"
`$credential = Get-Credential
Set-MonitoringConfiguration -SMTPServer "smtp.gmail.com" -SMTPPort 587 -UseSSL -FromAddress "monitoring@gmail.com" -ToAddress @("admin@company.com")
`$Global:ModuleConfig.Credential = `$credential
Test-SMTPConfiguration
"@ -ForegroundColor White
}

# Export-ModuleMember aktualisieren
Export-ModuleMember -Function @(
    'Get-Windows10Computers',
    'Test-ComputerConnectivity', 
    'Send-ComputerStatusMail',
    'Invoke-Windows10ComputerMonitoring',
    'Set-MonitoringConfiguration',
    'Test-SMTPConfiguration',
    'Get-CommonSMTPSettings'
)

# Willkommensmeldung
Write-Host "Windows 10 AD Computer Monitor geladen. Verwenden Sie 'Invoke-Windows10ComputerMonitoring' zum Starten." -ForegroundColor Green