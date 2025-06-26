function Get-WmiBrief {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$ClassName,

        [string]$ComputerName = 'localhost'
    )

    try {
        $instances = Get-CimInstance -ClassName $ClassName -ComputerName $ComputerName -ErrorAction Stop

        $props = $instances |
        Select-Object -First 1 |
        Get-Member -MemberType Properties |
        Where-Object { $_.Name -notin @('CimClass', 'CimInstanceProperties', 'CimSystemProperties') } |
        Select-Object -ExpandProperty Name

        $instances | Select-Object -Property $props | ForEach-Object {
            [PSCustomObject]$_
        }
    }
    catch {
        Write-Error "Fehler beim Abrufen der Klasse '$ClassName' auf '$ComputerName': $_"
    }
}

function Get-WmiBriefOptimized {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, ValueFromPipeline)]
        [string]$ClassName,

        [string]$ComputerName = 'localhost'
    )

    process {
        try {
            # 1. Effizient die Eigenschaftsnamen direkt aus der Klassendefinition holen.
            #    Dies vermeidet das Abrufen einer kompletten Instanz nur für die Metadaten.
            $class = Get-CimClass -ClassName $ClassName -ComputerName $ComputerName -ErrorAction Stop
            $propertyNames = $class.CimClassProperties.Name

            # 2. Alle Instanzen abrufen, aber NUR die benötigten Eigenschaften anfordern.
            #    Der Parameter -Property reduziert die übertragene Datenmenge erheblich.
            Get-CimInstance -ClassName $ClassName -ComputerName $ComputerName -Property $propertyNames -ErrorAction Stop
        }
        catch {
            Write-Error "Fehler beim Verarbeiten der Klasse '$ClassName' auf '$ComputerName': $_"
        }
    }
}

New-Alias -Name wmic -Value Get-WmiBriefOptimized -Force