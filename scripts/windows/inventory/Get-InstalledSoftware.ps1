# This script searches for an installed software on all domain computers
$softwarename = "*7-Zip*"
$computers = Get-ADComputer -Filter * | Select-Object -ExpandProperty Name
foreach ($computer in $computers) {
    try {
        Invoke-Command -ComputerName $computer -ScriptBlock {
            Get-ItemProperty -Path "HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*" |
            Where-Object { $_.DisplayName -like $softwarename } |
            Select-Object @{
                Name = "PSComputerName"; Expression = { $env:COMPUTERNAME }
            }, DisplayName, @{Name = "Version"; Expression = { $_.Version } }
        }
    }
    catch {
        $errorMessage = $_.Exception.Message
        Write-Output ("Fehler bei {0}: {1}" -f $computer, $errorMessage)
    }
}


function Get-InstalledSoftware {
    <#
.SYNOPSIS
Liest installierte Software (Registry-basiert, ohne Win32_Product)
#>
    [CmdletBinding()]
    param(
        [string]$ComputerName = $env:COMPUTERNAME
    )

    $hives = @(
        @{ Path = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*'; Architecture = '64-bit' },
        @{ Path = 'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*'; Architecture = '32-bit' }
    )

    $scriptBlock = {
        param($hives)
        $apps = foreach ($entry in $hives) {
            Get-ItemProperty -Path $entry.Path -ErrorAction SilentlyContinue |
            Where-Object { $_.DisplayName -and $_.UninstallString } |
            ForEach-Object {
                [PSCustomObject]@{
                    Name            = $_.DisplayName
                    Version         = $_.DisplayVersion
                    Publisher       = $_.Publisher
                    InstallDate     = $_.InstallDate
                    UninstallString = $_.UninstallString
                    Architektur     = $entry.Architecture
                }
            }
        }
        $apps | Sort-Object Name
    }

    if ($ComputerName -eq $env:COMPUTERNAME) {
        & $scriptBlock $hives
    }
    else {
        Invoke-Command -ComputerName $ComputerName -ScriptBlock $scriptBlock -ArgumentList $hives
    }
}

