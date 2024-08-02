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
$principalContext = New-Object System.DirectoryServices.AccountManagement.PrincipalContext([System.DirectoryServices.AccountManagement.ContextType]::Domain, 'lewa-attendorn.local')

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