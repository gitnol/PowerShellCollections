# Requires -RunAsAdministrator
# PowerShell script to run Autoruns from Sysinternals and display results in a grid view.
# Allows enabling/disabling entries directly from the grid view.
# Lädt Autoruns, zeigt Einträge und ermöglicht Deaktivieren/Aktivieren/Beenden

# Time           : 19.07.1935 17:32
# Entry Location : HKLM\System\CurrentControlSet\Services\WinSock2\Parameters\NameSpace_Catalog5\Catalog_Entries64
# Entry          : Bluetooth Namespace
# Enabled        : enabled
# Category       : Network Providers
# Profile        : System-wide
# Description    : Windows Sockets Helper DLL
# Company        : Microsoft Corporation
# Image Path     : c:\windows\system32\wshbth.dll
# Version        : 10.0.26100.5074
# Launch String  : %SystemRoot%\system32\wshbth.dll

# Time           : 14.10.2024 13:02
# Entry Location : Task Scheduler
# Entry          : \redacted\redacted
# Enabled        : enabled
# Category       : Tasks
# Profile        : System-wide
# Description    : redacted
# Company        : redacted
# Image Path     : redacted
# Version        : redacted
# Launch String  : redacted


function Get-Autoruns {
    param (
        [string]$pathToSysinternals = "C:\install\sysinternalssuite",
        [switch]$WithMicrosoftEntries
    )
    
    if ($WithMicrosoftEntries) {
        Start-Process "$pathToSysinternals\autorunsc64.exe" -ArgumentList @( '-accepteula ', '-a', '*', '-ct', '-nobanner', '-o', ($pathToSysinternals + '\autoruns.txt') ) -Wait -NoNewWindow
    }
    else {
        Start-Process "$pathToSysinternals\autorunsc64.exe" -ArgumentList @( '-accepteula ', '-a', '*', '-ct', '-nobanner', '-m', '-o', ($pathToSysinternals + '\autoruns.txt') ) -Wait -NoNewWindow
    }
    return (Get-Content .\autoruns.txt -Encoding ansi | ConvertFrom-Csv -Delimiter "`t")
}

function Get-AutorunsAlternative {
    param (
        [string]$pathToSysinternals = "C:\install\sysinternalssuite",
        [switch]$WithMicrosoftEntries
    )
    # Alternative ohne Start-Process
    if ($WithMicrosoftEntries) {
        # $null (or another variable) is needed to suppress output from the command because of pipeline pollution
        Write-Host "[DEBUG] Starte Autoruns mit Microsoft-Einträgen"
        $null = & "$pathToSysinternals\autorunsc64.exe" -accepteula -a * -ct -nobanner -o "$pathToSysinternals\autoruns.txt"
        return (Get-Content "$pathToSysinternals\autoruns.txt" -Encoding ansi | ConvertFrom-Csv -Delimiter "`t")
    }
    else {
        Write-Host "[DEBUG] Starte Autoruns ohne Microsoft-Einträge"
        $null = & "$pathToSysinternals\autorunsc64.exe" -accepteula -a * -ct -nobanner -m -o "$pathToSysinternals\autoruns.txt"
        return (Get-Content "$pathToSysinternals\autoruns.txt" -Encoding ansi | ConvertFrom-Csv -Delimiter "`t")
    }
}

