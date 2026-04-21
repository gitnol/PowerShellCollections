# Beende alle laufenden Teams-Prozesse
Write-Host "Beende Microsoft Teams..."
Get-Process -Name "ms-teams", "Teams" -ErrorAction SilentlyContinue | Stop-Process -Force

# Kurze Wartezeit, damit die Prozesse sauber beendet werden und die Dateien nicht mehr gesperrt sind
Start-Sleep -Seconds 2

# Pfade für die Cache-Verzeichnisse definieren
$classicTeamsPath = "$env:APPDATA\Microsoft\Teams"
$newTeamsPath = "$env:LOCALAPPDATA\Packages\MSTeams_8wekyb3d8bbwe\LocalCache\Microsoft\MSTeams"

# Cache für das neue Teams (MSIX App) bereinigen
if (Test-Path -Path $newTeamsPath) {
    Write-Host "Lösche Cache für das neue Microsoft Teams unter $($newTeamsPath)..."
    Remove-Item -Path "$($newTeamsPath)\*" -Recurse -Force -ErrorAction SilentlyContinue
    Write-Host "Cache für das neue Teams wurde erfolgreich gelöscht."
} else {
    Write-Host "Das neue Microsoft Teams wurde nicht gefunden oder der Cache ist bereits leer."
}

# Cache für das klassische Teams bereinigen
if (Test-Path -Path $classicTeamsPath) {
    Write-Host "Lösche Cache für das klassische Microsoft Teams unter $($classicTeamsPath)..."
    Remove-Item -Path "$($classicTeamsPath)\*" -Recurse -Force -ErrorAction SilentlyContinue
    Write-Host "Cache für das klassische Teams wurde erfolgreich gelöscht."
} else {
    Write-Host "Das klassische Microsoft Teams wurde nicht gefunden."
}

Write-Host "Vorgang abgeschlossen. Teams kann nun wieder gestartet werden."