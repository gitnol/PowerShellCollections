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