<#
.SYNOPSIS
    Findet und entfernt doppelte DNS-A-Einträge zonenübergreifend.
.DESCRIPTION
    Dieses Skript stellt drei Funktionen bereit:
    1. Find-DuplicateDnsByIP: Sucht nach mehreren Hostnamen, die dieselbe IP-Adresse verwenden.
    2. Find-DuplicateDnsByName: Sucht nach demselben Hostnamen, der in mehreren Zonen mit unterschiedlichen IPs registriert ist.
    3. Remove-OldestDnsDuplicate: Nimmt die Ausgabe der "Find"-Funktionen entgegen
    und löscht alle Einträge bis auf den Neuesten (basierend auf dem Zeitstempel).

    Die Funktionen "Find-..." fügen eine benutzerdefinierte Eigenschaft 'MyZoneName' zu den Objekten hinzu,
    um sicherzustellen, dass der Zonenname korrekt an die "Remove-"-Funktion übergeben wird.

    WICHTIG: Muss auf einem DNS-Server oder einem System mit installierten RSAT-DNS-Tools
    als Administrator ausgeführt werden.
#>

Function Find-DuplicateDnsByIP {
    [CmdletBinding()]
    param ()

    # KORREKTUR: Ausschlussliste für kritische AD-Hostnamen
    $ExcludeHostList = @(
        '@',               # Der Zoneneintrag selbst
        'DomainDnsZones',  # AD-Replikation
        'ForestDnsZones',  # AD-Replikation
        'gc'               # Global Catalog
    )
    Write-Verbose "Folgende kritische Hostnamen werden bei der Suche ignoriert: $($ExcludeHostList -join ', ')"

    Write-Verbose "Sammle alle primären Forward-Lookup-Zonen..."
    # Filtere AD-spezifische Zonen heraus
    $Zones = Get-DnsServerZone | Where-Object { 
        $_.IsReverseLookupZone -eq $false -and 
        $_.ZoneType -eq 'Primary' -and
        $_.ZoneName -notlike '_msdcs.*' -and 
        $_.ZoneName -notlike 'TrustAnchors'
    }
    
    $AllARecords = @()

    foreach ($Zone in $Zones) {
        Write-Verbose "Durchsuche Zone: $($Zone.ZoneName)"
        
        $ZoneRecords = Get-DnsServerResourceRecord -ZoneName $Zone.ZoneName -RRType 'A' | Where-Object { 
            $null -ne $_.Timestamp -and 
            $null -ne $_.RecordData.IPv4Address 
        }
        
        # "Stempeln" der Datensätze mit dem Zonennamen
        $ZoneRecords | ForEach-Object {
            Add-Member -InputObject $_ -MemberType NoteProperty -Name 'MyZoneName' -Value $Zone.ZoneName -Force
        }

        $AllARecords += $ZoneRecords
        Write-Verbose "- $($ZoneRecords.Count) gültige A-Einträge in $($Zone.ZoneName) gefunden."
    }
    
    Write-Verbose "Insgesamt $($AllARecords.Count) A-Einträge gefunden."

    # KORREKTUR: Filtere die kritischen Hostnamen heraus, BEVOR gruppiert wird
    Write-Verbose "Filtere kritische Hostnamen aus der Liste heraus..."
    $FilteredRecords = $AllARecords | Where-Object { $ExcludeHostList -notcontains $_.HostName }
    Write-Verbose "$($FilteredRecords.Count) Einträge verbleiben nach der Filterung."

    Write-Verbose "Gruppiere verbleibende Einträge nach IP-Adresse..."
    # Verwende die gefilterte Liste für die Gruppierung
    $Groups = $FilteredRecords | Group-Object -Property { $_.RecordData.IPv4Address.ToString() }
    
    # Filtere nur die Gruppen heraus, die mehr als einen Eintrag haben (Duplikate)
    $Duplicates = $Groups | Where-Object { $_.Count -gt 1 }
    
    Write-Output $Duplicates
}

# ---

