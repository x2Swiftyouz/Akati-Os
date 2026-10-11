<#
.SYNOPSIS
    Akati OS Center: small functions without windows or registry, so tools/test-logic.ps1 can test them
    on any PowerShell (dot-sourced by AkatiCenter.ps1).
#>

# 1536 -> "2 KB", sizes in the units Windows Explorer shows
function Format-Size([double]$bytes) {
    if ($bytes -ge 1GB) { return '{0:N1} GB' -f ($bytes / 1GB) }
    if ($bytes -ge 1MB) { return '{0:N0} MB' -f ($bytes / 1MB) }
    if ($bytes -ge 1KB) { return '{0:N0} KB' -f ($bytes / 1KB) }
    return '0 KB'
}

# Accent colors from a hue (the accent from the wallpaper)
function ConvertFrom-Hsv([double]$h, [double]$s, [double]$v) {
    $c = $v * $s; $x = $c * (1 - [Math]::Abs((($h / 60) % 2) - 1)); $m = $v - $c
    $r, $g, $b = switch ([int][Math]::Floor($h / 60) % 6) { 0 { $c, $x, 0 } 1 { $x, $c, 0 } 2 { 0, $c, $x } 3 { 0, $x, $c } 4 { $x, 0, $c } default { $c, 0, $x } }
    '#{0:X2}{1:X2}{2:X2}' -f [int](($r + $m) * 255), [int](($g + $m) * 255), [int](($b + $m) * 255)
}
function New-HueAccent([double]$hue) {
    @{ Key = 'wallpaper'; Hue = $hue
       Base = ConvertFrom-Hsv $hue 0.7 0.84; Light = ConvertFrom-Hsv $hue 0.45 0.96
       G1 = ConvertFrom-Hsv $hue 0.62 0.94; G2 = ConvertFrom-Hsv $hue 0.74 0.78 }
}

# Ctrl+K: a word matches at the start of a word ("ram" finds "Free up RAM", not "frame"); Thai has no spaces
function Test-SpotWord([string]$text, [string]$word) {
    if ($word -match '[\u0E00-\u0E7F]') { return $text.Contains($word) }
    return $text -match ('(^|[^\p{L}\p{N}])' + [regex]::Escape($word))
}

# Akati Score (0-100): Akati Doctor 40, startup apps 15, memory in use 15, ping 15, free space 15.
# Returns the score and the text keys of what would raise it. Ping below 0 or missing: not measured.
function Get-ScorePoints([int]$issues, [int]$startup, [int]$ram, $ping, [int]$free) {
    $tips = New-Object System.Collections.ArrayList
    $score = [Math]::Max(0, 40 - 5 * $issues)
    if ($issues) { [void]$tips.Add('score.tip.doctor') }
    $score += if ($startup -le 3) { 15 } elseif ($startup -le 6) { 10 } elseif ($startup -le 10) { 5 } else { 0 }
    if ($startup -gt 3) { [void]$tips.Add('score.tip.startup') }
    $score += if ($ram -lt 50) { 15 } elseif ($ram -lt 70) { 10 } elseif ($ram -lt 85) { 5 } else { 0 }
    if ($ram -ge 50) { [void]$tips.Add('score.tip.ram') }
    $score += if ($null -eq $ping -or $ping -lt 0) { 8 } elseif ($ping -lt 40) { 15 } elseif ($ping -lt 80) { 10 } elseif ($ping -lt 150) { 5 } else { 0 }
    if ($ping -ge 40) { [void]$tips.Add('score.tip.ping') }
    $score += if ($free -ge 25) { 15 } elseif ($free -ge 10) { 8 } else { 0 }
    if ($free -lt 25) { [void]$tips.Add('score.tip.disk') }
    @{ Score = [int]$score; Tips = @($tips) }
}

# FPS test: frame times in ms -> average FPS and the 1% low (the 99th percentile frame time)
function Get-FpsStats([double[]]$frameTimes) {
    $ft = @($frameTimes | Where-Object { $_ -gt 0 -and $_ -lt 1000 })
    if ($ft.Count -lt 30) { return @{ Error = 'fps.nodata' } }
    $avgMs = ($ft | Measure-Object -Average).Average
    $sorted = @($ft | Sort-Object)
    $p99 = $sorted[[Math]::Min($sorted.Count - 1, [int][Math]::Floor($sorted.Count * 0.99))]
    @{ Avg = [int][Math]::Round(1000 / $avgMs); Low = [int][Math]::Round(1000 / $p99); Frames = $ft.Count }
}

