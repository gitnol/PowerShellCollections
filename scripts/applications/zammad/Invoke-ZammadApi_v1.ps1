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
        Invoke-RestMethod @Params
    } catch {
        Write-Error "Error: $_"
    }
}

function Get-ZammadTicket {
    param (
        [Parameter(Mandatory)] [int]$TicketId,
        [Parameter(Mandatory)] [string]$Token,
        [Parameter(Mandatory)] [string]$BaseUrl
    )
    
    Invoke-ZammadRequest -Method GET -Endpoint "tickets/$TicketId" -Token $Token -BaseUrl $BaseUrl
}

function New-ZammadTicket {
    param (
        [Parameter(Mandatory)] [string]$Title,
        [Parameter(Mandatory)] [string]$Group,
        [Parameter(Mandatory)] [string]$Customer,
        [Parameter(Mandatory)] [string]$State,
        [Parameter(Mandatory)] [string]$Priority,
        [Parameter()] [string]$Owner,
        [Parameter(Mandatory)] [string]$Token,
        [Parameter(Mandatory)] [string]$BaseUrl
    )
    
    $Body = @{ 
        title = $Title
        group = $Group
        customer = $Customer
        state = $State
        priority = $Priority
    }
    
    if ($Owner) { $Body.owner = $Owner }
    
    Invoke-ZammadRequest -Method POST -Endpoint "tickets" -Body $Body -Token $Token -BaseUrl $BaseUrl
}

function Set-ZammadTicket {
    param (
        [Parameter(Mandatory)] [int]$TicketId,
        [Parameter(Mandatory)] [hashtable]$UpdateFields,
        [Parameter(Mandatory)] [string]$Token,
        [Parameter(Mandatory)] [string]$BaseUrl
    )
    
    Invoke-ZammadRequest -Method PUT -Endpoint "tickets/$TicketId" -Body $UpdateFields -Token $Token -BaseUrl $BaseUrl
}

function Get-ZammadUser {
    param (
        [Parameter(Mandatory)] [int]$UserId,
        [Parameter(Mandatory)] [string]$Token,
        [Parameter(Mandatory)] [string]$BaseUrl
    )
    
    Invoke-ZammadRequest -Method GET -Endpoint "users/$UserId" -Token $Token -BaseUrl $BaseUrl
}

function New-ZammadUser {
    param (
        [Parameter(Mandatory)] [string]$Firstname,
        [Parameter(Mandatory)] [string]$Lastname,
        [Parameter(Mandatory)] [string]$Email,
        [Parameter(Mandatory)] [string]$Token,
        [Parameter(Mandatory)] [string]$BaseUrl
    )
    
    $Body = @{ 
        firstname = $Firstname
        lastname = $Lastname
        email = $Email
    }
    
    Invoke-ZammadRequest -Method POST -Endpoint "users" -Body $Body -Token $Token -BaseUrl $BaseUrl
}

function Set-ZammadUser {
    param (
        [Parameter(Mandatory)] [int]$UserId,
        [Parameter(Mandatory)] [hashtable]$UpdateFields,
        [Parameter(Mandatory)] [string]$Token,
        [Parameter(Mandatory)] [string]$BaseUrl
    )
    
    Invoke-ZammadRequest -Method PUT -Endpoint "users/$UserId" -Body $UpdateFields -Token $Token -BaseUrl $BaseUrl
}

function Get-ZammadGroups {
    param (
        [Parameter(Mandatory)] [string]$Token,
        [Parameter(Mandatory)] [string]$BaseUrl
    )
    
    Invoke-ZammadRequest -Method GET -Endpoint "groups" -Token $Token -BaseUrl $BaseUrl
}

function Get-ZammadOrganizations {
    param (
        [Parameter(Mandatory)] [string]$Token,
        [Parameter(Mandatory)] [string]$BaseUrl
    )
    
    Invoke-ZammadRequest -Method GET -Endpoint "organizations" -Token $Token -BaseUrl $BaseUrl
}

function Get-ZammadTicketArticles {
    param (
        [Parameter(Mandatory)] [int]$TicketId,
        [Parameter(Mandatory)] [string]$Token,
        [Parameter(Mandatory)] [string]$BaseUrl
    )
    
    Invoke-ZammadRequest -Method GET -Endpoint "tickets/$TicketId/articles" -Token $Token -BaseUrl $BaseUrl
}
