# Demo Usage with a JSON graph structure
# $json = Get-Content -Path "path\to\your\graph.json" | ConvertFrom-Json
# $edges = Get-EdgeListWithSpaceAndQN -GraphJson $json
# $shortestPath = Find-ShortestPath -GraphJson $json -StartNode "StartQualifiedName" -EndNode "EndQualifiedName" -ShowDirection
# $shortestPathBySpaceQN = Find-ShortestPathBySpaceAndQualifiedName -GraphJson $json -StartNode "SpaceName/StartQualifiedName" -EndNode "SpaceName/EndQualifiedName" -ShowDirection
# $shortestPathByID = Find-ShortestPathByID -GraphJson $json -StartNodeID "StartNodeID" -EndNodeID "EndNodeID" -ShowDirection
# $childNodesInSameSpace = Get-ChildNodesInSameSpace -GraphJson $json -StartNode "SpaceName/QualifiedName" -OnlyDirectChilds

function Get-EdgeListWithSpaceAndQN {
    param (
        [Parameter(Mandatory)]
        $GraphJson
    )
    
    # Test: anhand der ID ein Array mit dem QN und dem Space speichern, um später es aufzulösen
    $script:nodeMapIdToQnAndSpace = @{} # $nodeMapIdToQnAndSpace[$_][0] ist der QN und $nodeMapIdToQnAndSpace[$_][1] ist der Space
    $script:nodeMapSpaceToQNandID = @{} # Key is Space und Values sind Arrays (QN,ID) die dem Key hinzugefügt werden
    $script:nodeMapSpaceQNtoID = @{} # Space/QN to ID: # Anhand des Space kombiniert mit dem qualifiedName die IDs speichern. Space kombiniert mit dem qualifiedName ist eindeutig.
    $script:edgesWithDifferentSpaces = @() # Sammelt die Übergänge / Abhängigkeiten von einem Space zum anderen.
    
    $script:edges = @()
    
    function Extract-Edges {
        param($node)
        
        # Anhand der ID in ein hashtable ein Array mit dem QN und dem Space speichern, um später es aufzulösen (Eindeutigkeit. Deshalb kein , vor @)
        $script:nodeMapIdToQnAndSpace[$node.id] = @($node.qualifiedName, $node.properties.'#spaceName')
        
        # Anhand des Space alle qualifiedName und IDs als Array speichern
        $script:nodeMapSpaceToQNandID[$node.properties.'#spaceName'] += , @($node.qualifiedName, $node.id)
        
        # Anhand des Space kombiniert mit dem qualifiedName die IDs speichern. Space kombiniert mit dem qualifiedName ist eindeutig.
        $script:nodeMapSpaceQNtoID[$node.properties.'#spaceName' + "/" + $node.qualifiedName] = $node.id
        
        foreach ($dep in $node.dependencies) {
            if ($dep.impact -eq $true) {
                # Kind-Element: Fokus-Node -> Dependency
                $src = $node.properties.'#spaceName' + "/" + $node.qualifiedName
                $dst = $dep.properties.'#spaceName' + "/" + $dep.qualifiedName
                
                $edge = @($src, $dst)
                
                # if ($node.properties.'#spaceName' -ne $dep.properties.'#spaceName') {
                #     $script:edgesWithDifferentSpaces += @{src = ($node.properties.'#spaceName' + "/" + $node.qualifiedName);dst = ($dep.properties.'#spaceName' + "/" + $dep.qualifiedName);}
                # }
                
                if ($node.properties.'#spaceName' -ne $dep.properties.'#spaceName') {
                    $obj = New-SimpleObject -Properties @{
                        src_space = $node.properties.'#spaceName'
                        src_view  = $node.qualifiedName
                        dst_space = $dep.properties.'#spaceName'
                        dst_view  = $dep.qualifiedName
                    }
                    $script:edgesWithDifferentSpaces += $obj
                }
            }
            else {
                $src = $node.properties.'#spaceName' + "/" + $node.qualifiedName
                $dst = $dep.properties.'#spaceName' + "/" + $dep.qualifiedName
                
                # Eltern-Element: Dependency -> Fokus-Node
                $edge = @($dst, $src)
                
                if ($node.properties.'#spaceName' -ne $dep.properties.'#spaceName') {
                    # Dreht die Eltern Kind beziehung hier um, weil es vertauscht werden muss. (Pfeil umdrehen // der Richtung der gerichteten Kante umdrehen)
                    $obj = New-SimpleObject -Properties @{
                        src_space = $dep.properties.'#spaceName'
                        src_view  = $dep.qualifiedName
                        dst_space = $node.properties.'#spaceName'
                        dst_view  = $node.qualifiedName
                    }
                    $script:edgesWithDifferentSpaces += $obj
                    # $script:edgesWithDifferentSpaces += @{src = ($dep.properties.'#spaceName' + "/" + $dep.qualifiedName);dst = ($node.properties.'#spaceName' + "/" + $node.qualifiedName);}
                }
            }
            
            $script:edges += , $edge
            
            Extract-Edges -node $dep
        }
    }
    
    Extract-Edges -node $GraphJson
    return $script:edges
}

