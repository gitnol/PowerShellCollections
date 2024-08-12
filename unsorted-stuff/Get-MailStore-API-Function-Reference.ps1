# Because Mailstore does not give OpenAPI / Swagger Files... i have to structure it on my own... :(

# Get the content of the page
$erg = Invoke-WebRequest -UseBasicParsing -Uri "https://help.mailstore.com/en/server/Administration_API_-_Function_Reference"

# Step 2: Define the regular expression pattern to match <script>...</script> tags
$regexPattern = '<script.*?</script>'  # Match <script> tags and everything until </script>

# Step 3: Clean the content (Remove Script Tags and so on...)
$cleanedContent = [regex]::Replace($erg.Content, $regexPattern, '', [System.Text.RegularExpressions.RegexOptions]::Singleline)
$cleanedContent = [regex]::Replace($cleanedContent, '<!DOCTYPE html>', '', [System.Text.RegularExpressions.RegexOptions]::Singleline)
$cleanedContent = [regex]::Replace($cleanedContent, '<!-- 0 -->', '', [System.Text.RegularExpressions.RegexOptions]::Singleline)

# Alle h2 Nodes auswählen
$h2Nodes = ([xml]$cleanedContent).SelectNodes("//h2")
$h2NodesCount = ($h2Nodes).Count 

# Speichere alles zwischen den h2 tags in der Variable $myfunctions
$start = 0
$myfunctions = @()
Do {
    $currentNode = $start
    $nextNode = $start + 1
    Write-Host($currentNode)
    $firstH2 = $h2Nodes[$currentNode]
    $nextH2 = $h2Nodes[$nextNode]
	
    # Get content between the first and the second h2
    $contentBetween = @()
    $currentNode = $firstH2
    $functionName = $firstH2.span.'#text'

    while ($currentNode = $currentNode.NextSibling) {
        if ($currentNode -eq $nextH2) {
            break
        }
        $contentBetween += $currentNode.OuterXml
    }
    $myfunction = [xml]('<function name="' + $functionName + '">' + $contentBetween + '</function>')
    $myfunctions += $myfunction

    $start = $nextNode
} While ($nextNode -lt $h2NodesCount)


#######################
# $xml = [xml]$myfunction.OuterXml;$xml.SelectNodes("//table").tbody.tr | % {$_.ChildNodes[1].InnerText}

# # Das liefert die Nodes
# foreach ($node in $xml.DocumentElement.ChildNodes) {$node.Name}

# # Das folgende lieferte den Tag Ablauf (der ersten Ebene) innerhalb der funktion
# $allefunktionsaufbau = @()
# foreach ($function in ($myfunctions.function | select -first 100)) {
# $xml = [xml]$function.OuterXml
# $funktionsaufbau = @()
# foreach ($node in $xml.DocumentElement.ChildNodes) {
# if ($node.Name -ne '#comment') {
# $funktionsaufbau += [pscustomobject]@{
# NodeName = $node.Name
# }
# }
# }
# $allefunktionsaufbau += [pscustomobject]@{funktionsaufbau = $funktionsaufbau}
# }
# # Hiermit bekommt man den Aufbau , aber nur UNIQUE... also wie viele Verschiedene Aufbauten der tags gibt es.
# $allefunktionsaufbau | Sort-Object -Unique -Property funktionsaufbau | % {Write-Host("START");Write-Host($_.funktionsaufbau.NodeName) -ForegroundColor Green;Write-Host("ENDE")}
# # VARIANTEN, die Vorkommen
# # "p" {}
# # "p p" {}
# # "p h3 table" {}
# # "p h3 table p" {}
# # "p h3 table p p" {}
# # "p h3 table h3 h4 div" {}# # "p h3 table h3 h4 p div" {}
# # "p h3 table h3 h4 table h4 table" {}
# # "p h3 table h3 h4 table p h4 table" {}
# # "p h3 table p h3 h4 table h4 table h4 table" {}



