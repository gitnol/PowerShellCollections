function Test-ConnectionInParallel {
    # Only PowerShell 7+ (ForEach-Object -Parallel)
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, ValueFromPipeline = $true, Position = 0)]
        [string[]]$ComputerNames,
        [Parameter(Mandatory = $false)]
        [int]$throttlelimit = 10
    )
    $ComputerNames | ForEach-Object -Parallel {
        Write-Progress -Activity "Checking computer online status" -Status "$_"
        [PSCustomObject]@{
            ComputerName = $_
            Online       = Test-Connection -ComputerName $_ -Count 1 -Quiet -TimeoutSeconds 1
            IP           = (Test-Connection -ComputerName $_ -Count 1 -TimeoutSeconds 1 -ErrorAction SilentlyContinue).Address.IPAddressToString
        }
    } -ThrottleLimit $throttlelimit
}

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
