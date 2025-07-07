function Set-UserPhotoHybrid { 
    param (
        [Parameter(Mandatory)][string]$UserPrincipalName,
        [Parameter(Mandatory)][string]$PhotoPath,
        [Parameter()][PSCredential]$ADCredential,
        [Parameter()][switch]$SkipGraph
    )
    
    
    if (Test-Path $PhotoPath) {
        $PhotoPath = (Get-Item $photopath).FullName    
    }
    else {
        throw "PhotoPath '$PhotoPath' existiert nicht."
    }

    Add-Type -AssemblyName System.Drawing
    $original = [System.Drawing.Image]::FromFile($PhotoPath)

    function Resize-Image {
        param (
            [System.Drawing.Image]$Image,
            [int]$Size
        )

        $ratioX = $Size / $Image.Width
        $ratioY = $Size / $Image.Height
        $ratio = [math]::Min($ratioX, $ratioY)

        $newWidth = [math]::Round($Image.Width * $ratio)
        $newHeight = [math]::Round($Image.Height * $ratio)

        $thumb = New-Object System.Drawing.Bitmap -ArgumentList $Size, $Size
        $g = [System.Drawing.Graphics]::FromImage($thumb)

        $g.Clear([System.Drawing.Color]::White)
        $g.InterpolationMode = "HighQualityBicubic"

        $offsetX = [math]::Floor(($Size - $newWidth) / 2)
        $offsetY = [math]::Floor(($Size - $newHeight) / 2)

        $g.DrawImage($Image, $offsetX, $offsetY, $newWidth, $newHeight)
        $g.Dispose()

        return $thumb
    }


    # 1. Lokales AD (96x96)
    $adImage = Resize-Image -Image $original -Size 96
    $jpegCodec = [System.Drawing.Imaging.ImageCodecInfo]::GetImageEncoders() | Where-Object { $_.MimeType -eq 'image/jpeg' }
    $params = New-Object System.Drawing.Imaging.EncoderParameters(1)
    $params.Param[0] = New-Object System.Drawing.Imaging.EncoderParameter([System.Drawing.Imaging.Encoder]::Quality, 75L)
    $tmpAdPath = "$env:TEMP\AD_$($UserPrincipalName).jpg"
    $adImage.Save($tmpAdPath, $jpegCodec, $params)
    $adImage.Dispose()
    $adBytes = [System.IO.File]::ReadAllBytes($tmpAdPath)

    if ($ADCredential) {
        $root = [ADSI]"LDAP://RootDSE"
        $domain = $root.defaultNamingContext
        $ldap = "LDAP://$domain"
        $adUser = New-Object DirectoryServices.DirectoryEntry($ldap, $ADCredential.UserName, $ADCredential.GetNetworkCredential().Password)
        $search = New-Object DirectoryServices.DirectorySearcher($adUser)
        $search.Filter = "(&(objectClass=user)(userPrincipalName=$UserPrincipalName))"
        $result = $search.FindOne()

        if ($result -and $result.Properties) {
            $entry = $result.GetDirectoryEntry()
            $entry.Properties["thumbnailPhoto"].Clear()
            $entry.Properties["thumbnailPhoto"].Add($adBytes)
            $entry.CommitChanges()
            Write-Host "✓ Lokales AD aktualisiert: $UserPrincipalName"
        }
        else {
            Write-Warning "User $UserPrincipalName nicht im lokalen AD gefunden."
        }
    }
    else {
        Write-Warning "ADCredential nicht angegeben – lokales AD wird übersprungen."
    }

    # 2. Entra / Teams (648x648)
    if (-not $SkipGraph) {
        # Check Graph connection
        try {
            Get-MgUser -UserId $UserPrincipalName -ErrorAction Stop | Out-Null
        }
        catch {
            throw "Microsoft Graph ist nicht verbunden oder unzureichend berechtigt. Nutze Connect-MgGraph -Scopes 'User.ReadWrite.All' oder setze -SkipGraph."
        }

        $entraImage = Resize-Image -Image $original -Size 648
        $tmpGraphPath = "$env:TEMP\Graph_$($UserPrincipalName).jpg"
        $entraImage.Save($tmpGraphPath, $jpegCodec, $params)
        $entraImage.Dispose()

        try {
            Set-MgUserPhotoContent -UserId $UserPrincipalName -InFile $tmpGraphPath
            Write-Host "✓ Teams/Entra aktualisiert: $UserPrincipalName"
        }
        catch {
            Write-Warning "Fehler beim Hochladen in Entra: $_"
        }
    }
}

$ModuleName = "Microsoft.Graph"
if (-not (Get-Module -ListAvailable -Name $ModuleName)) {
    Install-Module -Name $ModuleName -Scope CurrentUser -Force
}

if ((Get-Module -ListAvailable -Name $ModuleName)) {
    # Voraussetzung: Verbinde Graph vorher
    Connect-MgGraph -Scopes "User.ReadWrite.All"
}

# Lokales AD Passwort-Dialog
$cred = Get-Credential
# Aufruf
# Set-UserPhotoHybrid -ADCredential $cred -UserPrincipalName "user@firma.de" -PhotoPath "C:\Fotos\user.jpg" 