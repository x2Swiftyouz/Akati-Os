<#
.SYNOPSIS
    Akati OS Center: Game boost, ping test and startup apps (also -Boost without a window).
    Dot-sourced by AkatiCenter.ps1 (runs in its scope: $ui, $window, T and the other parts).
#>
# ---------------------------------------------------------------------------------------------
# Game boost: one click before playing, and back again afterwards. What was changed is saved in the
# registry, so Stop still works after Akati OS Center or Windows was restarted.
# ---------------------------------------------------------------------------------------------
Add-Mark 'Game boost'
$boostKey = 'HKCU:\Software\AkatiOS\Center\Boost'
$toastKey = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\PushNotifications'
# Background apps that are safe to close while playing (never game launchers or browsers)
$boostCandidates = 'OneDrive', 'Teams', 'ms-teams', 'Spotify', 'PhoneExperienceHost', 'Dropbox', 'GoogleDriveFS', 'Skype'
# Services that work in the background and can wait until the game is closed: search indexing, SysMain (prefetch),
# printing and the downloads of Windows Update. Only stopped (the start type stays), started again at Stop; they start
# as usual after a restart too. None of them is used by anti-cheats.
$boostServices = 'WSearch', 'SysMain', 'Spooler', 'wuauserv', 'BITS', 'DoSvc'
$powerSchemes = @(
    '11111111-1111-1111-1111-111111111111'   # Akati OS Power Scheme (Maximum Performance)
    'e9a42b02-d5df-448d-aa00-03f14749eb61'   # Ultimate Performance
    '8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c'   # High performance
)

function Get-ActiveScheme { if ([string](powercfg /getactivescheme) -match '([0-9a-f]{8}-[0-9a-f-]{27})') { $Matches[1] } }
function Test-Boost { [bool](Get-RegValue $boostKey 'Active') }

# "Last session: 1 h 05 min · 2 apps closed · 4 services paused"
function Format-Minutes([int]$m) { if ($m -ge 60) { (T 'time.hm') -f [Math]::Floor($m / 60), ($m % 60) } else { (T 'time.m') -f $m } }
function Update-BoostLast {
    $parts = ([string](Get-RegValue $settingsKey 'LastBoost')).Split('|')
    if ($parts.Count -lt 4 -or (Test-Boost)) { $ui.BoostLast.Visibility = 'Collapsed'; return }
    $text = (T 'boost.last') -f (Format-Minutes ([int]$parts[1]))
    if ([int]$parts[2]) { $text += ' · ' + ((T 'boost.last.apps') -f $parts[2]) }
    if ([int]$parts[3]) { $text += ' · ' + ((T 'boost.last.services') -f $parts[3]) }
    $ui.BoostLast.Text = $text
    $ui.BoostLast.Visibility = 'Visible'
}
function Update-BoostCard {
    Update-BoostLast
    $running = @(Get-Process -Name $boostCandidates -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Name -Unique)
    $ui.BoostAppsText.Text = if ($running.Count) { (T 'boost.apps') + ' (' + ($running -join ', ') + ')' } else { (T 'boost.apps') + ' (' + (T 'boost.noapps') + ')' }
    if (Test-Boost) {
        $since = Get-RegValue $boostKey 'Since'
        $ui.BoostState.Text = (T 'boost.on') -f $since
        $ui.BoostState.Foreground = $window.FindResource('Good')
        $ui.BoostButton.Content = T 'boost.stop'
        $ui.BoostButton.Style = $window.FindResource('Secondary')
        $ui.BoostIcon.SetResourceReference([System.Windows.Controls.Border]::BackgroundProperty, 'AccentGradient')
        foreach ($c in 'BoostPower', 'BoostApps', 'BoostNotify', 'BoostServices') { $ui[$c].IsEnabled = $false }
    } else {
        $ui.BoostState.Text = T 'boost.off'
        $ui.BoostState.Foreground = $window.FindResource('MutedBrush')
        $ui.BoostButton.Content = T 'boost.start'
        $ui.BoostButton.Style = $window.FindResource('Primary')
        $ui.BoostIcon.SetResourceReference([System.Windows.Controls.Border]::BackgroundProperty, 'Fill')
        foreach ($c in 'BoostPower', 'BoostApps', 'BoostNotify', 'BoostServices') { $ui[$c].IsEnabled = $true }
    }
}

