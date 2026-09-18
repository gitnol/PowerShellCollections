function Set-WbemTracing {
    <#
.SYNOPSIS
Liest oder ändert WBEM/WMI Tracing-Einstellungen unter HKLM:\SOFTWARE\Microsoft\WBEM\CIMOM.

.BESCHREIBUNG
Diese Funktion ermöglicht das Auslesen oder gezielte Setzen von Registry-Werten zur Steuerung des WMI-Tracings:
- EnableEvents
- Logging
- LoggingLevel

Unterstützt drei Modi:
- ReadOnly: Nur aktuelle Werte anzeigen (Standardverhalten)
- DeactivateFull: Alle Werte auf 0 setzen (vollständig deaktivieren)
- Custom: Einzelne Werte gezielt setzen

.PARAMETER EnableEvents
Wert: 0 oder 1 — Aktiviert oder deaktiviert interne Events.

.PARAMETER Logging
Wert: 0 oder 1 — Schaltet das Logging ein oder aus.

.PARAMETER LoggingLevel
Wert: 0 bis 4 — Gibt das Detaillevel der Protokollierung an.

.PARAMETER ReadOnly
Gibt nur die aktuellen Werte zurück, ohne Änderungen vorzunehmen. (Standard)

.PARAMETER DeactivateFull
Setzt alle drei Tracing-Werte auf 0.

.EXAMPLE
Set-WbemTracing

Gibt aktuelle Werte zurück, ohne etwas zu verändern (Standardverhalten).

.EXAMPLE
Set-WbemTracing -DeactivateFull

Deaktiviert WBEM/WMI Tracing vollständig (alle Werte auf 0).

.EXAMPLE
Set-WbemTracing -EnableEvents 1 -Logging 1 -LoggingLevel 3

Aktiviert Tracing mit mittlerem Log-Level.
#>

    [CmdletBinding(DefaultParameterSetName = 'ReadOnly')]
    param (
        [Parameter(ParameterSetName = 'Custom')]
        [ValidateSet(0, 1)]
        [int]$EnableEvents,

        [Parameter(ParameterSetName = 'Custom')]
        [ValidateSet(0, 1)]
        [int]$Logging,

        [Parameter(ParameterSetName = 'Custom')]
        [ValidateSet(0, 1, 2, 3, 4)]
        [int]$LoggingLevel,

        [Parameter(ParameterSetName = 'ReadOnly')]
        [switch]$ReadOnly,

        [Parameter(ParameterSetName = 'Deactivate')]
        [switch]$DeactivateFull
    )

    $key = 'HKLM:\SOFTWARE\Microsoft\WBEM\CIMOM'
    $current = Get-ItemProperty -LiteralPath $key -Name 'EnableEvents', 'Logging', 'LoggingLevel' -ErrorAction SilentlyContinue

    if ($ReadOnly -or $PSCmdlet.ParameterSetName -eq 'ReadOnly') {
        Write-Verbose "ReadOnly-Modus aktiv: Aktuelle Tracing-Werte werden zurückgegeben."
        return [PSCustomObject]@{
            Path         = $key
            EnableEvents = $current.EnableEvents
            Logging      = $current.Logging
            LoggingLevel = $current.LoggingLevel
        }
    }


    if ($DeactivateFull) {
        $EnableEvents = 0
        $Logging = 0
        $LoggingLevel = 0
    }

    Set-ItemProperty -LiteralPath $key -Name 'EnableEvents' -Value $EnableEvents -Force
    Set-ItemProperty -LiteralPath $key -Name 'Logging' -Value $Logging -Force
    Set-ItemProperty -LiteralPath $key -Name 'LoggingLevel' -Value $LoggingLevel -Force
    Write-Verbose ("Bitte den Dienst 'Windows Management Instrumentation' neu starten, um die Änderungen zu übernehmen.")
    Write-Verbose ("Restart-Service winmgmt -Force")

    [PSCustomObject]@{
        Path            = $key
        OldEnableEvents = $current.EnableEvents
        OldLogging      = $current.Logging
        OldLoggingLevel = $current.LoggingLevel
        NewEnableEvents = $EnableEvents
        NewLogging      = $Logging
        NewLoggingLevel = $LoggingLevel
    }
}

# Example usage:
# Set-WbemTracing -ReadOnly -Verbose
# Set-WbemTracing -EnableEvents 1 -Logging 1 -LoggingLevel 3 -Verbose
# Set-WbemTracing -DeactivateFull -Verbose
