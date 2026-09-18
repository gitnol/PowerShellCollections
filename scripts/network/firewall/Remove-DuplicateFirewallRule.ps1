<#
.SYNOPSIS
    Entfernt doppelte Windows-Firewall-Regeln.

.DESCRIPTION
    Vergleicht eingehende und ausgehende Regeln mit gesetztem Owner nach
    Anzeigename und Owner und loescht die Dubletten. Zuvor wird die Anzahl
    vorher, nachher und die Zahl der zu entfernenden Regeln ausgegeben.

    Solche Dubletten entstehen, wenn Anwendungen bei jedem Start oder Update
    ihre Regel erneut anlegen. Mit der Zeit sammeln sich hunderte gleicher
    Eintraege an, die jede Firewall-Auswertung unuebersichtlich machen.

.NOTES
    Nur Regeln mit gesetztem Owner werden betrachtet - das sind die von
    Anwendungen erzeugten. Manuell angelegte und per Gruppenrichtlinie
    verteilte Regeln bleiben unangetastet.

    Erfordert administrative Rechte. Vorher die ausgegebenen Zahlen
    ansehen.
#>

# This script removes duplicate firewall rules

# Cleanup Inbound Rules:
$FWInboundRules = Get-NetFirewallRule -Direction Inbound | Where-Object { $_.Owner -ne $Null } | Sort-Object Displayname, Owner
$FWInboundRulesUnique = Get-NetFirewallRule -Direction Inbound | Where-Object { $_.Owner -ne $Null } | Sort-Object Displayname, Owner -Unique

Write-Host "# inbound rules         : " $FWInboundRules.Count
Write-Host "# inbound rules (Unique): " $FWInboundRulesUnique.Count

if ($FWInboundRules.Count -ne $FWInboundRulesUnique.Count) {
    Write-Host "# rules to remove       : " (Compare-Object -referenceObject $FWInboundRules  -differenceObject $FWInboundRulesUnique).Count
    Compare-Object -referenceObject $FWInboundRules  -differenceObject $FWInboundRulesUnique   | Select-Object -ExpandProperty inputobject | Remove-NetFirewallRule
}

# Cleanup Outbound Rules:
$FWOutboundRules = Get-NetFirewallRule -Direction Outbound | Where-Object { $_.Owner -ne $Null } | Sort-Object Displayname, Owner
$FWOutboundRulesUnique = Get-NetFirewallRule -Direction Outbound | Where-Object { $_.Owner -ne $Null } | Sort-Object Displayname, Owner -Unique
Write-Host "# outbound rules         : : " $FWOutboundRules.Count
Write-Host "# outbound rules (Unique): " $FWOutboundRulesUnique.Count
if ($FWOutboundRules.Count -ne $FWOutboundRulesUnique.Count) {
    Write-Host "# rules to remove       : " (Compare-Object -referenceObject $FWOutboundRules  -differenceObject $FWOutboundRulesUnique).Count
    Compare-Object -referenceObject $FWOutboundRules  -differenceObject $FWOutboundRulesUnique   | Select-Object -ExpandProperty inputobject | Remove-NetFirewallRule
}

# Cleanup Configurable Service Rules:
$FWConfigurableRules = Get-NetFirewallRule -policystore configurableservicestore | Where-Object { $_.Owner -ne $Null } | Sort-Object Displayname, Owner, Direction
$FWConfigurableRulesUnique = Get-NetFirewallRule -policystore configurableservicestore | Where-Object { $_.Owner -ne $Null } | Sort-Object Displayname, Owner, Direction -Unique
Write-Host "# service configurable rules         : " $FWConfigurableRules.Count
Write-Host "# service configurable rules (Unique): " $FWConfigurableRulesUnique.Count
if ($FWConfigurableRules.Count -ne $FWOutboundRulesUnique.Count) {
    Write-Host "# rules to remove                    : " (Compare-Object -referenceObject $FWConfigurableRules  -differenceObject $FWConfigurableRulesUnique).Count
    Compare-Object -referenceObject $FWConfigurableRules  -differenceObject $FWConfigurableRulesUnique   | Select-Object -ExpandProperty inputobject | Remove-NetFirewallRule
}