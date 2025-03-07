Import-Module ActiveDirectory

# $DomainName = "mycorp" # CaseSensitive
$TopLevelDomainName = "local" # CaseSensitive
# SearchScope should be limited to OneLevel if possible. (or limit by setting the SeachBase)
# $SearchScope = "OneLevel" 
$SearchScope = "Subtree" # Base (only the queried Item) or 0 # OneLevel (alls item in the OU) or 1 # Subtree (rescursively the OU and all Sub-OUs) or 2
# Search for groups in the following OU
# $SearchBase = "OU=Projektstruktur,OU=GRPMGMT,OU=ITMGMT,DC=$DomainName,DC=$TopLevelDomainName"
$SearchBase = "OU=ITMGMT,DC=$DomainName,DC=$TopLevelDomainName"
# Limit to group names that contain the following string (* can be used as a wildcard)
$GroupFilter = "*"

$mygroups = Get-ADGroup -SearchBase $SearchBase -Filter * -SearchScope $SearchScope | Where-Object Name -like $GroupFilter

function Get-ADGroupMembersRecursive {
    param (
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [string]$GroupName,
        [System.Collections.Generic.Dictionary[string, object]]$ProcessedGroups = (New-Object 'System.Collections.Generic.Dictionary[string, object]')
    )

    function Get-Members {
        param (
            [Parameter(Mandatory = $true)]
            [string]$GroupName, # Group, which should be revolved
            [Parameter(Mandatory = $true)]
            [int]$Level, # Which level are we at?
            [Parameter(Mandatory = $false)]
            [string]$SourceGroupName = '', # where did the call come from
            [Parameter(Mandatory = $false)]
            [string]$Breadcrumb = '', # Track recursive group memberships
            [Parameter(Mandatory = $true)]
            [System.Collections.Generic.Dictionary[string, object]]$ProcessedGroups
        )

        $userList = @()

        # Check if group has already been processed
        if ($ProcessedGroups.ContainsKey($GroupName)) {

            # Arriving at this point, the group has been seen before.
            # Write-Host("")
            # Write-Host("What kind of group are we examining (GroupName): “ + $GroupName) -ForegroundColor Red
            # Write-Host("Where do we come from (SourceGroupName)        : “ + $SourceGroupName) -ForegroundColor Red
            # Write-Host("Total path so far (breadcrumb)                 : ” + $Breadcrumb) -ForegroundColor Red

            # The MinLevel is required to determine the number that is added to the current level $level
            # Example: $_.level - $MinLevel results in 0 if it is the lowest level
            # Therefore: ($_.level - $MinLevel) + $level gives the correct level
            $MinLevel = ($ProcessedGroups[$GroupName].level | Measure-Object -Minimum).Minimum
            
            # Was it a cached group? 
            Write-Host("CG-") -NoNewline -ForegroundColor Green

            $ProcessedGroups[$GroupName] | ForEach-Object {
                $userList += [pscustomobject]@{
                    member          = $_.member
                    inGroup         = $_.inGroup # same like $GroupName
                    SourceGroupName = $SourceGroupName # not use $_.SourceGroupName, because it has changed!
                    level           = [int](($_.level - $MinLevel) + $level) # calculate new level based on the $MinLevel (see above)
                    # Search the Group in the current breadcrumb (because of recursion, there could be groups in groups... therefore it should be replaced)
                    # $dasWasZuErsetzenIst = ($_.breadcrumb -split "->")[0..(($_.breadcrumb -split "->").IndexOf($GroupName))] -join "->"
                    # ist das Gleiche wie
                    # $dasWasZuErsetzenIst = ($_.breadcrumb -match '^.*?->' + $GroupName + '->') ? $matches[0] : $null
                    breadcrumb      = $_.breadcrumb -replace ('^.*?->' + $GroupName + '->'), ($breadcrumb + "->") # New breadcrumb is the old breadcrumb replaced up to the point, where to groupname first appears
                    cached          = $true # this is not $false anymore... it is good to know, if this was cached or not.
                }
            }
            return $userList

        } else {
            # Was it a New Group? 
            Write-Host("NG-") -NoNewline -ForegroundColor Yellow
            # Write-Host("")
            # Write-Host("What kind of group are we examining (GroupName): “ + $GroupName) -ForegroundColor Blue
            # Write-Host("Where do we come from (SourceGroupName)        : “ + $SourceGroupName) -ForegroundColor Blue
            # Write-Host("Total path so far (breadcrumb)                 : ” + $Breadcrumb) -ForegroundColor Blue

            # If this $groupName is NOT cached, resolve the users and groups und call this function recursively if it is of type group.
            Try { 
                # If an foreigenSecurityPrincipal is in a Group and the DN can not be resolved by the other domain controller, an error occures in Get-ADGroupMember. 
                # One example could be an orphaned SID
                # You have to take a look here: CN=ForeignSecurityPrincipals,DC=AB,DC=local
                # I something can not be resolved, it should be deleted
                $members = Get-ADGroupMember -Identity $GroupName -ErrorAction Stop
                foreach ($member in $members) {
                    $IsForeignSecurityPrincipal = $false
                    if (($member.distinguishedName -split ',DC=')[1] -ne $DomainName) {
                        $IsForeignSecurityPrincipal = $true;
                        #Write-Host($member.distinguishedName -split ',DC=')[1]
                    }
                    if ($member.objectClass -eq 'user') {
                        $userList += [pscustomobject]@{
                            member          = $member.SamAccountName
                            inGroup         = $GroupName
                            SourceGroupName = $SourceGroupName
                            level           = $Level
                            breadcrumb      = ($Breadcrumb + "->[user]" + $member.SamAccountName)
                            cached          = $false
                        }
                    }
                    elseif ($member.objectClass -eq 'group' -and (-not $IsForeignSecurityPrincipal)) {
                        $newLevel = $Level + 1
                        $newBreadcrumb = $Breadcrumb + "->" + $member.SamAccountName # Here: The Groupname is being added to the breadcrumb
                        $nestedGroupMembers = Get-Members -GroupName $member.SamAccountName -Level $newLevel -SourceGroupName $GroupName -Breadcrumb $newBreadcrumb -ProcessedGroups $ProcessedGroups
                        $userList += $nestedGroupMembers # At this point, only user objects are in $nestedGroupMembers
                    }
                }
            }
            Catch {
                Write-Host("") -ForegroundColor Yellow
                Write-Host("Fehler in: " + $GroupName) -ForegroundColor Yellow
                Write-Host("SourceGroupName: " + $Breadcrumb ) -ForegroundColor Yellow
                Write-Host("Breadcrumb: " + $Breadcrumb ) -ForegroundColor Yellow

                return $userList
            }
            # Cache results of the Group
            $ProcessedGroups[$GroupName] = $userList
            return $userList
        } # End of Else
    }

    $userList = @()
    # The next line returns the list of all users in the group and subgroups and returns the dependencies, from which source the user is in what group and give an exact explanation in form of breadcrumbs
    $userList += Get-Members -GroupName $GroupName -Level 0 -Breadcrumb $GroupName -ProcessedGroups $ProcessedGroups
    return $userList
}

