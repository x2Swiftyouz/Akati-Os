<#
.SYNOPSIS
    Akati OS Center: Health: Akati Score, Akati Doctor, startup time, crashes, Windows Update, history, backup.
    Dot-sourced by AkatiCenter.ps1 (runs in its scope: $ui, $window, T and the other parts).
#>
# ---------------------------------------------------------------------------------------------
# Health: Akati Doctor, startup time, temperatures, crashes, Windows Update, change history, backup
# ---------------------------------------------------------------------------------------------
Add-Mark 'Health'
$getCulture = { Get-LangCulture }
$orange = (New-Object System.Windows.Media.BrushConverter).ConvertFromString('#FF9F0A')

# Akati Doctor: each check is $true when fine. Runs in the background (no functions of this script)
$doctorChecks = 'tray', 'menu', 'power', 'disk', 'restart', 'hvci', 'devices', 'crash'
$doctorWork = {
    $r = @{}
    $wanted = (Get-ItemProperty -Path 'HKLM:\SOFTWARE\AkatiOS' -Name TrayIcon -ErrorAction SilentlyContinue).TrayIcon -eq 1
    $r.tray = !$wanted -or [bool](Get-ScheduledTask -TaskPath '\AkatiOS\' -TaskName 'Akati OS tray' -ErrorAction SilentlyContinue)
    $menu = Test-Path 'HKLM:\SOFTWARE\Classes\DesktopBackground\Shell\AkatiOS'
    $r.menu = !$menu -or [bool](Get-ScheduledTask -TaskPath '\AkatiOS\' -TaskName 'Akati OS menu' -ErrorAction SilentlyContinue)
    # Akati OS power scheme (AtlasOS GUID), High performance or Ultimate Performance
    $r.power = [string](& powercfg.exe /getactivescheme) -match '11111111-1111-1111-1111-111111111111|8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c|e9a42b02-d5df-448d-aa00-03f14749eb61'
    try {
        $drive = [IO.DriveInfo]::new($env:SystemDrive.Substring(0, 1))
        $r.diskFree = [int](100 * $drive.AvailableFreeSpace / $drive.TotalSize)
    } catch { $r.diskFree = 100 }
    $r.disk = $r.diskFree -ge 10
    $r.restart = !((Test-Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired') -or
                   (Test-Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending'))
    # Memory integrity: what runs differs from the setting (unknown on builds without the DeviceGuard provider)
    try {
        $running = 2 -in @((Get-CimInstance -Namespace 'root\Microsoft\Windows\DeviceGuard' -ClassName Win32_DeviceGuard -ErrorAction Stop).SecurityServicesRunning)
        $want = (Get-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\DeviceGuard\Scenarios\HypervisorEnforcedCodeIntegrity' -Name Enabled -ErrorAction SilentlyContinue).Enabled -eq 1
        $r.hvci = $running -eq $want
    } catch { $r.hvci = $true }
    # Devices with a problem; 22 is a device the user turned off
    $r.devicesBad = @(Get-CimInstance Win32_PnPEntity -Filter 'ConfigManagerErrorCode <> 0' -ErrorAction SilentlyContinue | Where-Object { $_.ConfigManagerErrorCode -ne 22 }).Count
    $r.devices = $r.devicesBad -eq 0
    $r.crashCount = @(Get-WinEvent -FilterHashtable @{ LogName = 'System'; Id = 1001; ProviderName = 'Microsoft-Windows-WER-SystemErrorReporting'; StartTime = (Get-Date).AddDays(-7) } -ErrorAction SilentlyContinue).Count
    $r.crash = $r.crashCount -eq 0
    $r
}
# Startup time (Diagnostics-Performance log) and crashes of the last 30 days
$healthWork = {
    $r = @{ Boot = @(); Crashes = @() }
    # Some Windows builds (imOS) turn the startup time log off
    $r.BootLog = try { [bool](Get-WinEvent -ListLog 'Microsoft-Windows-Diagnostics-Performance/Operational' -ErrorAction Stop).IsEnabled } catch { $false }
    try {
        $r.Boot = @(Get-WinEvent -FilterHashtable @{ LogName = 'Microsoft-Windows-Diagnostics-Performance/Operational'; Id = 100 } -MaxEvents 5 -ErrorAction Stop | ForEach-Object {
            $d = @{}; foreach ($x in ([xml]$_.ToXml()).Event.EventData.Data) { $d[$x.Name] = $x.'#text' }
            @{ Time = $_.TimeCreated; Ms = [int]$d['BootTime'] }
        })
    } catch { }
    $since = (Get-Date).AddDays(-30)
    $list = @()
    try { $list += @(Get-WinEvent -FilterHashtable @{ LogName = 'System'; Id = 1001; ProviderName = 'Microsoft-Windows-WER-SystemErrorReporting'; StartTime = $since } -MaxEvents 10 -ErrorAction Stop | ForEach-Object { @{ Kind = 'bsod'; Time = $_.TimeCreated; Text = [string]$_.Properties[0].Value } }) } catch { }
    try { $list += @(Get-WinEvent -FilterHashtable @{ LogName = 'System'; Id = 41; ProviderName = 'Microsoft-Windows-Kernel-Power'; StartTime = $since } -MaxEvents 10 -ErrorAction Stop | ForEach-Object { @{ Kind = 'power'; Time = $_.TimeCreated; Text = '' } }) } catch { }
    try { $list += @(Get-WinEvent -FilterHashtable @{ LogName = 'Application'; Id = 1000; ProviderName = 'Application Error'; StartTime = $since } -MaxEvents 15 -ErrorAction Stop | ForEach-Object { @{ Kind = 'app'; Time = $_.TimeCreated; Text = [string]$_.Properties[0].Value } }) } catch { }
    $r.Crashes = @($list | Sort-Object { $_.Time } -Descending | Select-Object -First 12)
    $r
}
function Show-Doctor($r) {
    $script:doctorResult = $r
    $ui.DoctorList.Children.Clear()
    if ($r -isnot [hashtable]) { $ui.DoctorSummary.Text = T 'doc.failed'; return }
    $bad = 0
    foreach ($k in $doctorChecks) {
        $ok = [bool]$r[$k]
        if (!$ok) { $bad++ }
        $arg = switch ($k) { 'disk' { $r.diskFree } 'devices' { $r.devicesBad } 'crash' { $r.crashCount } default { '' } }
        $right = New-Object System.Windows.Controls.Border
        if (!$ok) {
            $right = New-Object System.Windows.Controls.Button
            $right.Style = $window.FindResource('PillAccent'); $right.Padding = '12,4'; $right.Content = T "doc.fix.$k"; $right.Tag = $k
            $right.Add_Click({ Invoke-DoctorFix $this.Tag })
        }
        $row = New-Row ([string][char]$(if ($ok) { 0xE73E } else { 0xE7BA })) ((T "doc.$k.$(if ($ok) { 'ok' } else { 'bad' })") -f $arg) $null $right $null
        $row.Sub.Visibility = 'Collapsed'
        $row.Icon.Child.Foreground = if ($ok) { $window.FindResource('Good') } else { $orange }
        [void]$ui.DoctorList.Children.Add($row.Row)
    }
    # Repair Windows files: DISM then SFC in a window (Akati OS Center runs as administrator)
    $repair = New-Object System.Windows.Controls.Button
    $repair.Style = $window.FindResource('Pill'); $repair.Padding = '12,4'; $repair.Content = T 'doc.repair.button'
    $repair.Add_Click({ Start-Process cmd.exe -ArgumentList '/k title Akati OS - Repair Windows files & DISM /Online /Cleanup-Image /RestoreHealth & sfc /scannow' })
    $row = New-Row ([string][char]0xE90F) (T 'doc.repair') $null $repair $null
    $row.Sub.Text = T 'doc.repair.d'
    [void]$ui.DoctorList.Children.Add($row.Row)
    Update-Separators $ui.DoctorList
    Update-Score
    $ui.DoctorSummary.Text = $(if ($bad) { (T 'doc.issues') -f $bad } else { T 'doc.allgood' }) + ' · ' + ((T 'doc.checked') -f (Get-Date).ToString('HH:mm'))
}
# Akati Score (0-100): Akati Doctor 40, startup apps 15, memory in use 15, ping 15, free space 15
function Get-StartupOnCount {
    if (!$script:startupAt -or (Get-Date) -gt $script:startupAt) {
        $script:startupAt = (Get-Date).AddMinutes(1)
        $script:startupOn = try { @(Get-StartupItems | Where-Object { Test-StartupOn $_ }).Count } catch { 0 }
    }
    $script:startupOn
}
function Get-AkatiScore {
    $r = $script:doctorResult
    if ($r -isnot [hashtable]) { return $null }
    $issues = @($doctorChecks | Where-Object { !$r[$_] }).Count
    Get-ScorePoints $issues (Get-StartupOnCount) $stats.Ram $stats.Ping ([int]$r.diskFree)
}
function Get-ScoreBrush([int]$s) {
    if ($s -ge 80) { $window.FindResource('Good') } elseif ($s -ge 60) { $orange } else { (New-Object System.Windows.Media.BrushConverter).ConvertFromString('#FF453A') }
}
function Update-Score {
    $s = Get-AkatiScore
    if (!$s) { return }
    $ui.ScoreValue.Text = [string]$s.Score
    $ui.ScoreValue.Foreground = Get-ScoreBrush $s.Score
    $ui.ScoreTitle.Text = T $(if ($s.Score -ge 85) { 'score.great' } elseif ($s.Score -ge 65) { 'score.good' } else { 'score.low' })
    $ui.ScoreTips.Children.Clear()
    foreach ($tip in @($s.Tips | Select-Object -First 3)) {
        $tb = New-Text ('•  ' + (T $tip)) 13; $tb.Margin = '0,2,0,0'
        $tb.Foreground = $window.FindResource('MutedBrush')
        [void]$ui.ScoreTips.Children.Add($tb)
    }
}
function Invoke-DoctorFix([string]$k) {
    switch ($k) {
        'tray' {
            Set-Status (T 'doc.fixing') $true
            Start-Work { param($f) & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $f -Install } @((Join-Path $appDir 'AkatiTray.ps1')) { param($r) Set-Status (T 'ready'); Start-Health } $null
        }
        'menu' { Update-DesktopMenu; Start-Health }
        'power' {
            $t = $tweaks | Where-Object { $_.Key -eq 'maxperf' } | Select-Object -First 1
            if ($t -and $t.Toggle) { $t.Toggle.IsChecked = $true; Invoke-Tweak $t $true; Add-History $t.Key $true }
        }
        'disk' { $ui.NavCleaner.IsChecked = $true }
        { $_ -in 'restart', 'hvci' } {
            if ([System.Windows.MessageBox]::Show((T 'restart.ask'), 'Akati OS Center', 'YesNo', 'Question') -eq 'Yes') { Restart-Computer -Force }
        }
        'devices' { Start-Process devmgmt.msc }
        'crash' { $ui.CrashList.BringIntoView() }
    }
}
function Show-HealthInfo($r) {
    $script:healthResult = $r
    $c = & $getCulture
    $boot = @(if ($r -is [hashtable]) { $r.Boot | Where-Object { $_ -and $_.Ms -gt 0 } })
    if ($boot.Count) {
        $ui.BootTime.Text = (T 'boot.last') -f ($boot[0].Ms / 1000)
        $ui.BootDetail.Text = (T 'boot.avg') -f $boot.Count, (($boot | ForEach-Object { $_.Ms } | Measure-Object -Average).Average / 1000)
    } else { $ui.BootTime.Text = '-'; $ui.BootDetail.Text = T $(if ($r -is [hashtable] -and !$r.BootLog) { 'boot.off' } else { 'boot.none' }) }
    $ui.BootLogOn.Visibility = if ($r -is [hashtable] -and !$r.BootLog) { 'Visible' } else { 'Collapsed' }
    $ui.CrashList.Children.Clear()
    $crashes = @(if ($r -is [hashtable]) { $r.Crashes | Where-Object { $_ } })
    foreach ($x in $crashes) {
        $title = switch ($x.Kind) { 'bsod' { (T 'crash.bsod') -f (([string]$x.Text).Trim() -split '\s')[0] } 'power' { T 'crash.power' } default { (T 'crash.app') -f $x.Text } }
        $glyph = switch ($x.Kind) { 'bsod' { 0xE7BA } 'power' { 0xE7E8 } default { 0xE783 } }
        $row = New-Row ([string][char]$glyph) $title $null (New-Object System.Windows.Controls.Border) $null
        $row.Sub.Text = ([datetime]$x.Time).ToString('d MMM yyyy HH:mm', $c)
        if ($x.Kind -ne 'app') { $row.Icon.Child.Foreground = $orange }
        [void]$ui.CrashList.Children.Add($row.Row)
    }
    $ui.CrashEmpty.Visibility = if ($crashes.Count) { 'Collapsed' } else { 'Visible' }
    Update-Separators $ui.CrashList
    $ui.MinidumpOpen.Visibility = if (Test-Path (Join-Path $windir 'Minidump')) { 'Visible' } else { 'Collapsed' }
}
function Update-TempText {
    $parts = @()
    if ($stats.CpuTemp -gt 0) { $parts += (T 'chip.temp.sys') -f $stats.CpuTemp }
    if ($stats.GpuTemp -gt 0) { $parts += (T 'chip.temp.gpu') -f $stats.GpuTemp }
    $ui.TempDetail.Text = if ($parts.Count) { (T 'temp.now') -f ($parts -join ' · ') } else { T 'temp.none' }
}
function Start-Health {
    if ($Screenshot) { Show-Doctor (& $doctorWork); Show-HealthInfo (& $healthWork); return }
    $ui.DoctorRun.IsEnabled = $false; $ui.DoctorSummary.Text = T 'doc.checking'
    Start-Work $doctorWork @() { param($r) Show-Doctor (Get-LastOutput $r); $ui.DoctorRun.IsEnabled = $true } $null
    Start-Work $healthWork @() { param($r) Show-HealthInfo (Get-LastOutput $r) } $null
}
$ui.DoctorRun.Add_Click({ Start-Health })
$ui.BootLogOn.Add_Click({
    & wevtutil.exe sl 'Microsoft-Windows-Diagnostics-Performance/Operational' /e:true 2>$null
    if ($LASTEXITCODE -eq 0) { $this.Visibility = 'Collapsed'; $ui.BootDetail.Text = T 'boot.next'; Set-Status (T 'boot.next') }
    else { Set-Status (T 'boot.failed') }
})
$ui.MinidumpOpen.Add_Click({ Start-Process explorer.exe -ArgumentList "`"$(Join-Path $windir 'Minidump')`"" })

# Windows Update: the same pause values as Settings > Windows Update > Pause updates
$wuKey = 'HKLM:\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings'
$wuNames = 'PauseUpdatesStartTime', 'PauseUpdatesExpiryTime', 'PauseFeatureUpdatesStartTime', 'PauseFeatureUpdatesEndTime', 'PauseQualityUpdatesStartTime', 'PauseQualityUpdatesEndTime'
function Update-WuState {
    $until = $null
    try { $until = [datetime]::Parse((Get-RegValue $wuKey 'PauseUpdatesExpiryTime'), [Globalization.CultureInfo]::InvariantCulture, [Globalization.DateTimeStyles]'AdjustToUniversal, AssumeUniversal') } catch { }
    $paused = $until -and $until -gt (Get-Date).ToUniversalTime()
    $ui.WuState.Text = if ($paused) { (T 'wu.paused') -f $until.ToLocalTime().ToString('d MMMM yyyy', (& $getCulture)) } else { T 'wu.on' }
    $ui.WuResume.IsEnabled = [bool]$paused
}
function Set-WuPause([int]$days) {
    try {
        if ($days -le 0) { Remove-ItemProperty -Path $wuKey -Name $wuNames -ErrorAction SilentlyContinue }
        else {
            if (!(Test-Path $wuKey)) { New-Item -Path $wuKey -Force | Out-Null }
            $start = (Get-Date).ToUniversalTime().ToString("yyyy-MM-dd'T'HH:mm:ss'Z'")
            $end = (Get-Date).AddDays($days).ToUniversalTime().ToString("yyyy-MM-dd'T'HH:mm:ss'Z'")
            foreach ($n in $wuNames) { Set-ItemProperty -Path $wuKey -Name $n -Value $(if ($n -like '*Start*') { $start } else { $end }) -Type String -Force }
        }
    } catch { Set-Status $_.Exception.Message }
    Update-WuState
}
$ui.WuPause7.Add_Click({ Set-WuPause 7 })
$ui.WuPause35.Add_Click({ Set-WuPause 35 })
$ui.WuResume.Add_Click({ Set-WuPause 0 })
$ui.WuOpen.Add_Click({ Start-Process 'ms-settings:windowsupdate' })

# Change history: the last 30 switches changed in Akati OS Center, newest first ("time|key|1 or 0")
function Add-History([string]$key, [bool]$on) {
    try {
        if (!(Test-Path $settingsKey)) { New-Item -Path $settingsKey -Force | Out-Null }
        $list = @("$((Get-Date).ToString('s'))|$key|$([int]$on)") + @(Get-RegValue $settingsKey 'History' | Where-Object { $_ })
        Set-ItemProperty -Path $settingsKey -Name History -Value ([string[]]@($list | Select-Object -First 30)) -Type MultiString -Force
    } catch { }
    if ($script:page -eq 'health') { Show-History }
}
function Show-History {
    $ui.HistoryList.Children.Clear()
    $c = & $getCulture
    foreach ($item in @(Get-RegValue $settingsKey 'History' | Where-Object { $_ })) {
        $time, $key, $state = $item -split '\|', 3
        $t = $tweaks | Where-Object { $_.Key -eq $key } | Select-Object -First 1
        if (!$t -or !$t.Toggle) { continue }
        $on = $state -eq '1'
        $undo = New-Object System.Windows.Controls.Button
        $undo.Style = $window.FindResource('Pill'); $undo.Padding = '12,4'; $undo.Content = T 'toast.undo'; $undo.Tag = @{ Tweak = $t; On = $on }
        # Only while the switch is still as this change left it
        $undo.IsEnabled = $t.Toggle.IsEnabled -and ([bool]$t.Toggle.IsChecked -eq $on)
        $undo.Add_Click({ $u = $this.Tag; $back = !$u.On; $u.Tweak.Toggle.IsChecked = $back; Invoke-Tweak $u.Tweak $back; Add-History $u.Tweak.Key $back })
        $row = New-Row ([string]$t.Glyph) (T "tw.$key") $null $undo $null
        $when = try { [datetime]::ParseExact($time, 's', [Globalization.CultureInfo]::InvariantCulture).ToString('d MMM HH:mm', $c) } catch { $time }
        $row.Sub.Text = (T $(if ($on) { 'history.on' } else { 'history.off' })) + ' · ' + $when
        [void]$ui.HistoryList.Children.Add($row.Row)
    }
    $any = $ui.HistoryList.Children.Count -gt 0
    $ui.HistoryEmpty.Visibility = if ($any) { 'Collapsed' } else { 'Visible' }
    $ui.HistoryClear.Visibility = if ($any) { 'Visible' } else { 'Collapsed' }
    Update-Separators $ui.HistoryList
}
$ui.HistoryClear.Add_Click({ Remove-ItemProperty -Path $settingsKey -Name History -ErrorAction SilentlyContinue; Show-History })

# Backup: settings of Akati OS Center, My games with their profiles and the state of every switch, in one JSON file
$ui.BackupSave.Add_Click({
    $d = New-Object Microsoft.Win32.SaveFileDialog
    $d.Filter = 'Akati OS backup (*.json)|*.json'; $d.FileName = "AkatiOS-backup-$(Get-Date -Format yyyy-MM-dd).json"
    if (!$d.ShowDialog($window)) { return }
    $data = [ordered]@{ AkatiOS = $version; Date = (Get-Date).ToString('s'); Settings = [ordered]@{}; Games = @(); Profiles = [ordered]@{}; Tweaks = [ordered]@{} }
    if (Test-Path $settingsKey) {
        foreach ($p in (Get-ItemProperty -Path $settingsKey).PSObject.Properties) {
            if ($p.Name -notlike 'PS*' -and $p.Name -ne 'History' -and $p.Value -isnot [byte[]]) { $data.Settings[$p.Name] = $p.Value }
        }
    }
    if (Test-Path $gamesKey) { $data.Games = @((Get-Item $gamesKey).Property) }
    if (Test-Path $profilesKey) { foreach ($p in (Get-ItemProperty -Path $profilesKey).PSObject.Properties) { if ($p.Name -notlike 'PS*') { $data.Profiles[$p.Name] = $p.Value } } }
    # Slow switches (Microsoft Store) are left out
    foreach ($t in $tweaks) { if ($t.Toggle -and $t.Toggle.IsEnabled -and !$t.Slow -and $null -ne $t.Toggle.IsChecked) { $data.Tweaks[$t.Key] = [bool]$t.Toggle.IsChecked } }
    try {
        [IO.File]::WriteAllText($d.FileName, ($data | ConvertTo-Json -Depth 5), (New-Object System.Text.UTF8Encoding $false))
        Set-Status ((T 'backup.saved') -f (Split-Path $d.FileName -Leaf))
    } catch { Set-Status $_.Exception.Message }
})
$ui.BackupLoad.Add_Click({
    $d = New-Object Microsoft.Win32.OpenFileDialog
    $d.Filter = 'Akati OS backup (*.json)|*.json'
    if (!$d.ShowDialog($window)) { return }
    $data = try { [IO.File]::ReadAllText($d.FileName) | ConvertFrom-Json } catch { $null }
    if (!$data -or !$data.AkatiOS) { Set-Status (T 'backup.bad'); return }
    if ([System.Windows.MessageBox]::Show((T 'backup.ask'), 'Akati OS Center', 'YesNo', 'Question') -ne 'Yes') { return }
    if (!(Test-Path $settingsKey)) { New-Item -Path $settingsKey -Force | Out-Null }
    foreach ($p in @($data.Settings.PSObject.Properties)) {
        $v = $p.Value
        if ($v -is [array]) { Set-ItemProperty -Path $settingsKey -Name $p.Name -Value ([string[]]@($v)) -Type MultiString -Force }
        elseif ($v -is [int] -or $v -is [long]) { Set-ItemProperty -Path $settingsKey -Name $p.Name -Value ([int]$v) -Type DWord -Force }
        elseif ($null -ne $v) { Set-ItemProperty -Path $settingsKey -Name $p.Name -Value ([string]$v) -Type String -Force }
    }
    if (@($data.Games).Count) {
        if (!(Test-Path $gamesKey)) { New-Item -Path $gamesKey -Force | Out-Null }
        foreach ($g in @($data.Games)) { if ($g) { Set-ItemProperty -Path $gamesKey -Name $g -Value 1 -Type DWord -Force } }
    }
    foreach ($p in @($data.Profiles.PSObject.Properties)) {
        if (!(Test-Path $profilesKey)) { New-Item -Path $profilesKey -Force | Out-Null }
        Set-ItemProperty -Path $profilesKey -Name $p.Name -Value ([int]$p.Value) -Type DWord -Force
    }
    $changed = 0
    foreach ($p in @($data.Tweaks.PSObject.Properties)) {
        $t = $tweaks | Where-Object { $_.Key -eq $p.Name } | Select-Object -First 1
        if (!$t -or !$t.Toggle -or !$t.Toggle.IsEnabled -or [bool]$t.Toggle.IsChecked -eq [bool]$p.Value) { continue }
        $t.Toggle.IsChecked = [bool]$p.Value; Invoke-Tweak $t ([bool]$p.Value); Add-History $t.Key ([bool]$p.Value)
        $changed++
    }
    Show-Games
    Request-MenuUpdate
    if ($data.Settings.Language -in $languages.Keys -and $data.Settings.Language -ne $lang) { Set-AppLanguage $data.Settings.Language }
    Set-Status ((T 'backup.restored') -f $changed)
})

