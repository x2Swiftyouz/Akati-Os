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
foreach ($ci in $cleanItems) {
    $right = New-Object System.Windows.Controls.StackPanel
    $right.Orientation = 'Horizontal'
    $size = New-Text '-' 13 'SemiBold'; $size.Margin = '0,0,18,0'; $size.VerticalAlignment = 'Center'; $size.MinWidth = 70; $size.TextAlignment = 'Right'
    $check = New-Object System.Windows.Controls.CheckBox
    $check.Style = $window.FindResource('Tick'); $check.IsChecked = !$ci.Off; $check.VerticalAlignment = 'Center'
    $check.Add_Click({ Update-CleanTotal })
    [void]$right.Children.Add($size); [void]$right.Children.Add($check)
    $row = New-Row ([string]$ci.Glyph) (T "clean.$($ci.Key)") "t:clean.$($ci.Key)" $right "t:clean.$($ci.Key).d"
    $row.Sub.Text = T "clean.$($ci.Key).d"
    $ci.SizeText = $size; $ci.Check = $check; $ci.Bytes = 0
    [void]$ui.CleanList.Children.Add($row.Row)
}
Update-Separators $ui.CleanList

function Update-CleanTotal {
    $total = 0
    foreach ($ci in $cleanItems) { if ($ci.Check.IsChecked) { $total += $ci.Bytes } }
    $ui.CleanTotal.Text = Format-Size $total
}

function Start-Scan([scriptblock]$then) {
    Set-Status (T 'status.scanning') $true
    $ui.ScanButton.IsEnabled = $false; $ui.CleanButton.IsEnabled = $false
    $items = @($cleanItems | ForEach-Object { @{ Key = $_.Key; Folders = $_.Folders; Files = $_.Files; Recycle = $_.Recycle } })
    Start-Work $measureWork @(, $items) {
        param($r, $ctx)
        $sizes = Get-LastOutput $r
        foreach ($ci in $cleanItems) { $ci.Bytes = if ($sizes) { [double]$sizes[$ci.Key] } else { 0 }; $ci.SizeText.Text = Format-Size $ci.Bytes }
        Update-CleanTotal
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
    $ui.ScanButton.IsEnabled = $false; $ui.CleanButton.IsEnabled = $false
    Start-Work $cleanWork @(, $selected) {
        param($r, $ctx)
        Start-Scan {
            $after = 0
            foreach ($ci in $cleanItems) { if ($ci.Check.IsChecked) { $after += $ci.Bytes } }
            $freed = [Math]::Max(0, $script:cleanBefore - $after)
            Set-Status ((T 'status.cleaned') -f (Format-Size $freed))
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

