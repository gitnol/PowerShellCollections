[CmdletBinding()]
param (
    [Parameter(Mandatory = $true, ValueFromPipeline = $true, HelpMessage = "Liste von Computernamen oder DNSHostNames.")]
    [string[]]$ComputerNames,

    [Parameter(Mandatory = $true, HelpMessage = "Der TeamViewer AccessControlType (0 = Vollzugriff, 1 = Bestätigung, 2 = Nur Ansicht, 3 = Custom).")]
    [ValidateRange(0, 3)]
    [int]$AccessControlType
)

begin {
    # Definition der Funktion für die parallele Online-Prüfung im Begin-Block
    function Test-ConnectionInParallel {
        [CmdletBinding()]
        param (
            [Parameter(Mandatory = $true)]
            [string[]]$Targets,
            [int]$Throttle = 10
        )
        $Targets | ForEach-Object -Parallel {
            Write-Progress -Activity "Checking computer online status" -Status "$_"
            [PSCustomObject]@{
                ComputerName = $_
                Online       = Test-Connection -ComputerName $_ -Count 1 -Quiet -TimeoutSeconds 1
                IP           = (Test-Connection -ComputerName $_ -Count 1 -TimeoutSeconds 1 -ErrorAction SilentlyContinue).Address.IPAddressToString
            }
        } -ThrottleLimit $Throttle
    }
}

process {
    Write-Output "Starte Vorab-Prüfung der Erreichbarkeit für $($ComputerNames.Count) Systeme..."

    # ─────────────────────────────────────────────────────────────────────────────
    # 1. Erreichbarkeit prüfen (Verpflichtend)
    # ─────────────────────────────────────────────────────────────────────────────
    $OnlineComputers = Test-ConnectionInParallel -Throttle 20 -Targets $ComputerNames |
    Where-Object { $_.Online }

    $TargetHosts = $OnlineComputers.ComputerName

    if (-not $TargetHosts) {
        Write-Warning "Keine der übergebenen Rechner sind online. Abbruch."
        return
    }

    Write-Output "Führe TeamViewer-Konfiguration auf $($TargetHosts.Count) Online-Systemen aus..."

    # ─────────────────────────────────────────────────────────────────────────────
    # 2. TeamViewer-Konfiguration remote anpassen
    # ─────────────────────────────────────────────────────────────────────────────
    $FinalResults = Invoke-Command -ComputerName $TargetHosts -ThrottleLimit 20 -ScriptBlock {
        $Value = $using:AccessControlType
        $RegPath = "HKLM:\SOFTWARE\TeamViewer\AccessControl"
        $KeyName = "AC_Server_AccessControlType"

        # Rückgabeobjekt initialisieren
        $Result = [PSCustomObject]@{
            ComputerName = $env:COMPUTERNAME
            Status       = "Fehler"
            Details      = ""
        }

        if (-not (Test-Path -Path $RegPath)) {
            New-Item -Path $RegPath -Force | Out-Null
        }

        try {
            # Registry-Wert setzen
            Set-ItemProperty -Path $RegPath -Name $KeyName -Value $Value -Type DWord -ErrorAction Stop
            $Result.Details = "Registry-Key auf $Value gesetzt."
            
            # TeamViewer-Dienst neu starten
            $TvService = Get-Service -Name "*teamviewer*" -ErrorAction SilentlyContinue
            if ($TvService) {
                Restart-Service -InputObject $TvService -Force
                $Result.Status = "Erfolgreich"
                $Result.Details += " Dienst ($($TvService.Name)) neu gestartet."
            }
            else {
                $Result.Status = "Warnung"
                $Result.Details += " Aber TeamViewer-Dienst wurde nicht gefunden."
            }
        }
        catch {
            $Result.Status = "Fehler"
            $Result.Details = $_.Exception.Message
        }

        return $Result
    } -ErrorAction SilentlyContinue

    # ─────────────────────────────────────────────────────────────────────────────
    # 3. Ergebnisse strukturiert anzeigen
    # ─────────────────────────────────────────────────────────────────────────────
    if ($FinalResults) {
        $FinalResults |
        Select-Object ComputerName, Status, Details |
        Sort-Object Status, ComputerName |
        Out-GridView -Title "TeamViewer AC-Typ Umstellung ($($FinalResults.Count) Systeme verarbeitet)"
    }
    else {
        Write-Warning "Es wurden keine Ergebnisse von den Remote-Systemen zurückgegeben (WinRM-Fehler?)."
    }
}