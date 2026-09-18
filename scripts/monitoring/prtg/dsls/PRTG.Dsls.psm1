<#
.SYNOPSIS
    Gemeinsame Hilfsfunktionen fuer die DSLS-Sensoren (Dassault Systemes License Server).

.DESCRIPTION
    Buendelt das, was alle DSLS-Sensoren brauchen: Erreichbarkeitspruefung,
    Aufruf von DSLicSrv.exe im Admin-Modus und das Zusammenbauen der
    PRTG-XML-Antwort inklusive Escaping.

    Das Modul liegt bewusst im selben Ordner wie die Sensoren. PRTG fuehrt
    Custom-EXEXML-Sensoren aus ihrem Verzeichnis aus, deshalb funktioniert
    der Import ueber $PSScriptRoot. Beim Ausrollen den kompletten Ordner nach
    "Custom Sensors\EXEXML\" kopieren, nicht nur die einzelne .ps1.

.NOTES
    Autor: IT-Administration
#>

Set-StrictMode -Version Latest

function Test-DslsServer {
    <#
    .SYNOPSIS
        Prueft, ob der Lizenzserver per ICMP erreichbar ist.
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory)]
        [string]$TargetServer
    )

    Test-Connection -ComputerName $TargetServer -Count 1 -Quiet
}

function Invoke-DslsAdmin {
    <#
    .SYNOPSIS
        Fuehrt eine Befehlsfolge im Admin-Modus von DSLicSrv.exe aus.

    .PARAMETER Command
        Die Befehlsfolge ohne das fuehrende "c <server> <port>;" und ohne
        das abschliessende "d; quit" - beides wird hier ergaenzt.

    .EXAMPLE
        Invoke-DslsAdmin -TargetServer 'licsrv01' -DslsExe $exe -Command 'gli; glu -all'
    #>
    [CmdletBinding()]
    [OutputType([string[]])]
    param(
        [Parameter(Mandatory)]
        [string]$TargetServer,

        [Parameter(Mandatory)]
        [string]$DslsExe,

        [Parameter(Mandatory)]
        [string]$Command,

        [ValidateRange(1, 65535)]
        [int]$Port = 4084
    )

    if (-not (Test-Path -LiteralPath $DslsExe)) {
        throw "DSLicSrv.exe nicht gefunden unter '$DslsExe'."
    }

    $script = "c $TargetServer $Port; $Command; d; quit"
    & $DslsExe -admin -run $script 2>&1 | ForEach-Object { [string]$_ }
}

function ConvertTo-PrtgText {
    <#
    .SYNOPSIS
        Maskiert Zeichen, die die PRTG-XML-Antwort sonst zerlegen wuerden.

    .DESCRIPTION
        Kanalnamen und Meldungstexte kommen teilweise direkt aus dem
        DSLS-Output. Ein '&' oder '<' darin macht die Antwort ungueltig und
        der Sensor faellt mit "XML-Parsingfehler" aus, ohne dass der Grund
        ersichtlich waere.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [AllowNull()]
        [AllowEmptyString()]
        [string]$Text
    )

    if ([string]::IsNullOrEmpty($Text)) { return '' }

    $Text.Replace('&', '&amp;').
        Replace('<', '&lt;').
        Replace('>', '&gt;').
        Replace('"', '&quot;').
        Replace("'", '&apos;')
}

function New-PrtgResult {
    <#
    .SYNOPSIS
        Erzeugt ein einzelnes <result>-Element fuer die PRTG-Antwort.

    .PARAMETER Unit
        PRTG-Einheit. 'Custom' zusammen mit -CustomUnit fuer eigene Beschriftungen.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [string]$Channel,

        [Parameter(Mandatory)]
        [int]$Value,

        [string]$Unit = 'Count',
        [string]$CustomUnit,
        [Nullable[int]]$LimitMinWarning,
        [Nullable[int]]$LimitMinError,
        [Nullable[int]]$LimitMaxWarning,
        [Nullable[int]]$LimitMaxError
    )

    $sb = [System.Text.StringBuilder]::new()
    [void]$sb.Append('<result>')
    [void]$sb.Append("<channel>$(ConvertTo-PrtgText $Channel)</channel>")
    [void]$sb.Append("<value>$Value</value>")
    [void]$sb.Append("<unit>$Unit</unit>")

    if ($CustomUnit) {
        [void]$sb.Append("<customunit>$(ConvertTo-PrtgText $CustomUnit)</customunit>")
    }

    # limitmode nur setzen, wenn tatsaechlich eine Grenze definiert ist -
    # sonst zeigt PRTG den Kanal dauerhaft als "Limits aktiv, aber keine".
    $limits = @{
        limitminwarning = $LimitMinWarning
        limitminerror   = $LimitMinError
        limitmaxwarning = $LimitMaxWarning
        limitmaxerror   = $LimitMaxError
    }

    if ($limits.Values.Where({ $null -ne $_ }).Count -gt 0) {
        [void]$sb.Append('<limitmode>1</limitmode>')
        foreach ($name in 'limitminwarning', 'limitminerror', 'limitmaxwarning', 'limitmaxerror') {
            if ($null -ne $limits[$name]) {
                [void]$sb.Append("<$name>$($limits[$name])</$name>")
            }
        }
    }

    [void]$sb.Append('</result>')
    $sb.ToString()
}

function Write-PrtgResponse {
    <#
    .SYNOPSIS
        Gibt die vollstaendige PRTG-Antwort aus und beendet das Skript.

    .DESCRIPTION
        PRTG wertet ausschliesslich stdout aus. Der Exitcode wird ignoriert,
        Fehler muessen ueber <error>1</error> gemeldet werden - deshalb gibt
        es hier -ErrorText statt eines throw.
    #>
    [CmdletBinding()]
    param(
        [string[]]$Result,
        [string]$Text,
        [string]$ErrorText
    )

    $sb = [System.Text.StringBuilder]::new()
    [void]$sb.Append('<prtg>')

    if ($ErrorText) {
        [void]$sb.Append('<error>1</error>')
        [void]$sb.Append("<text>$(ConvertTo-PrtgText $ErrorText)</text>")
    }
    else {
        foreach ($r in $Result) { [void]$sb.Append($r) }
        if ($Text) { [void]$sb.Append("<text>$(ConvertTo-PrtgText $Text)</text>") }
    }

    [void]$sb.Append('</prtg>')
    Write-Output $sb.ToString()
}

Export-ModuleMember -Function Test-DslsServer, Invoke-DslsAdmin,
ConvertTo-PrtgText, New-PrtgResult, Write-PrtgResponse
