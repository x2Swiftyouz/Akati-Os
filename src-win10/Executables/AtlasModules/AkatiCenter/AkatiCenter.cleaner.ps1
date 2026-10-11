<#
.SYNOPSIS
    Akati OS Center: Cleaner (the items are in AkatiClean.ps1) and the weekly automatic clean.
    Dot-sourced by AkatiCenter.ps1 (runs in its scope: $ui, $window, T and the other parts).
#>
# ---------------------------------------------------------------------------------------------
# Cleaner
# ---------------------------------------------------------------------------------------------
Add-Mark 'Cleaner'
# The items are in AkatiClean.ps1 (also used by the weekly automatic clean)
. (Join-Path $appDir 'AkatiClean.ps1')
# A short tag for each item, in the small monospace chip of its row
$cleanTags = @{ temp = 'TMP'; wintemp = 'WIN'; update = 'UPD'; dumps = 'DMP'; logs = 'LOG'; thumbs = 'IMG'; apps = 'APP'; browser = 'WEB'; shaders = 'GPU'; recycle = 'BIN' }
# Where the files are, short: the first folder with %LOCALAPPDATA% and the like (and "+2" for two more)
function Get-CleanPath($ci) {
    if ($ci.Recycle) { return '$Recycle.Bin' }
    $all = @(@($ci.Folders) + @($ci.Files) | Where-Object { $_ })
    if (!$all.Count) { return '' }
    $p = [string]$all[0]
    foreach ($v in 'TEMP', 'LOCALAPPDATA', 'APPDATA', 'USERPROFILE', 'ProgramData') {
        $value = [Environment]::GetEnvironmentVariable($v)
        if ($value -and $p.StartsWith($value, [StringComparison]::OrdinalIgnoreCase)) { $p = "%$v%" + $p.Substring($value.Length); break }
    }
    if ($p.StartsWith($windir, [StringComparison]::OrdinalIgnoreCase)) { $p = '%WINDIR%' + $p.Substring($windir.Length) }
    if ($all.Count -gt 1) { $p += "  +$($all.Count - 1)" }
    return $p
}
# One row: tick, tag chip, title, description, path, a thin bar with its share of everything found; size and files on the right
foreach ($ci in $cleanItems) {
    $border = New-Object System.Windows.Controls.Border
    $border.Padding = '14,11'; $border.Background = [System.Windows.Media.Brushes]::Transparent
    $grid = New-Object System.Windows.Controls.Grid
    foreach ($w in 'Auto', 'Auto', '*', 'Auto') { $c = New-Object System.Windows.Controls.ColumnDefinition; $c.Width = $w; $grid.ColumnDefinitions.Add($c) }
    $check = New-Object System.Windows.Controls.CheckBox
    $check.Style = $window.FindResource('Tick'); $check.IsChecked = !$ci.Off; $check.VerticalAlignment = 'Top'; $check.Margin = '0,2,12,0'
    $check.Add_Click({ Update-CleanTotal })
    $chip = New-Object System.Windows.Controls.Border
    $chip.CornerRadius = 5; $chip.Padding = '0,2'; $chip.Width = 40; $chip.Margin = '0,1,12,0'; $chip.VerticalAlignment = 'Top'; $chip.BorderThickness = '1'
    $chip.SetResourceReference([System.Windows.Controls.Border]::BackgroundProperty, 'AccentSoft')
    $chip.SetResourceReference([System.Windows.Controls.Border]::BorderBrushProperty, 'AccentLine')
    $tag = New-Text $cleanTags[$ci.Key] 10 'Bold'; $tag.FontFamily = $window.FindResource('MonoFont'); $tag.HorizontalAlignment = 'Center'
    $tag.SetResourceReference([System.Windows.Controls.TextBlock]::ForegroundProperty, 'AccentText')
    $chip.Child = $tag
    [System.Windows.Controls.Grid]::SetColumn($chip, 1)
    $text = New-Object System.Windows.Controls.StackPanel
    $title = New-Text (T "clean.$($ci.Key)") 14 'SemiBold' "t:clean.$($ci.Key)"
    $sub = New-Text (T "clean.$($ci.Key).d") 12 'Normal' "t:clean.$($ci.Key).d"; $sub.Style = $window.FindResource('Muted'); $sub.Margin = '0,2,12,0'
    $path = New-Text (Get-CleanPath $ci) 10.5; $path.Style = $window.FindResource('MonoText'); $path.Margin = '0,4,12,0'; $path.Opacity = 0.8
    $bar = New-Object System.Windows.Controls.ProgressBar
    $bar.Style = $window.FindResource('Meter'); $bar.Height = 3; $bar.Margin = '0,8,12,0'
    [void]$text.Children.Add($title); [void]$text.Children.Add($sub); [void]$text.Children.Add($path); [void]$text.Children.Add($bar)
    [System.Windows.Controls.Grid]::SetColumn($text, 2)
    $right = New-Object System.Windows.Controls.StackPanel
    $right.MinWidth = 86
    $size = New-Text '-' 14 'Bold'; $size.FontFamily = $window.FindResource('MonoFont'); $size.TextAlignment = 'Right'; $size.HorizontalAlignment = 'Right'
    $count = New-Text '' 10.5; $count.Style = $window.FindResource('MonoText'); $count.HorizontalAlignment = 'Right'; $count.Margin = '0,3,0,0'
    [void]$right.Children.Add($size); [void]$right.Children.Add($count)
    [System.Windows.Controls.Grid]::SetColumn($right, 3)
    [void]$grid.Children.Add($check); [void]$grid.Children.Add($chip); [void]$grid.Children.Add($text); [void]$grid.Children.Add($right)
    $border.Child = $grid
    $ci.SizeText = $size; $ci.CountText = $count; $ci.Bar = $bar; $ci.Check = $check; $ci.Bytes = 0; $ci.FileCount = -1
    [void]$ui.CleanList.Children.Add($border)
}
Update-Separators $ui.CleanList

