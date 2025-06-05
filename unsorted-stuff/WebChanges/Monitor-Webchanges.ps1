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

    $urlsToCheck = @()
    if ($Url) {
        $urlsToCheck += $Url
    }
    else {
        $urlsToCheck += $state.Keys | Where-Object {
            $s = $state[$_]
            $null -ne $s.NeuHash -or $null -ne $s.NeuFound
        }
    }

    foreach ($u in $urlsToCheck) {
        if (-not $state.ContainsKey($u)) {
            Write-Warning "URL nicht in Status-Datei: $u"
            continue
        }

        $s = $state[$u]
        if ($null -eq $s.NeuHash -and $null -eq $s.NeuFound) {
            Write-Host "Keine neuen Änderungen bei: $u"
            continue
        }

        if (-not $Url) {
            Write-Host ""
            Write-Host "Änderung erkannt für:"
            Write-Host "  URL: $u"
            Write-Host "  Alter Hash: $($s.Hash)"
            Write-Host "  Neuer Hash: $($s.NeuHash)"
            Write-Host "  Text vorher gefunden: $($s.FoundText)"
            Write-Host "  Text jetzt gefunden:  $($s.NeuFound)"
            
            $skipToNext = $false
            while (-not $skipToNext) {
                $eingabe = Read-Host "Aktion? (j=ja / n=nein / s=überspringen / o=öffnen / q=abbrechen)"
                switch ($eingabe.ToLower()) {
                    'j' {
                        $s.Hash = $s.NeuHash
                        $s.FoundText = $s.NeuFound
                        $s.NeuHash = $null
                        $s.NeuFound = $null
                        Write-Host "Änderung bestätigt: $u"
                        $skipToNext = $true
                    }
                    'n' {
                        $s.NeuHash = $null
                        $s.NeuFound = $null
                        Write-Host "Änderung verworfen: $u"
                        $skipToNext = $true
                    }
                    's' {
                        Write-Host "Übersprungen: $u"
                        $skipToNext = $true
                    }
                    'o' {
                        Start-Process $u
                    }
                    'q' {
                        Write-Host "Abbruch durch Benutzer."
                        return
                    }
                    default {
                        Write-Host "Ungültige Eingabe."
                    }
                }
            }
        }
        else {
            $s.Hash = $s.NeuHash
            $s.FoundText = $s.NeuFound
            $s.NeuHash = $null
            $s.NeuFound = $null
            Write-Host "Änderung bestätigt: $u"
        }
    }

    try {
        $state | ConvertTo-Json -Depth 5 | Set-Content -Encoding UTF8 -Path $StateDatei -Force
    }
    catch {
        Write-Warning "Fehler beim Speichern des bestätigten States: $_"
    }
}


# Test-WebChanges -EingabeDatei "urls.txt" -StateDatei "state.json"
# Confirm-WebChange -Url "https://help-viewer.kisters.de/desktop/en/3dvs_versioninfo_intro.php"
# Confirm-WebChange -Url "https://www.teamviewer.com/de/global/support/knowledge-base/teamviewer-remote/download-and-installation/supported-operating-systems-for-teamviewer-remote"

# urls.txt
# https://help-viewer.kisters.de/desktop/en/3dvs_versioninfo_intro.php | 2025.2.312
# https://www.teamviewer.com/de/global/support/knowledge-base/teamviewer-remote/download-and-installation/supported-operating-systems-for-teamviewer-remote | TeamViewer 15.64
