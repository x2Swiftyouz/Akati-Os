<#
.SYNOPSIS
    Akati OS Center: Dashboard: system info, live usage, busiest apps, network, drives.
    Dot-sourced by AkatiCenter.ps1 (runs in its scope: $ui, $window, T and the other parts).
#>
# ---------------------------------------------------------------------------------------------
# Dashboard: system info and live usage
# ---------------------------------------------------------------------------------------------
Add-Mark 'Dashboard'


$akati = Get-ItemProperty -Path 'HKLM:\SOFTWARE\AkatiOS' -ErrorAction SilentlyContinue
$version = if ($akati.Version) { $akati.Version } else { 'v1.10.0' }
$build = [Environment]::OSVersion.Version.Build
$edition = if ($akati.Edition) { $akati.Edition } elseif ($build -ge 22000) { 'Windows 11' } else { 'Windows 10' }
$ui.VersionBig.Text = $version
$ui.EditionText.Text = $edition
$ui.AboutVersion.Text = "$version  ·  $edition"
$ui.FooterVersion.Text = "Akati OS $version"
$ui.PcName.Text = $env:COMPUTERNAME

# Windows, CPU, graphics card and RAM: read in the background (the first WMI query takes about a second)
$specWork = {
    $r = @{}
    try {
        $os = Get-CimInstance Win32_OperatingSystem
        $cv = Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion'
        $r.Os = "$($os.Caption)  ·  $($cv.DisplayVersion)  ·  Build $($cv.CurrentBuild).$($cv.UBR)"
        $r.Ram = [double]$os.TotalVisibleMemorySize * 1KB
        $r.Cpu = ((Get-CimInstance Win32_Processor | Select-Object -First 1).Name -replace '\s+', ' ').Trim()
        $all = @(Get-CimInstance Win32_VideoController)
        $gpu = @($all | Where-Object { $_.Name -notmatch 'Basic Display|Remote' } | Select-Object -First 1)
        $r.Gpu = if ($gpu.Count) { $gpu[0].Name } else { @($all | Select-Object -First 1)[0].Name }
    } catch { }
    $r
}
function Show-Specs($r) {
    if ($r -isnot [hashtable]) { return }
    if ($r.Os) { $ui.OsLine.Text = $r.Os }
    if ($r.Cpu) { $ui.CpuName.Text = $r.Cpu }
    if ($r.Gpu) { $ui.GpuName.Text = $r.Gpu }
    if ($r.Ram) { $ui.RamName.Text = Format-Size $r.Ram }
}
if ($Screenshot) { Show-Specs (& $specWork) } else { Start-Work $specWork @() { param($r) Show-Specs (Get-LastOutput $r) } $null }

# Storage: every local drive with a bar
function Show-Disks {
    $ui.DisksPanel.Children.Clear()
    # .NET instead of Win32_LogicalDisk: on some trimmed Windows builds (imOS) WMI returns drives without a size
    foreach ($d in @([IO.DriveInfo]::GetDrives() | Where-Object { $_.DriveType -eq 'Fixed' -and $_.IsReady } | Sort-Object Name)) {
        if (!$d.TotalSize) { continue }
        $used = 100 * ($d.TotalSize - $d.TotalFreeSpace) / $d.TotalSize
        $row = New-Object System.Windows.Controls.StackPanel
        $row.Margin = '0,0,0,10'
        $top = New-Object System.Windows.Controls.Grid
        $name = New-Text ("$($d.Name.TrimEnd('\'))  " + $(if ($d.VolumeLabel) { $d.VolumeLabel } else { T 'disk.local' })) 13 'SemiBold'
        $free = New-Text ((T 'disk.free') -f (Format-Size $d.TotalFreeSpace), (Format-Size $d.TotalSize)) 12
        $free.Foreground = $window.FindResource('MutedBrush'); $free.HorizontalAlignment = 'Right'
        [void]$top.Children.Add($name); [void]$top.Children.Add($free)
        $bar = New-Object System.Windows.Controls.ProgressBar
        $bar.Style = $window.FindResource('Meter'); $bar.Margin = '0,6,0,0'; $bar.Value = $used
        if ($used -ge 90) { $bar.Foreground = '#FF453A' }
        [void]$row.Children.Add($top); [void]$row.Children.Add($bar)
        # Less than 15% free: a shortcut to the Cleaner
        if ($d.TotalFreeSpace / $d.TotalSize -lt 0.15) {
            $clean = New-Object System.Windows.Controls.Button
            $clean.Style = $window.FindResource('Pill'); $clean.Content = T 'disk.clean'; $clean.HorizontalAlignment = 'Left'; $clean.Margin = '0,8,0,0'
            $clean.Add_Click({ $ui.NavCleaner.IsChecked = $true })
            [void]$row.Children.Add($clean)
        }
        [void]$ui.DisksPanel.Children.Add($row)
    }
}

