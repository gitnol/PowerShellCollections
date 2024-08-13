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
function Set-MSDirectoryServicesConfiguration {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $True, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
        [string]$config,

        [Parameter(Mandatory = $true)]
        $msapiclient
    )
    process {
        $SetDirectoryServicesConfiguration = (Invoke-MSApiCall -MSApiClient $msapiclient -ApiFunction "SetDirectoryServicesConfiguration" -ApiFunctionParameters @{config = "$config" }).result
        $SetDirectoryServicesConfiguration
    }
}

# SyncUsersWithDirectoryServices
function Sync-MSUsersWithDirectoryServices {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $False, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
        [Boolean]$dryRun,

        [Parameter(Mandatory = $true)]
        $msapiclient
    )
    process {
        $SyncUsersWithDirectoryServices = (Invoke-MSApiCall -MSApiClient $msapiclient -ApiFunction "SyncUsersWithDirectoryServices" -ApiFunctionParameters @{dryRun = "$dryRun" }).result
        $SyncUsersWithDirectoryServices
    }
}
#endregion

#region Credentials

# # ---------------------------------------------------------------- #
# # Credentials                                                      #
# # ---------------------------------------------------------------- #
# GetCredentials
function Get-MSCredentials {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        $msapiclient
    )
    process {
        $GetCredentials = (Invoke-MSApiCall -MSApiClient $msapiclient -ApiFunction "GetCredentials").result
        $GetCredentials
    }
}
#endregion

#region Compliance
# # ---------------------------------------------------------------- #
# # Compliance                                                       #
# # ---------------------------------------------------------------- #
# GetComplianceConfiguration
function Get-MSComplianceConfiguration {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        $msapiclient
    )
    process {
        $GetComplianceConfiguration = (Invoke-MSApiCall -MSApiClient $msapiclient -ApiFunction "GetComplianceConfiguration").result
        $GetComplianceConfiguration
    }
}

# SetComplianceConfiguration
function Set-MSComplianceConfiguration {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $True, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
        [string]$config,

        [Parameter(Mandatory = $true)]
        $msapiclient
    )
    process {
        $SetComplianceConfiguration = (Invoke-MSApiCall -MSApiClient $msapiclient -ApiFunction "SetComplianceConfiguration" -ApiFunctionParameters @{config = "$config" }).result
        $SetComplianceConfiguration
    }
}
#endregion

#region Retention Policies
# # ---------------------------------------------------------------- #
# # Retention Policies                                               #
# # ---------------------------------------------------------------- #
# GetRetentionPolicies
function Get-MSRetentionPolicies {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        $msapiclient
    )
    process {
        $GetRetentionPolicies = (Invoke-MSApiCall -MSApiClient $msapiclient -ApiFunction "GetRetentionPolicies").result
        $GetRetentionPolicies
    }
}

# SetRetentionPolicies
function Set-MSRetentionPolicies {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $True, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
        [string]$config,

        [Parameter(Mandatory = $true)]
        $msapiclient
    )
    process {
        $SetRetentionPolicies = (Invoke-MSApiCall -MSApiClient $msapiclient -ApiFunction "SetRetentionPolicies" -ApiFunctionParameters @{config = "$config" }).result
        $SetRetentionPolicies
    }
}

# ProcessRetentionPolicies
function Process-MSRetentionPolicies {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        $msapiclient
    )
    process {
        $ProcessRetentionPolicies = (Invoke-MSApiCall -MSApiClient $msapiclient -ApiFunction "ProcessRetentionPolicies").result
        $ProcessRetentionPolicies
    }
}
#endregion

