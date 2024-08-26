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
        [string]$PfxPath,       # Path to the PFX file
        [string]$OutputPath,    # Output path for the PEM file
        [string]$Password,      # Password for the PFX file (if any)
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

$hostnameFQDN = "a220.mycorp.local"
$ExportPassword = "test123" # Just a Password if you  do not want to use the config.json

if ($hostnameFQDN.Trim() -eq "") {
    if (Test-Path -LiteralPath $configfilepath){
        $myconfig = Get-Content -LiteralPath $configfilepath | ConvertFrom-Json
    } else {
        Write-Host("No config.json File Found") -ForegroundColor Red
        Exit(0)
    }

    # From here... the certificates are being generated. You must3 have priviledge
    $hostnameFQDN = $myconfig.Hostname | Select-Object -first 1
    if (!$hostnameFQDN) {
        Write-Host("No Hostname in Config.json File Found") -ForegroundColor Red
        Exit(0)
    }
}
if ($hostnameFQDN.Trim() -eq "") {
    Exit(1)
}

if ($ExportPassword.Trim() -eq "") {
    $ExportPassword = ($myconfig | Where-Object Hostname -eq $($hostnameFQDN)).detail.password
    if ($ExportPassword.Trim() -eq "") {
        $ExportPassword = Read-Host -Prompt "Please Input Export Password for PFX File"
    }
}

if ($ExportPassword.Trim() -eq "") {
    Write-Error("ExportPassword is empty")
    Exit(1)
}


# $hostnameFQDN = "replicavcsa.$($mycorp).local"
# $hostnameFQDN = "vcsa.$($mycorp).local"
$TemplateName = "Webserver" # Template Name from the CA which is being used for Webservers
$myOrganization = $hostnameFQDN # = O
$Department = "IT" # = OU
$Country = "DE" # = C
$FriendlyName = $hostnameFQDN + "_" + (Get-Date).ToString("yyyyMMdd-HHmmss")
$SAN = "dns=$hostnameFQDN" # Minimal MUST Haves
$ExportPath = "C:\temp\certtest" # The Certificates and everything around that is located here
# $ExportPassword = "test123" # Just a Password if you  do not want to use the config.json
$ExportPassword = ($myconfig | Where-Object Hostname -eq $($hostnameFQDN)).detail.password
$ExportPasswordSecureString = (ConvertTo-SecureString -String $ExportPassword -AsPlainText -Force)

$pfxFile = $ExportPath + "\" + $hostnameFQDN  + ".pfx" # Request-Certificate.ps1 creates a PFX File with the CN parameter => hostnameFQDN
$pemFile = $ExportPath + "\" + $FriendlyName  + ".pem"
$fullchain = $ExportPath + "\" + $FriendlyName  + "_full_chain.pem"
$hostonly_pemfile = $ExportPath + "\" + $FriendlyName + "_certificate.pem"
$hostonly_privatekeyfile = $ExportPath + "\" + $FriendlyName +  "_privatekey.pem"

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



Exit(0) # For safety reasons... remove this in order to test the replacement of certificates at the vcsa and esxi level. Be Careful. Important: First please add the CA and SUB CA public Keys to the VCSA and ESXi HOSTS! You were warned!
$cred_vcsa = Get-Credential -Message "Enter credentials for vcsa"
$cred_replicavcsa = Get-Credential -Message "Enter credentials for replicavcsa"
$conn_vcsa = Connect-VIServer -Server "vcsa.$($mycorp).local" -Credential $cred_vcsa -Force
$conn_replicavcsa = Connect-VIServer -Server "replicavcsa.$($mycorp).local" -Credential $cred_replicavcsa -Force

if (Test-Path ($fullchain)) { # Add Root Certificates to VMWare. VERY IMPORTANT. IF THIS FAILS, THEN DO NOT REPLACE THE ESXi CERTIFICATES
    $trustedCertChain  = Get-Content $fullchain -Raw
    #Add it to the trusted certificate stores of the vCenter and the ESXi servers
    Add-VITrustedCertificate -PemCertificateOrChain $trustedCertChain -Server $conn_vcsa
    Add-VITrustedCertificate -PemCertificateOrChain $trustedCertChain -Server $conn_replicavcsa
}

if ($cred_vcsa){
    # Remove expired Certificates
    Get-VITrustedCertificate -VCenterOnly -Server $conn_vcsa | Where-Object { $_.NotValidAfter -lt (Get-Date) } | Remove-VITrustedCertificate
    # Get Machine Certificate of vCenter
    Get-VIMachineCertificate -VCenterOnly -Server $conn_vcsa

    $vcCertPemCert  = Get-Content $hostonly_pemfile -Raw # "C:\Temp\certtest\vcsa.$($mycorp).local_20240824-210844_certificate.pem"
    # $vcCertPemCert  = Get-Content "C:\Temp\certtest\vcsa.$($mycorp).local_20240824-210844_certificate.pem" -Raw # "C:\Temp\certtest\vcsa.$($mycorp).local_20240824-210844_certificate.pem"

    $vcCertPemKey  = Get-Content $hostonly_privatekeyfile -Raw # "C:\Temp\certtest\vcsa.$($mycorp).local_20240824-210844_certificate.pem"
    # $vcCertPemKey  = Get-Content "C:\Temp\certtest\vcsa.$($mycorp).local_20240824-210844_privatekey.pem" -Raw # "C:\Temp\certtest\vcsa.$($mycorp).local_20240824-210844_certificate.pem"

    Set-VIMachineCertificate -PemCertificate $vcCertPemCert -PemKey $vcCertPemKey -Server $conn_vcsa -WhatIf
}
if ($cred_replicavcsa){
    # Remove expired Certificates
    Get-VITrustedCertificate -VCenterOnly -Server $conn_replicavcsa | Where-Object { $_.NotValidAfter -lt (Get-Date) } | Remove-VITrustedCertificate
    # Get Machine Certificate of vCenter
    Get-VIMachineCertificate -VCenterOnly -Server $conn_replicavcsa


    # EXAMPLE for replacing the certificate with your own

    # Replace certificate on a ESXi Host. (should be manageable with vCenter from Version 8.0.3 or newer, but i can get it working over the UI)
    $vmhost = VMware.VimAutomation.Core\Get-VMHost -Name "esx20.$($mycorp).local"
    # Maintenance Mode ON
    VMware.VimAutomation.Core\Set-VMHost -VMhost $vmhost -state Maintenance
    # Certificate
    $esx20certpem = get-content "C:\Temp\certtest\esx20.$($mycorp).local_20240824-221934_certificate.pem" -Raw
    # PrivateKey
    $esx20certpemkey = get-content "C:\Temp\certtest\esx20.$($mycorp).local_20240824-221934_privatekey.pem" -Raw
    # Define target Host
    $targetEsxHost = VMware.VimAutomation.Core\Get-VMHost $vmhost.Name  -Server $conn_replicavcsa
    # Set the certificate. IMPORTANT: The Root CA and SUB Ca public certificate MUST be present beforehand
    Set-VIMachineCertificate -VMHost $targetEsxHost  -PemCertificate $esx20certpem -PemKey $esx20certpemkey -Server $conn_replicavcsa
    # Maintenance Mode OFF
    VMware.VimAutomation.Core\Set-VMHost -VMhost $vmhost -state
}