$myNewFunctionDefinitions = @()
foreach ($function in ($myfunctions.function)) {
    # foreach ($function in ($myfunctions.function | select -first 1000)) {
    $xml = [xml]$function.OuterXml
    $functionName = $xml.function.name.trim()
    $functionDescription = ''
    $h3TableDescription = ''
    # $h4TableDescription = ''
    $ArgumentsValuesDescription = ''
    $myNewFunctionDefinition = [pscustomobject]@{
        Name                       = $functionName
        Description                = $functionDescription
        ArgumentsTable             = @()
        ArgumentsTableDescription  = $h3TableDescription
        ArgumentsValuesTable       = @()
        # ArgumentsValuesTableDescription = $h4TableDescription
        ArgumentsValuesDescription = $ArgumentsValuesDescription
    }

    $NodeNamehistory = '' # Zurücksetzen der Tag History, damit man genau sieht, wo man sich gerade befindet und switch Unterscheidungen machen kann. Dann kann man den Inhalt entsprechend zuweisen.
    # $lastNodeName = ''
    $ArgumentValueName = ''
    foreach ($node in $xml.DocumentElement.ChildNodes) {
        $NodeNamehistory = ($NodeNamehistory + " " + $node.Name).trim()
        switch ($node.Name) {
            "p" {
                switch ($NodeNamehistory) {
                    "p" {
                        # Function Description
                        $myNewFunctionDefinition.Description = $node.InnerText.trim()
                    }
                    "p p" {
                        # Add to Function Description
                        $myNewFunctionDefinition.Description += "`r`n" + $node.InnerText.trim()
                    }
                    "p h3 table p" {
                        # ArgumentsTableDescription
                        $myNewFunctionDefinition.ArgumentsTableDescription = $node.InnerText.trim()
                    }
                    "p h3 table p p" {
                        $myNewFunctionDefinition.ArgumentsTableDescription += "`r`n" + $node.InnerText.trim()
                    }
                    "p h3 table h3 h4 p" {
                        $myNewFunctionDefinition.ArgumentsValuesDescription = $node.InnerText.trim()
                    }
                    # "p h3 table h3 h4 table p" {
                    # # Write-Host($functionName + ":" + $ArgumentValueName) -ForegroundColor Red
                    # # Write-Host("p h3 table h3 h4 table p") -ForegroundColor Red
                    # # Write-Host($node.InnerText.trim()) -ForegroundColor Red # nur ein FUcking nochmal Zeilenumbruch im p tag unter Create User :-(
                    # $myNewFunctionDefinition.ArgumentsValuesTableDescription = $node.InnerText.trim()
                    # }
                }
            }
            "div" {
                switch ($NodeNamehistory) {
                    "p h3 table h3 h4 div" {
                        # Set ArgumentsValuesDescription
                        $myNewFunctionDefinition.ArgumentsValuesDescription = $node.InnerText.trim()
                    }
                    "p h3 table h3 h4 p div" {
                        # Add to ArgumentsValuesDescription
                        $myNewFunctionDefinition.ArgumentsValuesDescription += "`r`n" + $node.InnerText.trim()
                    }
                }
            }			
            "h3" {
                switch ($NodeNamehistory) {
                    # hier muss nichts gemacht werden.
                    "p h3" {}
                    "p h3 table h3" {}
                    "p h3 table p h3" {}
                }
            }
            "h4" {
                switch ($NodeNamehistory) {
                    # hier muss nichts gemacht werden.
                    "p h3 table h3 h4" {
                        $ArgumentValueName = $node.InnerText.trim()
                    }
                    "p h3 table h3 h4 table h4" {
                        $ArgumentValueName = $node.InnerText.trim()
                    }
                    "p h3 table h3 h4 table p h4" {
                        $ArgumentValueName = $node.InnerText.trim()
                    }
                    "p h3 table p h3 h4" {
                        $ArgumentValueName = $node.InnerText.trim()
                    }
                    "p h3 table p h3 h4 table h4" {
                        $ArgumentValueName = $node.InnerText.trim()
                    }
                    "p h3 table p h3 h4 table h4 table h4" {
                        $ArgumentValueName = $node.InnerText.trim()
                    }
                }				
            }
            "table" {
                $table = [pscustomobject]@{
                    TableRows        = @()
                    TableDescription = ''
                }
                $Zeilen = $node.tbody.tr
                $anzahlSpalten = $Zeilen[0].ChildNodes.count
                $Zeilen | Select-Object -Skip 1 | ForEach-Object {
                    $spalte1 = $_.ChildNodes[0].InnerText.trim()
                    $spalte2 = $_.ChildNodes[1].InnerText.trim()
                    if ($anzahlSpalten -ge 3) {
                        # Arguments Table
                        $spalte3 = $_.ChildNodes[2].InnerText.trim()
                        $nodeTableRow = [pscustomobject]@{
                            ArgumentName        = $spalte1
                            ArgumentTypeOriginal= $spalte2
                            ArgumentType        = ($spalte2 -replace '\(optional\)','').trim()
                            ArgumentDescription = $spalte3
                            Mandatory           = (-not ($spalte2 -like "*(optional)*"))
                            ArgumentValuesTable = @() # Neu
                        }
                    }
                    if ($anzahlSpalten -eq 2) {
                        # Argument Values Table
                        $nodeTableRow = [pscustomobject]@{
                            ArgumentName                     = $ArgumentValueName
                            ArgumentNameValidItem            = $spalte1
                            ArgumentNameValidItemDescription = $spalte2
                        }
                    }
                    $table.TableRows += $nodeTableRow
                }
				
                switch ($NodeNamehistory) {
                    "p h3 table" {
                        $myNewFunctionDefinition.ArgumentsTable += $table
                    }	
                    "p h3 table h3 h4 table" {
                        $myNewFunctionDefinition.ArgumentsValuesTable += $table
                        # Zu jedem Argument die entsprechend erlaubten Werte als Tabelle mit abspeichern.
						(($myNewFunctionDefinition | Where-Object { $_.Name -eq $functionName }).ArgumentsTable.TableRows | Where-Object { $_.ArgumentName -eq $ArgumentValueName }).ArgumentValuesTable += $table
                    }
                    "p h3 table h3 h4 table h4 table" {
                        $myNewFunctionDefinition.ArgumentsValuesTable += $table
						(($myNewFunctionDefinition | Where-Object { $_.Name -eq $functionName }).ArgumentsTable.TableRows | Where-Object { $_.ArgumentName -eq $ArgumentValueName }).ArgumentValuesTable += $table
                    }
                    "p h3 table h3 h4 table p h4 table" {
                        $myNewFunctionDefinition.ArgumentsValuesTable += $table
						(($myNewFunctionDefinition | Where-Object { $_.Name -eq $functionName }).ArgumentsTable.TableRows | Where-Object { $_.ArgumentName -eq $ArgumentValueName }).ArgumentValuesTable += $table
                    }
                    "p h3 table p h3 h4 table" {
                        $myNewFunctionDefinition.ArgumentsValuesTable += $table
						(($myNewFunctionDefinition | Where-Object { $_.Name -eq $functionName }).ArgumentsTable.TableRows | Where-Object { $_.ArgumentName -eq $ArgumentValueName }).ArgumentValuesTable += $table
                    }
                    "p h3 table p h3 h4 table h4 table" {
                        $myNewFunctionDefinition.ArgumentsValuesTable += $table
						(($myNewFunctionDefinition | Where-Object { $_.Name -eq $functionName }).ArgumentsTable.TableRows | Where-Object { $_.ArgumentName -eq $ArgumentValueName }).ArgumentValuesTable += $table
                    }
                    "p h3 table p h3 h4 table h4 table h4 table" {
                        $myNewFunctionDefinition.ArgumentsValuesTable += $table
						(($myNewFunctionDefinition | Where-Object { $_.Name -eq $functionName }).ArgumentsTable.TableRows | Where-Object { $_.ArgumentName -eq $ArgumentValueName }).ArgumentValuesTable += $table
                    }
                }
                $ArgumentValueName = '' # Zurücksetzen.
            }
        }
    }
    $myNewFunctionDefinitions += $myNewFunctionDefinition
}

