#requires -Version 7.0
<#
.SYNOPSIS
    Requests certificates from ADCS, exports PFX to PEM, splits key/cert, and writes CA chain.

.DESCRIPTION
    Operates in two modes:
    - Config mode (default): Reads certificate definitions from a JSON config file.
    - Single mode: Generates one certificate from command-line parameters.

    Requires the PSPKI module (auto-installed if missing) and Request-Certificate.ps1 in the same directory.

.PARAMETER ConfigPath
    Path to a JSON configuration file. Defaults to config.json in the script directory.
    See config.example.json for the expected format.

.PARAMETER HostnameFQDN
    FQDN for the certificate subject (single-cert mode).

.PARAMETER SanDns
    Additional DNS subject alternative names.

.PARAMETER SanIpAddress
    IP address subject alternative names.

.PARAMETER TemplateName
    CA certificate template name. Default: Webserver

.PARAMETER Department
    OU field for the certificate subject. Default: IT

.PARAMETER Country
    C field for the certificate subject. Default: DE

.PARAMETER ExportPath
    Directory for exported certificate files. Default: C:\temp\certs

.PARAMETER ExportPassword
    Password for PFX export. If omitted, you will be prompted securely.

.EXAMPLE
    .\Generate-Certificate.ps1
    Reads config.json from the script directory and generates certificates for all entries.

.EXAMPLE
    .\Generate-Certificate.ps1 -ConfigPath .\myconfig.json

.EXAMPLE
    .\Generate-Certificate.ps1 -HostnameFQDN "server.mycorp.local" -SanDns "server","server.mycorp.local" -SanIpAddress "10.0.1.5"
    Generates a single certificate with DNS and IP SANs. Prompts for export password.

.EXAMPLE
    .\Generate-Certificate.ps1 -HostnameFQDN "server.mycorp.local" -ExportPassword "mypass" -TemplateName "CustomTemplate"
    Generates a single certificate with a custom template and explicit password.
#>

[CmdletBinding(DefaultParameterSetName = 'Config')]
param(
    [Parameter(ParameterSetName = 'Config')]
    [string]$ConfigPath,

    [Parameter(Mandatory, ParameterSetName = 'Single')]
    [string]$HostnameFQDN,

    [Parameter(ParameterSetName = 'Single')]
    [string[]]$SanDns = @(),

    [Parameter(ParameterSetName = 'Single')]
    [string[]]$SanIpAddress = @(),

    [Parameter(ParameterSetName = 'Single')]
    [string]$TemplateName,

    [Parameter(ParameterSetName = 'Single')]
    [string]$Department,

    [Parameter(ParameterSetName = 'Single')]
    [string]$Country,

    [Parameter(ParameterSetName = 'Single')]
    [string]$ExportPath,

    [Parameter(ParameterSetName = 'Single')]
    [string]$ExportPassword
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$script:ScriptDir = if ($PSScriptRoot) { $PSScriptRoot } else { (Get-Location).Path }
$script:Defaults = @{
    TemplateName = "Webserver"
    Department   = "IT"
    Country      = "DE"
    ExportPath   = "C:\temp\certs"
}

#region Helper Functions

function Ensure-Module {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Name
    )
    if (-not (Get-Module -ListAvailable -Name $Name)) {
        Write-Host "Installing module $Name..." -ForegroundColor Yellow
        Install-Module -Name $Name -Scope CurrentUser -Force
    }
    Import-Module -Name $Name -Force
}

function Read-ExportPassword {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Hostname
    )
    $secure = Read-Host -Prompt "Export password for '$Hostname'" -AsSecureString
    [System.Net.NetworkCredential]::new('', $secure).Password
}

