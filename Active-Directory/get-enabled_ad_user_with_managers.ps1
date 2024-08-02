# Import the Active Directory module
Import-Module ActiveDirectory

$SearchScope = "Subtree" # Base or 0 # OneLevel or 1 # Subtree or 2
# Search for users in the following OU
$SearchBase = "OU=USRMGMT,OU=ITMGMT,DC=mycorp,DC=local"

# Get all users from Active Directory
$allUsers = Get-ADUser -SearchBase $SearchBase -Filter {Enabled -eq $true} -SearchScope $SearchScope -Property DisplayName, Manager, SamAccountName, Description

# Create an array to hold the results
$results = @()

foreach ($user in $allUsers) {
    # Initialize a hashtable to store the user's information
    $userInfo = [PSCustomObject]@{
        SamAccountName        = $user.SamAccountName
        FullName              = $user.DisplayName
		Description              = $user.Description
        ManagerSamAccountName = ""
        ManagerFullName       = ""
		ManagerDescription    = ""
    }

    # Get the manager's information if it exists
    if ($user.Manager) {
        $manager = Get-ADUser -Identity $user.Manager -Property DisplayName, SamAccountName
        $userInfo.ManagerSamAccountName = $manager.SamAccountName
        $userInfo.ManagerFullName       = $manager.DisplayName
		$userInfo.ManagerDescription    = $manager.Description
    }

    # Add the user's information to the results array
    $results += $userInfo
}

# Convert the results to a formatted table and output it
# $results | Format-Table -Property SamAccountName, FullName, ManagerSamAccountName, ManagerFullName -AutoSize
$results | Out-GridView

