@{
    Severity = @('Error', 'Warning', 'Information')
    ExcludeRules = @(
        # InjectionHunter's Add-Type rule reports every Add-Type -AssemblyName, which loads a .NET assembly by name.
        # The scripts' other Add-Type calls compile constant C# here-strings with nothing interpolated into them.
        'Measure-AddType'
    )
    Rules    = @{
        # The tools are run with Windows PowerShell 5.1 (powershell.exe), which comes with Windows, so every script
        # must work there as well as in PowerShell 7.
        PSUseCompatibleSyntax   = @{
            Enable         = $true
            TargetVersions = @('5.1', '7.0')
        }
        # PSUseCompatibleTypes is left off: it reports the WinForms and UI Automation types, which the scripts load
        # themselves with Add-Type -AssemblyName.
        PSUseCompatibleCommands = @{
            Enable         = $true
            TargetProfiles = @('win-8_x64_10.0.17763.0_5.1.17763.316_x64_4.0.30319.42000_framework')
        }
    }
}
