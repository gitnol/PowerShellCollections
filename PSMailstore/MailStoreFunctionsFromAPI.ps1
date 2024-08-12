function Attach-MSStore {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $True, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
        [string]$name,

        [Parameter(Mandatory = $True, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
        [ValidateSet('FileSystemInternal', 'SQLServer', 'PostgreSQL')]
        [string]$type,

        [Parameter(Mandatory = $False, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
        [string]$databaseName,

        [Parameter(Mandatory = $False, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
        [string]$databasePath,

        [Parameter(Mandatory = $False, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
        [string]$contentPath,

        [Parameter(Mandatory = $False, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
        [string]$indexPath,

        [Parameter(Mandatory = $False, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
        [string]$serverName,

        [Parameter(Mandatory = $False, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
        [string]$userName,

        [Parameter(Mandatory = $False, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
        [string]$password,

        [Parameter(Mandatory = $False, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
        [ValidateSet('current', 'normal', 'writeProtected', 'disabled')]
        [string]$requestedState,

        [Parameter(Mandatory = $true)]
        $msapiclient
    )
    process {
        $AttachStore = (Invoke-MSApiCall -MSApiClient $msapiclient -ApiFunction "AttachStore" -ApiFunctionParameters @{name = "$name"; type = "$type"; databaseName = "$databaseName"; databasePath = "$databasePath"; contentPath = "$contentPath"; indexPath = "$indexPath"; serverName = "$serverName"; userName = "$userName"; password = "$password"; requestedState = "$requestedState" }).result
        $AttachStore
    }
}
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
function Compact-MSMasterDatabase {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        $msapiclient
    )
    process {
        $CompactMasterDatabase = (Invoke-MSApiCall -MSApiClient $msapiclient -ApiFunction "CompactMasterDatabase").result
        $CompactMasterDatabase
    }
}
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
function Create-MSBackup {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $True, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
        [string]$path,

        [Parameter(Mandatory = $False, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
        [Boolean]$excludeSearchIndexes,

        [Parameter(Mandatory = $true)]
        $msapiclient
    )
    process {
        $CreateBackup = (Invoke-MSApiCall -MSApiClient $msapiclient -ApiFunction "CreateBackup" -ApiFunctionParameters @{path = "$path"; excludeSearchIndexes = "$excludeSearchIndexes" }).result
        $CreateBackup
    }
}
function Create-MSJob {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $False, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
        [string]$name,

        [Parameter(Mandatory = $False, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
        [string]$action,

        [Parameter(Mandatory = $False, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
        [string]$owner,

        [Parameter(Mandatory = $False, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
        [string]$timeZoneId,

        [Parameter(Mandatory = $False, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
        [string]$date,

        [Parameter(Mandatory = $False, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
        [ValidateSet('5', '10', '15', '20', '30', '60', '120', '180', '240', '360', '720')]
        [int]$interval,

        [Parameter(Mandatory = $False, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
        [string]$time,

        [Parameter(Mandatory = $False, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
        [ValidateSet('Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday')]
        [string]$dayOfWeek,

        [Parameter(Mandatory = $False, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
        [ValidateSet('1,2,3,4,5,6,7,8,9,10,11,11,12,13,14,15,16,17,18,29,20,21,22,23,24,25,26,27,28,29,30,31', 'Last')]
        [string]$dayOfMonth,

        [Parameter(Mandatory = $true)]
        $msapiclient
    )
    process {
        $CreateJob = (Invoke-MSApiCall -MSApiClient $msapiclient -ApiFunction "CreateJob" -ApiFunctionParameters @{name = "$name"; action = "$action"; owner = "$owner"; timeZoneId = "$timeZoneId"; date = "$date"; interval = "$interval"; time = "$time"; dayOfWeek = "$dayOfWeek"; dayOfMonth = "$dayOfMonth" }).result
        $CreateJob
    }
}
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
function Create-MSStore {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $True, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
        [string]$name,

        [Parameter(Mandatory = $False, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
        [ValidateSet('FileSystemInternal', 'SQLServer', 'PostgreSQL')]
        [string]$type,

        [Parameter(Mandatory = $False, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
        [string]$databaseName,

        [Parameter(Mandatory = $False, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
        [string]$databasePath,

        [Parameter(Mandatory = $False, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
        [string]$contentPath,

        [Parameter(Mandatory = $False, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
        [string]$indexPath,

        [Parameter(Mandatory = $False, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
        [string]$serverName,

        [Parameter(Mandatory = $False, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
        [string]$userName,

        [Parameter(Mandatory = $False, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
        [string]$password,

        [Parameter(Mandatory = $False, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
        [ValidateSet('current', 'normal', 'writeProtected', 'disabled')]
        [string]$requestedState,

        [Parameter(Mandatory = $true)]
        $msapiclient
    )
    process {
        $CreateStore = (Invoke-MSApiCall -MSApiClient $msapiclient -ApiFunction "CreateStore" -ApiFunctionParameters @{name = "$name"; type = "$type"; databaseName = "$databaseName"; databasePath = "$databasePath"; contentPath = "$contentPath"; indexPath = "$indexPath"; serverName = "$serverName"; userName = "$userName"; password = "$password"; requestedState = "$requestedState" }).result
        $CreateStore
    }
}
function Create-MSUser {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $True, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
        [string]$userName,

        [Parameter(Mandatory = $True, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
        [ValidateSet('none', 'admin', 'login', 'changePassword', 'archive', 'modifyArchiveProfiles', 'export', 'modifyExportProfiles', 'delete')]
        [string]$privileges,

        [Parameter(Mandatory = $False, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
        [string]$fullName,

        [Parameter(Mandatory = $False, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
        [string]$distinguishedName,

        [Parameter(Mandatory = $False, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
        [string]$authentication,

        [Parameter(Mandatory = $False, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
        [string]$password,

        [Parameter(Mandatory = $False, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
        [ValidateSet('none', 'windows', 'web', 'outlook', 'windowsCmd', 'imap', 'api')]
        [string]$loginPrivileges,

        [Parameter(Mandatory = $true)]
        $msapiclient
    )
    process {
        $CreateUser = (Invoke-MSApiCall -MSApiClient $msapiclient -ApiFunction "CreateUser" -ApiFunctionParameters @{userName = "$userName"; privileges = "$privileges"; fullName = "$fullName"; distinguishedName = "$distinguishedName"; authentication = "$authentication"; password = "$password"; loginPrivileges = "$loginPrivileges" }).result
        $CreateUser
    }
}
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
function Delete-MSEmptyFolders {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $False, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
        [string]$folder,

        [Parameter(Mandatory = $true)]
        $msapiclient
    )
    process {
        $DeleteEmptyFolders = (Invoke-MSApiCall -MSApiClient $msapiclient -ApiFunction "DeleteEmptyFolders" -ApiFunctionParameters @{folder = "$folder" }).result
        $DeleteEmptyFolders
    }
}
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
function Delete-MSMessage {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $True, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
        [string]$id,

        [Parameter(Mandatory = $True, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
        [string]$reason,

        [Parameter(Mandatory = $true)]
        $msapiclient
    )
    process {
        $DeleteMessage = (Invoke-MSApiCall -MSApiClient $msapiclient -ApiFunction "DeleteMessage" -ApiFunctionParameters @{id = "$id"; reason = "$reason" }).result
        $DeleteMessage
    }
}
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
function Get-MSActiveSessions {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        $msapiclient
    )
    process {
        $GetActiveSessions = (Invoke-MSApiCall -MSApiClient $msapiclient -ApiFunction "GetActiveSessions").result
        $GetActiveSessions
    }
}
function Get-MSChildFolders {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $False, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
        [string]$folder,

        [Parameter(Mandatory = $False, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
        [int]$maxLevels,

        [Parameter(Mandatory = $true)]
        $msapiclient
    )
    process {
        $GetChildFolders = (Invoke-MSApiCall -MSApiClient $msapiclient -ApiFunction "GetChildFolders" -ApiFunctionParameters @{folder = "$folder"; maxLevels = "$maxLevels" }).result
        $GetChildFolders
    }
}
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
function Get-MSFolderStatistics {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        $msapiclient
    )
    process {
        $GetFolderStatistics = (Invoke-MSApiCall -MSApiClient $msapiclient -ApiFunction "GetFolderStatistics").result
        $GetFolderStatistics
    }
}
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
function Get-MSLicenseInformation {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        $msapiclient
    )
    process {
        $GetLicenseInformation = (Invoke-MSApiCall -MSApiClient $msapiclient -ApiFunction "GetLicenseInformation").result
        $GetLicenseInformation
    }
}
function Get-MSMessages {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $False, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
        [string]$folder,

        [Parameter(Mandatory = $true)]
        $msapiclient
    )
    process {
        $GetMessages = (Invoke-MSApiCall -MSApiClient $msapiclient -ApiFunction "GetMessages" -ApiFunctionParameters @{folder = "$folder" }).result
        $GetMessages
    }
}
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
function Get-MSServerInfo {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        $msapiclient
    )
    process {
        $GetServerInfo = (Invoke-MSApiCall -MSApiClient $msapiclient -ApiFunction "GetServerInfo").result
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
        $GetServiceConfiguration = (Invoke-MSApiCall -MSApiClient $msapiclient -ApiFunction "GetServiceConfiguration").result
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
        $GetSmtpSettings = (Invoke-MSApiCall -MSApiClient $msapiclient -ApiFunction "GetSmtpSettings").result
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
        $GetStoreAutoCreateConfiguration = (Invoke-MSApiCall -MSApiClient $msapiclient -ApiFunction "GetStoreAutoCreateConfiguration").result
        $GetStoreAutoCreateConfiguration
    }
}
function Get-MSStoreIndexes {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $False, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
        [int]$id,

        [Parameter(Mandatory = $true)]
        $msapiclient
    )
    process {
        $GetStoreIndexes = (Invoke-MSApiCall -MSApiClient $msapiclient -ApiFunction "GetStoreIndexes" -ApiFunctionParameters @{id = "$id" }).result
        $GetStoreIndexes
    }
}
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
function Get-MSTimeZones {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        $msapiclient
    )
    process {
        $GetTimeZones = (Invoke-MSApiCall -MSApiClient $msapiclient -ApiFunction "GetTimeZones").result
        $GetTimeZones
    }
}
function Get-MSUserInfo {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $True, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
        [string]$userName,

        [Parameter(Mandatory = $true)]
        $msapiclient
    )
    process {
        $GetUserInfo = (Invoke-MSApiCall -MSApiClient $msapiclient -ApiFunction "GetUserInfo" -ApiFunctionParameters @{userName = "$userName" }).result
        $GetUserInfo
    }
}
function Get-MSUsers {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        $msapiclient
    )
    process {
        $GetUsers = (Invoke-MSApiCall -MSApiClient $msapiclient -ApiFunction "GetUsers").result
        $GetUsers
    }
}
function Get-MSWorkerResults {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $True, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
        [string]$fromIncluding,

        [Parameter(Mandatory = $True, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
        [string]$toExcluding,

        [Parameter(Mandatory = $True, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
        [string]$timeZoneID,

        [Parameter(Mandatory = $False, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
        [int]$profileID,

        [Parameter(Mandatory = $False, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
        [string]$userName,

        [Parameter(Mandatory = $true)]
        $msapiclient
    )
    process {
        $GetWorkerResults = (Invoke-MSApiCall -MSApiClient $msapiclient -ApiFunction "GetWorkerResults" -ApiFunctionParameters @{fromIncluding = "$fromIncluding"; toExcluding = "$toExcluding"; timeZoneID = "$timeZoneID"; profileID = "$profileID"; userName = "$userName" }).result
        $GetWorkerResults
    }
}
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
function Move-MSFolder {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $True, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
        [string]$fromFolder,

        [Parameter(Mandatory = $True, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
        [string]$toFolder,

        [Parameter(Mandatory = $true)]
        $msapiclient
    )
    process {
        $MoveFolder = (Invoke-MSApiCall -MSApiClient $msapiclient -ApiFunction "MoveFolder" -ApiFunctionParameters @{fromFolder = "$fromFolder"; toFolder = "$toFolder" }).result
        $MoveFolder
    }
}
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
function Rebuild-MSStoreIndex {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $True, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
        [int]$id,

        [Parameter(Mandatory = $True, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
        [string]$folder,

        [Parameter(Mandatory = $true)]
        $msapiclient
    )
    process {
        $RebuildStoreIndex = (Invoke-MSApiCall -MSApiClient $msapiclient -ApiFunction "RebuildStoreIndex" -ApiFunctionParameters @{id = "$id"; folder = "$folder" }).result
        $RebuildStoreIndex
    }
}
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
function -MSRecreateRecoveryRecords {
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
function Renew-MSMasterKey {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        $msapiclient
    )
    process {
        $RenewMasterKey = (Invoke-MSApiCall -MSApiClient $msapiclient -ApiFunction "RenewMasterKey").result
        $RenewMasterKey
    }
}
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
function -MSSendStatusReport {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $True, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
        [ValidateSet('today', 'yesterday', 'thisweek', 'lastweek', 'thismonth', 'lastmonth')]
        [string]$timespan,

        [Parameter(Mandatory = $True, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
        [string]$timeZoneId,

        [Parameter(Mandatory = $True, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
        [string]$recipients,

        [Parameter(Mandatory = $true)]
        $msapiclient
    )
    process {
        $SendStatusReport = (Invoke-MSApiCall -MSApiClient $msapiclient -ApiFunction "SendStatusReport" -ApiFunctionParameters @{timespan = "$timespan"; timeZoneId = "$timeZoneId"; recipients = "$recipients" }).result
        $SendStatusReport
    }
}
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
function Set-MSJobSchedule {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $True, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
        [int]$id,

        [Parameter(Mandatory = $True, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
        [string]$timeZoneId,

        [Parameter(Mandatory = $False, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
        [string]$date,

        [Parameter(Mandatory = $False, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
        [ValidateSet('5', '10', '15', '20', '30', '60', '120', '180', '260', '360', '720')]
        [int]$interval,

        [Parameter(Mandatory = $False, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
        [string]$time,

        [Parameter(Mandatory = $False, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
        [ValidateSet('Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday')]
        [string]$dayOfWeek,

        [Parameter(Mandatory = $False, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
        [ValidateSet('1,2,3,4,5,6,7,8,9,10,11,11,12,13,14,15,16,17,18,29,20,21,22,23,24,25,26,27,28,29,30,31', 'Last')]
        [string]$dayOfMonth,

        [Parameter(Mandatory = $true)]
        $msapiclient
    )
    process {
        $SetJobSchedule = (Invoke-MSApiCall -MSApiClient $msapiclient -ApiFunction "SetJobSchedule" -ApiFunctionParameters @{id = "$id"; timeZoneId = "$timeZoneId"; date = "$date"; interval = "$interval"; time = "$time"; dayOfWeek = "$dayOfWeek"; dayOfMonth = "$dayOfMonth" }).result
        $SetJobSchedule
    }
}
function Set-MSProfileServerSideExecution {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $True, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
        [int]$id,

        [Parameter(Mandatory = $True, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
        [Boolean]$automatic,

        [Parameter(Mandatory = $False, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
        [int]$automaticPauseBetweenExecutions,

        [Parameter(Mandatory = $False, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
        [string]$automaticMaintenanceWindows,

        [Parameter(Mandatory = $true)]
        $msapiclient
    )
    process {
        $SetProfileServerSideExecution = (Invoke-MSApiCall -MSApiClient $msapiclient -ApiFunction "SetProfileServerSideExecution" -ApiFunctionParameters @{id = "$id"; automatic = "$automatic"; automaticPauseBetweenExecutions = "$automaticPauseBetweenExecutions"; automaticMaintenanceWindows = "$automaticMaintenanceWindows" }).result
        $SetProfileServerSideExecution
    }
}
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
function -MSSetServiceCertificate {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $True, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
        [string]$thumbprint,

        [Parameter(Mandatory = $true)]
        $msapiclient
    )
    process {
        $SetServiceCertificate = (Invoke-MSApiCall -MSApiClient $msapiclient -ApiFunction "SetServiceCertificate" -ApiFunctionParameters @{thumbprint = "$thumbprint" }).result
        $SetServiceCertificate
    }
}
function -MSSetSmtpSettings {
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
function -MSSetStoreAutoCreateConfiguration {
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
function -MSSetStoreProperties {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $True, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
        [int]$id,

        [Parameter(Mandatory = $False, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
        [ValidateSet('FileSystemInternal', 'SQLServer', 'PostgreSQL')]
        [string]$type,

        [Parameter(Mandatory = $False, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
        [string]$databaseName,

        [Parameter(Mandatory = $False, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
        [string]$databasePath,

        [Parameter(Mandatory = $False, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
        [string]$contentPath,

        [Parameter(Mandatory = $False, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
        [string]$indexPath,

        [Parameter(Mandatory = $False, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
        [string]$serverName,

        [Parameter(Mandatory = $False, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
        [string]$userName,

        [Parameter(Mandatory = $False, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
        [string]$password,

        [Parameter(Mandatory = $true)]
        $msapiclient
    )
    process {
        $SetStoreProperties = (Invoke-MSApiCall -MSApiClient $msapiclient -ApiFunction "SetStoreProperties" -ApiFunctionParameters @{id = "$id"; type = "$type"; databaseName = "$databaseName"; databasePath = "$databasePath"; contentPath = "$contentPath"; indexPath = "$indexPath"; serverName = "$serverName"; userName = "$userName"; password = "$password" }).result
        $SetStoreProperties
    }
}
function -MSSetStoreRequestedState {
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
function Set-MSUserFullName {
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