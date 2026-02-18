<#
.SYNOPSIS
    Verwaltet Outlook Add-ins (Status prüfen, Listen, Reparieren).

.DESCRIPTION
    Dieses Script kann alle installierten Add-ins auflisten oder ein spezifisches Add-in prüfen und reparieren.
    Es berücksichtigt User- (HKCU) und System-Einstellungen (HKLM) sowie die "Resiliency" (Absturzliste).

.PARAMETER List
    Listet alle gefundenen Add-ins und deren Status tabellarisch auf.

.PARAMETER TargetAddin
    Der technische Name des Add-ins (Registry-Schlüssel), z.B. 'PhishAlert.AddinModule'.

.PARAMETER FixIssues
    Versucht, das angegebene TargetAddin zu reparieren (Resiliency bereinigen, LoadBehavior erzwingen).

.EXAMPLE
    .\Manage-OutlookAddins.ps1 -List
    Zeigt eine Tabelle aller Add-ins.

.EXAMPLE
    .\Manage-OutlookAddins.ps1 -TargetAddin "PhishAlert.AddinModule" -FixIssues
    Prüft das spezifische Add-in und repariert es bei Fehlern.
#>

[CmdletBinding(DefaultParameterSetName = 'ListAll')]
param(
    [Parameter(Mandatory = $true, ParameterSetName = 'ListAll')]
    [Switch]$List,

    [Parameter(Mandatory = $true, ParameterSetName = 'SingleTarget')]
    [string]$TargetAddin,

    [Parameter(ParameterSetName = 'SingleTarget')]
    [Switch]$FixIssues
)

# --- HILFSFUNKTIONEN ---

function Get-AddinStatus {
    param([string]$Name)

    # Pfade definieren
    $p_HKCU = "HKCU:\Software\Microsoft\Office\Outlook\Addins\$Name"
    $p_HKLM_64 = "HKLM:\Software\Microsoft\Office\Outlook\Addins\$Name"
    $p_HKLM_32 = "HKLM:\Software\WOW6432Node\Microsoft\Office\Outlook\Addins\$Name"
    $p_Resiliency = "HKCU:\Software\Microsoft\Office\16.0\Outlook\Resiliency\DisabledItems"
    
    $statusObj = [PSCustomObject]@{
        Name           = $Name
        LoadBehavior   = "N/A"
        Source         = "Nicht gefunden"
        StatusText     = "Nicht installiert"
        IsHardDisabled = $false
    }

    # 1. Check Hard-Disabled (Resiliency)
    if (Test-Path $p_Resiliency) {
        $items = Get-ItemProperty -Path $p_Resiliency
        foreach ($prop in $items.PSObject.Properties) {
            if ($prop.Name -match "default" -or $prop.Name -match "PS") { continue }
            try {
                $decoded = [System.Text.Encoding]::Unicode.GetString($prop.Value) -replace "`0", ""
                if ($decoded -match $Name) {
                    $statusObj.IsHardDisabled = $true
                }
            }
            catch {}
        }
    }

    # 2. Check LoadBehavior (Hierarchie: HKCU > HKLM64 > HKLM32)
    $lb = $null
    
    if (Test-Path $p_HKCU) {
        $val = (Get-ItemProperty $p_HKCU).LoadBehavior
        if ($null -ne $val) { $lb = $val; $statusObj.Source = "HKCU (User)" }
    }
    
    if ($null -eq $lb -and (Test-Path $p_HKLM_64)) {
        $val = (Get-ItemProperty $p_HKLM_64).LoadBehavior
        if ($null -ne $val) { $lb = $val; $statusObj.Source = "HKLM (System 64)" }
    }

    if ($null -eq $lb -and (Test-Path $p_HKLM_32)) {
        $val = (Get-ItemProperty $p_HKLM_32).LoadBehavior
        if ($null -ne $val) { $lb = $val; $statusObj.Source = "HKLM (System 32)" }
    }

    $statusObj.LoadBehavior = if ($null -ne $lb) { $lb } else { "Fehlt" }

    # 3. Finaler Status Text
    if ($statusObj.IsHardDisabled) {
        $statusObj.StatusText = "CRITICAL (Hard Disabled)"
    }
    elseif ($lb -eq 3) {
        $statusObj.StatusText = "OK (Aktiv)"
    }
    elseif ($lb -eq 2) {
        $statusObj.StatusText = "Inaktiv (Load on Demand)"
    }
    elseif ($lb -eq 0) {
        $statusObj.StatusText = "Deaktiviert"
    }
    else {
        $statusObj.StatusText = "Unbekannt ($lb)"
    }

    return $statusObj
}

