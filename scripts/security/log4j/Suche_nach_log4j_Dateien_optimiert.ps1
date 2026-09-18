param (
    [string]$Suchmuster = "*jndilookup.class*",
    [string]$AusgabePfad = "C:\install\log4j_$($env:COMPUTERNAME).txt",
    [string]$PfadZu7z = "$PSScriptRoot\7z.exe",
    [switch]$Loeschen,
    [string[]]$Allowlist = @(),
    [string[]]$Denylist = @()
)

function Invoke-ExternalCommand {
    param (
        [string]$Title,
        [string]$Path,
        [string]$Arguments
    )
    try {
        $psi = New-Object System.Diagnostics.ProcessStartInfo
        $psi.FileName = $Path
        $psi.Arguments = $Arguments
        $psi.UseShellExecute = $false
        $psi.RedirectStandardOutput = $true
        $psi.RedirectStandardError = $true
        $psi.StandardOutputEncoding = [System.Text.Encoding]::GetEncoding(1252)

        $proc = New-Object System.Diagnostics.Process
        $proc.StartInfo = $psi
        $null = $proc.Start()
        $stdout = $proc.StandardOutput.ReadToEnd()
        $stderr = $proc.StandardError.ReadToEnd()
        $proc.WaitForExit()

        [pscustomobject]@{
            Title    = $Title
            StdOut   = $stdout
            StdErr   = $stderr
            ExitCode = $proc.ExitCode
        }
    }
    catch {
        Write-Warning "Fehler bei Befehl $Title  $_"
        return $null
    }
}

function Test-JarDatei {
    param (
        [System.IO.FileInfo]$JarDatei,
        [string]$Suchmuster
    )

    $cmdResult = Invoke-ExternalCommand -Title "Scan: $($JarDatei.FullName)" `
        -Path $PfadZu7z -Arguments "l `"$($JarDatei.FullName)`""

    if ($null -eq $cmdResult) { return }

    $foundItems = $cmdResult.StdOut -split "`n" | Where-Object { $_ -like $Suchmuster }

    if ($foundItems) {
        $Treffer = $foundItems | ForEach-Object {
            ($_ -split "\s+")[-1]
        }
        return [pscustomobject]@{
            Computername = $env:COMPUTERNAME
            Datei        = $JarDatei.FullName
            Fundstellen  = $Treffer -join ", "
        }
    }
}

function Test-InList {
    param (
        [string]$Pfad,
        [string[]]$Liste
    )
    foreach ($item in $Liste) {
        if ($Pfad -like $item) { return $true }
    }
    return $false
}

# Vorbereitungen
if (-not (Test-Path -Path $PfadZu7z)) {
    Write-Error "7z.exe nicht gefunden unter $PfadZu7z"
    exit 1
}

if (Test-Path $AusgabePfad) {
    Remove-Item $AusgabePfad -Force
}

Write-Host "Starte Log4j-Suchlauf auf $env:COMPUTERNAME..."

# Laufwerke durchgehen
$Laufwerke = [System.IO.DriveInfo]::GetDrives() | Where-Object { $_.DriveType -eq 'Fixed' } | Select-Object -ExpandProperty Name

foreach ($Laufwerk in $Laufwerke) {
    try {
        Get-ChildItem -Path $Laufwerk -Include '*.jar', '*.war' -File -Recurse -Force -ErrorAction SilentlyContinue | ForEach-Object {
            $pfad = $_.FullName

            if ($Denylist.Count -gt 0 -and (Test-InList -Pfad $pfad -Liste $Denylist)) { return }
            if ($Allowlist.Count -gt 0 -and -not (Test-InList -Pfad $pfad -Liste $Allowlist)) { return }

            Write-Host "Untersuche: $pfad"
            $ergebnis = Test-JarDatei -JarDatei $_ -Suchmuster $Suchmuster

            if ($ergebnis) {
                $text = "$($ergebnis.Computername)`t$($ergebnis.Datei)`t$($ergebnis.Fundstellen)"
                Add-Content -Path $AusgabePfad -Value $text
                Write-Host "Gefunden: $text" -ForegroundColor Red

                if ($Loeschen) {
                    try {
                        Remove-Item -Path $_.FullName -Force
                        Write-Host "Datei gelöscht: $pfad" -ForegroundColor Yellow
                    }
                    catch {
                        Write-Warning "Fehler beim Löschen: $pfad - $_"
                    }
                }
            }
        }
    }
    catch {
        Write-Warning "Fehler beim Scannen von $Laufwerk $_"
    }
}

Write-Host "Scan abgeschlossen. Ergebnisse: $AusgabePfad"
