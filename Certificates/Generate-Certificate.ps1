Install-Module -Name PSPKI
# Check if the PSPKI module is installed
$moduleName = "PSPKI"
$moduleInstalled = Get-Module -ListAvailable -Name $moduleName
if (-not $moduleInstalled) {
    Install-Module -Name $moduleName -Force
    Import-Module -Name $moduleName
}

function Export-CertificateChain {
    # Example usage:
    # Export the full certificate chain
    # Export-CertificateChain -PfxPath "C:\path\to\yourfile.pfx" -OutputPath "C:\path\to\output\full_chain.pem" -Password "YourPfxPassword"

    # Export only the CA certificates (intermediate and root)
    # Export-CertificateChain -PfxPath "C:\path\to\yourfile.pfx" -OutputPath "C:\path\to\output\ca_chain.pem" -Password "YourPfxPassword" -CaOnly
    param (
        [string]$PfxPath, # Path to the PFX file
        [string]$OutputPath, # Output path for the PEM file
        [string]$Password, # Password for the PFX file (if any)
        [switch]$CaOnly         # Switch to export only the CA certificates
    )

    # Clear any existing file at the output path
    Remove-Item $OutputPath -ErrorAction Ignore

    # Load the PFX file using the constructor method
    $pfx = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2($PfxPath, $Password, [System.Security.Cryptography.X509Certificates.X509KeyStorageFlags]::Exportable)

    # Create a collection to hold the certificates in the chain
    $certChain = New-Object System.Security.Cryptography.X509Certificates.X509Chain
    $certChain.Build($pfx)

    # Loop through each certificate in the chain
    foreach ($element in $certChain.ChainElements) {
        # If $CaOnly is specified, skip the end-entity certificate
        if ($CaOnly -and $element.Certificate.Thumbprint -eq $pfx.Thumbprint) {
            continue
        }

        # Convert the certificate to PEM format
        $certPem = [System.Convert]::ToBase64String($element.Certificate.RawData)
        Add-Content -Path $OutputPath -Value "-----BEGIN CERTIFICATE-----"
        Add-Content -Path $OutputPath -Value $certPem
        Add-Content -Path $OutputPath -Value "-----END CERTIFICATE-----"
    }

    Write-Host "Certificate chain exported to $OutputPath"
}

$myScriptpath = if ($PSScriptRoot) { $PSScriptRoot }else { (Get-Location) }
$configfilepath = $myScriptpath.Path + "\config.json" # Just implement your own config. Makes everything easier
#region config.json Example
# [
#   {
#     "vendor": "VMWare",
#     "type": "VCSA",
#     "Hostname": "vcsa.mycorp.local",
#     "Parent": "",
#     "detail": [
#       {
#         "hostname": "vcsa.mycorp.local",
#         "priviledge": "admin",
#         "password": "test123"
#       }
#     ]
#   },
#   {
#     "vendor": "Me",
#     "type": "Password",
#     "hostname": "mytesthost",
#     "parent": "",
#     "detail": [
#       {
#         "hostname": "mytesthost",
#         "priviledge": "user",
#         "password": "test123"
#       }
#     ]
#   }
# ]
#endregion


function New-Certificate {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
        [string]$hostnameFQDN,
        [Parameter(Mandatory = $true, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
        [string]$ExportPassword
    )
    
    begin {
        
    }
    
    process {
        $TemplateName = "Webserver" # Template Name from the CA which is being used for Webservers
        $myOrganization = $hostnameFQDN # = O
        $Department = "IT" # = OU
        $Country = "DE" # = C
        $FriendlyName = $hostnameFQDN + "_" + (Get-Date).ToString("yyyyMMdd-HHmmss")
        $SAN = "dns=$hostnameFQDN" # Minimal MUST Haves
        $ExportPath = "C:\temp\certtest" # The Certificates and everything around that is located here
        $ExportPasswordSecureString = (ConvertTo-SecureString -String $ExportPassword -AsPlainText -Force)

        $pfxFile = $ExportPath + "\" + $hostnameFQDN + ".pfx" # Request-Certificate.ps1 creates a PFX File with the CN parameter => hostnameFQDN
        $pemFile = $ExportPath + "\" + $FriendlyName + ".pem"
        $fullchain = $ExportPath + "\" + $FriendlyName + "_full_chain.pem"
        $hostonly_pemfile = $ExportPath + "\" + $FriendlyName + "_certificate.pem"
        $hostonly_privatekeyfile = $ExportPath + "\" + $FriendlyName + "_privatekey.pem"

        .\Request-Certificate.ps1 -CN $hostnameFQDN -SAN $SAN -Country $Country -Organisation $myOrganization -Department $Department -FriendlyName $FriendlyName -AddCNinSAN -Export -ExportPath $ExportPath -Password $ExportPassword -TemplateName $TemplateName

        if (Test-Path ($pfxFile)) {
            Convert-PfxToPem -InputFile $pfxFile -OutputFile $pemFile -Password $ExportPasswordSecureString
            Export-CertificateChain -PfxPath $pfxFile -OutputPath $fullchain -Password $ExportPassword -CaOnly
        }

        if (Test-Path ($pemFile)) {
            (Get-Content -LiteralPath $pemFile -Raw) -match "(?ms)(\s*((?<privatekey>-----BEGIN PRIVATE KEY-----.*?-----END PRIVATE KEY-----)|(?<certificate>-----BEGIN CERTIFICATE-----.*?-----END CERTIFICATE-----))\s*){2}"
            $Matches["privatekey"] | Set-Content -LiteralPath ($hostonly_privatekeyfile)
            $Matches["certificate"] | Set-Content -LiteralPath ($hostonly_pemfile)
        }
    }
    
    end {
        
    }
}

#region Main program
$hostnameFQDN = "na-rz02.mycorp.local"
$ExportPassword = "test123" # Just a Password if you  do not want to use the config.json
New-Certificate -hostnameFQDN $hostnameFQDN -ExportPassword $ExportPassword
#endregion