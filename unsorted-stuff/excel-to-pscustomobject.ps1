# This function enables you to copy information from Excel to a pscustomobject
# In Excel CTRL+A CTRL+C, then in powershell type e2p, return is a pscustomobject which can then be used in powershell afterwards
function e2p {
    [CmdletBinding()]

    $cli    
    $spaltennamen = $clip | Select-Object -First 1 | Where-Object { $_ } | ForEach-Object {
        $_ -split "`t"
    }
    
    $erstedatenzeile = $clip | Select-Object -Skip 1 -First 1 | Where-Object { $_ } | ForEach-Object {
        $_ -split "`t"
    }
    
    $excelsheet = @()
    $myline = [pscustomobject]@{}
    $i = 0 
    foreach ($spaltenname in $spaltennamen) {
        $myline | Add-Member -MemberType NoteProperty -Name $spaltenname -Value $erstedatenzeile[$i]
        $i += 1
    }
    $excelsheet += $myline
    
    
    $clip | Select-Object -Skip 2 | Where-Object { $_ } | ForEach-Object {
        $zeile = $_ -split "`t"
        $myline = [pscustomobject]@{}
        $j = 0
        foreach ($spaltenname in $spaltennamen) {
            $myline | Add-Member -MemberType NoteProperty -Name $spaltenname -Value $zeile[$j]
            $j += 1
        }
        $excelSheet += $myline 
    }
    
    
    return $excelSheet
}p = Get-Clipboard

    
$erg = e2p
$a = ($erg | Where-Object {$_.Hostname -eq "" -or $_.Name -eq ""} | Select-Object Hostname).Hostname
Test-ConnectionInParallel -computers $a

$erg | ConvertTo-Json
