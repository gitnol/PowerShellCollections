<#
.SYNOPSIS
    Findet auf einem Dateiserver Ordner, auf denen einzelne Benutzer statt
    Gruppen berechtigt sind.

.DESCRIPTION
    Liest einmal alle AD-Benutzer-SIDs in eine Hashtable und prueft dann die
    ACLs der Verzeichnisse dagegen. Gemeldet wird, wo ein Eintrag auf eine
    Benutzer-SID zeigt statt auf eine Gruppe.

    Einzelberechtigungen sind die uebliche Ursache dafuer, dass Rechte beim
    Abteilungswechsel nicht mitwandern und beim Austritt nicht entzogen
    werden.

.NOTES
    Der Abgleich ueber eine vorab gefuellte Hashtable vermeidet einen
    Get-ADUser-Aufruf je ACL-Eintrag - bei grossen Freigaben ist das der
    Unterschied zwischen Minuten und Stunden.
#>

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