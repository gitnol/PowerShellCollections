Import-Module ActiveDirectory
# 1x alle Benutzer-Accounts in Hashtable
$UserAccounts = @{}

Get-ADUser -Filter * -Properties SamAccountName | ForEach-Object {
    $UserAccounts["$($_.SID)"] = $true
}

#$acl.Access | Where-Object {
#    $sid = $_.IdentityReference.Translate([System.Security.Principal.SecurityIdentifier]).Value
#    $UserAccounts.ContainsKey($sid)
#}

Get-ChildItem -Path N:\ -Recurse -Depth 3 -Directory | ForEach-Object {
    $pfad = $_.Fullname
    $acl = Get-Acl $pfad 
    $myaccess = $acl.Access | Where-Object {
        $sid = $_.IdentityReference.Translate([System.Security.Principal.SecurityIdentifier]).Value
        $UserAccounts.ContainsKey($sid)
    } 
    if ($myaccess -and (-not $acl.AreAccessRulesProtected)) {
        [PSCustomObject]@{Pfad = $pfad; Identity = $myaccess.IdentityReference.Value }
    }
}