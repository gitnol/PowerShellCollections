<#
.SYNOPSIS
    Kopiert eine Installationsdatei (z.B. FalconSensor) auf Zielcomputer
    und führt sie dort remote mit Parametern aus.
    Das Skript muss als Administrator ausgeführt werden.
#>

param (
    [string[]]$ZielComputerListe = @(
        "CLIENT-PC-01",
        "CLIENT-PC-02"  # Bitte durch Ihre echten Computernamen ersetzen
    ),
    [string]$RemoteTempPfad = "C:\Temp"
)

# --- Konfiguration der Installationsdatei ---
$DateiName = "FalconSensor_FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF-FF.exe"
$Argumente = "/install /quiet /norestart /CID=FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF-FF"
$Quelldatei = Join-Path $PSScriptRoot $DateiName
$RemoteTempPfadTeil = $RemoteTempPfad.TrimStart('C:')

# --- Vorab-Prüfung ---
if (!(Test-Path -Path $Quelldatei)) {
    Write-Error "Die Quelldatei '$Quelldatei' wurde nicht gefunden. Das Skript wird beendet."
    return
}

Write-Host "Starte parallelisierte Ausführung für $($ZielComputerListe.Count) Computer..."

# --- Parallele Verarbeitung ---
$ZielComputerListe | ForEach-Object -Parallel {

    # --- Zuweisung der $using:-Variablen (gemäß Ihrer Anforderung) ---
    # $Computer ist die aktuelle Eingabe (von ForEach-Object)
    $Computer = $_
    
    # $using: Variablen aus dem Haupt-Thread (P_ = Parallel)
    $P_RemoteTempPfad = $using:RemoteTempPfad
    $P_DateiName = $using:DateiName
    $P_RemoteTempPfadTeil = $using:RemoteTempPfadTeil
    $P_Quelldatei = $using:Quelldatei
    $P_Argumente = $using:Argumente
    # --- Ende Zuweisung ---

    # Wir verwenden nun die lokalen $P_ Variablen innerhalb des Parallel-Threads
    $RemoteDateiPfad = "$P_RemoteTempPfad\$P_DateiName"
    $ZielAdminPfad = "\\$Computer\C$\$P_RemoteTempPfadTeil\$P_DateiName"

    try {
        Write-Host "[$Computer] Starte Verarbeitung..."

        # 1. Sicherstellen, dass der Zielordner existiert
        # Wir definieren den ScriptBlock und nutzen -ArgumentList,
        # um $using: im Block zu vermeiden (beste Praxis)
        $ScriptBlockDir = {
            param(
                [string]$R_RemoteTempPfad, # R_ = Remote
                [string]$R_Computer
            )
            
            if (!(Test-Path -Path $R_RemoteTempPfad)) {
                Write-Host "[$R_Computer] Erstelle Ordner $R_RemoteTempPfad"
                New-Item -Path $R_RemoteTempPfad -ItemType Directory -Force | Out-Null
            }
        }
        # Wir übergeben die Variablen aus dem Parallel-Thread ($P_... und $Computer)
        Invoke-Command -ComputerName $Computer -ScriptBlock $ScriptBlockDir -ArgumentList $P_RemoteTempPfad, $Computer -ErrorAction Stop

        # 2. Datei kopieren
        Write-Host "[$Computer] Kopiere '$P_DateiName'..."
        Copy-Item -Path $P_Quelldatei -Destination $ZielAdminPfad -Force -ErrorAction Stop

        # 3. Befehl remote ausführen
        Write-Host "[$Computer] Führe Installation aus..."
        
        # Dieser Block war bereits korrekt (nutzt param() und ArgumentList)
        $ScriptBlockInstall = {
            param($Pfad, $ArgumenteListe)
            Start-Process -FilePath $Pfad -ArgumentList $ArgumenteListe -Wait
        }
        
        Invoke-Command -ComputerName $Computer -ScriptBlock $ScriptBlockInstall -ArgumentList $RemoteDateiPfad, $P_Argumente -ErrorAction Stop

        Write-Host "[$Computer] Verarbeitung ERFOLGREICH abgeschlossen."
    }
    catch {
        Write-Warning "[$Computer] FEHLER bei der Verarbeitung: $($_.Exception.Message)"
    }
    
} -ThrottleLimit 8

Write-Host "Skriptausführung für alle Computer beendet."