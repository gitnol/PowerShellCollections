# Source: https://stackoverflow.com/questions/16347214/pass-arguments-to-a-scriptblock-in-powershell
$myScriptBlock = {
    param($p1,$p2)
    $OFS=','
    "p1 is $p1, p2 is $p2, rest of args: $args"
}

Invoke-Command $myScriptBlock -ArgumentList 1,2,3,4
# Output: 
# p1 is 1, p2 is 2, rest of args: 3,4