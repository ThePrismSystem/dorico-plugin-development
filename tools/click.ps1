<#
Press a named button in a window through UI Automation (no mouse needed).
  powershell -NoProfile -File tools/click.ps1 -Window "Edit Instrument Names" -Button "OK" [-OnlyButton]
Finds the window among Dorico's and PowerShell's (the form helper's box) visible top-level windows by its exact
title, case included, then among Dorico's owned windows (Qt dialogs). Buttons that UI Automation shows as Panes
(WinForms) are pressed with BM_CLICK on their window handle. Exits 3 when nothing is found.
-OnlyButton is for answering a prompt nobody has looked at: the window must be one of Dorico's own with exactly that
title, and the button must be its only one, so a prompt that offers a choice is never answered. Exits 3 otherwise.
#>
param(
    [Parameter(Mandatory = $true)][string]$Window,
    [Parameter(Mandatory = $true)][string]$Button,
    [switch]$OnlyButton
)
Add-Type -AssemblyName UIAutomationClient, UIAutomationTypes
Add-Type @"
using System;
using System.Runtime.InteropServices;
using System.Text;
public static class HbucClick {
    public delegate bool EnumProc(IntPtr hwnd, IntPtr lParam);
    [DllImport("user32.dll")] public static extern IntPtr SendMessage(IntPtr hwnd, uint msg, IntPtr w, IntPtr l);
    [DllImport("user32.dll")] public static extern bool EnumWindows(EnumProc cb, IntPtr lParam);
    [DllImport("user32.dll", CharSet = CharSet.Unicode)] public static extern int GetWindowText(IntPtr h, StringBuilder sb, int n);
    [DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr h);
    [DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr h, out uint pid);
    public static IntPtr WindowOf(uint pid, string title) {
        IntPtr found = IntPtr.Zero;
        EnumWindows((h, l) => {
            uint p;
            GetWindowThreadProcessId(h, out p);
            if (p != pid || !IsWindowVisible(h)) return true;
            var sb = new StringBuilder(512);
            GetWindowText(h, sb, 512);
            if (sb.ToString() != title) return true;
            found = h;
            return false;
        }, IntPtr.Zero);
        return found;
    }
}
"@
$A = [System.Windows.Automation.AutomationElement]
$scope = [System.Windows.Automation.TreeScope]
$root = $A::RootElement
$byName = New-Object System.Windows.Automation.PropertyCondition ($A::NameProperty), $Window
$isButton = New-Object System.Windows.Automation.PropertyCondition ($A::ControlTypeProperty), ([System.Windows.Automation.ControlType]::Button)
$proc = Get-Process -Name Dorico6 -ErrorAction SilentlyContinue | Select-Object -First 1
if ($OnlyButton) {
    # Dorico's own windows only: File Explorer showing a folder named Dorico is titled "Dorico" too.
    $hwnd = if ($proc) { [HbucClick]::WindowOf([uint32]$proc.Id, $Window) } else { [IntPtr]::Zero }
    if ($hwnd -eq [IntPtr]::Zero) { Write-Output "Dorico has no window named '$Window'"; exit 3 }
    $win = $A::FromHandle($hwnd)
    $buttonType = [System.Windows.Automation.ControlType]::Button
    $titleBar = [System.Windows.Automation.ControlType]::TitleBar
    $walker = [System.Windows.Automation.TreeWalker]::ControlViewWalker
    # Qt's buttons are Buttons to UI Automation, a native dialog's are Panes of the Win32 class Button. The title
    # bar's own buttons (Close) aren't the prompt's.
    $buttons = @($win.FindAll($scope::Descendants, [System.Windows.Automation.Condition]::TrueCondition) |
        Where-Object { ($_.Current.ControlType -eq $buttonType -or $_.Current.ClassName -eq "Button") -and
            $walker.GetParent($_).Current.ControlType -ne $titleBar })
    if ($buttons.Count -ne 1 -or $buttons[0].Current.Name -ne $Button) {
        $names = ($buttons | ForEach-Object { "'$($_.Current.Name)'" }) -join ", "
        Write-Output "'$Window' has the buttons $names, not only '$Button'; nothing pressed"
        exit 3
    }
    $btn = $buttons[0]
} else {
    # A top-level window is found by Win32, which reads window titles without asking their programs: UI Automation's
    # search of the desktop asks every window, and a Dorico waiting on the plug-in's dialog can take minutes to answer.
    # Only Dorico's and PowerShell's windows are looked at: FindWindow took any program's and ignored case, so "Find and
    # replace" could find a word processor's "Find and Replace".
    $hwnd = [IntPtr]::Zero
    foreach ($owner in @(Get-Process -Name Dorico6, powershell -ErrorAction SilentlyContinue)) {
        $hwnd = [HbucClick]::WindowOf([uint32]$owner.Id, $Window)
        if ($hwnd -ne [IntPtr]::Zero) { break }
    }
    $win = if ($hwnd -ne [IntPtr]::Zero) { $A::FromHandle($hwnd) } else { $null }
    if (-not $win) {
        # Qt parents its dialogs to the main window, so look one level further down too.
        if ($proc) {
            $byPid = New-Object System.Windows.Automation.PropertyCondition ($A::ProcessIdProperty), $proc.Id
            foreach ($top in $root.FindAll($scope::Children, $byPid)) {
                $win = $top.FindFirst($scope::Descendants, $byName)
                if ($win) { break }
            }
        }
    }
    if (-not $win) { Write-Output "no window named '$Window'"; exit 3 }
    $named = New-Object System.Windows.Automation.PropertyCondition ($A::NameProperty), $Button
    $btn = $win.FindFirst($scope::Descendants, (New-Object System.Windows.Automation.AndCondition $isButton, $named))
    if (-not $btn) { $btn = $win.FindFirst($scope::Descendants, $named) }
    if (-not $btn) { Write-Output "no button '$Button' in '$Window'"; exit 3 }
}
$invoke = $null
if ($btn.TryGetCurrentPattern([System.Windows.Automation.InvokePattern]::Pattern, [ref]$invoke)) {
    $invoke.Invoke()
} else {
    $hwnd = [IntPtr]$btn.Current.NativeWindowHandle
    if ($hwnd -eq [IntPtr]::Zero) { Write-Output "'$Button' in '$Window' has no window handle"; exit 3 }
    [void][HbucClick]::SendMessage($hwnd, 0x00F5, [IntPtr]::Zero, [IntPtr]::Zero)   # BM_CLICK
}
"pressed '$Button' in '$Window'"
