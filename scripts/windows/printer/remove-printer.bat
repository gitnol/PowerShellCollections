@echo off
:: Batch-Datei zum Entfernen von Netzwerkdruckern, die einem bestimmten Muster entsprechen
:: und zum Erstellen einer Liste aller installierten Drucker, wenn diese Liste noch nicht existiert.

setlocal enabledelayedexpansion

:: Suchstring (Case-Insensitive)
set "stringToMatch=svrprt02"

:: Netzwerkdrucker durchgehen
for /f "tokens=2 delims==" %%A in (
    'wmic printer where "Network=true" get caption /value'
) do (
    set "printerName=%%A"
    if defined printerName (
        set "printerName=!printerName:~0,-1!"
        echo !printerName! | findstr /I /C:"%stringToMatch%" >nul && (
            rundll32 printui.dll,PrintUIEntry /dn /n "!printerName!"
        )
    )
)

:: Benutzer- und Rechnername
set "filepath=\\myfileserver\TempData\_installed_printer\%USERNAME%_%COMPUTERNAME%.txt"

:: Falls Datei existiert -> nichts tun
if exist "%filepath%" exit /b 0

:: Druckerliste schreiben
wmic printer get name > "%filepath%"

if exist "%filepath%" (
    echo Druckerliste erstellt: %filepath%
) else (
    echo Fehler: Datei konnte nicht erstellt werden
)

endlocal
exit /b 0