Write-Host('Warning: The following step can take a very long time, depending on the size of $mygroups and the recursion depth!') -ForegroundColor Red
$myUsers = ($mygroups | ForEach-Object { Get-ADGroupMembersRecursive -GroupName $_.SamAccountName }) # Recursively resolve the groups

# $myUsers | Where-Object member -eq bde01 # see if a user and how a user obtained the permissions!
$maxlevel = $myUsers.level | Sort-Object -Unique -Descending | Select-Object -First 1
$myUsers | Out-GridView -Title "All Users and Group Memberships"
# $indexedMyUsers | Out-GridView -Title "All Users and Group Memberships (indexiert)"
Write-Host('Max Level: ' + $maxlevel) -ForegroundColor Red

# # Caution: Takes a long time: Returns the number of authorizations for a user. Is an indication of too many useless authorizations 
# $gesamtanzahl = $myUsers.member | Sort-Object -Unique | % { [pscustomobject]@{member=$_;Anzahl=($myUsers | Where member -eq $_ | Measure-Object).Count}}

# Get-ADPrincipalGroupMembership -Identity myuser

# Idee ProcessedGroups könnte man um die AD Property der Gruppe erweitern und modifyTimeStamp mit abspeichern, um viele Abfragen an das AD zu reduzieren.
Get-ADGroup -Identity "AG_Personal_R" -Properties samAccountName,modifyTimeStamp | Select-Object samAccountName,modifyTimeStamp

$myUsers | Group-Object -Property breadcrumb | Where-Object Count -gt 1 | Select-Object -ExpandProperty name