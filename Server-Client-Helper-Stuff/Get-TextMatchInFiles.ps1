function Get-TextMatchInFiles {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [string]$Path,                   # Verzeichnis, das durchsucht werden soll

        [Parameter(Mandatory)]
        [string[]]$ContainsAll,          # Alle Begriffe, die in einer Zeile vorkommen müssen

        [string]$Filter = '*.txt',       # Dateifilter, z.B. *.log, *.conf

        [switch]$Recurse                 # Optional rekursiv in Unterverzeichnissen suchen
    )

    # Dateien nach Filter einsammeln
    $files = Get-ChildItem -Path $Path -Filter $Filter -File -Recurse:$Recurse

    foreach ($file in $files) {
        $found = $false

        # Jede Zeile einzeln prüfen
        foreach ($line in Get-Content -Path $file.FullName) {
            $match = $true

            # Alle Suchbegriffe müssen in der Zeile vorkommen (UND-Verknüpfung)
            foreach ($term in $ContainsAll) {
                if ($line -notmatch $term) {
                    $match = $false
                    break
                }
            }

            # Treffer gefunden, Abbruch der weiteren Prüfung
            if ($match) {
                $found = $true
                break
            }
        }

        # Ergebnis als Objekt zurückgeben
        [PSCustomObject]@{
            Dateiname = $file.Name
            Gefunden  = $found
            Fullname  = $file.FullName
        }
    }
}


# # Beispielaufruf: Alle Dateien im Verzeichnis und Unterverzeichnissen, die alle Begriffe "snmp", "public" und "unrestricted" enthalten
# Get-TextMatchInFiles -Path "\\MEINSERVER\SHARENAME" -ContainsAll @("snmp", "public", "unrestricted") -Filter "*.cfg" -Recurse

# # Beispielaufruf (Simple Version): Alle Dateien im aktuellen Verzeichnis, die den Text "snmp" und nachfolgend "public" und nachfolgend "unrestricted" enthalten
# Get-ChildItem | ForEach-Object {
#     [pscustomobject]@{
#         Dateiname = $_.Name;
#         Gefunden  = (Select-String $_ -Pattern ".*snmp.+public.+unrestricted.*" -Quiet);
#         Fullname  = $_.Fullname
#     }
# }