# The notification switch is copied as it is (value and registry type), so Stop restores exactly that
$toastSubKey = 'Software\Microsoft\Windows\CurrentVersion\PushNotifications'
function Start-Boost {
    New-Item -Path $boostKey -Force | Out-Null
    # Marked as on first: if a step fails, Stop still undoes the steps that worked
    Set-ItemProperty -Path $boostKey -Name Since -Value (Get-Date -Format 'HH:mm')
    Set-ItemProperty -Path $boostKey -Name Started -Value (Get-Date).ToString('s', [Globalization.CultureInfo]::InvariantCulture)
    Set-ItemProperty -Path $boostKey -Name Active -Value 1 -Type DWord
    $failed = @()
    if ($ui.BoostPower.IsChecked) {
        try {
            $before = Get-ActiveScheme
            $list = [string](powercfg /list)
            $target = $powerSchemes | Where-Object { $list -match $_ } | Select-Object -First 1
            if ($target -and $before -and $target -ne $before) {
                Set-ItemProperty -Path $boostKey -Name PrevScheme -Value $before
                powercfg /setactive $target | Out-Null
            }
        } catch { $failed += 'power' }
    }
    if ($ui.BoostApps.IsChecked) {
        try {
            $closed = @()
            foreach ($p in Get-Process -Name $boostCandidates -ErrorAction SilentlyContinue) {
                $path = try { $p.Path } catch { $null }
                if ($p.Name -eq 'OneDrive' -and $path) { & $path /shutdown } else { Stop-Process -Id $p.Id -Force -ErrorAction SilentlyContinue }
                if ($path -and $closed -notcontains $path) { $closed += $path }
            }
            if ($closed.Count) { Set-ItemProperty -Path $boostKey -Name Closed -Value ([string[]]$closed) -Type MultiString }
        } catch { $failed += 'apps' }
    }
    if ($ui.BoostNotify.IsChecked) {
        try {
            $key = [Microsoft.Win32.Registry]::CurrentUser.CreateSubKey($toastSubKey)
            $old = $key.GetValue('ToastEnabled', $null, 'DoNotExpandEnvironmentNames')
            if ($null -eq $old) { Set-ItemProperty -Path $boostKey -Name PrevToastKind -Value 'none' }
            else {
                Set-ItemProperty -Path $boostKey -Name PrevToastKind -Value ([string]$key.GetValueKind('ToastEnabled'))
                Set-ItemProperty -Path $boostKey -Name PrevToast -Value ([string]$old)
            }
            $key.SetValue('ToastEnabled', 0, 'DWord')
            $key.Close()
        } catch { $failed += 'notify' }
    }
    if ($ui.BoostServices.IsChecked) {
        try {
            # sc.exe returns at once (the service stops in the background); only running services are noted
            $paused = @(Get-Service -Name $boostServices -ErrorAction SilentlyContinue | Where-Object { $_.Status -eq 'Running' } | ForEach-Object { $_.Name })
            foreach ($n in $paused) { & sc.exe stop $n | Out-Null }
            if ($paused.Count) { Set-ItemProperty -Path $boostKey -Name PausedServices -Value ([string[]]$paused) -Type MultiString }
        } catch { $failed += 'services' }
    }
    if ($ui.BoostMemory.IsChecked) {
        # The standby list fills up again by itself, so there is nothing to undo at Stop
        try { if ([AkatiOS.Perf]::PurgeStandbyList() -ne 0) { $failed += 'memory' } } catch { $failed += 'memory' }
    }
    if ($failed.Count) { throw ((T 'status.boostpartial') -f ($failed -join ', ')) }
}

