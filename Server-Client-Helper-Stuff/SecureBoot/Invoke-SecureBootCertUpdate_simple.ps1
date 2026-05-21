#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Erzwingt das manuelle Update der Secure Boot Zertifikate (2023er Keys)
    gemäß den Vorgaben von Microsoft über die Registry und den System-Task.
.NOTES
    Das System erfordert nach der Ausführung zwingend einen Neustart,
    damit die Firmware (BIOS/UEFI) die Zertifikate beim Booten einpflegen kann.
#>

# --- Prüfen und Erzwingen von Administratorrechten ---
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if (-not $isAdmin) {
    Write-Host "Skript läuft nicht als Administrator. Versuche, mit erhöhten Rechten neu zu starten..." -ForegroundColor Yellow
    try {
        Start-Process powershell.exe -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs -ErrorAction Stop
        Exit
    } catch {
        Write-Error "Das Skript benötigt Administratorrechte, um Änderungen an der Registry und den System-Tasks vorzunehmen. Abbruch."
        Exit
    }
}

# --- Ab hier läuft das Skript garantiert als Administrator ---

$regPath = "HKLM:\SYSTEM\CurrentControlSet\Control\SecureBoot"
$regValueName = "AvailableUpdates"
$regValueData = 0x5944 # Der von Microsoft vorgegebene Hex-Wert für das Zertifikats-Update

Write-Host "1. Setze Registrierungsschlüssel in der Registry..." -ForegroundColor Cyan

try {
    # Prüfen, ob der SecureBoot-Pfad existiert
    if (-not (Test-Path $regPath)) {
        New-Item -Path $regPath -Force | Out-Null
    }
    
    # DWORD-Wert setzen
    Set-ItemProperty -Path $regPath -Name $regValueName -Value $regValueData -Type DWord -ErrorAction Stop
    Write-Host "   -> Registry-Wert erfolgreich auf 0x5944 gesetzt." -ForegroundColor Green
} catch {
    Write-Error "Fehler beim Schreiben in die Registry: $_"
    Exit
}

Write-Host "`n2. Triggere den geplanten Windows-Systemtask für das Secure-Boot-Update..." -ForegroundColor Cyan

try {
    # Den spezifischen Microsoft-Task direkt starten
    Start-ScheduledTask -TaskName "Secure-Boot-Update" -TaskPath "\Microsoft\Windows\PI\" -ErrorAction Stop
    Write-Host "   -> Der System-Task wurde erfolgreich gestartet und läuft im Hintergrund." -ForegroundColor Green
} catch {
    Write-Error "Fehler beim Starten des Scheduled Tasks: $_"
    Exit
}

Write-Host "`n--- FERTIG ---" -ForegroundColor Green
Write-Host "Die manuelle Erzwingung wurde initiiert." -ForegroundColor Yellow
Write-Host "WICHTIG: Das System muss nun neu gestartet werden, damit die UEFI-Firmware die Änderungen beim Booten verarbeiten kann." -ForegroundColor White
Write-Host "In manchen Fällen ist ein zweiter Neustart erforderlich, bis das Prüfskript 'OK' meldet." -ForegroundColor White

# Abfrage für einen sofortigen Neustart
$response = Read-Host "`nMöchtest du das System jetzt sofort neu starten? (J/N)"
if ($response -match "^[JjYy]") {
    Write-Host "System wird neu gestartet..." -ForegroundColor Yellow
    Restart-Computer -Force
}
