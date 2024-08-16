# This function gets all settings from a GPO. together with "Get-GPO -All"  it is possible to search for settings within the whole domain
# When you have plenty of GPOs and have no clue which setting is set within which GPO. (without generating an GPResultset for a Computer or user on demand)

function Get-GPOReportSettings {
    param (
        $mynode,
        $sourceNodeName = "",
        $sourceNodeName2 = "",
        $gpoName
    )

    $mynodeName = $mynode.LocalName
    $mynode | Get-Member -MemberType Properties |  ForEach-Object {
        if ($_.Definition.StartsWith("string")) {
            $mynodePropertyName = $_.Name
            $mynodePropertyValue = $mynode."$($_.Name)"
            # Nodeinfos zurückgeben
            [pscustomobject]@{
                GPOName             = $gpoName
                Name                = $mynodeName
                mynodePropertyName  = $mynodePropertyName
                mynodePropertyValue = $mynodePropertyValue 
                SourceNodeName      = $sourceNodeName
                SourceNodeName2     = $sourceNodeName2
            }
        }
    }

    if ($mynode.HasChildNodes) {
        # Hat der Node ein Kindelement...
        foreach ($node in $mynode.Childnodes) {
            # jedes Kindelement an die Funktion übergeben (Rekursion!)
            # Merke dir die Historie
            if ($sourceNodeName -eq "") {
                $historie = $mynode.LocalName
                $historie2 = $mynode.LocalName
            }
            else {
                $historie = $mynode.LocalName + "<-" + $sourceNodeName
                $historie2 = $sourceNodeName + "->" + $mynode.LocalName
            }
            #rufdichselbstauf
            checkiechan -mynode $node -sourceNodeName $historie -sourceNodeName2 $historie2 -gpoName $gpoName
        }
    } 
}


# Alle GPOs laden (dauert etwas)
$GPOReport = Get-GPO -All | ForEach-Object {
    [xml](Get-GPOReport -Guid $_.Id -ReportType Xml)
}

# Suchbegriff festlegen (Vorsicht bei nur *... das gibt Probleme mit der Datenmenge)
$suchbegriffSettings = "*Logix*"

$LimitToGPOName = "*Logix*"

# Analyse und Ausgabe der GPOs mit den Suchbegriffen
$GPOReport | Where-Object { $_.GPO.Name -like $LimitToGPOName } | ForEach-Object { Get-GPOReportSettings  -mynode $_.GPO -gpoName $_.GPO.name } | Where-Object { $_ -like $suchbegriffSettings } | Out-GridView

