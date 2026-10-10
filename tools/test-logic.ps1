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

Write-Host "$script:count checks, $script:failed failed"
if ($script:failed) { exit 1 }
