<#
.SYNOPSIS
Konfiguriert die Zeitsynchronisierung für den PDC-Emulationsmaster korrekt.
Besser ist es jedoch, wenn eine GPO für die Zeitsynchronisierung verwendet wird.
.DESCRIPTION
Dieses Skript überprüft, ob der aktuelle Computer der PDC-Emulator der Gesamtstruktur ist.
Wenn ja, wird die Zeitsynchronisierung entweder auf externe NTP-Server (Standard: deutsche Pool-Server) oder auf die Domänenhierarchie eingestellt.
.PARAMETER UseExternal
Wenn dieser Schalter gesetzt ist, werden externe NTP-Server für die Zeitsynchronisierung verwendet. Andernfalls wird die Domänenhierarchie verwendet.
.PARAMETER NtpServer
Gibt die Liste der NTP-Server an, die verwendet werden sollen, wenn der Schalter UseExternal gesetzt ist. Standardmäßig sind dies deutsche Pool-Server.
.EXAMPLE
Set-TimeSync -UseExternal
Konfiguriert die Zeitsynchronisierung des PDC-Emulators auf externe NTP-Server.
.EXAMPLE
Set-TimeSync
Konfiguriert die Zeitsynchronisierung des PDC-Emulators auf die Domänenhierarchie.
.NOTES

#>

param(
    [switch]$UseExternal,
    [string]$NtpServer = '0.de.pool.ntp.org,1.de.pool.ntp.org,2.de.pool.ntp.org,3.de.pool.ntp.org'
)

function Set-TimeSync {
    $Domain = (Get-ADDomain).DNSRoot
    $PdcFqdn = (Get-ADDomain $Domain).PDCEmulator
    $LocalFqdn = "$($env:COMPUTERNAME).$((Get-WmiObject Win32_ComputerSystem).Domain)"

    Write-Host "PDC-Emulator der Gesamtstruktur: $PdcFqdn"

    if ($LocalFqdn -ieq $PdcFqdn) {
        if ($UseExternal) {
            Write-Host "Konfiguriere externe deutsche Zeitquelle(n): $NtpServer"
            w32tm /config /manualpeerlist:$NtpServer /syncfromflags:manual /update | Out-Null
            w32tm /config /reliable:yes /update | Out-Null
        }
        else {
            Write-Host "Konfiguriere Zeitsynchronisierung über Domänenhierarchie"
            w32tm /config /syncfromflags:domhier /update | Out-Null
            w32tm /config /reliable:no /update | Out-Null
        }

        Restart-Service w32time -Force
        Start-Sleep 3
        w32tm /resync
        Write-Host "Zeitsynchronisierung wurde konfiguriert und gestartet."
    }
    else {
        Write-Host "Dieser Rechner ist kein PDC-Emulator ($LocalFqdn ≠ $PdcFqdn). Keine Änderung durchgeführt."
    }
}

Set-TimeSync
