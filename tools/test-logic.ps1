<#
.SYNOPSIS
    Tests the small functions of Akati OS Center that need no window (AkatiCenter.logic.ps1), on any
    PowerShell: score, FPS numbers, sizes, wallpaper accent colors and the Ctrl+K word match.
.EXAMPLE
    pwsh tools/test-logic.ps1
#>
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
. (Join-Path $root 'src/Executables/AtlasModules/AkatiCenter/AkatiCenter.logic.ps1')
$script:failed = 0; $script:count = 0
function Check([string]$name, $actual, $expected) {
    $script:count++
    if ("$actual" -ne "$expected") { $script:failed++; Write-Host "FAIL: $name -> '$actual', expected '$expected'" }
}

# Akati Score
$best = Get-ScorePoints 0 2 30 20 60
Check 'score best' $best.Score 100
Check 'score best tips' $best.Tips.Count 0
$worst = Get-ScorePoints 8 20 95 300 5
Check 'score worst' $worst.Score 0
Check 'score worst tips' ($worst.Tips -join ',') 'score.tip.doctor,score.tip.startup,score.tip.ram,score.tip.ping,score.tip.disk'
Check 'score ping unknown' (Get-ScorePoints 0 0 0 (-1) 50).Score 93
Check 'score middle' (Get-ScorePoints 1 5 60 60 15).Score 73

# FPS: 16.667 ms = 60 FPS; one slow frame of 50 ms in 100 sets the 1% low to 20 FPS
$frames = @(1..99 | ForEach-Object { 16.667 }) + @(50)
$fps = Get-FpsStats $frames
Check 'fps average' $fps.Avg 59
Check 'fps 1% low' $fps.Low 20
Check 'fps frames' $fps.Frames 100
Check 'fps too few' (Get-FpsStats @(16, 16)).Error 'fps.nodata'
Check 'fps drops bad values' (Get-FpsStats (@(1..40 | ForEach-Object { 10 }) + @(0, -1, 5000))).Frames 40

# Sizes (the number format follows the culture, so only the unit is checked)
Check 'size zero' (Format-Size 0) '0 KB'
Check 'size MB' ((Format-Size (5MB)) -replace '^[\d.,\s]+', '') 'MB'
Check 'size GB' ((Format-Size (3GB)) -replace '^[\d.,\s]+', '') 'GB'

# Accent from a hue
Check 'hsv red' (ConvertFrom-Hsv 0 1 1) '#FF0000'
Check 'hsv green' (ConvertFrom-Hsv 120 1 1) '#00FF00'
Check 'hsv blue' (ConvertFrom-Hsv 240 1 1) '#0000FF'
$acc = New-HueAccent 275
Check 'accent key' $acc.Key 'wallpaper'
Check 'accent colors' (@($acc.Base, $acc.Light, $acc.G1, $acc.G2) | Where-Object { $_ -match '^#[0-9A-F]{6}$' }).Count 4

# Ctrl+K word match
Check 'spot word start' (Test-SpotWord 'Free up RAM' 'ram') $true
Check 'spot inside word' (Test-SpotWord 'Highest frame rate' 'ram') $false
Check 'spot Thai' (Test-SpotWord 'ล้าง RAM' 'ล้าง') $true

# Weekly report and score history
Check 'week monday' (Get-WeekStart ([datetime]'2026-10-12')) '2026-10-12'
Check 'week sunday' (Get-WeekStart ([datetime]'2026-10-11')) '2026-10-05'
Check 'week friday' (Get-WeekStart ([datetime]'2026-10-09 23:30')) '2026-10-05'
$h = Update-ScoreHistory @('2026-10-01=70', '2026-10-02=75') '2026-10-02' 80
Check 'score history same day' ($h -join ',') '2026-10-01=70,2026-10-02=80'
$h = Update-ScoreHistory @('2026-10-01=70', 'bad', '2026-10-02=75') '2026-10-03' 90 2
Check 'score history keep' ($h -join ',') '2026-10-02=75,2026-10-03=90'
Check 'score history empty' ((Update-ScoreHistory $null '2026-10-03' 88) -join ',') '2026-10-03=88'

