#Requires -RunAsAdministrator
# https://learn.microsoft.com/th-th/powershell/module/microsoft.powershell.core/about/about_requires?view=powershell-5.1
wevtutil el | Foreach-Object {Write-Host "Clearing $_"; wevtutil cl "$_"}