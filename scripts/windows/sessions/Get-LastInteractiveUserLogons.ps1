<#
.SYNOPSIS
    Findet die letzten interaktiven Anmeldungen und RDP-Sitzungen der letzten
    90 Tage.

.DESCRIPTION
    Wertet Event 4624 im Sicherheitsprotokoll aus und behaelt nur die
    Anmeldetypen 2 (lokal an der Konsole) und 10 (RemoteDesktop). Damit
    faellt der ganze Rest weg - Dienst-, Netzwerk- und Batch-Anmeldungen, die
    den Grossteil der Eintraege ausmachen.

    Beantwortet die Frage, wer zuletzt tatsaechlich an einem Rechner
    gearbeitet hat.

.NOTES
    Liest maximal 10000 Events. Auf stark genutzten Systemen reicht das
    unter Umstaenden nicht ueber die vollen 90 Tage zurueck - das Ergebnis
    ist dann unvollstaendig, ohne dass es auffaellt.
#>

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
