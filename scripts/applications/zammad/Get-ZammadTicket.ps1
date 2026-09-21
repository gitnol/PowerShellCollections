<#
.SYNOPSIS
    Holt zu einer Liste von Ticket-IDs die vollstaendigen Zammad-Ticketdaten
    samt Artikeln.

.DESCRIPTION
    Baut auf ZammadApiFunctions.ps1 im selben Ordner auf: von dort kommen
    Invoke-ZammadRequest, Get-ZammadTickets und Get-ZammadTicketArticles.
    Diese Datei ergaenzt nur Get-ZammadTicketDetails, das Ticket und Artikel
    zu einem Objekt je Ticket zusammenfuehrt, und zeigt am Ende die typische
    Anwendung.

.NOTES
    Die Datei definierte frueher eine eigene Get-ZammadTickets mit anderen
    Parameternamen (-ZammadUrl/-ApiToken statt -BaseUrl/-Token). Beim
    gleichzeitigen Dot-Sourcing beider Dateien gewann die zuletzt geladene,
    und Aufrufe schlugen mit "Parameter nicht gefunden" fehl. Die Funktion
    ist entfernt; es gibt sie jetzt nur noch in der Bibliothek.

    Ebenfalls behoben: in Get-ZammadTicketDetails wurde die Artikel-URL
    unmittelbar nach dem Setzen durch die Ticket-URL ueberschrieben. Die
    Spalte Articles enthielt deshalb das Ticket statt seiner Artikel - die
    ausgewaehlten Felder (sender, from, to, subject, body) waren leer, ohne
    dass ein Fehler auftrat.
#>

# Bibliothek aus demselben Ordner laden - sie bringt Invoke-ZammadRequest,
# Get-ZammadTickets und Get-ZammadTicketArticles mit.
. (Join-Path $PSScriptRoot 'ZammadApiFunctions.ps1')

function Get-ZammadTicketDetails {
    <#
    .SYNOPSIS
        Holt zu einer oder mehreren Ticket-IDs Stammdaten und Artikel.

    .PARAMETER TicketIds
        Eine oder mehrere Ticket-IDs.

    .PARAMETER Token
        Zammad-API-Token.

    .PARAMETER BaseUrl
        Basis-URL der Zammad-Instanz, ohne /api/v1.

    .EXAMPLE
        Get-ZammadTicketDetails -TicketIds 9680, 9679 -Token $token -BaseUrl $url
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory)]
        [int[]]$TicketIds,

        [Parameter(Mandatory)]
        [string]$Token,

        [Parameter(Mandatory)]
        [string]$BaseUrl
    )

    foreach ($TicketId in $TicketIds) {
        $ticket = Invoke-ZammadRequest -Method GET -Endpoint "tickets/$TicketId" `
            -Token $Token -BaseUrl $BaseUrl

        # Eigener Endpunkt - /tickets/<id> liefert das Ticket, die Artikel
        # stehen unter /tickets/<id>/articles.
        $articles = Get-ZammadTicketArticles -TicketId $TicketId `
            -Token $Token -BaseUrl $BaseUrl

        [pscustomobject]@{
            TicketID      = $ticket.id
            Title         = $ticket.title
            State         = $ticket.state
            CreatedAt     = $ticket.created_at
            UpdatedAt     = $ticket.updated_at
            Owner         = if ($ticket.PSObject.Properties['owner'] -and $ticket.owner) { $ticket.owner.email } else { 'N/A' }
            LastUpdatedBy = $ticket.last_contact_agent_at
            Articles      = $articles | Select-Object -Property id, type, created_at, sender, from, to, subject, body
        }
    }
}

<#
Anwendungsbeispiele - bewusst in einem Kommentarblock, damit das
Dot-Sourcing dieser Datei nichts ausfuehrt.

    $BaseUrl = 'https://zammad.example.com'
    $Token   = Read-Host -AsSecureString -Prompt 'Zammad-API-Token' |
        ConvertFrom-SecureString -AsPlainText

    # Vollstaendige Daten zu einzelnen Tickets
    Get-ZammadTicketDetails -TicketIds 9680, 9679 -Token $Token -BaseUrl $BaseUrl |
        Format-List

    # Offene Tickets der letzten 30 Tage (aus der Bibliothek)
    Get-ZammadTickets -Days 30 -Statuses 'open', 'new', 'pending close' `
        -Token $Token -BaseUrl $BaseUrl

    # Nur die Artikel-IDs eines Tickets
    (Invoke-ZammadRequest -Method GET -Endpoint 'tickets/9680?all=true' `
        -Token $Token -BaseUrl $BaseUrl).ticket_article_ids
#>