# Interrupts
Check 'irq modes' (Get-IrqModes 7) 'LB, MSI, MSI-X'
Check 'irq modes lb' (Get-IrqModes 1) 'LB'
Check 'cpu mask' (ConvertTo-CpuMask @(2, 4)) 20
Check 'cpu mask high' (ConvertTo-CpuMask @(63)) ([uint64]9223372036854775808)
Check 'cpu mask back' ((ConvertFrom-CpuMask 20) -join ',') '2,4'
Check 'best cores' ((Get-BestCores @(9, 5, 8, 7) $false) -join ',') '2,3,1'
Check 'best cores ht' ((Get-BestCores @(9, 9, 5, 8, 7, 6) $true) -join ',') '3,4'

# Win32PrioritySeparation
$ps = Get-PrioritySeparation 0x26
Check 'w32 0x26' ('{0} {1} {2}' -f $ps.Quantum, $ps.Fixed, $ps.Boost) 'short False 2'
$ps = Get-PrioritySeparation 0x18
Check 'w32 0x18' ('{0} {1} {2}' -f $ps.Quantum, $ps.Fixed, $ps.Boost) 'long True 0'
$ps = Get-PrioritySeparation 2
Check 'w32 default bits' ('{0} {1} {2}' -f $ps.Quantum, $ps.Fixed, $ps.Boost) 'short False 2'

# Uninstaller names
Check 'base 7zip' (Get-ProgramBaseName '7-Zip 21.07 (x64 edition)') '7-Zip'
Check 'base plain' (Get-ProgramBaseName 'Brave') 'Brave'
Check 'base version dash' (Get-ProgramBaseName 'Microsoft Visual C++ 2010  x64 Redistributable - 10.0.40219') 'Microsoft Visual C++ 2010  x64 Redistributable'
Check 'base bitness' (Get-ProgramBaseName 'Notepad++ (64-bit x64)') 'Notepad++'

# Disk health
Check 'disk kind nvme' (Get-DiskKind 'NVMe' 'SSD') 'NVMe'
Check 'disk kind nvme number' (Get-DiskKind 17 0) 'NVMe'
Check 'disk kind ssd' (Get-DiskKind 'SATA' 'SSD') 'SSD'
Check 'disk kind hdd number' (Get-DiskKind 11 3) 'HDD'
Check 'disk kind unknown' (Get-DiskKind 'USB' 'Unspecified') ''
Check 'disk health number' (Get-DiskHealthName 2) 'Unhealthy'
Check 'disk health none' (Get-DiskHealthName $null) ''
Check 'disk ok' ((Get-DiskWarnings 'Healthy' 12 41) -join ',') ''
Check 'disk not reported' ((Get-DiskWarnings $null $null $null) -join ',') ''
Check 'disk all bad' ((Get-DiskWarnings 'Warning' 90 70) -join ',') 'smart.warn.health,smart.warn.wear,smart.warn.temp'
Check 'disk unknown health' ((Get-DiskWarnings 'Unknown' 0 69) -join ',') ''
Check 'disk unhealthy' ((Get-DiskWarnings 'Unhealthy' $null $null) -join ',') 'smart.warn.health'

# Speed test
Check 'mbps' (Get-Mbps 25000000 2) 100
Check 'mbps no time' (Get-Mbps 1000 0) 0
$pst = Get-PingStats @(10, 12, 11, 30, 12)
Check 'ping median' $pst.Ping 12
Check 'jitter' $pst.Jitter 10
Check 'ping none' (Get-PingStats @()).Ping -1
$entry = New-SpeedEntry ([datetime]'2026-10-11T09:30:00') 245.3 41.25 12 1.5
Check 'speed entry' $entry '2026-10-11T09:30:00|245.3|41.25|12|1.5'
Check 'speed entry back' (ConvertFrom-SpeedEntry $entry).Up 41.25
Check 'speed entry bad' ($null -eq (ConvertFrom-SpeedEntry 'x|1')) 'True'
$sh = Add-SpeedHistory @('2026-10-10T09:00:00|1|2|3|4', 'bad', '2026-10-09T09:00:00|-1|-1|-1|-1') $entry 2
Check 'speed history keep' ($sh.Count) 2
Check 'speed history newest first' ($sh[0]) $entry

