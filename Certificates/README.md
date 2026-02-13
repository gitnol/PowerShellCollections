# Certificates - ADCS Certificate Generation Toolkit

Requests certificates from an Active Directory Certificate Services (ADCS) CA, exports them as PFX, converts to PEM, and splits into individual key/cert/chain files ready for use in web servers, VMware, or any other service.

## Prerequisites

- **PowerShell 7.0+**
- **PSPKI module** - auto-installed on first run if missing
- **Active Directory Certificate Services (ADCS)** - an enterprise CA reachable from the machine
- **Admin privileges** - `certreq.exe` needs to access the local machine certificate store

## Files

| File | Description |
|------|-------------|
| `Generate-Certificate.ps1` | Main script - orchestrates the full workflow |
| `Request-Certificate.ps1` | Low-level ADCS request via `certreq.exe` (by [J0F3](https://github.com/J0F3/PowerShell), modded for PS7) |
| `config.json` | Your local certificate definitions (gitignored) |
| `config.example.json` | Example config with the expected JSON schema |

## Workflow

```
Generate-Certificate.ps1
        |
        |  1. Reads config.json (or CLI parameters)
        |  2. For each certificate:
        |
        v
Request-Certificate.ps1          (certreq.exe -> ADCS CA)
        |
        |  3. Produces: <hostname>.pfx
        v
Convert-PfxToPem (PSPKI)         (PFX -> PEM with key + cert)
        |
        |  4. Produces: <friendlyname>.pem
        v
Export-CertificateChain           (PFX -> CA chain PEM)
Split-Pem                         (PEM -> separate key + cert files)
        |
        |  5. Final output files:
        v
  <friendlyname>_privatekey.pem   (private key only)
  <friendlyname>_certificate.pem  (host certificate only)
  <friendlyname>_ca_chain.pem     (intermediate + root CA certs)
  <friendlyname>.pem              (combined key + cert)
  <hostname>.pfx                  (PKCS#12 archive)
```

## Usage

### Mode 1: Config file (batch - recommended)

Generate certificates for multiple hosts defined in a JSON config file.

```powershell
# Uses config.json in the script directory by default
.\Generate-Certificate.ps1

# Or specify a custom config path
.\Generate-Certificate.ps1 -ConfigPath .\my-environment.json
```

You will be prompted for each certificate's export password (unless set in config).

### Mode 2: Single certificate (CLI parameters)

Generate one certificate directly from the command line.

```powershell
# Minimal - prompts for password, uses all defaults
.\Generate-Certificate.ps1 -HostnameFQDN "webserver.mycorp.local"

# With DNS SANs
.\Generate-Certificate.ps1 -HostnameFQDN "webserver.mycorp.local" `
    -SanDns "webserver","www.mycorp.local"

# With DNS + IP SANs and explicit password
.\Generate-Certificate.ps1 -HostnameFQDN "webserver.mycorp.local" `
    -SanDns "webserver","www.mycorp.local" `
    -SanIpAddress "10.0.1.50" `
    -ExportPassword "MyP@ssw0rd"

# Override all defaults
.\Generate-Certificate.ps1 -HostnameFQDN "webserver.mycorp.local" `
    -SanDns "webserver" `
    -TemplateName "CustomWebTemplate" `
    -Department "Engineering" `
    -Country "AT" `
    -ExportPath "D:\certs\output"
```

### Working with the output

The script returns a `PSCustomObject` per certificate, so you can pipe or store results:

```powershell
# Store results for further processing
$certs = .\Generate-Certificate.ps1

# Show all generated file paths
$certs | Format-List

# Example output:
# HostnameFQDN    : webserver.mycorp.local
# SAN             : DNS=webserver.mycorp.local,DNS=webserver,IPAddress=10.0.1.50
# FriendlyName    : webserver.mycorp.local_20250213-143022
# PfxPath         : C:\temp\certs\webserver.mycorp.local.pfx
# PemPath         : C:\temp\certs\webserver.mycorp.local_20250213-143022.pem
# CaChainPath     : C:\temp\certs\webserver.mycorp.local_20250213-143022_ca_chain.pem
# CertificatePath : C:\temp\certs\webserver.mycorp.local_20250213-143022_certificate.pem
# PrivateKeyPath  : C:\temp\certs\webserver.mycorp.local_20250213-143022_privatekey.pem

# Use in downstream scripts (e.g. VMware certificate replacement)
foreach ($cert in $certs) {
    $certPem = Get-Content $cert.CertificatePath -Raw
    $keyPem  = Get-Content $cert.PrivateKeyPath -Raw
    # ... apply to target system
}
```

## Config file format

Create your `config.json` based on `config.example.json`:

```json
{
  "defaults": {
    "templateName": "Webserver",
    "department": "IT",
    "country": "DE",
    "exportPath": "C:\\temp\\certs"
  },
  "certificates": [
    {
      "hostnameFQDN": "myserver.mycorp.local",
      "sanDns": ["myserver", "myserver.mycorp.local"],
      "sanIpAddress": ["10.0.5.170"],
      "exportPassword": null
    },
    {
      "hostnameFQDN": "webapp.mycorp.local",
      "sanDns": ["webapp"],
      "sanIpAddress": [],
      "templateName": "CustomWebTemplate",
      "exportPassword": null
    }
  ]
}
```

### Config reference

#### `defaults` section

Global defaults applied to every certificate unless overridden per entry.

| Property | Default | Description |
|----------|---------|-------------|
| `templateName` | `Webserver` | ADCS certificate template name |
| `department` | `IT` | OU field in the certificate subject |
| `country` | `DE` | C field in the certificate subject |
| `exportPath` | `C:\temp\certs` | Output directory for all generated files |

#### `certificates[]` entries

| Property | Required | Description |
|----------|----------|-------------|
| `hostnameFQDN` | **yes** | FQDN used as CN and Organisation in the certificate subject |
| `sanDns` | no | Array of additional DNS SANs (the CN is always included automatically) |
| `sanIpAddress` | no | Array of IP address SANs |
| `templateName` | no | Override the default template for this certificate |
| `department` | no | Override the default department |
| `country` | no | Override the default country |
| `exportPath` | no | Override the default export path |
| `exportPassword` | no | PFX export password. Set to `null` to be prompted securely at runtime |

## Output files explained

For a certificate with `hostnameFQDN = "server.mycorp.local"` generated at 14:30:22 on 2025-02-13:

| File | Contains | Typical use |
|------|----------|-------------|
| `server.mycorp.local.pfx` | PKCS#12 archive (key + cert + chain) | Windows IIS, MMC import |
| `server.mycorp.local_20250213-143022.pem` | Combined private key + certificate | Reference / backup |
| `server.mycorp.local_20250213-143022_privatekey.pem` | Private key only | Nginx `ssl_certificate_key`, Apache `SSLCertificateKeyFile` |
| `server.mycorp.local_20250213-143022_certificate.pem` | Host certificate only | Nginx `ssl_certificate`, Apache `SSLCertificateFile` |
| `server.mycorp.local_20250213-143022_ca_chain.pem` | Intermediate + Root CA certificates | Nginx chain, Apache `SSLCertificateChainFile`, VMware trusted certs |

## Password handling

Passwords are **never hardcoded** in the scripts. Three options:

1. **Interactive prompt (recommended)** - set `exportPassword` to `null` in config (or omit `-ExportPassword` in CLI mode). You will be prompted with a masked input.
2. **In config.json** - set `exportPassword` to a string value. Acceptable for automation since `config.json` is gitignored, but be aware the password is stored in plain text on disk.
3. **CLI parameter** - pass `-ExportPassword "value"` directly. Useful for scripted pipelines, but the password may appear in process lists or shell history.

## SAN handling

The CN (hostname FQDN) is **always** automatically included as the first DNS SAN entry. You only need to specify _additional_ names:

```json
{
  "hostnameFQDN": "server.mycorp.local",
  "sanDns": ["server", "alias.mycorp.local"],
  "sanIpAddress": ["10.0.1.50", "192.168.1.50"]
}
```

This produces the SAN string: `DNS=server.mycorp.local,DNS=server,DNS=alias.mycorp.local,IPAddress=10.0.1.50,IPAddress=192.168.1.50`

Duplicates are automatically removed.
