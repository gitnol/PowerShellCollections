# Powershell Version 6 oder höher erzwingen
if ($PSVersionTable.PSVersion.Major -le 6) {
    pwsh $MyInvocation.InvocationName
} else {
    # Letzte Änderung: 20230309
    # $AD_Bitlocker_Informationen um wesentliche Infos ergänzt
    $CompList = @()
    $AD_Bitlocker_Informationen = @()
    $CompList = Get-ADComputer -Filter 'operatingSystem -like "Windows*" -and Enabled -eq "True"' -Properties *
    #$CompList = Get-ADComputer 980A1C-M 
    
    # Schritt 1: Sammle von allen aktiven Windows Rechnern die Bitlockerinformationen AUS DEM ACTIVE DIRECTORY ein
    Foreach ($CL in $CompList) {
        # Für jeden Computer hole die Recovery Infos (können mehrere RecoveryPasswörter sein.
        $Bitlocker_Object = Get-ADObject -Filter { objectclass -eq 'msFVE-RecoveryInformation' } -SearchBase $CL.DistinguishedName -Properties 'msFVE-RecoveryPassword'
        # $Bitlocker_Object | ogv
        # Für jedes RecoveryPasswort eine einzelne Zeile in $AD_Bitlocker_Informationen anlegen.
        $Bitlocker_Object | ForEach-Object {
            $anzahlkeys = $Bitlocker_Object.'msFVE-RecoveryPassword'.Count
            $AD_Bitlocker_Informationen += [PSCustomObject]@{
                Computername                  = $CL.Name
                Beschreibung                  = $CL.description
                BitlockerKeyCount             = $anzahlkeys
                BitlockerKeyRecoveryPasswords = $_.'msFVE-RecoveryPassword'
                ComputerDistinguishedName     = $CL.DistinguishedName
                msFVE_DN_KeyID                = ((($_.DistinguishedName).split(",")[0]).split('{')[1]).split('}')[0]
                msFVE_DN_TimeStamp            = $date = [DateTime]::Parse(((($_.DistinguishedName).split(",")[0]).split('{')[0]).split('=')[1].replace('\', ''))
            }
        }
    }
    
    # Schritt 2: Sammle von allen aktiven Windows Rechnern, die online sind, die Bitlockerinformationen LOKAL ein
    $OnlineComputerBitlockerInfos = @()
    # Alle Computer mit Bitlocker!
    # $AD_Bitlocker_Informationen | Where {$_.BitlockerKeyCount -gt 0}
    # Für alle Computer mit Bitlockerinfos im AD ausführen
    $OnlineComputerBitlockerInfos += (($AD_Bitlocker_Informationen | Where-Object { $_.BitlockerKeyCount -gt 0 }).Computername | Sort-Object -Unique) | ForEach-Object -Parallel {	
        if (Test-Connection -BufferSize 32 -Count 1 -ComputerName $_ -Quiet) {
            Write-Host("Verarbeite $_") -ForegroundColor Green
            # Diese Computer sind Online. Jetzt Lokales Passwort des Computers ermitteln und zurückgeben.
            [PSCustomObject]@{
                Computername             = $_
                Lokales_RecoveryPassword = (Invoke-Command -ComputerName $_ -ScriptBlock { (Get-BitLockerVolume -MountPoint C:).KeyProtector.RecoveryPassword } | Where-Object { $_ })
                VolumeStatus_C           = (Invoke-Command -ComputerName $_ -ScriptBlock { (Get-BitLockerVolume -MountPoint C:).VolumeStatus }).Value
            }
            Write-Host("Verarbeite $_ ... FERTIG!!!") -ForegroundColor Green
        } else {
            Write-Host("Host Offline $_") -ForegroundColor Red
        }
    }
    
    # Schritt 3: Vergleiche die Informationen von LOKAL und AD miteinander und gebe sie aus 
    $ergebnis = @()
    $OnlineComputerBitlockerInfos | ForEach-Object {
        $aktueller_computer = $_.Computername
        $aktuelles_bitlockerpasswort = $_.Lokales_RecoveryPassword | Where-Object { $_ }
        $aktueller_VolumeStatus_C = $_.VolumeStatus_C
        # Write-Host ($aktueller_computer,$aktuelles_bitlockerpasswort) -ForegroundColor Green
        # Filtere die RecoveryPasswörter für den jeweiligen Rechner und füge das lokale RecoveryPassword dem Ergebnis Array hinzu.
        $AD_Bitlocker_Informationen | Where-Object { $_.Computername -eq $aktueller_computer } | ForEach-Object {
            $_ | ForEach-Object {
                $currentBitlockerKeyRecoveryPassword = $_.BitlockerKeyRecoveryPasswords
                $currentmsFVE_DN_KeyID = $_.msFVE_DN_KeyID
                $currentmsFVE_DN_TimeStamp = $_.msFVE_DN_TimeStamp
                $ergebnis += [PSCustomObject]@{
                    Computername              = $aktueller_computer
                    AD_Bitlocker_Kennwort     = $currentBitlockerKeyRecoveryPassword
                    Lokales_Bitlockerpasswort = $aktuelles_bitlockerpasswort
                    Identisch                 = ($currentBitlockerKeyRecoveryPassword -eq $aktuelles_bitlockerpasswort)
                    VolumeStatus_C            = $aktueller_VolumeStatus_C
                    msFVE_DN_KeyID            = $currentmsFVE_DN_KeyID
                    msFVE_DN_TimeStamp        = $currentmsFVE_DN_TimeStamp
                }
            }
        } 
    }
    
    $AD_Bitlocker_Informationen | Out-GridView -Title "Alle Bitlocker Informationen aus dem AD"
    $ergebnis | Out-GridView -Title "Vergleichtabelle zwischen lokalen und AD Informationen"
    $OnlineComputerBitlockerInfos | Out-GridView -Title "Alle Bitlockerinformationen von ONLINE Rechnern"
}