# Network use: processes without End task
Check 'protected session 0' (Test-ProtectedProcess 'game' 0 'D:\Games\game.exe' 'C:\Windows') 'True'
Check 'protected name' (Test-ProtectedProcess 'explorer' 1 'C:\Program Files\x.exe' 'C:\Windows') 'True'
Check 'protected windows folder' (Test-ProtectedProcess 'notepad' 1 'C:\WINDOWS\System32\notepad.exe' 'C:\Windows') 'True'
Check 'protected no path' (Test-ProtectedProcess 'anticheat' 1 '' 'C:\Windows') 'True'
Check 'not protected' (Test-ProtectedProcess 'chrome' 1 'C:\Program Files\Google\Chrome\Application\chrome.exe' 'C:\Windows') 'False'

# Profiles and the game profile
Check 'gaming profile' ((Get-GamingProfile).Keys -join ',') 'gamemode,maxperf,timer,access,mouseaccel,ducking,nagle,edgebg,startdelay'
$pt = ConvertFrom-ProfileText 'gamemode=1;timer=0;bad;x=2'
Check 'profile text' (($pt.Keys | ForEach-Object { "$_=$($pt[$_])" }) -join ',') 'gamemode=True,timer=False'
Check 'profile text empty' (ConvertFrom-ProfileText '').Count 0
$cur = @{ gamemode = $false; timer = $false; mouseaccel = $true; ducking = $false; edgebg = $null; hotkeys = $false; maxperf = $false }
$plan = Get-GameTweakPlan ([ordered]@{ gamemode = $true; timer = $true; mouseaccel = $false; ducking = $false; edgebg = $true; hotkeys = $true; maxperf = $true }) $cur @('timer')
Check 'plan set' (($plan.Set.Keys | ForEach-Object { "$_=$($plan.Set[$_])" }) -join ',') 'gamemode=True,mouseaccel=False,maxperf=True'
Check 'plan prev' (($plan.Prev.Keys | ForEach-Object { "$_=$($plan.Prev[$_])" }) -join ',') 'gamemode=False,mouseaccel=True,maxperf=False'
Check 'plan restart skipped' ($plan.Restart -join ',') 'timer'
$plan = Get-GameTweakPlan ([ordered]@{ gamemode = $true; maxperf = $true; nagle = $false }) @{ gamemode = $false } @('nagle') @('gamemode', 'mouseaccel')
Check 'plan tray set' ($plan.Set.Keys -join ',') 'gamemode'
Check 'plan tray admin' ($plan.Admin -join ',') 'maxperf'
Check 'plan tray restart' ($plan.Restart -join ',') 'nagle'
$st = ConvertTo-GameTweakState 'center' '2026-10-11T10:00:00' 'C:\Games\game.exe' ([ordered]@{ gamemode = $false; mouseaccel = $true })
Check 'state text' $st 'center|2026-10-11T10:00:00|C:\Games\game.exe|gamemode=0;mouseaccel=1'
$back = ConvertFrom-GameTweakState $st
Check 'state back' ('{0} {1} {2}' -f $back.By, $back.Path, $back.Prev['mouseaccel']) 'center C:\Games\game.exe True'
Check 'state bad' ($null -eq (ConvertFrom-GameTweakState 'other|x|y|z')) 'True'

