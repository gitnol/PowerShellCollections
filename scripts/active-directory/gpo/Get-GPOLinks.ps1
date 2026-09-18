# # Alle GPOs inkl. Links
# Get-GPOLinks

# # Nur eine bestimmte GPO (Name oder GUID, auch mit Wildcard)
# Get-GPOLinks -GPOName "Default*"

# # Nur unverknüpfte GPOs
# Get-GPOLinks -UnlinkedOnly

function Get-GPOLinks {
    [CmdletBinding()]
    param(
        [string]$GPOName,
        [switch]$UnlinkedOnly
    )

    $allGPOs = if ($GPOName) {
        # Direkt filtern auf Name oder GUID, damit wir nicht alle durchlaufen müssen
        Get-GPO -All | Where-Object {
            $_.DisplayName -like $GPOName -or $_.Id.Guid -like $GPOName
        }
    }
    else {
        Get-GPO -All
    }

    $result = foreach ($gpo in $allGPOs) {
        try {
            $xmlReport = Get-GPOReport -Guid $gpo.Id -ReportType Xml
            [xml]$xmlContent = $xmlReport
        }
        catch {
            Write-Warning "Fehler beim Einlesen von GPO $($gpo.DisplayName) ($($gpo.Id)): $($_.Exception.Message)"
            continue
        }

        $links = $xmlContent.GPO.LinksTo

        if ($links) {
            foreach ($link in $links) {
                [PSCustomObject]@{
                    DisplayName = $xmlContent.GPO.Name
                    GUID        = $xmlContent.GPO.Identifier.Identifier.InnerText
                    OU          = $link.SOMPath
                    Enabled     = $link.Enabled
                    Enforced    = $link.NoOverride
                }
            }
        }
        else {
            [PSCustomObject]@{
                DisplayName = $xmlContent.GPO.Name
                GUID        = $xmlContent.GPO.Identifier.Identifier.InnerText
                OU          = $null
                Enabled     = $false
                Enforced    = $false
            }
        }
    }

    if ($UnlinkedOnly) {
        $result = $result | Where-Object { -not $_.OU }
    }

    $result
}
