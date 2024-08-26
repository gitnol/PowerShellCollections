function Parse-TeamViewerLogFile {
    # Look here: https://medium.com/mii-cybersec/digital-forensic-artifact-of-teamviewer-application-cfd6290dc0a7
    # and here: https://benleeyr.wordpress.com/2020/05/19/teamviewer-forensics-tested-on-v15/
# TODO connection ingoing and outgoing

    $registryPath = "HKLM:\SOFTWARE\TeamViewer"
    $valueName = "InstallationDirectory"
    $installationDirectory = Get-ItemProperty -Path $registryPath -Name $valueName
    $installationpath = $installationDirectory.$valueName
    
    # Define the path to the logfile
    $logFilePath = "C:\Program Files\TeamViewer\TeamViewer15_Logfile.log"
    $logFilePath = $installationpath + "TeamViewer15_Logfile.log"
    
    if (Test-Path -LiteralPath $logFilePath) {
        # Define the regular expression pattern
        $pattern = '^(?<date>\d{4}/\d{2}/\d{2})\s+(?<time>\d{2}:\d{2}:\d{2}\.\d+)\s{2}\d+\s+\d+\s+[^\s]+\s+.+client hello received from (?<number>\d+),'
        
        # Read the logfile and process each line
        Get-Content $logFilePath | ForEach-Object {
            if ($_ -match $pattern) {
                $dateTimeString = "$($matches['date']) $($matches['time'])"
                $dateTime = [DateTime]::ParseExact($dateTimeString, "yyyy/MM/dd HH:mm:ss.fff", $null)
                [PSCustomObject]@{
                    Date   = $matches['date']
                    Time   = $matches['time']
                    DateTime = $dateTime
                    Number = $matches['number']
                }
            }
        }
    }
    }
    
    Parse-TeamViewerLogFile | Out-GridView
