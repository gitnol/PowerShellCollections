function Cancel-MSJobAsync {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $True, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
[int]$id,

        [Parameter(Mandatory = $true)]
        $msapiclient
    )
    process {
        $CancelJobAsync = (Invoke-MSApiCall -MSApiClient $msapiclient -ApiFunction "CancelJobAsync" -ApiFunctionParameters @{id = "$id"}).result
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
        $ClearUserPrivilegesOnFolders = (Invoke-MSApiCall -MSApiClient $msapiclient -ApiFunction "ClearUserPrivilegesOnFolders" -ApiFunctionParameters @{userName = "$userName"}).result
        $ClearUserPrivilegesOnFolders
    }
}
function Compact-MSMasterDatabase {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
[]$,

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
        $CompactStore = (Invoke-MSApiCall -MSApiClient $msapiclient -ApiFunction "CompactStore" -ApiFunctionParameters @{id = "$id"}).result
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
        $CreateBackup = (Invoke-MSApiCall -MSApiClient $msapiclient -ApiFunction "CreateBackup" -ApiFunctionParameters @{path = "$path";excludeSearchIndexes = "$excludeSearchIndexes"}).result
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
[ValidateSet(5,10,15,20,30,60,120,180,240,360,720)]
[int]$interval,

[Parameter(Mandatory = $False, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
[string]$time,

[Parameter(Mandatory = $False, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
[ValidateSet(Sunday,Monday,Tuesday,Wednesday,Thursday,Friday,Saturday)]
[string]$dayOfWeek,

[Parameter(Mandatory = $False, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
[ValidateSet(1,2,3,4,5,6,7,8,9,10,11,11,12,13,14,15,16,17,18,29,20,21,22,23,24,25,26,27,28,29,30,31,Last)]
[string]$dayOfMonth,

        [Parameter(Mandatory = $true)]
        $msapiclient
    )
    process {
        $CreateJob = (Invoke-MSApiCall -MSApiClient $msapiclient -ApiFunction "CreateJob" -ApiFunctionParameters @{name = "$name";action = "$action";owner = "$owner";timeZoneId = "$timeZoneId";date = "$date";interval = "$interval";time = "$time";dayOfWeek = "$dayOfWeek";dayOfMonth = "$dayOfMonth"}).result
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
        $CreateProfile = (Invoke-MSApiCall -MSApiClient $msapiclient -ApiFunction "CreateProfile" -ApiFunctionParameters @{properties = "$properties";raw = "$raw"}).result
        $CreateProfile
    }
}
function Create-MSStore {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $True, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
[string]$name,

[Parameter(Mandatory = $False, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
[ValidateSet(FileSystemInternal,SQLServer,PostgreSQL)]
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
[ValidateSet(current,normal,writeProtected,disabled)]
[string]$requestedState,

        [Parameter(Mandatory = $true)]
        $msapiclient
    )
    process {
        $CreateStore = (Invoke-MSApiCall -MSApiClient $msapiclient -ApiFunction "CreateStore" -ApiFunctionParameters @{name = "$name";type = "$type";databaseName = "$databaseName";databasePath = "$databasePath";contentPath = "$contentPath";indexPath = "$indexPath";serverName = "$serverName";userName = "$userName";password = "$password";requestedState = "$requestedState"}).result
        $CreateStore
    }
}
function Create-MSUser {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $True, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
[string]$userName,

[Parameter(Mandatory = $True, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
[ValidateSet(none,admin,login,changePassword,archive,modifyArchiveProfiles,export,modifyExportProfiles,delete)]
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
[ValidateSet(none,windows,web,outlook,windowsCmd,imap,api)]
[string]$loginPrivileges,

        [Parameter(Mandatory = $true)]
        $msapiclient
    )
    process {
        $CreateUser = (Invoke-MSApiCall -MSApiClient $msapiclient -ApiFunction "CreateUser" -ApiFunctionParameters @{userName = "$userName";privileges = "$privileges";fullName = "$fullName";distinguishedName = "$distinguishedName";authentication = "$authentication";password = "$password";loginPrivileges = "$loginPrivileges"}).result
        $CreateUser
    }
}