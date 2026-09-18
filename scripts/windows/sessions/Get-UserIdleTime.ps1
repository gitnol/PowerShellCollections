<#
.SYNOPSIS
    Ermittelt, wie lange der angemeldete Benutzer keine Eingabe mehr gemacht
    hat.

.DESCRIPTION
    Bindet die Win32-Funktion GetLastInputInfo ein und rechnet die Differenz
    zur Systemlaufzeit aus.

.NOTES
    GetLastInputInfo gilt nur fuer die eigene Sitzung: aus einer Sitzung
    heraus laesst sich die Leerlaufzeit anderer Sitzungen damit nicht
    ermitteln, und aus einem Dienstkontext heraus ergibt der Wert gar keinen
    Sinn.

    Fuer die Leerlaufzeit ueber alle Sitzungen eines Rechners nutzt
    Test-IdleSession.ps1 im selben Ordner einen indirekten Weg ueber die
    IO-Zaehler von csrss.exe.
#>

Add-Type @"
using System;
using System.Runtime.InteropServices;

public class IdleTime
{
    [StructLayout(LayoutKind.Sequential)]
    public struct LASTINPUTINFO
    {
        public uint cbSize;
        public uint dwTime;
    }

    [DllImport("user32.dll")]
    public static extern bool GetLastInputInfo(ref LASTINPUTINFO plii);

    public static uint GetIdleTime()
    {
        LASTINPUTINFO lastInputInfo = new LASTINPUTINFO();
        lastInputInfo.cbSize = (uint)Marshal.SizeOf(lastInputInfo);
        
        if (GetLastInputInfo(ref lastInputInfo))
        {
            uint idleTime = (uint)Environment.TickCount - lastInputInfo.dwTime;
            return idleTime; // Idle time in milliseconds
        }

        return 0;
    }
}
"@
Start-Sleep 1
$idleTime = [IdleTime]::GetIdleTime()
$idleSpan = [TimeSpan]::FromMilliseconds($idleTime)
$idleSpan.TotalSeconds
