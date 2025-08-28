# Parameter: Start- und Enddatum für den Abfragezeitraum
$StartDate = (get-date).AddDays(-1)
$EndDate = (get-date)


####

# Letzter Monat
$today = Get-Date

# Erster Tag des aktuellen Monats
$firstOfThisMonth = Get-Date -Year $today.Year -Month $today.Month -Day 1

# Letzter Tag des Vormonats = einen Tag vor dem ersten Tag des aktuellen Monats
$lastOfLastMonth = $firstOfThisMonth.AddDays(-1)

# Erster Tag des Vormonats
$firstOfLastMonth = Get-Date -Year $lastOfLastMonth.Year -Month $lastOfLastMonth.Month -Day 1

# Ausgabe
[PSCustomObject]@{
    StartDate = $firstOfLastMonth
    EndDate   = $lastOfLastMonth
}
$StartDate = $firstOfLastMonth
$EndDate = $lastOfLastMonth

####
# $fromDate = [Datetime]::ParseExact("14.08.2025", 'dd.MM.yyyy', $null)
# $toDate = ([Datetime]::ParseExact("15.08.2025", 'dd.MM.yyyy', $null))
# Get-NspMessageTrack -WithAddresses -Directions All -from $fromDate -To $toDate

# Get-NspMessageTrack gibt Datensätze im Zeitraum zurück
# Filter auf Zeitraum durch -Age Parameter mit Start- und Endalter (in Tagen) nicht direkt möglich
# Daher Nutzung eines größeren Zeitraums und Filterung anschließend im Skript

Connect-Nsp -IgnoreServerCertificateErrors 
# Hole alle MessageTrack-Objekte im maximalen Zeitraum
# $maxAge = ($EndDate - $StartDate)
# $allMessages = Get-NspMessageTrack -Status Success -Age $maxAge -WithFilters:$false -WithActions:$false -WithAddresses:$true

# $allMessages = Get-NspMessageTrack -WithAddresses -Directions All -from ([Datetime]::ParseExact("14.08.2025", 'dd.MM.yyyy', $null)) -To ([Datetime]::ParseExact("15.08.2025", 'dd.MM.yyyy', $null)) -WithFilters -WithActions -Status Success | Where Subject -notlike "Automatische Antwort*" 

# Nutzung der Variablen StartDaten und EndDate
$allMessages = Get-NspMessageTrack -WithAddresses -Directions FromLocal -from ([Datetime]$StartDate) -To ([Datetime]$EndDate) -Status Success | Where-Object Subject -notlike "Automatische Antwort*"

# Status
# ------
# PermanentlyBlocked
# Success
# DispatcherError
# DeliveryPending
# TemporarilyBlocked
# PutOnHold


# Filtere Nachrichten, die im definierten Zeitraum liegen
$filteredMessages = $allMessages | Where-Object {
    $_.Sent -ge $StartDate -and $_.Sent -le $EndDate
}


$myDomains = @()
$myDomains += "mydomain.local"

# Erzeuge PSCustomObjects für Sender und Empfänger
# $result = $filteredMessages | Select -property Addresses | % {
# $addresses = $_.Addresses
# $direction = "unknown"

# foreach ($address in $addresses) {

# if ($address.AddressType -eq "Sender") {
# $from = $address.Address
# $fromDomain = $address.Domain
# if ($address.Domain -in $myDomains){$direction="out"}
# }
# if ($address.AddressType -eq "Recipient") {
# $to = $address.Address
# $toDomain = $address.Domain
# if ($address.Domain -in $myDomains){$direction="in"}
# }
# if ($address.AddressType -eq "HeaderFrom") {
# $HeaderFrom = $address.Address
# $HeaderFromDomain = $address.Domain
# if ($address.Domain -in $myDomains){$direction="out"}
# }

# }
# [PSCustomObject]@{from=$from;fromDomain=$fromDomain;HeaderFrom=$HeaderFrom;HeaderFromDomain=$HeaderfromDomain;to=$to;toDomain=$toDomain;direction=$direction}
# }

# Erzeuge PSCustomObjects für Sender und Empfänger
$result = $filteredMessages | Select-Object -Property Addresses | ForEach-Object {
    $addresses = $_.Addresses
    $direction = "unknown"
    foreach ($address in $addresses) {
        switch ($address.AddressType) {
            "Sender" {
                $from = $address.Address
                $fromDomain = $address.Domain
                if ($address.Domain -in $myDomains) { $direction = "out" }
            }
            "Recipient" {
                $to = $address.Address
                $toDomain = $address.Domain
                if ($address.Domain -in $myDomains) { $direction = "in" }
            }
            "HeaderFrom" {
                $HeaderFrom = $address.Address
                $HeaderFromDomain = $address.Domain
                if ($address.Domain -in $myDomains) { $direction = "out" }
            }
        }
    }
    [PSCustomObject]@{
        from             = $from
        fromDomain       = $fromDomain
        HeaderFrom       = $HeaderFrom
        HeaderFromDomain = $HeaderFromDomain
        to               = $to
        toDomain         = $toDomain
        direction        = $direction
    }
}


# Ergebnis zur weiteren Verarbeitung zurückgeben
# return $result

# von mydomain user nach externer domain sortiert
# $result | Where from -ne "noreply@mydomain.local" | Select from,toDomain -Unique | Sort-Object -Property from,toDomain | ogv
# $result | Where from -ne "noreply@mydomain.local" | Select from,to,toDomain -Unique | Sort-Object -Property from,to,toDomain | ogv

# Die häufigsten Empfänger
$result | Group-Object -Property from, to | ForEach-Object {
    $group = $_
    $first = $group.Group[0]
    [PSCustomObject]@{
        from  = $first.from
        to    = $first.to
        count = $group.Count
    }
} | Sort-Object count -Descending | Select-Object -first 40 | Out-GridView