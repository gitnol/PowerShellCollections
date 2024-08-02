# This Script helps to identify, which Office 365 or Microsoft 365 Licenses could perhaps be available for reuse.
# It identifies the users which haven't logged on or which have a LastLogonTimestamp older than 100 days
# perfect to manually check. This out grid view list should always be empty.

# Import the Active Directory module
Import-Module ActiveDirectory

$groupName = "Office 365"
$groupDN = (Get-ADGroup -Identity "Office 365").DistinguishedName

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

