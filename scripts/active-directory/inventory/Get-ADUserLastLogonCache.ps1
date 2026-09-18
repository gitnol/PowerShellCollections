<#
.SYNOPSIS
    Baut eine Nachschlagetabelle SamAccountName -> letzte Anmeldung ueber
    alle Domain Controller.

.DESCRIPTION
    Fragt jeden DC einmal ab und behaelt je Benutzer den juengsten
    lastLogon-Wert. Das Attribut wird nicht repliziert, ein einzelner DC
    liefert also einen zu alten Wert.

    Gedacht als Vorstufe fuer Auswertungen, die den Wert fuer viele Benutzer
    brauchen: einmal alle DCs abfragen ist deutlich schneller als je Benutzer
    einzeln.

.NOTES
    Rueckgabe ist eine Hashtable mit SamAccountName als Schluessel und einem
    DateTime als Wert.
#>

function Get-ADUserLastLogonCache {
    param(
        [string[]]$SamAccountNames
    )

    $DCs = Get-ADDomainController -Filter * | Select-Object -ExpandProperty HostName
    $Cache = @{}

    foreach ($DC in $DCs) {
        Get-ADUser -Filter * -Server $DC -Properties SamAccountName, LastLogon |
        Where-Object { $_.SamAccountName -in $SamAccountNames } |
        ForEach-Object {
            $Current = $Cache[$_.SamAccountName]
            if (-not $Current -or $_.LastLogon -gt $Current) {
                $Cache[$_.SamAccountName] = $_.LastLogon
            }
        }
    }

    # Rückgabe als Hashtable mit SamAccountName -> DateTime
    $Result = @{}
    foreach ($Key in $Cache.Keys) {
        $Result[$Key] = if ($Cache[$Key] -gt 0) {
            [DateTime]::FromFileTime($Cache[$Key])
        }
        else {
            $null
        }
    }
    return $Result
}

$OU = "OU=USRMGMT,OU=ITMGMT,DC=mycorp,DC=local"
$thresholdDate = (Get-Date).AddYears(-3)
# Hauptabfrage
$Users = Get-ADUser -Filter { Enabled -eq $true } -SearchBase $OU -Properties Name, SamAccountName, PasswordLastSet, DistinguishedName |
Where-Object {
    $_.PasswordLastSet -lt $thresholdDate -and
    $_.DistinguishedName -notmatch "OU=Dienst-Accounts"
}

$SamNames = $Users.SamAccountName
$Logons = Get-ADUserLastLogonCache -SamAccountNames $SamNames

$Users | ForEach-Object {
    [PSCustomObject]@{
        Name              = $_.Name
        SamAccountName    = $_.SamAccountName
        PasswordLastSet   = $_.PasswordLastSet
        DistinguishedName = $_.DistinguishedName
        LastLogonDate     = $Logons[$_.SamAccountName]
    }
} |
Sort-Object PasswordLastSet |
Out-GridView -Title "Aktive Benutzer in USRMGMT ohne Dienst-Accounts mit Passwort älter als 3 Jahre"
