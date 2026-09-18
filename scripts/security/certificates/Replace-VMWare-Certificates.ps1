#requires -Version 7.0
<#
.SYNOPSIS
    Deploys certificates from Generate-Certificate.ps1 to VMware vCenter and ESXi hosts.

.DESCRIPTION
    Takes certificate results from Generate-Certificate.ps1 and deploys them to VMware infrastructure.

    Execution order (safe sequence):
      1. Upload CA chain as trusted certificates to all vCenter servers
      2. Remove expired trusted certificates from all vCenter servers
      3. Replace ESXi host certificates (while vCenter is still operational)
      4. Replace vCenter machine certificates (last, because vCenter restarts)

    vCenter certificates are replaced LAST because the vCenter services restart
    after certificate replacement, which drops the API connection. ESXi hosts are
    done first while the managing vCenter is still fully operational.

    IMPORTANT: This script performs high-impact changes. It uses -WhatIf and
    -Confirm by default. Run with -WhatIf first to review all planned actions.

.PARAMETER CertificateResults
    Array of PSCustomObject from Generate-Certificate.ps1 output.
    Each object must have: HostnameFQDN, CaChainPath, CertificatePath, PrivateKeyPath.

.PARAMETER ConfigPath
    Path to VMware topology config (JSON). Defaults to vmware-config.json in the script directory.
    See vmware-config.example.json for the expected format.

.PARAMETER SkipCaChainUpload
    Skip uploading the CA chain to vCenter trusted stores (use if already done).

.PARAMETER SkipExpiredCleanup
    Skip removal of expired trusted certificates.

.PARAMETER SkipEsxi
    Skip ESXi host certificate replacement. Only process vCenter servers.

.PARAMETER SkipVcenter
    Skip vCenter machine certificate replacement. Only process ESXi hosts.

.EXAMPLE
    $certs = .\Generate-Certificate.ps1
    .\Replace-VMWare-Certificates.ps1 -CertificateResults $certs -WhatIf
    Dry run - shows what would happen without making changes.

.EXAMPLE
    $certs = .\Generate-Certificate.ps1
    .\Replace-VMWare-Certificates.ps1 -CertificateResults $certs
    Full run - prompts for confirmation at each step (ConfirmImpact = High).

.EXAMPLE
    $certs = .\Generate-Certificate.ps1
    .\Replace-VMWare-Certificates.ps1 -CertificateResults $certs -SkipEsxi
    Only replace vCenter machine certificates, skip ESXi hosts.
#>

[CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
param(
    [Parameter(Mandatory)]
    [PSCustomObject[]]$CertificateResults,

    [string]$ConfigPath,

    [switch]$SkipCaChainUpload,
    [switch]$SkipExpiredCleanup,
    [switch]$SkipEsxi,
    [switch]$SkipVcenter
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$script:ScriptDir = if ($PSScriptRoot) { $PSScriptRoot } else { (Get-Location).Path }

#region Validation

if (-not (Get-Module -ListAvailable -Name VMware.VimAutomation.Core)) {
    throw "VMware.VimAutomation.Core module is not installed.`nInstall it with: Install-Module VMware.PowerCLI -Scope CurrentUser"
}
Import-Module VMware.VimAutomation.Core -Force

#endregion

#region Helper Functions

function Find-CertResult {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Hostname,

        [Parameter(Mandatory)]
        [PSCustomObject[]]$Results
    )

    $match = $Results | Where-Object { $_.HostnameFQDN -eq $Hostname }
    if (-not $match) {
        Write-Warning "No certificate found for '$Hostname' in results. Skipping this host."
    }
    $match
}

function Read-CertFiles {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [PSCustomObject]$CertResult
    )

    foreach ($path in @($CertResult.CertificatePath, $CertResult.PrivateKeyPath)) {
        if (-not (Test-Path -LiteralPath $path)) {
            throw "Certificate file not found: $path"
        }
    }

    @{
        CertPem = Get-Content -LiteralPath $CertResult.CertificatePath -Raw
        KeyPem  = Get-Content -LiteralPath $CertResult.PrivateKeyPath -Raw
    }
}

#endregion

# ---- MAIN ----

# Load VMware topology config
if (-not $ConfigPath) {
    $ConfigPath = Join-Path $script:ScriptDir "vmware-config.json"
}

if (-not (Test-Path -LiteralPath $ConfigPath)) {
    throw "VMware config not found: $ConfigPath`nCreate one based on vmware-config.example.json."
}

$vmConfig = Get-Content -LiteralPath $ConfigPath -Raw | ConvertFrom-Json

if (-not $vmConfig.vCenters -or $vmConfig.vCenters.Count -eq 0) {
    throw "No vCenters defined in VMware config."
}

# Locate the CA chain (same CA for all certs, use the first available)
$caChainPath = $CertificateResults[0].CaChainPath
if (-not (Test-Path -LiteralPath $caChainPath)) {
    throw "CA chain file not found: $caChainPath"
}
$caChainPem = Get-Content -LiteralPath $caChainPath -Raw

# ---- Phase 0: Connect to all vCenter servers ----
Write-Host "`n=== Connecting to vCenter servers ===" -ForegroundColor Cyan

$connections = @{}
foreach ($vc in $vmConfig.vCenters) {
    $vcHost = $vc.hostname
    Write-Host "  Connecting to $vcHost..." -ForegroundColor Gray
    $cred = Get-Credential -Message "Credentials for vCenter '$vcHost'"
    $connections[$vcHost] = Connect-VIServer -Server $vcHost -Credential $cred -Force
    Write-Host "  Connected to $vcHost" -ForegroundColor Green
}

