<#
.SYNOPSIS
    Setzt das Benutzerfoto gleichzeitig im lokalen AD (thumbnailPhoto) und in
    Entra ID / Teams.

.DESCRIPTION
    Skaliert ein Bild zweimal und verteilt es an beide Ziele, weil sie
    unterschiedliche Groessen erwarten: 96x96 fuer das AD-Attribut
    thumbnailPhoto (Groessenlimit), 648x648 fuer Entra ID ueber Microsoft
    Graph.

    Fehlt -ADCredential, wird das lokale AD uebersprungen; mit -SkipGraph
    entfaellt der Entra-Teil. Schreibfehler ins AD (fehlende Rechte auf
    thumbnailPhoto) brechen den Ablauf nicht ab, damit der Entra-Teil noch
    laeuft.

    Benoetigt das Modul Microsoft.Graph.Users und eine bestehende
    Graph-Verbindung mit dem Scope 'User.ReadWrite.All'.

.NOTES
    Zum Zuschneiden der Vorlage gibt es photo-cropper/MyPhotoCropper.html
    im selben Verzeichnis.
#>

function Set-UserPhotoHybrid { 
    param (
        [Parameter(Mandatory)][string]$UserPrincipalName,
        [Parameter(Mandatory)][string]$PhotoPath,
        [Parameter()][PSCredential]$ADCredential,
        [Parameter()][switch]$SkipGraph
    )
    
    if (Test-Path $PhotoPath) {
        $PhotoPath = (Get-Item $PhotoPath).FullName    
    }
    else {
        throw "Das Bild unter '$PhotoPath' existiert nicht."
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

    try {
        $jpegCodec = [System.Drawing.Imaging.ImageCodecInfo]::GetImageEncoders() | Where-Object { $_.MimeType -eq 'image/jpeg' }
        $params = New-Object System.Drawing.Imaging.EncoderParameters(1)
        $params.Param[0] = New-Object System.Drawing.Imaging.EncoderParameter([System.Drawing.Imaging.Encoder]::Quality, 75L)

        # 1. Lokales AD (96x96)
        $adImage = Resize-Image -Image $original -Size 96
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
                try {
                    $entry = $result.GetDirectoryEntry()
                    $entry.Properties["thumbnailPhoto"].Clear()
                    $entry.Properties["thumbnailPhoto"].Add($adBytes)
                    $entry.CommitChanges()
                    Write-Host "✓ Lokales AD aktualisiert: $($UserPrincipalName)" -ForegroundColor Green
                }
                catch {
                    Write-Warning "Fehler beim Schreiben ins AD für $($UserPrincipalName). Möglicherweise fehlen Berechtigungen."
                }
            }
            else {
                Write-Warning "User $($UserPrincipalName) nicht im lokalen AD gefunden."
            }
        }
        else {
            Write-Warning "ADCredential nicht angegeben – lokales AD wird übersprungen."
        }

        # 2. Entra / Teams (648x648)
        if (-not $SkipGraph) {
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
                Write-Host "✓ Teams/Entra aktualisiert: $($UserPrincipalName)" -ForegroundColor Green
            }
            catch {
                Write-Warning "Fehler beim Hochladen in Entra: $_"
            }
        }
    }
    finally {
        # Ressourcen sauber freigeben und aufräumen
        if ($original) { $original.Dispose() }
        if ($params) { $params.Dispose() }
        if (Test-Path $tmpAdPath) { Remove-Item -Path $tmpAdPath -Force -ErrorAction SilentlyContinue }
        if (Test-Path $tmpGraphPath) { Remove-Item -Path $tmpGraphPath -Force -ErrorAction SilentlyContinue }
    }
}

# Modul-Prüfung (nur das benötigte Users-Modul statt des ganzen Graph-Pakets)
$ModuleName = "Microsoft.Graph.Users"
if (-not (Get-Module -ListAvailable -Name $ModuleName)) {
    Install-Module -Name $ModuleName -Scope CurrentUser -Force -AllowClobber
}

if ((Get-Module -ListAvailable -Name $ModuleName)) {
    Connect-MgGraph -Scopes "User.ReadWrite.All"
}

# Beispielaufruf
# $cred = Get-Credential
# Set-UserPhotoHybrid -ADCredential $cred -UserPrincipalName "user@firma.de" -PhotoPath "C:\Fotos\user.jpg"