# Privacy status
Check 'privacy telemetry off' (Test-PrivacyOff 'telemetry' @{ AllowTelemetry = 0; DiagTrackStart = 4 }) 'True'
Check 'privacy telemetry service on' (Test-PrivacyOff 'telemetry' @{ AllowTelemetry = 0; DiagTrackStart = 2 }) 'False'
Check 'privacy telemetry no policy' (Test-PrivacyOff 'telemetry' @{ DiagTrackStart = 4 }) 'False'
Check 'privacy adid default' (Test-PrivacyOff 'adid' @{}) 'False'
Check 'privacy adid user off' (Test-PrivacyOff 'adid' @{ AdEnabled = 0 }) 'True'
Check 'privacy location deny' (Test-PrivacyOff 'location' @{ LocationMachine = 'Deny' }) 'True'
Check 'privacy location allow' (Test-PrivacyOff 'location' @{ LocationMachine = 'Allow' }) 'False'
Check 'privacy recall policy' (Test-PrivacyOff 'recall' @{ RecallMachine = 1 }) 'True'
Check 'privacy speech default' (Test-PrivacyOff 'speech' @{}) 'True'
Check 'privacy speech accepted' (Test-PrivacyOff 'speech' @{ SpeechAccepted = 1 }) 'False'
Check 'privacy appdiag policy' (Test-PrivacyOff 'appdiag' @{ AppDiagPolicy = 2 }) 'True'

# After Windows Update
$e = ConvertFrom-WuEntry 'svc:diagnosticshub.standardcollector.service=4'
Check 'wu entry' ('{0} {1} {2}' -f $e.Kind, $e.Id, $e.Value) 'svc diagnosticshub.standardcollector.service 4'
Check 'wu entry app' (ConvertFrom-WuEntry 'app:Microsoft.BingNews').Key 'app:Microsoft.BingNews'
Check 'wu entry bad' ($null -eq (ConvertFrom-WuEntry 'x:y')) 'True'
$base = @('svc:DiagTrack=4', 'svc:Spooler=4', 'svc:SysMain=4', 'app:Microsoft.BingNews', 'app:Microsoft.Todos', 'pol:telemetry=0', 'pol:recall=1')
$now = @{ 'svc:DiagTrack' = '2'; 'svc:Spooler' = '3'; 'svc:SysMain' = '4'; 'app:Microsoft.BingNews' = '1'; 'app:Microsoft.Todos' = '0'; 'pol:telemetry' = ''; 'pol:recall' = '1' }
Check 'wu compare' ((Compare-WuBaseline $base $now @('svc:Spooler') | ForEach-Object { $_.Key }) -join ',') 'svc:DiagTrack,app:Microsoft.BingNews,pol:telemetry'
Check 'wu compare none' (@(Compare-WuBaseline $base @{} @()).Count) 0
Check 'wu set entry' ((Set-WuEntry @('svc:A=4', 'app:B') 'svc:A=4') -join ',') 'app:B,svc:A=4'
Check 'wu remove entry' ((Remove-WuEntry @('svc:A=4', 'app:B', 'pol:x') 'svc:A') -join ',') 'app:B,pol:x'

# Badges
Check 'badges none' ((Get-BadgeUnlocks @{}) -join ',') ''
$bu = Get-BadgeUnlocks @{ CleanBytes = 2GB; Boosts = 10; BestScore = 91; ScoreDays = 7; Profile = $true; DoctorGood = $true; SpeedTests = 1; FpsTests = 0 }
Check 'badges some' ($bu -join ',') 'firstclean,clean1gb,firstboost,boost10,score90,days7,profile,doctor,speedtest'
Check 'badges all ids' ($badgeIds.Count) 12
$bl = Update-BadgeList @('firstclean=2026-10-01', 'bad') @('firstclean', 'boost10') '2026-10-11'
Check 'badge list' ($bl.List -join ',') 'firstclean=2026-10-01,boost10=2026-10-11'
Check 'badge new' ($bl.New -join ',') 'boost10'

# Service helper
Check 'service critical' (Test-ServiceChangeable 'RpcSs' 'safe' $false) 'False'
Check 'service defender' (Test-ServiceChangeable 'WinDefend' 'careful' $false) 'False'
Check 'service safe' (Test-ServiceChangeable 'DiagTrack' 'safe' $false) 'True'
Check 'service keep' (Test-ServiceChangeable 'Themes' 'keep' $false) 'False'
Check 'service update running' (Test-ServiceChangeable 'wuauserv' 'careful' $true) 'False'
Check 'service update idle' (Test-ServiceChangeable 'wuauserv' 'careful' $false) 'True'

