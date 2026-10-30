<#
Put text in the first text box of a window, through Win32 (no keyboard focus needed).
  powershell -NoProfile -File tools/fill.ps1 -Window "Ask and report" -Text "Hello"
Finds the window by its exact title, in any program, and its first child window whose class is an edit control
(a Windows Forms TextBox's class is WindowsForms10.EDIT...). UI Automation shows that control as a bare pane, which
is why this doesn't use it. Exits 3 when the window, or a text box in it, isn't found.
#>
param(
    [Parameter(Mandatory = $true)][string]$Window,
    [Parameter(Mandatory = $true)][string]$Text
)
Add-Type @"
using System;
using System.Text;
using System.Runtime.InteropServices;
public static class ExamplesFill {
    public delegate bool EnumProc(IntPtr hwnd, IntPtr lParam);
    [DllImport("user32.dll", CharSet = CharSet.Unicode)] public static extern IntPtr FindWindow(string cls, string title);
    [DllImport("user32.dll")] public static extern bool EnumChildWindows(IntPtr parent, EnumProc cb, IntPtr lParam);
    [DllImport("user32.dll", CharSet = CharSet.Unicode)] public static extern int GetClassName(IntPtr hwnd, StringBuilder sb, int max);
    [DllImport("user32.dll", CharSet = CharSet.Unicode)] public static extern IntPtr SendMessage(IntPtr hwnd, uint msg, IntPtr w, string l);
    public static IntPtr FirstEdit(IntPtr parent) {
        IntPtr found = IntPtr.Zero;
        EnumChildWindows(parent, (h, l) => {
            var sb = new StringBuilder(256);
            GetClassName(h, sb, 256);
            string cls = sb.ToString().ToUpperInvariant();
            if (cls == "EDIT" || cls.Contains(".EDIT.")) { found = h; return false; }
            return true;
        }, IntPtr.Zero);
        return found;
    }
}
"@
$hwnd = [ExamplesFill]::FindWindow([NullString]::Value, $Window)
if ($hwnd -eq [IntPtr]::Zero) { Write-Output "no window named '$Window'"; exit 3 }
$box = [ExamplesFill]::FirstEdit($hwnd)
if ($box -eq [IntPtr]::Zero) { Write-Output "no text box in '$Window'"; exit 3 }
[void][ExamplesFill]::SendMessage($box, 0x000C, [IntPtr]::Zero, $Text)   # WM_SETTEXT
"filled the text box in '$Window'"
