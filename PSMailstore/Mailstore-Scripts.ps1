$myScriptpath = if ($PSScriptRoot) { $PSScriptRoot }else { (Get-Location) }

Import-Module ActiveDirectory
Import-Module "$myScriptpath\API-Wrapper\MS.PS.Lib.psd1"

function Get-MailstoreAndExchangeUsers {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, ValueFromPipeline = $false, ValueFromPipelineByPropertyName = $false)]
        $allusers
    )
    # Ensure the Active Directory module is imported
    Import-Module ActiveDirectory
	
    # Get all users with a non-empty email address
    $usersWithEmail = Get-ADUser -Filter { EmailAddress -like "*" } -Property EmailAddress
	
    $usersWithEmail | ForEach-Object {
        $groupmemberDN = $_.distinguishedName
        $groupmemberName = $_.Name
        $groupmemberSamAccountName = $_.samAccountName
        $CheckMailStoreUser = $allusers | Where-Object distinguishedName -eq $groupmemberDN
        if ($CheckMailStoreUser) {
            [pscustomobject]@{
                MailstoreUserFound	= $true
                distinguishedName  = $groupmemberDN
                Name               = $groupmemberName
                samAccountName     = $groupmemberSamAccountName
            }
        } else {
            [pscustomobject]@{
                MailstoreUserFound	= $false
                distinguishedName  = $groupmemberDN
                Name               = $groupmemberName
                samAccountName     = $groupmemberSamAccountName
            }
        }
    }
}

function Get-MSUserPriviledgesOnFolder {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $false, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
        [string]$userName = "*",
        [Parameter(Mandatory = $false)] # Todo: ggf. , ValueFromPipeline=$true, ValueFromPipelineByPropertyName=$true in Betracht ziehen.
        [string]$folder = "*",
        [Parameter(Mandatory = $true)]
        $msapiclient
    )
    process {
        if($userName -eq '*'){
            Get-MSUsers -msapiclient $msapiclient | ForEach-Object {
                $userName = $_.userName
                (Get-MSUserInfo -msapiclient $msapiclient -userName $userName).privilegesOnFolders | Where-Object folder -like $folder | ForEach-Object {
                    [PSCustomObject]@{
                        userName = $userName
                        folder = $_.folder
                        privileges = $_.privileges
                    }
                }
            }
        }
        if($userName -ne '*'){
            (Get-MSUserInfo -userName $userName -msapiclient $msapiclient).privilegesOnFolders | Where-Object folder -like $folder | ForEach-Object {
                [PSCustomObject]@{
                    userName = $userName
                    folder = $_.folder
                    privileges = $_.privileges
                }
            }
        }
    }
}

function Set-MSUserPrivilegesOnFolder {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
        [string]$userName,
        [Parameter(Mandatory = $true)]
        [string]$folder,
        [Parameter(Mandatory = $true)]
        [string]$privileges,
        [Parameter(Mandatory = $true)]
        $msapiclient
    )
    process {
        $allprivs = $privileges -split ","
        $allprivs | ForEach-Object {
            if ($_ -notin @('none', 'read', 'write', 'delete')) {
                throw "Priviledges MUST contain only 'none','read','write','delete'"
            }
        }
        $SetUserPrivilegesOnFolder = (Invoke-MSApiCall $msapiclient "SetUserPrivilegesOnFolder"  @{userName = $userName; folder = $folder; privileges = $privileges }).result
        $SetUserPrivilegesOnFolder
    }
}

function Get-MSActiveSessions {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        $msapiclient
    )
    process {
        $GetActiveSessions = (Invoke-MSApiCall $msapiclient "GetActiveSessions").result
        $GetActiveSessions
    }
}

function Get-MSComplianceConfiguration {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        $msapiclient
    )
    process {
        $GetComplianceConfiguration = (Invoke-MSApiCall $msapiclient "GetComplianceConfiguration").result
        $GetComplianceConfiguration
    }
}

function Get-MSCredentials {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        $msapiclient
    )
    process {
        $GetCredentials = (Invoke-MSApiCall $msapiclient "GetCredentials").result
        $GetCredentials
    }
}

function Get-MSDirectoryServicesConfiguration {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        $msapiclient
    )
    process {
        $GetDirectoryServicesConfiguration = (Invoke-MSApiCall $msapiclient "GetDirectoryServicesConfiguration").result
        $GetDirectoryServicesConfiguration
    }
}

