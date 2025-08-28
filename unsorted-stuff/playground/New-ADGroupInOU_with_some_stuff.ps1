function New-ADGroupInOU {
    param (
        [Parameter(Mandatory)]
        [string]$GroupName,

        [Parameter(Mandatory)]
        [string]$OUPath,

        [Parameter(Mandatory)]
        [string]$Description,

        [ValidateSet("Global", "Universal", "DomainLocal")]
        [string]$GroupScope = "Global",

        [ValidateSet("Security", "Distribution")]
        [string]$GroupCategory = "Security"
    )

    try {
        # Prüfen, ob OU existiert
        if (-not (Get-ADOrganizationalUnit -LDAPFilter "(distinguishedName=$OUPath)" -ErrorAction SilentlyContinue)) {
            throw "OU '$OUPath' existiert nicht."
        }

        # Prüfen, ob Gruppe im Ziel-OU bereits existiert
        $existingGroup = Get-ADGroup -LDAPFilter "(&(samAccountName=$GroupName)(distinguishedName=*$OUPath))" -ErrorAction SilentlyContinue

        if ($existingGroup) {
            Write-Warning "Gruppe '$GroupName' existiert bereits in '$OUPath'."
            return $existingGroup
        }

        # Gruppe erstellen
        $newGroup = New-ADGroup -Name $GroupName `
            -SamAccountName $GroupName `
            -GroupScope $GroupScope `
            -GroupCategory $GroupCategory `
            -Path $OUPath `
            -Description $Description #-Whatif

        Write-Host "Gruppe '$GroupName' erfolgreich erstellt in '$OUPath'." -ForegroundColor Green
        return $newGroup

    }
    catch {
        Write-Error "Fehler beim Erstellen der Gruppe: $_"
    }
}



function Add-GeheimeOrdner {
    param (
        [string]$BasisPfad = 'M:\',
        [string[]]$Ordnernamen = @('_1_VERTRAULICH', '_2_STRENG_VERTRAULICH', '_3_INTERN')
    )

    Get-ChildItem -Path $BasisPfad -Directory | ForEach-Object {
        $Ziel = $_.FullName
        foreach ($Ordner in $Ordnernamen) {
            $Pfad = Join-Path -Path $Ziel -ChildPath $Ordner
            if (-not (Test-Path $Pfad)) {
                New-Item -Path $Pfad -ItemType Directory  #| Out-Null
            }
        }
    }
}


function w {
    param (
        [string]$BasisPfad = 'M:\',
        [string[]]$Ordnernamen = @('_1_VERTR', '_2_STRENG_VERTR') # Längere Namen können zu Problemen führen, daher kürzer gehalten.
    )

    Get-ChildItem -Path $BasisPfad -Directory | ForEach-Object {
        $ZielName = $_.Name
        foreach ($Ordner in $Ordnernamen) {
            $description = if ($Ordner -eq '_1_VERTR') { "Zugriff auf M:\$($ZielName)\_1_VERTRAULICH" } else { "Zugriff auf M:\$($ZielName)\_2_STRENG_VERTRAULICH" }
            $Pfad = if ($Ordner -eq '_1_VERTR') { "M:\$($ZielName)\_1_VERTRAULICH" } else { "M:\$($ZielName)\_2_STRENG_VERTRAULICH" }
            Write-Host($Pfad)
            [PSCustomObject]@{
                GroupName   = ("Schutzklasse$($Ordner)_$($ZielName)_W");
                Description = $description;
                Pfad        = $Pfad;
            }
        }
    }
}

function Set-FolderPermissions {
    param (
        [string]$Pfad = 'GibHierEinenPfadEin',
        [string]$ExtraGruppe = 'gibhierEineExtraGruppeEin'
    )
    Write-Host($Pfad, $ExtraGruppe) -foregroundcolor yellow
    $Admins = @(
        'SYSTEM',
        'mydomain.local\Domänen-Admins',
        'mydomain.local\Server-Admins',
        'VORDEFINIERT\Administratoren'
    )

    foreach ($Acc in $Admins) {
        icacls $Pfad /grant "$($Acc):(OI)(CI)F"
    }
    icacls $Pfad /grant "$($ExtraGruppe):(OI)(CI)M" 
    icacls $Pfad /inheritance:r
}

Create-GroupNames | Select-Object -First 1000 | ForEach-Object {
    Set-FolderPermissions -Pfad $_.Pfad -ExtraGruppe $_.GroupName
}

# Add-GeheimeOrdner
# Create-GroupNames | select -first 1 | %{New-ADGroupInOU -GroupName $_.GroupName -OUPath "OU=Abteilungen,OU=DFS,OU=Verzeichnisspezifische Gruppen,OU=GRPMGMT,OU=ITMGMT,DC=mydomain,DC=local" -Description $_.Description -GroupScope Universal -GroupCategory Security -Verbose}