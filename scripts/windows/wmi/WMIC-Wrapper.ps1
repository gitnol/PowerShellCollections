<#
.SYNOPSIS
    Ruft WMI/CIM-Klasseninformationen effizient ab und stellt eine vereinfachte Schnittstelle bereit.

.DESCRIPTION
    Get-WmiBriefOptimized ist eine optimierte PowerShell-Funktion zum Abrufen von WMI/CIM-Klassen-
    informationen. Die Funktion automatisiert das Hinzufügen des Win32_-Präfixes, verwendet 
    CIM-Sessions für bessere Performance und minimiert die Datenübertragung durch selektive 
    Eigenschaftsabfragen.

    Hauptmerkmale:
    - Automatisches Hinzufügen des Win32_-Präfixes bei Bedarf
    - Effiziente CIM-Session-Verwaltung
    - Optimierte Datenübertragung durch Property-Selektion
    - Pipeline-Unterstützung für Batch-Verarbeitung
    - Alias 'wmic' für vereinfachte Verwendung

.PARAMETER ClassName
    Der Name der WMI/CIM-Klasse. Das Win32_-Präfix wird automatisch hinzugefügt, falls nicht vorhanden.
    Dieser Parameter unterstützt Pipeline-Input.

.PARAMETER ComputerName
    Der Name des Zielcomputers. Standard ist 'localhost' für den lokalen Computer.

.EXAMPLE
    Get-WmiBriefOptimized -ClassName "LogicalDisk"
    Ruft alle LogicalDisk-Instanzen vom lokalen Computer ab.

.EXAMPLE
    "Processor", "BIOS" | Get-WmiBriefOptimized
    Ruft Processor- und BIOS-Informationen über die Pipeline ab.

.EXAMPLE
    wmic LogicalDisk
    Verwendet den Alias für eine vereinfachte Syntax.

.EXAMPLE
    Get-WmiBriefOptimized -ClassName "Service" -ComputerName "Server01"
    Ruft Service-Informationen von einem Remote-Computer ab.

.NOTES
    Autor: [Ihr Name]
    Version: 2.0
    Erstellt: [Datum]
    
    Voraussetzungen:
    - PowerShell 3.0 oder höher
    - CIM-Cmdlets verfügbar
    - Entsprechende Berechtigungen für Remote-Zugriff (falls verwendet)

.LINK
    Get-CimInstance
    Get-CimClass
    Get-CimSession
#>

function Get-WmiBriefOptimized {
    [CmdletBinding()]
    param(
        [Parameter(
            Mandatory,
            ValueFromPipeline,
            HelpMessage = "Name der WMI/CIM-Klasse (Win32_-Präfix wird automatisch hinzugefügt)"
        )]
        [ValidateNotNullOrEmpty()]
        [string]$ClassName,

        [Parameter(HelpMessage = "Name des Zielcomputers (Standard: localhost)")]
        [ValidateNotNullOrEmpty()]
        [string]$ComputerName = 'localhost'
    )

    begin {
        Write-Verbose "Starte WMI-Abfrage für Computer: $ComputerName"
        
        # Session-Variable für Wiederverwendung bei Pipeline-Input
        $cimSession = $null
    }

    process {
        try {
            # Win32_-Präfix automatisch hinzufügen, falls nicht vorhanden
            if ($ClassName -notmatch '^Win32_') {
                $ClassName = "Win32_$ClassName"
                Write-Verbose "Klassenname erweitert zu: $ClassName"
            }

            # CIM-Session einmalig erstellen oder wiederverwenden
            if (-not $cimSession) {
                Write-Verbose "Erstelle CIM-Session..."
                
                if ($ComputerName -eq "localhost") {
                    # Lokale Session - effizienter für lokale Abfragen
                    $cimSession = New-CimSession -ErrorAction Stop
                }
                else {
                    # Remote-Session mit explizitem Computernamen
                    $cimSession = New-CimSession -ComputerName $ComputerName -ErrorAction Stop
                    Write-Verbose "Remote-Session zu $ComputerName erstellt"
                }
            }

            # Klassendefinition abrufen für Eigenschaftsmetadaten
            Write-Verbose "Lade Klassendefinition für: $ClassName"
            $class = Get-CimClass -ClassName $ClassName -CimSession $cimSession -ErrorAction Stop
            
            # Nur verfügbare Eigenschaften extrahieren
            $propertyNames = $class.CimClassProperties.Name
            Write-Verbose "Gefunden: $($propertyNames.Count) Eigenschaften"

            # Instanzen mit selektiven Eigenschaften abrufen (Performance-Optimierung)
            Write-Verbose "Rufe Instanzen ab..."
            $instances = Get-CimInstance -ClassName $ClassName -CimSession $cimSession -Property $propertyNames -ErrorAction Stop
            
            Write-Verbose "Erfolgreich $($instances.Count) Instanzen abgerufen"
            return $instances

        }
        catch [Microsoft.Management.Infrastructure.CimException] {
            Write-Error "CIM-Fehler bei Klasse '$ClassName' auf '$ComputerName': $($_.Exception.Message)" -Category InvalidOperation
        }
        catch [System.UnauthorizedAccessException] {
            Write-Error "Zugriff auf '$ComputerName' verweigert. Überprüfen Sie Ihre Berechtigungen." -Category PermissionDenied
        }
        catch {
            Write-Error "Unerwarteter Fehler bei Klasse '$ClassName' auf '$ComputerName': $($_.Exception.Message)" -Category NotSpecified
        }
    }

    end {
        # CIM-Session cleanup
        if ($cimSession) {
            Write-Verbose "Schließe CIM-Session"
            Remove-CimSession -CimSession $cimSession -ErrorAction SilentlyContinue
        }
    }
}

