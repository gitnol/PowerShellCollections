function Write-Log {
    param([string]$Message)
    $logPath = "C:\Install"
    $logFile = "$logPath\shadowcopy.log"

    if (-not (Test-Path $logPath)) {
        New-Item -ItemType Directory -Path $logPath -Force | Out-Null
    }
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    "$timestamp - $Message" | Out-File -FilePath $logFile -Encoding UTF8 -Append
}

function Enable-ShadowCopyC {
    param(
        [int]$MaxPercent = 10
    )

    # $volume = Get-CimInstance -Query "SELECT * FROM Win32_Volume WHERE DriveLetter = 'C:' AND FileSystem = 'NTFS'"
    $volume = Get-CimInstance -Namespace root\cimv2 -ClassName Win32_Volume | Where-Object { $_.Name -eq "C:\" -and $_.FileSystem -eq "NTFS" }

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

        Write-Log "Schattenkopie für C:\ geändert mit max. $MaxPercent% = $([math]::Round($maxSizeBytes / 1MB)) MB."
    }
}

# Legt die maximale Größe der Schattenkopie fest und aktiviert sie
Enable-ShadowCopyC -MaxPercent 10

# Aktiviert den Systemschutz für C:\
Enable-ComputerRestore -Drive 'C:\':

# Erstellt einen initialen Wiederherstellungspunkt
if (-not (Get-ComputerRestorePoint -ErrorAction SilentlyContinue)) {
    Write-Log "Erstelle initialen Wiederherstellungspunkt ..."
    Checkpoint-Computer -Description 'Initialer Wiederherstellungspunkt' -RestorePointType 'MODIFY_SETTINGS' -ErrorAction Stop
    Write-Log "Initialer Wiederherstellungspunkt erstellt."
}
else {
    Write-Log "Initialer Wiederherstellungspunkt bereits vorhanden."
}

$myScriptPath = Split-Path -Path $MyInvocation.MyCommand.Definition -Parent
$myFilename = "Wiederherstellungspunkt_C_Täglich.xml"
$fullPath = Join-Path -Path $myScriptPath -ChildPath $myFilename
if (Test-Path -Path $fullPath -PathType Leaf) {
    schtasks /create /tn "Wiederherstellungspunkt_C_Täglich" /xml $fullPath /f
}




# Erstellt eine Schattenkopie
# $r = ([WmiClass]'root\cimv2:Win32_ShadowCopy').Create('C:\', 'ClientAccessible')