function Get-MSFolderStatistics { # IMPORTANT: This command will last very long. ToDo: Implement "Handling Asynchronous API Call" from here: https://help.mailstore.com/de/server/PowerShell_API-Wrapper_Tutorial
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        $msapiclient
    )
    process {
        $GetFolderStatistics = (Invoke-MSApiCall $msapiclient "GetFolderStatistics").result
        $GetFolderStatistics
    }
}

function Get-MSJobs {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        $msapiclient
    )
    process {
        $GetJobs = (Invoke-MSApiCall $msapiclient "GetJobs").result
        $GetJobs
    }
}

function Get-MSLicenseInformation {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        $msapiclient
    )
    process {
        $GetLicenseInformation = (Invoke-MSApiCall $msapiclient "GetLicenseInformation").result
        $GetLicenseInformation
    }
}

function Get-MSRetentionPolicies {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        $msapiclient
    )
    process {
        $GetRetentionPolicies = (Invoke-MSApiCall $msapiclient "GetRetentionPolicies").result
        $GetRetentionPolicies
    }
}

function Get-MSServerInfo {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        $msapiclient
    )
    process {
        $GetServerInfo = (Invoke-MSApiCall $msapiclient "GetServerInfo").result
        $GetServerInfo
    }
}

function Get-MSServiceConfiguration {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        $msapiclient
    )
    process {
        $GetServiceConfiguration = (Invoke-MSApiCall $msapiclient "GetServiceConfiguration").result
        $GetServiceConfiguration
    }
}

function Get-MSSmtpSettings {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        $msapiclient
    )
    process {
        $GetSmtpSettings = (Invoke-MSApiCall $msapiclient "GetSmtpSettings").result
        $GetSmtpSettings
    }
}

function Get-MSStoreAutoCreateConfiguration {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        $msapiclient
    )
    process {
        $GetStoreAutoCreateConfiguration = (Invoke-MSApiCall $msapiclient "GetStoreAutoCreateConfiguration").result
        $GetStoreAutoCreateConfiguration
    }
}

function Get-MSTimeZones {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        $msapiclient
    )
    process {
        $GetTimeZones = (Invoke-MSApiCall $msapiclient "GetTimeZones").result
        $GetTimeZones
    }
}

function Get-MSUsers {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        $msapiclient
    )
    process {
        $GetAllUsers = (Invoke-MSApiCall $msapiclient "GetUsers").result
        $GetAllUsers
    }
}

function Get-MSUserInfo {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
        [string]$userName, # hier sollten der userName übergeben werden.
        [Parameter(Mandatory = $true)]
        $msapiclient
    )
    process {
        $GetUserInfo = (Invoke-MSApiCall $msapiclient "GetUserInfo"  @{userName = $userName}).result
        # Invoke-MSApiCall -MSApiClient $msapiclient -ApiFunction "GetUserInfo" -ApiFunctionParameters @{userName = $userName}
        $GetUserInfo
    }
    # $GetUserInfo.privilegesOnFolders beinhaltet die Berechtigungen für andere Ordner
}