# The summary next to the list: space to free (the ticked items), how many are ticked and everything found
function Update-CleanTotal {
    $total = 0; $all = 0; $n = 0
    foreach ($ci in $cleanItems) { $all += $ci.Bytes; if ($ci.Check.IsChecked) { $total += $ci.Bytes; $n++ } }
    $scanned = $ui.CleanTotal.Text -ne '-' -or $all -gt 0
    if ($scanned) { $ui.CleanTotal.Text = Format-Size $total }
    $ui.CleanCount.Text = '{0} / {1}' -f $n, $cleanItems.Count
    $ui.CleanDetected.Text = if ($scanned) { Format-Size $all } else { '-' }
    $ui.CleanShare.Value = if ($all -gt 0) { 100 * $total / $all } else { 0 }
    foreach ($ci in $cleanItems) {
        $ci.Bar.Value = if ($all -gt 0) { 100 * $ci.Bytes / $all } else { 0 }
        $ci.CountText.Text = if ($ci.FileCount -ge 0) { (T 'cleaner.files') -f $ci.FileCount } else { '' }
    }
}
# Sizes and file counts from a scan (also used by the screenshot mode with sample numbers)
function Show-CleanSizes($sizes) {
    $counts = if ($sizes -is [hashtable] -and $sizes['_counts'] -is [hashtable]) { $sizes['_counts'] } else { @{} }
    foreach ($ci in $cleanItems) {
        $ci.Bytes = if ($sizes) { [double]$sizes[$ci.Key] } else { 0 }
        $ci.FileCount = if ($counts.ContainsKey($ci.Key)) { [int]$counts[$ci.Key] } else { -1 }
        $ci.SizeText.Text = Format-Size $ci.Bytes
    }
    if ($ui.CleanTotal.Text -eq '-') { $ui.CleanTotal.Text = Format-Size 0 }
    Update-CleanTotal
}
# The summary panel sits next to the list in a wide window and below it in a narrow one
function Update-CleanLayout {
    $wide = $ui.CleanGrid.ActualWidth -ge 720 -or $ui.CleanGrid.ActualWidth -le 0
    [System.Windows.Controls.Grid]::SetColumn($ui.CleanSide, $(if ($wide) { 1 } else { 0 }))
    [System.Windows.Controls.Grid]::SetRow($ui.CleanSide, $(if ($wide) { 0 } else { 1 }))
    $ui.CleanSide.Margin = if ($wide) { '14,0,0,0' } else { '0,14,0,0' }
    $ui.CleanGrid.ColumnDefinitions[1].Width = New-Object System.Windows.GridLength ($(if ($wide) { 270 } else { 0 }))
}
$ui.CleanGrid.Add_SizeChanged({ Update-CleanLayout })
$ui.CleanSelectAll.Add_Click({ foreach ($ci in $cleanItems) { $ci.Check.IsChecked = $true }; Update-CleanTotal })
$ui.CleanNone.Add_Click({ foreach ($ci in $cleanItems) { $ci.Check.IsChecked = $false }; Update-CleanTotal })