function Disable-AutorunEntry {
    param($Entry)
    Write-Host("[DEBUG] Deaktiviere Eintrag: $($Entry.Entry) in $($Entry.'Entry Location') (derzeit: $($Entry.Enabled))")
    if ($Entry.Enabled -eq "disabled") {
        Write-Host "[DEBUG] Eintrag ist bereits deaktiviert."
        return
    }
    $loc = $Entry.'Entry Location'
    $valueName = $Entry.Entry

    if ($loc -match '^(HKLM|HKCU)\\') {
        $path = $loc
        $disabledPath = Join-Path $path "AutorunsDisabled"

        if (-not (Test-Path "Registry::$disabledPath")) {
            Write-Host "[DEBUG] Erstelle Unterschlüssel: $disabledPath"
            New-Item -Path "Registry::$disabledPath" -Force | Out-Null
        }

        # Wert auslesen
        $val = Get-ItemPropertyValue -Path "Registry::$path" -Name $valueName -ErrorAction SilentlyContinue
        if ($null -ne $val) {
            $prop = (Get-ItemProperty "Registry::$path").PSObject.Properties[$valueName]
            Write-Host "[DEBUG] Verschiebe Wert '$valueName' von $path → $disabledPath"

            # Kopieren
            New-ItemProperty -Path "Registry::$disabledPath" -Name $valueName -Value $val -PropertyType $prop.Type -Force | Out-Null
            Write-Host "[DEBUG] Neuer Wert in AutorunsDisabled: $valueName = $val"

            # Original löschen
            Remove-ItemProperty -Path "Registry::$path" -Name $valueName -ErrorAction SilentlyContinue

            # Nachkontrolle ohne Fehler
            $check = (Get-ItemProperty -Path "Registry::$path" -ErrorAction SilentlyContinue).PSObject.Properties.Name
            if ($check -notcontains $valueName) {
                Write-Host "[DEBUG] Wert '$valueName' wurde erfolgreich aus $path entfernt."
            }
            else {
                Write-Host "[DEBUG] Achtung: Wert '$valueName' ist noch in $path vorhanden!"
            }
        }
        else {
            Write-Host "[DEBUG] Kein Wert '$valueName' in $path gefunden."
        }
    }
    elseif ($loc -eq 'Task Scheduler') {
        $taskName = $Entry.Entry
        Write-Host "[DEBUG] Deaktiviere geplanten Task: $taskName"
        schtasks /Change /TN "$taskName" /DISABLE | Out-Null
    }
}

function Enable-AutorunEntry {
    param($Entry)
    Write-Host("[DEBUG] Aktiviere Eintrag: $($Entry.Entry) in $($Entry.'Entry Location') (derzeit: $($Entry.Enabled))")
    if ($Entry.Enabled -eq "enabled") {
        Write-Host "[DEBUG] Eintrag ist bereits aktiviert."
        return
    }
    $loc = $Entry.'Entry Location'
    $valueName = $Entry.Entry

    if ($loc -match '^(HKLM|HKCU)\\') {
        $path = $loc
        $disabledPath = Join-Path $path "AutorunsDisabled"

        # Prüfen, ob der Wert im AutorunsDisabled-Ordner existiert
        $props = (Get-ItemProperty -Path "Registry::$disabledPath" -ErrorAction SilentlyContinue).PSObject.Properties.Name
        if ($props -contains $valueName) {
            $val = (Get-ItemProperty -Path "Registry::$disabledPath" -ErrorAction SilentlyContinue).PSObject.Properties[$valueName].Value
            $prop = (Get-ItemProperty "Registry::$disabledPath").PSObject.Properties[$valueName]

            Write-Host "[DEBUG] Verschiebe Wert '$valueName' zurück von $disabledPath → $path"
            New-ItemProperty -Path "Registry::$path" -Name $valueName -Value $val -PropertyType $prop.Type -Force | Out-Null
            Write-Host "[DEBUG] Neuer Wert in $path : $valueName = $val"

            # Aus AutorunsDisabled löschen
            Remove-ItemProperty -Path "Registry::$disabledPath" -Name $valueName -ErrorAction SilentlyContinue

            # Nachkontrolle
            $check = (Get-ItemProperty -Path "Registry::$path" -ErrorAction SilentlyContinue).PSObject.Properties.Name
            if ($check -contains $valueName) {
                Write-Host "[DEBUG] Wert '$valueName' wurde erfolgreich nach $path verschoben."
            }
            else {
                Write-Host "[DEBUG] Achtung Wert '$valueName' konnte nicht nach $path verschoben werden!"
            }
        }
        else {
            Write-Host "[DEBUG] Kein Wert '$valueName' in $disabledPath gefunden."
        }
    }
    elseif ($loc -eq 'Task Scheduler') {
        $taskName = $Entry.Entry
        Write-Host "[DEBUG] Aktiviere geplanten Task $taskName"
        schtasks /Change /TN "$taskName" /ENABLE | Out-Null
    }
}

do {
    $a = Get-Autoruns
    $selection = $a | Out-GridView -Title "Autoruns - Auswahl" -PassThru
    if ($null -eq $selection) { break }

    $action = @("Disable", "Enable", "End programm") | Out-GridView -Title "Choose Action" -PassThru
    switch ($action) {
        "Disable" { Disable-AutorunEntry -Entry $selection }
        "Enable" { Enable-AutorunEntry -Entry $selection }
        "End programm" { break }
    }
}
while ($action -ne "Programm beenden")