function New-MSUser {
    # Example: New-MSUser -userName 'testuser' -privileges export,archive,changePassword -authentication integrated -loginPrivileges none,api,imap
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$userName,

        [Parameter(Mandatory = $true, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
        [ValidateNotNullOrEmpty()]
        [ValidateSet('none', 'admin', 'login', 'changePassword', 'archive', 'modifyArchiveProfiles', 'export', 'modifyExportProfiles', 'delete')]
        [string[]]$privileges,

        [Parameter(Mandatory = $false, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$fullName,

        [Parameter(Mandatory = $false, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
        [string]$distinguishedName,

        [Parameter(Mandatory = $false, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
        [ValidateSet("integrated", "directoryServices")]
        [string]$authentication = "integrated",

        [Parameter(Mandatory = $false, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
        [string]$password,

        [Parameter(Mandatory = $true, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
        [ValidateNotNullOrEmpty()]
        [ValidateSet('none', 'windows', 'web', 'outlook', 'windowsCmd', 'imap', 'api')]
        [string[]]$loginPrivileges
    )
    process {

        $validPrivileges = @('none', 'admin', 'login', 'changePassword', 'archive', 'modifyArchiveProfiles', 'export', 'modifyExportProfiles', 'delete')
        $privileges | ForEach-Object {
            if ($_ -cnotin $validPrivileges) {
                throw "priviledges MUST contain only 'none', 'admin', 'login', 'changePassword', 'archive', 'modifyArchiveProfiles', 'export', 'modifyExportProfiles', 'delete'"
            }
        }

        $validLoginPrivileges = @('none', 'windows', 'web', 'outlook', 'windowsCmd', 'imap', 'api')
        $loginPrivileges | ForEach-Object {
            if ($_ -cnotin $validLoginPrivileges) {
                throw "loginPrivileges MUST contain only 'none', 'windows', 'web', 'outlook', 'windowsCmd', 'imap', 'api'"
            }
        }
            
        # Prepare the parameters
        $params = @{
            userName          = $userName
            privileges        = $privileges -join ','
            fullName          = $fullName
            distinguishedName = $distinguishedName
            authentication    = $authentication
            password          = $password
            loginPrivileges   = $loginPrivileges -join ','
        }
        
        # $params
        return (Invoke-MSApiCall -MSApiClient $msapiclient -ApiFunction "CreateUser" -ApiFunctionParameters $params)
        # error           : wenn statusCode = failed, dann stehen hier weitere Infos drin.
        # token           :
        # statusVersion   : 2
        # statusCode      : succeeded  oder failed
        # percentProgress :
        # statusText      :
        # result          :
        # logOutput       :
    }
}

function Get-MSUsersPrivileges {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        $msapiclient
    )
    process {
        # Privilegien aller Users auf andere Ordner
        Get-MSUsers -msapiclient $msapiclient | Get-MSUserInfo -msapiclient $msapiclient | ForEach-Object {
            $userName = $_.userName
            $privilegesOnFolders = $_.privilegesOnFolders
            $privilegesOnFolders | ForEach-Object {
                $folder = $_.folder
                $privilegesOnFolder = $_.privileges
                [PSCustomObject]@{
                    userName           = $userName
                    folder             = $folder
                    privilegesOnFolder = $privilegesOnFolder
                }
            }
        }
    }
}


# $servername = localhost
if (-not $servername) {
    $servername = Read-Host -Prompt "Please input the Mailstore servername"
}

if (-not $credential) {
    $credential = (Get-Credential -Message "Please input the Mailstore credentials with api access rights (admin)")
}

Try {
    $msapiclient = New-MSApiClient -Credentials $credential -MailStoreServer $servername -Port 8463 -IgnoreInvalidSSLCerts
    
    if ($msapiclient) {
        # Das hier sind alle SharedMailbox User innerhalb von Mailstore
        $allusers = Get-MSUsers -msapiclient $msapiclient
        $allusers
        $users = $allusers | Where-Object UserName -like "sharedmailbox*" # Hier ist in distinguishedName der gruppenname, den man holen muss.
        $users | Out-GridView -Title "All filtered user elements"
        # $myusertest = 'myusertest'
        # $targetfolder = 'sharedmailboxinvoice'
        # $targetprivileges = 'read' # Valid settings: none,read,write,delete
            # Set priviledges for user on a specific folder
        # Set-MSUserPrivilegesOnFolder -userName $myusertest -folder $targetfolder -privileges $targetprivileges -msapiclient $msapiclient
        
        # Remove priviledges for user on a specific folder
        # $targetprivileges = 'none'
        # Set-MSUserPrivilegesOnFolder -userName 'myuser' -folder $targetfolder -privileges $targetprivileges -msapiclient $msapiclient
        
        # Get the priviledges of every user on the target folder with their priviledges
        Get-MSUsersPrivileges -msapiclient $msapiclient | Out-GridView -Title "Get-MSUsersPrivileges"

        # Get specific priviledges of a user to a target folder
        Get-MSUserPriviledgesOnFolder -userName 'myuser' -folder 'sharedmailboxinvoice'  -msapiclient $msapiclient
        
        # Get all users with their specific priviledges to a target folder
        Get-MSUserPriviledgesOnFolder -folder 'sharedmailboxinvoice' -msapiclient $msapiclient

        # Get-Specific UserInfo
        $allusers | Where-Object { ($_.userName -eq 'myuser2') -or ($_.userName -eq 'myuser2') } | Get-MSUserInfo -msapiclient $msapiclient

        # Get All Users from ActiveDirectory with an emailaddress and check if their DN is within $allusers
        $result = Get-MailstoreAndExchangeUsers -allusers $allusers
        $result | Where-Object MailstoreUserFound -eq $false | Out-GridView -Title "Exchange/Mail User WITHOUT Mailstore User"
        $result | Where-Object MailstoreUserFound -eq $true | Out-GridView -Title "Exchange/Mail User WITH Mailstore User"
    }

}
catch {
    Write-Host "Exception Message: $($_.Exception.Message)"
    Write-Host "Inner Exception: $($_.Exception.InnerException)"
    Write-Host "Inner Exception Message: $($_.Exception.InnerException.Message)"
}
