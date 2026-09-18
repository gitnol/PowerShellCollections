function Copy-ADGroupMembers {
    param (
        [Parameter(Mandatory = $true)]
        [string]$SourceGroup,

        [Parameter(Mandatory = $true)]
        [string]$TargetGroup
    )

    $sourceMembers = Get-ADGroupMember -Identity $SourceGroup -Recursive

    foreach ($member in $sourceMembers) {
        try {
            Add-ADGroupMember -Identity $TargetGroup -Members $member.SamAccountName -ErrorAction Stop
            Write-Host "Hinzugefügt: $($member.SamAccountName) zu $TargetGroup"
        }
        catch {
            Write-Warning "Fehler beim Hinzufügen von $($member.SamAccountName): $_"
        }
    }
}
