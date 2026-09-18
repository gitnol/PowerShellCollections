<#
.SYNOPSIS
Setzt Prozesspriorität per Name oder PID

Um es zu kompilieren, nutze PS2EXE:
Install-Module PS2EXE -Scope CurrentUser
Invoke-PS2EXE -inputFile "G:\AVERP\Set-ProcPriority.ps1" -outputFile "G:\AVERP\Set-ProcPriority.exe" -noConsole
\\myserver\myshare\Set-ProcPriority.exe -Name MYPROCESS -Priority AboveNormal
#>
param(
    [string]$Name,
    [int]$ProcId,
    [ValidateSet('Normal', 'BelowNormal', 'AboveNormal', 'High')]
    [string]$Priority = 'AboveNormal'
)

if ($ProcId) {
    $procs = Get-Process -Id $ProcId -ErrorAction SilentlyContinue
}
elseif ($Name) {
    $procs = Get-Process -Name $Name -ErrorAction SilentlyContinue
}
else {
    return
}

foreach ($p in $procs) {
    try {
        $p.PriorityClass = $Priority
        # [PSCustomObject]@{
        # PID      = $p.Id
        # Name     = $p.ProcessName
        # Priority = $p.PriorityClass
        # Success  = $true
        # }
    }
    catch {
        # [PSCustomObject]@{
        # PID      = $p.Id
        # Name     = $p.ProcessName
        # Priority = $Priority
        # Success  = $false
        # }
    }
}