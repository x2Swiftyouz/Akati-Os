<#
.SYNOPSIS
    Akati OS Center: Game boost > CPU balance and process rules. The icon next to the clock (AkatiTray.ps1) does the
    work every 3 seconds; this page only saves the settings and shows what it did.
    Dot-sourced by AkatiCenter.ps1 (runs in its scope: $ui, $window, T and the other parts).
#>
# Settings in HKCU\Software\AkatiOS\Center: Balance (1 on), BalanceLimit (20, 30 or 50 % of the whole CPU),
# BalanceLog ("time|app|%", newest first), ProcessRules ("app|priority|affinity mask", priority empty = keep)
Add-Mark 'Process rules'
$rulePrios = 'Keep', 'Idle', 'BelowNormal', 'Normal', 'AboveNormal', 'High'
function Get-Rules {
    @(foreach ($line in @(Get-RegValue $settingsKey 'ProcessRules' | Where-Object { $_ })) {
        $name, $prio, $mask = ([string]$line).Split('|')
        @{ Name = $name; Prio = [string]$prio; Mask = [uint64]$(if ($mask) { $mask } else { 0 }) }
    })
}
function Save-Rules($rules) {
    $lines = [string[]]@($rules | ForEach-Object { '{0}|{1}|{2}' -f $_.Name, $_.Prio, $(if ($_.Mask) { $_.Mask } else { '' }) })
    if ($lines.Count) { Save-Setting ProcessRules $lines } else { Remove-ItemProperty -Path $settingsKey -Name ProcessRules -ErrorAction SilentlyContinue }
}
function Get-RuleText($r) {
    $parts = @(T "rules.prio.$(if ($r.Prio) { $r.Prio } else { 'Keep' })")
    $parts += if ($r.Mask) { 'CPU ' + ((ConvertFrom-CpuMask $r.Mask) -join ', ') } else { T 'rules.allcpus' }
    $parts -join '  ·  '
}
function Show-Rules {
    $ui.RuleList.Children.Clear()
    $rules = @(Get-Rules)
    foreach ($r in $rules) {
        $remove = New-Object System.Windows.Controls.Button
        $remove.Style = $window.FindResource('Bare'); $remove.Padding = '7'; $remove.ToolTip = T 'games.remove'; $remove.Tag = $r.Name
        $x = New-Text ([string][char]0xE711) 12; $x.Style = $window.FindResource('Glyph'); $remove.Content = $x
        $remove.Add_Click({ $n = $this.Tag; Save-Rules @(Get-Rules | Where-Object { $_.Name -ne $n }); Show-Rules; Set-Status ((T 'rules.removed') -f $n) })
        $row = New-Row ([string][char]0xE7EF) "$($r.Name).exe" $null $remove $null
        $row.Sub.Text = Get-RuleText $r
        $row.Row.Padding = '0,8'
        [void]$ui.RuleList.Children.Add($row.Row)
    }
    Update-Separators $ui.RuleList
    $ui.RuleEmpty.Visibility = if ($rules.Count) { 'Collapsed' } else { 'Visible' }
}
function Show-BalLog {
    $ui.BalLog.Children.Clear()
    $c = Get-LangCulture
    $log = @(Get-RegValue $settingsKey 'BalanceLog' | Where-Object { $_ } | Select-Object -First 5)
    foreach ($line in $log) {
        $time, $name, $pct = ([string]$line).Split('|')
        $when = try { [datetime]::ParseExact($time, 's', [Globalization.CultureInfo]::InvariantCulture).ToString('d MMM HH:mm', $c) } catch { $time }
        $tb = New-Text ((T 'bal.entry') -f $when, $name, $pct) 12; $tb.Foreground = $window.FindResource('MutedBrush'); $tb.Margin = '0,1,0,0'
        [void]$ui.BalLog.Children.Add($tb)
    }
    $ui.BalLogHead.Visibility = if ($log.Count) { 'Visible' } else { 'Collapsed' }
}
# Settings
$ui.BalanceOn.IsChecked = (Get-RegValue $settingsKey 'Balance') -eq 1
$ui.BalanceOn.Add_Click({ Save-Setting Balance ([int][bool]$this.IsChecked); Set-Status (T $(if ($this.IsChecked) { 'bal.on' } else { 'bal.off' })) })
$balLimit = [int](Get-RegValue $settingsKey 'BalanceLimit')
if ($balLimit -in 20, 30, 50) { $ui["BalLimit$balLimit"].IsChecked = $true }
foreach ($n in 20, 30, 50) { $ui["BalLimit$n"].Add_Checked({ Save-Setting BalanceLimit ([int]$this.Name.Substring(8)) }) }
# The icon next to the clock must run for this: checked when the page first opens (in the background)
function Test-BalTray {
    if ($Screenshot) { return }
    Start-Work { [bool]@(Get-CimInstance Win32_Process -Filter "Name='powershell.exe'" -ErrorAction SilentlyContinue | Where-Object { $_.CommandLine -like '*AkatiTray.ps1*' -and $_.CommandLine -notlike '*-Install*' }).Count } @() {
        param($r) $ui.BalTray.Visibility = if ((Get-LastOutput $r) -eq $true) { 'Collapsed' } else { 'Visible' } } $null
}
# Add rule: running apps with a window as chips, the processors as chips, a priority
$ui.RuleAdd.Add_Click({
    if ($ui.RulePanel.Visibility -eq 'Visible') { $ui.RulePanel.Visibility = 'Collapsed'; return }
    $ui.RuleApps.Children.Clear(); $ui.RuleCpus.Children.Clear(); $ui.RuleName.Text = ''; $ui.RulePrioKeep.IsChecked = $true
    $names = @(Get-Process -ErrorAction SilentlyContinue | Where-Object { $_.MainWindowHandle -ne 0 -and $_.Id -ne $PID -and $_.ProcessName -notin $boostNever } | ForEach-Object { $_.ProcessName } | Sort-Object -Unique)
    foreach ($n in $names) {
        $chip = New-Object System.Windows.Controls.Button
        $chip.Style = $window.FindResource('Pill'); $chip.Padding = '10,3'; $chip.Margin = '0,0,6,6'; $chip.FontSize = 12; $chip.Content = $n
        $chip.Add_Click({ $ui.RuleName.Text = [string]$this.Content })
        [void]$ui.RuleApps.Children.Add($chip)
    }
    for ($i = 0; $i -lt [Math]::Min(64, [Environment]::ProcessorCount); $i++) {
        $cpu = New-Object System.Windows.Controls.CheckBox
        $cpu.Style = $window.FindResource('Chip'); $cpu.Content = "CPU $i"; $cpu.Tag = $i; $cpu.Margin = '0,0,6,6'
        [void]$ui.RuleCpus.Children.Add($cpu)
    }
    $ui.RulePanel.Visibility = 'Visible'
})
$ui.RuleName.Add_TextChanged({ $ui.RuleNameHint.Visibility = if ($this.Text) { 'Collapsed' } else { 'Visible' } })
$ui.RuleCancel.Add_Click({ $ui.RulePanel.Visibility = 'Collapsed' })
$ui.RuleSave.Add_Click({
    $name = ($ui.RuleName.Text.Trim() -replace '\.exe$', '')
    if ($name -notmatch '^[\w .+-]{2,}$') { Set-Status (T 'rules.badname'); return }
    $prio = ($rulePrios | Where-Object { $ui["RulePrio$_"].IsChecked } | Select-Object -First 1)
    if ($prio -eq 'Keep') { $prio = '' }
    $mask = ConvertTo-CpuMask @($ui.RuleCpus.Children | Where-Object { $_.IsChecked } | ForEach-Object { [int]$_.Tag })
    if (!$prio -and !$mask) { Set-Status (T 'rules.nothing'); return }
    Save-Rules (@(Get-Rules | Where-Object { $_.Name -ne $name }) + @(@{ Name = $name; Prio = $prio; Mask = $mask }))
    $ui.RulePanel.Visibility = 'Collapsed'
    Show-Rules
    Set-Status ((T 'rules.saved') -f $name)
})
Show-Rules
Show-BalLog
