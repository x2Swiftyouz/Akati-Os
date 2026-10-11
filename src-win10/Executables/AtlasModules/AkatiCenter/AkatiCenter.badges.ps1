<#
.SYNOPSIS
    Akati OS Center: Health > Badges, earned from the numbers Akati OS Center already keeps on this PC (cleaned bytes,
    Game boost sessions, the Akati Score history, speed and FPS tests). No network, no account.
    Dot-sourced by AkatiCenter.ps1 (runs in its scope: $ui, $window, T and the other parts).
#>
Add-Mark 'Badges'
$badgeGlyphs = @{ firstclean = 0xE74D; clean1gb = 0xE74D; clean10gb = 0xE7C1; firstboost = 0xE945; boost10 = 0xE945; score90 = 0xE735
                  days7 = 0xE787; days30 = 0xE81C; profile = 0xE728; doctor = 0xE73E; speedtest = 0xEC4A; fpstest = 0xE7FC }
# The numbers of Get-BadgeUnlocks. TotalCleanBytes and TotalBoosts count all time (Add-WeekStat, AkatiClean.ps1); on a
# PC that has only the weekly numbers so far, the week counts.
function Get-BadgeData {
    $num = { param($n) $v = 0.0; [void][double]::TryParse([string](Get-RegValue $settingsKey $n), [Globalization.NumberStyles]::Float, [Globalization.CultureInfo]::InvariantCulture, [ref]$v); $v }
    $scores = @(Get-ScoreDays)
    @{ CleanBytes = [Math]::Max((& $num 'TotalCleanBytes'), (Get-WeekNumber 'WeekCleanBytes'))
       Cleaned = [bool](Get-RegValue $settingsKey 'AutoCleanLast')
       Boosts = [Math]::Max([Math]::Max((& $num 'TotalBoosts'), (Get-WeekNumber 'WeekBoosts')), $(if (Get-RegValue $settingsKey 'LastBoost') { 1 } else { 0 }))
       BestScore = [int](@($scores | ForEach-Object { $_.Score }) + 0 | Measure-Object -Maximum).Maximum
       ScoreDays = $scores.Count
       Profile = [bool](Get-RegValue $settingsKey 'TweakProfile')
       DoctorGood = [bool](Get-RegValue $settingsKey 'DoctorAllGood')
       SpeedTests = @(Get-RegValue $settingsKey 'SpeedHistory' | Where-Object { $_ }).Count
       FpsTests = @(Get-RegValue $settingsKey 'FpsResults' | Where-Object { $_ }).Count }
}
# Every 20 seconds (the window timer) and when the Health page opens: new badges are saved with today's date and
# shown in a toast
$script:badgeAt = [datetime]::MinValue
function Update-Badges([switch]$Now) {
    if ($Screenshot -or (!$Now -and (Get-Date) -lt $script:badgeAt)) { return }
    $script:badgeAt = (Get-Date).AddSeconds(20)
    $day = (Get-Date).ToString('yyyy-MM-dd', [Globalization.CultureInfo]::InvariantCulture)
    $res = Update-BadgeList @(Get-RegValue $settingsKey 'Badges') (Get-BadgeUnlocks (Get-BadgeData)) $day
    if (!$res.New.Count) { return }
    Save-Setting Badges $res.List
    Show-Toast ((T 'badge.toast') -f ((@($res.New) | ForEach-Object { T "badge.$_" }) -join ', ')) $null
    if ($script:page -eq 'health') { Show-Badges }
}
function New-BadgeTile([string]$id, [string]$day) {
    $on = [bool]$day
    $tile = New-Object System.Windows.Controls.Border
    $tile.Width = 178; $tile.Margin = '0,0,10,10'; $tile.CornerRadius = 12; $tile.Padding = '12,10'; $tile.BorderThickness = '1'
    $tile.SetResourceReference([System.Windows.Controls.Border]::BackgroundProperty, $(if ($on) { 'AccentSoft' } else { 'CardBg' }))
    $tile.SetResourceReference([System.Windows.Controls.Border]::BorderBrushProperty, $(if ($on) { 'AccentLine' } else { 'CardBorder' }))
    $tile.ToolTip = T "badge.$id.d"
    $dock = New-Object System.Windows.Controls.DockPanel
    $circle = New-Object System.Windows.Controls.Border
    $circle.Width = 34; $circle.Height = 34; $circle.CornerRadius = 17; $circle.Margin = '0,0,10,0'; $circle.VerticalAlignment = 'Top'
    $circle.SetResourceReference([System.Windows.Controls.Border]::BackgroundProperty, $(if ($on) { 'Accent' } else { 'Fill' }))
    $g = New-Text ([string][char]$badgeGlyphs[$id]) 15; $g.Style = $window.FindResource('Glyph'); $g.FontSize = 15; $g.HorizontalAlignment = 'Center'
    if ($on) { $g.Foreground = [System.Windows.Media.Brushes]::White } else { $g.SetResourceReference([System.Windows.Controls.TextBlock]::ForegroundProperty, 'MutedBrush') }
    $circle.Child = $g
    [System.Windows.Controls.DockPanel]::SetDock($circle, 'Left')
    $text = New-Object System.Windows.Controls.StackPanel; $text.VerticalAlignment = 'Center'
    $name = New-Text (T "badge.$id") 13 'SemiBold'; $name.TextWrapping = 'Wrap'
    if (!$on) { $name.SetResourceReference([System.Windows.Controls.TextBlock]::ForegroundProperty, 'MutedBrush') }
    $when = if ($on) {
        $d = try { [datetime]::ParseExact($day, 'yyyy-MM-dd', [Globalization.CultureInfo]::InvariantCulture).ToString('d MMM yyyy', (Get-LangCulture)) } catch { $day }
        (T 'badge.on') -f $d
    } else { T "badge.$id.d" }
    $sub = New-Text $when 11; $sub.TextWrapping = 'Wrap'; $sub.Margin = '0,2,0,0'
    $sub.SetResourceReference([System.Windows.Controls.TextBlock]::ForegroundProperty, 'MutedBrush')
    [void]$text.Children.Add($name); [void]$text.Children.Add($sub)
    [void]$dock.Children.Add($circle); [void]$dock.Children.Add($text)
    $tile.Child = $dock
    $tile
}
function Show-Badges {
    $saved = @{}
    foreach ($e in @(Get-RegValue $settingsKey 'Badges')) { if ([string]$e -match '^(\w+)=(\d{4}-\d{2}-\d{2})$') { $saved[$Matches[1]] = $Matches[2] } }
    $ui.BadgeList.Children.Clear()
    foreach ($id in $badgeIds) { [void]$ui.BadgeList.Children.Add((New-BadgeTile $id $saved[$id])) }
    $ui.BadgeSummary.Text = (T 'badge.count') -f @($badgeIds | Where-Object { $saved.ContainsKey($_) }).Count, $badgeIds.Count
}
