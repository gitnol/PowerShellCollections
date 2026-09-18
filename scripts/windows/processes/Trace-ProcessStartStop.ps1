<#
.SYNOPSIS
    Protokolliert laufend jeden Prozessstart und jedes Prozessende des lokalen
    Rechners nach JSON.

.DESCRIPTION
    Registriert zwei WMI-Ereignisabonnements auf __InstanceCreationEvent und
    __InstanceDeletionEvent fuer Win32_Process (Abfrageintervall 1 Sekunde).
    Jedes Ereignis wird als eine JSON-Zeile angehaengt und waehrenddessen
    farbig auf der Konsole gemeldet.

    Gedacht fuer die Beobachtung eines laufenden Vorgangs: welcher Prozess
    startet kurz und verschwindet wieder, was startet ein Installer im
    Hintergrund, wer beendet einen Dienst.

    Das Skript blockiert, bis eine Taste gedrueckt wird. Danach werden die
    Abonnements entfernt und die gesammelten Ereignisse in einem
    Out-GridView-Fenster geoeffnet.

.NOTES
    Verhalten, das man vorher wissen sollte:

    - Das Zielverzeichnis C:\install muss existieren. Out-File legt die Datei
      an, aber nicht den Ordner.
    - Beim Aufraeumen laeuft `Get-EventSubscriber | Unregister-Event`. Das
      entfernt ALLE Ereignisabonnements der Session, nicht nur die beiden
      hier registrierten. Wer in derselben Session eigene Abonnements hat,
      verliert sie.
    - Die Abbruchbedingung liest [System.Console]::KeyAvailable. In Hosts
      ohne echte Konsole (ISE, manche Remoting-Szenarien) trifft die
      Bedingung nie zu.
    - Bei hoher Prozessaktivitaet waechst die Datei schnell; je Ereignis
      entsteht eine Zeile mit allen Win32_Process-Eigenschaften.

    Autor: IT-Administration
#>

# File to which the processes should be exported to in "json" format.
$global:mylogfileJson = "C:\install\{0}_processes.json" -f (Get-Date -Format 'yyyyMMdd')


$action = {
    param ($EnableRaisingEvents, $param_event)
    $logfileJson = $global:mylogfileJson

    if ($param_event.NewEvent.ToString() -eq "__InstanceCreationEvent") {
        foreach ($item in ($param_event.NewEvent.TargetInstance | Select-Object -Property *)) {
            Write-Host("Prozess gestartet {0}" -f $item.ProcessName) -ForegroundColor Green
            # Write-Host($item | Select -Property * | Format-Table -Property * | Out-String) -ForegroundColor Green
            # Write-Host($item | Select -Property * | Format-List -Property * | Out-String) -ForegroundColor Green
            $item | Select-Object -Property @{Name = "EventType"; Expression = { "__InstanceCreationEvent" } }, * | ConvertTo-Json -Compress -Depth 1 -WarningAction SilentlyContinue | Out-File -Append -FilePath $logfileJson -Encoding utf8
        }	
    }
    if ($param_event.NewEvent.ToString() -eq "__InstanceDeletionEvent") {
        foreach ($item in ($param_event.NewEvent.TargetInstance | Select-Object -Property *)) {
            Write-Host("Prozess entfernt {0}" -f $item.ProcessName) -ForegroundColor Red
            # Write-Host($item | Select -Property * |Format-Table -Property *| Out-String) -ForegroundColor Red
            # Write-Host($item | Select -Property * |Format-List -Property *  | Out-String) -ForegroundColor Red
            $item | Select-Object -Property @{Name = "EventType"; Expression = { "__InstanceDeletionEvent" } }, * | ConvertTo-Json -Compress -Depth 1 -WarningAction SilentlyContinue | Out-File -Append -FilePath $logfileJson -Encoding utf8
        }
    }
}

# Register event for process creation
Register-CimIndicationEvent -Namespace root/cimv2 -Query "SELECT * FROM __InstanceCreationEvent WITHIN 1 WHERE TargetInstance ISA 'Win32_Process'" -SourceIdentifier ProcessCreation -Action $action

# Register event for process termination
Register-CimIndicationEvent -Namespace root/cimv2 -Query "SELECT * FROM __InstanceDeletionEvent WITHIN 1 WHERE TargetInstance ISA 'Win32_Process'" -SourceIdentifier ProcessDeletion -Action $action

# # Keep the script running to listen for events
Write-Host("Listening for process start and stop events. Press Any Key to exit.")
# $logfileJson existiert nur innerhalb von $action; auf Skriptebene war die
# Meldung bisher leer.
Write-Host("LogFile: $global:mylogfileJson")

$sec = 0 
do {
    Write-Host -ForegroundColor Green "$sec Sec"
    Start-Sleep -Seconds 1
    $sec++    
} until ([System.Console]::KeyAvailable)

# Remove the registered Events
Get-EventSubscriber | Unregister-Event

# Einlesen
$Allprocesses = @(); Get-Content -Path $mylogfileJson | ForEach-Object { $Allprocesses += $_ | ConvertFrom-Json }
$Allprocesses | Out-GridView
