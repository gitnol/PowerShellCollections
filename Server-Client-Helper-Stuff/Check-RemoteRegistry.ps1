function Test-RemoteRegistryPrerequisites {
    param (
        [Parameter(Mandatory)]
        [string]$ComputerName
    )

    $results = [PSCustomObject]@{
        ComputerName                 = $ComputerName
        RemoteRegistryServiceRunning = $false
        FirewallRulesConfigured      = $false
        NetworkReachable             = $false
        UserHasAdminRights           = $false
    }

    # Test Netzwerkverbindung
    if (Test-Connection -ComputerName $ComputerName -Count 1 -Quiet) {
        $results.NetworkReachable = $true
    }

    # Remote Registry Dienst prüfen
    try {
        $service = Get-CimInstance -ClassName Win32_Service -ComputerName $ComputerName -Filter "Name='RemoteRegistry'"
        if ($service.State -eq 'Running') {
            $results.RemoteRegistryServiceRunning = $true
        }
    }
    catch {
        Write-Error "Fehler beim Abrufen des Dienstes auf $ComputerName $_"
    }

    # Firewall-Regeln prüfen
    try {
        $firewallRules = Get-CimInstance -Namespace "root/StandardCimv2" -ClassName MSFT_NetFirewallRule -ComputerName $ComputerName |
        Where-Object { $_.DisplayName -match 'Windows-Verwaltungsinstrumentation|Remoteverwaltung|RPC' -and $_.Enabled -eq $true }
        if ($firewallRules) {
            $results.FirewallRulesConfigured = $true
        }
    }
    catch {
        Write-Error "Fehler beim Überprüfen der Firewall-Regeln auf $ComputerName $_"
    }

    # Adminrechte prüfen
    try {
        $adminCheck = Invoke-Command -ComputerName $ComputerName -ScriptBlock {
            $user = [System.Security.Principal.WindowsIdentity]::GetCurrent()
            $principal = New-Object System.Security.Principal.WindowsPrincipal($user)
            $principal.IsInRole([System.Security.Principal.WindowsBuiltInRole]::Administrator)
        }
        if ($adminCheck -eq $true) {
            $results.UserHasAdminRights = $true
        }
    }
    catch {
        Write-Error "Fehler beim Überprüfen der Administratorrechte auf $ComputerName $_"
    }

    return $results
}

function Ensure-RemoteRegistryService {
    param (
        [Parameter(Mandatory)]
        [string]$ComputerName
    )

    try {
        # RemoteRegistry-Dienst abrufen
        $service = Get-CimInstance -ClassName Win32_Service -ComputerName $ComputerName -Filter "Name='RemoteRegistry'"

        # Starttyp auf Automatisch setzen, wenn nicht bereits konfiguriert
        if ($service.StartMode -ne 'Auto') {
            Set-CimInstance -InputObject $service -Property @{ StartMode = 'Auto' }
            Write-Output "Starttyp des Dienstes 'RemoteRegistry' auf 'Automatisch' gesetzt."
        }

        # Dienst starten, wenn er nicht läuft
        if ($service.State -ne 'Running') {
            Invoke-CimMethod -InputObject $service -MethodName StartService
            Write-Output "Dienst 'RemoteRegistry' wurde gestartet."
        }
        else {
            Write-Output "Dienst 'RemoteRegistry' läuft bereits."
        }
    }
    catch {
        Write-Error "Fehler beim Konfigurieren des RemoteRegistry-Dienstes auf $ComputerName : $_"
    }
}

# Beispielaufruf
$computerName = "905785-D"
$result = Test-RemoteRegistryPrerequisites -ComputerName $computerName
$result | Format-Table -AutoSize

Ensure-RemoteRegistryService -ComputerName $computerName
