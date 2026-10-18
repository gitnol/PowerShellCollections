#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Prüft lokal Secure Boot PK, db und KEK inkl. Handlungsempfehlung.
#>

function Test-UEFICertInVariable {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [byte[]]$VarBytes,

        [Parameter(Mandatory)]
        [string]$SubjectPattern
    )

    if (-not $VarBytes -or $VarBytes.Length -lt 28) {
        return $false
    }

    $x509Guid = [System.Guid]::new('a5c059a1-94e4-4aa7-87b5-ab155c2bf072')
    $pos = 0

    while ($pos + 28 -le $VarBytes.Length) {
        $listGuid = [System.Guid]::new([byte[]]$VarBytes[$pos..($pos + 15)])
        $listSize = [BitConverter]::ToUInt32($VarBytes, $pos + 16)
        $hdrSize = [BitConverter]::ToUInt32($VarBytes, $pos + 20)
        $sigSize = [BitConverter]::ToUInt32($VarBytes, $pos + 24)

        if ($listSize -eq 0 -or $sigSize -le 16) {
            break
        }

        if ($listGuid -eq $x509Guid) {
            $entry = $pos + 28 + [int]$hdrSize
            $end = $pos + [int]$listSize

            while ($entry + [int]$sigSize -le $end) {
                try {
                    $certBytes = $VarBytes[($entry + 16)..($entry + [int]$sigSize - 1)]
                    $cert = [System.Security.Cryptography.X509Certificates.X509Certificate2]::new([byte[]]$certBytes)

                    if ($cert.Subject -match [regex]::Escape($SubjectPattern)) {
                        return $true
                    }
                }
                catch {
                    # Defekte Einträge ignorieren
                }

                $entry += [int]$sigSize
            }
        }

        $pos += [int]$listSize
    }

    return $false
}

function Get-UEFICertStatus {
    <#
    .SYNOPSIS
        Prüft ein Secure-Boot-Zertifikat anhand des Subjects.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Name,

        [Parameter(Mandatory)]
        [string]$SubjectPattern
    )

    try {
        $variable = Get-SecureBootUEFI -Name $Name -ErrorAction Stop
        $present = Test-UEFICertInVariable -VarBytes $variable.Bytes -SubjectPattern $SubjectPattern

        [PSCustomObject]@{
            Name    = $Name
            Present = $present
            Status  = if ($present) { 'Vorhanden' } else { 'Fehlt' }
            Error   = $null
        }
    }
    catch {
        [PSCustomObject]@{
            Name    = $Name
            Present = $false
            Status  = 'Nicht lesbar'
            Error   = $_.Exception.Message
        }
    }
}

function Get-SecureBootRecommendation {
    <#
    .SYNOPSIS
        Erstellt eine Handlungsempfehlung zum Secure-Boot-Key-Status.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [bool]$SecureBootEnabled,

        [Parameter(Mandatory)]
        [bool]$PkPresent,

        [Parameter(Mandatory)]
        [bool]$DbPresent,

        [Parameter(Mandatory)]
        [bool]$KekPresent,

        [Parameter(Mandatory)]
        [bool]$HasReadError
    )

    if ($HasReadError) {
        return 'Als Administrator ausführen, UEFI-Zugriff prüfen und erneut testen. Wenn weiterhin nicht lesbar: Firmware-/BIOS-Update prüfen.'
    }

    if (-not $SecureBootEnabled) {
        return 'Vor UEFI-Änderungen BitLocker-Recovery-Key sichern bzw. Schutz aussetzen. Secure Boot im UEFI aktivieren und danach erneut prüfen.'
    }

    if ($DbPresent -and $KekPresent -and $PkPresent) {
        return 'Keine Maßnahme nötig. Secure Boot ist aktiv und die geprüften 2023er Keys sind vorhanden.'
    }

    if ($DbPresent -and $KekPresent -and -not $PkPresent) {
        return 'Keine Maßnahme nötig. db und KEK sind korrekt. PK fehlt nur für das gesuchte OEM-Subject; herstellerspezifischen PK nur bei Bedarf manuell prüfen.'
    }

    if ($DbPresent -and -not $KekPresent) {
        return 'KEK 2023 fehlt. Windows Updates/Firmwareprozess erneut anstoßen, Neustart durchführen und erneut prüfen. Keine manuellen UEFI-Key-Resets ohne BitLocker-Absicherung.'
    }

    if (-not $DbPresent -and $KekPresent) {
        return 'db 2023 fehlt. Windows Update/Firmwareprozess erneut ausführen, Neustart durchführen und erneut prüfen.'
    }

    return 'db und KEK 2023 fehlen. Gerät vollständig patchen, Secure-Boot-Update verteilen, Neustart durchführen und erneut prüfen. Vor UEFI-Änderungen BitLocker absichern.'
}

