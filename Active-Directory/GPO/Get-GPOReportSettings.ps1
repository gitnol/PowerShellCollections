Import-Module GroupPolicy # If this does not work with Powershell 7, try it as admin / elevated
# This function gets all settings from a GPO. together with "Get-GPO -All"  it is possible to search for settings within the whole domain
# When you have plenty of GPOs and have no clue which setting is set within which GPO. (without generating an GPResultset for a Computer or user on demand)
 
# Version 5.0: Hybrid-Ansatz für vollständige Abdeckung.
# - Kombiniert die intelligente Zusammenfassung von ADMX-Richtlinien (`<Policy>`-Knoten) mit einer generischen,
#   rekursiven Analyse für alle anderen GPO-Einstellungen (Preferences, Security Settings etc.).
# - Stellt sicher, dass keine Einstellung im GPO-Bericht übersehen wird.


function Get-GPOReportSettings {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$GpoName,

        [Parameter(Mandatory = $true)]
        [System.Xml.XmlElement]$XmlNode
    )

    # Interne Hilfsfunktion, um ADMX-basierte Richtlinien sauber zu parsen.
    function ConvertFrom-PolicyNode {
        param($policyNode)

        $policyName = $policyNode.SelectSingleNode("*[local-name()='Name']")?.InnerText
        $policyState = $policyNode.SelectSingleNode("*[local-name()='State']")?.InnerText
        $policyCategory = $policyNode.SelectSingleNode("*[local-name()='Category']")?.InnerText
        $policyExplain = $policyNode.SelectSingleNode("*[local-name()='Explain']")?.InnerText

        # NEU: Ermitteln, ob es sich um eine Computer- oder Benutzerrichtlinie handelt.
        $configType = "Unbekannt"
        if ($policyNode.SelectSingleNode("ancestor::*[local-name()='Computer']")) {
            $configType = "Computer"
        }
        elseif ($policyNode.SelectSingleNode("ancestor::*[local-name()='User']")) {
            $configType = "Benutzer"
        }

        $childSettingNodes = $policyNode.SelectNodes("*[local-name()!='Name' and local-name()!='State' and local-name()!='Category' and local-name()!='Explain' and local-name()!='Supported' and local-name()!='Text']")

        $settingsList = foreach ($node in $childSettingNodes) {
            $settingName = $node.SelectSingleNode("*[local-name()='Name']")?.InnerText
            $settingValue = ''

            switch ($node.LocalName) {
                'EditText' { $settingValue = $node.SelectSingleNode("*[local-name()='Value']")?.InnerText }
                'CheckBox' { $settingValue = $node.SelectSingleNode("*[local-name()='State']")?.InnerText }
                'DropDownList' { $settingValue = $node.SelectSingleNode("*[local-name()='Value']/*[local-name()='Name']")?.InnerText }
                'ListBox' {
                    $listItems = $node.SelectNodes(".//*[local-name()='Data']") | ForEach-Object { $_.InnerText }
                    $settingValue = $listItems -join ', '
                }
                default {
                    $settingValue = $node.SelectSingleNode("*[local-name()='Value']")?.InnerText
                }
            }

            if ([string]::IsNullOrWhiteSpace($settingName)) {
                $settingName = $node.LocalName
            }

            "$settingName = $settingValue"
        }

        [pscustomobject]@{
            GPOName           = $GpoName
            PolicyName        = $policyName
            PolicyState       = $policyState
            CategoryPath      = $policyCategory
            Konfigurationstyp = $configType # NEUE Spalte
            Settings          = $settingsList -join '; '
            Explain           = $policyExplain
            Type              = "Policy"
            Path              = "GPO -> " + ($policyCategory -replace '/', ' -> ')
        }
    }

    # Interne, rekursive Funktion für alle anderen Einstellungen.
    function Get-GenericSettings {
        param($node, $currentPath)

        # 1. Attribute des Knotens ausgeben
        foreach ($attribute in $node.Attributes) {
            [pscustomobject]@{
                GPOName           = $GpoName
                PolicyName        = $node.LocalName
                PolicyState       = $null
                Konfigurationstyp = $null # Nicht relevant für generische Einstellungen
                CategoryPath      = $null
                Settings          = "$($attribute.Name) = $($attribute.Value)"
                Explain           = $null # KORREKTUR: Eigenschaft für konsistente Ausgabe hinzufügen
                Type              = 'Attribute'
                Path              = $currentPath -join ' -> '
            }
        }

        # 2. Kindknoten rekursiv durchlaufen
        $childNodes = $node.ChildNodes | Where-Object { $_.NodeType -eq 'Element' }
        if ($childNodes.Count -gt 0) {
            foreach ($childNode in $childNodes) {
                # WICHTIG: Wenn wir einen 'Policy'-Knoten finden, stoppen wir die Rekursion hier,
                # da dieser separat behandelt wird.
                if ($childNode.LocalName -ne 'Policy') {
                    Get-GenericSettings -node $childNode -currentPath ($currentPath + $childNode.LocalName)
                }
            }
        }
        # 3. Textwert des Endknotens ausgeben
        else {
            if (-not [string]::IsNullOrWhiteSpace($node.InnerText)) {
                [pscustomobject]@{
                    GPOName           = $GpoName
                    PolicyName        = $node.ParentNode.LocalName
                    PolicyState       = $null
                    Konfigurationstyp = $null # Nicht relevant für generische Einstellungen
                    CategoryPath      = $null
                    Settings          = "$($node.LocalName) = $($node.InnerText.Trim())"
                    Explain           = $null # KORREKTUR: Eigenschaft für konsistente Ausgabe hinzufügen
                    Type              = 'Value'
                    Path              = $currentPath -join ' -> '
                }
            }
        }
    }

    # --- HAUPTAUSFÜHRUNG ---
    # KORREKTUR: Reihenfolge geändert, um sicherzustellen, dass das erste Objekt alle Spalten hat.
    # 1. Zuerst die reichhaltigen ADMX-basierten Richtlinien parsen.
    $policyNodes = $XmlNode.SelectNodes(".//*[local-name()='Policy']")
    foreach ($policyNode in $policyNodes) {
        ConvertFrom-PolicyNode -policyNode $policyNode
    }

    # 2. Danach alle anderen Einstellungen generisch und rekursiv durchlaufen.
    Get-GenericSettings -node $XmlNode -currentPath @($XmlNode.LocalName)
}

