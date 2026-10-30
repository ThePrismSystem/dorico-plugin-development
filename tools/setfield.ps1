<#
Set one field of a Windows Forms box through Win32 (no keyboard focus needed): the n-th text box, tick box or list,
counting from 0 in the order the box added them.
  powershell -NoProfile -File tools/setfield.ps1 -Window "Parallel fifths" -Kind text -Index 1 -Value "hello"
  powershell -NoProfile -File tools/setfield.ps1 -Window "Parallel fifths" -Kind check -Index 0 -Value true
  powershell -NoProfile -File tools/setfield.ps1 -Window "Parallel fifths" -Kind choice -Index 0 -Value 2
A text box gets WM_SETTEXT. A tick box is clicked (BM_CLICK) when its state differs from Value, so Windows Forms
sees the change. A list gets CB_SETCURSEL with Value as the item's number from 0. Tick boxes are counted among the
box's buttons, which works because the form helper adds every field before OK and Cancel. Exits 3 when the window
or the field isn't found.
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
    [DllImport("user32.dll", CharSet = CharSet.Unicode)] public static extern IntPtr FindWindow(string cls, string title);
    [DllImport("user32.dll")] public static extern bool EnumChildWindows(IntPtr parent, EnumProc cb, IntPtr lParam);
    [DllImport("user32.dll", CharSet = CharSet.Unicode)] public static extern int GetClassName(IntPtr hwnd, StringBuilder sb, int max);
    [DllImport("user32.dll", CharSet = CharSet.Unicode)] public static extern IntPtr SendMessage(IntPtr hwnd, int msg, IntPtr w, string l);
    [DllImport("user32.dll")] public static extern IntPtr SendMessage(IntPtr hwnd, int msg, IntPtr w, IntPtr l);
    public static IntPtr Nth(IntPtr parent, string kind, int index) {
        var found = new List<IntPtr>();
        EnumChildWindows(parent, (h, l) => {
            var sb = new StringBuilder(256);
            GetClassName(h, sb, 256);
            string cls = sb.ToString().ToUpperInvariant();
            if (cls == kind || cls.Contains("." + kind + ".")) { found.Add(h); }
            return true;
        }, IntPtr.Zero);
        return index < found.Count ? found[index] : IntPtr.Zero;
    }
}
"@
$hwnd = [ExamplesSetField]::FindWindow([NullString]::Value, $Window)
if ($hwnd -eq [IntPtr]::Zero) { Write-Output "no window named '$Window'"; exit 3 }
$class = @{ text = "EDIT"; check = "BUTTON"; choice = "COMBOBOX" }[$Kind]
$field = [ExamplesSetField]::Nth($hwnd, $class, $Index)
if ($field -eq [IntPtr]::Zero) { Write-Output "no $Kind field $Index in '$Window'"; exit 3 }
switch ($Kind) {
    "text" { [void][ExamplesSetField]::SendMessage($field, 0x000C, [IntPtr]::Zero, $Value) }   # WM_SETTEXT
    "check" {
        $want = $Value -eq "true"
        $now = [ExamplesSetField]::SendMessage($field, 0x00F0, [IntPtr]::Zero, [IntPtr]::Zero) -eq [IntPtr]1   # BM_GETCHECK
        if ($now -ne $want) { [void][ExamplesSetField]::SendMessage($field, 0x00F5, [IntPtr]::Zero, [IntPtr]::Zero) }   # BM_CLICK
    }
    "choice" { [void][ExamplesSetField]::SendMessage($field, 0x014E, [IntPtr][int]$Value, [IntPtr]::Zero) }   # CB_SETCURSEL
}
"set $Kind field $Index in '$Window'"
