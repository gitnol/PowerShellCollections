<#
.SYNOPSIS
    Registriert die beiden mitgelieferten Aufgabenplanungs-Definitionen fuer
    taegliche Schattenkopien.

.DESCRIPTION
    Ruft zweimal schtasks auf und importiert die XML-Dateien aus demselben
    Verzeichnis: eine Aufgabe fuer die taegliche Schattenkopie von C:, eine
    fuer den taeglichen Wiederherstellungspunkt.

.NOTES
    Muss aus dem Verzeichnis heraus ausgefuehrt werden, in dem die
    XML-Dateien liegen - die Pfade sind relativ.

    Erfordert administrative Rechte. `/f` ueberschreibt bestehende Aufgaben
    gleichen Namens ohne Rueckfrage.

    Zur Kontrolle danach: `vssadmin list shadowstorage` und
    `vssadmin list shadows`.
#>

schtasks /create /tn "Snapshot_C_Täglich" /xml "Snapshot_C_Täglich.xml" /f
schtasks /create /tn "Wiederherstellungspunkt_C_Täglich" /xml "Wiederherstellungspunkt_C_Täglich.xml" /f

# vssadmin list shadowstorage
# vssadmin list shadows
