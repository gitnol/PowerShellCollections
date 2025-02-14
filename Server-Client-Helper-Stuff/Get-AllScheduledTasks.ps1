$OutGridViewOutput = $false # Set to $false, if there is something being automated... 
$jsonExport = $true
$jsonExportPath = "c:\install\Tasks_" + $env:COMPUTERNAME + ".json"
$pipelineoutput = $true

# Prüfen, ob das Skript mit administrativen Rechten läuft
$adminCheck = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator") 

if (-not $adminCheck) {
    Write-Host "Dieses Skript muss mit administrativen Rechten ausgeführt werden!" -ForegroundColor Red 
} else {
    $erg = @()
    # Falls der Benutzer Admin ist, werden die Scheduled Tasks ausgelesen
    Get-ScheduledTask | ForEach-Object {
        $taskName = $_.TaskName
        $taskPath = $_.TaskPath
        $description = $_.Description
        $principal = $_.Principal.UserId
        $logonType = $_.Principal.LogonType
        $runLevel = $_.Principal.RunLevel
        $_.Actions | ForEach-Object {
            $program = $_.Execute
            $arguments = $_.Arguments
            $workingdirectory = $_.WorkingDirectory
            $erg += [PSCustomObject]@{
                User             = $principal
                LogonType        = $logonType
                RunLevel         = $runLevel
                TaskName         = $taskName
                Program          = $program
                Arguments        = $arguments
                WorkingDirectory = $workingdirectory
                TaskPath         = $taskPath
                Description      = $description
            }
        }
    } 
    if ($jsonExport -eq $true) {
        $erg | ConvertTo-Json -Depth 20 | Out-File -FilePath $jsonExportPath -Force
        Write-Host "File Exported to $jsonExportPath" -ForegroundColor Green
    }
    if ($OutGridViewOutput -eq $true) {
        $erg | Out-GridView -Title "Scheduled Tasks" -OutputMode Multiple
    }

    if ($pipelineoutput -eq $true) {
        $erg
    }
}
