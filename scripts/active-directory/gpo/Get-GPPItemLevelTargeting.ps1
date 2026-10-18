<#
.SYNOPSIS
    Listet die zielgruppenbasierte Zuordnung (Item-Level Targeting) aller
    Gruppenrichtlinien-Einstellungen auf.

.DESCRIPTION
    Durchsucht die XML-Reports aller GPOs nach FilterGroup-Knoten und gibt je
    Treffer GPO, Filtertyp und die adressierte Gruppe samt SID aus.

.NOTES
    Ist die Spalte SID leer, greift die Zuordnung nicht: die Verarbeitung
    haengt an der SID, nicht am Namen. Eine geloeschte und neu angelegte
    Gruppe gleichen Namens macht den Filter damit wirkungslos, ohne dass es
    auffaellt.
#>

# Diese Funktion liefert die zielgruppenbasierte Zuordnung innerhalb von GPPs bei GPOs.
# Wenn die Spalte SID leer ist, so ist die zielgruppenbasierte Zuordnung nicht gültig, da die Verarbeitung an die SID geknüpft ist.

function Get-GPPItemLevelTargeting {
    $GPOs = Get-GPO -All
    $Result = @()

    foreach ($GPO in $GPOs) {
        $GPOReport = Get-GPOReport -Guid $GPO.Id -ReportType Xml
        [xml]$xmlContent = $GPOReport

        # XPath Query
        $targetNodes = $xmlcontent.SelectNodes("//*[local-name()='FilterGroup']")

        foreach ($node in $targetNodes) {
            $Result += [PSCustomObject]@{
                GPOName   = $GPO.DisplayName
                GPOID     = $GPO.Id
                GroupName = $node.name
                SID       = $node.sid
            }
        }
    }

    return $Result
}

# Aufrufen der Funktion und Ergebnisse ausgeben
Get-GPPItemLevelTargeting | Out-GridView
Get-GPPItemLevelTargeting | Where-Object SID -eq ''
