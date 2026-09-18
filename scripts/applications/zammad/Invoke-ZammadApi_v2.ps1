# Zammad API PowerShell Modul

function Invoke-ZammadRequest {
    param (
        [string]$Method,
        [string]$Endpoint,
        [hashtable]$Body = @{},
        [string]$Token,
        [string]$BaseUrl
    )
    
    $Headers = @{ Authorization = "Token token=$Token" }
    $Uri = "$BaseUrl/api/v1/$Endpoint"
    $Params = @{ Headers = $Headers; Method = $Method; Uri = $Uri; ContentType = 'application/json' }
    
    if ($Body.Count -gt 0) {
        $Params.Body = ($Body | ConvertTo-Json -Depth 10)
    }
    
    try {
        Write-Host($Params.Uri)
        Invoke-RestMethod @Params
    }
    catch {
        Write-Error "Error: $_"
    }
}

# Generic
function Get-ZammadGenericEndpoint {
    param (
        [string]$Token,
        [string]$BaseUrl,
        [string]$Endpoint
    )

    # tickets/search?query=$([uri]::EscapeDataString($query))
    Invoke-ZammadRequest -Method GET -Endpoint $Endpoint -Token $Token -BaseUrl $BaseUrl
}

# Tickets
function Get-ZammadTickets {
    param (
        [string]$Token,
        [string]$BaseUrl,
        [int]$Days = 30, # Number of days in the past
        [string]$SortOrder = "desc",
        [int]$Limit = 500,
        [int]$Page = 1,
        [string[]]$Statuses = @() # Array of statuses (OR condition)
    )

    $DateFrom = (Get-Date).AddDays(-$DaysBack).ToString("yyyy-MM-dd")
    $Endpoint = "tickets/search?query=created_at:>=$DateFrom&limit=$Limit&page=$Page&sort_by=created_at&order_by=$SortOrder"
    Write-Host($Endpoint)

    # Convert status array to OR condition for search query
    $statusQuery = ($Statuses | ForEach-Object { "state.name:`"$_`"" }) -join " OR "
    # Build search query
    if ($Statuses.count -eq 0) {
        $query = "created_at:>=now-${Days}d"
    }
    else {
        $query = "created_at:>=now-${Days}d AND ($statusQuery)"
    }

    # tickets/search?query=$([uri]::EscapeDataString($query))
    # Invoke-ZammadRequest -Method GET -Endpoint "tickets" -Token $Token -BaseUrl $BaseUrl
    Invoke-ZammadRequest -Method GET -Endpoint "tickets/search?query=$([uri]::EscapeDataString($query))" -Token $Token -BaseUrl $BaseUrl
}

function Get-AllZammadTickets {
    param (
        [string]$Token,
        [string]$BaseUrl
    )

    # tickets/search?query=$([uri]::EscapeDataString($query))
    Invoke-ZammadRequest -Method GET -Endpoint "tickets" -Token $Token -BaseUrl $BaseUrl
}

function Get-ZammadTicket {
    param ([int]$TicketId, [string]$Token, [string]$BaseUrl)
    Invoke-ZammadRequest -Method GET -Endpoint "tickets/$TicketId" -Token $Token -BaseUrl $BaseUrl
}

function New-ZammadTicket {
    param (
        [string]$Title, [string]$Group, [string]$Customer, [string]$State,
        [string]$Priority, [string]$Token, [string]$BaseUrl
    )
    
    $Body = @{ title = $Title; group = $Group; customer = $Customer; state = $State; priority = $Priority }
    Invoke-ZammadRequest -Method POST -Endpoint "tickets" -Body $Body -Token $Token -BaseUrl $BaseUrl
}

function Set-ZammadTicket {
    param ([int]$TicketId, [hashtable]$UpdateFields, [string]$Token, [string]$BaseUrl)
    Invoke-ZammadRequest -Method PUT -Endpoint "tickets/$TicketId" -Body $UpdateFields -Token $Token -BaseUrl $BaseUrl
}

# Benutzer
function Get-ZammadUsers {
    param ([string]$Token, [string]$BaseUrl)
    Invoke-ZammadRequest -Method GET -Endpoint "users" -Token $Token -BaseUrl $BaseUrl
}

function Get-ZammadUser {
    param ([int]$UserId, [string]$Token, [string]$BaseUrl)
    Invoke-ZammadRequest -Method GET -Endpoint "users/$UserId" -Token $Token -BaseUrl $BaseUrl
}

# Ticket-States
function Get-ZammadTicketStates {
    param ([string]$Token, [string]$BaseUrl)
    Invoke-ZammadRequest -Method GET -Endpoint "ticket_states" -Token $Token -BaseUrl $BaseUrl
}

# Gruppen
function Get-ZammadGroups {
    param ([string]$Token, [string]$BaseUrl)
    Invoke-ZammadRequest -Method GET -Endpoint "groups" -Token $Token -BaseUrl $BaseUrl
}

# Organisationen
function Get-ZammadOrganizations {
    param ([string]$Token, [string]$BaseUrl)
    Invoke-ZammadRequest -Method GET -Endpoint "organizations" -Token $Token -BaseUrl $BaseUrl
}

# Rollen
function Get-ZammadRoles {
    param ([string]$Token, [string]$BaseUrl)
    Invoke-ZammadRequest -Method GET -Endpoint "roles" -Token $Token -BaseUrl $BaseUrl
}

# Tags
function Get-ZammadTags {
    param ([string]$Token, [string]$BaseUrl)
    Invoke-ZammadRequest -Method GET -Endpoint "tags" -Token $Token -BaseUrl $BaseUrl
}

# Einstellungen
function Get-ZammadSettings {
    param ([string]$Token, [string]$BaseUrl)
    Invoke-ZammadRequest -Method GET -Endpoint "settings" -Token $Token -BaseUrl $BaseUrl
}

# # Exportiere das Skript als Datei
# $ScriptPath = "$env:TEMP\ZammadAPI.ps1.txt"
# Get-Content $PSCommandPath | Set-Content -Path $ScriptPath
# Write-Output "Das Skript wurde gespeichert unter: $ScriptPath"