Function Find-DuplicateDnsByName {
    [CmdletBinding()]
    param ()

    # KORREKTUR: Ausschlussliste für kritische AD-Namen
    $ExcludeList = @(
        '@',               # Der Zoneneintrag selbst
        'DomainDnsZones',  # AD-Replikation
        'ForestDnsZones',  # AD-Replikation
        'gc'               # Global Catalog
    )
    Write-Verbose "Folgende kritische Hostnamen werden bei der Suche ignoriert: $($ExcludeList -join ', ')"

    Write-Verbose "Sammle alle primären Forward-Lookup-Zonen..."
    # Filtere AD-spezifische Zonen heraus
    $Zones = Get-DnsServerZone | Where-Object { 
        $_.IsReverseLookupZone -eq $false -and 
        $_.ZoneType -eq 'Primary' -and
        $_.ZoneName -notlike '_msdcs.*' -and 
        $_.ZoneName -notlike 'TrustAnchors'
    }
    
    $AllARecords = @()

    foreach ($Zone in $Zones) {
        Write-Verbose "Durchsuche Zone: $($Zone.ZoneName)"
        
        $ZoneRecords = Get-DnsServerResourceRecord -ZoneName $Zone.ZoneName -RRType 'A' | Where-Object { 
            $null -ne $_.Timestamp -and 
            $null -ne $_.RecordData.IPv4Address 
        }
        
        # "Stempeln" der Datensätze mit dem Zonennamen
        $ZoneRecords | ForEach-Object {
            Add-Member -InputObject $_ -MemberType NoteProperty -Name 'MyZoneName' -Value $Zone.ZoneName -Force
        }
        
        $AllARecords += $ZoneRecords
        Write-Verbose "- $($ZoneRecords.Count) gültige A-Einträge in $($Zone.ZoneName) gefunden."
    }
    
    Write-Verbose "Insgesamt $($AllARecords.Count) A-Einträge gefunden."

    # KORREKTUR: Filtere die kritischen Einträge heraus, BEVOR gruppiert wird
    Write-Verbose "Filtere kritische Hostnamen aus der Liste heraus..."
    $FilteredRecords = $AllARecords | Where-Object { $ExcludeList -notcontains $_.HostName }
    Write-Verbose "$($FilteredRecords.Count) Einträge verbleiben nach der Filterung."

    Write-Verbose "Gruppiere verbleibende Einträge nach Hostnamen..."
    # Verwende die gefilterte Liste für die Gruppierung
    $Groups = $FilteredRecords | Group-Object -Property HostName
    
    # Filtere nur die Gruppen heraus, die mehr als einen Eintrag haben (Duplikate)
    $Duplicates = $Groups | Where-Object { $_.Count -gt 1 }
    
    Write-Output $Duplicates
}

# ---

Function Remove-OldestDnsDuplicate {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param (
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [System.Management.Automation.PSObject]$DuplicateGroup
    )
    
    Process {
        # Sicherheits-Ausschlussliste für kritische AD-Einträge
        $ExcludeList = @(
            '@',               # Der Zoneneintrag selbst
            'DomainDnsZones',  # AD-Replikation
            'ForestDnsZones',  # AD-Replikation
            'gc'               # Global Catalog
        )

        $groupName = $DuplicateGroup.Name
        
        # Sortiere die Einträge innerhalb der Gruppe nach ihrem Zeitstempel, der Neueste zuerst.
        $SortedRecords = $DuplicateGroup.Group | Sort-Object Timestamp -Descending
        
        # Behalte den neuesten Eintrag (Index 0) und wähle alle anderen zum Löschen aus.
        $RecordsToDelete = $SortedRecords | Select-Object -Skip 1
        
        Write-Verbose "Verarbeite Gruppe: $groupName. $($SortedRecords.Count) Einträge gefunden. $($RecordsToDelete.Count) werden zum Löschen geprüft."
        
        foreach ($Record in $RecordsToDelete) {
            
            # KORREKTUR: Verwende die neue, zuverlässige Eigenschaft $Record.MyZoneName
            $TargetInfo = "Host: $($Record.HostName) | IP: $($Record.RecordData.IPv4Address.ToString()) | Zeitstempel: $($Record.Timestamp) | Zone: $($Record.MyZoneName)"
            
            # Sicherheitsprüfung gegen die Ausschlussliste
            if ($ExcludeList -contains $Record.HostName) {
                Write-Warning "ÜBERSPRUNGEN (Kritischer Eintrag): $TargetInfo"
                continue # Springe zum nächsten Eintrag in der Schleife
            }

            # $PSCmdlet.ShouldProcess prüft auf -WhatIf und -Confirm
            if ($PSCmdlet.ShouldProcess($TargetInfo, "Lösche ältesten DNS-Eintrag")) {
                try {
                    # KORREKTUR: Übergebe $Record.MyZoneName an den -ZoneName Parameter
                    Remove-DnsServerResourceRecord -ZoneName $Record.MyZoneName -InputObject $Record -Force -ErrorAction Stop
                    Write-Host "ERFOLGREICH gelöscht: $TargetInfo" -ForegroundColor Green
                }
                catch {
                    Write-Error "FEHLER beim Löschen von '$($Record.HostName)': $_"
                }
            }
        }
    }
}


$DuplicatesByIP = Find-DuplicateDnsByIP -Verbose
$DuplicatesByIP | Format-Table Name, Count -AutoSize

$DuplicatesByIP | Remove-OldestDnsDuplicate -WhatIf -Verbose

# Vorsicht, weil man gleichzeitig mit dem Host im LAN und WLAN sein kann.
#$DuplicatesByName = Find-DuplicateDnsByName -Verbose
#$DuplicatesByName | Format-Table Name, Count -AutoSize