# Usage is read in a background runspace so the window never stutters
$stats = [hashtable]::Synchronized(@{ Cpu = 0; Ram = 0; RamUsed = 0; RamTotal = 0; Gpu = -1; CpuTemp = -1; GpuTemp = -1; Run = $true; N = 0; Seq = 0
    Down = -1; Up = -1; Ping = -1; Top = $null; TopSeq = 0; Defender = -1; Boot = $null; Self = $PID })
$statsSample = {
    param($stats)
        $n = $stats.N; $stats.N = $n + 1
        try {
            $stats.Cpu = [int](Get-CimInstance Win32_PerfFormattedData_PerfOS_Processor -Filter "Name='_Total'").PercentProcessorTime
            $os = Get-CimInstance Win32_OperatingSystem
            $stats.RamTotal = [double]$os.TotalVisibleMemorySize * 1KB
            $stats.RamUsed = $stats.RamTotal - [double]$os.FreePhysicalMemory * 1KB
            $stats.Ram = [int](100 * $stats.RamUsed / $stats.RamTotal)
        } catch { }
        try {
            $engines = Get-CimInstance Win32_PerfFormattedData_GPUPerformanceCounters_GPUEngine -ErrorAction Stop |
                Where-Object { $_.Name -like '*engtype_3D*' }
            $sum = ($engines | Measure-Object -Property UtilizationPercentage -Sum).Sum
            $stats.Gpu = [int][Math]::Min(100, [double]$sum)
        } catch { $stats.Gpu = -1 }
        # Network speed (all adapters)
        try {
            $nics = @(Get-CimInstance Win32_PerfFormattedData_Tcpip_NetworkInterface -ErrorAction Stop)
            $stats.Down = [double]($nics | Measure-Object -Property BytesReceivedPersec -Sum).Sum
            $stats.Up = [double]($nics | Measure-Object -Property BytesSentPersec -Sum).Sum
        } catch { }
        # The apps using the most CPU, every 3rd sample
        if ($n % 3 -eq 0) {
            try {
                $cores = [Environment]::ProcessorCount
                # Processes with the same name are added together, like the groups in Task Manager
                $groups = Get-CimInstance Win32_PerfFormattedData_PerfProc_Process -ErrorAction Stop |
                    Where-Object { $_.Name -notin '_Total', 'Idle', 'System', 'Memory Compression', 'Registry' -and $_.IDProcess -gt 4 } |
                    Group-Object { $_.Name -replace '#\d+$', '' } | ForEach-Object {
                        @{ Name = $_.Name; Pids = @($_.Group | ForEach-Object { [int]$_.IDProcess })
                           Cpu = [double]($_.Group | Measure-Object -Property PercentProcessorTime -Sum).Sum
                           Ram = [double]($_.Group | Measure-Object -Property WorkingSetPrivate -Sum).Sum }
                    }
                foreach ($g in $groups) { $g.Cpu = [Math]::Round($g.Cpu / $cores, 1) }
                # Two lists: by CPU and by memory (the page shows one of them)
                $byCpu = @($groups | Sort-Object { $_.Cpu }, { $_.Ram } -Descending | Select-Object -First 5)
                $byRam = @($groups | Sort-Object { $_.Ram } -Descending | Select-Object -First 5)
                foreach ($g in @($byCpu + $byRam)) {
                    if (!$g.ContainsKey('Path')) { $g.Path = try { (Get-Process -Id $g.Pids[0] -ErrorAction Stop).Path } catch { $null } }
                }
                $stats.TopRam = $byRam
                $stats.Top = $byCpu
                $stats.TopSeq++
            } catch { }
        }
        # Ping to Singapore every 6th sample (TCP connect, like Game boost)
        if ($n % 6 -eq 0) {
            $ms = -1
            try {
                $ip = [Net.Dns]::GetHostAddresses('dynamodb.ap-southeast-1.amazonaws.com') | Where-Object { $_.AddressFamily -eq 'InterNetwork' } | Select-Object -First 1
                $c = New-Object Net.Sockets.TcpClient; $sw = [Diagnostics.Stopwatch]::StartNew()
                if ($c.ConnectAsync($ip, 443).Wait(2000) -and $c.Connected) { $ms = [int]$sw.Elapsed.TotalMilliseconds }
                $c.Close()
            } catch { }
            $stats.Ping = $ms
        }
        # Temperatures every 5th sample: the NVIDIA driver tool and the ACPI thermal zone. Many PCs report
        # no zone; no extra driver is installed for this (anti-cheats block the usual sensor drivers)
        if ($n % 5 -eq 0) {
            $gpuTemp = -1
            foreach ($smi in "$env:windir\System32\nvidia-smi.exe", "$env:ProgramFiles\NVIDIA Corporation\NVSMI\nvidia-smi.exe") {
                if (Test-Path $smi) { try { $gpuTemp = [int](@(& $smi --query-gpu=temperature.gpu --format=csv,noheader,nounits)[0]) } catch { }; break }
            }
            $stats.GpuTemp = $gpuTemp
            try {
                $zones = @(Get-CimInstance -Namespace 'root/wmi' -ClassName MSAcpi_ThermalZoneTemperature -ErrorAction Stop |
                    ForEach-Object { $_.CurrentTemperature / 10 - 273.15 } | Where-Object { $_ -gt 5 -and $_ -lt 125 })
                $stats.CpuTemp = if ($zones.Count) { [int]($zones | Measure-Object -Maximum).Maximum } else { -1 }
            } catch { $stats.CpuTemp = -1 }
        }
        if ($n -eq 0) {
            try { $stats.Boot = (Get-CimInstance Win32_OperatingSystem).LastBootUpTime } catch { }
            try { $stats.Defender = if ((Get-MpComputerStatus -ErrorAction Stop).RealTimeProtectionEnabled) { 1 } else { 0 } } catch { $stats.Defender = 0 }
        }
        $stats.Seq++
}
$statsWork = "param(`$stats)`n`$sample = {$statsSample}`nwhile (`$stats.Run) { & `$sample `$stats; Start-Sleep -Milliseconds 1500 }"
$statsPs = [PowerShell]::Create()
[void]$statsPs.AddScript($statsWork).AddArgument($stats)

