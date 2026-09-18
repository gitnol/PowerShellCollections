<#
.SYNOPSIS
    Liest die Dateiversion einer DLL oder EXE aus.

.DESCRIPTION
    Gibt die Versionsinformationen aus den Dateiressourcen zurueck -
    FileVersion, ProductVersion und Herstellerangaben.

    Nuetzlich, wenn ein Programm ohne Eintrag in Programme und Features
    installiert ist oder wenn die tatsaechlich geladene Bibliothek von der
    registrierten abweicht.

.NOTES
    Die Dateiversion kann von der Produktversion abweichen; bei
    Kompatibilitaetsfragen ist meist die Dateiversion die relevante.
#>

function Get-DllVersion {
    param (
        [Parameter(Mandatory)]
        [string]$Pfad
    )

    if (-not (Test-Path $Pfad)) {
        throw "Datei nicht gefunden: $Pfad"
    }

    $info = Get-Item -Path $Pfad | Select-Object -ExpandProperty VersionInfo

    [PSCustomObject]@{
        Datei    = $info.FileName
        Major    = $info.FileMajorPart
        Minor    = $info.FileMinorPart
        Build    = $info.FileBuildPart
        Revision = $info.FilePrivatePart
    }
}

# Get-DllVersion -Pfad 'C:\Tools\openssl\libeay32.dll'