#region SMTP Settings
# # ---------------------------------------------------------------- #
# # SMTP Settings                                                    #
# # ---------------------------------------------------------------- #
# GetSmtpSettings
function Get-MSSmtpSettings {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        $msapiclient
    )
    process {
        $GetSmtpSettings = (Invoke-MSApiCall -MSApiClient $msapiclient -ApiFunction "GetSmtpSettings").result
        $GetSmtpSettings
    }
}
# SetSmtpSettings
function Set-MSSmtpSettings {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $True, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
        [string]$settings,

        [Parameter(Mandatory = $true)]
        $msapiclient
    )
    process {
        $SetSmtpSettings = (Invoke-MSApiCall -MSApiClient $msapiclient -ApiFunction "SetSmtpSettings" -ApiFunctionParameters @{settings = "$settings" }).result
        $SetSmtpSettings
    }
}
# TestSmtpSettings
function Test-MSSmtpSettings {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        $msapiclient
    )
    process {
        $TestSmtpSettings = (Invoke-MSApiCall -MSApiClient $msapiclient -ApiFunction "TestSmtpSettings").result
        $TestSmtpSettings
    }
}
#endregion

#region Storage
# # ---------------------------------------------------------------- #
# # Storage                                                          #
# # ---------------------------------------------------------------- #
# MaintainFileSystemDatabases
function Maintain-MSFileSystemDatabases {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        $msapiclient
    )
    process {
        $MaintainFileSystemDatabases = (Invoke-MSApiCall -MSApiClient $msapiclient -ApiFunction "MaintainFileSystemDatabases").result
        $MaintainFileSystemDatabases
    }
}
# RefreshAllStoreStatistics
function Refresh-MSAllStoreStatistics {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        $msapiclient
    )
    process {
        $RefreshAllStoreStatistics = (Invoke-MSApiCall -MSApiClient $msapiclient -ApiFunction "RefreshAllStoreStatistics").result
        $RefreshAllStoreStatistics
    }
}
# RetryOpenStores
function Retry-MSOpenStores {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        $msapiclient
    )
    process {
        $RetryOpenStores = (Invoke-MSApiCall -MSApiClient $msapiclient -ApiFunction "RetryOpenStores").result
        $RetryOpenStores
    }
}
#endregion