# What setup changed
Check 'setup done' (Get-SetupItemState $true $true $false) 'done'
Check 'setup changed' (Get-SetupItemState $true $false $true) 'changed'
Check 'setup not done' (Get-SetupItemState $true $false $false) 'notdone'
Check 'setup not picked' (Get-SetupItemState $false $false $true) 'notpicked'
Check 'setup not recorded' (Get-SetupItemState $null $true $false) 'unknown'
$hist = @('2026-10-01T10:00:00|svcxbox|0', '2026-10-02T10:00:00|svc:W32Time|3,4', 'bad')
Check 'history key' (Test-HistoryKey $hist @('svcbt', 'svc:W32Time')) 'True'
Check 'history key none' (Test-HistoryKey $hist @('timer')) 'False'
Check 'baseline key' (Test-BaselineKey @('svc:DoSvc=4', 'app:Microsoft.WindowsStore') @('app:Microsoft.WindowsStore')) 'True'
Check 'baseline key none' (Test-BaselineKey @('svc:DoSvc=4') @('svc:W32Time')) 'False'

# Game runtimes: names in Apps & features
Check 'vc 2022 x64' (Test-VcRuntimeName 'Microsoft Visual C++ 2015-2022 Redistributable (x64) - 14.40.33810' '2015' 'x64') 'True'
Check 'vc 2022 not x86' (Test-VcRuntimeName 'Microsoft Visual C++ 2015-2022 Redistributable (x64) - 14.40.33810' '2015' 'x86') 'False'
Check 'vc 2019 x86' (Test-VcRuntimeName 'Microsoft Visual C++ 2019 Redistributable (x86) - 14.29.30133' '2015' 'x86') 'True'
Check 'vc v14 x64' (Test-VcRuntimeName 'Microsoft Visual C++ v14 Redistributable (x64) - 14.44.35211' '2015' 'x64') 'True'
Check 'vc minimum runtime' (Test-VcRuntimeName 'Microsoft Visual C++ 2022 X64 Minimum Runtime - 14.40.33810' '2015' 'x64') 'False'
Check 'vc 2010 x64' (Test-VcRuntimeName 'Microsoft Visual C++ 2010  x64 Redistributable - 10.0.40219' '2010' 'x64') 'True'
Check 'vc 2008 x86' (Test-VcRuntimeName 'Microsoft Visual C++ 2008 Redistributable - x86 9.0.30729.6161' '2008' 'x86') 'True'
Check 'vc 2005 x86' (Test-VcRuntimeName 'Microsoft Visual C++ 2005 Redistributable' '2005' 'x86') 'True'
Check 'vc 2005 x64 not x86' (Test-VcRuntimeName 'Microsoft Visual C++ 2005 Redistributable (x64)' '2005' 'x86') 'False'
Check 'vc 2013 not 2012' (Test-VcRuntimeName 'Microsoft Visual C++ 2013 Redistributable (x64) - 12.0.40664' '2012' 'x64') 'False'
Check 'dotnet 8' (Test-DotNetRuntimeName 'Microsoft Windows Desktop Runtime - 8.0.11 (x64)' 8) 'True'
Check 'dotnet 8 x86' (Test-DotNetRuntimeName 'Microsoft Windows Desktop Runtime - 8.0.11 (x86)' 8) 'False'
Check 'dotnet 10 not 1' (Test-DotNetRuntimeName 'Microsoft Windows Desktop Runtime - 10.0.0 (x64)' 1) 'False'

# Akati settings export: what belongs to this PC stays out
Check 'setting portable' (Test-PortableSetting 'Accent') 'True'
Check 'setting local' (Test-PortableSetting 'WindowX') 'False'
Check 'setting history' (Test-PortableSetting 'History') 'False'

