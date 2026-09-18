
# Change the two lines if you do not want to input it
$user1default = "my.user1"
$user2default = "my.user2"

# do not change anything below this line
$user1 = ""
$user1 = ""
if (!($user1 = Read-Host ("Please enter User 1: [$user1default]"))) { $user1 = $user1default }
if (!($user2 = Read-Host ("Please enter User 2: [$user2default]"))) { $user2 = $user2default }

# Replace double Wildcards with a single one
$user1 = ("*" + $user1 + "*").Replace('**', '*')
$user2 = ("*" + $user2 + "*").Replace('**', '*')
Write-Host("{0} and {1} will be searched..." -f $user1,$user2) -ForegroundColor Green
# Now get the AD Users
$user1ADObjects = get-aduser -Filter * -Properties MemberOf | Where-Object { ($_.Name -like $user1) -or ($_.samAccountName -like $user1) }
$user2ADObjects = get-aduser -Filter * -Properties MemberOf | Where-Object { ($_.Name -like $user2) -or ($_.samAccountName -like $user2) }

# If the result contain more than one user, choose one
if ($user1ADObjects.Count -ge 2) {
    $user1auswahl = $user1ADObjects | Out-GridView -Title "More than one possible User. Please choose User 1" -PassThru
}

if ($user2ADObjects.Count -ge 2) {
    $user2auswahl = $user2ADObjects | Out-GridView -Title "More than one possible User. Please choose User 2" -PassThru
}

# Vergleichen der User
if ($user1auswahl -and $user2auswahl) {
    Write-Host("Group memberships of {0} and {1} will be compared..." -f $user1auswahl.Name,$user2auswahl.Name) -ForegroundColor Green
    $groupsUser1 = $user1auswahl.MemberOf | Get-ADGroup
    $groupsUser2 = $user2auswahl.MemberOf | Get-ADGroup

    $comparision = Compare-Object -ReferenceObject $groupsUser1  -DifferenceObject $groupsUser2 -Property Name
    $comparision  | Out-GridView -Title ($user1auswahl.Name + " <-> " + $user2auswahl.Name)
}

if ((-not $PSScriptRoot) -or ($PSVersionTable.PSVersion.Major -le 5)) {Read-Host("Press enter")} # for < Powershell 7

