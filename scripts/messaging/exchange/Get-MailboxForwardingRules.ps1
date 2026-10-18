<#
.SYNOPSIS
    Findet Postfaecher mit eingerichteter Weiterleitung nach aussen.

.DESCRIPTION
    Baut eine Remote-Session zum Exchange-Server auf und prueft alle
    Postfaecher auf ForwardingAddress und ForwardingSmtpAddress.

    Das ist eine Standardpruefung nach einem Verdacht auf Kontouebernahme:
    eine unbemerkt eingerichtete Weiterleitung ist der uebliche Weg, um
    dauerhaft mitzulesen, auch nachdem das Passwort geaendert wurde.

.NOTES
    Die Session wird am Ende wieder abgebaut - sonst laeuft man in das
    Verbindungslimit von Exchange.

    Die Datei ist eigenstaendig lauffaehig. Sie rief frueher ein Write-Log
    auf, das es hier nicht gibt, mit einem Parameter -path, den auch keine
    der Nachbardefinitionen kennt, und einer nie gesetzten Variablen.

    Der Exchange-Server steht als Variable $exchserver am Dateianfang.
#>

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
    # War frueher ein Write-Log-Aufruf mit -path $logPfad. Beides gab es
    # nicht: die Funktion wird in dieser Datei nicht definiert, und $logPfad
    # war nie gesetzt. Der Rest der Datei meldet ueber Write-Error und
    # Write-Host - hier reicht eine Warnung, die Sitzung ist ohnehin am Ende.
    Write-Warning "Fehler beim Schliessen der Exchange-Sitzung: $_"
}
