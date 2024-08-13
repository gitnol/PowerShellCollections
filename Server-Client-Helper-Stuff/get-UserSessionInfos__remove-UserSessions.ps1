# This Script is able to get remote user sessions information and is able to log off the (discconnected | connected) remote user sessions
function Remove-UserSessions {
    param (
        [Parameter(Mandatory = $true, ValueFromPipeline = $true, Position = 0)]
        [string[]]$server,
        [Parameter(Mandatory = $true, ValueFromPipeline = $true, Position = 1)]
        [PSCredential]$credentials,
        [switch]$all
    )
    $allObj = @()
    
    $allObj += Invoke-Command -ComputerName $server -Credential $credentials -ScriptBlock {
        $computer = $env:COMPUTERNAME
        $allSessions = (query user);
        $myObj = @()
        if ($using:all) {
            $allSessions | Where-Object { $_ -notlike "*STATUS*" -and $_ -like "*Aktiv*" } | ForEach-Object {
                $myObj += [PSCustomObject]@{
                    BENUTZERNAME = ($_ -split "\s+")[1]
                    SITZUNGSNAME = ($_ -split "\s+")[2]
                    ID           = ($_ -split "\s+")[3]
                    STATUS       = ($_ -split "\s+")[4]
                    LEERLAUF     = ($_ -split "\s+")[5]
                    ANMELDEZEIT  = (($_ -split "\s+")[6] + " " + ($_ -split "\s+")[7])
                }
            }
            $allSessions | Where-Object { $_ -notlike "*STATUS*" -and $_ -like "*Active*" } | ForEach-Object {
                $myObj += [PSCustomObject]@{
                    BENUTZERNAME = ($_ -split "\s+")[1]
                    SITZUNGSNAME = ($_ -split "\s+")[2]
                    ID           = ($_ -split "\s+")[3]
                    STATUS       = ($_ -split "\s+")[4]
                    LEERLAUF     = ($_ -split "\s+")[5]
                    ANMELDEZEIT  = (($_ -split "\s+")[6] + " " + ($_ -split "\s+")[7]+ " " + ($_ -split "\s+")[8])
                }
            }
        }

        $allSessions | Where-Object { $_ -notlike "*SITZUNGSNAME*" -and $_ -like "*GETR*" } | ForEach-Object {
            $myObj += [PSCustomObject]@{
                BENUTZERNAME = ($_ -split "\s+")[1]
                SITZUNGSNAME = "" 
                ID           = ($_ -split "\s+")[2]
                STATUS       = ($_ -split "\s+")[3]
                LEERLAUF     = ($_ -split "\s+")[4]
                ANMELDEZEIT  = (($_ -split "\s+")[5] + " " + ($_ -split "\s+")[6])
            }
        }

        $myObj | ForEach-Object {
            $user = $_.BENUTZERNAME
            $sessionID = $_.ID
            Write-Host("Melde User {0} von {1} ab." -f $user,$computer)
            ( cmd.exe /C "Logoff $sessionID " )    
        }
        return $myObj
    }
    return $allObj
}

function Get-UserSessions {
    param (
        [Parameter(Mandatory = $true, ValueFromPipeline = $true, Position = 0)]
        [string[]]$server,
        [Parameter(Mandatory = $true, ValueFromPipeline = $true, Position = 1)]
        [PSCredential]$credentials
    )
    $allObj = @()
    $allObj += Invoke-Command -ComputerName $server -Credential $credentials -ScriptBlock {
        $computer = $env:COMPUTERNAME
        $allSessions = (query user);
        $myObj = @()
        $allSessions | Select-Object -skip 1 |
		ForEach-Object {
            if(($_ -split "\s+").count -eq 9){       # CONNECTED     = 9 columns English
                $myObj += [PSCustomObject]@{
                    USERNAME = ($_ -split "\s+")[1]
                    SESSIONNAME = ($_ -split "\s+")[2]
                    ID           = ($_ -split "\s+")[3]
                    STATUS       = ($_ -split "\s+")[4]
                    IDLETIME     = ($_ -split "\s+")[5]
                    LOGONTIME  = (($_ -split "\s+")[6] + " " + ($_ -split "\s+")[7] + " " + ($_ -split "\s+")[8])
                }
            } elseif(($_ -split "\s+").count -eq 8){       # CONNECTED     = 8 columns
                $myObj += [PSCustomObject]@{
                    USERNAME = ($_ -split "\s+")[1]
                    SESSIONNAME = ($_ -split "\s+")[2]
                    ID           = ($_ -split "\s+")[3]
                    STATUS       = ($_ -split "\s+")[4]
                    IDLETIME     = ($_ -split "\s+")[5]
                    LOGONTIME  = (($_ -split "\s+")[6] + " " + ($_ -split "\s+")[7])
                }
            } elseif(($_ -split "\s+").count -eq 7){ # DISCONNTECTED = 7 columns
                $myObj += [PSCustomObject]@{
                    USERNAME = ($_ -split "\s+")[1]
                    SESSIONNAME = "" 
                    ID           = ($_ -split "\s+")[2]
                    STATUS       = ($_ -split "\s+")[3]
                    IDLETIME     = ($_ -split "\s+")[4]
                    LOGONTIME  = (($_ -split "\s+")[5] + " " + ($_ -split "\s+")[6])
                }
            } else {
                Write-Error("{0} The amount of columns is neither 7 nor 8 nor 9 at this column:" -f $computer)
                Write-Error($_)
            }
        }
        return $myObj
    }
    return $allObj
}

$server=@()
$server+="SVRRDSH03"
$server+="SVRRDSH04"
$server+="SVRRDSH05"

if (-not $cred) {
    $cred = Get-Credential -Message "Please input adminstrative priviledges on the target hosts"
}

if ($cred) {
    Get-UserSessions -server $server -credentials $cred
    # Remove-UserSessions -server $server -credentials $cred #-all
}