Import-Module GroupPolicy # If this does not work with Powershell 7, try it as admin / elevated
# This function gets all settings from a GPO. together with "Get-GPO -All"  it is possible to search for settings within the whole domain
# When you have plenty of GPOs and have no clue which setting is set within which GPO. (without generating an GPResultset for a Computer or user on demand)

function Get-GPOReportSettings {
    param (
        $gpoName,
        $mynode,
        $sourceNode = @()
    )
    $sourceNode += $mynode.LocalName

    $mynode | Get-Member -MemberType Properties |  ForEach-Object {
        if ($_.Definition.StartsWith("string")) {
            $mynodePropertyName = $_.Name
            $mynodePropertyValue = $mynode."$($_.Name)"
            # Nodeinfos zurückgeben
            [pscustomobject]@{
                GPOName             = $gpoName
                Name                = $mynode.LocalName
                mynodePropertyName  = $mynodePropertyName
                mynodePropertyValue = $mynodePropertyValue 
                sourceNodeRevert    = ($sourceNode[($sourceNode.count - 1)..0] -join "<-") # Breadcumbs
                sourceNode          = ($sourceNode -join "->") # Breadcumbs
            }
        }
    }

    if ($mynode.HasChildNodes) {
        # Hat der Node ein Kindelement...
        foreach ($node in $mynode.Childnodes) {
            # # jedes Kindelement an die Funktion übergeben (Rekursion!)
            #rufdichselbstauf
            Get-GPOReportSettings -gpoName $gpoName  -mynode $node -sourceNode $sourceNode
        }
    } 
}

# Suchbegriff festlegen (Vorsicht bei nur *... das gibt Probleme mit der Datenmenge)
$suchbegriffSettings = "*Benutzer*"

# Begrenze es auf eine GPO mit dem folgendem Namen. "*" als Wildcard nutzbar"
$LimitToGPOName = "*lauf*"

# Ab brauch nichts mehr verändert werden:
# Alle GPOs laden (dauert etwas)
$GPOReport = Get-GPO -All | Where-Object DisplayName -like $LimitToGPOName  | ForEach-Object {
    [xml](Get-GPOReport -Guid $_.Id -ReportType Xml)
}

# Analyse und Ausgabe der GPOs mit den Suchbegriffen
$GPOReport | Where-Object { $_.GPO.Name -like $LimitToGPOName } | ForEach-Object { Get-GPOReportSettings  -mynode $_.GPO -gpoName $_.GPO.name } | Where-Object { $_ -like $suchbegriffSettings } | Out-GridView