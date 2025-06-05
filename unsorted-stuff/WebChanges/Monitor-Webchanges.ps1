function Test-WebChanges {
    param (
        [string]$EingabeDatei = "urls.txt",
        [string]$StateDatei = "state.json",
        [int]$TimeoutSec = 30,
        [string]$UserAgent = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36"
    )

    if (-not (Test-Path -LiteralPath $EingabeDatei -PathType Leaf)) {
        Write-Warning "Datei '$EingabeDatei' nicht gefunden."
        return
    }

    $state = @{}
    if (Test-Path -LiteralPath $StateDatei -PathType Leaf) {
        try {
            $state = Get-Content $StateDatei -Raw -ErrorAction Stop | ConvertFrom-Json -AsHashtable -ErrorAction Stop
        }
        catch {
            Write-Warning "Fehler beim Lesen der State-Datei: $_"
            $state = @{}
        }
    }

    $urls = Get-Content $EingabeDatei
    foreach ($line in $urls) {
        if ($line -match '^(?<url>[^|]+)\s*\|\s*(?<text>.+)$') {
            $url = $matches.url.Trim()
            $searchText = $matches.text.Trim()
        }
        else {
            Write-Warning "Zeile ungültig: $line"
            continue
        }

        try {
            $response = Invoke-WebRequest -Uri $url -UseBasicParsing -TimeoutSec $TimeoutSec -UserAgent $UserAgent -ErrorAction Stop
            $content = $response.Content
        }
        catch {
            Write-Warning "FEHLER beim Abruf: $url – $_"
            continue
        }

        # Effiziente Hash-Berechnung
        $hash = [System.BitConverter]::ToString(
            [System.Security.Cryptography.SHA256]::HashData(
                [System.Text.Encoding]::UTF8.GetBytes($content)
            )
        ).Replace('-', '')

        # Case-insensitive Textsuche mit Regex
        $foundText = [bool]($content -imatch [regex]::Escape($searchText))

        if (-not $state.ContainsKey($url)) {
            $state[$url] = [ordered]@{
                Hash      = $hash
                FoundText = $foundText
                NeuHash   = $null
                NeuFound  = $null
            }
            Write-Host "Erster Check: $url – Hash gespeichert"
            continue
        }

        $oldHash = $state[$url].Hash
        $oldFound = $state[$url].FoundText

        if ($hash -ne $oldHash -or $foundText -ne $oldFound) {
            if ($state[$url].NeuHash -ne $hash -or $state[$url].NeuFound -ne $foundText) {
                $state[$url].NeuHash = $hash
                $state[$url].NeuFound = $foundText
                Write-Warning "ÄNDERUNG: $url (Hash oder Text geändert)"
            }
            else {
                Write-Warning "Noch nicht bestätigt: $url"
            }
        }
    }

    try {
        $state | ConvertTo-Json -Depth 5 | Set-Content -Encoding UTF8 -Path $StateDatei -Force
    }
    catch {
        Write-Warning "Fehler beim Speichern des States: $_"
    }
}

function Confirm-WebChange {
    param (
        [Parameter(Mandatory = $true)]
        [string]$Url,
        [string]$StateDatei = "state.json"
    )

    if (-not (Test-Path -LiteralPath $StateDatei -PathType Leaf)) {
        Write-Warning "State-Datei nicht gefunden."
        return
    }

    try {
        $state = Get-Content $StateDatei -Raw -ErrorAction Stop | ConvertFrom-Json -AsHashtable -ErrorAction Stop
    }
    catch {
        Write-Warning "Fehler beim Lesen der State-Datei: $_"
        return
    }

    if (-not $state.ContainsKey($Url)) {
        Write-Warning "URL nicht in Status-Datei: $Url"
        return
    }

    if ($null -ne $state[$Url].NeuHash) {
        $state[$Url].Hash = $state[$Url].NeuHash
        $state[$Url].FoundText = $state[$Url].NeuFound
        $state[$Url].NeuHash = $null
        $state[$Url].NeuFound = $null
        
        try {
            $state | ConvertTo-Json -Depth 5 | Set-Content -Encoding UTF8 -Path $StateDatei -Force
            Write-Host "Änderung bestätigt: $Url"
        }
        catch {
            Write-Warning "Fehler beim Speichern des bestätigten States: $_"
        }
    }
    else {
        Write-Host "Keine neue Änderung bei: $Url"
    }
}

Test-WebChanges -EingabeDatei "urls.txt" -StateDatei "state.json"
# Confirm-WebChange -Url "https://help-viewer.kisters.de/desktop/en/3dvs_versioninfo_intro.php"
# Confirm-WebChange -Url "https://www.teamviewer.com/de/global/support/knowledge-base/teamviewer-remote/download-and-installation/supported-operating-systems-for-teamviewer-remote"

# urls.txt
# https://help-viewer.kisters.de/desktop/en/3dvs_versioninfo_intro.php | 2025.2.312
# https://www.teamviewer.com/de/global/support/knowledge-base/teamviewer-remote/download-and-installation/supported-operating-systems-for-teamviewer-remote | TeamViewer 15.64