$myNewFunctionDefinitions

# 
$functionDefinitions = @()
$myNewFunctionDefinitions | ForEach-Object {
    $functionName = $_.Name
    $ArgumentsTable=$_.ArgumentsTable
    $ArgumentsValuesTable=$_.ArgumentsValuesTable
    $functionDefinition = [PSCustomObject]@{
        function = $functionName
        parameters = @()
    }
    $ArgumentsTable.TableRows | ForEach-Object {
        $ArgumentName = $_.ArgumentName
        $ArgumentType = $_.ArgumentType
        $Mandatory = $_.Mandatory
        $validItems = ($ArgumentsValuesTable.TableRows | Where-Object ArgumentName -eq $ArgumentName).ArgumentNameValidItem -join ','

        $parameter = [pscustomobject]@{
            # function = $functionName
            ArgumentName = $ArgumentName
            ArgumentType = $ArgumentType
            Mandatory = $mandatory 
            ValidItems = $validItems
        }
        $functionDefinition.parameters += $parameter
    }
    $functionDefinitions += $functionDefinition
}
# Nice OverView over all functions with parameters, parametertypes, mandatory and validItemValues
$functionDefinitions | Out-GridView -Title "Nice structured OverView"

$overview = $myNewFunctionDefinitions | ForEach-Object {
    $functionName = $_.Name
    $ArgumentsTable=$_.ArgumentsTable
    $ArgumentsValuesTable=$_.ArgumentsValuesTable
    $ArgumentsTable.TableRows | ForEach-Object {
        $ArgumentName = $_.ArgumentName
        $ArgumentType = $_.ArgumentType
        $Mandatory = $_.Mandatory
        $validItems = ($ArgumentsValuesTable.TableRows | Where-Object ArgumentName -eq $ArgumentName).ArgumentNameValidItem -join ','
        [pscustomobject]@{
            function = $functionName
            ArgumentName = $ArgumentName
            ArgumentType = $ArgumentType
            Mandatory = $mandatory 
            ValidItems = $validItems
        }
    }
}
# Nice OverView over all functions with parameters, parametertypes, mandatory and validItemValues
$overview | Out-GridView -Title "Nice OverView over all functions with parameters, parametertypes, mandatory and validItemValues"

