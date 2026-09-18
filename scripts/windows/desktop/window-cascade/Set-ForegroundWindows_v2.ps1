<#
.SYNOPSIS
    Skript zur Wiederherstellung der "Fenster überlappend anzeigen"-Funktion unter Windows 11.

.DESCRIPTION
    Bietet globales und prozessspezifisches Kaskadieren von Fenstern.
    Option 1 gruppiert die Fenster automatisch nach Prozess (jeder Prozess bekommt
    seinen eigenen Kaskaden-Cluster) und erlaubt bei mehreren Bildschirmen die Wahl
    des Zielmonitors.
    Die Monitor-Erkennung und Fenstergröße (85% der Auflösung des gewählten
    Bildschirms) laufen komplett über die Win32-API (EnumDisplayMonitors /
    GetMonitorInfo), um Abhängigkeiten von Windows.Forms zu vermeiden.
    Unterstützt Multi-Window-Apps wie Outlook.
#>

# --- 1. Win32 API Definition ---
if (-not ([System.Management.Automation.PSTypeName]"Win32Functions.Win11Fix").Type) {
    $methods = @'
    [StructLayout(LayoutKind.Sequential)]
    public struct RECT
    {
        public int Left;
        public int Top;
        public int Right;
        public int Bottom;
    }

    [StructLayout(LayoutKind.Sequential)]
    public struct MONITORINFO
    {
        public uint cbSize;
        public RECT rcMonitor;
        public RECT rcWork;
        public uint dwFlags;
    }

    public delegate bool MonitorEnumProc(IntPtr hMonitor, IntPtr hdcMonitor, IntPtr lprcMonitor, IntPtr dwData);

    [DllImport("user32.dll")]
    public static extern bool EnumDisplayMonitors(IntPtr hdc, IntPtr lprcClip, MonitorEnumProc lpfnEnum, IntPtr dwData);

    [DllImport("user32.dll", CharSet = CharSet.Auto)]
    public static extern bool GetMonitorInfo(IntPtr hMonitor, ref MONITORINFO lpmi);

    [DllImport("user32.dll")]
    public static extern bool SetWindowPos(IntPtr hWnd, IntPtr hWndInsertAfter, int X, int Y, int cx, int cy, uint uFlags);

    [DllImport("user32.dll")]
    public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);

    [DllImport("user32.dll")]
    public static extern ushort CascadeWindows(IntPtr hwndParent, uint wHow, IntPtr lpRect, uint cKids, IntPtr[] lpKids);

    [DllImport("user32.dll")]
    public static extern bool SetForegroundWindow(IntPtr hWnd);

    [DllImport("user32.dll")]
    public static extern bool IsIconic(IntPtr hWnd);

    [DllImport("user32.dll")]
    public static extern bool IsWindowVisible(IntPtr hWnd);

    [DllImport("user32.dll")]
    public static extern uint GetWindowThreadProcessId(IntPtr hWnd, out uint lpdwProcessId);

    public delegate bool EnumWindowsProc(IntPtr hWnd, IntPtr lParam);

    [DllImport("user32.dll")]
    public static extern bool EnumWindows(EnumWindowsProc lpEnumFunc, IntPtr lParam);

    [DllImport("user32.dll", CharSet = CharSet.Auto, SetLastError = true)]
    public static extern int GetWindowText(IntPtr hWnd, System.Text.StringBuilder lpString, int nMaxCount);
'@
    Add-Type -MemberDefinition $methods -Name "Win11Fix" -Namespace "Win32Functions"
}

$Win32 = [Win32Functions.Win11Fix]
$SW_RESTORE = 9
$SWP_SHOWWINDOW = 0x0040
$MONITORINFOF_PRIMARY = 0x00000001

# Prozesse, die von der globalen Kaskade (Option 1) NIEMALS angefasst werden sollen,
# z.B. weil sie auf Fenstergröße/-position empfindlich reagieren (Remote-Tools etc.).
# Bei Bedarf einfach ergänzen (Name ohne .exe, wie in Get-Process ausgegeben).
$ExcludedProcessNames = @(
    "TeamViewer",
    "TeamViewer_Service"
)

# Minimale Fenstergröße als Sicherheitsnetz - verhindert 0x0/zu kleine Fenster
# falls eine Monitor-Auflösung aus irgendeinem Grund nicht korrekt ermittelt werden konnte.
$MinWindowWidth = 400
$MinWindowHeight = 300

# --- 2. Monitor-Erkennung (reine Win32-API, kein Windows.Forms) ---

