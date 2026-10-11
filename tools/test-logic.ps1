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
Check 'disk unknown health' ((Get-DiskWarnings 'Unknown' 0 69) -join ',') 'smart.warn.health'

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

Write-Host "$script:count checks, $script:failed failed"
if ($script:failed) { exit 1 }
