#Requires -RunAsAdministrator

<#
.SYNOPSIS
    PowerShell script to manage Windows startup entries using Sysinternals Autoruns
.DESCRIPTION
    Displays autorun entries in a grid view and allows enabling/disabling them directly
.PARAMETER PathToSysinternals
    Path to the Sysinternals suite directory
.PARAMETER WithMicrosoftEntries
    Include Microsoft-signed entries in the output
#>

[CmdletBinding()]
param(
    [string]$PathToSysinternals = "C:\install\sysinternalssuite",
    [switch]$WithMicrosoftEntries
)

# ═══════════════════════════════════════════════════════════════════════════════
# CONFIGURATION
# ═══════════════════════════════════════════════════════════════════════════════

$Script:Config = @{
    AutorunsPath     = Join-Path $PathToSysinternals "autorunsc64.exe"
    OutputFile       = Join-Path $PathToSysinternals "autoruns.txt"
    DisabledKeyName  = "AutorunsDisabled"
}

# ═══════════════════════════════════════════════════════════════════════════════
# HELPER FUNCTIONS
# ═══════════════════════════════════════════════════════════════════════════════

function Test-Prerequisites {
    <#
    .SYNOPSIS
        Validates that required tools and permissions are available
    #>
    if (-not (Test-Path $Script:Config.AutorunsPath)) {
        throw "Autorunsc64.exe nicht gefunden unter: $($Script:Config.AutorunsPath)"
    }
    
    if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        throw "Dieses Script erfordert Administratorrechte"
    }
}

function Write-DebugInfo {
    <#
    .SYNOPSIS
        Writes debug information with consistent formatting
    #>
    param([string]$Message)
    Write-Host "[DEBUG] $Message" -ForegroundColor Yellow
}

# ═══════════════════════════════════════════════════════════════════════════════
# CORE FUNCTIONS
# ═══════════════════════════════════════════════════════════════════════════════

function Get-AutorunEntries {
    <#
    .SYNOPSIS
        Retrieves autorun entries using Sysinternals Autoruns
    #>
    param([switch]$IncludeMicrosoftEntries)
    
    Write-DebugInfo "Sammle Autorun-Einträge$(if (-not $IncludeMicrosoftEntries) {' (ohne Microsoft-Einträge)'})"
    
    $arguments = @(
        '-accepteula'
        '-a', '*'
        '-ct'
        '-nobanner'
        '-o', $Script:Config.OutputFile
    )
    
    if (-not $IncludeMicrosoftEntries) {
        $arguments += '-m'
    }
    
    try {
        $null = & $Script:Config.AutorunsPath @arguments
        
        if (-not (Test-Path $Script:Config.OutputFile)) {
            throw "Autoruns-Ausgabedatei wurde nicht erstellt"
        }
        
        return Get-Content $Script:Config.OutputFile -Encoding Default | ConvertFrom-Csv -Delimiter "`t"
    }
    catch {
        throw "Fehler beim Ausführen von Autoruns: $($_.Exception.Message)"
    }
}

function Set-AutorunEntryState {
    <#
    .SYNOPSIS
        Enables or disables an autorun entry
    #>
    param(
        [Parameter(Mandatory)]$Entry,
        [Parameter(Mandatory)][ValidateSet('Enable', 'Disable')][string]$Action
    )
    
    $currentState = $Entry.Enabled
    $targetState = if ($Action -eq 'Enable') { 'enabled' } else { 'disabled' }
    
    Write-DebugInfo "$Action Eintrag: '$($Entry.Entry)' in '$($Entry.'Entry Location')' (aktuell: $currentState)"
    
    if ($currentState -eq $targetState) {
        Write-DebugInfo "Eintrag ist bereits im gewünschten Zustand ($targetState)"
        return
    }
    
    switch -Regex ($Entry.'Entry Location') {
        '^(HKLM|HKCU)\\' { 
            Set-RegistryAutorunEntry -Entry $Entry -Action $Action 
        }
        'Task Scheduler' { 
            Set-TaskAutorunEntry -Entry $Entry -Action $Action 
        }
        default { 
            Write-Warning "Nicht unterstützter Entry-Typ: $($Entry.'Entry Location')" 
        }
    }
}

function Set-RegistryAutorunEntry {
    <#
    .SYNOPSIS
        Handles registry-based autorun entries
    #>
    param(
        [Parameter(Mandatory)]$Entry,
        [Parameter(Mandatory)][string]$Action
    )
    
    $registryPath = $Entry.'Entry Location'
    $valueName = $Entry.Entry
    $disabledPath = Join-Path $registryPath $Script:Config.DisabledKeyName
    
    try {
        if ($Action -eq 'Disable') {
            Move-RegistryValue -SourcePath $registryPath -TargetPath $disabledPath -ValueName $valueName
        } else {
            Move-RegistryValue -SourcePath $disabledPath -TargetPath $registryPath -ValueName $valueName
        }
    }
    catch {
        Write-Error "Fehler beim Bearbeiten des Registry-Eintrags: $($_.Exception.Message)"
    }
}