function Repair-Addin {
    param([string]$Name)

    Write-Host "--- Starte Reparatur für '$Name' ---" -ForegroundColor Yellow
    
    # 1. Resiliency bereinigen
    $p_Resiliency = "HKCU:\Software\Microsoft\Office\16.0\Outlook\Resiliency\DisabledItems"
    if (Test-Path $p_Resiliency) {
        $items = Get-ItemProperty -Path $p_Resiliency
        foreach ($prop in $items.PSObject.Properties) {
            if ($prop.Name -match "default" -or $prop.Name -match "PS") { continue }
            try {
                $decoded = [System.Text.Encoding]::Unicode.GetString($prop.Value) -replace "`0", ""
                if ($decoded -match $Name) {
                    Remove-ItemProperty -Path $p_Resiliency -Name $prop.Name
                    Write-Host " [FIX] Eintrag aus Absturzliste (Resiliency) entfernt." -ForegroundColor Green
                }
            }
            catch {}
        }
    }

    # 2. LoadBehavior erzwingen (HKCU)
    $p_HKCU = "HKCU:\Software\Microsoft\Office\Outlook\Addins\$Name"
    if (-not (Test-Path $p_HKCU)) {
        New-Item -Path $p_HKCU -Force | Out-Null
        Write-Host " [FIX] Registry-Key in HKCU erstellt." -ForegroundColor Cyan
    }
    
    Set-ItemProperty -Path $p_HKCU -Name "LoadBehavior" -Value 3 -Type DWord
    Write-Host " [FIX] LoadBehavior in HKCU hart auf 3 gesetzt." -ForegroundColor Green
}

# --- HAUPTPROGRAMM ---

if ($PSCmdlet.ParameterSetName -eq 'ListAll') {
    Write-Host "--- Installierte Outlook Add-ins ---" -ForegroundColor Cyan
    
    # Sammle alle eindeutigen Namen aus HKCU und HKLM
    $names = @()
    $paths = @(
        "HKCU:\Software\Microsoft\Office\Outlook\Addins",
        "HKLM:\Software\Microsoft\Office\Outlook\Addins",
        "HKLM:\Software\WOW6432Node\Microsoft\Office\Outlook\Addins"
    )

    foreach ($path in $paths) {
        if (Test-Path $path) {
            $names += Get-ChildItem $path | Select-Object -ExpandProperty PSChildName
        }
    }
    $uniqueNames = $names | Select-Object -Unique | Sort-Object

    $results = @()
    foreach ($n in $uniqueNames) {
        $results += Get-AddinStatus -Name $n
    }

    $results | Format-Table -AutoSize
}

if ($PSCmdlet.ParameterSetName -eq 'SingleTarget') {
    $status = Get-AddinStatus -Name $TargetAddin
    
    Write-Host "Add-in: " -NoNewline; Write-Host $TargetAddin -ForegroundColor Cyan
    Write-Host "Quelle: " -NoNewline; Write-Host $status.Source -ForegroundColor Gray
    
    if ($status.IsHardDisabled) {
        Write-Host "Status: " -NoNewline; Write-Host $status.StatusText -ForegroundColor Red
    }
    elseif ($status.LoadBehavior -eq 3) {
        Write-Host "Status: " -NoNewline; Write-Host $status.StatusText -ForegroundColor Green
    }
    else {
        Write-Host "Status: " -NoNewline; Write-Host $status.StatusText -ForegroundColor Yellow
    }

    if ($FixIssues) {
        if ($status.LoadBehavior -ne 3 -or $status.IsHardDisabled) {
            Repair-Addin -Name $TargetAddin
            
            # Re-Check
            $newStatus = Get-AddinStatus -Name $TargetAddin
            if ($newStatus.LoadBehavior -eq 3 -and -not $newStatus.IsHardDisabled) {
                Write-Host "ERGEBNIS: Add-in erfolgreich aktiviert." -ForegroundColor Green
            }
        }
        else {
            Write-Host "Keine Reparatur notwendig. Add-in ist bereits aktiv." -ForegroundColor Green
        }
    }
}