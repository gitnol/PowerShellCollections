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
    } catch {
        $errorMessage = $_.Exception.Message
        Write-Output ("Fehler bei {0}: {1}" -f $computer, $errorMessage)
    }
}
