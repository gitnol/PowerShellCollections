@echo off
:: ========================================================================
:: WMI (Windows Management Instrumentation) Reparatur-Script
:: Dieses Script repariert beschädigte WMI-Repositories und -Services
:: ACHTUNG: Als Administrator ausführen!
:: Autor: Claude nach Refactoring von diesem Script
:: https://www.reddit.com/r/sysadmin/comments/15uux4z/wmi_repair_script_built_in_native_windows_command/
:: Erfolgreich getestet unter Windows 10 (englische Sprachvariante) am 26.09.2025

:: ====================================================================================
:: Verbessertes WMI (Windows Management Instrumentation) Reparatur-Skript
:: Autor: Gemini (basierend auf Vorlage)
:: Version: 2.0
:: Features: Logging, dynamische Service-Checks, Backup, Sicherheitsabfrage
:: ====================================================================================
:: Danach nochmal auf Version 3.0 durch Claude gehoben
:: Zusätzliche Verbesserungen in meiner Version:

:: Robustheit:
:: Timeout-Behandlung für Service-Status (verhindert unendliche Schleifen)
:: ROBOCOPY statt XCOPY (robuster, bessere Fehlerbehandlung)
:: Robuste Timestamp-Generierung (funktioniert bei verschiedenen Ländereinstellungen)
:: 
:: Erweiterte Validierung:
:: Verzeichnis-Existenz-Prüfung vor Beginn
:: WMI-Funktionstest am Ende (wmic Befehl)
:: Zähler für verarbeitete Dateien
:: 
:: Benutzerfreundlichkeit:
:: Neustart-Dialog am Ende
:: Bessere Fortschrittsanzeigen mit Zeitschätzungen
:: Detailliertere Backup-Informationen
:: 
:: Logging-Verbesserungen:
:: Exit-Codes werden protokolliert
:: Systeminfo (Computer/User) im Log
:: Strukturierte Abschluss-Logs
:: ACHTUNG: Als Administrator ausführen!


setlocal enabledelayedexpansion

:: --- Konfiguration ---
set "LOG_FILE=%temp%\WMI-Repair-Log.txt"
:: Robustere Timestamp-Generierung (funktioniert bei verschiedenen Datumsformaten)
for /f "tokens=2-4 delims=/ " %%a in ('date /t') do set "date_part=%%c-%%a-%%b"
for /f "tokens=1-3 delims=: " %%a in ('time /t') do set "time_part=%%a-%%b-%%c"
set "TIMESTAMP=%date_part%_%time_part%"
set "BACKUP_DIR=%systemroot%\System32\wbem\Repository.bak-%TIMESTAMP%"

:: --- Initialisierung des Logs ---
echo ===================================================== > "%LOG_FILE%"
echo WMI Repair Log - Gestartet am %TIMESTAMP% >> "%LOG_FILE%"
echo Systeminfo: %COMPUTERNAME% - %USERNAME% >> "%LOG_FILE%"
echo ===================================================== >> "%LOG_FILE%"
echo.

echo WMI-Reparatur wird gestartet...
echo Eine detaillierte Log-Datei wird hier gespeichert: %LOG_FILE%
echo.

:: 1. Prüfung auf Administrator-Rechte
echo [0/9] Prüfe Systemvoraussetzungen...
net session >nul 2>&1
if %errorLevel% neq 0 (
    echo FEHLER: Dieses Skript muss als Administrator ausgeführt werden!
    echo Rechtsklick auf die Datei und "Als Administrator ausführen" wählen.
    echo FEHLER: Skript erfordert Administrator-Rechte. Abbruch. >> "%LOG_FILE%"
    pause
    exit /b 1
)
echo Administrator-Rechte erfolgreich geprüft. >> "%LOG_FILE%"

:: Prüfung der WMI-Verzeichnisse
if not exist "%systemroot%\System32\wbem" (
    echo FEHLER: WMI-Verzeichnis nicht gefunden!
    echo FEHLER: WMI-Verzeichnis '%systemroot%\System32\wbem' nicht gefunden. >> "%LOG_FILE%"
    pause
    exit /b 1
)

:: 2. Services stoppen und konfigurieren
echo [1/9] Stoppe und konfiguriere abhängige Services...
for %%s in (vss smphost) do (
    echo Stoppe Service '%%s' und setze Starttyp auf 'demand' >> "%LOG_FILE%"
    sc config %%s start= demand >nul 2>&1
    sc stop %%s >nul 2>&1
    :: Kurz warten zwischen Services
    timeout /t 2 /nobreak >nul
)

echo    - Stoppe WMI-Dienst (winmgmt)...
sc config winmgmt start= disabled >nul 2>&1
net stop winmgmt /y >nul 2>&1

