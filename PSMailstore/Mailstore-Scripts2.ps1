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

# SetUserLoginPrivileges

# SetUserPassword

# InitializeMFA

# DisableMFA

# DeleteAppPasswords

# SetUserPop3UserNames

# SetUserPrivileges

# RenameUser

# DeleteUser

# SetUserPrivilegesOnFolder

# ClearUserPrivilegesOnFolders

#endregion

# # ---------------------------------------------------------------- #
# # Directory Services                                               #
# # ---------------------------------------------------------------- #
# GetDirectoryServicesConfiguration
# SetDirectoryServicesConfiguration
# SyncUsersWithDirectoryServices
# # ---------------------------------------------------------------- #
# # Credentials                                                      #
# # ---------------------------------------------------------------- #
# GetCredentials
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