# Last 60 seconds of usage (40 samples of 1.5 s), drawn as a line in each card
$script:history = @{ Cpu = New-Object System.Collections.ArrayList; Ram = New-Object System.Collections.ArrayList; Gpu = New-Object System.Collections.ArrayList }
$script:lastSeq = -1; $script:lastTopSeq = -1; $script:chipsAt = [datetime]::MinValue
function Update-Spark([string]$key, [double]$value) {
    $h = $script:history[$key]
    [void]$h.Add([Math]::Max(0, [Math]::Min(100, $value)))
    while ($h.Count -gt 40) { $h.RemoveAt(0) }
    Show-Spark $key
}
function Show-Spark([string]$key) {
    $h = $script:history[$key]
    $canvas = $ui["${key}Spark"]
    $w = if ($canvas.ActualWidth -gt 0) { $canvas.ActualWidth } else { 220 }
    $pts = New-Object System.Windows.Media.PointCollection
    for ($i = 0; $i -lt $h.Count; $i++) { $pts.Add((New-Object System.Windows.Point ($w - ($h.Count - 1 - $i) * $w / 39), (36 - 34 * $h[$i] / 100))) }
    $ui["${key}Line"].Points = $pts
    # The area under the line, filled with the accent color (see-through)
    $area = New-Object System.Windows.Media.PointCollection
    if ($pts.Count) {
        foreach ($pt in $pts) { $area.Add($pt) }
        $area.Add((New-Object System.Windows.Point $pts[$pts.Count - 1].X, 38)); $area.Add((New-Object System.Windows.Point $pts[0].X, 38))
    }
    $ui["${key}Fill"].Points = $area
}
# Drawn again for the new width when the window is resized (and at the first layout)
foreach ($k in 'Cpu', 'Ram', 'Gpu') { $ui["${k}Spark"].Add_SizeChanged({ Show-Spark $this.Name.Substring(0, 3) }) }

function Format-Speed([double]$bytesPerSec) {
    if ($bytesPerSec -lt 0) { return '-' }
    $bits = $bytesPerSec * 8
    if ($bits -ge 1e6) { return '{0:N1} Mb/s' -f ($bits / 1e6) }
    return '{0:N0} Kb/s' -f ($bits / 1e3)
}