function Get-MonitorList {
    $monitorList = New-Object System.Collections.Generic.List[PSObject]

    $callback = {
        param($hMonitor, $hdcMonitor, $lprcMonitor, $dwData)

        $mi = New-Object -TypeName "Win32Functions.Win11Fix+MONITORINFO"
        # WICHTIG: SizeOf braucht eine tatsächliche Struct-Instanz, nicht den Type selbst -
        # sonst greift die falsche Overload und cbSize/GetMonitorInfo liefern Fehler bzw. 0-Werte.
        $mi.cbSize = [System.Runtime.InteropServices.Marshal]::SizeOf($mi)

        $success = $Win32::GetMonitorInfo($hMonitor, [ref]$mi)

        if ($success -and ($mi.rcMonitor.Right - $mi.rcMonitor.Left) -gt 0 -and ($mi.rcMonitor.Bottom - $mi.rcMonitor.Top) -gt 0) {
            $monitorList.Add([PSCustomObject]@{
                Handle    = $hMonitor
                Left      = $mi.rcMonitor.Left
                Top       = $mi.rcMonitor.Top
                Width     = $mi.rcMonitor.Right - $mi.rcMonitor.Left
                Height    = $mi.rcMonitor.Bottom - $mi.rcMonitor.Top
                IsPrimary = [bool]($mi.dwFlags -band $MONITORINFOF_PRIMARY)
            }) | Out-Null
        }

        # Immer $true zurückgeben, damit die Enumeration weiterer Monitore nicht abbricht
        return $true
    }

    $enumProc = [Win32Functions.Win11Fix+MonitorEnumProc]$callback
    [void]$Win32::EnumDisplayMonitors([IntPtr]::Zero, [IntPtr]::Zero, $enumProc, [IntPtr]::Zero)

    # Fallback, falls die Enumeration ausnahmsweise nichts liefert
    if ($monitorList.Count -eq 0) {
        $videoConfig = Get-CimInstance Win32_VideoController |
            Select-Object CurrentHorizontalResolution, CurrentVerticalResolution |
            Select-Object -First 1

        $fallbackWidth = $videoConfig.CurrentHorizontalResolution
        $fallbackHeight = $videoConfig.CurrentVerticalResolution
        if (-not $fallbackWidth) { $fallbackWidth = 1920; $fallbackHeight = 1080 }

        $monitorList.Add([PSCustomObject]@{
            Handle    = [IntPtr]::Zero
            Left      = 0
            Top       = 0
            Width     = $fallbackWidth
            Height    = $fallbackHeight
            IsPrimary = $true
        }) | Out-Null
    }

    for ($i = 0; $i -lt $monitorList.Count; $i++) {
        $monitorList[$i] | Add-Member -NotePropertyName Index -NotePropertyValue ($i + 1)
    }

    return $monitorList
}

function Select-TargetMonitor {
    $monitors = Get-MonitorList

    if ($monitors.Count -le 1) {
        return $monitors[0]
    }

    $selected = $monitors |
        Select-Object Index, Width, Height, Left, Top, IsPrimary |
        Out-GridView -Title "Zielbildschirm für die Fensteranordnung wählen" -OutputMode Single

    if (-not $selected) {
        return ($monitors | Where-Object { $_.IsPrimary } | Select-Object -First 1)
    }

    return ($monitors | Where-Object { $_.Index -eq $selected.Index })
}

# --- 3. Hilfsfunktionen ---

function Get-AllWindowHandles {
    param([uint32]$TargetProcessId)
    $handles = New-Object System.Collections.Generic.List[IntPtr]

    $enumProc = [Win32Functions.Win11Fix+EnumWindowsProc] {
        param($hWnd, $lParam)
        $currentP_Id = 0
        [void]$Win32::GetWindowThreadProcessId($hWnd, [ref]$currentP_Id)

        if ($currentP_Id -eq $TargetProcessId -and $Win32::IsWindowVisible($hWnd)) {
            $sb = New-Object System.Text.StringBuilder 256
            [void]$Win32::GetWindowText($hWnd, $sb, $sb.Capacity)
            if ($sb.ToString().Length -gt 0) {
                $handles.Add($hWnd)
            }
        }
        return $true
    }

    [void]$Win32::EnumWindows($enumProc, [IntPtr]::Zero)
    return $handles
}

function Restore-And-Focus {
    param([Parameter(Mandatory = $true)]$hWnd)
    if ($Win32::IsIconic($hWnd)) {
        [void]$Win32::ShowWindow($hWnd, $SW_RESTORE)
    }
    [void]$Win32::SetForegroundWindow($hWnd)
}

