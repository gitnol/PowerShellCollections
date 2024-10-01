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
    Get-ChildItem -LiteralPath c:\ -Force -Recurse -ErrorAction SilentlyContinue -Attributes reparsepoint | ForEach-Object {
        (Get-Item -LiteralPath $_.FullName -Force -ErrorAction SilentlyContinue) | Select-Object Name,FullName,LinkType,LinkTarget
    }
}

# Beispielaufruf: Resolve-Links -Path "C:\install"
# $result = Resolve-Links -Path "C:\"
Resolve-Links -Path "C:\"
