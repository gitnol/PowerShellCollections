# See also here for some kyocera OIDs 
# https://github.com/fusioninventory/fusioninventory-agent/issues/638

function Get-SnmpOID {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)][string]$IP,
        [Parameter(Mandatory = $true)][string]$OID
    )
    
    begin {
        Import-Module SNMP
    }
    
    process {
        $Result = Get-SnmpData -IP $IP -OID $StatusOID | Select-Object -ExpandProperty Data
        return $Result
    }
    
    end {
        
    }
}


$StatusOID = ".1.3.6.1.4.1.1347.43.18.2.1.2.1.2"
Get-SnmpOID -IP 10.20.30.40 -OID $StatusOID