#region Archive Stores
# # ---------------------------------------------------------------- #
# # Archive Stores                                                   #
# # ---------------------------------------------------------------- #
# GetStores
function Get-MSStores {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $False, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
        [Boolean]$includeSize,

        [Parameter(Mandatory = $true)]
        $msapiclient
    )
    process {
        $GetStores = (Invoke-MSApiCall -MSApiClient $msapiclient -ApiFunction "GetStores" -ApiFunctionParameters @{includeSize = "$includeSize" }).result
        $GetStores
    }
}
# SetStoreRequestedState
function Set-MSStoreRequestedState {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $True, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
        [int]$id,

        [Parameter(Mandatory = $False, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
        [ValidateSet('current', 'normal', 'writeProtected', 'disabled')]
        [string]$requestedState,

        [Parameter(Mandatory = $true)]
        $msapiclient
    )
    process {
        $SetStoreRequestedState = (Invoke-MSApiCall -MSApiClient $msapiclient -ApiFunction "SetStoreRequestedState" -ApiFunctionParameters @{id = "$id"; requestedState = "$requestedState" }).result
        $SetStoreRequestedState
    }
}
# RenameStore
function Rename-MSStore {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $True, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
        [int]$id,

        [Parameter(Mandatory = $True, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
        [string]$name,

        [Parameter(Mandatory = $true)]
        $msapiclient
    )
    process {
        $RenameStore = (Invoke-MSApiCall -MSApiClient $msapiclient -ApiFunction "RenameStore" -ApiFunctionParameters @{id = "$id"; name = "$name" }).result
        $RenameStore
    }
}
# DetachStore
function Detach-MSStore {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $True, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
        [int]$id,

        [Parameter(Mandatory = $true)]
        $msapiclient
    )
    process {
        $DetachStore = (Invoke-MSApiCall -MSApiClient $msapiclient -ApiFunction "DetachStore" -ApiFunctionParameters @{id = "$id" }).result
        $DetachStore
    }
}
# CompactStore
function Compact-MSStore {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $True, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
        [int]$id,

        [Parameter(Mandatory = $true)]
        $msapiclient
    )
    process {
        $CompactStore = (Invoke-MSApiCall -MSApiClient $msapiclient -ApiFunction "CompactStore" -ApiFunctionParameters @{id = "$id" }).result
        $CompactStore
    }
}
# MergeStore
function Merge-MSStore {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $True, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
        [int]$id,

        [Parameter(Mandatory = $True, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
        [int]$sourceId,

        [Parameter(Mandatory = $true)]
        $msapiclient
    )
    process {
        $MergeStore = (Invoke-MSApiCall -MSApiClient $msapiclient -ApiFunction "MergeStore" -ApiFunctionParameters @{id = "$id"; sourceId = "$sourceId" }).result
        $MergeStore
    }
}
# RecoverStore
function Recover-MSStore {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $True, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
        [int]$id,

        [Parameter(Mandatory = $False, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
        [string]$encryptionKey,

        [Parameter(Mandatory = $False, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
        [Boolean]$recoverDeletedMessages,

        [Parameter(Mandatory = $true)]
        $msapiclient
    )
    process {
        $RecoverStore = (Invoke-MSApiCall -MSApiClient $msapiclient -ApiFunction "RecoverStore" -ApiFunctionParameters @{id = "$id"; encryptionKey = "$encryptionKey"; recoverDeletedMessages = "$recoverDeletedMessages" }).result
        $RecoverStore
    }
}
# RecreateRecoveryRecords
function Recreate-MSRecoveryRecords {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $True, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
        [int]$id,

        [Parameter(Mandatory = $true)]
        $msapiclient
    )
    process {
        $RecreateRecoveryRecords = (Invoke-MSApiCall -MSApiClient $msapiclient -ApiFunction "RecreateRecoveryRecords" -ApiFunctionParameters @{id = "$id" }).result
        $RecreateRecoveryRecords
    }
}
# RepairStoreDatabase
function Repair-MSStoreDatabase {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $True, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
        [int]$id,

        [Parameter(Mandatory = $true)]
        $msapiclient
    )
    process {
        $RepairStoreDatabase = (Invoke-MSApiCall -MSApiClient $msapiclient -ApiFunction "RepairStoreDatabase" -ApiFunctionParameters @{id = "$id" }).result
        $RepairStoreDatabase
    }
}
# UnlockStore
function Unlock-MSStore {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $True, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
        [int]$id,

        [Parameter(Mandatory = $True, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
        [string]$passphrase,

        [Parameter(Mandatory = $true)]
        $msapiclient
    )
    process {
        $UnlockStore = (Invoke-MSApiCall -MSApiClient $msapiclient -ApiFunction "UnlockStore" -ApiFunctionParameters @{id = "$id"; passphrase = "$passphrase" }).result
        $UnlockStore
    }
}
# UpgradeStore
function Upgrade-MSStore {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $True, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
        [int]$id,

        [Parameter(Mandatory = $true)]
        $msapiclient
    )
    process {
        $UpgradeStore = (Invoke-MSApiCall -MSApiClient $msapiclient -ApiFunction "UpgradeStore" -ApiFunctionParameters @{id = "$id" }).result
        $UpgradeStore
    }
}
# UpgradeStores
function Upgrade-MSStores {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        $msapiclient
    )
    process {
        $UpgradeStores = (Invoke-MSApiCall -MSApiClient $msapiclient -ApiFunction "UpgradeStores").result
        $UpgradeStores
    }
}
# VerifyStore
function Verify-MSStore {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $True, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
        [int]$id,

        [Parameter(Mandatory = $True, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
        [Boolean]$includeIndexes,

        [Parameter(Mandatory = $true)]
        $msapiclient
    )
    process {
        $VerifyStore = (Invoke-MSApiCall -MSApiClient $msapiclient -ApiFunction "VerifyStore" -ApiFunctionParameters @{id = "$id"; includeIndexes = "$includeIndexes" }).result
        $VerifyStore
    }
}
# VerifyStores
function Verify-MSStores {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $True, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
        [Boolean]$includeIndexes,

        [Parameter(Mandatory = $true)]
        $msapiclient
    )
    process {
        $VerifyStores = (Invoke-MSApiCall -MSApiClient $msapiclient -ApiFunction "VerifyStores" -ApiFunctionParameters @{includeIndexes = "$includeIndexes" }).result
        $VerifyStores
    }
}
#endregion

#region Auto Create Archive Store Configuration
# # ---------------------------------------------------------------- #
# # Auto Create Archive Store Configuration                          #
# # ---------------------------------------------------------------- #
# GetStoreAutoCreateConfiguration
function Get-MSStoreAutoCreateConfiguration {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        $msapiclient
    )
    process {
        $GetStoreAutoCreateConfiguration = (Invoke-MSApiCall -MSApiClient $msapiclient -ApiFunction "GetStoreAutoCreateConfiguration").result
        $GetStoreAutoCreateConfiguration
    }
}
# SetStoreAutoCreateConfiguration
function Set-MSStoreAutoCreateConfiguration {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $True, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
        [string]$config,

        [Parameter(Mandatory = $true)]
        $msapiclient
    )
    process {
        $SetStoreAutoCreateConfiguration = (Invoke-MSApiCall -MSApiClient $msapiclient -ApiFunction "SetStoreAutoCreateConfiguration" -ApiFunctionParameters @{config = "$config" }).result
        $SetStoreAutoCreateConfiguration
    }
}
#endregion