# The weekly report on the Dashboard: totals of this week (they start again on Monday)
function Add-WeekStat([string]$name, [double]$value) {
    $key = 'HKCU:\Software\AkatiOS\Center'
    if (!(Test-Path $key)) { New-Item -Path $key -Force | Out-Null }
    $week = Get-WeekStart (Get-Date)
    if ((Get-RegValue $key 'WeekStart') -ne $week) {
        Set-ItemProperty -Path $key -Name WeekStart -Value $week
        foreach ($n in 'WeekCleanBytes', 'WeekBoostMinutes', 'WeekBoosts') { Set-ItemProperty -Path $key -Name $n -Value '0' }
    }
    $old = 0.0; [void][double]::TryParse([string](Get-RegValue $key $name), [Globalization.NumberStyles]::Float, [Globalization.CultureInfo]::InvariantCulture, [ref]$old)
    Set-ItemProperty -Path $key -Name $name -Value ([string][long]($old + $value))
}
# The last session for the Game boost page: "start|minutes|apps closed|services paused"
function Save-BoostSession {
    $started = [string](Get-RegValue $boostKey 'Started')
    $start = [datetime]::MinValue
    if (![datetime]::TryParseExact($started, 's', [Globalization.CultureInfo]::InvariantCulture, 'None', [ref]$start)) { return }
    $minutes = [int][Math]::Max(0, ((Get-Date) - $start).TotalMinutes)
    $apps = @(Get-RegValue $boostKey 'Closed' | Where-Object { $_ }).Count
    $services = @(Get-RegValue $boostKey 'PausedServices' | Where-Object { $_ }).Count
    Set-ItemProperty -Path 'HKCU:\Software\AkatiOS\Center' -Name LastBoost -Value ('{0}|{1}|{2}|{3}' -f $started, $minutes, $apps, $services)
    Add-WeekStat 'WeekBoostMinutes' $minutes
    Add-WeekStat 'WeekBoosts' 1
}

