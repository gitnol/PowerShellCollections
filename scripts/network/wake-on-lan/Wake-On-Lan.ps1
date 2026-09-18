function Send-WakeOnLan {
    <#
    .SYNOPSIS
        Sendet ein Wake-on-LAN Magic Packet an eine MAC-Adresse.
    
    .DESCRIPTION
        Diese Funktion erstellt und sendet ein Wake-on-LAN Magic Packet über UDP,
        um ein Gerät im Netzwerk aufzuwecken.
    
    .PARAMETER MacAddress
        Die MAC-Adresse des Zielgeräts (Format: XX:XX:XX:XX:XX:XX oder XX-XX-XX-XX-XX-XX)
    
    .PARAMETER Broadcast
        Die Broadcast-Adresse (Standard: 255.255.255.255)
    
    .PARAMETER Port
        Der UDP-Port (Standard: 9) 
        Üblicherweise wird Port 9 für Wake-on-LAN verwendet, mann kann aber auch andere Ports wie z.B. 30000 (für Dell Geräte) nutzen.
    
    .EXAMPLE
        Send-WakeOnLan -MacAddress "00:11:22:33:44:55"
        
    .EXAMPLE
        Send-WakeOnLan -MacAddress "00-11-22-33-44-55" -Broadcast "192.168.1.255"

    .EXAMPLE
        Send-WakeOnLan -MacAddress "00-11-22-33-44-55" -Port 30000 -Verbose
    #>
    
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, ValueFromPipeline)]
        [ValidatePattern('^([0-9A-Fa-f]{2}[:-]){5}([0-9A-Fa-f]{2})$')]
        [string]$MacAddress,
        
        [Parameter()]
        [ValidatePattern('^(?:(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)$')]
        [string]$Broadcast = "255.255.255.255",
        
        [Parameter()]
        [ValidateRange(1, 65535)]
        [int]$Port = 9
    )
    
    begin {
        Write-Verbose "Initialisiere Wake-on-LAN Funktion"
    }
    
    process {
        try {
            Write-Verbose "Verarbeite MAC-Adresse: $MacAddress"
            
            # MAC-Adresse normalisieren und in Bytes konvertieren
            $CleanMac = $MacAddress -replace '[:-]', ''
            if ($CleanMac.Length -ne 12) {
                throw "Ungültige MAC-Adresse: $MacAddress"
            }
            
            # Effiziente Byte-Konvertierung
            $MacBytes = [byte[]]::new(6)
            for ($i = 0; $i -lt 6; $i++) {
                $MacBytes[$i] = [Convert]::ToByte($CleanMac.Substring($i * 2, 2), 16)
            }
            
            # Magic Packet erstellen (6 x 0xFF + 16 x MAC-Adresse)
            $MagicPacket = [byte[]]::new(102)  # 6 + (6 * 16) = 102 Bytes
            
            # Header: 6 x 0xFF
            [Array]::Fill($MagicPacket, [byte]0xFF, 0, 6)
            
            # Payload: 16 x MAC-Adresse
            for ($i = 0; $i -lt 16; $i++) {
                [Array]::Copy($MacBytes, 0, $MagicPacket, 6 + ($i * 6), 6)
            }
            
            Write-Verbose "Magic Packet erstellt ($(${MagicPacket}.Length) Bytes)"
            Write-Verbose "Sende an: $Broadcast`:$Port"
            
            # UDP-Client für Paket-Versendung
            $UdpClient = $null
            try {
                $UdpClient = [System.Net.Sockets.UdpClient]::new()
                $UdpClient.EnableBroadcast = $true
                $UdpClient.Connect($Broadcast, $Port)
                $BytesSent = $UdpClient.Send($MagicPacket, $MagicPacket.Length)
                
                Write-Verbose "Magic Packet erfolgreich gesendet ($BytesSent Bytes)"
                
                # Erfolgreiche Ausgabe
                [PSCustomObject]@{
                    MacAddress = $MacAddress
                    Broadcast  = $Broadcast
                    Port       = $Port
                    BytesSent  = $BytesSent
                    Status     = "Erfolgreich"
                    Timestamp  = Get-Date
                }
            }
            finally {
                if ($UdpClient) {
                    $UdpClient.Close()
                    $UdpClient.Dispose()
                }
            }
        }
        catch {
            Write-Error "Fehler beim Senden des Wake-on-LAN Packets für $MacAddress`: $($_.Exception.Message)"
            
            # Fehler-Ausgabe nur bei tatsächlichem Fehler
            [PSCustomObject]@{
                MacAddress = $MacAddress
                Broadcast  = $Broadcast
                Port       = $Port
                BytesSent  = 0
                Status     = "Fehler: $($_.Exception.Message)"
                Timestamp  = Get-Date
            }
        }
    }
}

# Erweiterte Hilfsfunktion für mehrere Geräte
function Send-WakeOnLanBatch {
    <#
    .SYNOPSIS
        Sendet Wake-on-LAN Packets an mehrere Geräte gleichzeitig.
    
    .PARAMETER DeviceList
        Array von MAC-Adressen oder Hashtable mit Name und MAC-Adresse
    
    .EXAMPLE
        $devices = @("00:11:22:33:44:55", "AA:BB:CC:DD:EE:FF")
        Send-WakeOnLanBatch -DeviceList $devices
        
    .EXAMPLE
        $devices = @(
            @{Name="Server1"; Mac="00:11:22:33:44:55"},
            @{Name="Workstation1"; Mac="AA:BB:CC:DD:EE:FF"}
        )
        Send-WakeOnLanBatch -DeviceList $devices
    #>
    
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [array]$DeviceList,
        
        [string]$Broadcast = "255.255.255.255",
        [int]$Port = 9
    )
    
    $Results = @()
    
    foreach ($Device in $DeviceList) {
        if ($Device -is [hashtable] -and $Device.Mac) {
            Write-Host "Wecke Gerät '$($Device.Name)' auf..." -ForegroundColor Cyan
            $Result = Send-WakeOnLan -MacAddress $Device.Mac -Broadcast $Broadcast -Port $Port
            $Result | Add-Member -NotePropertyName "DeviceName" -NotePropertyValue $Device.Name
        }
        elseif ($Device -is [string]) {
            Write-Host "Wecke Gerät mit MAC '$Device' auf..." -ForegroundColor Cyan
            $Result = Send-WakeOnLan -MacAddress $Device -Broadcast $Broadcast -Port $Port
            $Result | Add-Member -NotePropertyName "DeviceName" -NotePropertyValue "Unbekannt"
        }
        else {
            Write-Warning "Ungültiger Geräteeintrag: $Device"
            continue
        }
        
        $Results += $Result
        Start-Sleep -Milliseconds 100  # Kurze Pause zwischen Paketen
    }
    
    return $Results
}

# Verwendungsbeispiele:
<#
# Einzelnes Gerät
Send-WakeOnLan -MacAddress "00:11:22:33:44:55" -Verbose

# Mehrere Geräte
$devices = @(
    @{Name="Server"; Mac="00:11:22:33:44:55"},
    @{Name="NAS"; Mac="AA:BB:CC:DD:EE:FF"}
)
$results = Send-WakeOnLanBatch -DeviceList $devices
$results | Format-Table -AutoSize

# Pipeline-Unterstützung
"00:11:22:33:44:55", "AA:BB:CC:DD:EE:FF" | Send-WakeOnLan

# Mit spezifischer Broadcast-Adresse
Send-WakeOnLan -MacAddress "00:11:22:33:44:55" -Broadcast "192.168.1.255"
#>