#region Search Indexes
# # ---------------------------------------------------------------- #
# # Search Indexes                                                   #
# # ---------------------------------------------------------------- #
# SelectAllStoreIndexesForRebuild
function Select-MSAllStoreIndexesForRebuild {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        $msapiclient
    )
    process {
        $SelectAllStoreIndexesForRebuild = (Invoke-MSApiCall -MSApiClient $msapiclient -ApiFunction "SelectAllStoreIndexesForRebuild").result
        $SelectAllStoreIndexesForRebuild
    }
}
# RebuildSelectedStoreIndexes
function Rebuild-MSSelectedStoreIndexes {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        $msapiclient
    )
    process {
        $RebuildSelectedStoreIndexes = (Invoke-MSApiCall -MSApiClient $msapiclient -ApiFunction "RebuildSelectedStoreIndexes").result
        $RebuildSelectedStoreIndexes
    }
}
#endregion

#region Jobs
# # ---------------------------------------------------------------- #
# # Jobs                                                             #
# # ---------------------------------------------------------------- #
# GetJobs
function Get-MSJobs {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        $msapiclient
    )
    process {
        $GetJobs = (Invoke-MSApiCall -MSApiClient $msapiclient -ApiFunction "GetJobs").result
        $GetJobs
    }
}
# GetJobResults
function Get-MSJobResults {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $True, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
        [string]$fromIncluding,

        [Parameter(Mandatory = $True, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
        [string]$toExcluding,

        [Parameter(Mandatory = $True, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
        [string]$timeZoneId,

        [Parameter(Mandatory = $False, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
        [int]$jobId,

        [Parameter(Mandatory = $true)]
        $msapiclient
    )
    process {
        $GetJobResults = (Invoke-MSApiCall -MSApiClient $msapiclient -ApiFunction "GetJobResults" -ApiFunctionParameters @{fromIncluding = "$fromIncluding"; toExcluding = "$toExcluding"; timeZoneId = "$timeZoneId"; jobId = "$jobId" }).result
        $GetJobResults
    }
}
# RenameJob
function Rename-MSJob {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $False, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
        [int]$id,

        [Parameter(Mandatory = $False, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
        [string]$name,

        [Parameter(Mandatory = $true)]
        $msapiclient
    )
    process {
        $RenameJob = (Invoke-MSApiCall -MSApiClient $msapiclient -ApiFunction "RenameJob" -ApiFunctionParameters @{id = "$id"; name = "$name" }).result
        $RenameJob
    }
}
# SetJobEnabled
function Set-MSJobEnabled {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $False, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
        [int]$id,

        [Parameter(Mandatory = $False, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
        [Boolean]$enabled,

        [Parameter(Mandatory = $true)]
        $msapiclient
    )
    process {
        $SetJobEnabled = (Invoke-MSApiCall -MSApiClient $msapiclient -ApiFunction "SetJobEnabled" -ApiFunctionParameters @{id = "$id"; enabled = "$enabled" }).result
        $SetJobEnabled
    }
}
# DeleteJob
function Delete-MSJob {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $True, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
        [string]$id,

        [Parameter(Mandatory = $true)]
        $msapiclient
    )
    process {
        $DeleteJob = (Invoke-MSApiCall -MSApiClient $msapiclient -ApiFunction "DeleteJob" -ApiFunctionParameters @{id = "$id" }).result
        $DeleteJob
    }
}
# RunJobAsync
function Run-MSJobAsync {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $True, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
        [int]$id,

        [Parameter(Mandatory = $true)]
        $msapiclient
    )
    process {
        $RunJobAsync = (Invoke-MSApiCall -MSApiClient $msapiclient -ApiFunction "RunJobAsync" -ApiFunctionParameters @{id = "$id" }).result
        $RunJobAsync
    }
}
# CancelJobAsync
function Cancel-MSJobAsync {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $True, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
        [int]$id,

        [Parameter(Mandatory = $true)]
        $msapiclient
    )
    process {
        $CancelJobAsync = (Invoke-MSApiCall -MSApiClient $msapiclient -ApiFunction "CancelJobAsync" -ApiFunctionParameters @{id = "$id" }).result
        $CancelJobAsync
    }
}
#endregion

#region Profiles
# # ---------------------------------------------------------------- #
# # Profiles                                                         #
# # ---------------------------------------------------------------- #
# GetProfiles
function Get-MSProfiles {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $True, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
        [Boolean]$raw,

        [Parameter(Mandatory = $true)]
        $msapiclient
    )
    process {
        $GetProfiles = (Invoke-MSApiCall -MSApiClient $msapiclient -ApiFunction "GetProfiles" -ApiFunctionParameters @{raw = "$raw" }).result
        $GetProfiles
    }
}
# GetWorkerResultReport
function Get-MSWorkerResultReport {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $True, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
        [int]$id,

        [Parameter(Mandatory = $true)]
        $msapiclient
    )
    process {
        $GetWorkerResultReport = (Invoke-MSApiCall -MSApiClient $msapiclient -ApiFunction "GetWorkerResultReport" -ApiFunctionParameters @{id = "$id" }).result
        $GetWorkerResultReport
    }
}
# CreateProfile
function Create-MSProfile {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $True, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
        [string]$properties,

        [Parameter(Mandatory = $True, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
        [Boolean]$raw,

        [Parameter(Mandatory = $true)]
        $msapiclient
    )
    process {
        $CreateProfile = (Invoke-MSApiCall -MSApiClient $msapiclient -ApiFunction "CreateProfile" -ApiFunctionParameters @{properties = "$properties"; raw = "$raw" }).result
        $CreateProfile
    }
}
# RunProfile
function Run-MSProfile {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $True, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
        [int]$id,

        [Parameter(Mandatory = $true)]
        $msapiclient
    )
    process {
        $RunProfile = (Invoke-MSApiCall -MSApiClient $msapiclient -ApiFunction "RunProfile" -ApiFunctionParameters @{id = "$id" }).result
        $RunProfile
    }
}
# RunTemporaryProfile
function Run-MSTemporaryProfile {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $True, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
        [string]$properties,

        [Parameter(Mandatory = $True, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
        [Boolean]$raw,

        [Parameter(Mandatory = $true)]
        $msapiclient
    )
    process {
        $RunTemporaryProfile = (Invoke-MSApiCall -MSApiClient $msapiclient -ApiFunction "RunTemporaryProfile" -ApiFunctionParameters @{properties = "$properties"; raw = "$raw" }).result
        $RunTemporaryProfile
    }
}
# DeleteProfile
function Delete-MSProfile {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $True, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
        [int]$id,

        [Parameter(Mandatory = $true)]
        $msapiclient
    )
    process {
        $DeleteProfile = (Invoke-MSApiCall -MSApiClient $msapiclient -ApiFunction "DeleteProfile" -ApiFunctionParameters @{id = "$id" }).result
        $DeleteProfile
    }
}
#endregion

#region Folders
# # ---------------------------------------------------------------- #
# # Folders                                                          #
# # ---------------------------------------------------------------- #
# GetFolderStatistics
# GetChildFolders
# MoveFolder
# DeleteEmptyFolders
#endregion

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
