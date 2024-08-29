# This function enables you to copy information from Excel to a pscustomobject
# In Excel CTRL+A CTRL+C, then in powershell type e2p, return is a pscustomobject which can then be used in powershell afterwards
function e2p {
    [CmdletBinding()]

    # This object holds the rows and columns in form of multiple pscustomobject in this array
    $excelsheet = @()

    # Get the marked and copied Excel content
    $clip = Get-Clipboard 

    # get the columnheaders
    $spaltennamen = $clip | Select-Object -First 1 | Where-Object { $_ } | ForEach-Object {
        $_ -split "`t"
    }
    
    # Get the content from line 2 onwards
    $clip | Select-Object -Skip 1 | Where-Object { $_ } | ForEach-Object {
        $zeile = $_ -split "`t"
        $myline = [pscustomobject]@{}
        $j = 0
        foreach ($spaltenname in $spaltennamen) {
            # Add-Member is needed, because the column headers have to be dynamically added
            $myline | Add-Member -MemberType NoteProperty -Name $spaltenname -Value $zeile[$j]
            $j += 1
        }
        # add the line as pscustomobject to the array
        $excelSheet += $myline 
    }
    
    return $excelSheet
}

# get the clipboard content and add it to a variable
$erg = e2p
# use the $erg where the column Hostname and the column are set and then use the column Hostname to...
$a = ($erg | Where-Object {$_.Hostname -eq "" -or $_.Name -eq ""} | Select-Object Hostname).Hostname
# ... check the online status of the Hosts
Test-ConnectionInParallel -computers $a

# This example is a quick an easy way to convert excel sheet contents into json
$erg | ConvertTo-Json
# This example is a quick an easy way to convert excel sheet contents into json and the save it directly to a mytest.json file
$erg | ConvertTo-Json | Out-File -LiteralPath "c:\temp\mytest.json" -Encoding utf8
