# This Script creates a new public spot user for LANCOM Public Spot
# Tested with LANCOM WLC vRouter 10.80.xxxx
# Keep in mind of "-SkipCertificateCheck" and that not every option in the documentation (search for MA_LCOS-1080-Public-Spot_DE.pdf) has been adapted. 
# Feel free to change everything to your needs.
<#
.SYNOPSIS
Registers a new Public Spot user via a REST API call to a specified server.

.DESCRIPTION
The function `Invoke-CmdPbSpotUser` is used to add or manage a Public Spot user. The function takes several parameters to define the user's access, bandwidth, and session limits. The function sends an HTTP request to a specified server, utilizing Base64-encoded credentials for authentication.

.PARAMETER ServerIP
The IP address of the server where the Public Spot is managed.

.PARAMETER Action
Defines the action to perform, e.g., 'addpbspotuser'.

.PARAMETER Comment
Comment on the registered user. Supports a single or multiple comments but with a maximum of 191 characters. Special characters like umlauts are not supported.

.PARAMETER Unit
Specifies the unit of lifetime for access, such as minute, hour, or day.

.PARAMETER Runtime
Duration of the access based on the unit specified.

.PARAMETER NbGuests
Number of Public Spot users to create. Defaults to 1 if omitted.

.PARAMETER ExpiryType
Defines the expiry type of the user account. Acceptable values are 'absolute', 'relative', 'both', or 'none'. Combine with 'ValidPer' to specify validity period.

.PARAMETER ValidPer
Validity period in days, used when 'both' expiry type is chosen.

.PARAMETER SSID
The network name. Defaults to the server's default SSID if not provided.

.PARAMETER MaxConcLogins
Defines the maximum number of concurrent logins. Requires 'multilogin' to be enabled.

.PARAMETER BandwidthProfile
Specifies the bandwidth profile by index number. If omitted, no bandwidth limit is applied.

.PARAMETER TimeBudget
Specifies the time budget for the user. Defaults to a server-defined value if omitted.

.PARAMETER VolumeBudget
Specifies the volume budget in bytes (B), kilobytes (kB), megabytes (MB), or gigabytes (GB). Defaults to a server-defined value if omitted.

.PARAMETER Active
Specifies whether the user account is active (1 for active, 0 for inactive).

.PARAMETER Username
The username for authentication.

.PARAMETER Password
The password for authentication.

.EXAMPLE
Invoke-CmdPbSpotUser -ServerIP '192.168.0.1' -Action 'addpbspotuser' -Comment 'Guest User' -Unit 'hour' -Runtime 3 -NbGuests 5 -ExpiryType 'relative' -ValidPer 7 -SSID 'PublicNetwork' -MaxConcLogins 2 -BandwidthProfile 1 -TimeBudget 3600 -VolumeBudget 1000m -Active 1 -Username 'admin' -Password 'P@ssw0rd'

# Adds a Public Spot user on the server with specific parameters.
#>
function Invoke-CmdPbSpotUser {
    param (
        [string]$ServerIP,
        [string]$Action,
        [string]$Comment,
        [string]$Unit,
        [int]$Runtime,
        [int]$NbGuests,
        [string]$ExpiryType,
        [int]$ValidPer,
        [string]$SSID,
        [int]$MaxConcLogins,
        [int]$BandwidthProfile,
        [int]$TimeBudget,
        [int]$VolumeBudget,
        [int]$Active,
        [string]$Username,
        [string]$Password
    )
    

    # Base64 encoding for credentials
    $base64AuthInfo = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(("{0}:{1}" -f $Username, $Password)))

    # Construct the URI
    $uri = "https://$ServerIP/cmdpbspotuser/?action=$Action&comment=$Comment&unit=$Unit+runtime=$Runtime&multilogin&print&printcomment&casesensitive=0&nbGuests=$NbGuests&expirytype=$ExpiryType+validper=$ValidPer&ssid=$SSID&maxconclogins=$MaxConcLogins&bandwidthprofile=$BandwidthProfile&timebudget=$TimeBudget&volumebudget=$VolumeBudget&active=$Active"
    # regarding to  https://www.lancom-forum.de/alles-zum-lancom-wlc-4100-wlc-4025-wlc-4025-und-wl-f32/web-api-lcos-9-20-login-t15426.html adding oldauth could work, too, if used in a brower: 
    # example: cmdpbspotuser&oldauth

    # Invoke the REST method
    return Invoke-RestMethod -Uri $uri `
        -Method Get `
        -Headers @{Authorization = ("Basic {0}" -f $base64AuthInfo) } `
        -SkipCertificateCheck
}

# Beispielaufruf der Funktion
$result = Invoke-CmdPbSpotUser -ServerIP "10.0.8.240" -Action "addpbspotuser" -Comment "TESTKOMMENTAR" -Unit "Minute" `
    -Runtime 7200 -NbGuests 1 -ExpiryType "absolute" -ValidPer 1 -SSID "LVISITOR" `
    -MaxConcLogins 0 -BandwidthProfile 1 -TimeBudget 0 -VolumeBudget 0 -Active 1 `
    -Username "myuser" -Password "mypass"

$pattern = '{ SSID:.*}'

if ($match.Success) {
    $userdata = $match.Value | ConvertFrom-Json
    $userdata
}
else {
    Write-Output "No Match found. Please Check result variable"
}

