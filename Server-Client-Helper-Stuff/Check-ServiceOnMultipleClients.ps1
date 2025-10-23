param (
    $Computer = @()
)
# Annahme: $Computer ist eine Liste/Array von Computernamen
# z.B. $Computer = "PC1", "PC-Offline", "PC3"

# Liste zu prüfender Dienste ("Oder" Verknüpfung)
# Beispiel: "GDATA Service"
$myServices = @(
    "GdProxy",
    "GdWMService",
    "G DATA Security Service",
    "GdUpdSvc",
    "GDFwSvc",
    "GDFirewall",
    "GdMailSecurity"
)


# $servicename = "CSFalconService"
# Fehler-Variable initialisieren
$invokeErrors = @()

# 1. Parallele Ausführung und Fehler separat sammeln
# Die Roh-Ergebnisse (mit PSComputerName etc.) landen in $rawResults
$rawResults = Invoke-Command -ComputerName $Computer -ScriptBlock {
    $actualcomputer = $ENV:Computername
    $Services = $using:myServices

    # Prüfen, ob einer der Dienste existiert
    $found = $false
    foreach ($service in $Services) {
        if (Get-Service -Name $service -ErrorAction SilentlyContinue) {
            $found = $true
            break
        }
    }

    # Ausgabe als PSCustomObject
    [PSCustomObject]@{
        Computer    = $actualcomputer
        Installiert = $found
    }

} -ErrorAction SilentlyContinue -ErrorVariable +invokeErrors

# 2. Erfolgreiche Ergebnisse BEREINIGEN (Die wichtige Änderung)
# Wir wählen explizit nur die Spalten aus, die wir wollen.
# Dadurch werden die zusätzlichen Eigenschaften von Invoke-Command entfernt.
$successfulResults = $rawResults | Select-Object -Property Computer, Installiert

# 3. Fehler verarbeiten (wie zuvor)
$failedResults = $invokeErrors | ForEach-Object {
    if ($_.TargetObject -is [string]) {
        [PSCustomObject]@{
            Computer    = $_.TargetObject
            Installiert = "unknown"
        }
    }
} | Select-Object -Property * -Unique # Stellt sicher, dass jeder PC nur einmal gelistet wird

# 4. Ergebnisse kombinieren
# Jetzt haben $successfulResults und $failedResults dieselbe Struktur
$serviceinstalled = $successfulResults + $failedResults

# Zur Kontrolle:
# $serviceinstalled | Sort-Object Computer | ogv -title $title

return $serviceinstalled