function Update-Stats {
    if (!(Test-Counting $ui.CpuValue)) { $ui.CpuValue.Text = "$($stats.Cpu)%" }; $ui.CpuBar.Value = $stats.Cpu
    if (!(Test-Counting $ui.RamValue)) { $ui.RamValue.Text = "$($stats.Ram)%" }; $ui.RamBar.Value = $stats.Ram
    if ($stats.RamTotal) { $ui.RamDetail.Text = '{0} / {1}' -f (Format-Size $stats.RamUsed), (Format-Size $stats.RamTotal) }
    if ($stats.Gpu -ge 0) { if (!(Test-Counting $ui.GpuValue)) { $ui.GpuValue.Text = "$($stats.Gpu)%" }; $ui.GpuBar.Value = $stats.Gpu } else { $ui.GpuValue.Text = '-'; $ui.GpuBar.Value = 0 }
    Set-Level $ui.CpuValue $ui.CpuBar $stats.Cpu
    Set-Level $ui.RamValue $ui.RamBar $stats.Ram
    Set-Level $ui.GpuValue $ui.GpuBar ([Math]::Max(0, $stats.Gpu))
    # No graphics card that Windows reports usage for (virtual machines): CPU and RAM share the row
    $gpuShown = $stats.Gpu -ge 0 -and @($gpuNames).Count -gt 0
    $ui.GpuCard.Visibility = if ($gpuShown) { 'Visible' } else { 'Collapsed' }
    $ui.UsageGrid.Columns = if ($gpuShown) { 3 } else { 2 }
    if ($stats.Seq -ne $script:lastSeq) {
        $script:lastSeq = $stats.Seq
        Update-Spark 'Cpu' $stats.Cpu; Update-Spark 'Ram' $stats.Ram; Update-Spark 'Gpu' ([Math]::Max(0, $stats.Gpu))
        $ui.NetDown.Text = Format-Speed $stats.Down
        $ui.NetUp.Text = Format-Speed $stats.Up
        if ($stats.Ping -ge 0) {
            $ui.NetPing.Text = "$($stats.Ping) ms"
            $ui.NetPing.Foreground = if ($stats.Ping -lt 60) { $window.FindResource('Good') } elseif ($stats.Ping -lt 120) { '#F2C55C' } else { '#F2557A' }
        } else { $ui.NetPing.Text = '-' }
    }
    if ($stats.TopSeq -ne $script:lastTopSeq -and $stats.Top) { $script:lastTopSeq = $stats.TopSeq; Show-TopApps }
    Update-Clock
    if ((Get-Date) -gt $script:chipsAt) { $script:chipsAt = (Get-Date).AddSeconds(10); Update-Chips }
    if ((Get-Date) -gt $script:netInfoAt) { $script:netInfoAt = (Get-Date).AddSeconds(60); Start-NetInfo }
}

# Orange from 85%, red from 95% (the number and the bar)
function Set-Level($text, $bar, [double]$value) {
    $color = if ($value -ge 95) { '#FF453A' } elseif ($value -ge 85) { '#FF9F0A' } else { $null }
    if ($color) { $text.Foreground = $color; $bar.Foreground = $color }
    else { $text.ClearValue([System.Windows.Controls.TextBlock]::ForegroundProperty); $bar.ClearValue([System.Windows.Controls.Control]::ForegroundProperty) }
}

# Greeting and clock like macOS
function Update-Clock {
    $now = Get-Date
    $h = $now.Hour
    $ui.Greeting.Text = T $(if ($h -ge 5 -and $h -lt 12) { 'greet.morning' } elseif ($h -lt 17 -and $h -ge 12) { 'greet.afternoon' } elseif ($h -ge 17 -and $h -lt 21) { 'greet.evening' } else { 'greet.night' })
    $ui.ClockTime.Text = $now.ToString('HH:mm')
    $culture = (Get-LangCulture)
    $ui.ClockDate.Text = $now.ToString('ddd d MMMM', $culture)
}

# Network card: the connected adapter (Wi-Fi or Ethernet), its link speed and IP address, read in the background
function Start-NetInfo {
    Start-Work {
        $a = Get-NetAdapter -Physical -ErrorAction SilentlyContinue | Where-Object Status -eq 'Up' | Sort-Object { $_.NdisPhysicalMedium -ne 9 } | Select-Object -First 1
        if (!$a) { return '' }
        $kind = if ($a.NdisPhysicalMedium -eq 9 -or $a.PhysicalMediaType -match '802\.11') { 'Wi-Fi' } else { 'Ethernet' }
        $ip = (Get-NetIPAddress -InterfaceIndex $a.ifIndex -AddressFamily IPv4 -ErrorAction SilentlyContinue | Select-Object -First 1).IPAddress
        (@($kind, $a.LinkSpeed, $ip) | Where-Object { $_ }) -join ' · '
    } @() { param($r, $c) $ui.NetInfo.Text = [string](Get-LastOutput $r) } $null
}

