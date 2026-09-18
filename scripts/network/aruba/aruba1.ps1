
# iwr https://www.wireshark.org/json/manuf.json -OutFile C:\install\manuf.json
$global:ouilist = (Get-Content -LiteralPath "C:\install\manuf.json" | ConvertFrom-Json -AsHashtable -Depth 10).data

function lookup-mac_address {
    # https://www.wireshark.org/json/manuf.json
    [CmdletBinding()]
    param(
        [Parameter(Position = 0, mandatory = $true)]
        [string[]] 
        $mac_addresses
    )
    PROCESS {
        if (Test-Path variable:global:ouilist) {
            #Write-Host "oui liste ist definiert"
            # es gibt OUI mit 6,7,9 Zeichen länge. Suchen in umgekehrter Reihenfolge!
            $changed_mac_addresses = @()
            foreach ($mac_address in $mac_addresses) {
                $mac_address = ((($mac_address -replace ":", "") -replace "-", "") -replace "\.", "")
                $search9 = $mac_Address.substring(0, 9).ToLower()
                $search7 = $mac_Address.substring(0, 7).ToLower()
                $search6 = $mac_Address.substring(0, 6).ToLower()
                if ($global:ouilist[$search9]) {
                    #$changed_mac_addresses+=@($mac_address,$global:ouilist[$mac_address.substring(0,9)])
                    $changed_mac_addresses += @([pscustomobject]@{mac_address = $mac_address; ouilookup = $global:ouilist[$search9] })
                }
                elseif ($global:ouilist[$search7]) {
                    $changed_mac_addresses += @([pscustomobject]@{mac_address = $mac_address; ouilookup = $global:ouilist[$search7] })
                }
                elseif ($global:ouilist[$search6]) {
                    $changed_mac_addresses += @([pscustomobject]@{mac_address = $mac_address; ouilookup = $global:ouilist[$search6] })
                }
                else {
                    $changed_mac_addresses += @([pscustomobject]@{mac_address = $mac_address; ouilookup = "_N_V_" })
                }
            }
        }
        else {
            # Write-Host "oui liste ist nicht definiert. Breche ab"
            $changed_mac_addresses += @([pscustomobject]@{mac_address = $mac_address; ouilookup = "OUI-Liste nicht geladen" })
        }
        return $changed_mac_addresses
    }
}

function format-mac_address {
    # https://www.wireshark.org/tools/assets/js/manuf.json
    # lädt das hier https://www.wireshark.org/assets/js/manuf.json
    # $type="5-" führt zu 00-11-22-33-44-55 --> IEEE802-TYPE (hypen)
    # $type="5:" führt zu 00:11:22:33:44:55 --> IETF-YANG-Type (colon)
    # $type="1-" führt zu 001122-334455
    # $type="." führt zu 0011.2233.4455
    # $type="" führt zu 001122334455
    [CmdletBinding()]
    param(
        [Parameter(Position = 0, mandatory = $true)]
        [string[]] 
        $mac_addresses,
        [Parameter(Position = 1, mandatory = $true)]
        [AllowEmptyString()]
        [string] [ValidateSet("5-", "1-", "5:", "", ".")]
        $type
    )
    PROCESS {
        $changed_mac_addresses = @()
        foreach ($mac_address in $mac_addresses) {
            $mac_address = ((($mac_address -replace ":", "") -replace "-", "") -replace "\.", "")
            if ($mac_address.length -ne 12) {
                throw "Die MAC-Adresse $mac_address hat nicht die korrekte Länge"
            }
            if ($mac_address -notmatch '^[0-9a-fA-F]+$') {
                throw "Die MAC-Adresse $mac_address beinhaltet nicht hexadezimale Zeichen."
            }			
            switch ( $type ) {
                # Quelle https://stackoverflow.com/questions/60435381/hyper-v-powershell-add-colons-to-mac-address
                "5-" { $changed_mac_addresses += $mac_address -replace '..(?!$)', '$&-' }
                "1-" { $changed_mac_addresses += $mac_address -replace '......(?!$)', '$&-' }
                "5:" { $changed_mac_addresses += $mac_address -replace '..(?!$)', '$&:' }
                "." { $changed_mac_addresses += $mac_address -replace '....(?!$)', '$&.' }
                "" { $changed_mac_addresses += $mac_address }
            }			
        }
        return $changed_mac_addresses
    }
}


