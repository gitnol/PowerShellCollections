Import-Module ActiveDirectory

# SearchScope should be limited to OneLevel if possible.
$SearchScope = "OneLevel" # Base or 0 # OneLevel or 1 # Subtree or 2
# Search for groups in the following OU
$SearchBase = "OU=Projektstruktur,OU=GRPMGMT,OU=ITMGMT,DC=mycorp,DC=local"
# Limit to group names that contain the following string (* can be used as a wildcard)
$GroupFilter = "*"

$mygroups = Get-ADGroup -SearchBase $SearchBase -Filter {Name -like $GroupFilter} -SearchScope $SearchScope

function Get-ADGroupMembersRecursive {
    param (
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [string]$GroupName
    )

    function Get-Members {
        param (
            [Parameter(Mandatory = $true)]
            [string]$GroupName,
            [Parameter(Mandatory = $true)]
            [int]$Level, # Which level are we at?
            [Parameter(Mandatory = $false)]
            [string]$SourceGroupName = '', # where did the call come from
            [Parameter(Mandatory = $false)]
            [string]$Breadcrumb = '' # Track recursive group memberships
        )
        $userList = @()

        $members = Get-ADGroupMember -Identity $GroupName
        foreach ($member in $members) {
            if ($member.objectClass -eq 'user') {
                $userList += [pscustomobject]@{
                    member = $member.SamAccountName
                    inGroup = $GroupName
                    SourceGroupName = $SourceGroupName
                    level = $Level
                    breadcrumb = ($Breadcrumb + "->[user]" + $member.SamAccountName)
                }
            } elseif ($member.objectClass -eq 'group') {
                $newLevel = $Level + 1
                $newBreadcrumb = $Breadcrumb + "->" + $member.SamAccountName
                $nestedGroupMembers = Get-Members -GroupName $member.SamAccountName -Level $newLevel -SourceGroupName $GroupName -Breadcrumb $newBreadcrumb
                $userList += $nestedGroupMembers # At this point, only user objects are in $nestedGroupMembers
            }
        }
        return $userList
    }

    $userList = @()
    $userList += Get-Members -GroupName $GroupName -Level 0 -Breadcrumb $GroupName
    return $userList
}

Write-Host('Warning: The following step can take a very long time, depending on the size of $mygroups and the recursion depth!') -ForegroundColor Red
$myUsers = ($mygroups | % {Get-ADGroupMembersRecursive -GroupName $_.Name}) # Recursively resolve the groups
$myUsers | where member -eq bde01 # see if a user and how a user obtained the permissions!
$maxlevel = $myUsers.level | Sort-Object -Unique -Descending | Select-Object -First 1
$myUsers | ogv
Write-Host('Max Level: ' + $maxlevel) -ForegroundColor Red
