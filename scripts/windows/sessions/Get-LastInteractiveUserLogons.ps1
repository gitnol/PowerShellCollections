function Get-LastInteractiveLogons {
    $cutoffDate = (Get-Date).AddDays(-90)
    $logons = Get-WinEvent -LogName Security -FilterXPath "*[System[(EventID=4624)]]" -MaxEvents 10000 -EA SilentlyContinue |
    Where-Object {
        $_.TimeCreated -ge $cutoffDate
    } | Where-Object {
        $logonType = $_.Properties[8].Value
        $logonType -eq 2 -or $logonType -eq 10
    } | ForEach-Object {
        [PSCustomObject]@{
            Time      = $_.TimeCreated
            User      = $_.Properties[5].Value
            LogonType = $_.Properties[8].Value
            AllProperties = $_.Properties
        }
    }

    $logons | Group-Object User | ForEach-Object {
        $_.Group | Sort-Object Time -Descending | Select-Object -First 1
    } | Sort-Object Time
}
