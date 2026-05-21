#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Prüft den Secure Boot Status und das Vorhandensein der 2023er Zertifikate.
    Erzwingt administrative Rechte beim Start.
.OUTPUTS
    Gibt ein PSCustomObject mit dem Status zurück.
#>

# --- Prüfen und Erzwingen von Administratorrechten ---
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if (-not $isAdmin) {
    Write-Host "Skript läuft nicht als Administrator. Versuche, mit erhöhten Rechten neu zu starten..." -ForegroundColor Yellow
    
    try {
        # Startet das Skript selbst in einer neuen PowerShell-Instanz als Administrator
        Start-Process powershell.exe -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs -ErrorAction Stop
        Exit
    } catch {
        Write-Error "Das Skript benötigt Administratorrechte, um die UEFI-Variablen auszulesen. Abbruch."
        Exit
    }
}

# --- Ab hier läuft das Skript garantiert als Administrator ---

# 1. Prüfen, ob Secure Boot überhaupt aktiv ist
$secureBootActive = Confirm-SecureBootUEFI

if (-not $secureBootActive) {
    [PSCustomObject]@{
        Status               = "OK"
        SecureBootEnabled    = $false
        Cert2023Present      = $false
        Details              = "Secure Boot ist deaktiviert. Keine akute Boot-Gefahr im Juni 2026, aber verringerter Schutz."
    }
} else {
    # 2. Secure Boot ist aktiv -> Vorhandensein des Windows UEFI CA 2023 Zertifikats in der DB prüfen
    try {
        $dbBytes = Get-SecureBootUEFI -Name db
        $dbString = [System.Text.Encoding]::ASCII.GetString($dbBytes.bytes)
        
        # Prüfung auf die entscheidende 2023er Signatur
        $certPresent = $dbString -match 'Windows UEFI CA 2023'
        
        if ($certPresent) {
            [PSCustomObject]@{
                Status               = "OK"
                SecureBootEnabled    = $true
                Cert2023Present      = $true
                Details              = "Das System ist sicher. Das 2023er Zertifikat ist aktiv im UEFI hinterlegt."
            }
        } else {
            [PSCustomObject]@{
                Status               = "GEFAHR"
                SecureBootEnabled    = $true
                Cert2023Present      = $false
                Details              = "Secure Boot aktiv, aber das 2023er Zertifikat fehlt! System läuft Gefahr, nach dem Ablauf 2026 nicht mehr zu booten."
            }
        }
    } catch {
        [PSCustomObject]@{
            Status               = "FEHLER"
            SecureBootEnabled    = $true
            Cert2023Present      = $false
            Details              = "Fehler beim Auslesen der UEFI-Variablen trotz Administratorrechten."
        }
    }
}
