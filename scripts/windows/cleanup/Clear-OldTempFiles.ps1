function Get-CleanupPaths {
    <#
        .SYNOPSIS
        Gibt eine Liste bereinigungswürdiger Verzeichnispfade zurück.
        Bezieht sowohl systemweite als auch benutzerspezifische Pfade ein.
    #>

    # Benutzerprofile via CIM ermitteln (keine Spezialprofile, keine NULL-Pfade)
    $UserProfiles = Get-CimInstance -Class Win32_UserProfile |
        Where-Object { -not $_.Special -and $_.LocalPath } |
        Select-Object -ExpandProperty LocalPath

    # Systemweite statische Pfade
    $staticPaths = @(
        "C:\Windows\Temp\*",
        "C:\Windows\Logs\CBS\*",
        "C:\Windows\Downloaded Program Files\*",
        "C:\ProgramData\Microsoft\Windows\WER\*"
    )

    # Benutzerbezogene relative Pfade
    $userRelativePaths = @(
        "AppData\Local\Microsoft\Terminal Server Client\Cache\*",
        "AppData\Local\Microsoft\Windows\AppCache\*",
        "AppData\Local\Microsoft\Windows\WER\*",
        "AppData\Local\Microsoft\Windows\INetCache\*",
        "AppData\Local\Microsoft\Internet Explorer\Recovery\*",
        "AppData\Local\CrashDumps\*",
        "AppData\Local\Temp\*"
    )

    # Kombination aus Benutzerpfad + Relativpfad
    $userPaths = foreach ($user in $UserProfiles) {
        foreach ($rel in $userRelativePaths) {
            Join-Path -Path $user -ChildPath $rel
        }
    }

    return $staticPaths + $userPaths
}

function Clear-OldFiles {
    <#
        .SYNOPSIS
        Löscht Dateien älter als 1 Tag aus definierten temporären und Cache-Verzeichnissen.
        Unterstützt -WhatIf korrekt per CmdletBinding.

        .PARAMETER WhatIf
        Zeigt an, was gelöscht würde, ohne wirklich zu löschen.
    #>
    [CmdletBinding(SupportsShouldProcess = $true)]
    param()

    if (-not ([bool](New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator))) {
        Write-Warning "Dieses Skript sollte als Administrator ausgeführt werden."
        return
    }

    $folders = Get-CleanupPaths
    $threshold = (Get-Date).AddDays(-1)
    $totalSize = 0
    $deletedFiles = @()

    foreach ($path in $folders) {
        # Dateien rekursiv suchen, älter als Threshold, keine Container
        $files = Get-ChildItem -Path $path -Recurse -Force -Attributes !ReparsePoint -EA SilentlyContinue |
            Where-Object { $_.LastWriteTime -le $threshold -and -not $_.PSIsContainer }

        foreach ($file in $files) {
            $totalSize += $file.Length

            # Optionales Logging einzelner Dateien
            $deletedFiles += [PSCustomObject]@{
                Path       = $file.FullName
                SizeMB     = [math]::Round($file.Length / 1MB, 2)
                LastWrite  = $file.LastWriteTime
            }

            # Korrekte WhatIf-Unterstützung
            if ($PSCmdlet.ShouldProcess($file.FullName, "Remove Old File")) {
				try {
					Remove-Item -LiteralPath $file.FullName -Force -ErrorAction Stop
					Write-Verbose "Erfolgreich gelöscht: $($file.FullName)"
				}
				catch {
					Write-Error "FEHLER: $($_.Exception.Message)"
				}
            }
        }
    }

    foreach ($path in $folders) {
        $emptyFolders = Get-ChildItem -Path $path -Recurse -Force -Attributes !ReparsePoint -ErrorAction SilentlyContinue |
            Where-Object { $_.PSIsContainer } |
            Where-Object {
                @(Get-ChildItem -LiteralPath $_.FullName -Force -ErrorAction SilentlyContinue).Count -eq 0
            }
                        # Korrekte WhatIf-Unterstützung
            foreach ($emptyFolder in $emptyFolders) {
                        if ($PSCmdlet.ShouldProcess($emptyFolder.FullName, "Remove Empty Folder")) {
				try {
					Remove-Item -LiteralPath $emptyFolder.FullName -Force -ErrorAction Stop
					Write-Verbose "Erfolgreich gelöscht (Leerer Ordner): $($emptyFolder.FullName)"
				}
				catch {
					Write-Error "FEHLER (Leerer Ordner): $($_.Exception.Message)"
				}
            }
        }
    }
    # Gesamtergebnis ausgeben
    Write-Host ("{0:N2} MB eingespart." -f ($totalSize / 1MB))

    # Optional: Gelöschte Dateien anzeigen oder exportieren
    # $deletedFiles | Sort-Object SizeMB -Descending | Format-Table -AutoSize
    # $deletedFiles | Export-Csv "C:\CleanupLog.csv" -NoTypeInformation -Encoding UTF8
}


# Ausführung mit Simulation
# Clear-OldFiles -WhatIf -Verbose
# Für das echte Löschen: Clear-OldFiles -Verbose
