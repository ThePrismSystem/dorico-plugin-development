<#
Lists the titles of the visible top-level windows that Dorico and PowerShell (the plug-in's dialog) have open, one
per line. For run_lua.py's timeout message, which names what Dorico is waiting on, and for its checks for a scratch
copy and the prompts it answers while opening one, which look at Dorico's windows only (-Process Dorico6).
  powershell -NoProfile -File tools/titles.ps1 [-Process <name>]
Win32 reads another program's window titles without asking it, so a Dorico waiting on a dialog can't hold this up,
as it holds up UI Automation and capture.ps1 -All. Exits 3 when no process of those names is running, so that isn't
mistaken for a Dorico with no window open.
#>
param([string[]]$Process = @("Dorico6", "powershell"))
if (-not (Get-Process -Name $Process -ErrorAction SilentlyContinue)) {
    [Console]::Error.WriteLine("no process named $($Process -join ' or ') is running")
    exit 3
}
Add-Type @"
using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Runtime.InteropServices;
using System.Text;
public static class HbucTitles {
    public delegate bool EnumProc(IntPtr hwnd, IntPtr lParam);
    [DllImport("user32.dll")] public static extern bool EnumWindows(EnumProc cb, IntPtr lParam);
    [DllImport("user32.dll", CharSet = CharSet.Unicode)] public static extern int GetWindowText(IntPtr h, StringBuilder sb, int n);
    [DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr h);
    [DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr h, out uint pid);
    public static List<string> Of(string[] processNames) {
        var names = new HashSet<string>(processNames, StringComparer.OrdinalIgnoreCase);
        var found = new List<string>();
        EnumWindows((h, l) => {
            if (!IsWindowVisible(h)) return true;
            var sb = new StringBuilder(512);
            if (GetWindowText(h, sb, 512) == 0) return true;
            uint pid;
            GetWindowThreadProcessId(h, out pid);
            try {
                if (names.Contains(Process.GetProcessById((int)pid).ProcessName)) found.Add(sb.ToString());
            } catch (ArgumentException) { }
            return true;
        }, IntPtr.Zero);
        return found;
    }
}
"@
[HbucTitles]::Of($Process)