function Export-CertificateChain {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$PfxPath,

        [Parameter(Mandatory)]
        [string]$OutputPath,

        [string]$Password,

        [switch]$CaOnly
    )

    if (Test-Path -LiteralPath $OutputPath) {
        Remove-Item -LiteralPath $OutputPath -Force
    }

    $pfx = [System.Security.Cryptography.X509Certificates.X509Certificate2]::new(
        $PfxPath,
        $Password,
        [System.Security.Cryptography.X509Certificates.X509KeyStorageFlags]::Exportable
    )

    $chain = [System.Security.Cryptography.X509Certificates.X509Chain]::new()
    $built = $chain.Build($pfx)

    if (-not $built) {
        foreach ($status in $chain.ChainStatus) {
            Write-Warning "Chain validation: $($status.StatusInformation.Trim())"
        }
    }

    $lines = [System.Collections.Generic.List[string]]::new()
    foreach ($element in $chain.ChainElements) {
        if ($CaOnly -and $element.Certificate.Thumbprint -eq $pfx.Thumbprint) { continue }
        $lines.Add("-----BEGIN CERTIFICATE-----")
        $b64 = [Convert]::ToBase64String($element.Certificate.RawData)
        for ($i = 0; $i -lt $b64.Length; $i += 64) {
            $lines.Add($b64.Substring($i, [Math]::Min(64, $b64.Length - $i)))
        }
        $lines.Add("-----END CERTIFICATE-----")
    }

    Set-Content -LiteralPath $OutputPath -Value ($lines -join "`r`n") -Encoding ascii
}

function Split-Pem {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$PemPath,

        [Parameter(Mandatory)]
        [string]$OutPrivateKeyPath,

        [Parameter(Mandatory)]
        [string]$OutCertPath
    )

    $raw = Get-Content -LiteralPath $PemPath -Raw

    if ($raw -notmatch "(?ms)(?<privatekey>-----BEGIN [\w ]*PRIVATE KEY-----.*?-----END [\w ]*PRIVATE KEY-----)") {
        throw "PEM file does not contain a private key block: $PemPath"
    }
    $privateKey = $Matches["privatekey"]

    if ($raw -notmatch "(?ms)(?<certificate>-----BEGIN CERTIFICATE-----.*?-----END CERTIFICATE-----)") {
        throw "PEM file does not contain a certificate block: $PemPath"
    }
    $certificate = $Matches["certificate"]

    Set-Content -LiteralPath $OutPrivateKeyPath -Value $privateKey -Encoding ascii
    Set-Content -LiteralPath $OutCertPath -Value $certificate -Encoding ascii
}

function New-SanString {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$CN,

        [string[]]$Dns = @(),
        [string[]]$IpAddress = @()
    )

    $dnsAll = @($CN) + $Dns | Where-Object { $_ } | Select-Object -Unique
    $ipAll = $IpAddress | Where-Object { $_ } | Select-Object -Unique

    $parts = [System.Collections.Generic.List[string]]::new()
    foreach ($d in $dnsAll) { $parts.Add("DNS=$d") }
    foreach ($ip in $ipAll) { $parts.Add("IPAddress=$ip") }

    $parts -join ","
}

