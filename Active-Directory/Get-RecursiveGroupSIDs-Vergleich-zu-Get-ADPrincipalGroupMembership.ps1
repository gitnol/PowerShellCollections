$userDN = "myuser"
$GroupsOfUser = Get-ADPrincipalGroupMembership -Identity $userDN 

$user = Get-ADUser -Identity $UserDN -Properties MemberOf, SIDHistory
$groups = @()
foreach ($groupDN in $user.MemberOf) {
$groupDN

}
# ($user.MemberOf).count

#$GroupsOfUser.DistinguishedName | Sort-Object -Unique
#$user.MemberOf | Sort-Object -Unique | Where {$_ -like "*n-benutzer*"}


function Get-RecursiveGroupSIDs {
    param (
        [string]$GroupDN,
        [System.Collections.Generic.HashSet[string]]$ProcessedGroups = (New-Object 'System.Collections.Generic.HashSet[string]')
    )

    # Prüfen, ob die Gruppe bereits verarbeitet wurde
    if ($ProcessedGroups.Contains($GroupDN)) { return @() }
    [void]$ProcessedGroups.Add($GroupDN)

    # AD-Gruppe abrufen
    $group = Get-ADGroup -Identity $GroupDN -Properties Members, groupScope, distinguishedName
    $groupInfo = [PSCustomObject]@{
        SID    = $group.SID.Value
        Scope  = $group.groupScope
        Domain = ($group.distinguishedName -split ',DC=')[1]
        GroupName = $group.Name
        GroupSamAccountName = $group.samAccountName
    }

    $groupSIDs = @($groupInfo)

    # Mitglieder der Gruppe durchlaufen
    foreach ($member in $group.Members) {
        $memberObject = Get-ADObject -Identity $member -Properties objectClass
        if ($memberObject.objectClass -eq "group") {
            # Wenn Mitglied eine Gruppe ist, rekursiv weitersuchen
            $groupSIDs += Get-RecursiveGroupSIDs -GroupDN $member -ProcessedGroups $ProcessedGroups
        }
    }

    return $groupSIDs
}

(Get-RecursiveGroupSIDs -GroupDN 20-Projektleitung-Schreibzugriff | Select-Object GroupName | Sort-Object -Property GroupName).Count

Get-ADPrincipalGroupMembership -Identity myuser | Out-GridView -Title "Get-ADPrincipalGroupMembership"
ist identisch zu 
$myUsers | Where-Object member -eq "myuser" | Select-Object inGroup | Sort-Object -Unique -Property inGroup | Out-GridView