# Status chips: Game boost, power plan, Defender, time since start
function New-Chip([string]$text, $dot) {
    $b = New-Object System.Windows.Controls.Border
    $b.CornerRadius = 12; $b.SetResourceReference([System.Windows.Controls.Border]::BackgroundProperty, 'Field'); $b.Padding = '10,4'; $b.Margin = '0,0,8,6'
    $sp = New-Object System.Windows.Controls.StackPanel; $sp.Orientation = 'Horizontal'
    $e = New-Object System.Windows.Shapes.Ellipse; $e.Width = 7; $e.Height = 7; $e.Margin = '0,0,7,0'; $e.VerticalAlignment = 'Center'; $e.Fill = $dot
    $t = New-Text $text 12
    [void]$sp.Children.Add($e); [void]$sp.Children.Add($t)
    $b.Child = $sp
    return $b
}
function Update-Chips {
    $ui.StatusChips.Children.Clear()
    $good = $window.FindResource('Good'); $muted = $window.FindResource('MutedBrush')
    $boost = Test-Boost
    [void]$ui.StatusChips.Children.Add((New-Chip (T $(if ($boost) { 'chip.boost.on' } else { 'chip.boost.off' })) $(if ($boost) { $good } else { $muted })))
    $plan = if ([string](powercfg /getactivescheme) -match '\((.+)\)\s*$') { $Matches[1] } else { '-' }
    [void]$ui.StatusChips.Children.Add((New-Chip ((T 'chip.power') -f $plan) $window.FindResource('Accent2')))
    # Screen refresh rate, orange when the screen can do more
    if ($script:screenNow -gt 1) {
        if ($script:screenMax -gt $script:screenNow) { [void]$ui.StatusChips.Children.Add((New-Chip ((T 'chip.hzlow') -f $script:screenNow, $script:screenMax) '#FF9F0A')) }
        else { [void]$ui.StatusChips.Children.Add((New-Chip ((T 'chip.hz') -f $script:screenNow) $muted)) }
    }
    if ($stats.Defender -ge 0) {
        [void]$ui.StatusChips.Children.Add((New-Chip (T $(if ($stats.Defender -eq 1) { 'chip.defender.on' } else { 'chip.defender.off' })) $(if ($stats.Defender -eq 1) { $good } else { '#FF9F0A' })))
    }
    if ($script:doctorResult -is [hashtable]) {
        $sc = Get-AkatiScore
        $chip = New-Chip ((T 'chip.score') -f $sc.Score) (Get-ScoreBrush $sc.Score)
        $chip.Cursor = 'Hand'; $chip.ToolTip = T 'nav.health'
        $chip.Add_MouseLeftButtonUp({ $ui.NavHealth.IsChecked = $true })
        [void]$ui.StatusChips.Children.Add($chip)
    }
    # Orange from 80 °C, red from 90 °C
    foreach ($tp in @(@('chip.temp.sys', $stats.CpuTemp), @('chip.temp.gpu', $stats.GpuTemp))) {
        if ($tp[1] -gt 0) { [void]$ui.StatusChips.Children.Add((New-Chip ((T $tp[0]) -f $tp[1]) $(if ($tp[1] -ge 90) { '#FF453A' } elseif ($tp[1] -ge 80) { '#FF9F0A' } else { $muted }))) }
    }
    if ($ui.PageHealth.Visibility -eq 'Visible') { Update-TempText }
    if ($stats.Boot) {
        $up = (Get-Date) - $stats.Boot
        $text = if ($up.TotalDays -ge 1) { (T 'chip.days') -f [int][Math]::Floor($up.TotalDays), $up.Hours } else { (T 'chip.hours') -f $up.Hours, $up.Minutes }
        [void]$ui.StatusChips.Children.Add((New-Chip ((T 'chip.uptime') -f $text) $muted))
    }
}