function Find-ShortestPath {
    param (
        [Parameter(Mandatory)]
        $GraphJson,
        [Parameter(Mandatory)]
        [string]$StartNode,
        [Parameter(Mandatory)]
        [string]$EndNode,
        [switch]$ShowDirection
    )

    # function New-SimpleObject {
    #     param (
    #         [hashtable]$Properties
    #     )
    #     $obj = New-Object PSObject
    #     foreach ($key in $Properties.Keys) {
    #         $obj | Add-Member -MemberType NoteProperty -Name $key -Value $Properties[$key]
    #     }
    #     return $obj
    # }

    # Node Map aufbauen: qualifiedName → NodeObjekt
    $nodeMap = @{}

    function Build-NodeMap {
        param($node)
        
        if (-not $nodeMap.ContainsKey($node.qualifiedName)) {
            $nodeMap[$node.qualifiedName] = $node
            
            foreach ($dep in $node.dependencies) {
                Build-NodeMap -node $dep
            }
        }
        else {
            Write-Warning -Message "Der QualifiedName $($node.qualifiedName) wurde in der nodeMap schon gefunden."
            Write-Warning -Message "QualifiedNames müssen eindeutig sein, sonst kommt es zu Problemen wegen der Space Zuordnung."
            Write-Warning -Message "Benutze dann stattdessen die gleiche Funktion mit node IDs und übersetze später es korrekt."
        }
    }

    Build-NodeMap -node $GraphJson

    # Ungerichteten Graph aufbauen: jeder Knoten kennt alle seine Nachbarn
    $adjacencyList = @{}

    function Build-UndirectedGraph {
        # Alle Knoten initialisieren
        $nodeKeys = @($nodeMap.Keys)
        foreach ($qualifiedName in $nodeKeys) {
            $adjacencyList[$qualifiedName] = @()
        }

        # Bidirektionale Verbindungen hinzufügen
        foreach ($qualifiedName in $nodeKeys) {
            $node = $nodeMap[$qualifiedName]
            
            foreach ($dep in $node.dependencies) {
                # Bidirektionale Verbindung hinzufügen
                $adjacencyList[$qualifiedName] += $dep.qualifiedName
                $adjacencyList[$dep.qualifiedName] += $qualifiedName
            }
        }

        # Duplikate entfernen - Keys erneut in Array kopieren
        $adjacencyKeys = @($adjacencyList.Keys)
        foreach ($qualifiedName in $adjacencyKeys) {
            $adjacencyList[$qualifiedName] = $adjacencyList[$qualifiedName] | Select-Object -Unique
        }
    }

    Build-UndirectedGraph

    # Richtungs-Map für ursprüngliche Dependencies erstellen
    $directionMap = @{}
    foreach ($qualifiedName in $nodeMap.Keys) {
        $node = $nodeMap[$qualifiedName]
        
        foreach ($dep in $node.dependencies) {
            # Von Parent zu Child (runter): ↓
            $directionMap["$qualifiedName->$($dep.qualifiedName)"] = "↓"
            # Von Child zu Parent (rauf): ↑
            $directionMap["$($dep.qualifiedName)->$qualifiedName"] = "↑"
        }
    }

    # Debug: Ausgabe der Nachbarschaften
    Write-Host "Ungerichteter Graph - Nachbarschaften:"
    foreach ($qualifiedName in $adjacencyList.Keys) {
        $neighbors = $adjacencyList[$qualifiedName] -join ', '
        Write-Host "  $qualifiedName -> [$neighbors]"
    }

    # Funktion zur Auflösung eines Namens oder einer ID auf das qualifiedName-Feld
    function Resolve-NodeQualifiedName {
        param($val)
        
        $found = $nodeMap.Values | Where-Object { $_.qualifiedName -eq $val -or $_.name -eq $val -or $_.id -eq $val }
        if ($found) {
            return $found.qualifiedName
        }
        return $null
    }

    $startQualifiedName = Resolve-NodeQualifiedName -val $StartNode
    $endQualifiedName = Resolve-NodeQualifiedName -val $EndNode

    Write-Host "Start: $StartNode -> QualifiedName: $startQualifiedName"
    Write-Host "Ende: $EndNode -> QualifiedName: $endQualifiedName"

    if (-not $startQualifiedName -or -not $endQualifiedName) {
        Write-Warning "Start ($StartNode -> $startQualifiedName) oder Ziel ($EndNode -> $endQualifiedName) wurde nicht gefunden."
        return
    }

    # BFS für kürzesten Pfad
    function BFS-ShortestPath {
        param($start, $target)

        if ($start -eq $target) {
            return @($start)
        }

        # Queue für BFS: jedes Element ist @(currentNode, path)
        $queue = @(, @($start, @($start)))
        $visited = @{}
        $visited[$start] = $true

        while ($queue.Count -gt 0) {
            # Erstes Element aus Queue nehmen
            $current = $queue[0]
            $queue = $queue[1..($queue.Count - 1)]

            $currentNode = $current[0]
            $currentPath = $current[1]

            Write-Host "BFS: Besuche $currentNode, Pfadlänge: $($currentPath.Count)"

            # Alle Nachbarn untersuchen
            foreach ($neighbor in $adjacencyList[$currentNode]) {
                if (-not $visited.ContainsKey($neighbor)) {
                    $newPath = $currentPath + $neighbor

                    if ($neighbor -eq $target) {
                        Write-Host "Kürzester Pfad gefunden: $($newPath -join ' -> ')"
                        return $newPath
                    }

                    $visited[$neighbor] = $true
                    $queue += , @($neighbor, $newPath)
                }
            }
        }

        # Kein Pfad gefunden
        return $null
    }

    $shortestPath = BFS-ShortestPath -start $startQualifiedName -target $endQualifiedName

    if ($shortestPath) {
        Write-Host "Kürzester Pfad gefunden mit $($shortestPath.Count) Knoten"

        if ($ShowDirection -and $shortestPath.Count -gt 1) {
            # Pfad mit Richtungspfeilen erstellen
            $pathWithDirection = @()
            
            for ($i = 0; $i -lt $shortestPath.Count; $i++) {
                $pathWithDirection += $shortestPath[$i]

                if ($i -lt $shortestPath.Count - 1) {
                    $from = $shortestPath[$i]
                    $to = $shortestPath[$i + 1]
                    $directionKey = "$from->$to"
                    $arrow = $directionMap[$directionKey]
                    
                    if ($arrow) {
                        $pathWithDirection += $arrow
                    }
                    else {
                        $pathWithDirection += "?"  # Fallback, sollte nicht passieren
                    }
                }
            }

            Write-Host "Pfad mit Richtung: $($pathWithDirection -join ' ')"
            Write-Host "Legende: ↓ = runter zu Dependencies, ↑ = rauf zu Parent"
        }
        
        $myerg = @() # added
        
        foreach ($qn in $shortestPath) {
            $obj = New-SimpleObject -Properties @{ # added
                id            = $nodeMap[$qn].id
                qualifiedName = $nodeMap[$qn].qualifiedName
                Name          = $nodeMap[$qn].Name
                spaceName     = $nodeMap[$qn].properties.'#spaceName'
            }
            $myerg += $obj # added
            # Write-Host($nodeMap[$qn].id,$nodeMap[$qn].qualifiedName,$nodeMap[$qn].Name,$nodeMap[$qn].properties.'#spaceName') -ForegroundColor Green
        }
        
        $myerg # added

        return $shortestPath
    }
    else {
        Write-Host "Kein Pfad gefunden zwischen $StartNode und $EndNode"
        return $null
    }
}