# Ctrl+K: Thai spacing, intent words, word order and the Thai keyboard layout
Check 'spot Thai spacing' (Test-SpotWord 'เน็ต ช้า ปิงสูง' 'เน็ตช้า') $true
Check 'spot rank title' (Get-SpotRank 'dns' 'DNS server' 'dns server' 'faster lookups' '') 0
Check 'spot rank name' (Get-SpotRank 'server dns' 'DNS server' 'dns server' '' '') 1
Check 'spot rank desc' (Get-SpotRank 'lookups' 'DNS server' 'dns server' 'faster lookups' '') 2
Check 'spot rank intent' (Get-SpotRank 'เน็ตช้า' 'DNS server' 'dns server' '' 'slow internet เน็ตช้า ปิงสูง แลค') 3
Check 'spot rank intent spaced' (Get-SpotRank 'เน็ต ช้า' 'DNS server' 'dns server' '' 'เน็ตช้า ปิงสูง') 3
Check 'spot rank intent any order' (Get-SpotRank 'internet slow' 'Speed test' 'speed test' '' 'slow internet high ping') 3
Check 'spot rank none' (Get-SpotRank 'printer' 'DNS server' 'dns server' '' 'slow internet') -1
Check 'thai keys dns' (ConvertFrom-ThaiKeys 'กืห') 'dns'
Check 'spot rank thai layout' (Get-SpotRank 'กืห' 'DNS server' 'dns server' '' '') 4
Check 'spot rank thai word not layout' (Get-SpotRank 'ล้าง' 'ล้าง RAM' 'ล้าง ram free up ram' '' '') 0
Check 'spot rank empty' (Get-SpotRank '  ' 'DNS' 'dns' '' '') -1

# Resizable BAR from nvidia-smi -q
$smiOn = @('Attached GPUs : 1', 'GPU 00000000:01:00.0', '    FB Memory Usage', '        Total                             : 12282 MiB', '        Used : 900 MiB',
           '    BAR1 Memory Usage', '        Total                             : 16384 MiB', '        Used : 3 MiB')
Check 'rebar on by size' (Get-RebarState $smiOn) 'on'
$smiOff = @('GPU 00000000:01:00.0', '    FB Memory Usage', '        Total : 8188 MiB', '    BAR1 Memory Usage', '        Total : 256 MiB')
Check 'rebar off by size' (Get-RebarState $smiOff) 'off'
Check 'rebar direct' (Get-RebarState @('GPU 00000000:01:00.0', '    Resizable BAR                     : Disabled', '    BAR1 Memory Usage', '        Total : 16384 MiB')) 'off'
Check 'rebar in between' (Get-RebarState @('GPU 00000000:01:00.0', '    FB Memory Usage', '        Total : 8188 MiB', '    BAR1 Memory Usage', '        Total : 2048 MiB')) 'unknown'
Check 'rebar nothing' (Get-RebarState @('NVIDIA-SMI has failed')) 'unknown'
Check 'rebar first gpu only' (Get-RebarState ($smiOff + @('GPU 00000000:02:00.0', '    Resizable BAR : Enabled'))) 'off'

# Mouse test: 1000 Hz for 5 s, 125 Hz, a pause in the middle, too few reports
Check 'mouse 1000' (Get-MouseRate @(0..4999 | ForEach-Object { [double]$_ })).Avg 1000
Check 'mouse 1000 peak' (Get-MouseRate @(0..4999 | ForEach-Object { [double]$_ })).Peak 1000
$m125 = Get-MouseRate @(0..624 | ForEach-Object { $_ * 8.0 })
Check 'mouse 125 class' (Get-MouseRateClass $m125.Avg) 125
Check 'mouse pause' (Get-MouseRate (@(0..1999 | ForEach-Object { [double]$_ }) + @(3000..4999 | ForEach-Object { [double]$_ }))).Avg 1000
Check 'mouse slow edges' (Get-MouseRate (@(0..49 | ForEach-Object { $_ * 4.0 }) + @(200..4999 | ForEach-Object { [double]$_ }))).Avg 1000
Check 'mouse too few' (Get-MouseRate @(1, 2, 3)).Error 'mouse.nodata'
Check 'mouse class 500' (Get-MouseRateClass 480) 500
Check 'mouse class 1000' (Get-MouseRateClass 990) 1000
Check 'mouse class 2000' (Get-MouseRateClass 3900) 2000