# Alias-Management: Bestehenden Alias entfernen und neuen erstellen
Write-Verbose "Konfiguriere Alias 'wmic'..."

try {
    # Prüfen ob Alias bereits existiert und entfernen
    $existingAlias = Get-Alias -Name wmic -ErrorAction SilentlyContinue
    if ($existingAlias) {
        Remove-Alias -Name wmic -Force -ErrorAction Stop
        Write-Verbose "Bestehenden Alias 'wmic' entfernt"
    }
    
    # Neuen Alias erstellen
    New-Alias -Name wmic -Value Get-WmiBriefOptimized -Force -ErrorAction Stop
    Write-Verbose "Alias 'wmic' erfolgreich erstellt"
    
    Write-Host "✓ Get-WmiBriefOptimized geladen. Verwenden Sie 'wmic <ClassName>' für schnellen Zugriff." -ForegroundColor Green
}
catch {
    Write-Warning "Fehler beim Erstellen des Alias 'wmic': $($_.Exception.Message)"
    Write-Host "✓ Get-WmiBriefOptimized geladen (ohne Alias)." -ForegroundColor Yellow
}

# Hinweis: Export-ModuleMember wird nur benötigt, wenn dieses Script als .psm1-Modul verwendet wird
# Export-ModuleMember -Function Get-WmiBriefOptimized -Alias wmic

# Beispiele: 
# @("Win32_BIOS", "Win32_Computersystem") | Get-WmiBriefOptimized -ComputerName localhost -Verbose
# @("Win32_BIOS", "Win32_Computersystem") | ForEach-Object { wmic $_ | Out-GridView -Title $_ }
# @("BIOS", "Computersystem") | ForEach-Object { wmic $_ -Verbose | Out-GridView -Title $_ }

function Show-WmiCimMap {
    $mapping = @'
| WMIC-Befehl                          | CIM/WMI-Klasse                                                      |
| ------------------------------------ | ------------------------------------------------------------------- |
| `wmic computersystem`                | `Win32_ComputerSystem`                                              |
| `wmic bios`                          | `Win32_BIOS`                                                        |
| `wmic cpu`                           | `Win32_Processor`                                                   |
| `wmic os`                            | `Win32_OperatingSystem`                                             |
| `wmic logicaldisk`                   | `Win32_LogicalDisk`                                                 |
| `wmic nic`                           | `Win32_NetworkAdapter`                                              |
| `wmic nicconfig`                     | `Win32_NetworkAdapterConfiguration`                                 |
| `wmic baseboard`                     | `Win32_BaseBoard`                                                   |
| `wmic csproduct`                     | `Win32_ComputerSystemProduct`                                       |
| `wmic diskdrive`                     | `Win32_DiskDrive`                                                   |
| `wmic memphysical`                   | `Win32_PhysicalMemoryArray`                                         |
| `wmic memorychip`                    | `Win32_PhysicalMemory`                                              |
| `wmic path softwarelicensingservice` | `SoftwareLicensingService`                                          |
| `wmic volume`                        | `Win32_Volume`                                                      |
| `wmic service`                       | `Win32_Service`                                                     |
| `wmic startup`                       | `Win32_StartupCommand`                                              |
| `wmic useraccount`                   | `Win32_UserAccount`                                                 |
| `wmic qfe`                           | `Win32_QuickFixEngineering`                                         |
| `wmic product`                       | `Win32_Product` *(⚠️ vermeiden – langsam, verändert Systemzustand)* |
| `wmic printer`                       | `Win32_Printer`                                                     |
| `wmic sounddev`                      | `Win32_SoundDevice`                                                 |
| `wmic timezone`                      | `Win32_TimeZone`                                                    |
| `wmic desktopmonitor`                | `Win32_DesktopMonitor`                                              |
| `wmic videocontroller`               | `Win32_VideoController`                                             |
| `wmic battery`                       | `Win32_Battery`                                                     |
| `wmic env`                           | `Win32_Environment`                                                 |
| `wmic userprofile`                   | `Win32_UserProfile`                                                 |

Beispiele: 
@("Win32_BIOS", "Win32_Computersystem") | Get-WmiBriefOptimized -ComputerName localhost -Verbose
@("Win32_BIOS", "Win32_Computersystem") | ForEach-Object { wmic $_ | Out-GridView -Title $_ }
@("BIOS", "Computersystem") | ForEach-Object { wmic $_ -Verbose | Out-GridView -Title $_ }
'@

    $mapping -split "`n" | ForEach-Object {
        Write-Host $_ -ForegroundColor Yellow
    }
}

# Hinweis: Diese Funktion zeigt eine Tabelle mit den gängigen WMIC-Befehlen und ihren entsprechenden CIM/WMI-Klassen.
Show-WmiCimMap