function New-SimpleObject {
    param (
        [hashtable]$Properties
    )
    $obj = New-Object PSObject
    foreach ($key in $Properties.Keys) {
        $obj | Add-Member -MemberType NoteProperty -Name $key -Value $Properties[$key]
    }
    return $obj
}

function Find-ShortestPathBySpaceAndQualifiedName {
    param (
        [Parameter(Mandatory)]
        $GraphJson,
        [Parameter(Mandatory)]
        [string]$StartNode,  # Format: "SpaceName/QualifiedName"
        [Parameter(Mandatory)]
        [string]$EndNode,    # Format: "SpaceName/QualifiedName"
        [switch]$ShowDirection
    )

    # Node Map aufbauen: "SpaceName/QualifiedName" → NodeObjekt
    $nodeMap = @{}

    function Build-NodeMap {
        param($node)
        
        $spaceQnKey = $node.properties.'#spaceName' + "/" + $node.qualifiedName
        
        if (-not $nodeMap.ContainsKey($spaceQnKey)) {
            $nodeMap[$spaceQnKey] = $node
            
            foreach ($dep in $node.dependencies) {
                Build-NodeMap -node $dep
            }
        }
        else {
            Write-Warning -Message "Der SpaceName/QualifiedName $spaceQnKey wurde in der nodeMap schon gefunden."
        }
    }

    Build-NodeMap -node $GraphJson

    # Ungerichteten Graph aufbauen: jeder Knoten kennt alle seine Nachbarn
    $adjacencyList = @{}

    function Build-UndirectedGraph {
        # Alle Knoten initialisieren
        $nodeKeys = @($nodeMap.Keys)
        foreach ($spaceQnKey in $nodeKeys) {
            $adjacencyList[$spaceQnKey] = @()
        }

        # Bidirektionale Verbindungen hinzufügen
        foreach ($spaceQnKey in $nodeKeys) {
            $node = $nodeMap[$spaceQnKey]
            
            foreach ($dep in $node.dependencies) {
                $depKey = $dep.properties.'#spaceName' + "/" + $dep.qualifiedName
                
                # Bidirektionale Verbindung hinzufügen
                $adjacencyList[$spaceQnKey] += $depKey
                $adjacencyList[$depKey] += $spaceQnKey
            }
        }

        # Duplikate entfernen
        $adjacencyKeys = @($adjacencyList.Keys)
        foreach ($spaceQnKey in $adjacencyKeys) {
            $adjacencyList[$spaceQnKey] = $adjacencyList[$spaceQnKey] | Select-Object -Unique
        }
    }

    Build-UndirectedGraph

    # Richtungs-Map für ursprüngliche Dependencies erstellen
    $directionMap = @{}
    foreach ($spaceQnKey in $nodeMap.Keys) {
        $node = $nodeMap[$spaceQnKey]
        
        foreach ($dep in $node.dependencies) {
            $depKey = $dep.properties.'#spaceName' + "/" + $dep.qualifiedName
            
            # Von Parent zu Child (runter): ↓
            $directionMap["$spaceQnKey->$depKey"] = "↓"
            # Von Child zu Parent (rauf): ↑
            $directionMap["$depKey->$spaceQnKey"] = "↑"
        }
    }

    # Debug: Ausgabe der Nachbarschaften
    Write-Host "Ungerichteter Graph - Nachbarschaften:"
    foreach ($spaceQnKey in $adjacencyList.Keys) {
        $neighbors = $adjacencyList[$spaceQnKey] -join ', '
        Write-Host "  $spaceQnKey -> [$neighbors]"
    }

    Write-Host "Start: $StartNode"
    Write-Host "Ende: $EndNode"

    if (-not $nodeMap.ContainsKey($StartNode) -or -not $nodeMap.ContainsKey($EndNode)) {
        Write-Warning "Start ($StartNode) oder Ziel ($EndNode) wurde nicht in der NodeMap gefunden."
        return
    }

    # BFS für kürzesten Pfad
    function BFS-ShortestPath {
        param($start, $target)

        if ($start -eq $target) {
            return @($start)
        }

        # Queue für BFS: jedes Element ist @(currentNode, path)
        $queue = @(, @($start, @($start)))
        $visited = @{}
        $visited[$start] = $true

        while ($queue.Count -gt 0) {
            # Erstes Element aus Queue nehmen
            $current = $queue[0]
            $queue = $queue[1..($queue.Count - 1)]

            $currentNode = $current[0]
            $currentPath = $current[1]

            Write-Host "BFS: Besuche $currentNode, Pfadlänge: $($currentPath.Count)"

            # Alle Nachbarn untersuchen
            foreach ($neighbor in $adjacencyList[$currentNode]) {
                if (-not $visited.ContainsKey($neighbor)) {
                    $newPath = $currentPath + $neighbor

                    if ($neighbor -eq $target) {
                        Write-Host "Kürzester Pfad gefunden: $($newPath -join ' -> ')"
                        return $newPath
                    }

                    $visited[$neighbor] = $true
                    $queue += , @($neighbor, $newPath)
                }
            }
        }

        # Kein Pfad gefunden
        return $null
    }

    $shortestPath = BFS-ShortestPath -start $StartNode -target $EndNode

    if ($shortestPath) {
        Write-Host "Kürzester Pfad gefunden mit $($shortestPath.Count) Knoten"

        if ($ShowDirection -and $shortestPath.Count -gt 1) {
            # Pfad mit Richtungspfeilen erstellen
            $pathWithDirection = @()
            
            for ($i = 0; $i -lt $shortestPath.Count; $i++) {
                $pathWithDirection += $shortestPath[$i]

                if ($i -lt $shortestPath.Count - 1) {
                    $from = $shortestPath[$i]
                    $to = $shortestPath[$i + 1]
                    $directionKey = "$from->$to"
                    $arrow = $directionMap[$directionKey]
                    
                    if ($arrow) {
                        $pathWithDirection += $arrow
                    }
                    else {
                        $pathWithDirection += "?"  # Fallback
                    }
                }
            }

            Write-Host "Pfad mit Richtung: $($pathWithDirection -join ' ')"
            Write-Host "Legende: ↓ = runter zu Dependencies, ↑ = rauf zu Parent"
        }
        
        $myerg = @()
        
        foreach ($spaceQnKey in $shortestPath) {
            $node = $nodeMap[$spaceQnKey]
            $obj = New-SimpleObject -Properties @{
                id            = $node.id
                qualifiedName = $node.qualifiedName
                Name          = $node.Name
                spaceName     = $node.properties.'#spaceName'
            }
            $myerg += $obj
        }
        
        $myerg

        return $shortestPath
    }
    else {
        Write-Host "Kein Pfad gefunden zwischen $StartNode und $EndNode"
        return $null
    }
}

