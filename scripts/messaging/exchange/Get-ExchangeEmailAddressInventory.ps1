<#
.SYNOPSIS
    Listet alle E-Mail-Adressen aller Exchange-Empfänger auf - eine Zeile je
    Adresse statt je Empfänger.

.DESCRIPTION
    Ein Empfänger trägt in der Regel mehrere Proxy-Adressen: die primäre
    SMTP-Adresse, Aliasse aus früheren Namensschemata, X500-Adressen aus
    Migrationen. In der Exchange-Verwaltung stehen sie als Liste in einem
    Feld und lassen sich dort weder sortieren noch durchsuchen.

    Dieses Skript flacht die Liste auf: je Adresse eine Zeile mit dem
    zugehörigen Empfänger. Damit beantworten sich die üblichen Fragen per
    Where-Object und Group-Object statt von Hand:

      - Welche Domänen sind überhaupt als Adresse in Gebrauch?
      - Wer trägt noch eine Adresse der alten Firmendomäne?
      - Gibt es dieselbe Adresse doppelt?

    Die Ausgabe ist bewusst unformatiert - sie geht in Export-Csv,
    Out-GridView oder eine Pipeline weiter.

.PARAMETER Identity
    Ein oder mehrere Empfänger. Ohne Angabe werden alle erfasst.

.PARAMETER Filter
    OPATH-Filter, wie ihn Get-Recipient versteht, etwa
    "Office -eq 'Berlin'". Wird serverseitig ausgewertet.

.PARAMETER RecipientTypeDetails
    Einschränkung auf bestimmte Empfängertypen, etwa UserMailbox oder
    SharedMailbox. Mehrere Werte sind zulässig.

.PARAMETER OrganizationalUnit
    Einschränkung auf eine OU.

.PARAMETER ResultSize
    Maximale Trefferzahl. Standard: Unlimited. Ohne diesen Wert liefert
    Get-Recipient nur die ersten 1000 Empfänger - stillschweigend.

.EXAMPLE
    .\Get-ExchangeEmailAddressInventory.ps1 |
        Export-Csv .\adressen.csv -NoTypeInformation -Encoding UTF8 -Delimiter ';'

.EXAMPLE
    .\Get-ExchangeEmailAddressInventory.ps1 |
        Where-Object Domain -eq 'alte-firma.example' |
        Select-Object DisplayName, EmailAddress, IsPrimarySmtpAddress

    Wer trägt noch Adressen einer abzulösenden Domäne - und bei wem ist sie
    sogar die primäre?

.EXAMPLE
    .\Get-ExchangeEmailAddressInventory.ps1 |
        Group-Object EmailAddress |
        Where-Object Count -gt 1

    Doppelt vergebene Adressen. Sollte leer sein.

.EXAMPLE
    .\Get-ExchangeEmailAddressInventory.ps1 -RecipientTypeDetails SharedMailbox |
        Group-Object Domain |
        Sort-Object Count -Descending

.OUTPUTS
    PSCustomObject mit Name, DisplayName, Alias, RecipientType,
    RecipientTypeDetails, PrimarySmtpAddress, ProxyAddress, AddressType,
    EmailAddress, Domain, IsPrimarySmtpAddress, HiddenFromAddressLists,
    Identity

.NOTES
    Setzt eine bestehende Exchange-Sitzung voraus - lokal über die Exchange
    Management Shell, für Exchange Online über Connect-ExchangeOnline. Das
    Skript prüft das und bricht sonst mit einer klaren Meldung ab.

    AddressType ist kleingeschrieben normalisiert (smtp, x500, sip). Im
    Rohwert unterscheidet Exchange über die Schreibweise: SMTP: ist die
    primäre Adresse, smtp: eine weitere. Diese eine Information steht in
    IsPrimarySmtpAddress; ohne die Normalisierung zerfiele jede Gruppierung
    nach AddressType in zwei Gruppen.

    Domain wird nur für SMTP-Adressen gefüllt. Eine SIP-Adresse hat zwar
    auch einen Domänenteil, gehört aber nicht in eine Auswertung der
    E-Mail-Domänen - sonst verfälscht sie jede Gruppierung nach Domain.

    HiddenFromAddressLists kann leer bleiben. Die Dokumentation zu
    Get-Recipient weist ausdrücklich darauf hin, dass objektspezifische
    Eigenschaften nicht zurückgegeben werden - dafür braucht es Get-Mailbox
    und Verwandte. Der Wert ist also ein Hinweis, keine verlässliche Angabe.
    Der Zugriff darauf läuft über Get-PropertyOrNull: unter
    Set-StrictMode -Version Latest würde ein direkter Zugriff auf eine
    fehlende Eigenschaft das Skript abbrechen lassen, statt die Spalte leer
    zu lassen.

    In Exchange Online empfiehlt Microsoft Get-EXORecipient statt
    Get-Recipient; dieses Skript nutzt bewusst Get-Recipient, weil es in
    beiden Welten vorhanden ist.

    Empfänger ohne jede Proxy-Adresse erzeugen trotzdem eine Zeile, mit
    leerem EmailAddress. Das ist ein Ausnahmefall und gerade deshalb
    interessant - er soll nicht stillschweigend aus der Liste fallen.

    Autor: IT-Administration
