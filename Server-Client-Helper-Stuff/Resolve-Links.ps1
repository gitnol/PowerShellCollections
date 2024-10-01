# This function searches for symlinks / junction points and hardlinks in a folder and subfolder.
# Administrative priviledges are needed. Otherwise the target can not be resolved.
# Due to a bug in Powershell 5.x it is not possible to resolve the target of a symlink. Therefore the execution is being limited to Powershell versions 7.x and above
function Resolve-Links {
    param (
        [string]$Path  # Der Pfad, der durchsucht werden soll
    )
    # Überprüfen, ob die PowerShell-Version 7 oder höher ist
    if ($PSVersionTable.PSVersion.Major -lt 7) {
        Write-Error "Dieses Skript erfordert PowerShell 7 oder höher."
        return
    }

    # Überprüfen, ob das Skript mit Administratorrechten ausgeführt wird
    if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
        Write-Error "Dieses Skript muss mit Administratorrechten ausgeführt werden."
        return
    }

    # Durchsuche alle Dateien und Ordner rekursiv
    Get-ChildItem -Path $Path -Recurse -Force -ErrorAction SilentlyContinue | ForEach-Object {
        $linkType = ''  # Typ des Links (symbolisch oder Hardlink)
        $attributes = $_.Attributes  # Attribute der Datei
        $target = $null  # Ziel des Links

        # Überprüfen, ob es sich um einen symbolischen Link handelt
        if ($attributes -band [System.IO.FileAttributes]::ReparsePoint) {
            $linkType = 'Symbolic Link'  # Setze den Linktyp
            # Hole das Ziel des symbolischen Links
            $target = (Get-Item $_.FullName -Force -ErrorAction SilentlyContinue).Target
        } 
        # Überprüfen, ob es sich um einen Hardlink handelt
        elseif ((Get-Item $_.FullName -Force -ErrorAction SilentlyContinue).Attributes -band [System.IO.FileAttributes]::Archive) {
            $linkType = 'Hard Link'  # Setze den Linktyp
            # Hole die Hardlink-Ziele mit fsutil
            $fsutilOutput = & fsutil hardlink list $_.FullName 2>$null
            # Filtere die Ausgabe, um nur die Hardlink-Pfade zu erhalten
            $target = $fsutilOutput | Where-Object { $_ -ne $_.FullName }
        }

        # Wenn ein Linktyp gefunden wurde, erstelle ein PSCustomObject
        if ($linkType) {
            [PSCustomObject]@{
                Name     = $_.Name           # Name der Datei
                FullName = $_.FullName       # Vollständiger Pfad
                LinkType = $linkType         # Typ des Links
                Target   = $target           # Ziel des Links
            }
        }
    }
}

# Beispielaufruf: Resolve-Links -Path "C:\install"
Resolve-Links -Path "C:\"
