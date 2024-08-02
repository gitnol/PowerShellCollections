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

$idleTime = [IdleTime]::GetIdleTime()
$idleSpan = [TimeSpan]::FromMilliseconds($idleTime)
$idleSpan.TotalSeconds