# ToDo ... Jetzt können die Funktionen automatisch erstellt werden.

function bla {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
        [PSCustomObject]
        $functionDefinition
    )
    $functionName = $functionDefinition.function
    $firstUppercasePosition = ($functionName.ToCharArray() | % {$_} | Where {$_ -cmatch "[A-Z]"} | select -skip 1 -First 1)
    if ($firstUppercasePosition) {
        $index = $functionName.IndexOf($firstUppercasePosition) + 1

        $beforeUppercase = $functionName.Substring(0, $index - 1)
        $afterUppercase = $functionName.Substring($index - 1)
        
        # Write-Output "The first uppercase character is at position $index."
    } else {
        # Write-Output "No uppercase character found."
    }

    $functionNameModified = $beforeUppercase + '-MS' + $afterUppercase
    # Write-Host($functionNameModified)
    $parameters = $functionDefinition.parameters
    
    $paramStrings = @()
    $paramJsons = @()
    $parameters | ForEach-Object {
        $parameter = $_
        $parameter | ForEach-Object {
            $parameterName = $_.ArgumentName
            $parameterArgumentType = $_.ArgumentType        
            $parameterMandatory = $_.Mandatory
            $parameterValidItems = $_.ValidItems

            $paramJson = '<<parameterName>> = "$<<parameterName>>"'
            $paramJson = ($paramJson -replace '<<parameterName>>',$parameterName)
            $paramJsons += $paramJson

            $paramString = @'
[Parameter(Mandatory = $<<parameterMandatory>>, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]<<paramStringValidateSets>>
[<<parameterArgumentType>>]$<<parameterName>>,

'@
            if ($parameterArgumentType -eq "bool"){$parameterArgumentType = "Boolean"}
            if ($parameterArgumentType -eq "json"){$parameterArgumentType = "string"}
            if ($parameterArgumentType -eq "number"){$parameterArgumentType = "int"}
            if ($parameterValidItems -like "*1 to 31*") {
                $parameterValidItems = ($parameterValidItems -replace '1 to 31','1,2,3,4,5,6,7,8,9,10,11,11,12,13,14,15,16,17,18,29,20,21,22,23,24,25,26,27,28,29,30,31')
            }

            $paramStringValidateSets = @"

[ValidateSet(<<parameterValidItems>>)]
"@

            $paramStringValidateSets = ($paramStringValidateSets -replace '<<parameterValidItems>>',$parameterValidItems)
            $paramString = ($paramString -replace '<<parameterMandatory>>',$parameterMandatory)
            $paramString = ($paramString -replace '<<parameterArgumentType>>',$parameterArgumentType)
            $paramString = ($paramString -replace '<<parameterName>>',$parameterName)
            if(-not $parameterValidItems){$paramStringValidateSets = ''}
            $paramString = ($paramString -replace '<<paramStringValidateSets>>',$paramStringValidateSets)
            $paramStrings += $paramString
        }
    }

    $allparamStrings = $paramStrings -join "`r`n"

    # Write-Host($paramStrings)

    $functionstring = @'
function <<functionNameModified>> {
    [CmdletBinding()]
    param (
        <<allparamStrings>>
        [Parameter(Mandatory = $true)]
        $msapiclient
    )
    process {
        $<<functionName>> = (Invoke-MSApiCall -MSApiClient $msapiclient -ApiFunction "<<functionName>>" -ApiFunctionParameters @{<<parameterJsons>>}).result
        $<<functionName>>
    }
}
'@


$functionstring = ($functionstring -replace '<<functionNameModified>>',$functionNameModified)
$functionstring = ($functionstring -replace '<<allparamStrings>>',$allparamStrings)
$functionstring = ($functionstring -replace '<<functionName>>',$functionName)
$parameterJsons = $paramJsons -join ";"
$functionstring = ($functionstring -replace '<<parameterJsons>>',$parameterJsons)
$functionstring = ($functionstring -replace ' -ApiFunctionParameters @{ = "\$"}','')


# Write-Host ($parameterJsons)
$functionstring
}