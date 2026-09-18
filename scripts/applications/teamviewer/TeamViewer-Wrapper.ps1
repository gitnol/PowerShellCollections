function Start-TeamViewer {
    <#
    .SYNOPSIS
    Startet TeamViewer mit verschiedenen Konfigurationsoptionen und Verbindungsparametern.
    
    .DESCRIPTION
    Diese Funktion bietet eine PowerShell-Schnittstelle für die TeamViewer Command Line Interface.
    Sie unterstützt alle wichtigen Parameter wie Verbindungs-ID, Passwort, Verbindungsmodus,
    Qualitätseinstellungen, Proxy-Konfiguration und verschiedene Dateitypen.
    
    .PARAMETER ExePath
    Pfad zur TeamViewer.exe. Standard: "$Env:ProgramFiles\TeamViewer\TeamViewer.exe"
    
    .PARAMETER Minimize
    Startet TeamViewer minimiert in der Taskleiste
    
    .PARAMETER ID
    Partner-ID für die TeamViewer-Verbindung
    
    .PARAMETER Password
    Passwort für die Verbindung (SecureString)
    
    .PARAMETER PasswordB64
    Base64-kodiertes Passwort für die Verbindung (SecureString)
    
    .PARAMETER Mode
    Verbindungsmodus: 'remoteControl' (Standard), 'fileTransfer', oder 'vpn'
    
    .PARAMETER Quality
    Verbindungsqualität: '0' (Auto), '1' (Optimized Speed), '2' (Optimized Quality)
    
    .PARAMETER AccessControl
    Zugriffskontrollstufe von 0 (Vollzugriff) bis 9 (Undefiniert)
    
    .PARAMETER NoInstallation
    Startet TeamViewer im portablen Modus ohne Installation
    
    .PARAMETER PlayFile
    Pfad zu einer TeamViewer Session-Datei (*.tvs) zum Abspielen
    
    .PARAMETER ControlFile
    Pfad zu einer TeamViewer Control-Datei (*.tvc) für Verbindungen
    
    .PARAMETER ProxyIP
    Proxy-Server im Format 'IP:Port' (z.B. '192.168.1.1:8080')
    
    .PARAMETER ProxyUser
    Benutzername für Proxy-Authentifizierung
    
    .PARAMETER ProxyPassword
    Passwort für Proxy-Authentifizierung (SecureString) (SecureString)
    
    .PARAMETER SendTo
    Array von Dateipfaden zum Senden an einen Partner
    
    .EXAMPLE
    Start-TeamViewer -Minimize
    Startet TeamViewer minimiert
    
    .EXAMPLE
    $securePassword = ConvertTo-SecureString "mypassword" -AsPlainText -Force
    Start-TeamViewer -ID 123456789 -Password $securePassword
    Stellt eine Remote Control-Verbindung mit ID und sicherem Passwort her
    
    .EXAMPLE
    $securePasswordB64 = ConvertTo-SecureString "bXlwYXNzd29yZA==" -AsPlainText -Force
    Start-TeamViewer -ID 123456789 -PasswordB64 $securePasswordB64 -Mode vpn -Quality 2
    Stellt eine VPN-Verbindung mit Base64-Passwort und hoher Qualität her
    
    .EXAMPLE
    Start-TeamViewer -PlayFile "C:\Sessions\backup.tvs"
    Spielt eine gespeicherte TeamViewer-Session ab
    
    .EXAMPLE
    Start-TeamViewer -SendTo @("C:\file1.txt", "C:\file2.pdf")
    Sendet Dateien an einen Partner (Partner-Auswahl wird angezeigt)
    
    .EXAMPLE
    $proxyPassword = ConvertTo-SecureString "proxypass" -AsPlainText -Force
    $teamviewerPassword = ConvertTo-SecureString "abc" -AsPlainText -Force
    Start-TeamViewer -ID 123456789 -Password $teamviewerPassword -ProxyIP "192.168.1.1:8080" -ProxyUser "admin" -ProxyPassword $proxyPassword
    Verbindung über Proxy-Server mit Authentifizierung
    
    .NOTES
    Basiert auf TeamViewer Command Line Parameters:
    https://www.teamviewer.com/cs/global/support/knowledge-base/teamviewer-classic/for-developers/command-line-parameters/
    
    Erfordert TeamViewer (Classic) Version 13.2 oder höher für alle Parameter.
    
    .LINK
    https://www.teamviewer.com/
    #>
    [CmdletBinding()]
    param(
        # Pfad zur TeamViewer.exe
        [string] $ExePath = "$Env:ProgramFiles\TeamViewer\TeamViewer.exe",
        
        # TeamViewer minimiert starten
        [switch] $Minimize,
        
        # Partner-ID für Verbindung
        [string] $ID,
        
        # Passwort für Verbindung (SecureString)
        [SecureString] $Password,
        
        # Passwort Base64-kodiert (SecureString)
        [SecureString] $PasswordB64,
        
        # Verbindungsmodus
        [ValidateSet('fileTransfer', 'vpn', 'remoteControl')]
        [string] $Mode = 'remoteControl',
        
        # Verbindungsqualität
        [ValidateSet('0', '1', '2')]
        [string] $Quality,
        
        # Zugriffskontrolle
        [ValidateRange(0, 9)]
        [int] $AccessControl,
        
        # Portabler Modus ohne Installation
        [switch] $NoInstallation,
        
        # TeamViewer Session-Datei abspielen (*.tvs)
        [string] $PlayFile,
        
        # Control-Datei für Verbindung (*.tvc)
        [string] $ControlFile,
        
        # Proxy-Konfiguration
        [string] $ProxyIP,
        [string] $ProxyUser,
        [SecureString] $ProxyPassword,
        
        # Dateien an Partner senden
        [string[]] $SendTo
    )
    
    # Validierungen
    if (-not (Test-Path $ExePath)) {
        throw "TeamViewer executable not found at: $ExePath"
    }
    
    if ($PlayFile -and -not (Test-Path $PlayFile)) {
        throw "Play file not found: $PlayFile"
    }
    
    if ($ControlFile -and -not (Test-Path $ControlFile)) {
        throw "Control file not found: $ControlFile"
    }
    
    if ($Password -and $PasswordB64) {
        throw "Cannot specify both Password and PasswordB64"
    }
    
    if ($ProxyIP -and $ProxyIP -notmatch '^\d+\.\d+\.\d+\.\d+:\d+$') {
        throw "ProxyIP must be in format 'IP:Port'"
    }
    
    # Argument-Liste erstellen
    $argumentList = [System.Collections.Generic.List[string]]::new()
    
    # Basis-Parameter
    if ($Minimize) { $argumentList.Add('--Minimize') }
    if ($NoInstallation) { $argumentList.Add('--noInstallation') }
    
    # Verbindungs-Parameter
    if ($ID) {
        $argumentList.Add('--id')
        $argumentList.Add($ID)
        
        # Passwort hinzufügen
        if ($Password) {
            $argumentList.Add('--Password')
            $argumentList.Add([System.Runtime.InteropServices.Marshal]::PtrToStringAuto([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($Password)))
        }
        elseif ($PasswordB64) {
            $argumentList.Add('--PasswordB64') 
            $argumentList.Add([System.Runtime.InteropServices.Marshal]::PtrToStringAuto([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($PasswordB64)))
        }
        
        # Modus (nur wenn nicht Standard)
        if ($Mode -and $Mode -ne 'remoteControl') {
            $argumentList.Add('--mode')
            $argumentList.Add($Mode)
        }
        
        # Qualität
        if ($Quality) {
            $argumentList.Add("--quality$Quality")
        }
        
        # Zugriffskontrolle
        if ($PSBoundParameters.ContainsKey('AccessControl')) {
            $argumentList.Add("--ac$AccessControl")
        }
    }
    
    # Datei-Parameter (gegenseitig ausschließend)
    if ($PlayFile) {
        $argumentList.Add('--play')
        $argumentList.Add($PlayFile)
    }
    elseif ($ControlFile) {
        $argumentList.Add('--control')
        $argumentList.Add($ControlFile)
    }
    elseif ($SendTo) {
        $argumentList.Add('--Sendto')
        $argumentList.AddRange($SendTo)
    }
    
    # Proxy-Parameter
    if ($ProxyIP) {
        $argumentList.Add('--ProxyIP')
        $argumentList.Add($ProxyIP)
        
        if ($ProxyUser) {
            $argumentList.Add('--ProxyUser')
            $argumentList.Add($ProxyUser)
        }
        
        if ($ProxyPassword) {
            $argumentList.Add('--ProxyPassword')
            $argumentList.Add([System.Runtime.InteropServices.Marshal]::PtrToStringAuto([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($ProxyPassword)))
        }
    }
    
    # TeamViewer starten
    try {
        Write-Verbose "Starting TeamViewer with arguments: $($argumentList -join ' ')"
        & $ExePath @argumentList
    }
    catch {
        throw "Failed to start TeamViewer: $_"
    }
}

# Zusätzliche Hilfsfunktion für Assignment
function Set-TeamViewerAssignment {
    <#
    .SYNOPSIS
    Weist ein TeamViewer-Gerät einem Account/einer Gruppe zu.
    
    .DESCRIPTION
    Diese Funktion verwendet die TeamViewer Assignment-Funktionalität, um ein Gerät
    automatisch einem TeamViewer-Account und einer Gruppe zuzuweisen. Dies ist besonders
    nützlich für Mass-Deployment-Szenarien.
    
    .PARAMETER ExePath
    Pfad zur TeamViewer.exe. Standard: "$Env:ProgramFiles\TeamViewer\TeamViewer.exe"
    
    .PARAMETER ApiToken
    API-Token für den Zugriff auf das TeamViewer-Konto (aus Management Console)
    
    .PARAMETER Group
    Name der Gruppe, zu der das Gerät hinzugefügt werden soll (wird erstellt falls nicht vorhanden)
    
    .PARAMETER GroupId
    ID der Gruppe (Alternative zu Group-Parameter, schneller für große Umgebungen)
    
    .PARAMETER Alias
    Alias-Name für das Gerät in der Kontaktliste
    
    .PARAMETER GrantEasyAccess
    Gewährt Easy Access nach der Zuweisung
    
    .PARAMETER Reassign
    Weist das Gerät zu, auch wenn es bereits einem Account zugewiesen ist
    
    .PARAMETER DataFileTimeout
    Wartezeit in Sekunden für die Erstellung der Datendatei (Standard: 10)
    
    .PARAMETER ProxyIP
    Proxy-Server im Format 'IP:Port'
    
    .PARAMETER ProxyUser
    Benutzername für Proxy-Authentifizierung
    
    .PARAMETER ProxyPassword
    Passwort für Proxy-Authentifizierung
    
    .PARAMETER RetryCount
    Anzahl der Wiederholungsversuche bei temporären Fehlern (Standard: 3)
    
    .PARAMETER Timeout
    Gesamt-Timeout in Sekunden für alle Assignment-Versuche (Standard: 60)
    
    .EXAMPLE
    Set-TeamViewerAssignment -ApiToken "12345678" -Group "IT-Support"
    Basis-Zuweisung zu einer Gruppe
    
    .EXAMPLE
    Set-TeamViewerAssignment -ApiToken "12345678" -Group "Servers" -Alias $env:COMPUTERNAME -GrantEasyAccess
    Zuweisung mit Computer-Namen als Alias und Easy Access
    
    .EXAMPLE
    Set-TeamViewerAssignment -ApiToken "12345678" -GroupId 12345 -Reassign -ProxyIP "proxy.company.com:8080"
    Zuweisung über Proxy mit Gruppen-ID und Reassign-Option
    
    .NOTES
    Erfordert Admin-Rechte auf macOS (sudo).
    API-Token kann in der TeamViewer Management Console unter "Profil > Apps" erstellt werden.
    
    .LINK
    https://www.teamviewer.com/cs/global/support/knowledge-base/teamviewer-remote/deployment/mass-deployment-user-guide/assign-a-device-via-command-line-8-10/
    #>
    [CmdletBinding()]
    param(
        [string] $ExePath = "$Env:ProgramFiles\TeamViewer\TeamViewer.exe",
        [Parameter(Mandatory)] [string] $ApiToken,
        [string] $Group,
        [int] $GroupId,
        [string] $Alias,
        [switch] $GrantEasyAccess,
        [switch] $Reassign,
        [int] $DataFileTimeout = 10,
        [string] $ProxyIP,
        [string] $ProxyUser, 
        [SecureString] $ProxyPassword,
        [int] $RetryCount = 3,
        [int] $Timeout = 60
    )
    
    if (-not (Test-Path $ExePath)) {
        throw "TeamViewer executable not found at: $ExePath"
    }
    
    if (-not $Group -and -not $GroupId) {
        throw "Either Group or GroupId must be specified"
    }
    
    $argumentList = [System.Collections.Generic.List[string]]::new()
    $argumentList.Add('assign')
    $argumentList.Add('--api-token'); $argumentList.Add($ApiToken)
    
    if ($Group) { $argumentList.Add('--group'); $argumentList.Add($Group) }
    if ($GroupId) { $argumentList.Add('--groupid'); $argumentList.Add($GroupId) }
    if ($Alias) { $argumentList.Add('--alias'); $argumentList.Add($Alias) }
    if ($GrantEasyAccess) { $argumentList.Add('--grant-easy-access') }
    if ($Reassign) { $argumentList.Add('--reassign') }
    if ($DataFileTimeout -ne 10) { $argumentList.Add('--datafolder-timeout'); $argumentList.Add($DataFileTimeout) }
    if ($RetryCount -ne 3) { $argumentList.Add('--retry'); $argumentList.Add($RetryCount) }
    if ($Timeout -ne 60) { $argumentList.Add('--timeout'); $argumentList.Add($Timeout) }
    
    if ($ProxyIP) {
        $argumentList.Add('--proxy'); $argumentList.Add($ProxyIP)
        if ($ProxyUser) { $argumentList.Add('--proxy-user'); $argumentList.Add($ProxyUser) }
        if ($ProxyPassword) { 
            $argumentList.Add('--proxy-pw'); 
            $argumentList.Add([System.Runtime.InteropServices.Marshal]::PtrToStringAuto([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($ProxyPassword)))
        }
    }
    
    try {
        Write-Verbose "Assigning TeamViewer with arguments: $($argumentList -join ' ')"
        & $ExePath @argumentList
    }
    catch {
        throw "Failed to assign TeamViewer: $_"
    }
}

function Start-TeamViewerRemote {
    <#
    .SYNOPSIS
    Öffnet TeamViewer auf erreichbaren AD-Computern, gefiltert nach Name oder Beschreibung.

    .DESCRIPTION
    Findet Active Directory-Computer anhand eines Suchbegriffs (Computername oder Beschreibung), 
    prüft deren Erreichbarkeit per Ping und startet TeamViewer für jeden erreichbaren Rechner.

    .PARAMETER SearchTerm
    Teilstring des Computernamens oder der Beschreibung im AD

    .PARAMETER Timeout
    Timeout für die Ping-Erreichbarkeitsprüfung in Sekunden (Default: 1)

    .EXAMPLE
    Start-TeamViewerRemote -SearchTerm "Meier"

    .EXAMPLE
    Start-TeamViewerRemote -SearchTerm "Laptop" -Timeout 2
    #>

    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$SearchTerm,

        [int]$Timeout = 1
    )

    $computers = Get-ADComputer -Filter { Enabled -eq $true } -Properties Description |
    Where-Object { $_.Description -like "*$SearchTerm*" -or $_.Name -like "*$SearchTerm*" } |
    Out-GridView -PassThru

    foreach ($comp in $computers) {
        Write-Host "Checking if computer is reachable: $($comp.DNSHostName)" -ForegroundColor Yellow
        if (Test-Connection -ComputerName $comp.DNSHostName -IPv4 -Ping -Count 1 -Quiet -TimeoutSeconds $Timeout) {
            Write-Host "reachable: $($comp.DNSHostName)" -ForegroundColor Green
            Start-TeamViewer -ID $comp.DNSHostName
        }
        else {
            Write-Host "not reachable: $($comp.DNSHostName)" -ForegroundColor Red
        }
    }
}

# Example usage of the Start-TeamViewer function
# Start-TeamViewer -ID "MYHOSTNAME"
$UserOrComputer = Read-Host -Prompt "(Part of) Username (Description) Or Computername"
Start-TeamViewerRemote -SearchTerm $UserOrComputer