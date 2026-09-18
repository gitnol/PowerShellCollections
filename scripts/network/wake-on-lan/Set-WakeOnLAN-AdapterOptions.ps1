$adapters = Get-NetAdapter -Physical | Get-NetAdapterPowerManagement
foreach ($adapter in $adapters) {
    $adapter.AllowComputerToTurnOffDevice = 'Disabled'
    $adapter | Set-NetAdapterPowerManagement
}

$settings = (Get-NetAdapterPowerManagement -Name Ethernet).WakeOnMagicPacket    
If ($settings -eq "Disabled") {
    Set-NetAdapterPowerManagement -Name Ethernet -WakeOnMagicPacket Enabled -Confirm:$false
} 