# Weekly report: the Monday of the week of a date, as yyyy-MM-dd
function Get-WeekStart([datetime]$date) {
    $date.Date.AddDays(-(([int]$date.DayOfWeek + 6) % 7)).ToString('yyyy-MM-dd', [Globalization.CultureInfo]::InvariantCulture)
}

# Akati Score history: "yyyy-MM-dd=score" per day, the newest last, at most $keep days. A new score on the
# same day replaces that day's score.
function Update-ScoreHistory([string[]]$list, [string]$day, [int]$score, [int]$keep = 30) {
    $days = @($list | Where-Object { $_ -match '^\d{4}-\d{2}-\d{2}=\d+$' -and !$_.StartsWith("$day=") })
    $days = @($days + "$day=$score" | Sort-Object)
    if ($days.Count -gt $keep) { $days = $days[($days.Count - $keep)..($days.Count - 1)] }
    , [string[]]$days
}

# Interrupts: the modes a PCI device supports (DEVPKEY_PciDevice_InterruptSupport: 1 line-based, 2 MSI, 4 MSI-X)
function Get-IrqModes([int]$support) {
    $m = @(); if ($support -band 1) { $m += 'LB' }; if ($support -band 2) { $m += 'MSI' }; if ($support -band 4) { $m += 'MSI-X' }
    $m -join ', '
}
# CPU affinity mask (bit n = logical processor n) from a list of processors, and back
function ConvertTo-CpuMask([int[]]$cpus) { [uint64]$mask = 0; foreach ($c in $cpus) { if ($c -ge 0 -and $c -lt 64) { $mask = $mask -bor ([uint64]1 -shl $c) } }; $mask }
function ConvertFrom-CpuMask([uint64]$mask) { @(for ($i = 0; $i -lt 64; $i++) { if ($mask -band ([uint64]1 -shl $i)) { $i } }) }
# Core benchmark: the logical processors from best to worst score, without CPU 0 (Windows handles most of its own
# interrupts there). With Hyper-Threading two logical processors share a core (0-1, 2-3...): only the better one of
# each pair is kept, so two devices never land on the same physical core.
function Get-BestCores([double[]]$scores, [bool]$ht) {
    $order = @(0..($scores.Count - 1) | Sort-Object { - $scores[$_] }, { $_ })
    $used = @{}; $best = @()
    foreach ($c in $order) {
        if ($c -eq 0) { continue }
        $core = if ($ht) { [int][Math]::Floor($c / 2) } else { [int]$c }
        if ($ht -and $core -eq 0) { continue }
        if ($used.ContainsKey($core)) { continue }
        $used[$core] = $true; $best += $c
    }
    , [int[]]$best
}

# Win32PrioritySeparation: bits 4-5 the length of a CPU turn (1 long, 2 short, 0 or 3 the Windows default: short on
# Windows 10 and 11), bits 2-3 variable or fixed turns (1 variable, 2 fixed, 0 or 3 default: variable), bits 0-1 how
# much the window in front gets (0, 1, 2; 3 counts as 2): with variable turns its turns are 1, 2 or 3 times as long,
# and its threads get that much more priority when they wake up.
function Get-PrioritySeparation([int]$value) {
    $q = ($value -shr 4) -band 3; $k = ($value -shr 2) -band 3
    @{ Quantum = $(if ($q -eq 1) { 'long' } else { 'short' }); Fixed = $k -eq 2; Boost = [Math]::Min(2, $value -band 3) }
}

# Uninstaller: the name a program uses for its folders and registry keys, without the version, the edition in
# brackets and the bitness ("7-Zip 21.07 (x64 edition)" -> "7-Zip")
function Get-ProgramBaseName([string]$name) {
    $n = $name -replace '\s*\([^)]*\)', ''
    $n = $n -replace '\s+-?\s*v?\d+(\.\d+)+.*$', ''
    $n = $n -replace '\s+(x64|x86|64-bit|32-bit)$', ''
    $n.Trim().Trim('-').Trim()
}

