# This Script creates a new public spot user for LANCOM Public Spot
# Tested with LANCOM WLC vRouter 10.80.xxxx
# Keep in mind of "-SkipCertificateCheck" and that not every option in the documentation (search for MA_LCOS-1080-Public-Spot_DE.pdf) has been adapted. 
# Feel free to change everything to your needs.
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

    # Invoke the REST method
    Invoke-RestMethod -Uri $uri `
        -Method Get `
        -Headers @{Authorization=("Basic {0}" -f $base64AuthInfo)} `
        -SkipCertificateCheck
}

# Beispielaufruf der Funktion
Invoke-CmdPbSpotUser -ServerIP "10.0.8.240" -Action "addpbspotuser" -Comment "TESTKOMMENTAR" -Unit "Minute" `
    -Runtime 7200 -NbGuests 1 -ExpiryType "absolute" -ValidPer 1 -SSID "LVISITOR" `
    -MaxConcLogins 0 -BandwidthProfile 1 -TimeBudget 0 -VolumeBudget 0 -Active 1 `
    -Username "myuser" -Password "mypass"