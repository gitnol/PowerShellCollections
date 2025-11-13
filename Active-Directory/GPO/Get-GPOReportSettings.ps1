Import-Module GroupPolicy # If this does not work with Powershell 7, try it as admin / elevated
# This function gets all settings from a GPO. together with "Get-GPO -All"  it is possible to search for settings within the whole domain
# When you have plenty of GPOs and have no clue which setting is set within which GPO. (without generating an GPResultset for a Computer or user on demand)

function Get-GPOReportSettings {
    param (
        $gpoName,
        $mynode, # Dies ist der aktuelle XML-Knoten (z.B. <q1:EditText>)
        $sourceNode = @()
    )
    # Beachte: Beim Start des Skriptblocks sollte für $sourceNode 
    # nur der Wert des aktuellen Knotens hinzugefügt werden.
    # Wenn $mynode ein XML-Node ist, ist LocalName passend.
    $sourceNode += $mynode.LocalName

    # Wir verwenden Get-Member auf dem XML-Knoten, um alle direkten Unterelemente
    # und Attribute als Properties zu finden, die Strings sein könnten.
    $mynode | Get-Member -MemberType Properties | ForEach-Object {
        # Wir filtern nach 'string' Properties, die oft direkt den Textinhalt 
        # eines Kindknotens repräsentieren, ODER nach XML-Knoten selbst.
        # Im GPO-Kontext können Properties wie 'Name', 'State', 'Value' Strings 
        # oder Kind-XML-Nodes sein, die als String zurückgegeben werden sollen.
        # Da Get-Member für diese Childnodes oft 'string' ausgibt, 
        # bleiben wir bei der Prüfung auf "string" oder "System.Xml.XmlElement".
        
        $isStringProp = $_.Definition.StartsWith("string") 
        $isXmlElementProp = $_.TypeName -eq 'System.Xml.XmlElement'
        
        if ($isStringProp -or $isXmlElementProp) {
            $mynodePropertyName = $_.Name
            
            # 1. Versuche den Wert direkt zu holen. Wenn das ChildNode leer ist (z.B. <q1:Name/>), 
            #    liefert $mynode."$mynodePropertyName" oft $null.
            $mynodePropertyValue = $mynode."$mynodePropertyName"

            # 2. Wenn $mynodePropertyValue $null ist, ist dies ein starker Hinweis darauf, 
            #    dass der Child-Knoten existiert, aber leer ist. Wir müssen explizit 
            #    .InnerText des Child-Knotens abrufen, um einen leeren String zu erhalten.
            if ($null -eq $mynodePropertyValue) { 
                # Versuche, den tatsächlichen XML-ChildNode zu finden
                $childNode = $mynode.$mynodePropertyName
                
                # Wenn der ChildNode existiert, aber keinen Wert hatte (wie bei <q1:Name />),
                # dann liefert .InnerText den leeren String "".
                if ($null -ne $childNode) {
                    $mynodePropertyValue = $childNode.InnerText
                }
                else {
                    # Falls es aus irgendeinem Grund $null bleibt, explizit auf leeren String setzen
                    $mynodePropertyValue = [string]::Empty
                }
            } 
            
            # WICHTIG: Wenn der Wert jetzt noch $null ist, war der Property-Name möglicherweise 
            # nicht vorhanden. Aber in den meisten Fällen, wo Get-Member es meldet, 
            # sollte er jetzt ein String oder ein leerer String sein.
            if ([string]::IsNullOrEmpty($mynodePropertyValue)) {
                $mynodePropertyValue = [string]::Empty
            }


            # Nodeinfos zurückgeben
            [pscustomobject]@{
                GPOName             = $gpoName
                Name                = $mynode.LocalName
                mynodePropertyName  = $mynodePropertyName
                mynodePropertyValue = $mynodePropertyValue # <- Jetzt ist es ein String oder ein leerer String
                sourceNodeRevert    = ($sourceNode[($sourceNode.count - 1)..0] -join "<-")
                sourceNode          = ($sourceNode -join "->")
            }
        }
    }

    # Rekursion für ChildNodes
    if ($mynode.HasChildNodes) {
        # Hat der Node ein Kindelement...
        foreach ($node in $mynode.Childnodes) {
            # Da der XML-Knoten $mynode.Childnodes auch Text-Knoten enthält,
            # prüfen wir, ob es sich um ein Element handelt.
            if ($node.NodeType -eq [System.Xml.XmlNodeType]::Element) {
                # jedes Kindelement an die Funktion übergeben (Rekursion!)
                Get-GPOReportSettings -gpoName $gpoName -mynode $node -sourceNode $sourceNode
            }
        }
    } 
    # Nach der Rekursion den aktuellen Node aus $sourceNode entfernen (wird aber im 
    # nächsten Aufruf des $sourceNode-Parameters automatisch korrekt gehandhabt, 
    # solange $sourceNode als Parameter übergeben wird).
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
# Alles - Sehr langsam bei sehr vieen GPOs
# $GPOReport | Where-Object { $_.GPO.Name -like $LimitToGPOName } | ForEach-Object { Get-GPOReportSettings  -mynode $_.GPO -gpoName $_.GPO.name } | Out-GridView