function Stop-Boost {
    try { Save-BoostSession } catch { }
    try {
        $prevScheme = Get-RegValue $boostKey 'PrevScheme'
        if ($prevScheme) { powercfg /setactive $prevScheme | Out-Null }
    } catch { }
    try {
        $kind = Get-RegValue $boostKey 'PrevToastKind'
        if ($kind) {
            $key = [Microsoft.Win32.Registry]::CurrentUser.CreateSubKey($toastSubKey)
            if ($kind -eq 'none') { $key.DeleteValue('ToastEnabled', $false) }
            else {
                $text = [string](Get-RegValue $boostKey 'PrevToast')
                # A DWord comes back as the number written out; keep its 32 bits as they were
                $value = switch ($kind) {
                    'DWord' { [BitConverter]::ToInt32([BitConverter]::GetBytes([int64]$text), 0) }
                    'QWord' { [int64]$text }
                    default { $text }
                }
                $key.SetValue('ToastEnabled', $value, $kind)
            }
            $key.Close()
        }
    } catch { }
    foreach ($n in @(Get-RegValue $boostKey 'PausedServices')) { if ($n) { & sc.exe start $n | Out-Null } }
    # Open the closed apps again. explorer.exe starts them as the signed-in user, not elevated like this window.
    foreach ($path in @(Get-RegValue $boostKey 'Closed')) {
        if ($path -and (Test-Path -LiteralPath $path)) { Start-Process explorer.exe -ArgumentList "`"$path`"" }
    }
    Remove-Item -Path $boostKey -Recurse -Force -ErrorAction SilentlyContinue
}

# Game boost started: a short sound and the icon grows and settles (can be turned off)
$ui.BoostSound.IsChecked = (Get-RegValue $settingsKey 'BoostSound') -ne 0
$ui.BoostSound.Add_Click({ Save-Setting BoostSound ([int][bool]$this.IsChecked) })
function Show-BoostEffect {
    if (!$ui.BoostSound.IsChecked) { return }
    try {
        $wav = Join-Path $windir 'AtlasModules\Other\AkatiOS\Sounds\akatios-connect.wav'
        if (Test-Path $wav) { (New-Object System.Media.SoundPlayer $wav).Play() }
    } catch { }
    $scale = New-Object System.Windows.Media.ScaleTransform 1, 1
    $ui.BoostIcon.RenderTransformOrigin = '0.5,0.5'; $ui.BoostIcon.RenderTransform = $scale
    $grow = New-Object System.Windows.Media.Animation.DoubleAnimation 1, 1.25, (New-Object System.Windows.Duration ([TimeSpan]::FromMilliseconds(180)))
    $grow.AutoReverse = $true; $grow.RepeatBehavior = New-Object System.Windows.Media.Animation.RepeatBehavior 2
    $scale.BeginAnimation([System.Windows.Media.ScaleTransform]::ScaleXProperty, $grow)
    $scale.BeginAnimation([System.Windows.Media.ScaleTransform]::ScaleYProperty, $grow)
}
$ui.BoostButton.Add_Click({
    try {
        if (Test-Boost) { Stop-Boost; Set-Status (T 'status.boostoff') } else { Start-Boost; Set-Status (T 'status.booston'); Show-BoostEffect }
    } catch { Set-Status $_.Exception.Message }
    Update-BoostCard
    Request-MenuUpdate
})
# Automatic Game boost: the tray app (AkatiTray.ps1) watches for the games in My games
$ui.BoostAuto.IsChecked = (Get-RegValue 'HKCU:\Software\AkatiOS\Center' 'AutoBoost') -eq 1
$ui.BoostAuto.Add_Click({ Save-Setting AutoBoost $(if ($this.IsChecked) { 1 } else { 0 }) })

# Desktop menu > Game boost: start or stop it without the window; the menu shows the message
if ($Boost) {
    $message = try {
        $active = Test-Boost
        if ($Boost -eq 'off' -or ($Boost -eq 'toggle' -and $active)) { if ($active) { Stop-Boost }; T 'status.boostoff' }
        else { if (!$active) { Start-Boost }; T 'status.booston' }
    } catch { $_.Exception.Message }
    $centerKey = 'HKCU:\Software\AkatiOS\Center'
    if (!(Test-Path $centerKey)) { New-Item -Path $centerKey -Force | Out-Null }
    Set-ItemProperty -Path $centerKey -Name MenuResult -Value $message
    $script:exitNow = 0; return
}

# Ping: TCP connect time (more reliable than ICMP, which many servers block) to cloud regions near
# Thailand. Many online games run their Asian servers in these data centers.
$pingTargets = @(
    @{ Key = 'bkk'; Host = 'dynamodb.ap-southeast-7.amazonaws.com' }
    @{ Key = 'sin'; Host = 'dynamodb.ap-southeast-1.amazonaws.com' }
    @{ Key = 'hkg'; Host = 'dynamodb.ap-east-1.amazonaws.com' }
    @{ Key = 'tyo'; Host = 'dynamodb.ap-northeast-1.amazonaws.com' }
)
$pingWork = {
    param($targets)
    $out = @{}
    foreach ($t in $targets) {
        $ms = -1
        try {
            $ip = [Net.Dns]::GetHostAddresses($t.Host) | Where-Object { $_.AddressFamily -eq 'InterNetwork' } | Select-Object -First 1
            $client = New-Object Net.Sockets.TcpClient
            $sw = [Diagnostics.Stopwatch]::StartNew()
            $task = $client.ConnectAsync($ip, 443)
            if ($task.Wait(2000) -and $client.Connected) { $ms = [int]$sw.Elapsed.TotalMilliseconds }
            $client.Close()
        } catch { }
        $out[$t.Key] = $ms
    }
    $out
}
foreach ($t in $pingTargets) {
    $right = New-Object System.Windows.Controls.StackPanel
    $right.Orientation = 'Horizontal'
    $chart = New-Object System.Windows.Controls.Canvas
    $chart.Width = 160; $chart.Height = 30; $chart.Margin = '0,0,18,0'; $chart.ClipToBounds = $true
    $line = New-Object System.Windows.Shapes.Polyline
    $line.SetResourceReference([System.Windows.Shapes.Shape]::StrokeProperty, 'Accent2'); $line.StrokeThickness = 2; $line.StrokeLineJoin = 'Round'
    [void]$chart.Children.Add($line)
    $value = New-Text '-' 18 'Bold'; $value.MinWidth = 80; $value.TextAlignment = 'Right'; $value.VerticalAlignment = 'Center'
    [void]$right.Children.Add($chart); [void]$right.Children.Add($value)
    $row = New-Row ([string][char]0xE909) (T "ping.$($t.Key)") "t:ping.$($t.Key)" $right $null
    $row.Sub.Text = $t.Host
    $t.Line = $line; $t.Value = $value; $t.History = New-Object System.Collections.ArrayList
    [void]$ui.PingList.Children.Add($row.Row)
}
$script:pingOn = $false; $script:pingBusy = $false; $script:pingNext = [datetime]::MinValue
function Set-PingButton {
    $ui.PingButtonText.Text = if ($script:pingOn) { T 'ping.stop' } else { T 'ping.start' }
    $ui.PingButtonText.Tag = if ($script:pingOn) { 't:ping.stop' } else { 't:ping.start' }
    $ui.PingGlyph.Text = if ($script:pingOn) { [string][char]0xE71A } else { [string][char]0xE768 }
}
function Update-Ping {
    if (!$script:pingOn -or $script:pingBusy -or (Get-Date) -lt $script:pingNext -or $script:page -ne 'boost') { return }
    $script:pingBusy = $true
    Start-Work $pingWork @(, @($pingTargets | ForEach-Object { @{ Key = $_.Key; Host = $_.Host } })) {
        param($r, $ctx)
        $script:pingBusy = $false; $script:pingNext = (Get-Date).AddSeconds(2)
        $res = Get-LastOutput $r
        foreach ($t in $pingTargets) {
            $ms = if ($res) { [int]$res[$t.Key] } else { -1 }
            [void]$t.History.Add($ms)
            while ($t.History.Count -gt 30) { $t.History.RemoveAt(0) }
            if ($ms -ge 0) {
                $t.Value.Text = "$ms ms"
                $t.Value.Foreground = if ($ms -lt 60) { $window.FindResource('Good') } elseif ($ms -lt 120) { '#F2C55C' } else { '#F2557A' }
            } else { $t.Value.Text = T 'ping.timeout'; $t.Value.Foreground = $window.FindResource('MutedBrush') }
            $valid = @($t.History | Where-Object { $_ -ge 0 })
            $max = [Math]::Max(50, ($valid | Measure-Object -Maximum).Maximum)
            $points = New-Object System.Windows.Media.PointCollection
            for ($i = 0; $i -lt $t.History.Count; $i++) {
                $v = $t.History[$i]; if ($v -lt 0) { $v = $max }
                $points.Add((New-Object System.Windows.Point ($i * 160 / 29), (28 - 26 * $v / $max)))
            }
            $t.Line.Points = $points
        }
    }
}
$ui.PingButton.Add_Click({ $script:pingOn = !$script:pingOn; $script:pingNext = [datetime]::MinValue; Set-PingButton; if (!$script:pingOn) { Set-Status (T 'ready') } })

# Startup apps, like the Startup tab of Task Manager: Windows keeps the on/off state in the
# StartupApproved keys (first byte even = on, odd = off) and never changes the Run entries themselves.
$approvedRoot = 'Software\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved'
function Get-StartupItems {
    $items = @()
    $sources = @(
        @{ Hive = 'HKCU'; Run = 'Software\Microsoft\Windows\CurrentVersion\Run'; Approved = 'Run' }
        @{ Hive = 'HKLM'; Run = 'Software\Microsoft\Windows\CurrentVersion\Run'; Approved = 'Run' }
        @{ Hive = 'HKLM'; Run = 'Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Run'; Approved = 'Run32' }
    )
    foreach ($src in $sources) {
        $key = Get-Item -Path "$($src.Hive):\$($src.Run)" -ErrorAction SilentlyContinue
        if (!$key) { continue }
        foreach ($name in $key.GetValueNames()) {
            if (!$name) { continue }
            $cmd = [string]$key.GetValue($name)
            $exe = if ($cmd -match '^\s*"([^"]+)"') { $Matches[1] } elseif ($cmd -match '^\s*(\S+?\.exe)') { $Matches[1] } else { $cmd }
            $items += @{ Name = $name; Command = $cmd; Exe = [Environment]::ExpandEnvironmentVariables($exe); Approved = "$($src.Hive):\$approvedRoot\$($src.Approved)" }
        }
    }
    foreach ($src in @(@{ Dir = [Environment]::GetFolderPath('Startup'); Hive = 'HKCU' }, @{ Dir = [Environment]::GetFolderPath('CommonStartup'); Hive = 'HKLM' })) {
        foreach ($f in Get-ChildItem -LiteralPath $src.Dir -File -ErrorAction SilentlyContinue | Where-Object { $_.Name -ne 'desktop.ini' }) {
            $target = $f.FullName
            if ($f.Extension -eq '.lnk') { try { $target = (New-Object -ComObject WScript.Shell).CreateShortcut($f.FullName).TargetPath } catch { } }
            $items += @{ Name = $f.Name; Command = $f.FullName; Exe = $target; Approved = "$($src.Hive):\$approvedRoot\StartupFolder" }
        }
    }
    return $items
}
function Test-StartupOn($item) {
    $data = Get-RegValue $item.Approved $item.Name
    return !($data -is [byte[]] -and $data.Count -gt 0 -and ($data[0] -band 1))
}
function Set-StartupOn($item, [bool]$on) {
    if (!(Test-Path $item.Approved)) { New-Item -Path $item.Approved -Force | Out-Null }
    $data = New-Object byte[] 12
    if ($on) { $data[0] = 2 } else { $data[0] = 3; [BitConverter]::GetBytes([DateTime]::Now.ToFileTime()).CopyTo($data, 4) }
    Set-ItemProperty -Path $item.Approved -Name $item.Name -Value $data -Type Binary
}
function Show-StartupItems {
    $ui.StartupList.Children.Clear()
    $items = @(Get-StartupItems | Sort-Object { $_.Name })
    $ui.StartupEmpty.Visibility = if ($items.Count) { 'Collapsed' } else { 'Visible' }
    foreach ($item in $items) {
        $toggle = New-Object System.Windows.Controls.CheckBox
        $toggle.Style = $window.FindResource('Switch')
        $toggle.IsChecked = Test-StartupOn $item
        $toggle.Tag = $item
        $toggle.Add_Click({
            $i = $this.Tag
            try { Set-StartupOn $i ([bool]$this.IsChecked); Set-Status ((T $(if ($this.IsChecked) { 'status.startupon' } else { 'status.startupoff' })) -f $i.Name) }
            catch { Set-Status $_.Exception.Message; $this.IsChecked = Test-StartupOn $i }
        })
        $row = New-Row ([string][char]0xE7B5) ($item.Name -replace '\.lnk$', '') $null $toggle $null
        $row.Sub.Text = $item.Command
        $row.Sub.TextTrimming = 'CharacterEllipsis'; $row.Sub.TextWrapping = 'NoWrap'
        Set-RowIcon $row (Get-FileIcon @($item.Exe))
        [void]$ui.StartupList.Children.Add($row.Row)
    }
    Update-Separators $ui.StartupList
}
# Background tasks: scheduled tasks of other apps (not Windows, Akati OS or AtlasOS), mostly updaters that start
# by themselves. Read in the background when the page first opens (the Task Scheduler module is slow to load).
$bgTaskWork = {
    $windows = [Environment]::GetFolderPath('Windows')
    @(Get-ScheduledTask -ErrorAction SilentlyContinue | Where-Object {
        $_.TaskPath -notlike '\Microsoft\*' -and $_.TaskPath -notlike '\AkatiOS\*' -and $_.TaskName -notmatch 'Atlas|Akati|Timer Resolution' } | ForEach-Object {
        $exe = [string]@($_.Actions | Where-Object { $_.Execute } | Select-Object -First 1 -ExpandProperty Execute)
        $exe = [Environment]::ExpandEnvironmentVariables($exe.Trim('"'))
        # Programs in the Windows folder belong to Windows
        if ($exe -and $exe -notlike "$windows\*") {
            @{ Name = $_.TaskName; Path = $_.TaskPath; Exe = $exe; On = [string]$_.State -ne 'Disabled' }
        } })
}
function Show-BgTasks($list) {
    $ui.BgTaskList.Children.Clear()
    $list = @($list | Where-Object { $_ -is [hashtable] } | Sort-Object { $_.Name })
    $ui.BgTaskEmpty.Tag = 't:bgtasks.empty'; $ui.BgTaskEmpty.Text = T 'bgtasks.empty'
    $ui.BgTaskEmpty.Visibility = if ($list.Count) { 'Collapsed' } else { 'Visible' }
    foreach ($item in $list) {
        $toggle = New-Object System.Windows.Controls.CheckBox
        $toggle.Style = $window.FindResource('Switch')
        $toggle.IsChecked = $item.On
        $toggle.Tag = $item
        $toggle.Add_Click({
            $i = $this.Tag; $on = [bool]$this.IsChecked
            $this.IsEnabled = $false
            Start-Work { param($path, $name, $on)
                try {
                    if ($on) { Enable-ScheduledTask -TaskPath $path -TaskName $name -ErrorAction Stop | Out-Null } else { Disable-ScheduledTask -TaskPath $path -TaskName $name -ErrorAction Stop | Out-Null }
                    [string](Get-ScheduledTask -TaskPath $path -TaskName $name).State -ne 'Disabled'
                } catch { $_.Exception.Message } } @($i.Path, $i.Name, $on) {
                param($r, $ctx)
                $res = Get-LastOutput $r
                $ctx.Toggle.IsEnabled = $true
                if ($res -is [bool]) {
                    $ctx.Toggle.IsChecked = $res
                    Set-Status ((T $(if ($res) { 'status.taskon' } else { 'status.taskoff' })) -f $ctx.Item.Name)
                } else { $ctx.Toggle.IsChecked = !$ctx.On; Set-Status "$($ctx.Item.Name): $res" }
            } @{ Toggle = $this; Item = $i; On = $on }
        })
        $row = New-Row ([string][char]0xE823) $item.Name $null $toggle $null
        $row.Sub.Text = $item.Exe
        $row.Sub.TextTrimming = 'CharacterEllipsis'; $row.Sub.TextWrapping = 'NoWrap'
        Set-RowIcon $row (Get-FileIcon @($item.Exe))
        [void]$ui.BgTaskList.Children.Add($row.Row)
    }
    Update-Separators $ui.BgTaskList
}
function Start-BgTasks {
    if ($Screenshot) {
        # Sample tasks: the CI runner has its own (Azure) tasks
        Show-BgTasks @(@{ Name = 'GoogleUpdateTaskMachineCore'; Path = '\'; Exe = "${env:ProgramFiles(x86)}\Google\Update\GoogleUpdate.exe"; On = $true }
                       @{ Name = 'MicrosoftEdgeUpdateTaskMachineUA'; Path = '\'; Exe = "${env:ProgramFiles(x86)}\Microsoft\EdgeUpdate\MicrosoftEdgeUpdate.exe"; On = $false })
        return
    }
    Start-Work $bgTaskWork @() { param($r) Show-BgTasks @($r) } $null
}

# The startup apps are read when the page first opens (the shortcuts are slow to read)
if ($Screenshot) { $script:startupShown = $true; Show-StartupItems; Start-BgTasks }
Update-BoostCard
Update-Separators $ui.PingList

