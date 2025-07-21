function Enable-ShadowCopyC {
    param(
        [int]$MaxPercent = 10
    )

    $logPath = "C:\Install"
    $logFile = "$logPath\shadowcopy.log"

    if (-not (Test-Path $logPath)) {
        New-Item -ItemType Directory -Path $logPath -Force | Out-Null
    }

    function Write-Log {
        param([string]$Message)
        $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        "$timestamp - $Message" | Out-File -FilePath $logFile -Encoding UTF8 -Append
    }

    $volume = Get-CimInstance -Query "SELECT * FROM Win32_Volume WHERE DriveLetter = 'C:' AND FileSystem = 'NTFS'"
    if (-not $volume) {
        Write-Log "C:\ nicht gefunden oder kein NTFS-Dateisystem. Abbruch."
        return
    }

    $maxSizeBytes = [math]::Floor($volume.Capacity * ($MaxPercent / 100))

    $existing = Get-CimInstance -Namespace root\cimv2 -ClassName Win32_ShadowStorage | Where-Object { $_.Volume.DeviceID -eq $volume.DeviceID }

    if (-not $existing) {
        Start-Process -Wait -FilePath "vssadmin.exe" -ArgumentList @(
            "add shadowstorage",
            "/for=C:",
            "/on=C:",
            "/maxsize=$([math]::Round($maxSizeBytes / 1MB))MB"
        ) -WindowStyle Hidden

        Write-Log "Schattenkopie für C:\ aktiviert mit max. $MaxPercent% = $([math]::Round($maxSizeBytes / 1MB)) MB."
    }
    else {
        Write-Log "Schattenkopien für C:\ waren bereits aktiv. Ändere auf $MaxPercent ..."
        Start-Process -Wait -FilePath "vssadmin.exe" -ArgumentList @(
            "resize shadowstorage",
            "/for=C:",
            "/on=C:",
            "/maxsize=$([math]::Round($maxSizeBytes / 1MB))MB"
        ) -WindowStyle Hidden

        Write-Log "Schattenkopie für C:\ aktiviert mit max. $MaxPercent% = $([math]::Round($maxSizeBytes / 1MB)) MB."
    }
}

Enable-ShadowCopyC -MaxPercent 10

Enable-ComputerRestore -Drive 'C:\'
Checkpoint-Computer -Description 'Initialer Wiederherstellungspunkt' -RestorePointType 'MODIFY_SETTINGS'


# Erstellt eine Schattenkopie
# $r = ([WmiClass]'root\cimv2:Win32_ShadowCopy').Create('C:\', 'ClientAccessible')