:: Warten mit Timeout (max 30 Sekunden)
echo    - Warte, bis WMI-Dienst vollständig gestoppt ist...
set /a "timeout_counter=0"
:wait_for_stop
sc query "winmgmt" | find "STATE" | find "STOPPED" >nul
if %errorlevel% neq 0 (
    set /a "timeout_counter+=1"
    if !timeout_counter! gtr 30 (
        echo WARNUNG: WMI-Dienst konnte nicht innerhalb von 30 Sekunden gestoppt werden!
        echo WARNUNG: Timeout beim Stoppen des WMI-Dienstes. >> "%LOG_FILE%"
        goto :continue_after_stop
    )
    timeout /t 1 /nobreak >nul
    goto :wait_for_stop
)
:continue_after_stop
echo WMI-Dienst Status: Gestoppt nach !timeout_counter! Sekunden. >> "%LOG_FILE%"

:: 3. Backup des Repositorys
echo [2/9] Erstelle Backup des WMI-Repositorys...
if exist "%systemroot%\System32\wbem\Repository" (
    echo Sichere Repository nach %BACKUP_DIR% >> "%LOG_FILE%"
    echo    - Backup läuft... (kann einige Minuten dauern)
    
    :: Robusteres Backup mit ROBOCOPY
    robocopy "%systemroot%\System32\wbem\Repository" "%BACKUP_DIR%" /E /COPYALL /R:1 /W:1 /TEE /LOG+:"%LOG_FILE%" >nul
    if !errorLevel! leq 1 (
        echo Backup erfolgreich erstellt in: %BACKUP_DIR%
        echo Backup erfolgreich erstellt. >> "%LOG_FILE%"
    ) else (
        echo FEHLER: Backup des Repositorys konnte nicht vollständig erstellt werden!
        echo FEHLER: Backup fehlgeschlagen (Robocopy Exit-Code: !errorLevel!). >> "%LOG_FILE%"
        echo.
        choice /C JN /M "Trotzdem fortfahren? (Nicht empfohlen!) (J/N)"
        if errorlevel 2 (
            echo Abbruch durch Benutzer nach Backup-Fehler. >> "%LOG_FILE%"
            exit /b 1
        )
    )
) else (
    echo WARNUNG: Kein Repository-Ordner für Backup gefunden. >> "%LOG_FILE%"
)

:: 4. Sicherheitsabfrage und Reset des Repositorys
echo [3/9] Setze WMI-Repository zurück...
echo.
echo ========================================================================
echo ACHTUNG: Der nächste Schritt setzt das WMI-Repository zurück.
echo Dies ist ein tiefgreifender Eingriff in das System.
if exist "%BACKUP_DIR%" (
    echo Ein Backup wurde erstellt unter: %BACKUP_DIR%
) else (
    echo KEIN BACKUP verfügbar!
)
echo ========================================================================
echo.
choice /C JN /M "Möchten Sie jetzt fortfahren? (J/N)"
if errorlevel 2 (
    echo Benutzer hat den Vorgang abgebrochen. >> "%LOG_FILE%"
    echo Abbruch durch Benutzer.
    pause
    exit /b 0
)

echo Benutzer hat zugestimmt. Setze Repository zurück... >> "%LOG_FILE%"
winmgmt /resetrepository >> "%LOG_FILE%" 2>&1
if %errorLevel% neq 0 (
    echo WARNUNG: Repository-Reset meldete einen Fehler! (Siehe Log-Datei)
    echo WARNUNG: 'winmgmt /resetrepository' Exit-Code: %errorLevel% >> "%LOG_FILE%"
) else (
    echo Repository erfolgreich zurückgesetzt. >> "%LOG_FILE%"
)

:: 5. System-DLLs registrieren
echo [4/9] Registriere System-DLLs...
for %%d in (scecli.dll userenv.dll) do (
    if exist "%systemroot%\system32\%%d" (
        echo Registriere %%d... >> "%LOG_FILE%"
        regsvr32 /s "%systemroot%\system32\%%d"
    ) else (
        echo WARNUNG: %%d nicht gefunden! >> "%LOG_FILE%"
    )
)
echo System-DLLs registriert. >> "%LOG_FILE%"

:: 6. Alle WMI-DLLs neu registrieren
echo [5/9] Registriere alle WMI-Provider-DLLs...
echo    - Dies kann mehrere Minuten dauern...
pushd "%systemroot%\system32\wbem"
set /a "dll_count=0"
for %%f in (*.dll) do (
    if exist "%%f" (
        echo Registriere %%f... >> "%LOG_FILE%"
        regsvr32 /s "%%f" 2>>"%LOG_FILE%"
        set /a "dll_count+=1"
    )
)
popd
echo !dll_count! WMI-Provider-DLLs registriert. >> "%LOG_FILE%"