# Disk health: the kind of a disk from Get-PhysicalDisk (names, or the numbers of MSFT_PhysicalDisk): NVMe by its
# bus (17), SSD (4) or HDD (3) by its media type, '' when Windows does not say
function Get-DiskKind($busType, $mediaType) {
    $bus = [string]$busType; $media = [string]$mediaType
    if ($bus -eq 'NVMe' -or $bus -eq '17') { return 'NVMe' }
    if ($media -eq 'SSD' -or $media -eq '4') { return 'SSD' }
    if ($media -eq 'HDD' -or $media -eq '3') { return 'HDD' }
    return ''
}
# HealthStatus as a name (numbers: 0 Healthy, 1 Warning, 2 Unhealthy); '' when it is not reported
function Get-DiskHealthName($status) {
    $s = [string]$status
    if ($s -in 'Healthy', '0') { return 'Healthy' }
    if ($s -in 'Warning', '1') { return 'Warning' }
    if ($s -in 'Unhealthy', '2') { return 'Unhealthy' }
    if ($s) { return 'Unknown' }
    return ''
}
# What Akati Doctor warns about: health Warning or Unhealthy, wear 90% or more, 70 °C or more.
# Unknown is not a warning (virtual and USB disks often report it). $null means not reported and never counts.
# Returns the text keys.
function Get-DiskWarnings($health, $wear, $temp) {
    $w = @()
    $h = Get-DiskHealthName $health
    if ($h -in 'Warning', 'Unhealthy') { $w += 'smart.warn.health' }
    if ($null -ne $wear -and [double]$wear -ge 90) { $w += 'smart.warn.wear' }
    if ($null -ne $temp -and [double]$temp -ge 70) { $w += 'smart.warn.temp' }
    $w
}

# Speed test: bytes in a time -> megabits per second (1 Mbps = 1,000,000 bits per second, like speed test sites)
function Get-Mbps([double]$bytes, [double]$seconds) {
    if ($seconds -le 0 -or $bytes -le 0) { return 0 }
    [Math]::Round($bytes * 8 / $seconds / 1e6, 1)
}
# Ping and jitter from round-trip times in ms: the median, and the average change from one time to the next.
# -1 when there is no time.
function Get-PingStats([double[]]$times) {
    $t = @($times | Where-Object { $_ -ge 0 })
    if (!$t.Count) { return @{ Ping = -1; Jitter = -1 } }
    $s = @($t | Sort-Object)
    $mid = [int][Math]::Floor($s.Count / 2)
    $median = if ($s.Count % 2) { $s[$mid] } else { ($s[$mid - 1] + $s[$mid]) / 2 }
    $j = 0
    for ($i = 1; $i -lt $t.Count; $i++) { $j += [Math]::Abs($t[$i] - $t[$i - 1]) }
    if ($t.Count -gt 1) { $j = $j / ($t.Count - 1) }
    @{ Ping = [Math]::Round($median, 1); Jitter = [Math]::Round($j, 1) }
}
# Speed test history: "yyyy-MM-ddTHH:mm:ss|down|up|ping|jitter" (invariant numbers, -1 = not measured), newest first
function New-SpeedEntry([datetime]$time, [double]$down, [double]$up, [double]$ping, [double]$jitter) {
    $inv = [Globalization.CultureInfo]::InvariantCulture
    [string]::Format($inv, '{0}|{1}|{2}|{3}|{4}', $time.ToString('s', $inv), $down, $up, $ping, $jitter)
}
function Add-SpeedHistory([string[]]$list, [string]$entry, [int]$keep = 10) {
    $old = @($list | Where-Object { $_ -match '^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(\|-?[\d.]+){4}$' })
    , [string[]]@(@($entry) + $old | Select-Object -First $keep)
}
function ConvertFrom-SpeedEntry([string]$entry) {
    if ($entry -notmatch '^(\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2})\|(-?[\d.]+)\|(-?[\d.]+)\|(-?[\d.]+)\|(-?[\d.]+)$') { return $null }
    $inv = [Globalization.CultureInfo]::InvariantCulture
    @{ Time = [datetime]::ParseExact($Matches[1], 's', $inv); Down = [double]::Parse($Matches[2], $inv); Up = [double]::Parse($Matches[3], $inv)
       Ping = [double]::Parse($Matches[4], $inv); Jitter = [double]::Parse($Matches[5], $inv) }
}

