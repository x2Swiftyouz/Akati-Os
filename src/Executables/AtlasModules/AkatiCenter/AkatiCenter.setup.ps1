<#
.SYNOPSIS
    Akati OS Center: Health > What setup changed (the setup options against this PC now, read only) and the Start here
    card of the Dashboard (the first steps after setup).
    Dot-sourced by AkatiCenter.ps1 (runs in its scope: $ui, $window, T and the other parts).
#>
# ---------------------------------------------------------------------------------------------
# What setup changed. The setup writes the options picked in AME Wizard to HKLM\SOFTWARE\AkatiOS\Options, one REG_DWORD
# per option (tweaks\misc\akati-options.yml). Each item compares an option with this PC now: Done, Not done, Changed later
# (the change history or the Windows Update baseline shows that it was done and changed afterwards) or Not picked. Only
# reads; Defender is shown, never changed.
# ---------------------------------------------------------------------------------------------
Add-Mark 'Setup report'
$optionsKey = 'HKLM:\SOFTWARE\AkatiOS\Options'
# Stock Windows services. One of them missing (or the Appx module not loading) means a trimmed Windows image.
$stockServices = 'wuauserv', 'BITS', 'W32Time', 'Spooler', 'WSearch', 'DoSvc', 'UsoSvc', 'Audiosrv'
# Id: the text keys setup.i.<Id>. Opt: the setup option. Group: services of $serviceGroups. App: an Appx package.
# Tweak: the switch in Tweaks that changes the same thing (its change in the history means "changed later").
$setupItems = @(
    @{ Id = 'extrasvc'; Opt = 'disable-extra-services'; Glyph = 0xE912; Group = 'extra'; Tweak = 'extrasvc' }
    @{ Id = 'xbox'; Opt = 'disable-xbox-services'; Glyph = 0xE7FC; Group = 'xbox'; Tweak = 'svcxbox' }
    @{ Id = 'bluetooth'; Opt = 'disable-bluetooth'; Glyph = 0xE702; Group = 'bluetooth'; Tweak = 'svcbt' }
    @{ Id = 'time'; Opt = 'disable-time-service'; Glyph = 0xE823; Group = 'time'; Tweak = 'svctime' }
    @{ Id = 'dosvc'; Opt = 'disable-delivery-optimization'; Glyph = 0xE896; Group = 'dosvc'; Tweak = 'svcdo' }
    @{ Id = 'wu'; Opt = 'updates-off'; Glyph = 0xE895; Group = 'wu'; Tweak = 'svcwu' }
    @{ Id = 'autoupd'; Glyph = 0xE777 }
    @{ Id = 'store'; Opt = 'remove-store'; Glyph = 0xE719; App = 'Microsoft.WindowsStore'; Tweak = 'store' }
    @{ Id = 'paint'; Opt = 'remove-paint'; Glyph = 0xE790; App = 'Microsoft.Paint' }
    @{ Id = 'snip'; Opt = 'remove-snipping-tool'; Glyph = 0xE722; App = 'Microsoft.ScreenSketch' }
    @{ Id = 'edge'; Opt = 'uninstall-edge'; Glyph = 0xE774 }
    @{ Id = 'hibernation'; Opt = 'disable-hibernation'; Glyph = 0xE708; Tweak = 'hibernation' }
    @{ Id = 'power'; Opt = 'disable-power-saving'; Glyph = 0xE945; Tweak = 'maxperf' }
    @{ Id = 'timer'; Opt = 'enable-timer-resolution'; Glyph = 0xE916; Tweak = 'timer' }
    @{ Id = 'notify'; Opt = 'disable-notifications'; Glyph = 0xEA8F }
    @{ Id = 'gamebar'; Opt = 'disable-game-bar'; Glyph = 0xE7FC }
    @{ Id = 'defender'; Glyph = 0xE83D }
)
# Background work: the options and the state of everything the items compare (only reads)
$setupWork = {
    param($key, $groups, [string[]]$stock)
    $r = @{ Build = [Environment]::OSVersion.Version.Build }
    if (Test-Path $key) {
        $r.Options = @{}
        $k = Get-Item -Path $key
        foreach ($n in $k.GetValueNames()) { if ([string]$k.GetValue($n) -eq '1') { $r.Options[$n] = $true } }
    }
    $base = 'HKLM:\SYSTEM\CurrentControlSet\Services'
    $r.Svc = @{}
    foreach ($g in @($groups.Keys)) {
        $found = 0; $on = @()
        foreach ($n in @($groups[$g])) {
            if (!(Test-Path "$base\$n")) { continue }
            $found++
            if ((Get-ItemProperty -Path "$base\$n" -Name Start -ErrorAction SilentlyContinue).Start -ne 4) { $on += $n }
        }
        $r.Svc[$g] = @{ Found = $found; On = $on }
    }
    $r.Missing = @($stock | Where-Object { !(Test-Path "$base\$_") })
    # Some trimmed Windows builds cannot load the Appx module: then the apps cannot be read
    $r.AppxOk = $true; $r.Apps = @{}
    try { foreach ($a in @(Get-AppxPackage -ErrorAction Stop)) { $r.Apps[[string]$a.Name] = $true } } catch { $r.AppxOk = $false }
    # Windows 10 also has the classic Paint (a Windows capability); Windows 11 has only the app
    $r.MsPaint = $r.Build -lt 22000 -and (Test-Path (Join-Path $env:windir 'System32\mspaint.exe'))
    $r.Edge = (Test-Path "${env:ProgramFiles(x86)}\Microsoft\Edge\Application\msedge.exe") -or (Test-Path "$env:ProgramFiles\Microsoft\Edge\Application\msedge.exe")
    $r.AU = (Get-ItemProperty -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU' -Name AUOptions -ErrorAction SilentlyContinue).AUOptions
    $r.Hib = (Get-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\Power' -Name HibernateEnabled -ErrorAction SilentlyContinue).HibernateEnabled
    $r.Power = [string](& powercfg.exe /getactivescheme) -match '11111111-1111-1111-1111-111111111111'
    $r.Timer = [bool](Get-ScheduledTask -TaskName 'Force Timer Resolution' -ErrorAction SilentlyContinue)
    $r.Toast = (Get-ItemProperty -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\PushNotifications' -Name ToastEnabled -ErrorAction SilentlyContinue).ToastEnabled
    $r.GameDvr = (Get-ItemProperty -Path 'HKCU:\System\GameConfigStore' -Name GameDVR_Enabled -ErrorAction SilentlyContinue).GameDVR_Enabled
    # Defender, read only: real-time protection as Windows reports it, else whether its service runs
    $r.Rtp = $null
    try { $r.Rtp = [bool](Get-MpComputerStatus -ErrorAction Stop).RealTimeProtectionEnabled } catch { }
    $r.DefSvc = try { [string](Get-Service -Name WinDefend -ErrorAction Stop).Status } catch { '' }
    $r
}
# Screenshot mode: a sample PC (most done, one changed later, one not done, one not picked)
$setupSample = @{ Build = 26100; Options = @{ 'defender-enable' = $true; 'auto-updates-disable' = $true; 'disable-hibernation' = $true; 'disable-power-saving' = $true
                  'remove-paint' = $true; 'remove-store' = $true; 'disable-unused-services' = $true; 'disable-extra-services' = $true; 'disable-xbox-services' = $true
                  'disable-time-service' = $true; 'disable-delivery-optimization' = $true; 'disable-notifications' = $true; 'disable-game-bar' = $true
                  'tray-icon' = $true; 'enable-timer-resolution' = $true; 'desktop-menu' = $true }
                  Svc = @{ extra = @{ Found = 28; On = @() }; xbox = @{ Found = 3; On = @('XblAuthManager', 'XblGameSave', 'XboxNetApiSvc') }; bluetooth = @{ Found = 3; On = @('bthserv', 'BTAGService', 'BthAvctpSvc') }
                           time = @{ Found = 1; On = @() }; dosvc = @{ Found = 1; On = @() }; wu = @{ Found = 3; On = @('wuauserv', 'UsoSvc', 'WaaSMedicSvc') } }
                  Missing = @(); AppxOk = $true; Apps = @{ 'Microsoft.WindowsStore' = $false }; MsPaint = $false; Edge = $true; AU = 2; Hib = 0; Power = $true; Timer = $true
                  Toast = 1; GameDvr = 0; Rtp = $true; DefSvc = 'Running' }
$setupSampleHistory = @("$((Get-Date).AddDays(-2).ToString('s', [Globalization.CultureInfo]::InvariantCulture))|svcxbox|0")
# One row: State (Get-SetupItemState), Now and Want (texts), Hint
function Get-SetupRow($item, $r, [string[]]$history, [string[]]$baseline) {
    $o = $r.Options
    $known = $o -is [hashtable]
    $picked = if ($known -and $item.Opt) { [bool]$o[$item.Opt] } elseif ($known) { $true } else { $null }
    $off = T 'setup.v.off'; $on = T 'setup.v.on'
    $want = ''; $now = ''; $ok = $false; $changed = $false; $hint = ''
    if ($item.Tweak) { $hint = (T 'setup.h.switch') -f (T "tw.$($item.Tweak)") }
    if ($item.Group) {
        $s = $r.Svc[$item.Group]
        $want = $off
        if (!$s -or !$s.Found) { $now = T 'setup.v.missing'; $ok = $true }
        elseif (!$s.On.Count) { $now = $off; $ok = $true }
        else { $now = if ($s.On.Count -eq $s.Found) { $on } else { (T 'setup.v.someon') -f (($s.On | Select-Object -First 4) -join ', ') } }
        $keys = @($serviceGroups[$item.Group].Keys | ForEach-Object { "svc:$_" })
        $changed = (Test-HistoryKey $history (@($item.Tweak) + $keys)) -or (Test-BaselineKey $baseline $keys)
    } elseif ($item.App) {
        $want = T 'setup.v.removed'
        if (!$r.AppxOk) { $now = T 'setup.v.noappx' }
        else {
            $there = [bool]$r.Apps[$item.App] -or ($item.Id -eq 'paint' -and $r.MsPaint)
            $now = T $(if ($there) { 'setup.v.installed' } else { 'setup.v.removed' }); $ok = !$there
        }
        if (!$item.Tweak) { $hint = T 'setup.h.app' }
        $changed = (Test-HistoryKey $history @($item.Tweak, "app:$($item.App)")) -or (Test-BaselineKey $baseline @("app:$($item.App)"))
    } else {
        switch ($item.Id) {
            'autoupd' {
                $wantOff = $known -and ($o['auto-updates-disable'] -or $o['updates-off'])
                if ($known -and !$wantOff -and !$o['auto-updates-default']) { $picked = $false }
                $want = T $(if ($wantOff) { 'setup.v.au.off' } else { 'setup.v.au.on' })
                $isOff = [string]$r.AU -eq '2'
                $now = T $(if ($isOff) { 'setup.v.au.off' } else { 'setup.v.au.on' })
                $ok = $isOff -eq [bool]$wantOff
                $hint = T 'setup.h.au'
            }
            'edge' { $want = T 'setup.v.removed'; $now = T $(if ($r.Edge) { 'setup.v.installed' } else { 'setup.v.removed' }); $ok = !$r.Edge; $hint = T 'setup.h.app' }
            'hibernation' { $want = $off; $now = if ([string]$r.Hib -eq '1') { $on } else { $off }; $ok = [string]$r.Hib -ne '1'; $changed = Test-HistoryKey $history @('hibernation') }
            'power' { $want = T 'setup.v.akatiplan'; $now = T $(if ($r.Power) { 'setup.v.akatiplan' } else { 'setup.v.otherplan' }); $ok = [bool]$r.Power; $changed = Test-HistoryKey $history @('maxperf') }
            'timer' { $want = T 'setup.v.timer.on'; $now = T $(if ($r.Timer) { 'setup.v.timer.on' } else { 'setup.v.timer.off' }); $ok = [bool]$r.Timer; $changed = Test-HistoryKey $history @('timer') }
            'notify' { $want = $off; $now = if ([string]$r.Toast -eq '0') { $off } else { $on }; $ok = [string]$r.Toast -eq '0'; $hint = T 'setup.h.notify' }
            'gamebar' { $want = $off; $now = if ([string]$r.GameDvr -eq '0') { $off } else { $on }; $ok = [string]$r.GameDvr -eq '0'; $hint = T 'setup.h.gamebar' }
            'defender' {
                # Read only: whether real-time protection is on (Get-MpComputerStatus), else whether the Defender service runs
                $wantOn = !($known -and $o['defender-disable'])
                if ($known -and !$o['defender-enable'] -and !$o['defender-disable']) { $picked = $false }
                $isOn = if ($null -ne $r.Rtp) { [bool]$r.Rtp } else { $r.DefSvc -eq 'Running' }
                $want = if ($wantOn) { $on } else { $off }
                $now = if ($null -eq $r.Rtp -and $isOn) { T 'setup.v.defsvc' } elseif ($isOn) { $on } else { $off }
                $ok = $isOn -eq $wantOn
                $hint = T $(if ($wantOn -and !$isOn) { 'setup.h.defender.other' } else { 'setup.h.defender' })
            }
        }
    }
    $state = Get-SetupItemState $picked $ok $changed
    $trimmed = $r.Missing.Count -or !$r.AppxOk
    # Not done on a trimmed Windows image: parts of Windows may be missing
    if ($state -eq 'notdone' -and $trimmed -and $item.Id -ne 'defender') { $hint = T 'setup.trimmed' }
    $showHint = $state -in 'notdone', 'changed' -or $item.Id -eq 'defender'
    @{ Item = $item; State = $state; Want = $want; Now = $now; Hint = $(if ($showHint) { $hint } else { '' }) }
}
# Done (green), Not done (amber), Changed later (accent), Not picked and Not recorded (gray)
function New-StateBadge([string]$state) {
    $b = New-Object System.Windows.Controls.Border
    $b.CornerRadius = 6; $b.Padding = '8,2'; $b.BorderThickness = '1'; $b.VerticalAlignment = 'Center'; $b.Margin = '12,0,0,0'
    $back, $line, $fore = switch ($state) { 'done' { 'Fill', 'Fill', 'Good' } 'notdone' { 'WarnSoft', 'WarnSoft', 'Warn' } 'changed' { 'AccentSoft', 'AccentLine', 'AccentText' } default { 'Fill', 'Fill', 'MutedBrush' } }
    $b.SetResourceReference([System.Windows.Controls.Border]::BackgroundProperty, $back)
    $b.SetResourceReference([System.Windows.Controls.Border]::BorderBrushProperty, $line)
    $t = New-Text (T "setup.s.$state") 11.5 'SemiBold'; $t.TextWrapping = 'NoWrap'
    $t.SetResourceReference([System.Windows.Controls.TextBlock]::ForegroundProperty, $fore)
    $b.Child = $t
    $b
}
function Get-SetupRows($r) {
    $history = [string[]]@(if ($Screenshot) { $setupSampleHistory } else { Get-RegValue $settingsKey 'History' | Where-Object { $_ } })
    $baseline = [string[]]@(if (!$Screenshot) { Get-RegValue $settingsKey 'WuBaseline' | Where-Object { $_ } })
    @(foreach ($item in $setupItems) { Get-SetupRow $item $r $history $baseline })
}
function Get-SetupLine($row) {
    if ($row.State -eq 'unknown') { (T 'setup.now') -f $row.Now }
    elseif ($row.State -eq 'notpicked') { (T 'setup.notpicked') -f $row.Now }
    else { (T 'setup.line') -f $row.Want, $row.Now }
}
function Show-SetupReport($r) {
    $script:setupResult = $r
    $ui.SetupList.Children.Clear()
    if ($r -isnot [hashtable]) {
        $ui.SetupEmpty.Text = T 'setup.loading'; $ui.SetupEmpty.SetResourceReference([System.Windows.Controls.TextBlock]::ForegroundProperty, 'MutedBrush')
        $ui.SetupEmpty.Visibility = 'Visible'; $ui.SetupSub.Text = T 'setup.sub'; return
    }
    $rows = Get-SetupRows $r
    $script:setupRows = $rows
    $notes = @()
    if ($r.Options -isnot [hashtable]) { $notes += T 'setup.norecord' }
    if ($r.Missing.Count -or !$r.AppxOk) { $notes += T 'setup.trimmed' }
    $ui.SetupEmpty.Text = $notes -join "`n"
    $ui.SetupEmpty.SetResourceReference([System.Windows.Controls.TextBlock]::ForegroundProperty, 'Warn')
    $ui.SetupEmpty.Visibility = if ($notes.Count) { 'Visible' } else { 'Collapsed' }
    foreach ($row in $rows) {
        $parts = New-Row ([string][char]$row.Item.Glyph) (T "setup.i.$($row.Item.Id)") $null (New-StateBadge $row.State) $null
        $parts.Sub.Text = Get-SetupLine $row
        if ($row.Hint) {
            $h = New-Text $row.Hint 12; $h.Margin = '0,3,12,0'
            $h.SetResourceReference([System.Windows.Controls.TextBlock]::ForegroundProperty, $(if ($row.State -eq 'notdone') { 'Warn' } else { 'MutedBrush' }))
            $parts.Sub.Parent.Children.Insert($parts.Sub.Parent.Children.IndexOf($parts.Sub) + 1, $h)
        }
        if ($row.State -in 'notpicked', 'unknown') { $parts.Icon.Opacity = 0.6 }
        [void]$ui.SetupList.Children.Add($parts.Row)
    }
    Update-Separators $ui.SetupList
    $count = { param($s) @($rows | Where-Object { $_.State -eq $s }).Count }
    $ui.SetupSub.Text = (T 'setup.sub') + '  ' + ((T 'setup.summary') -f (& $count 'done'), (& $count 'notdone'), (& $count 'changed'))
}
function Start-SetupReport {
    if ($Screenshot) { Show-SetupReport $setupSample; return }
    if ($script:setupBusy) { return }
    $script:setupBusy = $true
    if ($script:setupResult -isnot [hashtable]) { Show-SetupReport $null }
    $groups = @{}
    foreach ($i in $setupItems) { if ($i.Group) { $groups[$i.Group] = [string[]]@($serviceGroups[$i.Group].Keys) } }
    Start-Work $setupWork @($optionsKey, $groups, [string[]]$stockServices) { param($r) $script:setupBusy = $false; Show-SetupReport (Get-LastOutput $r) } $null
}
$ui.SetupRefresh.Add_Click({ Start-SetupReport })
# Export report: a plain text file on the desktop, in the window language
$ui.SetupExport.Add_Click({
    $rows = @($script:setupRows)
    if ($script:setupResult -isnot [hashtable] -or !$rows.Count) { Set-Status (T 'setup.loading'); return }
    $r = $script:setupResult
    $c = Get-LangCulture
    $lines = New-Object System.Collections.ArrayList
    [void]$lines.Add('Akati OS - ' + (T 'setup.title'))
    [void]$lines.Add(('Akati OS {0}  ·  Windows build {1}  ·  {2}' -f $version, $r.Build, (Get-Date).ToString('d MMMM yyyy HH:mm', $c)))
    [void]$lines.Add('')
    if ($ui.SetupEmpty.Visibility -eq 'Visible' -and $ui.SetupEmpty.Text) { [void]$lines.Add($ui.SetupEmpty.Text); [void]$lines.Add('') }
    foreach ($row in $rows) {
        [void]$lines.Add(('[{0}]  {1}' -f (T "setup.s.$($row.State)"), (T "setup.i.$($row.Item.Id)")))
        [void]$lines.Add('    ' + (Get-SetupLine $row))
        if ($row.Hint) { [void]$lines.Add('    ' + $row.Hint) }
    }
    [void]$lines.Add('')
    [void]$lines.Add($ui.SetupSub.Text)
    try {
        $file = Join-Path ([Environment]::GetFolderPath('Desktop')) ('Akati OS setup report {0}.txt' -f (Get-Date).ToString('yyyy-MM-dd HHmm', [Globalization.CultureInfo]::InvariantCulture))
        [IO.File]::WriteAllText($file, ($lines -join "`r`n") + "`r`n", (New-Object System.Text.UTF8Encoding $true))
        Set-Status ((T 'setup.exported') -f (Split-Path $file -Leaf))
    } catch { Set-Status $_.Exception.Message }
})

# ---------------------------------------------------------------------------------------------
# Start here (Dashboard): five first steps after setup, until Hide. Each step is ticked from what this PC and the
# settings show: a graphics driver of the maker is installed, a launcher of Gaming apps is installed, a Tweaks profile
# was applied (ProfileApplied) or saved (TweakProfile), a speed test result is kept (SpeedHistory), Akati Doctor ran
# from the Health page (DoctorRan).
# ---------------------------------------------------------------------------------------------
# Graphics cards by their PCI vendor: a card still on the Microsoft Basic Display Adapter has no driver of its maker
$startGpuWork = {
    $list = @()
    try {
        foreach ($v in @(Get-CimInstance Win32_VideoController -ErrorAction Stop)) {
            $id = [string]$v.PNPDeviceID
            $vendor = if ($id -match 'VEN_10DE') { 'nvidia' } elseif ($id -match 'VEN_1002') { 'amd' } elseif ($id -match 'VEN_8086') { 'intel' } else { '' }
            if (!$vendor) { continue }
            $list += @{ Vendor = $vendor; Name = [string]$v.Name; Basic = [string]$v.Name -match 'Basic Display|Basic Render' }
        }
    } catch { }
    $list
}
$gpuPages = @{ nvidia = 'https://www.nvidia.com/en-us/drivers/'; amd = 'https://www.amd.com/en/support/download/drivers.html'; intel = 'https://www.intel.com/content/www/us/en/download-center/home.html' }
$gpuVendorNames = @{ nvidia = 'NVIDIA'; amd = 'AMD'; intel = 'Intel' }
$script:startGpus = $null
function Get-StartSteps {
    $inv = [Globalization.CultureInfo]::InvariantCulture
    $c = Get-LangCulture
    $steps = @()
    # 1. Graphics driver
    $g = if ($null -eq $script:startGpus) { @() } else { @($script:startGpus) }
    $bad = @($g | Where-Object { $_.Basic })
    $good = @($g | Where-Object { !$_.Basic })
    $s1 = @{ N = 1; Done = $null -ne $script:startGpus -and $g.Count -gt 0 -and !$bad.Count; Go = 'start.1.go' }
    $s1.Vendor = if ($bad.Count) { $bad[0].Vendor } elseif ($good.Count) { $good[0].Vendor } else { '' }
    $s1.Sub = if ($null -eq $script:startGpus) { T 'rt.checking' } elseif ($s1.Done) { (T 'start.1.ok') -f (($good | ForEach-Object { $_.Name }) -join ', ') }
              elseif ($bad.Count) { (T 'start.1.bad') -f $gpuVendorNames[$bad[0].Vendor] } else { T 'start.1.none' }
    $steps += $s1
    # 2. Game launchers
    $launchers = @($apps | Where-Object { $_.Cat -eq 'launchers' -and (Test-App $_) } | ForEach-Object { $_.Name })
    $steps += @{ N = 2; Done = $launchers.Count -gt 0; Go = 'start.2.go'; Sub = $(if ($launchers.Count) { (T 'start.2.ok') -f ($launchers -join ', ') } else { T 'start.2.d' }) }
    # 3. Tweaks profile: applied, or a profile of your own saved
    $applied = [string](Get-RegValue $settingsKey 'ProfileApplied')
    $saved = [bool](Get-RegValue $settingsKey 'TweakProfile')
    $pname = ($applied -split '\|')[0]
    $steps += @{ N = 3; Done = [bool]$applied -or $saved; Go = 'start.3.go'
                 Sub = $(if ($pname -in 'gaming', 'normal', 'custom') { (T 'start.3.ok') -f (T "profile.$pname") } elseif ($saved) { (T 'start.3.ok') -f (T 'profile.custom') } else { T 'start.3.d' }) }
    # 4. Speed test
    $speed = @(@(Get-RegValue $settingsKey 'SpeedHistory') | ForEach-Object { ConvertFrom-SpeedEntry $_ } | Where-Object { $_ })
    $steps += @{ N = 4; Done = $speed.Count -gt 0; Go = 'start.4.go'
                 Sub = $(if ($speed.Count) { (T 'start.4.ok') -f (Format-SpeedValue $speed[0].Down), $speed[0].Time.ToString('d MMM', $c) } else { T 'start.4.d' }) }
    # 5. Akati Doctor from the Health page
    $ran = [string](Get-RegValue $settingsKey 'DoctorRan')
    $when = try { [datetime]::ParseExact($ran, 's', $inv).ToString('d MMM HH:mm', $c) } catch { '' }
    $steps += @{ N = 5; Done = [bool]$when; Go = 'start.5.go'; Sub = $(if ($when) { (T 'start.5.ok') -f $when } else { T 'start.5.d' }) }
    $steps
}
function Invoke-StartStep($step) {
    switch ($step.N) {
        1 { if ($step.Vendor) { Start-Process $gpuPages[$step.Vendor] } else { Show-Element 'gaming' $ui.GpuDetected.Parent.Parent } }
        2 { $ui.NavGaming.IsChecked = $true }
        3 { Show-Element 'tweaks' $ui.ProfileGrid }
        4 { Show-Element 'boost' $ui.SpeedSection; Start-SpeedTest }
        5 { if ($script:page -eq 'health' -or $script:healthLoaded) { $ui.NavHealth.IsChecked = $true; Start-Health } else { $ui.NavHealth.IsChecked = $true } }
    }
}
function Show-StartCard($steps) {
    $done = @($steps | Where-Object { $_.Done }).Count
    $ui.StartSub.Text = if ($done -ge $steps.Count) { T 'start.alldone' } else { (T 'start.sub') -f $done, $steps.Count }
    $ui.StartList.Children.Clear()
    foreach ($s in $steps) {
        $btn = New-Object System.Windows.Controls.Button
        $btn.Style = $window.FindResource($(if ($s.Done) { 'Pill' } else { 'PillAccent' })); $btn.Padding = '12,4'; $btn.Content = T $s.Go; $btn.Tag = $s
        $btn.Add_Click({ Invoke-StartStep $this.Tag })
        $row = New-Row '' (T "start.$($s.N)") $null $btn $null
        $row.Sub.Text = $s.Sub
        # A tick when done, else the number of the step
        if ($s.Done) {
            $row.Icon.Child.Text = [string][char]0xE73E
            $row.Icon.Child.SetResourceReference([System.Windows.Controls.TextBlock]::ForegroundProperty, 'Good')
            $row.Title.Opacity = 0.75
        } else {
            $num = New-Text ([string]$s.N) 13 'Bold'; $num.HorizontalAlignment = 'Center'; $num.VerticalAlignment = 'Center'
            $num.SetResourceReference([System.Windows.Controls.TextBlock]::ForegroundProperty, 'AccentText')
            $row.Icon.Child = $num
        }
        $row.Row.Padding = '4,9'
        [void]$ui.StartList.Children.Add($row.Row)
    }
    Update-Separators $ui.StartList
}
function Update-StartCard {
    if ($Screenshot -or (Get-RegValue $settingsKey 'StartHidden') -eq 1) { $ui.StartCard.Visibility = 'Collapsed'; return }
    $ui.StartCard.Visibility = 'Visible'
    Show-StartCard (Get-StartSteps)
}
function Start-StartGpus {
    Start-Work $startGpuWork @() {
        param($r)
        $script:startGpus = @($r | ForEach-Object { $_.psobject.BaseObject } | Where-Object { $_ -is [hashtable] })
        if ($script:page -eq 'dashboard') { Update-StartCard }
    } $null
}
$ui.StartHide.Add_Click({ Save-Setting StartHidden 1; $ui.StartCard.Visibility = 'Collapsed'; Set-Status (T 'start.hidden') })
# Ctrl+K > Start here: shows the card again
function Show-StartAgain {
    Remove-ItemProperty -Path $settingsKey -Name StartHidden -ErrorAction SilentlyContinue
    $ui.NavDashboard.IsChecked = $true
    if ($null -eq $script:startGpus -and !$Screenshot) { Start-StartGpus }
    Update-StartCard
    $ui.PageDashboard.ScrollToVerticalOffset(0)
}
if (!$Screenshot -and (Get-RegValue $settingsKey 'StartHidden') -ne 1) {
    Update-StartCard
    Start-StartGpus
}
