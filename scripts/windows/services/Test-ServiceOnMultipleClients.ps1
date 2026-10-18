<#
.SYNOPSIS
    Prueft auf mehreren Rechnern, ob mindestens einer aus einer Liste von
    Diensten laeuft.

.DESCRIPTION
    Geht eine Rechnerliste durch und meldet je Rechner, welcher der
    gesuchten Dienste vorhanden und in welchem Zustand er ist. Die Dienste
    sind oder-verknuepft: gedacht fuer Produkte, die je nach Version
    unterschiedliche Dienstnamen mitbringen.

    Im Auslieferungszustand sind die Dienste einer G-DATA-Installation
    hinterlegt.

.NOTES
    Dienstliste und Titel stehen als Variablen am Dateianfang. Nicht
    erreichbare Rechner werden als solche ausgewiesen und nicht
    stillschweigend uebergangen.
#>

param (
    $Computer = @()
)
# Annahme: $Computer ist eine Liste/Array von Computernamen
# z.B. $Computer = "PC1", "PC-Offline", "PC3"

$title = "GDATA Checks"

# Liste zu prüfender Dienste ("Oder" Verknüpfung)
$myServices = @(
    "GdProxy",
    "GdWMService",
    "G DATA Security Service",
    "GdUpdSvc",
    "GDFwSvc",
    "GDFirewall",
    "GdMailSecurity"
)

# Pfade für die neuen Prüfungen
$regPathToCheck = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\GDATA"
$folderPathToCheck = "C:\ProgramData\G DATA\Client"

# Fehler-Variable initialisieren
$invokeErrors = @()

# 1. Parallele Ausführung und Fehler separat sammeln
# Die Roh-Ergebnisse (mit PSComputerName etc.) landen in $rawResults
$rawResults = Invoke-Command -ComputerName $Computer -ScriptBlock {
    
    # $using-Variablen (wie von Ihnen bevorzugt) direkt zuweisen
    $Services = $using:myServices
    $RegPath = $using:regPathToCheck
    $FolderPath = $using:folderPathToCheck
    
    $actualcomputer = $ENV:Computername

    # --- Prüfung 1: Dienste ---
    $serviceFound = $false
    foreach ($service in $Services) {
        if (Get-Service -Name $service -ErrorAction SilentlyContinue) {
            $serviceFound = $true
            break # Beenden, sobald einer gefunden wurde
        }
    }

    # --- Prüfung 2: Registry ---
    # Test-Path prüft, ob der Schlüssel existiert
    $regFound = Test-Path -Path $RegPath -ErrorAction SilentlyContinue

    # --- Prüfung 3: Ordner ---
    # Test-Path prüft, ob der Ordner existiert
    $folderFound = Test-Path -Path $FolderPath -ErrorAction SilentlyContinue

    # Ausgabe als PSCustomObject (mit den neuen Spalten)
    [PSCustomObject]@{
        Computer        = $actualcomputer
        Dienste         = $serviceFound
        RegistryCheck   = $regFound
        FolderCheck     = $folderFound
        # --- NEUE SPALTE (Logisches OR) ---
        FinalesErgebnis = ($serviceFound -or $regFound -or $folderFound)
    }

} -ErrorAction SilentlyContinue -ErrorVariable +invokeErrors # <-- KORRIGIERT

# 2. Erfolgreiche Ergebnisse BEREINIGEN
# Wir wählen explizit nur die Spalten aus, die wir wollen.
$successfulResults = $rawResults | Select-Object -Property Computer, Dienste, RegistryCheck, FolderCheck, FinalesErgebnis

# 3. Fehler verarbeiten (Offline-PCs etc.)
# Muss dieselbe Struktur wie die erfolgreichen Ergebnisse haben
$failedResults = $invokeErrors | ForEach-Object {
    if ($_.TargetObject -is [string]) {
        [PSCustomObject]@{
            Computer        = $_.TargetObject
            Dienste         = "unknown"
            RegistryCheck   = "unknown"
            FolderCheck     = "unknown"
            FinalesErgebnis = "unknown"
        }
    }
} | Select-Object -Property * -Unique # Stellt sicher, dass jeder PC nur einmal gelistet wird

# 4. Ergebnisse kombinieren
# Sicherstellen, dass beide Variablen als Array behandelt werden
$finalResults = @($successfulResults) + @($failedResults)

# Zur Kontrolle (Sortiert ausgeben):
# $finalResults | Sort-Object Computer | ogv -title $title

return $finalResults