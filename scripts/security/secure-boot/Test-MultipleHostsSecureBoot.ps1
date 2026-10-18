<#
.SYNOPSIS
    Prueft auf vielen Rechnern parallel den Secure-Boot-Status und das
    Zertifikat 'Windows UEFI CA 2023'.

.DESCRIPTION
    Ermittelt die erreichbaren Rechner parallel und fragt bei jedem den
    Secure-Boot-Zustand sowie das Vorhandensein der UEFI-CA von 2023 ab.
    Anschliessend laesst sich das Update ueber Invoke-SecureBootCertUpdate.ps1
    anstossen.

    Hintergrund: die alte 'Microsoft Windows Production PCA 2011' laeuft aus.
    Systeme ohne das neue Zertifikat starten nach dem Ablauf nicht mehr mit
    aktiviertem Secure Boot.

.NOTES
    Erfordert PowerShell 7 (ForEach-Object -Parallel) und WinRM auf den
    Zielrechnern.

    Test-ConnectionInParallel kommt aus dem Modul
    modules/PSCollections.Connectivity. Diese Datei trug frueher eine eigene
    Kopie davon.
#>
# Gemeinsames Modul laden. Der Suchlauf nach oben macht den Import
# unabhaengig davon, wie tief die Datei im Verzeichnisbaum liegt.
$repoRoot = $PSScriptRoot
while ($repoRoot -and -not (Test-Path (Join-Path $repoRoot 'modules'))) {
    $repoRoot = Split-Path $repoRoot -Parent
}
Import-Module (Join-Path $repoRoot 'modules/PSCollections.Connectivity/PSCollections.Connectivity.psd1') -Force



# ─────────────────────────────────────────────────────────────────────────────
# 1. Computer-Objekte aus AD abrufen
#    Für Clients: Filter auf '*Windows 10*' oder '*Windows 11*' anpassen
# ─────────────────────────────────────────────────────────────────────────────
$adComputers = Get-ADComputer -Filter 'OperatingSystem -like "*Windows Server*" -and Enabled -eq $true' `
    -Properties LastLogonDate, OperatingSystem

# 2. Online-Status prüfen (parallel)
$OnlineComputers = Test-ConnectionInParallel -throttlelimit 20 -ComputerNames $adComputers.DNSHostName |
    Where-Object { $_.Online }
$TargetHosts = $OnlineComputers.ComputerName

# 3. Test-SecureBootCert2023.ps1 remote ausführen
#    Direkte X.509-Prüfung der UEFI-DB – kein State-File, kein ErrorActionPreference=Stop,
#    zuverlässigere Zertifikats-Erkennung als der Registry-Shortcut in Invoke-SecureBootCertUpdate.ps1
$ScriptContent = Get-Content ".\Test-SecureBootCert2023.ps1" -Raw
$FinalResults = Invoke-Command -ComputerName $TargetHosts -ThrottleLimit 20 -ScriptBlock {
    $sbi = [scriptblock]::Create($using:ScriptContent)
    & $sbi
} -ErrorAction SilentlyContinue

# 4. Ergebnisse anzeigen
#    Status = GEFAHR  → SecureBoot aktiv, Zertifikat fehlt → Handlungsbedarf
#    Status = OK      → Zertifikat vorhanden oder SecureBoot inaktiv
#    Status = KEIN_UEFI / FEHLER → Legacy-BIOS oder Lesefehler
$FinalResults |
    Select-Object ComputerName, Status, SecureBootEnabled, Cert2023Present, Timestamp, Details |
    Sort-Object Status, ComputerName |
    Out-GridView -Title "Secure Boot Cert 2023 – Inventar ($($FinalResults.Count) Systeme)"
