# Old Version of Elevate.ps1
# This script is used to run a PowerShell script with elevated privileges using a batch file.
<#
.SYNOPSIS
    Elevate a PowerShell script to run with administrative privileges using a batch file.
.DESCRIPTION
    This script creates a temporary batch file that runs a PowerShell command with elevated privileges.
    It uses the `runas` command to execute the batch file as a specified user. 
    The batch file is created in the Common Application Data folder to ensure it is accessible.
.PARAMETER User
    The user account under which the batch file will be executed. This should be in the format 'DOMAIN\Username'.
.EXAMPLE
    Invoke-RunAsBatch -User 'MYDOMAIN\MYUSER'
    This example runs the batch file as the specified user, which will start a new PowerShell session with elevated privileges.
.NOTES
    This script requires PowerShell to be run with sufficient permissions to create and execute batch files.
#>
# Requires -Version 5.1
<#
    .NOTES
    This script is designed to be run in a PowerShell environment with administrative privileges.
    It creates a batch file that, when executed, will start a new PowerShell session with elevated privileges.
    The batch file is created in the Common Application Data folder to ensure it is accessible to all users on the system.
    The script uses the `runas` command to execute the batch file as a specified user, allowing for elevation of privileges.
    The user must provide the username in the format 'DOMAIN\Username'.
#>

function Invoke-RunAsBatch {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$User
    )
    # Befehl zum Ausführen der Batch-Datei
    $Content = @'
start "Start Powershell Elevated" pwsh -ExecutionPolicy Bypass -NoProfile -Command "& { Start-Process pwsh -Verb RunAs }"
'@

    $File = Join-Path ([Environment]::GetFolderPath('CommonApplicationData')) "elevate.bat"
    #$File = Join-Path $env:TEMP "elevate_$([guid]::NewGuid()).bat"
    Set-Content -Path $file -Value $Content -Force
    Write-Host $file
    Write-Host $BatchFile

    # kurz warten, bis die Datei angelegt wurde
    Start-Sleep -Seconds 1
    if (-not (Test-Path $file)) {
        throw "Temp-Batch-Datei wurde nicht gefunden: $file"
    }
    $BatchFile = $File
    $cmd = "cmd.exe /C `"$BatchFile`""
    # runas starten
    $proc = Start-Process runas.exe -ArgumentList "/user:$User `"$cmd`"" -PassThru -Wait

    # Ergebnis zurückgeben
    [PSCustomObject]@{
        User      = $User
        BatchFile = $BatchFile
        ExitCode  = $proc.ExitCode
        StartedAt = (Get-Date)
    }
}

function elevate {
    Invoke-RunAsBatch -User 'MYDOMAIN\MYUSER' | Out-Null
}

# Beispielaufruf:
# Invoke-RunAsBatch -User 'MYDOMAIN\MYUSER' | Out-Null
# elevate