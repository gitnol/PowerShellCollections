<#
.SYNOPSIS
    Erzeugt eine Schattenkopie von C: und haengt sie als begehbaren Ordner
    ein.

.DESCRIPTION
    Legt spontan eine Schattenkopie an und verknuepft sie ueber einen
    symbolischen Link (per Vorgabe C:\vsslink). Danach laesst sich der
    eingefrorene Zustand des Laufwerks wie ein normales Verzeichnis
    durchsuchen.

    Nuetzlich, um an Dateien zu kommen, die gerade gesperrt sind, oder um
    einen Stand vor einer Aenderung zu sichern.

.NOTES
    Erfordert administrative Rechte. Besteht der Linkpfad bereits, bricht das
    Skript ab, statt ihn zu ueberschreiben.

    Link und Schattenkopie nach Gebrauch wieder entfernen - sonst bleibt
    Speicher belegt.
#>

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
    $vssClass = Get-CimClass -Namespace root/cimv2 -ClassName Win32_ShadowCopy
    $createParams = @{
        Volume  = $Volume
        Context = "ClientAccessible"
    }
    $result = Invoke-CimMethod -CimClass $vssClass -MethodName Create -Arguments $createParams

    if ($result.ReturnValue -ne 0) {
        Write-Error "VSS-Erstellung fehlgeschlagen. Fehlercode: $($result.ReturnValue)"
        return
    }

    $shadowID = $result.ShadowID.ToString()
    $snapshot = Get-CimInstance -ClassName Win32_ShadowCopy -Filter "ID='$shadowID'"

    if (-not $snapshot) {
        Write-Error "Snapshot nicht gefunden."
        return
    }

    $deviceObject = $snapshot.DeviceObject + "\"
    Write-Host "Snapshot erstellt unter: $deviceObject"

    Write-Host "Erstelle symbolischen Link unter $LinkPath ..."
    cmd.exe /c "mklink /d `"$LinkPath`" `"$deviceObject`"" | Out-Null

    Write-Host "Schattenkopie ist bereit unter $LinkPath. Vorgang abschließen und beliebige Eingabetaste drücken ..."
    Start-Process -Wait -FilePath "explorer.exe" -ArgumentList @("$LinkPath")
    Pause

    Write-Host "Entferne symbolischen Link ..."
    [System.IO.Directory]::Delete($LinkPath, $true)

    Write-Host "Lösche VSS-Instanz ..."
    $snapshot | Remove-CimInstance -ErrorAction Stop

    Write-Host "Fertig."
}

# Beispielaufruf:
# Erstelle einen symbolischen Link für die Schattenkopie von C:\ unter C:\vsslink
# Hinweis: Stelle sicher, dass der Pfad C:\vsslink nicht bereits existiert
# New-CShadowCopyLink -Volume "C:\" -LinkPath "C:\vsslink"
