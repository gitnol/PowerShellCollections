$credential = (Get-Credential)
$exchserver = "myexchange.mycorp.local"

try {
    $session = New-PSSession -ConfigurationName Microsoft.Exchange -ConnectionUri $exchserver -Authentication Kerberos -Credential $credential
    # Make Exchange-specific commands available
    Import-PSSession -Session $session -AllowClobber

    # in the context of the exchange server
    $mailboxes = Get-Mailbox -ResultSize Unlimited

    # Initialize an array to store forwarding rules
    $forwardingRules = @()

    # Loop through each mailbox and get inbox rules
    foreach ($mailbox in $mailboxes) {
        Write-Host($mailbox.Alias) -ForegroundColor Magenta
        $rules = Get-InboxRule -Mailbox $mailbox.Alias
        foreach ($rule in $rules) {
            # Check if the rule has a ForwardTo or RedirectTo action
            if ($rule.ForwardTo -or $rule.RedirectTo) {
                # Add relevant information to the array
                $forwardingRules += [PSCustomObject]@{
                    Mailbox    = $mailbox.PrimarySmtpAddress
                    RuleName   = $rule.Name
                    ForwardTo  = $rule.ForwardTo -join "; "
                    RedirectTo = $rule.RedirectTo -join "; "
                    Enabled    = $rule.Enabled
                }
            }
        }
    }

}
catch {
    Write-Error ("Error importing the session`r`n {0}" -f $_)
    return
}



try {
    Remove-PSSession $Session
}
catch {
    Write-Log "Error when removing the session: $_" -path $logPfad
}