# Suchbegriff festlegen (Vorsicht bei nur *... das gibt Probleme mit der Datenmenge)
$suchbegriffSettings = "*Startseite*"

# Begrenze es auf eine GPO mit dem folgendem Namen. "*" als Wildcard nutzbar"
$LimitToGPOName = "*Firefox*"

# Ab brauch nichts mehr verändert werden:
# Alle GPOs laden (dauert etwas)
$GPOs = Get-GPO -All | Where-Object { $_.DisplayName -like $LimitToGPOName }

Write-Host "Analysiere $($GPOs.Count) GPO(s)..."

# Die Ergebnisse aller GPO-Analysen in einer Variablen sammeln
$allSettings = foreach ($gpo in $GPOs) {
    Write-Host "Verarbeite GPO: $($gpo.DisplayName)"
    $xmlString = Get-GPOReport -Guid $gpo.Id -ReportType Xml
    $xmlReport = [xml]$xmlString

    # Wir rufen die Funktion für den gesamten GPO-Knoten auf.
    # Die Funktion durchsucht dann selbstständig alle Unterbereiche (Computer/User).
    Get-GPOReportSettings -GpoName $gpo.DisplayName -XmlNode $xmlReport.GPO
}

# Analyse und Ausgabe der GPOs mit den Suchbegriffen
$allSettings | Where-Object { $_.PolicyName -like $suchbegriffSettings -or $_.Settings -like "*$suchbegriffSettings*" -or $_.CategoryPath -like "*$suchbegriffSettings*" } | Out-GridView

Write-Host "Analyse abgeschlossen."