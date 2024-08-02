# This script get all DHCP Leases from the DHCP Server and list then together with the MAC Addresses in the valid RFC formats
# xx-yy-zz-aa-bb-cc
# xx:yy:zz:aa:bb:cc
# xxyyzz-aabbcc
# xxyyzzaabbcc
# xxyy.zzaa.bbcc

$myDHCPHosts = @()
$myDHCPHosts+='myDHCPHost1'
$myDHCPHosts+='myDHCPHost2'

$result =  $myDHCPHosts | ForEach-Object {
    $server=$_;Get-DhcpServerv4Scope -ComputerName $server | ForEach-Object {
        $scope=$_.ScopeID;Get-DhcpServerv4Lease -ComputerName $server -ScopeId $scope
        }
    } | Select-Object @{Label='Server';Expression={$server}},
    ScopeId,
    IPAddress,@{Label='test';Expression={$ip=$_.IPAddress;[int]$ip.split('.')[3]}},
    HostName,
    AddressState,
    LeaseExpiryTime,
    # xx-yy-zz-aa-bb-cc
    ClientID,
    # xx:yy:zz:aa:bb:cc
    @{Label='ClientID1';Expression={$id=$_.ClientID;$id -replace ("-",":")}},
    # xxyyzzaabbcc
    @{Label='ClientID2';Expression={$id=$_.ClientID;$id -replace ("-","")}},
    # xxyyzz-aabbcc
    @{Label='ClientID3';Expression={$id=$_.ClientID;$idneu=$id -replace ("-","");$idneu.substring(0,6)+"-"+$idneu.substring(6,6)}},
    # xxyy.zzaa.bbcc
    @{Label='ClientID4';Expression={$id=$_.ClientID;$idneu2=$id -replace ("-","");$idneu2.substring(0,4)+'.'+$idneu2.substring(4,4)+'.'+$idneu2.substring(8,4)}}

$result  | Out-GridView

if ((-not $PSScriptRoot) -or ($PSVersionTable.PSVersion.Major -le 5)) {Read-Host("Press enter")} # for < Powershell 7