function copy_file_explorer_like([string]$pfadzurdatei) {
    # Diese Funktion kopiert eine oder mehrere Dateien (z.B. mit Wildcard *) so in die Zwischenablage, dass man diese in/oder von RDP Verbindungen nutzen kann.
    Add-Type -AssemblyName System.Windows.Forms
    $f = New-Object System.Collections.Specialized.StringCollection
    foreach ($item in (Get-ChildItem $pfadzurdatei)) {
        $f.Add($item.Fullname)
    }
    [System.Windows.Forms.Clipboard]::SetFileDropList($f)
}

# $switche = @('10.0.1.40')
$switche = @('1.2.3.4')

$cred = Get-Credential

# Liste alle Seriennummern der Aruba Switche auf und hole die MAC-ADresstabelle von den Switchen.
$erg2 = @()
$erg3 = @() # Hierarchisch pro Switch entsprechende MAC-Adresstabellen
$erg4 = @() # Flache Tabelle
#$asso=@{}

# foreach($i in $switche) 
# {
# 	Write-Host "Verbinde zu $i"
# 	$con=Connect-ArubaSW -Server $i -Credentials $cred -SkipCertificateCheck
# 	$switch = Get-ArubaSWSystemStatus -connection $con -Verbose
# 	$erg2+=($i + ";" + $switch.serial_number + ";" + $switch.name)
# 	#@([pscustomobject]@{ip=$i;seriennummer=$switch.serial_number;switchname=$switch.name})
# 	#$asso[$i]=(Get-ArubaSWMacTable -connection $con)
# 	#$erg3+=@([pscustomobject]@{ip=$i;seriennummer=$switch.serial_number;switchname=$switch.name;mactable=$asso[$i]})
# 	(Get-ArubaSWMacTable -connection $con) | % {
# 		$erg4+=@([pscustomobject]@{ip=[string]$i;seriennummer=[string]$switch.serial_number;switchname=[string]$switch.name;mac_address=(format-mac_address -mac_addresses $_.mac_address -type "5:");vlan_id=[int]$_.vlan_id;port_id=[string]$_.port_id;ouilookup=(lookup-mac_address -mac_addresses $_.mac_address).ouilookup})
# 	}
	
# 	Disconnect-ArubaSW -connection $con -Confirm:$False
# }


foreach ($i in $switche) {
    Write-Host "Verbinde zu $i"
    $con = Connect-ArubaSW -Server $i -Credentials $cred -SkipCertificateCheck
    $switch = Get-ArubaSWSystemStatus -connection $con -Verbose
    $erg2 += ($i + ";" + $switch.serial_number + ";" + $switch.name)
    #@([pscustomobject]@{ip=$i;seriennummer=$switch.serial_number;switchname=$switch.name})
    #$asso[$i]=(Get-ArubaSWMacTable -connection $con)
    #$erg3+=@([pscustomobject]@{ip=$i;seriennummer=$switch.serial_number;switchname=$switch.name;mactable=$asso[$i]})
    (Get-ArubaSWMacTable -connection $con) | ForEach-Object {
        $erg4 += @([pscustomobject]@{ip = [string]$i; seriennummer = [string]$switch.serial_number; switchname = [string]$switch.name; mac_address = (format-mac_address -mac_addresses $_.mac_address -type "5:"); vlan_id = [int]$_.vlan_id; port_id = [string]$_.port_id; ouilookup = (lookup-mac_address -mac_addresses $_.mac_address).ouilookup })
    }
	
    Disconnect-ArubaSW -connection $con -Confirm:$False
}

$datum = Get-Date -Format "yyyyMMdd_HHmm_ss";
$erg4 | Export-CSV -LiteralPath "c:\install\switch_mac_tables_$datum.csv" -Encoding utf8 -Delimiter ";"
copy_file_explorer_like("c:\install\switch_mac_tables_$datum.csv")