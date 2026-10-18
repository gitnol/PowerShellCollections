<#
.SYNOPSIS
    Findet Mitglieder einer Gruppe, die sich seit laengerem nicht angemeldet
    haben - etwa zur Rueckgewinnung von Microsoft-365-Lizenzen.

.DESCRIPTION
    Filtert ueber LDAP alle Mitglieder einer Gruppe, deren
    lastLogonTimestamp aelter als der Schwellwert ist oder die noch nie
    gesetzt wurde. Vorgabe sind 100 Tage.

.NOTES
    lastLogonTimestamp wird absichtlich nur alle 9 bis 14 Tage repliziert.
    Der Wert ist deshalb systematisch zu alt und taugt nur fuer grobe
    Schwellen wie hier - fuer eine genaue Angabe braucht es lastLogon ueber
    alle DCs (siehe Get-ADComputerLastLogon.ps1 fuer das gleiche Problem bei
    Computern).

    Hintergrund:
    https://techcommunity.microsoft.com/t5/ask-the-directory-services-team/8220-the-lastlogontimestamp-attribute-8221-8211-8220-what-it-was/ba-p/396204
#>

# This Script helps to identify, which Office 365 or Microsoft 365 Licenses could perhaps be available for reuse.
# It identifies the users which haven't logged on or which have a LastLogonTimestamp older than 100 days
# perfect to manually check. This out grid view list should always be empty.

# Import the Active Directory module
Import-Module ActiveDirectory

$groupName = "Office 365"
$groupDN = (Get-ADGroup -Identity $groupName).DistinguishedName

$inactivityThreshold = 100
# Calculate the date 100 days ago
# https://techcommunity.microsoft.com/t5/ask-the-directory-services-team/8220-the-lastlogontimestamp-attribute-8221-8211-8220-what-it-was/ba-p/396204
$date_100_days_ago = (Get-Date).AddDays(-$inactivityThreshold ).ToFileTime()

# Construct the LDAP filter
$ldapFilter = "(&(memberOf=$groupDN)(|(lastLogonTimestamp<=$date_100_days_ago)(!lastLogonTimestamp=*)))"

# Use the filter with Get-ADUser
# Get-ADUser -LDAPFilter $ldapFilter -Property Name,LastLogonDate,Enabled,SamAccountName | Select Name,LastLogonDate,Enabled,SamAccountName | ogv

# Retrieve all domain controllers in the domain
$domainControllers = Get-ADDomainController -Filter *

$allUsers = @()

foreach ($dc in $domainControllers) {
$dcName = $dc.HostName
# Get all members of the group
$userMembers = Get-ADUser -LDAPFilter $ldapFilter -Property Name,LastLogonDate,Enabled,SamAccountName -Server $dcName| Select-Object Name,LastLogonDate,Enabled,SamAccountName
$allUsers += $userMembers
}

$allUsers | Select-Object Name,SamAccountName,Enabled,LastLogonDate | Sort-Object -Property Name,LastLogonDate -Unique | Out-GridView -Title "Members of the group $groupName with $inactivityThreshold days inactivity or without an logon."

