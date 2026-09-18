# mit Richtung. Demo
# Find-ShortestPath -GraphJson $erg -StartNode V_CRM_BUYER -EndNode V_CRM_ENDCUSTOMER
# Find-ShortestPath -GraphJson $erg -StartNode V_CRM_ENDCUSTOMER -EndNode V_CRM_BUYER
# Find-ShortestPath -GraphJson $erg -StartNode V_CRM_ENDCUSTOMER -EndNode V_CRM_BUYER -ShowDirection

# # Ohne Richtungsanzeige
# $path = Find-ShortestPath -GraphJson $graph -StartNode "start" -EndNode "end"

# # Mit Richtungsanzeige
# $path = Find-ShortestPath -GraphJson $graph -StartNode "start" -EndNode "end" -ShowDirection

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
        
        return $shortestPath
    }
    else {
        Write-Host "Kein Pfad gefunden zwischen $StartNode und $EndNode"
        return $null
    }
}