# Page file
$pf = ConvertFrom-PagingFiles @('C:\pagefile.sys 4096 8192')
Check 'pagefile custom' ('{0}{1}-{2}{3}' -f $pf.Files[0].Drive, $pf.Files[0].Min, $pf.Files[0].Max, $pf.Auto) 'C:4096-8192False'
Check 'pagefile auto' (ConvertFrom-PagingFiles @('?:\pagefile.sys')).Auto 'True'
Check 'pagefile system managed' (ConvertFrom-PagingFiles @('d:\pagefile.sys')).Files[0].Max 0
Check 'pagefile none' @((ConvertFrom-PagingFiles @('')).Files).Count 0
Check 'pagefile back' ((ConvertTo-PagingFiles @{ Auto = $false; Files = @(@{ Drive = 'D:'; Min = 0; Max = 0 }) }) -join ';') 'D:\pagefile.sys 0 0'
Check 'pagefile back auto' ((ConvertTo-PagingFiles @{ Auto = $true; Files = @() }) -join ';') '?:\pagefile.sys'
Check 'pagefile suggestion 16 GB' ('{0}-{1}' -f (Get-PageFileSuggestion (15.9GB)).Min, (Get-PageFileSuggestion (15.9GB)).Max) '4096-8192'
Check 'pagefile suggestion 8 GB' (Get-PageFileSuggestion (7.9GB)).Min 8192
Check 'pagefile suggestion 32 GB' (Get-PageFileSuggestion (31.9GB)).Min 2048
Check 'pagefile size ok' (Test-PageFileSize 4096 8192 50000) ''
Check 'pagefile size small' (Test-PageFileSize 200 8192) 'pf.err.small'
Check 'pagefile size order' (Test-PageFileSize 8192 4096) 'pf.err.order'
Check 'pagefile size space' (Test-PageFileSize 4096 8192 6000) 'pf.err.space'

# Scheduled task helper
Check 'task defender' (Test-TaskChangeable '\Microsoft\Windows\Windows Defender\Windows Defender Scheduled Scan' 'safe' $false) 'False'
Check 'task tpm' (Test-TaskProtected '\Microsoft\Windows\TPM\Tpm-Maintenance' $false) 'True'
Check 'task orchestrator updating' (Test-TaskChangeable '\Microsoft\Windows\UpdateOrchestrator\Schedule Scan' 'careful' $true) 'False'
Check 'task orchestrator idle' (Test-TaskProtected '\Microsoft\Windows\UpdateOrchestrator\Schedule Scan' $false) 'False'
Check 'task safe' (Test-TaskChangeable '\Microsoft\Windows\Maps\MapsUpdateTask' 'safe' $false) 'True'
Check 'task keep' (Test-TaskChangeable '\Microsoft\Windows\Defrag\ScheduledDefrag' 'keep' $false) 'False'
$tl = [ordered]@{ '\Microsoft\Windows\Maps\MapsUpdateTask' = @('safe', 'maps'); '\MicrosoftEdgeUpdateTaskMachineCore*' = @('careful', 'edgeupdate') }
Check 'task entry exact' (Find-TaskEntry $tl '\Microsoft\Windows\Maps\MapsUpdateTask')[1] 'maps'
Check 'task entry pattern' (Find-TaskEntry $tl '\MicrosoftEdgeUpdateTaskMachineCore{1A2B3C}')[1] 'edgeupdate'
Check 'task entry none' ($null -eq (Find-TaskEntry $tl '\Vendor\Updater')) 'True'

Write-Host "$script:count checks, $script:failed failed"
if ($script:failed) { exit 1 }
