function Parse-TeamViewerLogFile {
    param (
        [string]$logFilePath
    )
    # Look here: https://medium.com/mii-cybersec/digital-forensic-artifact-of-teamviewer-application-cfd6290dc0a7
    # and here: https://benleeyr.wordpress.com/2020/05/19/teamviewer-forensics-tested-on-v15/
    # TODO connection ingoing and outgoing

    # Installationspfad aus Registry holen
    $registryPath = "HKLM:\SOFTWARE\TeamViewer"
    $valueName = "InstallationDirectory"
    $installationDirectory = Get-ItemProperty -Path $registryPath -Name $valueName
    $installationPath = $installationDirectory.$valueName

    # Wenn kein Pfad übergeben wurde, Standardpfad verwenden
    if (-not $logFilePath) {
        $logFilePath = Join-Path -Path $installationPath -ChildPath "TeamViewer15_Logfile.log"
    }

    if (Test-Path -LiteralPath $logFilePath) {
        $pattern = '^(?<date>\d{4}/\d{2}/\d{2})\s+(?<time>\d{2}:\d{2}:\d{2}\.\d+)\s{2}\d+\s+\d+\s+[^\s]+\s+.+client hello received from (?<number>\d+),'

        Get-Content $logFilePath | ForEach-Object {
            if ($_ -match $pattern) {
                $dateTimeString = "$($matches['date']) $($matches['time'])"
                $dateTime = [DateTime]::ParseExact($dateTimeString, "yyyy/MM/dd HH:mm:ss.fff", $null)
                [PSCustomObject]@{
                    Date     = $matches['date']
                    Time     = $matches['time']
                    DateTime = $dateTime
                    Number   = $matches['number']
                }
            }
        }
    }
}

Parse-TeamViewerLogFile | Out-GridView