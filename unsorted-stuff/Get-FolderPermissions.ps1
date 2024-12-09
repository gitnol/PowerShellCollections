# This script looks for folder permissions recursively and lists those ones, which have (non inherited) single user permissions
# The first function Get-FolderPermissions uses a cache so that Get-ADUser is not being fired all the time.
# The second function Get-FolderPermissionsOLD has no cache functionality... 

function Get-FolderPermissions {
    param (
        [string]$Path,
        [int]$Depth = 2
    )

    # Ergebnisse und Cache initialisieren
    $result = @()
    if (-not $script:Cache) { $script:Cache = @{} }

    # Verzeichnisstruktur durchlaufen
    Get-ChildItem -Path $Path -Recurse -Directory -Depth $Depth | ForEach-Object {
        $folderPath = $_.FullName
        Write-Host "Prüfe Ordner: $folderPath"

        # Berechtigungen abrufen
        $acl = Get-Acl -Path $folderPath
        $customAccess = $acl.Access | Where-Object { -not $_.IsInherited }

        # Berechtigungen verarbeiten
        foreach ($entry in $customAccess) {
            $key = $entry.IdentityReference.Value

            # Prüfen, ob Benutzer bereits im Cache ist
            if (-not $script:Cache.ContainsKey($key)) {
                try {
                    $script:Cache[$key] = ""
                    $userSID = $entry.IdentityReference.Translate([System.Security.Principal.SecurityIdentifier]).Value
                    $samAccountName = (Get-ADUser -Identity $userSID -ErrorAction SilentlyContinue).SamAccountName
                    $script:Cache[$key] = $samAccountName
                } catch {
                    # Fehler ignorieren
                    Write-Warning "Konnte Benutzerinformationen für $key nicht abrufen."
                }
            }

            # Ergebnis hinzufügen, falls Benutzer gefunden
            if ($script:Cache[$key] -ne "") {
                $result += [PSCustomObject]@{
                    Folder     = $folderPath
                    ObjectUser = $script:Cache[$key]
                }
            }
        }
    }

    return $result
}



# function Get-FolderPermissionsOLD {
#     param (
#         [string]$Path,
#         [int]$Depth = 2
#     )

#     $result = @()

#     Get-ChildItem -Path $Path -Recurse -Directory -Depth $Depth | ForEach-Object {
#         $folderPath = $_.FullName
#     Write-Host ($folderPath)
#         $acl = Get-Acl -Path $folderPath
#         $customAccess = $acl.Access | Where-Object { 
#             -not $_.IsInherited
#         }

#         foreach ($entry in $customAccess) {
#             try {
#                 $samAccountName = (Get-ADUser -Identity ($entry.IdentityReference.Translate([System.Security.Principal.SecurityIdentifier]).Value) -ErrorAction SilentlyContinue).SamAccountName
#                 $result += [PSCustomObject]@{
#                     Folder     = $folderPath
#                     ObjectUser = $samAccountName
#                 }
#             } catch {
#                 # Fehler ignorieren
#             }
#         }
#     }

#     return $result
# }