function Get-LocalSecureBootKeyStatus {
    <#
    .SYNOPSIS
        Gibt lokalen Secure Boot PK, db und KEK Status inkl. Empfehlung zurück.
    #>
    [CmdletBinding()]
    param()

    try {
        $secureBootEnabled = Confirm-SecureBootUEFI -ErrorAction Stop
    }
    catch [System.PlatformNotSupportedException] {
        return [PSCustomObject]@{
            ComputerName        = $env:COMPUTERNAME
            Status              = 'KEIN_UEFI'
            SecureBootEnabled   = $false
            PK                  = 'Nicht geprüft'
            db                  = 'Nicht geprüft'
            KEK                 = 'Nicht geprüft'
            Handlungsempfehlung = 'Kein UEFI-System oder Legacy BIOS aktiv. Nur relevant, wenn Secure Boot benötigt wird; dann UEFI-Modus prüfen.'
            Details             = 'Secure Boot wird auf diesem System nicht unterstützt.'
        }
    }
    catch {
        return [PSCustomObject]@{
            ComputerName        = $env:COMPUTERNAME
            Status              = 'FEHLER'
            SecureBootEnabled   = $false
            PK                  = 'Nicht geprüft'
            db                  = 'Nicht geprüft'
            KEK                 = 'Nicht geprüft'
            Handlungsempfehlung = 'Als Administrator ausführen und UEFI-/Firmware-Zugriff prüfen.'
            Details             = $_.Exception.Message
        }
    }

    $pkStatus = Get-UEFICertStatus -Name 'PK'  -SubjectPattern 'Windows OEM Devices PK'
    $dbStatus = Get-UEFICertStatus -Name 'db'  -SubjectPattern 'Windows UEFI CA 2023'
    $kekStatus = Get-UEFICertStatus -Name 'KEK' -SubjectPattern 'KEK 2K CA 2023'

    $hasReadError = [bool]($pkStatus.Error -or $dbStatus.Error -or $kekStatus.Error)

    $status = if ($hasReadError) {
        'FEHLER'
    }
    elseif (-not $secureBootEnabled) {
        'WARNUNG'
    }
    elseif ($dbStatus.Present -and $kekStatus.Present) {
        'OK'
    }
    else {
        'GEFAHR'
    }

    $recommendation = Get-SecureBootRecommendation `
        -SecureBootEnabled $secureBootEnabled `
        -PkPresent $pkStatus.Present `
        -DbPresent $dbStatus.Present `
        -KekPresent $kekStatus.Present `
        -HasReadError $hasReadError

    $details = if ($hasReadError) {
        @(
            if ($pkStatus.Error) { 'PK Fehler: {0}' -f $pkStatus.Error }
            if ($dbStatus.Error) { 'db Fehler: {0}' -f $dbStatus.Error }
            if ($kekStatus.Error) { 'KEK Fehler: {0}' -f $kekStatus.Error }
        ) -join ' | '
    }
    elseif (-not $secureBootEnabled) {
        'Secure Boot ist deaktiviert.'
    }
    elseif ($dbStatus.Present -and $kekStatus.Present) {
        'Secure Boot ist aktiv. db und KEK 2023 sind vorhanden.'
    }
    else {
        'Secure Boot ist aktiv. Mindestens ein 2023er Schlüssel fehlt.'
    }

    [PSCustomObject]@{
        ComputerName        = $env:COMPUTERNAME
        Status              = $status
        SecureBootEnabled   = $secureBootEnabled
        PK                  = if ($pkStatus.Present) { 'Windows OEM Devices PK vorhanden' } else { $pkStatus.Status }
        db                  = if ($dbStatus.Present) { 'Windows UEFI CA 2023 vorhanden' } else { $dbStatus.Status }
        KEK                 = if ($kekStatus.Present) { 'KEK 2K CA 2023 vorhanden' } else { $kekStatus.Status }
        Handlungsempfehlung = $recommendation
        Details             = $details
    }
}

Get-LocalSecureBootKeyStatus | Format-List