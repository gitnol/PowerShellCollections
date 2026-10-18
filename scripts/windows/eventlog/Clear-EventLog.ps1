<#
.SYNOPSIS
    Leert saemtliche Windows-Ereignisprotokolle des lokalen Rechners.

.DESCRIPTION
    Zaehlt ueber `wevtutil el` alle vorhandenen Protokolle auf und leert
    jedes einzeln mit `wevtutil cl`.

.NOTES
    ACHTUNG: unwiderruflich. Damit verschwinden auch Sicherheitsprotokolle -
    also genau die Spuren, die man bei einer Stoerung oder einem
    Sicherheitsvorfall braucht. Sinnvoll eigentlich nur beim Vorbereiten
    eines Images.

    Erfordert administrative Rechte.
#>

#Requires -RunAsAdministrator
# https://learn.microsoft.com/th-th/powershell/module/microsoft.powershell.core/about/about_requires?view=powershell-5.1
wevtutil el | Foreach-Object {Write-Host "Clearing $_"; wevtutil cl "$_"}