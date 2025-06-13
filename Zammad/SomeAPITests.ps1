function Get-ZammadTickets {
    param (
        [string]$ZammadUrl,           # Base URL of Zammad API
        [string]$ApiToken,            # API Token for authentication
        [int]$Days,                   # Number of days in the past
        [string[]]$Statuses           # Array of statuses (OR condition)
    )

    $headers = @{
        "Authorization" = "Token token=$ApiToken"
        "Content-Type"  = "application/json"
    }

    # Convert status array to OR condition for search query
    $statusQuery = ($Statuses | ForEach-Object { "state.name:`"$_`"" }) -join " OR "

    # Build search query
    $query = "created_at:>=now-${Days}d AND ($statusQuery)"

    # Construct API URL
    $apiUrl = "$ZammadUrl/api/v1/tickets/search?query=$([uri]::EscapeDataString($query))"

    # Fetch data
    $response = Invoke-RestMethod -Uri $apiUrl -Method Get -Headers $headers

    return $response
}



function Get-ZammadTicketDetails {
    param (
        [string]$ZammadUrl,
        [string]$ApiToken,
        [int[]]$TicketIds
    )

    $headers = @{
        "Authorization" = "Token token=$ApiToken"
        "Content-Type"  = "application/json"
    }

    $ticketDetails = @()

    foreach ($TicketId in $TicketIds) {
        $apiUrl = "$ZammadUrl/api/v1/tickets/$TicketId"
        $ticket = Invoke-RestMethod -Uri $apiUrl -Method Get -Headers $headers

        $articlesUrl = "$ZammadUrl/api/v1/tickets/$TicketId/articles"
        $articlesUrl = "$ZammadUrl/api/v1/tickets/$TicketId"
        $articles = Invoke-RestMethod -Uri $articlesUrl -Method Get -Headers $headers

        $ticketDetails += [PSCustomObject]@{
            TicketID       = $ticket.id
            Title         = $ticket.title
            State         = $ticket.state
            CreatedAt     = $ticket.created_at
            UpdatedAt     = $ticket.updated_at
            Owner         = if ($ticket.PSObject.Properties['owner'] -and $ticket.owner) { $ticket.owner.email } else { "N/A" }
            LastUpdatedBy = $ticket.last_contact_agent_at
            Articles      = $articles | Select-Object -Property id, type, created_at, sender, from, to, subject, body
        }
    }

    return $ticketDetails
}

# Example usage:
$ZammadUrl = "https://your-zammad-instance.com"
$ApiToken = "your-api-token"
$TicketIds = @(9680, 9679, 9631, 9636)  # Replace with actual IDs

$TicketHistory = Get-ZammadTicketDetails -ZammadUrl $ZammadUrl -ApiToken $ApiToken -TicketIds $TicketIds
$TicketHistory | Format-List

# Example usage:
$ZammadUrl = "https://your-zammad-instance.com"
$ApiToken = "your-api-token"
$Days = 30
$Statuses = @("open", "new", "pending close")

$tickets = Get-ZammadTickets -ZammadUrl $ZammadUrl -ApiToken $ApiToken -Days $Days -Statuses $Statuses
$tickets

(Invoke-RestMethod -Uri https://helpdesk.lewa-attendorn.local/api/v1/tickets/9680?all=true -Method Get -Headers $headers).ticket_article_ids
Invoke-RestMethod -Uri https://helpdesk.lewa-attendorn.local/api/v1/tickets/9680?all=true -Method Get -Headers $headers