function Get-ChildNodesInSameSpace {
    param (
        [Parameter(Mandatory)]
        $GraphJson,
        [Parameter(Mandatory)]
        [string]$StartNode,  # Format: "SpaceName/QualifiedName"
        [switch]$OnlyDirectChilds
    )

    # Node Map aufbauen: "SpaceName/QualifiedName" → NodeObjekt
    $nodeMap = @{}

    function Build-NodeMap {
        param($node)
        
        $spaceQnKey = $node.properties.'#spaceName' + "/" + $node.qualifiedName
        
        if (-not $nodeMap.ContainsKey($spaceQnKey)) {
            $nodeMap[$spaceQnKey] = $node
            
            foreach ($dep in $node.dependencies) {
                Build-NodeMap -node $dep
            }
        }
    }

    Build-NodeMap -node $GraphJson

    # Prüfen ob StartNode existiert
    if (-not $nodeMap.ContainsKey($StartNode)) {
        Write-Warning "StartNode ($StartNode) wurde nicht in der NodeMap gefunden."
        return
    }

    $startNodeObj = $nodeMap[$StartNode]
    $startSpace = $startNodeObj.properties.'#spaceName'

    Write-Host "Suche Kinder von: $StartNode im Space: $startSpace"

    # Funktion zum rekursiven Durchlaufen der Kinder
    function Get-ChildPaths {
        param(
            $currentNode,
            $currentPath,
            $targetSpace,
            $onlyDirect = $false
        )

        $currentSpaceQnKey = $currentNode.properties.'#spaceName' + "/" + $currentNode.qualifiedName
        $newPath = $currentPath + $currentSpaceQnKey

        # Hole alle Dependencies (Kinder) des aktuellen Knotens im gleichen Space
        $childrenInSameSpace = $currentNode.dependencies | Where-Object { 
            $_.properties.'#spaceName' -eq $targetSpace 
        }

        if ($childrenInSameSpace.Count -eq 0) {
            # Keine Kinder im gleichen Space -> Ende des Pfads erreicht
            if ($newPath.Count -gt 1) {
                # Nur ausgeben wenn es mehr als nur den StartNode gibt
                return @(, $newPath)  # Array von Arrays zurückgeben
            }
            return @()
        }

        $allPaths = @()

        foreach ($child in $childrenInSameSpace) {
            $childSpaceQnKey = $child.properties.'#spaceName' + "/" + $child.qualifiedName

            if ($onlyDirect) {
                # Nur direkte Kinder - Pfad hier beenden
                $directPath = $newPath + $childSpaceQnKey
                $allPaths += , $directPath
            }
            else {
                # Rekursiv weitermachen
                $childPaths = Get-ChildPaths -currentNode $child -currentPath $newPath -targetSpace $targetSpace -onlyDirect $false
                $allPaths += $childPaths
            }
        }

        return $allPaths
    }

    # Starte die Suche
    $allFoundPaths = Get-ChildPaths -currentNode $startNodeObj -currentPath @() -targetSpace $startSpace -onlyDirect $OnlyDirectChilds

    # Ausgabe der gefundenen Pfade
    $resultPaths = @()
    $resultObjects = @()

    if ($allFoundPaths.Count -gt 0) {
        Write-Host "`nGefundene Pfade:"
        foreach ($path in $allFoundPaths) {
            $pathString = $path -join " -> "
            Write-Host $pathString
            $resultPaths += $pathString

            # Strukturierte Objekte für den Pfad erstellen
            $pathObjects = @()
            foreach ($spaceQnKey in $path) {
                if ($nodeMap.ContainsKey($spaceQnKey)) {
                    $node = $nodeMap[$spaceQnKey]
                    $obj = New-SimpleObject -Properties @{
                        id            = $node.id
                        qualifiedName = $node.qualifiedName
                        Name          = $node.Name
                        spaceName     = $node.properties.'#spaceName'
                        spaceQnKey    = $spaceQnKey
                    }
                    $pathObjects += $obj
                }
            }
            
            $pathResult = New-SimpleObject -Properties @{
                pathString  = $pathString
                pathObjects = $pathObjects
                pathLength  = $path.Count
            }
            $resultObjects += $pathResult
        }
        
        Write-Host "`nAnzahl gefundener Pfade: $($allFoundPaths.Count)"
    }
    else {
        Write-Host "Keine Kinder im gleichen Space gefunden."
    }

    # Strukturierte Rückgabe
    $result = New-SimpleObject -Properties @{
        startNode        = $StartNode
        startSpace       = $startSpace
        onlyDirectChilds = $OnlyDirectChilds.IsPresent
        pathCount        = $allFoundPaths.Count
        pathStrings      = $resultPaths
        pathDetails      = $resultObjects
    }

    return $result
}