#>
[CmdletBinding()]
param(
    [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
    [string[]]$Identity,

    [string]$Filter,

    [string[]]$RecipientTypeDetails,

    [string]$OrganizationalUnit,

    $ResultSize = 'Unlimited'
)

begin {
    Set-StrictMode -Version Latest
    $ErrorActionPreference = 'Stop'

    if (-not (Get-Command -Name Get-Recipient -ErrorAction SilentlyContinue)) {
        throw 'Get-Recipient ist nicht verfuegbar. Zuerst eine Exchange-Sitzung ' +
        'herstellen: Connect-ExchangeOnline fuer Exchange Online, sonst die ' +
        'Exchange Management Shell verwenden.'
    }

    # Nur die tatsaechlich gesetzten Parameter weiterreichen - Get-Recipient
    # kennt verschiedene Parametersaetze, und ein leerer Filter oder eine
    # leere OU wuerden sie gegeneinander ausschliessen.
    $common = @{ ResultSize = $ResultSize }
    if ($Filter) { $common['Filter'] = $Filter }
    if ($RecipientTypeDetails) { $common['RecipientTypeDetails'] = $RecipientTypeDetails }
    if ($OrganizationalUnit) { $common['OrganizationalUnit'] = $OrganizationalUnit }

    function Get-PropertyOrNull {
        <#
        .SYNOPSIS
            Liest eine Eigenschaft, die es moeglicherweise nicht gibt.

        .DESCRIPTION
            Unter Set-StrictMode -Version Latest wirft der Zugriff auf eine
            nicht vorhandene Eigenschaft eine PropertyNotFoundException. Da
            Get-Recipient laut Dokumentation objektspezifische Eigenschaften
            nicht zwingend zurueckgibt, wuerde das Skript daran abbrechen,
            statt die Spalte leer zu lassen.
        #>
        param(
            [Parameter(Mandatory)]
            $InputObject,

            [Parameter(Mandatory)]
            [string]$Name
        )

        if ($InputObject.PSObject.Properties[$Name]) {
            return $InputObject.$Name
        }
        return $null
    }

    function ConvertTo-AddressRow {
        <#
        .SYNOPSIS
            Macht aus einem Empfaenger je Proxy-Adresse eine Ergebniszeile.
        #>
        param(
            [Parameter(Mandatory)]
            $Recipient
        )

        $proxyAddresses = @($Recipient.EmailAddresses)
        if ($proxyAddresses.Count -eq 0) { $proxyAddresses = @($null) }

        foreach ($proxyAddress in $proxyAddresses) {
            $raw = [string]$proxyAddress

            $addressType = $null
            $addressValue = $null

            if ($raw) {
                # Aufteilen am ersten Doppelpunkt. IndexOf statt Regex: der
                # Wert selbst darf Doppelpunkte enthalten (X500-Adressen tun
                # das regelmaessig), nur der erste trennt Typ und Wert.
                $separator = $raw.IndexOf(':')
                if ($separator -gt 0) {
                    $addressType = $raw.Substring(0, $separator).ToLowerInvariant()
                    $addressValue = $raw.Substring($separator + 1)
                }
                else {
                    $addressValue = $raw
                }
            }

            # Grossschreibung des Praefixes kennzeichnet die primaere Adresse.
            # Ordinal vergleichen, damit die Kultur des Systems das Ergebnis
            # nicht beeinflusst.
            $isPrimary = $raw -and $raw.StartsWith('SMTP:', [System.StringComparison]::Ordinal)

            $domain = $null
            if ($addressType -eq 'smtp' -and $addressValue -and $addressValue.Contains('@')) {
                $domain = $addressValue.Substring($addressValue.LastIndexOf('@') + 1).ToLowerInvariant()
            }

            [PSCustomObject]@{
                Name                   = $Recipient.Name
                DisplayName            = $Recipient.DisplayName
                Alias                  = $Recipient.Alias
                RecipientType          = [string]$Recipient.RecipientType
                RecipientTypeDetails   = [string]$Recipient.RecipientTypeDetails
                PrimarySmtpAddress     = [string]$Recipient.PrimarySmtpAddress
                ProxyAddress           = $raw
                AddressType            = $addressType
                EmailAddress           = $addressValue
                Domain                 = $domain
                IsPrimarySmtpAddress   = [bool]$isPrimary
                HiddenFromAddressLists = Get-PropertyOrNull -InputObject $Recipient -Name 'HiddenFromAddressListsEnabled'
                Identity               = [string]$Recipient.Identity
            }
        }
    }
}

process {
    # Streamen statt sammeln: bei einer grossen Organisation muessen nicht
    # erst alle Empfaenger im Speicher liegen, bevor die erste Zeile
    # entsteht.
    if ($Identity) {
        foreach ($single in $Identity) {
            Get-Recipient -Identity $single @common | ForEach-Object {
                ConvertTo-AddressRow -Recipient $_
            }
        }
    }
    else {
        Get-Recipient @common | ForEach-Object {
            ConvertTo-AddressRow -Recipient $_
        }
    }
}
