<#
.SYNOPSIS
Aktiviert den Schutz vor versehentlichem Löschen für alle OUs in der Domäne.
#>
function Protect-OUs {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param()

    $ous = Get-ADOrganizationalUnit -Filter * -Properties ProtectedFromAccidentalDeletion |
    Sort-Object DistinguishedName

    $result = foreach ($ou in $ous) {
        $statusBefore = $ou.ProtectedFromAccidentalDeletion
        if (-not $statusBefore) {
            if ($PSCmdlet.ShouldProcess($ou.DistinguishedName, "Aktiviere Schutz vor versehentlichem Löschen")) {
                Set-ADOrganizationalUnit -Identity $ou.DistinguishedName -ProtectedFromAccidentalDeletion $true -ErrorAction Stop
            }
        }
        [PSCustomObject]@{
            OU                  = $ou.Name
            DistinguishedName   = $ou.DistinguishedName
            GeschütztVorLöschen = $true
            VorherGeschützt     = $statusBefore
            Aktion              = if ($statusBefore) { 'Keine Änderung' } else { 'Schutz aktiviert' }
        }
    }

    $result | Format-Table -AutoSize
}

# Beispielaufruf:
# Nur prüfen:
Protect-OUs -WhatIf

# Tatsächlich aktivieren:
# Protect-OUs
