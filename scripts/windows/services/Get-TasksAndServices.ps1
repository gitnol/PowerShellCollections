Import-Module ActiveDirectory
# make sure, that you have sufficient rights on the target machine
$credentials = Get-Credential -Message "Input Credentials with administrative priviledges on all PCs"

# used to filter the output to users from this domain
$domainname = "*mycorp.local*"

# max number for invoking commands to remote PCs.
$throttleLimit = 20

# max number of machines queried by this script
$limitToHowManyDomainComputers = 9999

# Variable to store all tasks and their configuration on all machines
$alletasks = @()
# Filename for storing the information after everything has been gathered
$alletasks_exportfile = 'C:\install\alle_tasks_aller_rechner.txt'

# Variable to store all services and their configuration on all machines
$alledienste = @()
# Filename for storing the information after everything has been gathered
$alledienste_exportfile = 'C:\install\alle_dienste_aller_rechner.txt'

# ScriptBlock um die Tasks / Aufgaben zu erfassen
[scriptblock]$meinScriptBlockTasks = {
    # Prüfen, ob das Skript mit administrativen Rechten läuft
    $adminCheck = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator") 

    if (-not $adminCheck) {
        Write-Host "Dieses Skript muss mit administrativen Rechten ausgeführt werden!" -ForegroundColor Red 
    } else {
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
                [PSCustomObject]@{
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
    }
}

# ScriptBlock um die Dienste zu erfassen
[scriptblock]$meinScriptBlockDienste = {
    Get-CimInstance -ClassName Win32_Service | ForEach-Object { 
        [PSCustomObject]@{
            computername = $env:COMPUTERNAME
            Name         = $_.Name
            Caption      = $_.Caption
            Started      = $_.Started
            StartName    = $_.StartName
            Description  = $_.Description
        }
    }
}

# Examples
# $computers = (Get-ADComputer -SearchBase 'DC=mycorp,dc=local' -Filter '*' | select -First 70) # Zum Testen
# $computers = (Get-ADComputer -Filter '*' | Select-Object -First 10) # Bitte Domänenstring anpassen

# Get all enabled AD Windows Computers, which are currently online
$computers = Get-ADComputer -Filter '*' -Properties DNSHostName,Enabled,OperatingSystem | Where-Object {$_.Enabled -eq $True -and $_.OperatingSystem -like "*Windows*"} | Select-Object -First $limitToHowManyDomainComputers | ForEach-Object -Parallel {
    Write-Progress -Activity "Checking computer online status: " -Status $_.DNSHostName
    if(Test-Connection -ComputerName $_.DNSHostName -Count 1 -Quiet -TimeoutSeconds 1){$_.DNSHostName}
}

# Query all tasks on all machines
$alletasks += Invoke-Command -ComputerName ($computers | Where-Object {$_}) -ThrottleLimit $throttleLimit -ScriptBlock $meinScriptBlockTasks -Credential $credentials
# Query all services on all machines
$alledienste += Invoke-Command -ComputerName ($computers | Where-Object {$_}) -ThrottleLimit $throttleLimit -ScriptBlock $meinScriptBlockDienste -Credential $credentials

# get all computer monitor. see Get-ClientMonitorEDIDData.ps1
# $allemonitore = @()
# $allemonitore_exportfile = 'C:\install\alle_monitore_aller_rechner.txt'
# $allemonitore += Invoke-Command -ComputerName ($computers | Where-Object {$_}) -ThrottleLimit $throttleLimit -ScriptBlock (Get-Command Get-ClientMonitorEDIDData).ScriptBlock -Credential $credentials
# $allemonitore | ConvertTo-Json | Out-File -FilePath $allemonitore_exportfile

$alletasks | ConvertTo-Json | Out-File -FilePath $alletasks_exportfile
$alledienste | ConvertTo-Json | Out-File -FilePath $alledienste_exportfile

# Example to see all task users (with the domain mycorp) on all machines currently online!
$alletasks | Where-Object {$_.User -like $domainname}  | Format-Table

# Example to see all tasks executed with powershell on all machines currently online!
$alletasks | Where-Object {$_.Program -like "*powershell*" -or $_.Program -like "*pwsh*"}  | Out-GridView -Title "Tasks with powershell or pwsh"

# Example to see all service users (with the domain mycorp) on all machines currently online!
$alledienste | Where-Object {$_.StartName -like $domainname} | Sort-Object -Property StartName,Started | Format-Table
