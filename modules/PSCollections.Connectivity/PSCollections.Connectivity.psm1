<#
    PSCollections.Connectivity

    Erreichbarkeitspruefung fuer viele Rechner. Zusammengefuehrt aus drei
    identischen Kopien von Test-ConnectionInParallel, die unabhaengig
    voneinander in scripts/windows/availability/, scripts/applications/
    teamviewer/ und scripts/security/secure-boot/ lagen.

    Die Kopien waren inhaltlich gleich und teilten dieselben Fehler; sie sind
    hier behoben. Was sich geaendert hat, steht in den .NOTES der jeweiligen
    Funktion.
#>

Set-StrictMode -Version Latest

function Test-ConnectionInParallel {
    <#
    .SYNOPSIS
        Prueft die Erreichbarkeit vieler Rechner parallel.

    .DESCRIPTION
        Sendet je Ziel einen Ping und gibt Erreichbarkeit, IP-Adresse,
        Antwortzeit und den rohen Ping-Status zurueck. Die Abfragen laufen
        ueber ForEach-Object -Parallel, die Gleichzeitigkeit ist ueber
        -ThrottleLimit begrenzt.

        Benoetigt PowerShell 7. Fuer Windows PowerShell 5.1 gibt es
        Get-ComputerOnlineStatus in diesem Modul, das ueber Hintergrundjobs
        arbeitet.

    .PARAMETER ComputerName
        Ein oder mehrere Ziele. Nimmt auch Pipeline-Eingaben entgegen, auch
        aus Objekten mit den Eigenschaften Name oder DNSHostName - damit
        funktioniert `Get-ADComputer -Filter * | Test-ConnectionInParallel`
        direkt.

    .PARAMETER ThrottleLimit
        Wie viele Pruefungen gleichzeitig laufen duerfen. Standard: 10

    .PARAMETER TimeoutSeconds
        Zeitlimit je Ping. Standard: 1

    .EXAMPLE
        Test-ConnectionInParallel -ComputerName 'DC01','DC02','FS01'

    .EXAMPLE
        Get-ADComputer -Filter * |
            Test-ConnectionInParallel -ThrottleLimit 50 |
            Where-Object Online

    .OUTPUTS
        PSCustomObject mit ComputerName, Online, IP, LatencyMs, Status

    .NOTES
        Gegenueber den drei zusammengefuehrten Kopien behoben:

        1. Pipeline-Eingabe ging verloren. ValueFromPipeline war deklariert,
           aber es gab keinen process-Block - dadurch wurde nur das LETZTE
           Element verarbeitet. `$liste | Test-ConnectionInParallel` pruefte
           also genau einen Rechner, ohne Fehlermeldung. Nachgemessen:
           drei Eingaben, ein Ergebnis.

        2. Test-Connection wurde je Ziel ZWEIMAL aufgerufen - einmal mit
           -Quiet fuer den Status, einmal ohne fuer die IP-Adresse. Das
           verdoppelte Laufzeit und Netzlast. Ein Aufruf liefert beides: die
           Eigenschaft Status sagt Success oder TimedOut, Address enthaelt
           die IP.

        3. LatencyMs und Status sind neu. Bestehende Auswertungen auf
           ComputerName, Online und IP funktionieren unveraendert weiter.

        Write-Progress innerhalb von ForEach-Object -Parallel schreiben alle
        Runspaces auf dieselbe Anzeige; die Fortschrittsangabe ist deshalb
        nur ein grober Lebenszeichen-Indikator.
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName, Position = 0)]
        [Alias('Targets', 'Name', 'DNSHostName', 'ComputerNames')]
        [string[]]$ComputerName,

        # 'throttlelimit' braucht keinen Alias - PowerShell unterscheidet bei
        # Parameternamen keine Gross- und Kleinschreibung.
        [Alias('Throttle')]
        [ValidateRange(1, 1000)]
        [int]$ThrottleLimit = 10,

        [ValidateRange(1, 60)]
        [int]$TimeoutSeconds = 1
    )

    begin {
        $targets = [System.Collections.Generic.List[string]]::new()
    }

    process {
        # Sammeln statt sofort pruefen: ForEach-Object -Parallel lohnt sich
        # erst, wenn alle Ziele bekannt sind.
        foreach ($name in $ComputerName) {
            if ($name) { $targets.Add($name) }
        }
    }

    end {
        if ($targets.Count -eq 0) { return }

        $timeout = $TimeoutSeconds

        $targets | ForEach-Object -ThrottleLimit $ThrottleLimit -Parallel {
            Write-Progress -Activity 'Erreichbarkeit wird geprueft' -Status $_

            $reply = Test-Connection -TargetName $_ -Count 1 `
                -TimeoutSeconds $using:timeout -ErrorAction SilentlyContinue

            $online = $reply -and $reply.Status -eq 'Success'

            [pscustomobject]@{
                ComputerName = $_
                Online       = [bool]$online
                IP           = if ($online) { $reply.Address.IPAddressToString } else { $null }
                LatencyMs    = if ($online) { $reply.Latency } else { $null }
                Status       = if ($reply) { [string]$reply.Status } else { 'NoReply' }
            }
        }
    }
}

function Get-ComputerOnlineStatus {
    <#
    .SYNOPSIS
        Prueft die Erreichbarkeit vieler Rechner ueber Hintergrundjobs - auch
        unter Windows PowerShell 5.1.

    .DESCRIPTION
        Gleiche Aufgabe wie Test-ConnectionInParallel, aber ohne
        ForEach-Object -Parallel: die Pruefungen laufen als Hintergrundjobs.
        Damit funktioniert die Funktion auch dort, wo nur Windows PowerShell
        5.1 zur Verfuegung steht.

        Jobs, die laenger als das Zeitlimit laufen, werden abgebrochen - ein
        Rechner, der weder antwortet noch ablehnt, blockiert den Lauf sonst
        bis zum Netzwerk-Timeout.

    .PARAMETER ComputerName
        Ein oder mehrere Ziele, auch ueber die Pipeline.

    .PARAMETER ThrottleLimit
        Wie viele Jobs gleichzeitig laufen duerfen. Standard: 12

    .PARAMETER PingCount
        Anzahl Pings je Ziel. Standard: 2

    .PARAMETER JobTimeoutMinutes
        Nach wie vielen Minuten ein haengender Job abgebrochen wird.
        Standard: 2

    .EXAMPLE
        Get-ComputerOnlineStatus -ComputerName 'DC01','DC02'

    .OUTPUTS
        PSCustomObject mit ComputerName, Online, IP

    .NOTES
        Gegenueber der zusammengefuehrten Fassung behoben:

        1. Derselbe Pipeline-Fehler wie bei Test-ConnectionInParallel: ohne
           process-Block wurde nur das letzte Element verarbeitet.

        2. Throttling und Zeitueberwachung liefen ueber `Get-Job -State
           Running` und betrachteten damit ALLE Jobs der Sitzung. Hatte der
           Aufrufer eigene Hintergrundjobs laufen, zaehlten die mit - und
           schlimmer: die Zeitueberwachung beendete sie nach zwei Minuten
           mit Stop-Job. Beides ist jetzt auf die eigenen Jobs beschraenkt.

        3. Die Ergebnis-Eigenschaft hiess Computer statt ComputerName und
           wich damit von Test-ConnectionInParallel ab. Jetzt einheitlich
           ComputerName.

        Test-Connection wird weiterhin zweimal je Ziel aufgerufen: unter
        Windows PowerShell 5.1 kennt das Cmdlet die Eigenschaft Status nicht,
        der Einzelaufruf-Trick aus der Parallel-Variante funktioniert dort
        also nicht.
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName, Position = 0)]
        [Alias('Computers', 'Name', 'DNSHostName')]
        [string[]]$ComputerName,

        [Alias('numberConcurrentJobs')]
        [ValidateRange(1, 100)]
        [int]$ThrottleLimit = 12,

        [Alias('pingCounts')]
        [ValidateRange(1, 10)]
        [int]$PingCount = 2,

        [ValidateRange(1, 60)]
        [int]$JobTimeoutMinutes = 2
    )

    begin {
        $targets = [System.Collections.Generic.List[string]]::new()
    }

    process {
        foreach ($name in $ComputerName) {
            if ($name) { $targets.Add($name) }
        }
    }

    end {
        if ($targets.Count -eq 0) { return }

        $jobs = [System.Collections.Generic.List[object]]::new()
        $started = 0
        $timeout = [TimeSpan]::FromMinutes($JobTimeoutMinutes)

        # Haengende Jobs abbrechen - ausschliesslich eigene.
        $stopOverdue = {
            param($ownJobs, $limit)
            $now = Get-Date
            foreach ($job in @($ownJobs | Where-Object { $_.State -eq 'Running' })) {
                if ($job.PSBeginTime -and ($now - $job.PSBeginTime) -gt $limit) {
                    Stop-Job -Job $job
                    Write-Verbose "Job $($job.Id) nach Zeitueberschreitung abgebrochen."
                }
            }
        }

        foreach ($computer in $targets) {
            while (@($jobs | Where-Object { $_.State -eq 'Running' }).Count -ge $ThrottleLimit) {
                & $stopOverdue $jobs $timeout
                Start-Sleep -Seconds 1
            }

            $jobs.Add((Start-Job -ScriptBlock {
                        $target = $using:computer
                        $online = Test-Connection -ComputerName $target -Count $using:PingCount -Quiet
                        $reply = Test-Connection -ComputerName $target -Count 1 -ErrorAction SilentlyContinue |
                            Select-Object -First 1

                        # Die Eigenschaft heisst je nach PowerShell-Version
                        # anders: Windows PowerShell 5.1 liefert
                        # Win32_PingStatus mit IPV4Address, PowerShell 7
                        # liefert PingStatus mit Address. In 5.1 enthaelt
                        # Address den Zielnamen, nicht die IP - deshalb wird
                        # IPV4Address zuerst geprueft.
                        $ip = $null
                        if ($reply) {
                            if ($reply.PSObject.Properties['IPV4Address']) {
                                $ip = $reply.IPV4Address.IPAddressToString
                            }
                            elseif ($reply.PSObject.Properties['Address']) {
                                $ip = $reply.Address.IPAddressToString
                            }
                        }

                        [pscustomobject]@{
                            ComputerName = $target
                            Online       = [bool]$online
                            IP           = $ip
                        }
                    }))

            $started++
            Write-Progress -Activity 'Erreichbarkeit wird geprueft' `
                -Status "Job $started von $($targets.Count)" `
                -PercentComplete (($started / $targets.Count) * 100)
        }

        while (@($jobs | Where-Object { $_.State -eq 'Running' }).Count -gt 0) {
            & $stopOverdue $jobs $timeout
            Start-Sleep -Seconds 2
        }

        try {
            $jobs | Receive-Job | Select-Object ComputerName, Online, IP
        }
        finally {
            $jobs | Remove-Job -Force -ErrorAction SilentlyContinue
        }
    }
}

Export-ModuleMember -Function Test-ConnectionInParallel, Get-ComputerOnlineStatus
