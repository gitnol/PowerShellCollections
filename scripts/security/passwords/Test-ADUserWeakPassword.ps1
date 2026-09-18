<#
.SYNOPSIS
    Prueft Mitglieder bestimmter AD-Gruppen auf schwache Passwoerter.

.DESCRIPTION
    Probiert fuer die Mitglieder der konfigurierten Gruppen eine Liste
    haeufiger Passwoerter durch und meldet die Treffer. Auf Wunsch wird bei
    den betroffenen Konten zusaetzlich PasswordNeverExpires abgeschaltet und
    ChangePasswordAtLogon gesetzt.

.NOTES
    ACHTUNG: Jeder Fehlversuch zaehlt auf den Sperrzaehler. Bestehen
    Kontosperrungsrichtlinien, MUSS $maxBadPwdCount niedriger liegen als der
    Schwellwert der Richtlinie - sonst sperrt das Skript reihenweise Konten
    und der Helpdesk hat zu tun.

    Vorgabe ist 3. Vor dem ersten Lauf die geltende Richtlinie nachsehen:
    `Get-ADDefaultDomainPasswordPolicy`.

    Nur mit ausdruecklicher Freigabe einsetzen - fachlich ist das ein
    Passwort-Rateangriff auf die eigene Domaene.
#>

# This little script checks the AD Users of specific groups, if they use a weak password
# The Script returns the bad users

# IMPORTANT: If you have a lockout policy, please set this value to a lower value! Otherwise you lock the users and your Support desk will have fun.
$maxBadPwdCount = 3 
$setPasswordNeverExpiresToFalse = $true
$setChangePasswordAtLogonToTrue = $true

$memberOfGroup1 = "*Microsoft 365*"
$memberOfGroup2 = "*Office 365*"

# Validate credentials
$PasswordToCheck = "mybadpassword123!"

# Nothing to change below this line

$badUsers = @()
[System.Reflection.Assembly]::LoadWithPartialName("System.DirectoryServices.AccountManagement")
$principalContext = New-Object System.DirectoryServices.AccountManagement.PrincipalContext([System.DirectoryServices.AccountManagement.ContextType]::Domain, 'mycorp.local')

# Get-ADUser -Filter * -Properties AccountLockoutTime,LastBadPasswordAttempt,BadPwdCount,LockedOut | Sort-Object -Property LastBadPasswordAttempt -Descending | ogv

Get-ADUser -Filter { BadPwdCount -le $maxBadPwdCount } -Properties BadPwdCount, Memberof | Where-Object { ($_.memberOf -like $memberOfGroup1) -or ($_.memberOf -like $memberOfGroup2) } | ForEach-Object {
    $username = $_.SamAccountName
    #Write-Host($username) -ForeGroundColor Yellow
    $erg = $principalContext.ValidateCredentials($username, $PasswordToCheck)
    if ($erg -eq $true) {
        $badUsers += $username
        Write-Host($username) -ForeGroundColor Red
    } else {
        Write-Host($username) -ForeGroundColor Green
    }
}


if ($setPasswordNeverExpiresToFalse) {
    $badUsers | ForEach-Object { Set-ADUser -Identity $_ -PasswordNeverExpires $false }
}

if ($setChangePasswordAtLogonToTrue) {
    $badUsers | ForEach-Object { Set-ADUser -Identity $_ -ChangePasswordAtLogon $true }
}

return $badUsers