function Set-TaskAutorunEntry {
    <#
    .SYNOPSIS
        Handles Task Scheduler autorun entries
    #>
    param(
        [Parameter(Mandatory)]$Entry,
        [Parameter(Mandatory)][string]$Action
    )
    
    $taskName = $Entry.Entry
    $operation = if ($Action -eq 'Enable') { '/ENABLE' } else { '/DISABLE' }
    
    Write-DebugInfo "$Action Task: $taskName"
    
    try {
        $result = schtasks /Change /TN "$taskName" $operation 2>&1
        if ($LASTEXITCODE -ne 0) {
            throw "schtasks beendet mit Fehlercode $LASTEXITCODE`: $result"
        }
    }
    catch {
        Write-Error "Fehler beim Bearbeiten des Tasks: $($_.Exception.Message)"
    }
}

function Move-RegistryValue {
    <#
    .SYNOPSIS
        Moves a registry value between keys
    #>
    param(
        [string]$SourcePath,
        [string]$TargetPath,
        [string]$ValueName
    )
    
    $sourceRegPath = "Registry::$SourcePath"
    $targetRegPath = "Registry::$TargetPath"
    
    # Prüfe ob Quellwert existiert
    $sourceValue = Get-ItemProperty -Path $sourceRegPath -Name $ValueName -ErrorAction SilentlyContinue
    if (-not $sourceValue) {
        throw "Wert '$ValueName' nicht gefunden in $SourcePath"
    }
    
    # Erstelle Zielschlüssel falls nicht vorhanden
    if (-not (Test-Path $targetRegPath)) {
        Write-DebugInfo "Erstelle Registry-Schlüssel: $TargetPath"
        New-Item -Path $targetRegPath -Force | Out-Null
    }
    
    # Kopiere Wert
    $propertyType = $sourceValue.PSObject.Properties[$ValueName].TypeNameOfValue
    $value = $sourceValue.$ValueName
    
    Write-DebugInfo "Verschiebe '$ValueName' von $SourcePath → $TargetPath"
    New-ItemProperty -Path $targetRegPath -Name $ValueName -Value $value -Force | Out-Null
    
    # Lösche Originalwert
    Remove-ItemProperty -Path $sourceRegPath -Name $ValueName
    
    # Verifikation
    $verification = Get-ItemProperty -Path $targetRegPath -Name $ValueName -ErrorAction SilentlyContinue
    if (-not $verification) {
        throw "Verschiebung fehlgeschlagen: Wert nicht im Ziel gefunden"
    }
}

function Show-UserInterface {
    <#
    .SYNOPSIS
        Main user interface loop
    #>
    do {
        try {
            Write-Host "Lade Autorun-Einträge..." -ForegroundColor Green
            $autorunEntries = Get-AutorunEntries -IncludeMicrosoftEntries:$WithMicrosoftEntries
            
            if (-not $autorunEntries) {
                Write-Warning "Keine Autorun-Einträge gefunden"
                break
            }
            
            Write-Host "Gefunden: $($autorunEntries.Count) Einträge" -ForegroundColor Green
            
            # Zeige Einträge zur Auswahl
            $selectedEntry = $autorunEntries | Out-GridView -Title "Autoruns - Eintrag auswählen" -PassThru
            if (-not $selectedEntry) {
                Write-Host "Keine Auswahl getroffen. Beende..." -ForegroundColor Yellow
                break
            }
            
            # Zeige Aktionsoptionen
            $availableActions = @('Enable', 'Disable', 'Beenden')
            $selectedAction = $availableActions | Out-GridView -Title "Aktion auswählen" -PassThru
            
            switch ($selectedAction) {
                { $_ -in @('Enable', 'Disable') } {
                    Set-AutorunEntryState -Entry $selectedEntry -Action $_
                    Write-Host "Aktion '$_' erfolgreich ausgeführt" -ForegroundColor Green
                }
                'Beenden' {
                    Write-Host "Programm wird beendet..." -ForegroundColor Yellow
                    return
                }
                default {
                    Write-Host "Keine gültige Aktion ausgewählt" -ForegroundColor Yellow
                }
            }
        }
        catch {
            Write-Error "Unerwarteter Fehler: $($_.Exception.Message)"
            $continue = Read-Host "Fortfahren? (j/n)"
            if ($continue -ne 'j') { break }
        }
    } while ($true)
}

# ═══════════════════════════════════════════════════════════════════════════════
# MAIN EXECUTION
# ═══════════════════════════════════════════════════════════════════════════════

try {
    Write-Host "Autoruns PowerShell Manager" -ForegroundColor Cyan
    Write-Host "═══════════════════════════════════════" -ForegroundColor Cyan
    
    Test-Prerequisites
    Show-UserInterface
}
catch {
    Write-Error "Kritischer Fehler: $($_.Exception.Message)"
    exit 1
}
finally {
    # Cleanup
    if (Test-Path $Script:Config.OutputFile) {
        Remove-Item $Script:Config.OutputFile -Force -ErrorAction SilentlyContinue
    }
}