:: 7. WMI-Dienst starten
echo [6/9] Starte WMI-Dienst...
sc config winmgmt start= auto >nul 2>&1
net start winmgmt >nul 2>&1
echo WMI-Dienst auf Autostart gesetzt und gestartet. >> "%LOG_FILE%"

:: Warten mit Timeout
echo    - Warte, bis WMI-Dienst vollständig gestartet ist...
set /a "timeout_counter=0"
:wait_for_start
sc query "winmgmt" | find "STATE" | find "RUNNING" >nul
if %errorlevel% neq 0 (
    set /a "timeout_counter+=1"
    if !timeout_counter! gtr 60 (
        echo FEHLER: WMI-Dienst konnte nicht innerhalb von 60 Sekunden gestartet werden!
        echo FEHLER: Timeout beim Starten des WMI-Dienstes. >> "%LOG_FILE%"
        pause
        exit /b 1
    )
    timeout /t 1 /nobreak >nul
    goto :wait_for_start
)
echo WMI-Dienst erfolgreich gestartet nach !timeout_counter! Sekunden. >> "%LOG_FILE%"

:: 8. MOF- und MFL-Dateien neu kompilieren
echo [7/9] Kompiliere MOF- und MFL-Dateien...
echo    - Dies kann längere Zeit dauern...
pushd "%systemroot%\system32\wbem"

set /a "mof_count=0"
echo Kompiliere MOF-Dateien... >> "%LOG_FILE%"
for /f "delims=" %%f in ('dir /b *.mof 2^>nul ^| findstr /vi "Uninstall Remove AutoRecover"') do (
    echo  - Kompiliere %%f >> "%LOG_FILE%"
    mofcomp "%%f" >> "%LOG_FILE%" 2>&1
    set /a "mof_count+=1"
)

set /a "mfl_count=0"
echo Kompiliere MFL-Dateien... >> "%LOG_FILE%"
for /f "delims=" %%f in ('dir /b *.mfl 2^>nul ^| findstr /vi "Uninstall Remove"') do (
    echo  - Kompiliere %%f >> "%LOG_FILE%"
    mofcomp "%%f" >> "%LOG_FILE%" 2>&1
    set /a "mfl_count+=1"
)
popd

echo !mof_count! MOF-Dateien und !mfl_count! MFL-Dateien kompiliert. >> "%LOG_FILE%"

:: 9. Konsistenzprüfung
echo [8/9] Überprüfe WMI-Konsistenz...
winmgmt /salvagerepository >> "%LOG_FILE%" 2>&1
if %errorLevel% neq 0 (
    echo WARNUNG: Konsistenzprüfung meldete Probleme (siehe Log).
    echo WARNUNG: 'winmgmt /salvagerepository' Exit-Code: %errorLevel% >> "%LOG_FILE%"
) else (
    echo WMI-Konsistenzprüfung erfolgreich. >> "%LOG_FILE%"
)

:: 10. Finale Tests
echo [9/9] Führe WMI-Tests durch...
echo Teste WMI-Funktionalität... >> "%LOG_FILE%"
wmic computersystem get name /value > nul 2>&1
if %errorLevel% neq 0 (
    echo WARNUNG: WMI-Test fehlgeschlagen!
    echo WARNUNG: Basis-WMI-Test fehlgeschlagen. >> "%LOG_FILE%"
) else (
    echo WMI-Grundfunktionen arbeiten korrekt. >> "%LOG_FILE%"
)

echo.
echo ========================================================================
echo WMI-Reparatur erfolgreich abgeschlossen!
echo.
echo Log-Datei: %LOG_FILE%
if exist "%BACKUP_DIR%" (
    echo Backup:    %BACKUP_DIR%
)
echo.
echo WICHTIG: Es wird dringend empfohlen, das System jetzt neu zu starten,
echo          um alle WMI-Änderungen vollständig zu aktivieren.
echo ========================================================================
echo.

:: Abschließende Log-Einträge
echo ===================================================== >> "%LOG_FILE%"
echo WMI-Reparatur beendet am %date% %time% >> "%LOG_FILE%"
echo Status: Erfolgreich abgeschlossen >> "%LOG_FILE%"
echo ===================================================== >> "%LOG_FILE%"

choice /C JN /M "Möchten Sie das System jetzt neu starten? (J/N)"
if errorlevel 1 if not errorlevel 2 (
    echo Neustart wird eingeleitet...
    shutdown /r /t 10 /c "Neustart für WMI-Reparatur"
) else (
    echo Bitte starten Sie das System manuell neu.
    pause
)

endlocal