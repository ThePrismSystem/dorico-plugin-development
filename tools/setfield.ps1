<#
Set one field of a Windows Forms box through Win32 (no keyboard focus needed): the n-th text box, tick box or list,
counting from 0 in the order the box added them.
  powershell -NoProfile -File tools/setfield.ps1 -Window "Find and replace" -Kind text -Index 1 -Value "hello"
  powershell -NoProfile -File tools/setfield.ps1 -Window "Parallel fifths and octaves" -Kind check -Index 0 -Value true
  powershell -NoProfile -File tools/setfield.ps1 -Window "Find and replace" -Kind choice -Index 0 -Value 1
The window is found among PowerShell's visible top-level windows (the form helper's box) by its exact title, case
included. A text box gets WM_SETTEXT. A tick box is clicked (BM_CLICK) when its state differs from Value, so Windows
Forms sees the change. A list gets CB_SETCURSEL with Value as the item's number from 0. Tick boxes are told from the
box's other buttons, OK and Cancel, by their button style, so an index past the last tick box finds nothing instead
of pressing OK. Each field is read back afterwards. Exits 3 when the window or the field isn't found, or the field
doesn't hold the value after.
#>
param(
    [Parameter(Mandatory = $true)][string]$Window,
    [Parameter(Mandatory = $true)][ValidateSet("text", "check", "choice")][string]$Kind,
    [Parameter(Mandatory = $true)][int]$Index,
    [Parameter(Mandatory = $true)][string]$Value
)
Add-Type @"
using System;
using System.Collections.Generic;
using System.Text;
using System.Runtime.InteropServices;
public static class ExamplesSetField {
    public delegate bool EnumProc(IntPtr hwnd, IntPtr lParam);
    [DllImport("user32.dll")] public static extern bool EnumWindows(EnumProc cb, IntPtr lParam);
    [DllImport("user32.dll", CharSet = CharSet.Unicode)] public static extern int GetWindowText(IntPtr h, StringBuilder sb, int n);
    [DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr h);
    [DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr h, out uint pid);
    [DllImport("user32.dll")] public static extern int GetWindowLong(IntPtr hwnd, int index);
    [DllImport("user32.dll")] public static extern bool EnumChildWindows(IntPtr parent, EnumProc cb, IntPtr lParam);
    [DllImport("user32.dll", CharSet = CharSet.Unicode)] public static extern int GetClassName(IntPtr hwnd, StringBuilder sb, int max);
    [DllImport("user32.dll", CharSet = CharSet.Unicode)] public static extern IntPtr SendMessage(IntPtr hwnd, int msg, IntPtr w, string l);
    [DllImport("user32.dll")] public static extern IntPtr SendMessage(IntPtr hwnd, int msg, IntPtr w, IntPtr l);
    [DllImport("user32.dll", CharSet = CharSet.Unicode)] public static extern IntPtr SendMessage(IntPtr hwnd, int msg, IntPtr w, StringBuilder l);
    public static string Text(IntPtr hwnd) {
        int length = (int)SendMessage(hwnd, 0x000E, IntPtr.Zero, IntPtr.Zero);   // WM_GETTEXTLENGTH
        var sb = new StringBuilder(length + 1);
        SendMessage(hwnd, 0x000D, (IntPtr)(length + 1), sb);   // WM_GETTEXT
        return sb.ToString();
    }
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
    // A tick box's button style (GWL_STYLE & BS_TYPEMASK): BS_CHECKBOX, BS_AUTOCHECKBOX, BS_3STATE (which Windows
    // Forms gives a CheckBox) or BS_AUTO3STATE. OK and Cancel are push buttons.
    static bool IsTickBox(IntPtr h) {
        int type = GetWindowLong(h, -16) & 0xF;
        return type == 2 || type == 3 || type == 5 || type == 6;
    }
    public static IntPtr Nth(IntPtr parent, string kind, int index) {
        var found = new List<IntPtr>();
        EnumChildWindows(parent, (h, l) => {
            var sb = new StringBuilder(256);
            GetClassName(h, sb, 256);
            string cls = sb.ToString().ToUpperInvariant();
            if ((cls == kind || cls.Contains("." + kind + ".")) && (kind != "BUTTON" || IsTickBox(h))) { found.Add(h); }
            return true;
        }, IntPtr.Zero);
        return index < found.Count ? found[index] : IntPtr.Zero;
    }
}
"@
# FindWindow would take any program's window and ignore case, so "Find and replace" could find a word processor's.
$hwnd = [IntPtr]::Zero
foreach ($owner in @(Get-Process -Name powershell -ErrorAction SilentlyContinue)) {
    $hwnd = [ExamplesSetField]::WindowOf([uint32]$owner.Id, $Window)
    if ($hwnd -ne [IntPtr]::Zero) { break }
}
if ($hwnd -eq [IntPtr]::Zero) { Write-Output "no window named '$Window'"; exit 3 }
$class = @{ text = "EDIT"; check = "BUTTON"; choice = "COMBOBOX" }[$Kind]
$field = [ExamplesSetField]::Nth($hwnd, $class, $Index)
if ($field -eq [IntPtr]::Zero) { Write-Output "no $Kind field $Index in '$Window'"; exit 3 }
function Get-Checked { [ExamplesSetField]::SendMessage($field, 0x00F0, [IntPtr]::Zero, [IntPtr]::Zero) -eq [IntPtr]1 }   # BM_GETCHECK
switch ($Kind) {
    "text" {
        [void][ExamplesSetField]::SendMessage($field, 0x000C, [IntPtr]::Zero, $Value)   # WM_SETTEXT
        $set = [ExamplesSetField]::Text($field) -ceq $Value
    }
    "check" {
        $want = $Value -eq "true"
        if ((Get-Checked) -ne $want) { [void][ExamplesSetField]::SendMessage($field, 0x00F5, [IntPtr]::Zero, [IntPtr]::Zero) }   # BM_CLICK
        $set = (Get-Checked) -eq $want
    }
    "choice" {
        [void][ExamplesSetField]::SendMessage($field, 0x014E, [IntPtr][int]$Value, [IntPtr]::Zero)   # CB_SETCURSEL
        $set = [int][ExamplesSetField]::SendMessage($field, 0x0147, [IntPtr]::Zero, [IntPtr]::Zero) -eq [int]$Value   # CB_GETCURSEL
    }
}
if (-not $set) { Write-Output "couldn't set $Kind field $Index in '$Window' to '$Value'"; exit 3 }
"set $Kind field $Index in '$Window'"