function Find-ShortestPathByID {
    param (
        [Parameter(Mandatory)]
        $GraphJson,
        [Parameter(Mandatory)]
        [string]$StartNodeID,
        [Parameter(Mandatory)]
        [string]$EndNodeID,
        [switch]$ShowDirection
    )

    # Node Map aufbauen: ID → NodeObjekt
    $nodeMapById = @{}

    function Build-NodeMapById {
        param($node)
        
        if (-not $nodeMapById.ContainsKey($node.id)) {
            $nodeMapById[$node.id] = $node
            
            foreach ($dep in $node.dependencies) {
                Build-NodeMapById -node $dep
            }
        }
        else {
            Write-Warning -Message "Die ID $($node.id) wurde in der nodeMap schon gefunden."
        }
    }

    Build-NodeMapById -node $GraphJson

    # Ungerichteten Graph aufbauen: jeder Knoten kennt alle seine Nachbarn
    $adjacencyListById = @{}

    function Build-UndirectedGraphById {
        # Alle Knoten initialisieren
        $nodeIds = @($nodeMapById.Keys)
        foreach ($nodeId in $nodeIds) {
            $adjacencyListById[$nodeId] = @()
        }

        # Bidirektionale Verbindungen hinzufügen
        foreach ($nodeId in $nodeIds) {
            $node = $nodeMapById[$nodeId]
            
            foreach ($dep in $node.dependencies) {
                # Bidirektionale Verbindung hinzufügen
                $adjacencyListById[$nodeId] += $dep.id
                $adjacencyListById[$dep.id] += $nodeId
            }
        }

        # Duplikate entfernen
        $adjacencyKeys = @($adjacencyListById.Keys)
        foreach ($nodeId in $adjacencyKeys) {
            $adjacencyListById[$nodeId] = $adjacencyListById[$nodeId] | Select-Object -Unique
        }
    }

    Build-UndirectedGraphById

    # Richtungs-Map für ursprüngliche Dependencies erstellen
    $directionMapById = @{}
    foreach ($nodeId in $nodeMapById.Keys) {
        $node = $nodeMapById[$nodeId]
        
        foreach ($dep in $node.dependencies) {
            # Von Parent zu Child (runter): ↓
            $directionMapById["$nodeId->$($dep.id)"] = "↓"
            # Von Child zu Parent (rauf): ↑
            $directionMapById["$($dep.id)->$nodeId"] = "↑"
        }
    }

    # Debug: Ausgabe der Nachbarschaften
    Write-Host "Ungerichteter Graph - Nachbarschaften (by ID):"
    foreach ($nodeId in $adjacencyListById.Keys) {
        $node = $nodeMapById[$nodeId]
        $spaceQnKey = $node.properties.'#spaceName' + "/" + $node.qualifiedName
        $neighbors = $adjacencyListById[$nodeId] -join ', '
        Write-Host "  $nodeId ($spaceQnKey) -> [$neighbors]"
    }

    Write-Host "Start ID: $StartNodeID"
    Write-Host "Ende ID: $EndNodeID"

    if (-not $nodeMapById.ContainsKey($StartNodeID) -or -not $nodeMapById.ContainsKey($EndNodeID)) {
        Write-Warning "Start ID ($StartNodeID) oder Ziel ID ($EndNodeID) wurde nicht in der NodeMap gefunden."
        return
    }

    # BFS für kürzesten Pfad
    function BFS-ShortestPathById {
        param($startId, $targetId)

        if ($startId -eq $targetId) {
            return @($startId)
        }

        # Queue für BFS: jedes Element ist @(currentNodeId, path)
        $queue = @(, @($startId, @($startId)))
        $visited = @{}
        $visited[$startId] = $true

        while ($queue.Count -gt 0) {
            # Erstes Element aus Queue nehmen
            $current = $queue[0]
            $queue = $queue[1..($queue.Count - 1)]

            $currentNodeId = $current[0]
            $currentPath = $current[1]

            $currentNode = $nodeMapById[$currentNodeId]
            $currentSpaceQn = $currentNode.properties.'#spaceName' + "/" + $currentNode.qualifiedName
            Write-Host "BFS: Besuche $currentNodeId ($currentSpaceQn), Pfadlänge: $($currentPath.Count)"

            # Alle Nachbarn untersuchen
            foreach ($neighborId in $adjacencyListById[$currentNodeId]) {
                if (-not $visited.ContainsKey($neighborId)) {
                    $newPath = $currentPath + $neighborId

                    if ($neighborId -eq $targetId) {
                        Write-Host "Kürzester Pfad gefunden: $($newPath -join ' -> ')"
                        return $newPath
                    }

                    $visited[$neighborId] = $true
                    $queue += , @($neighborId, $newPath)
                }
            }
        }

        # Kein Pfad gefunden
        return $null
    }

    $shortestPathIds = BFS-ShortestPathById -startId $StartNodeID -targetId $EndNodeID

    if ($shortestPathIds) {
        Write-Host "Kürzester Pfad gefunden mit $($shortestPathIds.Count) Knoten"

        if ($ShowDirection -and $shortestPathIds.Count -gt 1) {
            # Pfad mit Richtungspfeilen erstellen
            $pathWithDirection = @()
            
            for ($i = 0; $i -lt $shortestPathIds.Count; $i++) {
                $nodeId = $shortestPathIds[$i]
                $node = $nodeMapById[$nodeId]
                $spaceQnKey = $node.properties.'#spaceName' + "/" + $node.qualifiedName
                $pathWithDirection += "$nodeId ($spaceQnKey)"

                if ($i -lt $shortestPathIds.Count - 1) {
                    $fromId = $shortestPathIds[$i]
                    $toId = $shortestPathIds[$i + 1]
                    $directionKey = "$fromId->$toId"
                    $arrow = $directionMapById[$directionKey]
                    
                    if ($arrow) {
                        $pathWithDirection += $arrow
                    }
                    else {
                        $pathWithDirection += "?"  # Fallback
                    }
                }
            }

            Write-Host "Pfad mit Richtung: $($pathWithDirection -join ' ')"
            Write-Host "Legende: ↓ = runter zu Dependencies, ↑ = rauf zu Parent"
        }
        
        $myerg = @()
        
        foreach ($nodeId in $shortestPathIds) {
            $node = $nodeMapById[$nodeId]
            $obj = New-SimpleObject -Properties @{
                id            = $node.id
                qualifiedName = $node.qualifiedName
                Name          = $node.Name
                spaceName     = $node.properties.'#spaceName'
            }
            $myerg += $obj
        }
        
        $myerg

        return $shortestPathIds
    }
    else {
        Write-Host "Kein Pfad gefunden zwischen ID $StartNodeID und ID $EndNodeID"
        return $null
    }
}