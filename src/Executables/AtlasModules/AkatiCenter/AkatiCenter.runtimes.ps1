<#
.SYNOPSIS
    Akati OS Center: Gaming apps > Game runtimes: the Microsoft runtimes many games need (Visual C++, DirectX, .NET).
    Dot-sourced by AkatiCenter.ps1 (runs in its scope: $ui, $window, T and the other parts).
#>
# ---------------------------------------------------------------------------------------------
# Game runtimes. Each part is read from Apps & features (the uninstall keys of Windows), except two that have no entry
# there: DirectX End-User Runtime (June 2010), found by its d3dx9_43.dll, and .NET Framework 3.5, a Windows feature
# (the NDP\v3.5 key Windows sets when it is on). Parts with an Id install through GAMEAPPS.ps1 (WinGet, like the apps
# above: one after another, never next to an app install); .NET Framework 3.5 is turned on with DISM, which downloads
# it from Windows Update.
# ---------------------------------------------------------------------------------------------
Add-Mark 'Game runtimes'
$rtParts = @(
    @{ Key = 'VC2015x64'; Vc = '2015'; Arch = 'x64' }
    @{ Key = 'VC2015x86'; Vc = '2015'; Arch = 'x86' }
    @{ Key = 'DirectX'; File = 'd3dx9_43.dll' }
    @{ Key = 'DotNet8'; DotNet = 8 }
    @{ Key = 'DotNet10'; DotNet = 10 }
    @{ Key = 'NetFx3'; Feature = 'NetFx3' }
)
foreach ($y in '2013', '2012', '2010', '2008', '2005') { foreach ($a in 'x64', 'x86') { $rtParts += @{ Key = "VC$y$a"; Vc = $y; Arch = $a } } }
# The rows: a name, its parts, ticked at first or not (Old: the Visual C++ runtimes of 2005 to 2013, for older games)
$runtimes = @(
    @{ Id = 'vc64'; Name = 'Visual C++ 2015-2022 (x64)'; Parts = @('VC2015x64'); Desc = 'rt.d.vc' }
    @{ Id = 'vc86'; Name = 'Visual C++ 2015-2022 (x86)'; Parts = @('VC2015x86'); Desc = 'rt.d.vc' }
    @{ Id = 'directx'; Name = 'DirectX End-User Runtime (June 2010)'; Parts = @('DirectX'); Desc = 'rt.d.directx' }
    @{ Id = 'dotnet8'; Name = '.NET Desktop Runtime 8'; Parts = @('DotNet8'); Desc = 'rt.d.dotnet8' }
    @{ Id = 'dotnet10'; Name = '.NET Desktop Runtime 10'; Parts = @('DotNet10'); Desc = 'rt.d.dotnet10' }
    @{ Id = 'netfx3'; Name = '.NET Framework 3.5'; Parts = @('NetFx3'); Desc = 'rt.d.netfx3' }
    @{ Id = 'old'; NameKey = 'rt.n.old'; Parts = @($rtParts | Where-Object { $_.Vc -and $_.Vc -ne '2015' } | ForEach-Object { $_.Key }); Desc = 'rt.d.old'; Old = $true }
)
# Background work: part key -> $true when installed
$rtCheckWork = {
    param($logic, $parts)
    . $logic
    $names = @(foreach ($root in 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall', 'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall') {
        foreach ($k in @(Get-ChildItem -Path $root -ErrorAction SilentlyContinue)) {
            $n = [string](Get-ItemProperty -LiteralPath $k.PSPath -Name DisplayName -ErrorAction SilentlyContinue).DisplayName
            if ($n) { $n }
        }
    })
    $r = @{}
    foreach ($p in @($parts)) {
        $r[$p.Key] = if ($p.Vc) { [bool]@($names | Where-Object { Test-VcRuntimeName $_ $p.Vc $p.Arch }).Count }
            elseif ($p.DotNet) { [bool]@($names | Where-Object { Test-DotNetRuntimeName $_ $p.DotNet }).Count }
            elseif ($p.File) { (Test-Path (Join-Path $env:windir "SysWOW64\$($p.File)")) -or (Test-Path (Join-Path $env:windir "System32\$($p.File)")) }
            else { (Get-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\NET Framework Setup\NDP\v3.5' -Name Install -ErrorAction SilentlyContinue).Install -eq 1 }
    }
    $r
}
# Screenshot mode: a sample PC (some installed, some missing)
$rtSample = @{ VC2015x64 = $true; VC2015x86 = $false; DirectX = $false; DotNet8 = $true; DotNet10 = $false; NetFx3 = $false
               VC2013x64 = $true; VC2013x86 = $true; VC2012x64 = $true; VC2012x86 = $true; VC2010x64 = $true; VC2010x86 = $true
               VC2008x64 = $false; VC2008x86 = $false; VC2005x64 = $false; VC2005x86 = $false }
$script:rtState = $null
function Get-RuntimeMissing($rt) { @($rt.Parts | Where-Object { $script:rtState -is [hashtable] -and !$script:rtState[$_] }) }
function Show-Runtimes {
    if (!$script:rtBuilt) { return }
    foreach ($rt in $runtimes) {
        $row = $rt.Row
        $row.Title.Text = if ($rt.NameKey) { T $rt.NameKey } else { $rt.Name }
        $known = $script:rtState -is [hashtable]
        $missing = @(Get-RuntimeMissing $rt)
        $done = $known -and !$missing.Count
        $state = if (!$known) { T 'rt.checking' } elseif ($done) { T 'rt.installed' } elseif ($rt.Parts.Count -gt 1) { (T 'rt.partial') -f ($rt.Parts.Count - $missing.Count), $rt.Parts.Count } else { T 'rt.missing' }
        $row.Sub.Text = (T $rt.Desc) + '  ·  ' + $state
        $badge = $rt.Badge
        $badge.Child.Text = if ($done) { T 'rt.installed' } elseif ($known) { T 'rt.missing' } else { '-' }
        $back, $fore = if ($done) { 'Fill', 'Good' } elseif ($known) { 'WarnSoft', 'Warn' } else { 'Fill', 'MutedBrush' }
        $badge.SetResourceReference([System.Windows.Controls.Border]::BackgroundProperty, $back)
        $badge.Child.SetResourceReference([System.Windows.Controls.TextBlock]::ForegroundProperty, $fore)
        $rt.Check.IsEnabled = $known -and !$done -and !$script:rtBusy
        if ($done) { $rt.Check.IsChecked = $false }
    }
    Update-Separators $ui.RuntimeList
    $ui.RuntimeInstall.IsEnabled = !$script:rtBusy -and $script:rtState -is [hashtable] -and [bool]@($runtimes | Where-Object { @(Get-RuntimeMissing $_).Count }).Count
}
function Start-RuntimeCheck {
    if ($Screenshot) { $script:rtState = $rtSample; Show-Runtimes; return }
    Start-Work $rtCheckWork @($logicFile, $rtParts) { param($r) $res = Get-LastOutput $r; if ($res -is [hashtable]) { $script:rtState = $res }; Show-Runtimes } $null
}
function Initialize-Runtimes {
    if ($script:rtBuilt) { return }
    $script:rtBuilt = $true
    foreach ($rt in $runtimes) {
        $badge = New-Object System.Windows.Controls.Border
        $badge.CornerRadius = 6; $badge.Padding = '8,2'; $badge.VerticalAlignment = 'Center'
        $bt = New-Text '-' 11.5 'SemiBold'; $badge.Child = $bt
        $check = New-Object System.Windows.Controls.CheckBox
        $check.Style = $window.FindResource('Tick'); $check.IsChecked = !$rt.Old; $check.IsEnabled = $false
        $check.Add_Click({ Show-Runtimes })
        $row = New-Row ([string][char]$(if ($rt.Id -like 'dotnet*' -or $rt.Id -eq 'netfx3') { 0xE950 } elseif ($rt.Id -eq 'directx') { 0xE7FC } else { 0xE943 })) '' $null $badge $null $check
        $rt.Row = $row; $rt.Badge = $badge; $rt.Check = $check
        [void]$ui.RuntimeList.Children.Add($row.Row)
    }
    Show-Runtimes
    Start-RuntimeCheck
}

# Install: the missing parts of the ticked rows, one after another. App installs wait for it (Start-NextApp), and it
# waits for them.
$script:rtQueue = New-Object System.Collections.ArrayList
$script:rtBusy = $false
$rtInstallWork = {
    param($script, $key, $shared)
    if ($key -eq 'NetFx3') {
        # /NoRestart: DISM would otherwise wait for an answer to "Restart now?" in its hidden window
        $p = Start-Process dism.exe -ArgumentList '/Online /Enable-Feature /FeatureName:NetFx3 /All /NoRestart' -WindowStyle Hidden -PassThru
    } else {
        $p = Start-Process powershell.exe -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$script`" -App $key" -WindowStyle Hidden -PassThru
    }
    $null = $p.Handle; $shared.Pid = $p.Id
    $p.WaitForExit()
    $p.ExitCode
}
function Get-RuntimePartName([string]$key) {
    $rt = $runtimes | Where-Object { $key -in $_.Parts } | Select-Object -First 1
    if ($key -match '^VC(\d{4})(x\d\d)$' -and $Matches[1] -ne '2015') { "Visual C++ $($Matches[1]) ($($Matches[2]))" } elseif ($rt.NameKey) { T $rt.NameKey } else { $rt.Name }
}
function Start-NextRuntime {
    $total = $script:rtTotal
    if ($script:rtCancel -or !$script:rtQueue.Count) {
        $script:rtBusy = $false; $script:rtShared = $null
        Hide-Progress 'runtimes'
        $cancelled = $script:rtCancel
        if ($cancelled) { $script:rtCancel = $false; Set-Status (T 'rt.cancelled') }
        # Read again: what is installed now (an installer can report an error and still install)
        Start-Work $rtCheckWork @($logicFile, $rtParts) {
            param($r, $ctx)
            $res = Get-LastOutput $r
            if ($res -is [hashtable]) { $script:rtState = $res }
            # What is still missing of the parts that were installed
            $left = @($ctx.Parts | Where-Object { $script:rtState -is [hashtable] -and !$script:rtState[$_] } | ForEach-Object { Get-RuntimePartName $_ })
            Show-Runtimes
            if (!$ctx.Cancelled) { Set-Status $(if ($left.Count) { (T 'rt.left') -f ($left -join ', ') } else { T 'rt.done' }) }
        } @{ Parts = @($script:rtKeys); Cancelled = $cancelled }
        Show-Runtimes
        # App installs that waited
        Start-NextApp
        return
    }
    $key = [string]$script:rtQueue[0]; $script:rtQueue.RemoveAt(0)
    $name = Get-RuntimePartName $key
    $shared = [hashtable]::Synchronized(@{ Pid = 0 })
    $script:rtShared = $shared
    $doneCount = $total - $script:rtQueue.Count - 1
    $detail = if ($script:rtQueue.Count) { (T 'prog.queued') -f $script:rtQueue.Count } else { '' }
    Show-Progress 'runtimes' ((T 'status.installing') -f $name) ([int](100 * $doneCount / [Math]::Max(1, $total))) $detail { param($s) $script:rtCancel = $true; $script:rtQueue.Clear(); if ($s -and $s.Pid) { & taskkill.exe /PID $s.Pid /T /F *> $null } } $shared
    Set-Status ((T 'status.installing') -f $name) $true
    Start-Work $rtInstallWork @($gameApps, $key, $shared) { param($r) Start-NextRuntime } $null
}
$ui.RuntimeInstall.Add_Click({
    if ($script:rtBusy -or $script:rtState -isnot [hashtable]) { return }
    $rows = @($runtimes | Where-Object { $_.Check.IsChecked -and @(Get-RuntimeMissing $_).Count })
    if (!$rows.Count) { Set-Status (T 'rt.none'); return }
    # One install at a time: not while an app installs or updates
    if (@($apps | Where-Object { $_.State -ne 'idle' -and $null -ne $_.State }).Count) { Set-Status (T 'rt.wait'); return }
    $keys = @($rows | ForEach-Object { Get-RuntimeMissing $_ })
    if (@($keys | Where-Object { $_ -ne 'NetFx3' }).Count -and !(Get-Command winget -ErrorAction SilentlyContinue)) {
        $keys = @($keys | Where-Object { $_ -eq 'NetFx3' })
        if (!$keys.Count) { Set-Status (T 'status.nowinget'); return }
    }
    $lines = @($keys | ForEach-Object { Get-RuntimePartName $_ })
    if ((Show-Ask (T 'rt.ask') 'YesNo' 'Question' $lines (T 'rt.note')) -ne 'Yes') { return }
    $script:rtQueue.Clear(); foreach ($k in $keys) { [void]$script:rtQueue.Add($k) }
    $script:rtKeys = $keys; $script:rtTotal = $keys.Count; $script:rtCancel = $false; $script:rtBusy = $true
    Show-Runtimes
    Start-NextRuntime
})
