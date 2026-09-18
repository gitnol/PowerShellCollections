# Diese Funktion liefert die zielgruppenbasierte Zuordnung innerhalb von GPPs bei GPOs.
# Wenn die Spalte SID leer ist, so ist die zielgruppenbasierte Zuordnung nicht gültig, da die Verarbeitung an die SID geknüpft ist.

function Get-GPPItemLevelTargeting {
    $GPOs = Get-GPO -All
    $Result = @()

    foreach ($GPO in $GPOs) {
        $GPOReport = Get-GPOReport -Guid $GPO.Id -ReportType Xml
        [xml]$xmlContent = $GPOReport

        # XPath Query
        $targetNodes = $xmlcontent.SelectNodes("//*[local-name()='FilterGroup']")

        foreach ($node in $targetNodes) {
            $Result += [PSCustomObject]@{
                GPOName   = $GPO.DisplayName
                GPOID     = $GPO.Id
                GroupName = $node.name
                SID       = $node.sid
            }
        }
    }

    return $Result
}

# Aufrufen der Funktion und Ergebnisse ausgeben
Get-GPPItemLevelTargeting | Out-GridView
Get-GPPItemLevelTargeting | Where-Object SID -eq ''
