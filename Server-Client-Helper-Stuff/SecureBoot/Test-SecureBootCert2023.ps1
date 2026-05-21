#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Prüft den Secure Boot Status und das Vorhandensein des Windows UEFI CA 2023 Zertifikats.
.OUTPUTS
    PSCustomObject: ComputerName, Timestamp, Status, SecureBootEnabled, Cert2023Present, Details

    Status-Werte:
        OK         - Zertifikat vorhanden, oder Secure Boot deaktiviert (kein Boot-Risiko)
        GEFAHR     - Secure Boot aktiv, aber 2023er Zertifikat fehlt → Update erforderlich
        KEIN_UEFI  - Legacy-BIOS-System, Secure Boot nicht verfügbar
        FEHLER     - UEFI-DB konnte trotz Adminrechten nicht gelesen werden
#>

# ─────────────────────────────────────────────────────────────────────────────
# X.509-Zertifikat korrekt aus EFI_SIGNATURE_LIST parsen
# (ASCII-Suche auf Binärdaten ist unzuverlässig: X.509-Subjects sind DER-kodiert)
# ─────────────────────────────────────────────────────────────────────────────
function Test-UEFICA2023InDb {
    param(
        [byte[]]$DbBytes,
        [string]$SubjectPattern = 'Windows UEFI CA 2023'
    )
    if (-not $DbBytes -or $DbBytes.Length -lt 28) { return $false }

    # EFI_CERT_X509_GUID {a5c059a1-94e4-4aa7-87b5-ab155c2bf072}
    $x509Guid = [System.Guid]::new('a5c059a1-94e4-4aa7-87b5-ab155c2bf072')
    $pos = 0
    while ($pos + 28 -le $DbBytes.Length) {
        $listGuid = [System.Guid]::new([byte[]]$DbBytes[$pos..($pos + 15)])
        $listSize = [BitConverter]::ToUInt32($DbBytes, $pos + 16)
        $hdrSize  = [BitConverter]::ToUInt32($DbBytes, $pos + 20)
        $sigSize  = [BitConverter]::ToUInt32($DbBytes, $pos + 24)
        if ($listSize -eq 0 -or $sigSize -le 16) { break }
        if ($listGuid -eq $x509Guid) {
            $entry = $pos + 28 + [int]$hdrSize
            $end   = $pos + [int]$listSize
            while ($entry + [int]$sigSize -le $end) {
                try {
                    $certBytes = $DbBytes[($entry + 16)..($entry + [int]$sigSize - 1)]
                    $cert = [System.Security.Cryptography.X509Certificates.X509Certificate2]::new([byte[]]$certBytes)
                    if ($cert.Subject -match [regex]::Escape($SubjectPattern)) { return $true }
                }
                catch { }
                $entry += [int]$sigSize
            }
        }
        $pos += [int]$listSize
    }
    return $false
}

# ─────────────────────────────────────────────────────────────────────────────
# 1. Secure Boot Status ermitteln
#    Confirm-SecureBootUEFI wirft PlatformNotSupportedException auf Legacy-BIOS
# ─────────────────────────────────────────────────────────────────────────────
$secureBootEnabled = $false
try {
    $secureBootEnabled = Confirm-SecureBootUEFI
}
catch [System.PlatformNotSupportedException] {
    [PSCustomObject]@{
        ComputerName      = $env:COMPUTERNAME
        Timestamp         = Get-Date
        Status            = 'KEIN_UEFI'
        SecureBootEnabled = $false
        Cert2023Present   = $false
        Details           = 'Kein UEFI-System (Legacy BIOS). Secure Boot nicht verfügbar.'
    }
    return
}
catch {
    [PSCustomObject]@{
        ComputerName      = $env:COMPUTERNAME
        Timestamp         = Get-Date
        Status            = 'FEHLER'
        SecureBootEnabled = $false
        Cert2023Present   = $false
        Details           = "Secure Boot Status konnte nicht ermittelt werden: $_"
    }
    return
}

# ─────────────────────────────────────────────────────────────────────────────
# 2. Secure Boot deaktiviert → kein akutes Boot-Risiko
# ─────────────────────────────────────────────────────────────────────────────
if (-not $secureBootEnabled) {
    [PSCustomObject]@{
        ComputerName      = $env:COMPUTERNAME
        Timestamp         = Get-Date
        Status            = 'OK'
        SecureBootEnabled = $false
        Cert2023Present   = $false
        Details           = 'Secure Boot ist deaktiviert. Kein akutes Boot-Risiko, aber verringerter Schutz.'
    }
    return
}

# ─────────────────────────────────────────────────────────────────────────────
# 3. Secure Boot aktiv → UEFI CA 2023 in DB prüfen (X.509-Parsing)
# ─────────────────────────────────────────────────────────────────────────────
try {
    $db = Get-SecureBootUEFI -Name db -ErrorAction Stop
    $certPresent = Test-UEFICA2023InDb -DbBytes $db.bytes

    if ($certPresent) {
        [PSCustomObject]@{
            ComputerName      = $env:COMPUTERNAME
            Timestamp         = Get-Date
            Status            = 'OK'
            SecureBootEnabled = $true
            Cert2023Present   = $true
            Details           = 'Windows UEFI CA 2023 ist in der Secure Boot DB vorhanden. System ist sicher.'
        }
    }
    else {
        [PSCustomObject]@{
            ComputerName      = $env:COMPUTERNAME
            Timestamp         = Get-Date
            Status            = 'GEFAHR'
            SecureBootEnabled = $true
            Cert2023Present   = $false
            Details           = 'Secure Boot aktiv, aber Windows UEFI CA 2023 fehlt in der DB. Update mit Invoke-SecureBootCertUpdate.ps1 einleiten.'
        }
    }
}
catch {
    [PSCustomObject]@{
        ComputerName      = $env:COMPUTERNAME
        Timestamp         = Get-Date
        Status            = 'FEHLER'
        SecureBootEnabled = $true
        Cert2023Present   = $false
        Details           = "UEFI DB konnte nicht gelesen werden: $_"
    }
}