# The apps using the most CPU, with Quit (not for Windows itself or this window)
$protected = 'csrss', 'wininit', 'winlogon', 'services', 'lsass', 'smss', 'svchost', 'dwm', 'explorer', 'MsMpEng', 'fontdrvhost', 'sihost', 'ctfmon', 'audiodg', 'spoolsv', 'SecurityHealthService', 'NisSrv', 'conhost', 'WmiPrvSE', 'RuntimeBroker', 'taskhostw', 'dllhost', 'StartMenuExperienceHost', 'SearchHost', 'TextInputHost', 'ShellExperienceHost', 'vmtoolsd', 'vm3dservice'
$script:iconCache = @{}
function Show-TopApps {
    $ui.TopList.Children.Clear()
    $list = if ($ui.TopByRam.IsChecked) { $stats.TopRam } else { $stats.Top }
    foreach ($p in @($list)) {
        if (!$p) { continue }
        $right = New-Object System.Windows.Controls.StackPanel; $right.Orientation = 'Horizontal'
        $cpu = New-Text ('{0:N1}%' -f $p.Cpu) 13 'SemiBold'; $cpu.MinWidth = 60; $cpu.TextAlignment = 'Right'; $cpu.VerticalAlignment = 'Center'
        $ram = New-Text (Format-Size $p.Ram) 12; $ram.Foreground = $window.FindResource('MutedBrush'); $ram.MinWidth = 70; $ram.TextAlignment = 'Right'; $ram.VerticalAlignment = 'Center'; $ram.Margin = '0,0,14,0'
        [void]$right.Children.Add($ram); [void]$right.Children.Add($cpu)
        if ($p.Pids -notcontains $stats.Self -and $p.Name -notin $protected) {
            $btn = New-Object System.Windows.Controls.Button
            $btn.Style = $window.FindResource('Secondary'); $btn.Margin = '14,0,0,0'; $btn.Content = T 'top.end'; $btn.Tag = $p
            $btn.Add_Click({
                $t = $this.Tag
                $answer = [System.Windows.MessageBox]::Show(((T 'top.confirm') -f $t.Name), 'Akati OS Center', 'YesNo', 'Question')
                if ($answer -eq 'Yes') {
                    try { Stop-Process -Id $t.Pids -Force -ErrorAction Stop; Set-Status ((T 'status.ended') -f $t.Name) } catch { Set-Status $_.Exception.Message }
                }
            })
            [void]$right.Children.Add($btn)
        } else {
            $spacer = New-Object System.Windows.Controls.Border; $spacer.Width = 76
            [void]$right.Children.Add($spacer)
        }
        # This window runs in powershell.exe: show it by its own name and logo
        $self = $p.Pids -contains $stats.Self
        $label = if ($self) { T 'top.self' } elseif ($p.Pids.Count -gt 1) { '{0} ({1})' -f $p.Name, $p.Pids.Count } else { $p.Name }
        $row = New-Row ([string][char]0xE7C4) $label $null $right $null
        $row.Sub.Visibility = 'Collapsed'
        if ($self) {
            if (!$script:selfIcon) { $script:selfIcon = Get-Image $logoPath 64 }
            Set-RowIcon $row $script:selfIcon
        } elseif ($p.Path) {
            if (!$script:iconCache.ContainsKey($p.Path)) { $script:iconCache[$p.Path] = Get-FileIcon @($p.Path) }
            Set-RowIcon $row $script:iconCache[$p.Path]
        }
        [void]$ui.TopList.Children.Add($row.Row)
    }
    Update-Separators $ui.TopList
}

$ui.TopByCpu.Add_Checked({ Show-TopApps })
$ui.TopByRam.Add_Checked({ Show-TopApps })

