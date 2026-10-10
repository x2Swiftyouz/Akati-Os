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
