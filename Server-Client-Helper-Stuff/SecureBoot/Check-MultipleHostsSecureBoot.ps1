function Test-ConnectionInParallel {
    # Only Powershell 6 and above (because of ForEach-Object -Parallel)
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $false, Position = 0)]
        [string[]]$ComputerNames,
        [Parameter(Mandatory = $false)]
        [int]$throttlelimit = 10
    )
    $ComputerNames | ForEach-Object -Parallel {
        Write-Progress -Activity "Checking computer online status" -Status "$_"
        [pscustomobject]@{ComputerName = $_; Online = Test-Connection -ComputerName $_ -Count 1 -Quiet -TimeoutSeconds 1; IP = (Test-Connection -ComputerName $_ -Count 1 -TimeoutSeconds 1 -ErrorAction SilentlyContinue).Address.IPAddressToString }
    } -ThrottleLimit $throttlelimit
}

# 1. Computer-Objekte aus AD abrufen
$adComputers = Get-ADComputer -Filter 'OperatingSystem -like "*Windows Server*" -and Enabled -eq $true' -Properties LastLogonDate, OperatingSystem
# 2. Online-Status der Computer prüfen
$OnlineComputers = Test-ConnectionInParallel -throttlelimit 20 -ComputerNames $adComputers.DNSHostName | Where-Object { $_.Online }
$TargetHosts = $OnlineComputers.ComputerName

#3. Skript auf den Zielhosts ausführen
$ScriptContent = Get-Content ".\Invoke-SecureBootCertUpdate.ps1" -Raw
$FinalResults = Invoke-Command -ComputerName $TargetHosts -ScriptBlock {
    $sbi = [scriptblock]::Create($using:ScriptContent)
    # Ausführung mit -Status, damit nur geprüft, aber nichts verändert wird
    & $sbi -Status
} -ErrorAction SilentlyContinue
$FinalResults | Out-GridView