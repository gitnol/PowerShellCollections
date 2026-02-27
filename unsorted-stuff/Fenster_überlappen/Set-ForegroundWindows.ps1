<#
.SYNOPSIS
    Skript zur Wiederherstellung der "Fenster überlappend anzeigen"-Funktion unter Windows 11.

.DESCRIPTION
    Bietet globales und prozessspezifisches Kaskadieren von Fenstern.
    Berechnet die Fenstergröße dynamisch (85% der Auflösung) via WMI, um Abhängigkeiten 
    von Windows.Forms zu vermeiden. Unterstützt Multi-Window-Apps wie Outlook.
#>

# --- 1. Win32 API Definition ---
if (-not ([System.Management.Automation.PSTypeName]"Win32Functions.Win11Fix").Type) {
    $methods = @'
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

# --- 2. Dynamische Größenberechnung (WMI) ---
$videoConfig = Get-CimInstance Win32_VideoController | Select-Object CurrentHorizontalResolution, CurrentVerticalResolution | Select-Object -First 1
$screenWidth = $videoConfig.CurrentHorizontalResolution
$screenHeight = $videoConfig.CurrentVerticalResolution

# Fallback für unbekannte Auflösungen
if (-not $screenWidth) { $screenWidth = 1920; $screenHeight = 1080 }

$dynamicWidth = [int]($screenWidth * 0.85)
$dynamicHeight = [int]($screenHeight * 0.85)

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

# --- 4. Hauptfunktionen ---

function Invoke-GlobalCascade {
    $processes = Get-Process | Where-Object { $_.MainWindowHandle -ne 0 }
    foreach ($p in $processes) {
        $handles = Get-AllWindowHandles -TargetProcessId $p.Id
        foreach ($h in $handles) { Restore-And-Focus -hWnd $h }
    }
    Start-Sleep -Milliseconds 300
    [void]$Win32::CascadeWindows([IntPtr]::Zero, 4, [IntPtr]::Zero, 0, $null)
}

function Invoke-ProcessSpecificCascade {
    $selected = Get-Process | 
    Where-Object { $_.MainWindowTitle -ne "" } | 
    Select-Object ProcessName, Id, MainWindowTitle | 
    Out-GridView -Title "Prozess für Überlappung wählen" -OutputMode Single

    if ($selected) {
        $targetP_Ids = Get-Process -Name $selected.ProcessName | Select-Object -ExpandProperty Id
        
        $x, $y = 50, 50
        $offset = 35
        
        foreach ($p_id_entry in $targetP_Ids) {
            $allHandles = Get-AllWindowHandles -TargetProcessId $p_id_entry
            foreach ($handle in $allHandles) {
                Restore-And-Focus -hWnd $handle
                # Positionierung mit dynamischen Werten
                [void]$Win32::SetWindowPos($handle, [IntPtr]::Zero, $x, $y, $dynamicWidth, $dynamicHeight, $SWP_SHOWWINDOW)
                $x += $offset
                $y += $offset

                # Schutz vor Bildschirm-Überlauf
                if ($x -gt ($screenWidth - 300)) { $x = 50 }
                if ($y -gt ($screenHeight - 300)) { $y = 50 }
            }
        }
    }
}

# --- 5. Menüführung ---
Clear-Host
Write-Host "--- Windows 11 Fenster-Manager (Final) ---" -ForegroundColor Cyan
Write-Host "1: Alle Fenster überlappen (Global)"
Write-Host "2: Bestimmten Prozess wählen (z.B. Outlook)"
Write-Host "Q: Beenden"

$userInput = Read-Host "Eingabe"

switch ($userInput) {
    "1" { Invoke-GlobalCascade }
    "2" { Invoke-ProcessSpecificCascade }
    "Q" { exit }
    default { Write-Host "Ungültige Auswahl." -ForegroundColor Red }
}