# Network use per app: processes Akati OS Center never offers to end. Session 0 (services), Windows parts (a file
# under the Windows folder or a known name) and processes whose file cannot be read (protected ones).
$protectedProcesses = 'System', 'Idle', 'Registry', 'smss', 'csrss', 'wininit', 'winlogon', 'services', 'lsass', 'lsaiso', 'svchost',
    'dwm', 'fontdrvhost', 'LogonUI', 'sihost', 'explorer', 'MsMpEng', 'NisSrv', 'audiodg', 'spoolsv', 'Memory Compression', 'SecurityHealthService'
function Test-ProtectedProcess([string]$name, [int]$session, [string]$path, [string]$windir) {
    if ($session -eq 0) { return $true }
    if ($protectedProcesses -contains $name) { return $true }
    if (!$path) { return $true }
    if ($windir -and $path.StartsWith($windir.TrimEnd('\') + '\', [StringComparison]::OrdinalIgnoreCase)) { return $true }
    return $false
}

# ---------------------------------------------------------------------------------------------
# Tweaks profiles. The Gaming profile (also read by the icon next to the clock) and "key=1;key=0" texts
# (the custom profile TweakProfile, and the game profile state)
# ---------------------------------------------------------------------------------------------
function Get-GamingProfile {
    [ordered]@{ gamemode = $true; maxperf = $true; timer = $true; access = $false; mouseaccel = $false; ducking = $false; nagle = $false; edgebg = $true; startdelay = $false }
}
function ConvertFrom-ProfileText([string]$text) {
    $map = [ordered]@{}
    foreach ($part in $text.Split(';')) {
        $m = [regex]::Match($part, '^(\w+)=([01])$')
        if ($m.Success) { $map[$m.Groups[1].Value] = $m.Groups[2].Value -eq '1' }
    }
    $map
}
# Switches a game profile never sets: settings of Akati OS itself and the look of Windows
$gameTweakSkip = 'store', 'tray', 'desktopmenu', 'hotkeys', 'widget', 'schedtheme', 'updatenotify', 'darkmode', 'accentbars', 'transparency'
# Switches that need a restart (the Restart switches of AkatiCenter.tweaks.ps1; tools/test-center.ps1 checks the list)
$restartTweaks = 'hags', 'timer', 'access', 'nagle', 'mpo', 'msi', 'memcomp', 'extrasvc', 'svcxbox', 'svciphelper', 'svchello', 'svcscanner',
    'svchotspot', 'svcnotify', 'svccdp', 'svcprint', 'svcbt', 'vbs'
# What a game profile changes: the switches of $map that differ from $current (key -> $true or $false; $null or missing
# when it cannot be read here). $restart: keys that need a restart, skipped and reported. $only: when given, the only
# keys that can be set here (the icon next to the clock: switches without administrator rights); the others are
# reported as Admin. Set: key -> new value; Prev: key -> the value before, to put back when the game closes.
function Get-GameTweakPlan($map, $current, [string[]]$restart, $only = $null) {
    $set = [ordered]@{}; $prev = [ordered]@{}; $skipRestart = @(); $skipAdmin = @()
    foreach ($k in @($map.Keys)) {
        if ($k -in $gameTweakSkip) { continue }
        $want = [bool]$map[$k]
        $now = if ($current.Contains($k)) { $current[$k] } else { $null }
        if ($null -ne $now -and [bool]$now -eq $want) { continue }
        if ($k -in $restart) { $skipRestart += $k; continue }
        if ($null -ne $only -and $k -notin @($only)) { $skipAdmin += $k; continue }
        if ($null -eq $now) { continue }
        $set[$k] = $want; $prev[$k] = [bool]$now
    }
    @{ Set = $set; Prev = $prev; Restart = $skipRestart; Admin = $skipAdmin }
}
# The switches a game profile changed, kept until the game closes (setting GameTweaks): "by|time|path|key=0;key=1".
# by: center (Play) or tray (automatic); the values are the switches as they were before the game started.
function ConvertTo-GameTweakState([string]$by, [string]$time, [string]$path, $prev) {
    $pairs = @(foreach ($k in @($prev.Keys)) { '{0}={1}' -f $k, [int][bool]$prev[$k] })
    '{0}|{1}|{2}|{3}' -f $by, $time, $path, ($pairs -join ';')
}
function ConvertFrom-GameTweakState([string]$text) {
    $m = [regex]::Match($text, '^(center|tray)\|([^|]*)\|([^|]+)\|(.*)$')
    if (!$m.Success) { return $null }
    @{ By = $m.Groups[1].Value; Time = $m.Groups[2].Value; Path = $m.Groups[3].Value; Prev = (ConvertFrom-ProfileText $m.Groups[4].Value) }
}

# ---------------------------------------------------------------------------------------------
# Privacy status (Tweaks): On or Off from the values read from the registry and the services ($v: name -> value,
# $null when missing). Windows defaults: telemetry, advertising ID, location, activity history, tailored experiences
# and app diagnostics are on until something turns them off; online speech recognition is off until accepted.
# ---------------------------------------------------------------------------------------------
function Test-PrivacyOff([string]$item, $v) {
    switch ($item) {
        'telemetry' {
            $policy = @($v.AllowTelemetry, $v.AllowTelemetry2) | Where-Object { $null -ne $_ } | Select-Object -First 1
            return ($null -ne $policy -and [int]$policy -eq 0) -and ($null -eq $v.DiagTrackStart -or [int]$v.DiagTrackStart -eq 4)
        }
        'adid' { return [int]$v.AdPolicy -eq 1 -or ($null -ne $v.AdEnabled -and [int]$v.AdEnabled -eq 0) }
        'location' { return [int]$v.LocationPolicy -eq 1 -or [string]$v.LocationMachine -eq 'Deny' -or [string]$v.LocationUser -eq 'Deny' }
        'activity' { return ($null -ne $v.ActivityFeed -and [int]$v.ActivityFeed -eq 0) -or ($null -ne $v.PublishActivities -and [int]$v.PublishActivities -eq 0) }
        'recall' { return [int]$v.RecallMachine -eq 1 -or [int]$v.RecallUser -eq 1 -or ($null -ne $v.RecallAllow -and [int]$v.RecallAllow -eq 0) }
        'copilot' { return [int]$v.CopilotUser -eq 1 -or [int]$v.CopilotMachine -eq 1 }
        'tailored' { return [int]$v.TailoredPolicy -eq 1 -or ($null -ne $v.Tailored -and [int]$v.Tailored -eq 0) }
        'speech' { return ($null -ne $v.SpeechPolicy -and [int]$v.SpeechPolicy -eq 0) -or [int]$v.SpeechAccepted -ne 1 }
        'appdiag' { return [int]$v.AppDiagPolicy -eq 2 -or [string]$v.AppDiagMachine -eq 'Deny' -or [string]$v.AppDiagUser -eq 'Deny' }
    }
    $false
}

# ---------------------------------------------------------------------------------------------
# After Windows Update. Baseline entries (setting WuBaseline): "svc:<service>=4" (turned off), "app:<package name>"
# (removed) and "pol:<id>=<value>" (a policy Akati OS or AtlasOS set). The key is the part before "=".
# ---------------------------------------------------------------------------------------------
function ConvertFrom-WuEntry([string]$entry) {
    $m = [regex]::Match($entry, '^(svc|app|pol):([\w.\-]+)(=(.*))?$')
    if (!$m.Success) { return $null }
    @{ Kind = $m.Groups[1].Value; Id = $m.Groups[2].Value; Key = $m.Groups[1].Value + ':' + $m.Groups[2].Value; Value = $m.Groups[4].Value }
}
# What came back on: baseline entries whose current value ($now: key -> value as text) shows them on again, without the
# keys the user turned on in Akati OS Center ($keep). A service counts when its start type is automatic (2) or manual (3)
# again, an app when it is installed again ('1'), a policy when its value is not the baseline value any more.
function Compare-WuBaseline([string[]]$baseline, $now, [string[]]$keep) {
    @(foreach ($e in @($baseline)) {
        $p = ConvertFrom-WuEntry $e
        if (!$p -or $p.Key -in @($keep) -or !$now.ContainsKey($p.Key)) { continue }
        $value = [string]$now[$p.Key]
        $back = switch ($p.Kind) { 'svc' { $value -in '2', '3' } 'app' { $value -eq '1' } default { $value -ne $p.Value } }
        if ($back) { $p }
    })
}
# A list with one entry for a key: the entry is added, or replaces the one with the same key
function Set-WuEntry([string[]]$list, [string]$entry) {
    $key = (ConvertFrom-WuEntry $entry).Key
    , [string[]]@(@($list | Where-Object { $_ -and (ConvertFrom-WuEntry $_).Key -ne $key }) + $entry)
}
function Remove-WuEntry([string[]]$list, [string]$key) {
    , [string[]]@($list | Where-Object { $_ -and $_ -ne $key -and (ConvertFrom-WuEntry $_).Key -ne $key })
}

# ---------------------------------------------------------------------------------------------
# Badges (Health): the ids unlocked by the numbers Akati OS Center keeps. $d: CleanBytes (all time), Cleaned (a clean
# ran), Boosts (all time), BestScore, ScoreDays, Profile (a custom profile is saved), DoctorGood (Akati Doctor found
# nothing once), SpeedTests, FpsTests.
# ---------------------------------------------------------------------------------------------
$badgeIds = 'firstclean', 'clean1gb', 'clean10gb', 'firstboost', 'boost10', 'score90', 'days7', 'days30', 'profile', 'doctor', 'speedtest', 'fpstest'
function Get-BadgeUnlocks($d) {
    $on = @()
    if ($d.Cleaned -or [double]$d.CleanBytes -gt 0) { $on += 'firstclean' }
    if ([double]$d.CleanBytes -ge 1GB) { $on += 'clean1gb' }
    if ([double]$d.CleanBytes -ge 10GB) { $on += 'clean10gb' }
    if ([int]$d.Boosts -ge 1) { $on += 'firstboost' }
    if ([int]$d.Boosts -ge 10) { $on += 'boost10' }
    if ([int]$d.BestScore -ge 90) { $on += 'score90' }
    if ([int]$d.ScoreDays -ge 7) { $on += 'days7' }
    if ([int]$d.ScoreDays -ge 30) { $on += 'days30' }
    if ($d.Profile) { $on += 'profile' }
    if ($d.DoctorGood) { $on += 'doctor' }
    if ([int]$d.SpeedTests -ge 1) { $on += 'speedtest' }
    if ([int]$d.FpsTests -ge 1) { $on += 'fpstest' }
    , [string[]]$on
}
# Saved badges: "id=yyyy-MM-dd" (the day each was unlocked). Returns the new list and the ids that are new.
function Update-BadgeList([string[]]$saved, [string[]]$unlocked, [string]$day) {
    $list = @($saved | Where-Object { $_ -match '^\w+=\d{4}-\d{2}-\d{2}$' })
    $have = @($list | ForEach-Object { $_.Split('=')[0] })
    $new = @($unlocked | Where-Object { $_ -notin $have })
    @{ List = [string[]]@($list + @($new | ForEach-Object { "$_=$day" })); New = [string[]]$new }
}

# ---------------------------------------------------------------------------------------------
# Service helper (Tweaks): services that must never be offered for a change, whatever the list says
# ---------------------------------------------------------------------------------------------
$criticalServices = 'RpcSs', 'DcomLaunch', 'RpcEptMapper', 'LSM', 'Winmgmt', 'WinDefend', 'WdNisSvc', 'WdBoot', 'WdFilter', 'Sense', 'MDCoreSvc',
    'SecurityHealthService', 'mpssvc', 'BFE', 'EventLog', 'Schedule', 'ProfSvc', 'Power', 'PlugPlay', 'SamSs', 'BrokerInfrastructure',
    'CoreMessagingRegistrar', 'StateRepository', 'SystemEventsBroker', 'UserManager', 'Dhcp', 'Dnscache', 'nsi', 'AudioEndpointBuilder',
    'Audiosrv', 'CryptSvc', 'gpsvc', 'KeyIso', 'TrustedInstaller', 'msiserver', 'sppsvc', 'wscsvc', 'EventSystem', 'Appinfo', 'TimeBrokerSvc',
    'LanmanServer', 'VaultSvc', 'Wcmsvc', 'netprofm', 'NlaSvc', 'FontCache', 'AppXSvc', 'ClipSVC', 'camsvc', 'DeviceInstall', 'DsmSvc'
# $updating: Windows Update is installing now (then wuauserv is not offered either)
function Test-ServiceChangeable([string]$name, [string]$level, [bool]$updating) {
    if ($name -in $criticalServices) { return $false }
    if ($name -eq 'wuauserv' -and $updating) { return $false }
    $level -in 'safe', 'careful'
}
