# # ---------------------------------------------------------------- #
# # Private Methods                                                  #
# # ---------------------------------------------------------------- #
# _self_test
# _server_has_method
# _method_requires_instance_id
# call
# HandleToken
# YieldStatus
# # ---------------------------------------------------------------- #
# # Public Methods                                                   #
# # ---------------------------------------------------------------- #
# GetStatus
# CancelAsync
# GetMetadata
# # ---------------------------------------------------------------- #
# # Wrapped Administration API methods                               #
# # ---------------------------------------------------------------- #

#region Users
# # ---------------------------------------------------------------- #
# # Users                                                            #
# # ---------------------------------------------------------------- #
# GetUsers
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

# GetUserInfo
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

# SetUserAuthentication
function Set-MSUserAuthentication {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $True, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
        [string]$userName,

        [Parameter(Mandatory = $True, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
        [string]$authentication,

        [Parameter(Mandatory = $true)]
        $msapiclient
    )
    process {
        $SetUserAuthentication = (Invoke-MSApiCall -MSApiClient $msapiclient -ApiFunction "SetUserAuthentication" -ApiFunctionParameters @{userName = "$userName"; authentication = "$authentication" }).result
        $SetUserAuthentication
    }
}

# SetUserDistinguishedName
function Set-MSUserDistinguishedName {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $True, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
        [string]$userName,

        [Parameter(Mandatory = $False, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
        [string]$distinguishedName,

        [Parameter(Mandatory = $true)]
        $msapiclient
    )
    process {
        $SetUserDistinguishedName = (Invoke-MSApiCall -MSApiClient $msapiclient -ApiFunction "SetUserDistinguishedName" -ApiFunctionParameters @{userName = "$userName"; distinguishedName = "$distinguishedName" }).result
        $SetUserDistinguishedName
    }
}

# SetUserEmailAddresses
function Set-MSUserEmailAddresses {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $True, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
        [string]$userName,

        [Parameter(Mandatory = $False, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
        [string]$emailAddresses,

        [Parameter(Mandatory = $true)]
        $msapiclient
    )
    process {
        $SetUserEmailAddresses = (Invoke-MSApiCall -MSApiClient $msapiclient -ApiFunction "SetUserEmailAddresses" -ApiFunctionParameters @{userName = "$userName"; emailAddresses = "$emailAddresses" }).result
        $SetUserEmailAddresses
    }
}

# SetUserFullName
SetUserFullNamefunction Set-MSUserFullName {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $True, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
        [string]$userName,

        [Parameter(Mandatory = $False, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
        [string]$fullName,

        [Parameter(Mandatory = $true)]
        $msapiclient
    )
    process {
        $SetUserFullName = (Invoke-MSApiCall -MSApiClient $msapiclient -ApiFunction "SetUserFullName" -ApiFunctionParameters @{userName = "$userName"; fullName = "$fullName" }).result
        $SetUserFullName
    }
}

# SetUserLoginPrivileges
function Set-MSUserLoginPrivileges {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $True, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
        [string]$userName,

        [Parameter(Mandatory = $True, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
        [ValidateSet('none', 'windows', 'web', 'outlook', 'windowsCmd', 'imap', 'api')]
        [string]$loginPrivileges,

        [Parameter(Mandatory = $true)]
        $msapiclient
    )
    process {
        $SetUserLoginPrivileges = (Invoke-MSApiCall -MSApiClient $msapiclient -ApiFunction "SetUserLoginPrivileges" -ApiFunctionParameters @{userName = "$userName"; loginPrivileges = "$loginPrivileges" }).result
        $SetUserLoginPrivileges
    }
}

# SetUserPassword
function Set-MSUserPassword {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $True, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
        [string]$userName,

        [Parameter(Mandatory = $True, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
        [string]$password,

        [Parameter(Mandatory = $true)]
        $msapiclient
    )
    process {
        $SetUserPassword = (Invoke-MSApiCall -MSApiClient $msapiclient -ApiFunction "SetUserPassword" -ApiFunctionParameters @{userName = "$userName"; password = "$password" }).result
        $SetUserPassword
    }
}

# InitializeMFA
function Initialize-MSMFA {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $True, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
        [string]$userName,

        [Parameter(Mandatory = $true)]
        $msapiclient
    )
    process {
        $InitializeMFA = (Invoke-MSApiCall -MSApiClient $msapiclient -ApiFunction "InitializeMFA" -ApiFunctionParameters @{userName = "$userName" }).result
        $InitializeMFA
    }
}

# DisableMFA
function Disable-MSMFA {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $True, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
        [string]$userName,

        [Parameter(Mandatory = $true)]
        $msapiclient
    )
    process {
        $DisableMFA = (Invoke-MSApiCall -MSApiClient $msapiclient -ApiFunction "DisableMFA" -ApiFunctionParameters @{userName = "$userName" }).result
        $DisableMFA
    }
}

# DeleteAppPasswords
function Delete-MSAppPasswords {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $True, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
        [string]$userName,

        [Parameter(Mandatory = $true)]
        $msapiclient
    )
    process {
        $DeleteAppPasswords = (Invoke-MSApiCall -MSApiClient $msapiclient -ApiFunction "DeleteAppPasswords" -ApiFunctionParameters @{userName = "$userName" }).result
        $DeleteAppPasswords
    }
}

# SetUserPop3UserNames
function Set-MSUserPop3UserNames {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $True, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
        [string]$userName,

        [Parameter(Mandatory = $False, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
        [string]$pop3UserNames,

        [Parameter(Mandatory = $true)]
        $msapiclient
    )
    process {
        $SetUserPop3UserNames = (Invoke-MSApiCall -MSApiClient $msapiclient -ApiFunction "SetUserPop3UserNames" -ApiFunctionParameters @{userName = "$userName"; pop3UserNames = "$pop3UserNames" }).result
        $SetUserPop3UserNames
    }
}

# SetUserPrivileges
function Set-MSUserPrivileges {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $True, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
        [string]$userName,

        [Parameter(Mandatory = $True, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
        [ValidateSet('none', 'admin', 'login', 'changePassword', 'archive', 'modifyArchiveProfiles', 'export', 'modifyExportProfiles', 'delete')]
        [string]$privileges,

        [Parameter(Mandatory = $true)]
        $msapiclient
    )
    process {
        $SetUserPrivileges = (Invoke-MSApiCall -MSApiClient $msapiclient -ApiFunction "SetUserPrivileges" -ApiFunctionParameters @{userName = "$userName"; privileges = "$privileges" }).result
        $SetUserPrivileges
    }
}

# RenameUser
function Rename-MSUser {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $True, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
        [string]$oldUserName,

        [Parameter(Mandatory = $True, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
        [string]$newUserName,

        [Parameter(Mandatory = $true)]
        $msapiclient
    )
    process {
        $RenameUser = (Invoke-MSApiCall -MSApiClient $msapiclient -ApiFunction "RenameUser" -ApiFunctionParameters @{oldUserName = "$oldUserName"; newUserName = "$newUserName" }).result
        $RenameUser
    }
}

# DeleteUser
function Delete-MSUser {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $True, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
        [string]$userName,

        [Parameter(Mandatory = $true)]
        $msapiclient
    )
    process {
        $DeleteUser = (Invoke-MSApiCall -MSApiClient $msapiclient -ApiFunction "DeleteUser" -ApiFunctionParameters @{userName = "$userName" }).result
        $DeleteUser
    }
}

# SetUserPrivilegesOnFolder
function Set-MSUserPrivilegesOnFolder {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $True, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
        [string]$userName,

        [Parameter(Mandatory = $True, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
        [string]$folder,

        [Parameter(Mandatory = $True, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
        [ValidateSet('none', 'read', 'write', 'delete')]
        [string]$privileges,

        [Parameter(Mandatory = $true)]
        $msapiclient
    )
    process {
        $SetUserPrivilegesOnFolder = (Invoke-MSApiCall -MSApiClient $msapiclient -ApiFunction "SetUserPrivilegesOnFolder" -ApiFunctionParameters @{userName = "$userName"; folder = "$folder"; privileges = "$privileges" }).result
        $SetUserPrivilegesOnFolder
    }
}

# ClearUserPrivilegesOnFolders
function Clear-MSUserPrivilegesOnFolders {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $True, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
        [string]$userName,

        [Parameter(Mandatory = $true)]
        $msapiclient
    )
    process {
        $ClearUserPrivilegesOnFolders = (Invoke-MSApiCall -MSApiClient $msapiclient -ApiFunction "ClearUserPrivilegesOnFolders" -ApiFunctionParameters @{userName = "$userName" }).result
        $ClearUserPrivilegesOnFolders
    }
}

#endregion

#region Directory Services
# # ---------------------------------------------------------------- #
# # Directory Services                                               #
# # ---------------------------------------------------------------- #
# GetDirectoryServicesConfiguration
function Get-MSDirectoryServicesConfiguration {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        $msapiclient
    )
    process {
        $GetDirectoryServicesConfiguration = (Invoke-MSApiCall -MSApiClient $msapiclient -ApiFunction "GetDirectoryServicesConfiguration").result
        $GetDirectoryServicesConfiguration
    }
}

# SetDirectoryServicesConfiguration

# SyncUsersWithDirectoryServices
#endregion

#region Credentials

# # ---------------------------------------------------------------- #
# # Credentials                                                      #
# # ---------------------------------------------------------------- #
# GetCredentials
#endregion

# # ---------------------------------------------------------------- #
# # Compliance                                                       #
# # ---------------------------------------------------------------- #
# GetComplianceConfiguration
# SetComplianceConfiguration
# # ---------------------------------------------------------------- #
# # Retention Policies                                               #
# # ---------------------------------------------------------------- #
# GetRetentionPolicies
# SetRetentionPolicies
# ProcessRetentionPolicies
# # ---------------------------------------------------------------- #
# # SMTP Settings                                                    #
# # ---------------------------------------------------------------- #
# GetSmtpSettings
# SetSmtpSettings
# TestSmtpSettings
# # ---------------------------------------------------------------- #
# # Storage                                                          #
# # ---------------------------------------------------------------- #
# MaintainFileSystemDatabases
# RefreshAllStoreStatistics
# RetryOpenStores
# # ---------------------------------------------------------------- #
# # Archive Stores                                                   #
# # ---------------------------------------------------------------- #
# GetStores
# SetStoreRequestedState
# RenameStore
# DetachStore
# CompactStore
# MergeStore
# RecoverStore
# RecreateRecoveryRecords
# RepairStoreDatabase
# UnlockStore
# UpgradeStore
# UpgradeStores
# VerifyStore
# VerifyStores
# # ---------------------------------------------------------------- #
# # Auto Create Archive Store Configuration                          #
# # ---------------------------------------------------------------- #
# GetStoreAutoCreateConfiguration
# SetStoreAutoCreateConfiguration
# # ---------------------------------------------------------------- #
# # Search Indexes                                                   #
# # ---------------------------------------------------------------- #
# SelectAllStoreIndexesForRebuild
# RebuildSelectedStoreIndexes
# # ---------------------------------------------------------------- #
# # Jobs                                                             #
# # ---------------------------------------------------------------- #
# GetJobs
# GetJobResults
# RenameJob
# SetJobEnabled
# DeleteJob
# RunJobAsync
# CancelJobAsync
# # ---------------------------------------------------------------- #
# # Profiles                                                         #
# # ---------------------------------------------------------------- #
# GetProfiles
# GetWorkerResultReport
# CreateProfile
# RunProfile
# RunTemporaryProfile
# DeleteProfile
# # ---------------------------------------------------------------- #
# # Folders                                                          #
# # ---------------------------------------------------------------- #
# GetFolderStatistics
# GetChildFolders
# MoveFolder
# DeleteEmptyFolders
# # ---------------------------------------------------------------- #
# # Miscellaneous                                                    #
# # ---------------------------------------------------------------- #
# SendStatusReport
# GetTimeZones
# auth_test
# # ---------------------------------------------------------------- #
# # MailStore Server specific API methods                            #
# # ---------------------------------------------------------------- #
# # ---------------------------------------------------------------- #
# # Storage                                                          #
# # ---------------------------------------------------------------- #
# CreateBackup
# CompactMasterDatabase
# RenewMasterKey
# # ---------------------------------------------------------------- #
# # Archive Stores                                                   #
# # ---------------------------------------------------------------- #
# # ---------------------------------------------------------------- #
# # Search Indexes                                                   #
# # ---------------------------------------------------------------- #
# GetStoreIndexes
# RebuildStoreIndex
# # ---------------------------------------------------------------- #
# # Messages                                                         #
# # ---------------------------------------------------------------- #
# GetMessages
# DeleteMessage
# # ---------------------------------------------------------------- #
# # Miscellaneous                                                    #
# # ---------------------------------------------------------------- #
# GetServerInfo
# GetServiceConfiguration
# SetServiceCertificate
# GetActiveSessions
# GetLicenseInformation
# # ---------------------------------------------------------------- #
# # MailStore SPE specific API methods                               #
# # ---------------------------------------------------------------- #
# # ---------------------------------------------------------------- #
# # Management Server                                                #
# # ---------------------------------------------------------------- #
# GetEnvironmentInfo
# GetServiceStatus
# PairWithManagementServer
# # ---------------------------------------------------------------- #
# # Client Access Servers                                            #
# # ---------------------------------------------------------------- #
# GetClientAccessServers
# CreateClientAccessServer
# SetClientAccessServerConfiguration
# DeleteClientAccessServer
# # ---------------------------------------------------------------- #
# # Instance Hosts                                                   #
# # ---------------------------------------------------------------- #
# GetInstanceHosts
# CreateInstanceHost
# SetInstanceHostConfiguration
# GetDirectoriesOnInstanceHost
# CreateDirectoryOnInstanceHost
# DeleteInstanceHost
# # ---------------------------------------------------------------- #
# # Instances                                                        #
# # ---------------------------------------------------------------- #
# GetInstances
# CreateInstance
# GetInstanceConfiguration
# SetInstanceConfiguration
# StartInstances
# RestartInstances
# StopInstances
# FreezeInstances
# ThawInstances
# GetInstanceStatistics
# GetInstanceProcessLiveStatistics
# DeleteInstances
# # ---------------------------------------------------------------- #
# # Service Provider Access                                          #
# # ---------------------------------------------------------------- #
# GetArchiveAdminEnabled
# SetArchiveAdminEnabled
# CreateClientOneTimeUrlForArchiveAdmin
# # ---------------------------------------------------------------- #
# # Storage                                                          #
# # ---------------------------------------------------------------- #
# CanRunArchiveProfiles
# # ---------------------------------------------------------------- #
# # Archive Stores                                                   #
# # ---------------------------------------------------------------- #
# SetStorePath
# # ---------------------------------------------------------------- #
# # Search Indexes                                                   #
# # ---------------------------------------------------------------- #
# GetIndexConfiguration
# SetIndexConfiguration
# # ---------------------------------------------------------------- #
# # System Administrators                                            #
# # ---------------------------------------------------------------- #
# GetSystemAdministrators
# CreateSystemAdministrator
# SetSystemAdministratorConfiguration
# SetSystemAdministratorPassword
# DeleteSystemAdministrator
# # ---------------------------------------------------------------- #
# # System Administrators MFA Settings                               #
# # ---------------------------------------------------------------- #
# InitializeSystemAdministratorMFA
# DeactivateSystemAdministratorMFA
# CreateSystemAdministratorAPIPassword
# # ---------------------------------------------------------------- #
# # System SMTP Settings                                             #
# # ---------------------------------------------------------------- #
# GetSystemSmtpConfiguration
# SetSystemSmtpConfiguration
# TestSystemSmtpConfiguration
# # ---------------------------------------------------------------- #
# # Miscellaneous                                                    #
# # ---------------------------------------------------------------- #
# CreateLicenseRequest
# Ping
# ReloadBranding
