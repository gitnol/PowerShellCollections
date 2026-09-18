function Parse-FileZillaLog {
    param (
        [string]$LogPath
    )
    if (-not (Test-Path $LogPath)) {
        Write-Error "Datei nicht gefunden: $LogPath"
        return
    }

    $pattern = '^(?<Timestamp>\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\.\d+Z)\s+(?<Direction>>{2}|<{2}|==|!!)\s+(?:\[(?<Session>[^\]]+)\]\s+)?(?<Message>.+)$'

    Get-Content $LogPath | ForEach-Object {
        if ($_ -match $pattern) {
            [PSCustomObject]@{
                Timestamp = [datetime]$matches['Timestamp']
                Direction = switch ($matches['Direction']) {
                    '>>' { 'Client → Server' }
                    '<<' { 'Server → Client' }
                    '==' { 'Info' }
                    '!!' { 'Error' }
                }
                Session   = $matches['Session']
                Message   = $matches['Message']
            }
        }
    }
}

# $erg = Parse-FileZillaLog "D:\FILEZILLA_LOGS_bis_20250508\FILEZILLA.log"
# $ergteil= $erg | Where {$_.TimeStamp -gt ((Get-Date).AddDays(-30)) -and $_.Direction -ne "Info"}
# $ergteil.Message | % {$_.split(" ")[0]}  | Sort-Object -Unique