function Set-CascadeForHandles {
    param(
        [Parameter(Mandatory = $true)][System.Collections.Generic.List[IntPtr]]$Handles,
        [Parameter(Mandatory = $true)][int]$StartX,
        [Parameter(Mandatory = $true)][int]$StartY,
        [Parameter(Mandatory = $true)][int]$MonLeft,
        [Parameter(Mandatory = $true)][int]$MonTop,
        [Parameter(Mandatory = $true)][int]$MonWidth,
        [Parameter(Mandatory = $true)][int]$MonHeight,
        [Parameter(Mandatory = $true)][int]$WinWidth,
        [Parameter(Mandatory = $true)][int]$WinHeight,
        [int]$Offset = 35
    )

    $x = $StartX
    $y = $StartY

    foreach ($h in $Handles) {
        Restore-And-Focus -hWnd $h
        [void]$Win32::SetWindowPos($h, [IntPtr]::Zero, $x, $y, $WinWidth, $WinHeight, $SWP_SHOWWINDOW)

        $x += $Offset
        $y += $Offset

        if ($x -gt ($MonLeft + $MonWidth - 300)) { $x = $StartX }
        if ($y -gt ($MonTop + $MonHeight - 300)) { $y = $StartY }
    }
}

# --- 4. Hauptfunktionen ---

function Invoke-GlobalCascade {
    $targetMonitor = Select-TargetMonitor

    $monLeft   = $targetMonitor.Left
    $monTop    = $targetMonitor.Top
    $monWidth  = $targetMonitor.Width
    $monHeight = $targetMonitor.Height

    $winWidth  = [Math]::Max([int]($monWidth * 0.85), $MinWindowWidth)
    $winHeight = [Math]::Max([int]($monHeight * 0.85), $MinWindowHeight)

    $processes = Get-Process |
        Where-Object { $_.MainWindowHandle -ne 0 -and $_.Id -ne $PID -and $ExcludedProcessNames -notcontains $_.ProcessName }

    $processStepX = 60
    $processStepY = 40
    $maxOffsetX = [Math]::Max($monWidth - $winWidth - 40, 40)
    $maxOffsetY = [Math]::Max($monHeight - $winHeight - 40, 40)

    $processIndex = 0
    foreach ($p in $processes) {
        $handles = Get-AllWindowHandles -TargetProcessId $p.Id
        if ($handles.Count -eq 0) { continue }

        $startX = $monLeft + 40 + (($processIndex * $processStepX) % $maxOffsetX)
        $startY = $monTop + 40 + (($processIndex * $processStepY) % $maxOffsetY)

        Set-CascadeForHandles -Handles $handles -StartX $startX -StartY $startY `
            -MonLeft $monLeft -MonTop $monTop -MonWidth $monWidth -MonHeight $monHeight `
            -WinWidth $winWidth -WinHeight $winHeight

        $processIndex++
    }
}

function Invoke-ProcessSpecificCascade {
    $selected = Get-Process |
        Where-Object { $_.MainWindowTitle -ne "" } |
        Select-Object ProcessName, Id, MainWindowTitle |
        Out-GridView -Title "Prozess für Überlappung wählen" -OutputMode Single

    if ($selected) {
        $targetMonitor = Select-TargetMonitor

        $monLeft   = $targetMonitor.Left
        $monTop    = $targetMonitor.Top
        $monWidth  = $targetMonitor.Width
        $monHeight = $targetMonitor.Height

        $winWidth  = [Math]::Max([int]($monWidth * 0.85), $MinWindowWidth)
        $winHeight = [Math]::Max([int]($monHeight * 0.85), $MinWindowHeight)

        $targetP_Ids = Get-Process -Name $selected.ProcessName | Select-Object -ExpandProperty Id

        foreach ($p_id_entry in $targetP_Ids) {
            $allHandles = Get-AllWindowHandles -TargetProcessId $p_id_entry
            Set-CascadeForHandles -Handles $allHandles -StartX ($monLeft + 50) -StartY ($monTop + 50) `
                -MonLeft $monLeft -MonTop $monTop -MonWidth $monWidth -MonHeight $monHeight `
                -WinWidth $winWidth -WinHeight $winHeight
        }
    }
}

# --- 5. Menüführung ---
Clear-Host
Write-Host "--- Windows 11 Fenster-Manager (Final) ---" -ForegroundColor Cyan
Write-Host "1: Alle Fenster nach Prozess gruppiert überlappen (Global)"
Write-Host "2: Bestimmten Prozess wählen (z.B. Outlook)"
Write-Host "Q: Beenden"

$userInput = Read-Host "Eingabe"

switch ($userInput) {
    "1" { Invoke-GlobalCascade }
    "2" { Invoke-ProcessSpecificCascade }
    "Q" { exit }
    default { Write-Host "Ungültige Auswahl." -ForegroundColor Red }
}
