function New-CShadowCopyLink {
    param(
        [string]$Volume = "C:\",
        [string]$LinkPath = "C:\vsslink"
    )

    if (Test-Path $LinkPath) {
        Write-Warning "$LinkPath existiert bereits. Bitte vorher entfernen."
        return
    }

    Write-Host "Erzeuge VSS-Instanz für $Volume ..."
    $vssObject = [WmiClass]"root\cimv2:Win32_ShadowCopy"
    $result = $vssObject.Create($Volume, "ClientAccessible")

    if ($result.ReturnValue -ne 0) {
        Write-Error "VSS-Erstellung fehlgeschlagen. Fehlercode: $($result.ReturnValue)"
        return
    }

    $shadowID = [string]$result.ShadowID
    $snapshot = Get-WmiObject Win32_ShadowCopy | Where-Object { $_.ID -eq $shadowID }

    if (-not $snapshot) {
        Write-Error "Snapshot nicht gefunden."
        return
    }

    $deviceObject = $snapshot.DeviceObject + "\"
    Write-Host "Snapshot erstellt unter: $deviceObject"

    Write-Host "Erstelle symbolischen Link unter $LinkPath ..."
    cmd.exe /c "mklink /d `"$LinkPath`" `"$deviceObject`"" | Out-Null

    Write-Host "Schattenkopie ist bereit unter $LinkPath. Vorgang abschließen und beliebige Eingabetaste drücken ..."
    Pause

    Write-Host "Entferne symbolischen Link ..."
    [System.IO.Directory]::Delete($LinkPath, $true)

    Write-Host "Lösche VSS-Instanz ..."
    $snapshot.Delete() | Out-Null

    Write-Host "Fertig."
}

# New-CShadowCopyLink -Volume "C:\" -LinkPath "C:\vsslink"