function Start-Scan([scriptblock]$then) {
    Set-Status (T 'status.scanning') $true
    $ui.ScanButton.IsEnabled = $false; $ui.CleanButton.IsEnabled = $false
    $items = @($cleanItems | ForEach-Object { @{ Key = $_.Key; Folders = $_.Folders; Files = $_.Files; Recycle = $_.Recycle } })
    Start-Work $measureWork @($items, $true) {
        param($r, $ctx)
        Show-CleanSizes (Get-LastOutput $r)
        $found = 0; foreach ($ci in $cleanItems) { $found += $ci.Bytes }
        Add-Log 'CleanLog' ((T 'cleaner.log.scan') -f (Format-Size $found), $cleanItems.Count)
        $ui.ScanButton.IsEnabled = $true; $ui.CleanButton.IsEnabled = $true
        Set-Status (T 'ready')
        if ($ctx.Then) { & $ctx.Then }
    } @{ Then = $then }
}

function Start-Clean {
    $script:cleanBefore = 0
    $selected = @($cleanItems | Where-Object { $_.Check.IsChecked } | ForEach-Object { $script:cleanBefore += $_.Bytes; @{ Key = $_.Key; Folders = $_.Folders; Files = $_.Files; Recycle = $_.Recycle } })
    if (!$selected.Count) { return }
    Set-Status (T 'status.cleaning') $true
    Add-Log 'CleanLog' ((T 'cleaner.log.clean') -f $selected.Count, (Format-Size $script:cleanBefore))
    $ui.ScanButton.IsEnabled = $false; $ui.CleanButton.IsEnabled = $false
    Start-Work $cleanWork @(, $selected) {
        param($r, $ctx)
        Start-Scan {
            $after = 0
            foreach ($ci in $cleanItems) { if ($ci.Check.IsChecked) { $after += $ci.Bytes } }
            $freed = [Math]::Max(0, $script:cleanBefore - $after)
            Set-Status ((T 'status.cleaned') -f (Format-Size $freed))
            Add-Log 'CleanLog' ((T 'status.cleaned') -f (Format-Size $freed))
            Add-WeekStat 'WeekCleanBytes' $freed; Update-Week
        }
    }
}

# Weekly automatic clean: the task "\AkatiOS\Akati OS clean" (AkatiClean.ps1 -CleanNow)
function Update-AutoClean {
    $last = Get-RegValue $settingsKey 'AutoCleanLast'
    if ($last) {
        $c = (Get-LangCulture)
        $when = try { [datetime]::ParseExact($last, 's', [Globalization.CultureInfo]::InvariantCulture).ToString('d MMM', $c) } catch { $last }
        $ui.AutoCleanSub.Text = (T 'autoclean.last') -f $when, (Format-Size ([double](Get-RegValue $settingsKey 'AutoCleanBytes')))
    } else { $ui.AutoCleanSub.Text = T 'autoclean.sub' }
}
# Read in the background: the Task Scheduler module takes about half a second to load
$ui.AutoCleanToggle.IsChecked = $false
if (!$Screenshot) {
    $ui.AutoCleanToggle.IsEnabled = $false
    Start-Work { [bool](Get-ScheduledTask -TaskPath '\AkatiOS\' -TaskName 'Akati OS clean' -ErrorAction SilentlyContinue) } @() {
        param($r) $ui.AutoCleanToggle.IsChecked = (Get-LastOutput $r) -eq $true; $ui.AutoCleanToggle.IsEnabled = $true } $null
}
$ui.AutoCleanToggle.Add_Click({
    $on = [bool]$this.IsChecked
    Start-Work { param($file, $on) (& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $file $(if ($on) { '-RegisterTask' } else { '-RemoveTask' }) 2>&1 | Out-String).Trim() } @((Join-Path $appDir 'AkatiClean.ps1'), $on) {
        param($r, $on)
        $ui.AutoCleanToggle.IsChecked = [bool](Get-ScheduledTask -TaskPath '\AkatiOS\' -TaskName 'Akati OS clean' -ErrorAction SilentlyContinue)
        $out = [string](Get-LastOutput $r)
        # Turned on but no task: show why
        if ($on -and !$ui.AutoCleanToggle.IsChecked) { Set-Status ((T 'autoclean.failed') -f $out); return }
        Set-Status (T $(if ($ui.AutoCleanToggle.IsChecked) { 'autoclean.on' } else { 'autoclean.off' }))
    } $on
})
Update-AutoClean
$ui.ScanButton.Add_Click({ Start-Scan })
$ui.CleanButton.Add_Click({ Start-Clean })
$ui.QuickClean.Add_Click({ $ui.NavCleaner.IsChecked = $true; Start-Scan { Start-Clean } })

