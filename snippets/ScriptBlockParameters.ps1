<#
.SYNOPSIS
    Zeigt, wie man Argumente an einen Scriptblock uebergibt.

.DESCRIPTION
    Ein Scriptblock kann einen eigenen param()-Block haben. Ueber
    -ArgumentList uebergebene Werte werden der Reihe nach zugewiesen;
    ueberzaehlige landen in $args.

    Codebeispiel zum Nachschlagen, kein Betriebswerkzeug.

.NOTES
    Quelle:
    https://stackoverflow.com/questions/16347214/pass-arguments-to-a-scriptblock-in-powershell
#>

# Source: https://stackoverflow.com/questions/16347214/pass-arguments-to-a-scriptblock-in-powershell
$myScriptBlock = {
    param($p1,$p2)
    $OFS=','
    "p1 is $p1, p2 is $p2, rest of args: $args"
}

Invoke-Command $myScriptBlock -ArgumentList 1,2,3,4
# Output: 
# p1 is 1, p2 is 2, rest of args: 3,4