try {
    # ---- Phase 1: Add CA chain as trusted certificates ----
    if (-not $SkipCaChainUpload) {
        Write-Host "`n=== Phase 1: Adding CA chain to trusted certificate stores ===" -ForegroundColor Yellow

        foreach ($vc in $vmConfig.vCenters) {
            $vcHost = $vc.hostname
            $conn = $connections[$vcHost]

            if ($PSCmdlet.ShouldProcess($vcHost, "Add CA chain as trusted certificate")) {
                Add-VITrustedCertificate -PemCertificateOrChain $caChainPem -Server $conn
                Write-Host "  CA chain added to $vcHost" -ForegroundColor Green
            }
        }
    }
    else {
        Write-Host "`n=== Phase 1: Skipped CA chain upload (-SkipCaChainUpload) ===" -ForegroundColor Gray
    }

    # ---- Phase 2: Remove expired trusted certificates ----
    if (-not $SkipExpiredCleanup) {
        Write-Host "`n=== Phase 2: Removing expired trusted certificates ===" -ForegroundColor Yellow

        foreach ($vc in $vmConfig.vCenters) {
            $vcHost = $vc.hostname
            $conn = $connections[$vcHost]

            $expired = Get-VITrustedCertificate -VCenterOnly -Server $conn |
                Where-Object { $_.NotValidAfter -lt (Get-Date) }

            if ($expired) {
                Write-Host "  Found $($expired.Count) expired certificate(s) on $vcHost" -ForegroundColor Yellow
                if ($PSCmdlet.ShouldProcess($vcHost, "Remove $($expired.Count) expired trusted certificate(s)")) {
                    $expired | Remove-VITrustedCertificate -Confirm:$false
                    Write-Host "  Expired certificates removed from $vcHost" -ForegroundColor Green
                }
            }
            else {
                Write-Host "  No expired certificates on $vcHost" -ForegroundColor Gray
            }
        }
    }
    else {
        Write-Host "`n=== Phase 2: Skipped expired cert cleanup (-SkipExpiredCleanup) ===" -ForegroundColor Gray
    }

    # ---- Phase 3: Replace ESXi host certificates (BEFORE vCenter) ----
    if (-not $SkipEsxi) {
        Write-Host "`n=== Phase 3: Replacing ESXi host certificates ===" -ForegroundColor Yellow

        foreach ($vc in $vmConfig.vCenters) {
            $vcHost = $vc.hostname
            $conn = $connections[$vcHost]
            $managedHosts = @($vc.managedHosts)

            if ($managedHosts.Count -eq 0) {
                Write-Host "  No managed ESXi hosts configured for $vcHost" -ForegroundColor Gray
                continue
            }

            foreach ($esxiHostname in $managedHosts) {
                $certResult = Find-CertResult -Hostname $esxiHostname -Results $CertificateResults
                if (-not $certResult) { continue }

                $files = Read-CertFiles -CertResult $certResult

                if ($PSCmdlet.ShouldProcess($esxiHostname, "Replace ESXi certificate (maintenance mode on/off, managed by $vcHost)")) {
                    $vmhost = VMware.VimAutomation.Core\Get-VMHost -Name $esxiHostname -Server $conn

                    Write-Host "  Entering maintenance mode: $esxiHostname" -ForegroundColor Yellow
                    VMware.VimAutomation.Core\Set-VMHost -VMHost $vmhost -State Maintenance

                    $targetHost = VMware.VimAutomation.Core\Get-VMHost $vmhost.Name -Server $conn
                    Set-VIMachineCertificate -VMHost $targetHost -PemCertificate $files.CertPem -PemKey $files.KeyPem -Server $conn
                    Write-Host "  Certificate replaced on $esxiHostname" -ForegroundColor Green

                    Write-Host "  Exiting maintenance mode: $esxiHostname" -ForegroundColor Yellow
                    VMware.VimAutomation.Core\Set-VMHost -VMHost $vmhost -State Connected

                    Write-Host "  ESXi host $esxiHostname completed." -ForegroundColor Green
                }
            }
        }
    }
    else {
        Write-Host "`n=== Phase 3: Skipped ESXi host replacement (-SkipEsxi) ===" -ForegroundColor Gray
    }

    # ---- Phase 4: Replace vCenter machine certificates (LAST) ----
    if (-not $SkipVcenter) {
        Write-Host "`n=== Phase 4: Replacing vCenter machine certificates ===" -ForegroundColor Yellow
        Write-Host "  NOTE: vCenter services restart after certificate replacement." -ForegroundColor Yellow

        foreach ($vc in $vmConfig.vCenters) {
            $vcHost = $vc.hostname
            $conn = $connections[$vcHost]

            $certResult = Find-CertResult -Hostname $vcHost -Results $CertificateResults
            if (-not $certResult) { continue }

            $files = Read-CertFiles -CertResult $certResult

            Write-Host "  Current machine certificate for ${vcHost}:" -ForegroundColor Gray
            Get-VIMachineCertificate -VCenterOnly -Server $conn

            if ($PSCmdlet.ShouldProcess($vcHost, "Replace vCenter machine certificate (services will restart)")) {
                Set-VIMachineCertificate -PemCertificate $files.CertPem -PemKey $files.KeyPem -Server $conn
                Write-Host "  Machine certificate replaced on $vcHost" -ForegroundColor Green
            }
        }
    }
    else {
        Write-Host "`n=== Phase 4: Skipped vCenter replacement (-SkipVcenter) ===" -ForegroundColor Gray
    }

    Write-Host "`n=== All operations completed ===" -ForegroundColor Green
}
finally {
    # Always disconnect from vCenter servers
    Write-Host "`nDisconnecting from vCenter servers..." -ForegroundColor Gray
    foreach ($conn in $connections.Values) {
        Disconnect-VIServer -Server $conn -Confirm:$false -ErrorAction SilentlyContinue
    }
}
