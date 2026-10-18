<#
.SYNOPSIS
    Richtet die Netzwerkkarte fuer Wake-on-LAN ein.

.DESCRIPTION
    Setzt zwei Einstellungen, die zusammen gehoeren:

      - der Rechner darf das Geraet NICHT abschalten
        (AllowComputerToTurnOffDevice = Disabled)
      - der Adapter reagiert auf das Magic Packet
        (WakeOnMagicPacket = Enabled)

    Fehlt die erste, schaltet Windows die Karte im Energiesparmodus ab, und
    das Magic Packet kommt nie an - der haeufigste Grund dafuer, dass
    Wake-on-LAN "manchmal" nicht funktioniert.

.NOTES
    Erfordert administrative Rechte. Zusaetzlich muss Wake-on-LAN im BIOS
    beziehungsweise UEFI aktiviert sein; das laesst sich hier nicht
    beeinflussen.

    Der zweite Teil ist auf den Adapter 'Ethernet' verdrahtet.

    Das Magic Packet verschickt Send-WakeOnLan.ps1 im selben Ordner.
#>

$adapters = Get-NetAdapter -Physical | Get-NetAdapterPowerManagement
foreach ($adapter in $adapters) {
    $adapter.AllowComputerToTurnOffDevice = 'Disabled'
    $adapter | Set-NetAdapterPowerManagement
}

$settings = (Get-NetAdapterPowerManagement -Name Ethernet).WakeOnMagicPacket    
If ($settings -eq "Disabled") {
    Set-NetAdapterPowerManagement -Name Ethernet -WakeOnMagicPacket Enabled -Confirm:$false
} 