function New-Certificate {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$HostnameFQDN,

        [Parameter(Mandatory)]
        [string]$ExportPassword,

        [string[]]$SanDns = @(),
        [string[]]$SanIpAddress = @(),

        [string]$TemplateName = "Webserver",
        [string]$Department = "IT",
        [string]$Country = "DE",
        [string]$ExportPath = "C:\temp\certs"
    )

    if (-not (Test-Path -LiteralPath $ExportPath)) {
        New-Item -ItemType Directory -Path $ExportPath -Force | Out-Null
    }

    $reqScript = Join-Path $script:ScriptDir "Request-Certificate.ps1"
    if (-not (Test-Path -LiteralPath $reqScript)) {
        throw "Request-Certificate.ps1 not found at: $reqScript"
    }

    $friendlyName = "${HostnameFQDN}_$(Get-Date -Format 'yyyyMMdd-HHmmss')"
    $san = New-SanString -CN $HostnameFQDN -Dns $SanDns -IpAddress $SanIpAddress

    $pfxFile   = Join-Path $ExportPath "$HostnameFQDN.pfx"
    $pemFile   = Join-Path $ExportPath "$friendlyName.pem"
    $chainFile = Join-Path $ExportPath "${friendlyName}_ca_chain.pem"
    $certFile  = Join-Path $ExportPath "${friendlyName}_certificate.pem"
    $keyFile   = Join-Path $ExportPath "${friendlyName}_privatekey.pem"

    Write-Host "Requesting certificate for $HostnameFQDN (SAN: $san)..." -ForegroundColor Cyan

    & $reqScript `
        -CN $HostnameFQDN `
        -SAN $san `
        -Country $Country `
        -Organisation $HostnameFQDN `
        -Department $Department `
        -FriendlyName $friendlyName `
        -AddCNinSAN `
        -Export `
        -ExportPath $ExportPath `
        -Password $ExportPassword `
        -TemplateName $TemplateName

    if (-not (Test-Path -LiteralPath $pfxFile)) {
        throw "PFX was not created: $pfxFile"
    }

    $pwSecure = ConvertTo-SecureString -String $ExportPassword -AsPlainText -Force
    Convert-PfxToPem -InputFile $pfxFile -OutputFile $pemFile -Password $pwSecure

    if (-not (Test-Path -LiteralPath $pemFile)) {
        throw "PEM conversion failed: $pemFile"
    }

    Export-CertificateChain -PfxPath $pfxFile -OutputPath $chainFile -Password $ExportPassword -CaOnly
    Split-Pem -PemPath $pemFile -OutPrivateKeyPath $keyFile -OutCertPath $certFile

    Write-Host "Certificate for $HostnameFQDN created successfully." -ForegroundColor Green

    [PSCustomObject]@{
        HostnameFQDN    = $HostnameFQDN
        SAN             = $san
        FriendlyName    = $friendlyName
        PfxPath         = $pfxFile
        PemPath         = $pemFile
        CaChainPath     = $chainFile
        CertificatePath = $certFile
        PrivateKeyPath  = $keyFile
    }
}

#endregion

#region Helpers for config resolution

function Resolve-Value {
    param($Value, $Default)
    if ($Value) { $Value } else { $Default }
}

#endregion

# ---- MAIN ----
Ensure-Module -Name "PSPKI"

if ($PSCmdlet.ParameterSetName -eq 'Config') {
    if (-not $ConfigPath) {
        $ConfigPath = Join-Path $script:ScriptDir "config.json"
    }

    if (-not (Test-Path -LiteralPath $ConfigPath)) {
        throw "Config file not found: $ConfigPath`nCreate one based on config.example.json or use -HostnameFQDN for single-cert mode."
    }

    $config = Get-Content -LiteralPath $ConfigPath -Raw | ConvertFrom-Json

    # Merge config defaults with built-in defaults
    $defaults = $script:Defaults.Clone()
    if ($config.defaults) {
        foreach ($prop in $config.defaults.PSObject.Properties) {
            $defaults[$prop.Name] = $prop.Value
        }
    }

    if (-not $config.certificates -or $config.certificates.Count -eq 0) {
        throw "No certificates defined in config file."
    }

    $results = foreach ($cert in $config.certificates) {
        $pw = $cert.exportPassword
        if (-not $pw) {
            $pw = Read-ExportPassword -Hostname $cert.hostnameFQDN
        }

        New-Certificate `
            -HostnameFQDN $cert.hostnameFQDN `
            -ExportPassword $pw `
            -SanDns @($cert.sanDns ?? @()) `
            -SanIpAddress @($cert.sanIpAddress ?? @()) `
            -TemplateName (Resolve-Value $cert.templateName $defaults.TemplateName) `
            -Department (Resolve-Value $cert.department $defaults.Department) `
            -Country (Resolve-Value $cert.country $defaults.Country) `
            -ExportPath (Resolve-Value $cert.exportPath $defaults.ExportPath)
    }

    $results
}
else {
    # Single-cert mode
    if (-not $ExportPassword) {
        $ExportPassword = Read-ExportPassword -Hostname $HostnameFQDN
    }

    New-Certificate `
        -HostnameFQDN $HostnameFQDN `
        -ExportPassword $ExportPassword `
        -SanDns $SanDns `
        -SanIpAddress $SanIpAddress `
        -TemplateName (Resolve-Value $TemplateName $script:Defaults.TemplateName) `
        -Department (Resolve-Value $Department $script:Defaults.Department) `
        -Country (Resolve-Value $Country $script:Defaults.Country) `
        -ExportPath (Resolve-Value $ExportPath $script:Defaults.ExportPath)
}