# Desktop right-click menu (AkatiMenu.ps1): rebuilt shortly after something it shows changed
$menuScript = Join-Path $appDir 'AkatiMenu.ps1'
$menuKey = 'HKLM:\SOFTWARE\Classes\DesktopBackground\Shell\AkatiOS'
function Request-MenuUpdate { $script:menuAt = (Get-Date).AddSeconds(1) }
function Update-DesktopMenu {
    $script:menuAt = $null
    if ($Screenshot -or !(Test-Path $menuKey) -or !(Test-Path $menuScript)) { return }
    # "My apps": installed gaming apps as "name|command|icon"
    $list = @(foreach ($a in $apps) {
        if (!(Test-App $a)) { continue }
        $exe = Get-AppExe $a
        if (!$exe) { continue }
        # Discord moves to a new app-<version> folder with each update; its own launcher always works
        $command = if ($a.Key -eq 'Discord') { "`"$env:LOCALAPPDATA\Discord\Update.exe`" --processStart Discord.exe" } else { "`"$exe`"" }
        '{0}|{1}|{2}' -f $a.Name, $command, $exe
    })
    $centerKey = 'HKCU:\Software\AkatiOS\Center'
    if (!(Test-Path $centerKey)) { New-Item -Path $centerKey -Force | Out-Null }
    Set-ItemProperty -Path $centerKey -Name MenuApps -Value ([string[]]$list) -Type MultiString
    Start-Process powershell.exe -ArgumentList "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$menuScript`" -Install" -WindowStyle Hidden
}

# ---------------------------------------------------------------------------------------------
# Customize dashboard: each card can be hidden and moved. Saved as DashLayout, for example
# "usage,hero,-chips,..." (a "-" in front = hidden); cards missing from it (new ones) go last.
# ---------------------------------------------------------------------------------------------
$dashCards = [ordered]@{ hero = 'DashHero'; chips = 'StatusChips'; specs = 'DashSpecs'; usage = 'UsageGrid'; storage = 'DashStorage'; top = 'DashTop'; week = 'DashWeek'; quick = 'DashQuick' }
$dashGlyphs = @{ hero = [char]0xE80F; chips = [char]0xE8FD; specs = [char]0xE950; usage = [char]0xE9D9; storage = [char]0xEDA2; top = [char]0xE9F5; week = [char]0xE787; quick = [char]0xE945 }
function Get-DashLayout {
    $list = New-Object System.Collections.ArrayList
    foreach ($part in ([string](Get-RegValue $settingsKey 'DashLayout')).Split(',')) {
        $key = $part.Trim().TrimStart('-')
        if ($dashCards.Contains($key) -and !($list | Where-Object { $_.Key -eq $key })) { [void]$list.Add(@{ Key = $key; Shown = !$part.Trim().StartsWith('-') }) }
    }
    foreach ($key in $dashCards.Keys) { if (!($list | Where-Object { $_.Key -eq $key })) { [void]$list.Add(@{ Key = $key; Shown = $true }) } }
    return , $list
}
function Set-DashLayout($list, [switch]$Save) {
    # The cards first, in this order; the edit button and the editor stay after them
    for ($i = 0; $i -lt $list.Count; $i++) {
        $el = $ui[$dashCards[$list[$i].Key]]
        $ui.DashPanel.Children.Remove($el)
        $ui.DashPanel.Children.Insert($i, $el)
        $el.Visibility = if ($list[$i].Shown) { 'Visible' } else { 'Collapsed' }
    }
    if ($Save) { Save-Setting DashLayout (($list | ForEach-Object { $(if ($_.Shown) { '' } else { '-' }) + $_.Key }) -join ',') }
}
function Show-DashEditor {
    $list = Get-DashLayout
    $ui.DashEditList.Children.Clear()
    for ($i = 0; $i -lt $list.Count; $i++) {
        $item = $list[$i]
        $right = New-Object System.Windows.Controls.StackPanel
        $right.Orientation = 'Horizontal'
        foreach ($move in @(@{ Glyph = [char]0xE70E; By = -1 }, @{ Glyph = [char]0xE70D; By = 1 })) {
            $b = New-Object System.Windows.Controls.Button
            $b.Style = $window.FindResource('Pill'); $b.Padding = '9,5'; $b.Margin = '0,0,6,0'
            $g = New-Text ([string]$move.Glyph) 12; $g.Style = $window.FindResource('Glyph'); $b.Content = $g
            $b.Tag = @{ Index = $i; By = $move.By }
            $b.IsEnabled = ($i + $move.By) -ge 0 -and ($i + $move.By) -lt $list.Count
            $b.Add_Click({
                $l = Get-DashLayout; $a = $this.Tag.Index; $z = $a + $this.Tag.By
                $tmp = $l[$a]; $l[$a] = $l[$z]; $l[$z] = $tmp
                Set-DashLayout $l -Save; Show-DashEditor
            })
            [void]$right.Children.Add($b)
        }
        $sw = New-Object System.Windows.Controls.CheckBox
        $sw.Style = $window.FindResource('Switch'); $sw.Margin = '6,0,0,0'; $sw.IsChecked = $item.Shown; $sw.Tag = $item.Key
        $sw.Add_Click({
            $l = Get-DashLayout
            foreach ($x in $l) { if ($x.Key -eq $this.Tag) { $x.Shown = [bool]$this.IsChecked } }
            Set-DashLayout $l -Save
        })
        [void]$right.Children.Add($sw)
        $row = New-Row ([string]$dashGlyphs[$item.Key]) (T "dash.card.$($item.Key)") "t:dash.card.$($item.Key)" $right $null
        $row.Sub.Visibility = 'Collapsed'
        [void]$ui.DashEditList.Children.Add($row.Row)
    }
    Update-Separators $ui.DashEditList
}
$ui.DashEdit.Add_Click({ Show-DashEditor; $ui.DashEditor.Visibility = 'Visible'; $ui.DashEditBar.Visibility = 'Collapsed'; $ui.DashEditor.BringIntoView() })
$ui.DashDone.Add_Click({ $ui.DashEditor.Visibility = 'Collapsed'; $ui.DashEditBar.Visibility = 'Visible' })
$ui.DashReset.Add_Click({
    Remove-ItemProperty -Path $settingsKey -Name DashLayout -ErrorAction SilentlyContinue
    Set-DashLayout (Get-DashLayout); Show-DashEditor
})
if (!$Screenshot) { Set-DashLayout (Get-DashLayout) }

# ---------------------------------------------------------------------------------------------
# This week: cleaned (by hand and the weekly clean), Game boost time and the Akati Score since Monday.
# The totals are kept in WeekStart / WeekCleanBytes / WeekBoostMinutes / WeekBoosts (Add-WeekStat).
# Akati Score history: ScoreHistory, one "yyyy-MM-dd=score" per day (Update-ScoreHistory in logic.ps1).
# ---------------------------------------------------------------------------------------------
function Get-WeekNumber([string]$name) {
    if ((Get-RegValue $settingsKey 'WeekStart') -ne (Get-WeekStart (Get-Date))) { return 0 }
    $v = 0.0; [void][double]::TryParse([string](Get-RegValue $settingsKey $name), [Globalization.NumberStyles]::Float, [Globalization.CultureInfo]::InvariantCulture, [ref]$v)
    $v
}
function Get-ScoreDays {
    @(foreach ($e in @(Get-RegValue $settingsKey 'ScoreHistory')) {
        if ([string]$e -match '^(\d{4}-\d{2}-\d{2})=(\d+)$') { @{ Day = $Matches[1]; Score = [int]$Matches[2] } } })
}
function Update-Week {
    $monday = [datetime]::ParseExact((Get-WeekStart (Get-Date)), 'yyyy-MM-dd', [Globalization.CultureInfo]::InvariantCulture)
    $c = Get-LangCulture
    $ui.WeekRange.Text = '{0} - {1}' -f $monday.ToString('d MMM', $c), $monday.AddDays(6).ToString('d MMM', $c)
    $clean = Get-WeekNumber 'WeekCleanBytes'
    $ui.WeekClean.Text = if ($clean -gt 0) { Format-Size $clean } else { '0 MB' }
    $ui.WeekCleanSub.Text = T 'week.clean.d'
    $ui.WeekBoost.Text = Format-Minutes ([int](Get-WeekNumber 'WeekBoostMinutes'))
    $ui.WeekBoostSub.Text = (T 'week.boosts') -f [int](Get-WeekNumber 'WeekBoosts')
    $days = @(Get-ScoreDays)
    if (!$days.Count) { $ui.WeekScore.Text = '-'; $ui.WeekScoreSub.Text = T 'week.score.none'; return }
    $now = $days[-1].Score
    $ui.WeekScore.Text = [string]$now
    $ui.WeekScore.Foreground = Get-ScoreBrush $now
    # Compared with the last score before this week, or the first one of this week
    $weekStart = $monday.ToString('yyyy-MM-dd')
    $before = @($days | Where-Object { $_.Day -lt $weekStart })
    $base = if ($before.Count) { $before[-1].Score } else { $days[0].Score }
    $delta = $now - $base
    $ui.WeekScoreSub.Text = if ($delta -gt 0) { (T 'week.score.up') -f $delta } elseif ($delta -lt 0) { (T 'week.score.down') -f (-$delta) } else { T 'week.score.same' }
}
function Show-ScoreChart {
    $days = @(Get-ScoreDays)
    if ($days.Count -lt 2) { $ui.ScoreChartBox.Visibility = 'Collapsed'; return }
    $ui.ScoreChartBox.Visibility = 'Visible'
    $c = Get-LangCulture
    $first = [datetime]::ParseExact($days[0].Day, 'yyyy-MM-dd', [Globalization.CultureInfo]::InvariantCulture)
    $last = [datetime]::ParseExact($days[-1].Day, 'yyyy-MM-dd', [Globalization.CultureInfo]::InvariantCulture)
    $ui.ScoreChartRange.Text = '{0} - {1}' -f $first.ToString('d MMM', $c), $last.ToString('d MMM', $c)
    $w = $ui.ScoreChart.ActualWidth; if ($w -le 0) { $w = 300 }
    $h = 44
    $low = [Math]::Max(0, (($days | ForEach-Object { $_.Score } | Measure-Object -Minimum).Minimum) - 10)
    $line = New-Object System.Windows.Media.PointCollection
    for ($i = 0; $i -lt $days.Count; $i++) {
        $x = $i * $w / ($days.Count - 1)
        $y = 2 + ($h - 4) * (1 - ($days[$i].Score - $low) / [Math]::Max(1, 100 - $low))
        $line.Add((New-Object System.Windows.Point $x, $y))
    }
    $fill = New-Object System.Windows.Media.PointCollection
    foreach ($pt in $line) { $fill.Add($pt) }
    $fill.Add((New-Object System.Windows.Point $w, $h)); $fill.Add((New-Object System.Windows.Point 0, $h))
    $ui.ScoreLine.Points = $line; $ui.ScoreFill.Points = $fill
}
$ui.ScoreChart.Add_SizeChanged({ Show-ScoreChart })
# Called with each new score; saved once per change, so the registry is not written every second
function Save-ScoreDay([int]$score) {
    if ($Screenshot) { return }
    $day = (Get-Date).ToString('yyyy-MM-dd', [Globalization.CultureInfo]::InvariantCulture)
    if ($script:scoreSaved -eq "$day=$score") { return }
    $script:scoreSaved = "$day=$score"
    Save-Setting ScoreHistory (Update-ScoreHistory @(Get-RegValue $settingsKey 'ScoreHistory') $day $score)
    Show-ScoreChart; Update-Week
}
