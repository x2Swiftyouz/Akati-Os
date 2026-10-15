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

# Akati Doctor: each check is $true when fine. Runs in the background: only the functions of AkatiCenter.logic.ps1
# ($logic, dot-sourced there; not needed when it runs here in screenshot mode)
$doctorChecks = 'tray', 'menu', 'power', 'battery', 'refresh', 'xmp', 'disk', 'smart', 'restart', 'hvci', 'devices', 'crash', 'activation'
$logicFile = Join-Path $appDir 'AkatiCenter.logic.ps1'
$doctorWork = {
    param($logic)
    if ($logic) { . $logic }
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
    # Windows activation (LicenseStatus 1 = licensed); Akati OS does not change it
    try {
        $win = Get-CimInstance SoftwareLicensingProduct -Filter "ApplicationID='55c92734-d682-4d71-983e-d6ec3f16059f' AND PartialProductKey IS NOT NULL" -ErrorAction Stop | Select-Object -First 1
        $r.activation = $win.LicenseStatus -eq 1
    } catch { $r.activation = $true }
    # Checks this PC cannot answer are left out of the list
    $r.skip = @()
    # Laptops: on battery Windows holds the CPU and GPU back (BatteryStatus 1 = discharging); desktops have no battery
    $r.battery = $true
    try {
        $bat = @(Get-CimInstance Win32_Battery -ErrorAction Stop)
        if ($bat.Count) { $r.battery = !@($bat | Where-Object { $_.BatteryStatus -eq 1 }).Count } else { $r.skip += 'battery' }
    } catch { $r.skip += 'battery' }
    # Screen refresh rate: the highest the primary screen can do at its resolution ([AkatiOS.Perf], from the Game boost part)
    try { $r.hzNow = [AkatiOS.Perf]::Current()[2]; $r.hzMax = [AkatiOS.Perf]::MaxHz() } catch { $r.hzNow = 0; $r.hzMax = 0 }
    if ($r.hzNow -le 1 -or $r.hzMax -le 1) { $r.skip += 'refresh' }
    $r.refresh = $r.hzNow -ge $r.hzMax
    # RAM speed against the speed the modules report (SMBIOS): lower means XMP (Intel) or EXPO (AMD) is off in the BIOS.
    # Not on laptops (their RAM runs as the maker set it) and not when Windows reports no speed (virtual machines).
    # Some BIOSes report the configured speed at half (MHz instead of MT/s): that counts as unknown.
    $r.xmp = $true
    try {
        $mods = @(Get-CimInstance Win32_PhysicalMemory -ErrorAction Stop | Where-Object { $_.Speed -gt 0 -and $_.ConfiguredClockSpeed -gt 0 })
        $laptop = @(@((Get-CimInstance Win32_SystemEnclosure -ErrorAction SilentlyContinue).ChassisTypes) | Where-Object { $_ -in 8, 9, 10, 14, 30, 31, 32 }).Count -gt 0
        if ($mods.Count -and !$laptop) {
            $r.ramNow = [int]($mods | Measure-Object -Property ConfiguredClockSpeed -Minimum).Minimum
            $r.ramMax = [int]($mods | Measure-Object -Property Speed -Minimum).Minimum
            if ([Math]::Abs(2 * $r.ramNow - $r.ramMax) -le $r.ramMax * 0.05) { $r.skip += 'xmp' }
            else { $r.xmp = $r.ramNow -ge $r.ramMax * 0.97 }
        } else { $r.skip += 'xmp' }
    } catch { $r.skip += 'xmp' }
    # Disks (SMART through Windows): health Warning or Unhealthy (Unknown is not a warning), wear 90% or more or 70 °C or more (Get-DiskWarnings)
    try {
        $disks = @(Get-PhysicalDisk -ErrorAction Stop)
        $badDisks = @(foreach ($d in $disks) {
            $c = $null
            try { $c = $d | Get-StorageReliabilityCounter -ErrorAction Stop } catch { }
            $temp = if ($c -and $c.Temperature -gt 0) { $c.Temperature } else { $null }
            $wear = if ($c -and $null -ne $c.Wear) { $c.Wear } else { $null }
            if (@(Get-DiskWarnings ([string]$d.HealthStatus) $wear $temp).Count) { [string]$d.FriendlyName }
        })
        if ($disks.Count) { $r.smart = !$badDisks.Count; $r.smartBad = $badDisks -join ', ' } else { $r.skip += 'smart' }
    } catch { $r.skip += 'smart' }
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
        if ($k -in @($r.skip)) { continue }
        $ok = [bool]$r[$k]
        if (!$ok) { $bad++ }
        $arg = switch ($k) { 'disk' { $r.diskFree } 'smart' { $r.smartBad } 'devices' { $r.devicesBad } 'crash' { $r.crashCount }
                             'refresh' { , @($r.hzNow, $r.hzMax) } 'xmp' { , @($r.ramNow, $r.ramMax) } default { '' } }
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
    $script:doctorBad = $bad; Update-HealthBadge
    # Badges: Akati Doctor found nothing once
    if (!$bad -and !$Screenshot -and !(Get-RegValue $settingsKey 'DoctorAllGood')) { Save-Setting DoctorAllGood ((Get-Date).ToString('yyyy-MM-dd', [Globalization.CultureInfo]::InvariantCulture)) }
    Update-Score
    $ui.DoctorSummary.Text = $(if ($bad) { (T 'doc.issues') -f $bad } else { T 'doc.allgood' }) + ' · ' + ((T 'doc.checked') -f (Get-Date).ToString('HH:mm'))
}
# Akati Score (0-100): Akati Doctor 40, startup apps 15, memory in use 15, ping 15, free space 15
# Startup apps that are on: counted in the background every 2 minutes (reading the shortcuts is slow),
# with the same functions as the Game boost page
function Get-StartupOnCount {
    if ($Screenshot) { return 3 }
    if (!$script:startupAt -or (Get-Date) -gt $script:startupAt) {
        $script:startupAt = (Get-Date).AddMinutes(2)
        $code = "param(`$approvedRoot)`r`n" + (@('Get-RegValue', 'Get-StartupItems', 'Test-StartupOn') | ForEach-Object { "function $_ {`r`n$((Get-Command $_).Definition)`r`n}" }) -join "`r`n"
        $code += "`r`n@(Get-StartupItems | Where-Object { Test-StartupOn `$_ }).Count"
        Start-Work ([scriptblock]::Create($code)) @($approvedRoot) { param($r) $n = Get-LastOutput $r; if ($n -is [int]) { $script:startupOn = $n } } $null
    }
    if ($null -eq $script:startupOn) { 3 } else { $script:startupOn }
}
function Get-AkatiScore {
    $r = $script:doctorResult
    if ($r -isnot [hashtable]) { return $null }
    $issues = @($doctorChecks | Where-Object { !$r[$_] -and $_ -notin @($r.skip) }).Count
    Get-ScorePoints $issues (Get-StartupOnCount) $stats.Ram $stats.Ping ([int]$r.diskFree)
}
function Get-ScoreBrush([int]$s) {
    if ($s -ge 80) { $window.FindResource('Good') } elseif ($s -ge 60) { $orange } else { (New-Object System.Windows.Media.BrushConverter).ConvertFromString('#FF453A') }
}
function Update-Score {
    $s = Get-AkatiScore
    if (!$s) { return }
    Save-ScoreDay $s.Score
    # The first score counts up; later ones (memory and ping change it) are set at once
    if ($ui.ScoreValue.Text -notmatch '^\d+$') { Start-CountUp $ui.ScoreValue $s.Score $numberText 900 }
    elseif (!(Test-Counting $ui.ScoreValue)) { $ui.ScoreValue.Text = [string]$s.Score }
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
            Initialize-Tweaks
            $t = $tweaks | Where-Object { $_.Key -eq 'maxperf' } | Select-Object -First 1
            if ($t -and $t.Toggle) { $t.Toggle.IsChecked = $true; Invoke-Tweak $t $true; Add-History $t.Key $true }
        }
        'disk' { $ui.NavCleaner.IsChecked = $true }
        'smart' { $ui.DiskSection.BringIntoView() }
        { $_ -in 'restart', 'hvci' } {
            if ((Show-Ask (T 'restart.ask') 'YesNo' 'Question') -eq 'Yes') { Restart-Computer -Force }
        }
        'devices' { Start-Process devmgmt.msc }
        'crash' { $ui.CrashList.BringIntoView() }
        'activation' { Start-Process 'ms-settings:activation' }
        'battery' { Start-Process 'ms-settings:powersleep' }
        'refresh' {
            $max = $script:doctorResult.hzMax
            $result = try { [AkatiOS.Perf]::SetHz($max) } catch { -1 }
            if ($result -eq 0) { Set-Status ((T 'status.refresh') -f $max) } else { Set-Status ((T 'status.refreshfail') -f $result) }
            Update-RefreshRow; Update-Chips; Start-Health
        }
        # The BIOS setting cannot be changed from Windows: how to turn it on
        'xmp' { [void](Show-Ask (T 'doc.xmp.howto') 'OK' 'Information') }
    }
}
# The number on Health in the sidebar: Akati Doctor findings and what Windows Update turned back on
function Update-HealthBadge {
    # (Screenshot mode: the sample of the Windows Update banner does not count, so the other shots stay as they were)
    $script:navBadges['Health'] = [int]$script:doctorBad + $(if ($Screenshot) { 0 } else { @($script:wuBack).Count })
    Update-NavBadges
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
    Start-DiskHealth; Update-RestoreInfo
    if ($Screenshot) { Show-Doctor (& $doctorWork); Show-HealthInfo (& $healthWork); return }
    $ui.DoctorRun.IsEnabled = $false; $ui.DoctorSummary.Text = T 'doc.checking'
    Start-Work $doctorWork @($logicFile) {
        param($r)
        Show-Doctor (Get-LastOutput $r); $ui.DoctorRun.IsEnabled = $true
        # Start here (Dashboard): Akati Doctor ran from this page
        if ($script:doctorResult -is [hashtable]) { Save-Setting DoctorRan ((Get-Date).ToString('s', [Globalization.CultureInfo]::InvariantCulture)) }
    } $null
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

# ---------------------------------------------------------------------------------------------
# Disk health: what each physical disk reports to Windows (Get-PhysicalDisk and Get-StorageReliabilityCounter, the
# SMART values Windows reads; needs administrator rights). A value a disk does not report shows as "not reported".
# ---------------------------------------------------------------------------------------------
$diskHealthWork = {
    $list = @()
    try { $disks = @(Get-PhysicalDisk -ErrorAction Stop) } catch { return @{ Error = $_.Exception.Message } }
    # $null: not reported
    $num = { param($v) if ($null -eq $v -or [string]$v -eq '') { $null } else { [double]$v } }
    foreach ($d in $disks) {
        $c = $null
        try { $c = $d | Get-StorageReliabilityCounter -ErrorAction Stop } catch { }
        $temp = if ($c) { & $num $c.Temperature } else { $null }
        # 0 °C is not a reading: the disk has no sensor or does not share it
        if ($null -ne $temp -and $temp -le 0) { $temp = $null }
        $list += @{ Name = ([string]$d.FriendlyName).Trim(); Size = [double]$d.Size; Bus = [string]$d.BusType; Media = [string]$d.MediaType
                    Health = [string]$d.HealthStatus; Status = (@($d.OperationalStatus) | ForEach-Object { [string]$_ }) -join ', '; Temp = $temp
                    Wear = $(if ($c) { & $num $c.Wear } else { $null }); Hours = $(if ($c) { & $num $c.PowerOnHours } else { $null })
                    ReadErrors = $(if ($c) { & $num $c.ReadErrorsTotal } else { $null }); WriteErrors = $(if ($c) { & $num $c.WriteErrorsUncorrected } else { $null }) }
    }
    @{ Disks = $list }
}
# Screenshot mode: sample disks (one of them worn out), not the disks of the CI runner
$diskSamples = @(
    @{ Name = 'Samsung SSD 980 PRO 1TB'; Size = 1000204886016; Bus = 'NVMe'; Media = 'SSD'; Health = 'Healthy'; Status = 'OK'; Temp = 41; Wear = 3; Hours = 2140; ReadErrors = 0; WriteErrors = 0 }
    @{ Name = 'WDC WD20EZBX-00AYRA0'; Size = 2000398934016; Bus = 'SATA'; Media = 'HDD'; Health = 'Healthy'; Status = 'OK'; Temp = 36; Wear = $null; Hours = 18210; ReadErrors = $null; WriteErrors = 0 }
    @{ Name = 'Kingston SA400S37480G'; Size = 480103981056; Bus = 'SATA'; Media = 'SSD'; Health = 'Warning'; Status = 'OK'; Temp = 52; Wear = 92; Hours = 26350; ReadErrors = 14; WriteErrors = 0 }
)
# Healthy (green), Warning (amber), Unhealthy (red), Unknown or not reported (gray)
function New-HealthBadge([string]$health) {
    $b = New-Object System.Windows.Controls.Border
    $b.CornerRadius = 6; $b.Padding = '8,2'; $b.BorderThickness = '1'; $b.VerticalAlignment = 'Center'; $b.Margin = '12,0,0,0'
    $back, $fore = switch ($health) { 'Healthy' { 'Fill', 'Good' } 'Warning' { 'WarnSoft', 'Warn' } 'Unhealthy' { 'DangerSoft', 'Danger' } default { 'Fill', 'MutedBrush' } }
    $b.SetResourceReference([System.Windows.Controls.Border]::BackgroundProperty, $back)
    $b.SetResourceReference([System.Windows.Controls.Border]::BorderBrushProperty, $back)
    $t = New-Text (T $(if ($health) { "smart.h.$($health.ToLowerInvariant())" } else { 'smart.notreported' })) 11.5 'SemiBold'
    $t.SetResourceReference([System.Windows.Controls.TextBlock]::ForegroundProperty, $fore)
    $b.Child = $t
    return $b
}
# One value of a disk card: a small label and the value (amber when $warn)
function New-DiskStat([string]$label, [string]$value, [bool]$warn = $false) {
    $s = New-Object System.Windows.Controls.StackPanel; $s.Margin = '0,0,12,0'
    $l = New-Text (T $label) 10.5; $l.Style = $window.FindResource('StatLabel')
    $v = New-Text $value 15 'SemiBold'; $v.Margin = '0,3,0,0'; $v.TextWrapping = 'NoWrap'; $v.TextTrimming = 'CharacterEllipsis'
    if ($warn) { $v.SetResourceReference([System.Windows.Controls.TextBlock]::ForegroundProperty, 'Warn') }
    [void]$s.Children.Add($l); [void]$s.Children.Add($v)
    return $s
}
function New-DiskCard($d) {
    $nr = T 'smart.notreported'
    $c = Get-LangCulture
    $card = New-Object System.Windows.Controls.Border
    $card.Style = $window.FindResource('Card'); $card.Margin = '0,0,0,10'
    $stack = New-Object System.Windows.Controls.StackPanel
    # Model, size and kind, health
    $top = New-Object System.Windows.Controls.DockPanel
    $box = New-Object System.Windows.Controls.Border; $box.Style = $window.FindResource('IconBox'); $box.Margin = '0,0,14,0'; $box.VerticalAlignment = 'Center'
    $g = New-Text ([string][char]0xEDA2) 15; $g.Style = $window.FindResource('TileGlyph'); $box.Child = $g
    [System.Windows.Controls.DockPanel]::SetDock($box, 'Left')
    $health = Get-DiskHealthName $d.Health
    $badge = New-HealthBadge $health
    [System.Windows.Controls.DockPanel]::SetDock($badge, 'Right')
    $names = New-Object System.Windows.Controls.StackPanel; $names.VerticalAlignment = 'Center'
    $title = New-Text $(if ($d.Name) { $d.Name } else { $nr }) 14 'SemiBold'; $title.TextWrapping = 'NoWrap'; $title.TextTrimming = 'CharacterEllipsis'
    $kind = Get-DiskKind $d.Bus $d.Media
    $parts = @($(if ($d.Size -gt 0) { Format-Size $d.Size } else { $nr }), $(if ($kind) { $kind } else { $nr }))
    if ($d.Status) { $parts += $d.Status }
    $sub = New-Text ($parts -join '  ·  ') 12; $sub.Style = $window.FindResource('Muted'); $sub.Margin = '0,2,0,0'
    [void]$names.Children.Add($title); [void]$names.Children.Add($sub)
    [void]$top.Children.Add($box); [void]$top.Children.Add($badge); [void]$top.Children.Add($names)
    [void]$stack.Children.Add($top)
    # Temperature, power-on time, errors
    $grid = New-Object System.Windows.Controls.Primitives.UniformGrid; $grid.Columns = 3; $grid.Margin = '0,14,0,0'
    $temp = if ($null -ne $d.Temp) { (T 'smart.temp.v') -f ([double]$d.Temp).ToString('0', $c) } else { $nr }
    [void]$grid.Children.Add((New-DiskStat 'smart.temp' $temp ($null -ne $d.Temp -and $d.Temp -ge 70)))
    $hours = if ($null -ne $d.Hours) { (T 'smart.hours.v') -f ([double]$d.Hours).ToString('N0', $c) } else { $nr }
    [void]$grid.Children.Add((New-DiskStat 'smart.hours' $hours))
    $errors = if ($null -eq $d.ReadErrors -and $null -eq $d.WriteErrors) { $nr } else {
        (T 'smart.errors.v') -f $(if ($null -ne $d.ReadErrors) { ([double]$d.ReadErrors).ToString('N0', $c) } else { $nr }), $(if ($null -ne $d.WriteErrors) { ([double]$d.WriteErrors).ToString('N0', $c) } else { $nr }) }
    [void]$grid.Children.Add((New-DiskStat 'smart.errors' $errors ([double]$d.ReadErrors -gt 0 -or [double]$d.WriteErrors -gt 0)))
    [void]$stack.Children.Add($grid)
    # Wear (percent used): SSDs and NVMe disks; hard disks do not wear out this way
    $wearRow = New-Object System.Windows.Controls.DockPanel; $wearRow.Margin = '0,14,0,0'
    $wl = New-Text (T 'smart.wear') 10.5; $wl.Style = $window.FindResource('StatLabel'); $wl.Width = 90; $wl.VerticalAlignment = 'Center'
    [System.Windows.Controls.DockPanel]::SetDock($wl, 'Left')
    $hasWear = $null -ne $d.Wear -and $kind -ne 'HDD'
    $wv = New-Text $(if ($hasWear) { '{0}%' -f [int]$d.Wear } elseif ($kind -eq 'HDD') { T 'smart.wear.hdd' } else { $nr }) 12
    $wv.Style = $window.FindResource('MonoText'); $wv.FontSize = 12; $wv.VerticalAlignment = 'Center'; $wv.Margin = '12,0,0,0'
    [System.Windows.Controls.DockPanel]::SetDock($wv, 'Right')
    [void]$wearRow.Children.Add($wl); [void]$wearRow.Children.Add($wv)
    if ($hasWear) {
        $bar = New-Object System.Windows.Controls.ProgressBar
        $bar.Style = $window.FindResource('Meter'); $bar.Height = 6; $bar.VerticalAlignment = 'Center'; $bar.Value = [Math]::Min(100, [Math]::Max(0, [double]$d.Wear))
        if ($d.Wear -ge 90) { $bar.SetResourceReference([System.Windows.Controls.Control]::ForegroundProperty, 'Danger') }
        elseif ($d.Wear -ge 70) { $bar.SetResourceReference([System.Windows.Controls.Control]::ForegroundProperty, 'Warn') }
        [void]$wearRow.Children.Add($bar)
    } else { [void]$wearRow.Children.Add((New-Object System.Windows.Controls.Border)) }
    [void]$stack.Children.Add($wearRow)
    # What Akati Doctor warns about
    foreach ($w in @(Get-DiskWarnings $d.Health $d.Wear $d.Temp)) {
        $wt = New-Text (T $w) 12.5; $wt.Margin = '0,10,0,0'
        $wt.SetResourceReference([System.Windows.Controls.TextBlock]::ForegroundProperty, 'Warn')
        [void]$stack.Children.Add($wt)
    }
    $card.Child = $stack
    return $card
}
function Show-DiskHealth($res) {
    $ui.DiskList.Children.Clear()
    $disks = @(if ($res -is [hashtable]) { $res.Disks | Where-Object { $_ } })
    if (!$disks.Count) {
        $ui.DiskEmpty.Text = if ($res -is [hashtable] -and $res.Error) { (T 'smart.error') -f $res.Error } elseif ($res -is [hashtable]) { T 'smart.none' } else { T 'smart.loading' }
        $ui.DiskEmpty.Visibility = 'Visible'
        return
    }
    $ui.DiskEmpty.Visibility = 'Collapsed'
    foreach ($d in $disks) { [void]$ui.DiskList.Children.Add((New-DiskCard $d)) }
}
function Start-DiskHealth {
    if ($Screenshot) { $script:diskResult = @{ Disks = $diskSamples }; Show-DiskHealth $script:diskResult; return }
    if ($script:diskBusy) { return }
    $script:diskBusy = $true
    if (!$script:diskResult) { Show-DiskHealth $null }
    Start-Work $diskHealthWork @() { param($r) $script:diskBusy = $false; $script:diskResult = Get-LastOutput $r; Show-DiskHealth $script:diskResult } $null
}

# ---------------------------------------------------------------------------------------------
# Restore points: the last one, a weekly task (off at first) and one before a Tweaks profile (on at first).
# Windows makes at most one restore point every 24 hours (SystemRestorePointCreationFrequency). Akati OS leaves that
# value as it is and shows a skipped one as skipped.
# ---------------------------------------------------------------------------------------------
$rpTaskName = 'Akati OS weekly restore point'
$rpResultKey = 'HKLM:\SOFTWARE\AkatiOS'
# What the weekly task runs as SYSTEM: the restore point, then its result for this page ("time|made|weekly").
# Only single quotes inside, because the task passes it in double quotes.
$rpTaskCommand = @(
    'try { $n = @(Get-ComputerRestorePoint -ErrorAction Stop).Count; Checkpoint-Computer -Description ''Akati OS weekly'' -RestorePointType MODIFY_SETTINGS -ErrorAction Stop -WarningAction SilentlyContinue; $r = if (@(Get-ComputerRestorePoint).Count -gt $n) { ''made'' } else { ''recent'' } } catch { $r = ''off'' }'
    '$k = ''HKLM:\SOFTWARE\AkatiOS''; if (!(Test-Path $k)) { New-Item -Path $k -Force | Out-Null }'
    'Set-ItemProperty -Path $k -Name RestoreResult -Value ((Get-Date).ToString(''s'') + ''|'' + $r + ''|weekly'')'
) -join '; '
$rpTaskWork = {
    param($on, $name, $command)
    try {
        if ($on) {
            $action = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument ('-NoProfile -NonInteractive -ExecutionPolicy Bypass -WindowStyle Hidden -Command "' + $command + '"')
            $trigger = New-ScheduledTaskTrigger -Weekly -DaysOfWeek Sunday -At ([datetime]::Today.AddHours(12))
            $principal = New-ScheduledTaskPrincipal -UserId 'SYSTEM' -LogonType ServiceAccount -RunLevel Highest
            # A PC that was off on Sunday at noon makes it at the next start
            $set = New-ScheduledTaskSettingsSet -StartWhenAvailable -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -ExecutionTimeLimit (New-TimeSpan -Minutes 30)
            Register-ScheduledTask -TaskPath '\AkatiOS\' -TaskName $name -Action $action -Trigger $trigger -Principal $principal -Settings $set -Description 'Akati OS Center: a restore point once a week' -Force -ErrorAction Stop | Out-Null
        } else {
            Unregister-ScheduledTask -TaskPath '\AkatiOS\' -TaskName $name -Confirm:$false -ErrorAction SilentlyContinue
        }
        'ok'
    } catch { $_.Exception.Message }
}
$rpInfoWork = {
    param($name, $key)
    $r = @{ Task = [bool](Get-ScheduledTask -TaskPath '\AkatiOS\' -TaskName $name -ErrorAction SilentlyContinue) }
    try {
        $last = @(Get-ComputerRestorePoint -ErrorAction Stop) | Sort-Object { [int64]$_.SequenceNumber } | Select-Object -Last 1
        if ($last) { $r.Time = [Management.ManagementDateTimeConverter]::ToDateTime($last.CreationTime); $r.Desc = [string]$last.Description }
    } catch { $r.Off = $true }
    $r.Result = [string](Get-ItemProperty -Path $key -Name RestoreResult -ErrorAction SilentlyContinue).RestoreResult
    $r
}
# The last try of Akati OS ("time|made, recent or off|weekly, profile or atlas"), from the task or this window
function Save-RestoreResult([string]$source, [string]$result) {
    $value = '{0}|{1}|{2}' -f (Get-Date).ToString('s', [Globalization.CultureInfo]::InvariantCulture), $result, $source
    if (!$Screenshot) {
        try {
            if (!(Test-Path $rpResultKey)) { New-Item -Path $rpResultKey -Force | Out-Null }
            Set-ItemProperty -Path $rpResultKey -Name RestoreResult -Value $value -Force
        } catch { }
    }
    if ($script:rpInfo -is [hashtable]) { $script:rpInfo.Result = $value }
    if ($script:healthLoaded) { Update-RestoreInfo }
}
function Show-RestoreInfo($r) {
    $script:rpInfo = $r
    if ($r -isnot [hashtable]) { $ui.RpLast.Text = T 'rp.loading'; $ui.RpResult.Visibility = 'Collapsed'; return }
    $c = Get-LangCulture
    $ui.RpLast.Text = if ($r.Time) { (T 'rp.last') -f ([datetime]$r.Time).ToString('d MMM yyyy HH:mm', $c), $r.Desc } elseif ($r.Off) { T 'rp.off' } else { T 'rp.none' }
    $ui.RpWeekly.IsChecked = [bool]$r.Task
    $time, $result, $source = ([string]$r.Result) -split '\|', 3
    $when = try { [datetime]::ParseExact($time, 's', [Globalization.CultureInfo]::InvariantCulture) } catch { $null }
    if ($when -and $result -in 'made', 'recent', 'off' -and $source -in 'weekly', 'profile', 'atlas') {
        $ui.RpResult.Text = (T 'rp.result') -f (T "rp.src.$source"), $when.ToString('d MMM HH:mm', $c), (T "rp.res.$result")
        $ui.RpResult.Visibility = 'Visible'
    } else { $ui.RpResult.Visibility = 'Collapsed' }
}
function Update-RestoreInfo {
    if ($Screenshot) {
        $inv = [Globalization.CultureInfo]::InvariantCulture
        Show-RestoreInfo @{ Task = $true; Time = (Get-Date).Date.AddDays(-1).AddHours(12); Desc = 'Akati OS weekly'
                            Result = '{0}|recent|profile' -f (Get-Date).Date.AddHours(9).ToString('s', $inv) }
        return
    }
    if (!$script:rpInfo) { Show-RestoreInfo $null }
    Start-Work $rpInfoWork @($rpTaskName, $rpResultKey) { param($r) Show-RestoreInfo (Get-LastOutput $r) } $null
}
$ui.RpProfile.IsChecked = (Get-RegValue $settingsKey 'ProfileRestore') -ne 0
$ui.RpProfile.Add_Click({ Save-Setting ProfileRestore ([int][bool]$this.IsChecked) })
$ui.RpWeekly.Add_Click({
    $on = [bool]$this.IsChecked
    $this.IsEnabled = $false
    Start-Work $rpTaskWork @($on, $rpTaskName, $rpTaskCommand) {
        param($r, $on)
        $ui.RpWeekly.IsEnabled = $true
        $msg = [string](Get-LastOutput $r)
        if ($msg -eq 'ok') { Set-Status (T $(if ($on) { 'rp.weekly.on' } else { 'rp.weekly.off' })) }
        else { $ui.RpWeekly.IsChecked = !$on; Set-Status ((T 'rp.taskfail') -f $msg) }
    } $on
})
$ui.RpOpen.Add_Click({ Start-Process SystemPropertiesProtection.exe })

# Change history: the last 30 changes made in Akati OS Center (and by a game profile of the icon next to the clock),
# newest first: "time|key|1 or 0" for a switch, and for other changes "time|svc:<service>|<start type>,<before>",
# "time|pol:<id>|<value>,<before>" ('' = no value) and "time|app:<package name>|removed"
function Add-History([string]$key, [bool]$on) {
    Add-HistoryLine $key ([string][int]$on)
    Update-WuTrackTweak $key $on
    if ($script:page -eq 'health') { Show-History }
}
function Add-ChangeHistory([string]$key, [string]$state) {
    Add-HistoryLine $key $state
    if ($script:page -eq 'health') { Show-History }
}
# A history row for a service, a policy or an app (Undo while it is still as the change left it; none for an app)
function New-ChangeRow([string]$kind, [string]$id, [string]$state) {
    $to, $from = "$state,".Split(',')[0, 1]
    $undo = New-Object System.Windows.Controls.Button
    $undo.Style = $window.FindResource('Pill'); $undo.Padding = '12,4'; $undo.Content = T 'toast.undo'
    switch ($kind) {
        'svc' {
            $title = (T 'history.svc') -f (Get-ServiceLabel $id); $glyph = 0xE912
            $sub = T $(if ($to -eq '4') { 'history.off' } else { 'history.on' })
            $undo.IsEnabled = $from -match '^[234]$' -and [string](Get-RegValue "$servicesKey\$id" 'Start') -eq $to
            $undo.Tag = @{ Id = $id; From = $from }
            $undo.Add_Click({ Set-ServiceStart $this.Tag.Id ([int]$this.Tag.From) })
        }
        'pol' {
            $title = T "wu.pol.$id"; $glyph = 0xE72E
            $sub = T $(if ($wuPolicies.Contains($id) -and $to -eq [string]$wuPolicies[$id].Value) { 'history.off' } else { 'history.on' })
            $d = $wuPolicies[$id]
            $undo.IsEnabled = $d -and [string](Get-RegValue $d.Path $d.Name) -eq $to
            $undo.Tag = @{ Id = $id; From = $from }
            $undo.Add_Click({ Set-WuPolicy $this.Tag.Id $this.Tag.From })
        }
        default {
            $title = (T 'history.app') -f $id; $glyph = 0xE74D; $sub = T 'history.removed'
            $undo = New-Object System.Windows.Controls.Border
        }
    }
    $row = New-Row ([string][char]$glyph) $title $null $undo $null
    $row.Sub.Text = $sub
    $row
}
function Show-History {
    Initialize-Tweaks
    $ui.HistoryList.Children.Clear()
    $c = & $getCulture
    foreach ($item in @(Get-RegValue $settingsKey 'History' | Where-Object { $_ })) {
        $time, $key, $state = $item -split '\|', 3
        $when = try { [datetime]::ParseExact($time, 's', [Globalization.CultureInfo]::InvariantCulture).ToString('d MMM HH:mm', $c) } catch { $time }
        if ($key -match '^(svc|pol|app):([\w.\-]+)$') {
            $row = New-ChangeRow $Matches[1] $Matches[2] $state
            $row.Sub.Text += ' · ' + $when
            [void]$ui.HistoryList.Children.Add($row.Row)
            continue
        }
        $t = $tweaks | Where-Object { $_.Key -eq $key } | Select-Object -First 1
        if (!$t -or !$t.Toggle) { continue }
        $on = $state -eq '1'
        $undo = New-Object System.Windows.Controls.Button
        $undo.Style = $window.FindResource('Pill'); $undo.Padding = '12,4'; $undo.Content = T 'toast.undo'; $undo.Tag = @{ Tweak = $t; On = $on }
        # Only while the switch is still as this change left it
        $undo.IsEnabled = $t.Toggle.IsEnabled -and ([bool]$t.Toggle.IsChecked -eq $on)
        $undo.Add_Click({ $u = $this.Tag; $back = !$u.On; $u.Tweak.Toggle.IsChecked = $back; Invoke-Tweak $u.Tweak $back; Add-History $u.Tweak.Key $back })
        $row = New-Row ([string]$t.Glyph) (T "tw.$key") $null $undo $null
        $row.Sub.Text = (T $(if ($on) { 'history.on' } else { 'history.off' })) + ' · ' + $when
        [void]$ui.HistoryList.Children.Add($row.Row)
    }
    $any = $ui.HistoryList.Children.Count -gt 0
    $ui.HistoryEmpty.Visibility = if ($any) { 'Collapsed' } else { 'Visible' }
    $ui.HistoryClear.Visibility = if ($any) { 'Visible' } else { 'Collapsed' }
    Update-Separators $ui.HistoryList
}
$ui.HistoryClear.Add_Click({ Remove-ItemProperty -Path $settingsKey -Name History -ErrorAction SilentlyContinue; Show-History })

# ---------------------------------------------------------------------------------------------
# Akati settings in one JSON file, to keep or to move to another PC: the settings of Akati OS Center (theme, accent,
# style preset, text size, Tweaks profile, process rules, badges and their dates, speed and score history...) with their
# registry type, My games and the game profiles. What belongs to this PC only stays out (Test-PortableSetting: window
# places, the change history, the Windows Update baseline, the state of running work). No hardware IDs: none of these
# values holds one. Import writes only to HKCU\Software\AkatiOS\Center and its Games and GameProfiles keys.
# Backup (below) adds the state of every switch to the same file and sets them when it is restored.
# ---------------------------------------------------------------------------------------------
$settingTypes = 'String', 'ExpandString', 'DWord', 'QWord', 'MultiString'
function Get-AkatiSettingsData {
    $data = [ordered]@{ AkatiOS = $version; Kind = 'settings'; Date = (Get-Date).ToString('s', [Globalization.CultureInfo]::InvariantCulture)
                        Settings = [ordered]@{}; Types = [ordered]@{}; Games = @(); Profiles = [ordered]@{} }
    if (Test-Path $settingsKey) {
        $key = Get-Item -Path $settingsKey
        foreach ($n in @($key.GetValueNames() | Sort-Object)) {
            if (!(Test-PortableSetting $n)) { continue }
            $kind = [string]$key.GetValueKind($n)
            if ($kind -notin $settingTypes) { continue }
            $data.Settings[$n] = $key.GetValue($n, $null, 'DoNotExpandEnvironmentNames')
            $data.Types[$n] = $kind
        }
    }
    if (Test-Path $gamesKey) { $data.Games = @((Get-Item $gamesKey).Property) }
    if (Test-Path $profilesKey) { foreach ($p in (Get-ItemProperty -Path $profilesKey).PSObject.Properties) { if ($p.Name -notlike 'PS*') { $data.Profiles[$p.Name] = $p.Value } } }
    $data
}
# A file of Export (Kind settings) or of Backup: $null when it is neither
function Read-AkatiSettingsFile([string]$file) {
    $data = try { [IO.File]::ReadAllText($file) | ConvertFrom-Json } catch { $null }
    if (!$data -or !$data.AkatiOS -or !$data.Settings) { return $null }
    $data
}
# What an import replaces, one line each (the dialog)
function Get-AkatiSettingsLines($data) {
    $n = @($data.Settings.PSObject.Properties | Where-Object { Test-PortableSetting $_.Name }).Count
    @(((T 'set.b.settings') -f $n), ((T 'set.b.games') -f @($data.Games | Where-Object { $_ }).Count), ((T 'set.b.profiles') -f @($data.Profiles.PSObject.Properties).Count))
}
# Writes the settings, adds the games (a game already in My games stays as it is) and sets the game profiles
function Restore-AkatiSettings($data) {
    if (!(Test-Path $settingsKey)) { New-Item -Path $settingsKey -Force | Out-Null }
    $types = $data.Types
    foreach ($p in @($data.Settings.PSObject.Properties)) {
        if (!(Test-PortableSetting $p.Name)) { continue }
        $v = $p.Value
        $kind = if ($types -and $types.($p.Name) -in $settingTypes) { [string]$types.($p.Name) }
                elseif ($v -is [array]) { 'MultiString' } elseif ($v -is [int] -or $v -is [long]) { 'DWord' } else { 'String' }
        if ($null -eq $v) { continue }
        $value = switch ($kind) { 'MultiString' { [string[]]@($v) } 'DWord' { [int]$v } 'QWord' { [long]$v } default { [string]$v } }
        Set-ItemProperty -Path $settingsKey -Name $p.Name -Value $value -Type $kind -Force
    }
    if (@($data.Games | Where-Object { $_ }).Count) {
        if (!(Test-Path $gamesKey)) { New-Item -Path $gamesKey -Force | Out-Null }
        foreach ($g in @($data.Games)) { if ($g -and $null -eq (Get-RegValue $gamesKey $g)) { Set-ItemProperty -Path $gamesKey -Name $g -Value 1 -Type DWord -Force } }
    }
    foreach ($p in @($data.Profiles.PSObject.Properties)) {
        if (!(Test-Path $profilesKey)) { New-Item -Path $profilesKey -Force | Out-Null }
        Set-ItemProperty -Path $profilesKey -Name $p.Name -Value ([int]$p.Value) -Type DWord -Force
    }
}
# After an import: the pages that show these settings, then the theme and accent of the file if wanted (Use-Accent
# also sets the Windows accent color, as the Appearance page does)
function Update-AfterImport($data) {
    Show-Games; Show-Rules; Show-Badges; Update-ProfileTiles; Show-SpeedResults; Show-ScoreChart; Update-Week
    Request-MenuUpdate
    if ($data.Settings.Language -in $languages.Keys -and $data.Settings.Language -ne $lang) { Set-AppLanguage $data.Settings.Language }
    $s = $data.Settings
    $hasLook = [string]$s.CenterLook -in 'auto', 'dark', 'light', 'time'
    $acc = $accents | Where-Object { $_.Key -eq [string]$s.Accent } | Select-Object -First 1
    $hasAccent = $acc -or ([string]$s.Accent -eq 'wallpaper' -and $null -ne $s.AccentHue)
    if (($hasLook -or $hasAccent) -and (Show-Ask (T 'set.reapply') 'YesNo' 'Question') -eq 'Yes') {
        if ($hasLook) { $ui["Look$([Globalization.CultureInfo]::InvariantCulture.TextInfo.ToTitleCase([string]$s.CenterLook))"].IsChecked = $true; Set-CenterLook (Get-LookName) }
        if ($acc) { Use-Accent $acc }
        elseif ($hasAccent) { $wallSwatch.IsChecked = $true; Use-Accent (New-HueAccent ([double]$s.AccentHue)) }
        if ([int]$s.Zoom -in $zoomSteps) { $ui["Zoom$([int]$s.Zoom)"].IsChecked = $true }
    }
}
$ui.SettingsExport.Add_Click({
    $d = New-Object Microsoft.Win32.SaveFileDialog
    $d.Filter = 'Akati OS settings (*.json)|*.json'; $d.FileName = "AkatiOS-settings-$(Get-Date -Format yyyy-MM-dd).json"
    if (!$d.ShowDialog($window)) { return }
    try {
        [IO.File]::WriteAllText($d.FileName, (Get-AkatiSettingsData | ConvertTo-Json -Depth 5), (New-Object System.Text.UTF8Encoding $false))
        Set-Status ((T 'set.saved') -f (Split-Path $d.FileName -Leaf))
    } catch { Set-Status $_.Exception.Message }
})
$ui.SettingsImport.Add_Click({
    $d = New-Object Microsoft.Win32.OpenFileDialog
    $d.Filter = 'Akati OS settings (*.json)|*.json'
    if (!$d.ShowDialog($window)) { return }
    $data = Read-AkatiSettingsFile $d.FileName
    if (!$data) { Set-Status (T 'backup.bad'); return }
    if ((Show-Ask (T 'set.ask') 'YesNo' 'Question' (Get-AkatiSettingsLines $data) (T 'set.note')) -ne 'Yes') { return }
    try { Restore-AkatiSettings $data } catch { Set-Status $_.Exception.Message; return }
    Set-Status (T 'set.done')
    Update-AfterImport $data
})

# Backup: the Akati settings above and the state of every switch, in one JSON file; Restore also sets the switches
$ui.BackupSave.Add_Click({
    Initialize-Tweaks
    $d = New-Object Microsoft.Win32.SaveFileDialog
    $d.Filter = 'Akati OS backup (*.json)|*.json'; $d.FileName = "AkatiOS-backup-$(Get-Date -Format yyyy-MM-dd).json"
    if (!$d.ShowDialog($window)) { return }
    $data = Get-AkatiSettingsData
    $data.Kind = 'backup'; $data.Tweaks = [ordered]@{}
    # Slow switches (Microsoft Store) are left out
    foreach ($t in $tweaks) { if ($t.Toggle -and $t.Toggle.IsEnabled -and !$t.Slow -and $null -ne $t.Toggle.IsChecked) { $data.Tweaks[$t.Key] = [bool]$t.Toggle.IsChecked } }
    try {
        [IO.File]::WriteAllText($d.FileName, ($data | ConvertTo-Json -Depth 5), (New-Object System.Text.UTF8Encoding $false))
        Set-Status ((T 'backup.saved') -f (Split-Path $d.FileName -Leaf))
    } catch { Set-Status $_.Exception.Message }
})
$ui.BackupLoad.Add_Click({
    Initialize-Tweaks
    $d = New-Object Microsoft.Win32.OpenFileDialog
    $d.Filter = 'Akati OS backup (*.json)|*.json'
    if (!$d.ShowDialog($window)) { return }
    $data = Read-AkatiSettingsFile $d.FileName
    if (!$data) { Set-Status (T 'backup.bad'); return }
    if ((Show-Ask (T 'backup.ask') 'YesNo' 'Question' (Get-AkatiSettingsLines $data)) -ne 'Yes') { return }
    try { Restore-AkatiSettings $data } catch { Set-Status $_.Exception.Message; return }
    $changed = 0
    foreach ($p in @($data.Tweaks.PSObject.Properties)) {
        $t = $tweaks | Where-Object { $_.Key -eq $p.Name } | Select-Object -First 1
        if (!$t -or !$t.Toggle -or !$t.Toggle.IsEnabled -or [bool]$t.Toggle.IsChecked -eq [bool]$p.Value) { continue }
        $t.Toggle.IsChecked = [bool]$p.Value; Invoke-Tweak $t ([bool]$p.Value); Add-History $t.Key ([bool]$p.Value)
        $changed++
    }
    Set-Status ((T 'backup.restored') -f $changed)
    Update-AfterImport $data
})

# ---------------------------------------------------------------------------------------------
# Share score: a 1200 x 630 picture of the Akati Score and the PC (no PC or user name), saved to
# Pictures\Akati OS and copied to the clipboard, ready to paste in Discord or a chat
# ---------------------------------------------------------------------------------------------
function New-ScoreCard {
    $brush = { param($hex) [System.Windows.Media.SolidColorBrush]::new([System.Windows.Media.ColorConverter]::ConvertFromString($hex)) }
    $card = New-Object System.Windows.Controls.Border
    $card.Width = 1200; $card.Height = 630
    # A Border has no font of its own: the texts inside take the font of the window through TextElement
    [System.Windows.Documents.TextElement]::SetFontFamily($card, $window.FontFamily)
    $card.Background = [System.Windows.Media.LinearGradientBrush]::new([System.Windows.Media.ColorConverter]::ConvertFromString('#1E1230'), [System.Windows.Media.ColorConverter]::ConvertFromString('#0E0E12'), 45)
    $grid = New-Object System.Windows.Controls.Grid
    # Soft glow in the accent color behind the score
    $glow = New-Object System.Windows.Shapes.Ellipse
    $glow.Width = 620; $glow.Height = 620; $glow.HorizontalAlignment = 'Left'; $glow.VerticalAlignment = 'Center'; $glow.Margin = '-120,0,0,0'
    $glow.Fill = $window.FindResource('Accent2'); $glow.Opacity = 0.16
    $glow.Effect = New-Object System.Windows.Media.Effects.BlurEffect -Property @{ Radius = 160 }
    [void]$grid.Children.Add($glow)
    $cols = New-Object System.Windows.Controls.Grid; $cols.Margin = '80,70'
    foreach ($w in '420', '*') { $c = New-Object System.Windows.Controls.ColumnDefinition; $c.Width = $w; $cols.ColumnDefinitions.Add($c) }
    # Left: logo, score, title
    $left = New-Object System.Windows.Controls.StackPanel; $left.VerticalAlignment = 'Center'
    $brand = New-Object System.Windows.Controls.StackPanel; $brand.Orientation = 'Horizontal'
    $logo = New-Object System.Windows.Controls.Image; $logo.Source = Get-Image $logoPath 128; $logo.Width = 48; $logo.Height = 48; $logo.Margin = '0,0,14,0'
    $name = New-Text 'AKATI OS' 30 'Bold'; $name.Foreground = & $brush '#FFFFFF'; $name.VerticalAlignment = 'Center'
    [void]$brand.Children.Add($logo); [void]$brand.Children.Add($name)
    $score = New-Text $ui.ScoreValue.Text 190 'Bold'; $score.Foreground = $ui.ScoreValue.Foreground; $score.Margin = '0,10,0,-20'
    $label = New-Text 'AKATI SCORE' 22 'SemiBold'; $label.Foreground = & $brush '#B9B9C2'
    $title = New-Text $ui.ScoreTitle.Text 28 'SemiBold'; $title.Foreground = & $brush '#FFFFFF'; $title.Margin = '0,10,0,0'
    foreach ($x in $brand, $score, $label, $title) { [void]$left.Children.Add($x) }
    # Right: the PC
    $right = New-Object System.Windows.Controls.StackPanel; $right.VerticalAlignment = 'Center'; $right.Margin = '40,0,0,0'
    [System.Windows.Controls.Grid]::SetColumn($right, 1)
    $rows = @(@('CPU', $ui.CpuName.Text), @('GPU', $ui.GpuName.Text), @('RAM', $ui.RamName.Text), @('Windows', $ui.OsLine.Text), @('Ping', $ui.NetPing.Text))
    foreach ($r in $rows) {
        if (!$r[1] -or $r[1] -eq '-') { continue }
        $k = New-Text $r[0].ToUpperInvariant() 16 'SemiBold'; $k.Foreground = & $brush '#9A8CB8'; $k.Margin = '0,14,0,2'
        $v = New-Text $r[1] 26 'SemiBold'; $v.Foreground = & $brush '#F5F5F7'; $v.TextTrimming = 'CharacterEllipsis'; $v.TextWrapping = 'NoWrap'
        [void]$right.Children.Add($k); [void]$right.Children.Add($v)
    }
    $foot = New-Text ("Akati OS $version  ·  " + (Get-Date).ToString('d MMM yyyy', (Get-LangCulture))) 16; $foot.Foreground = & $brush '#8E8E96'; $foot.Margin = '0,26,0,0'
    [void]$right.Children.Add($foot)
    [void]$cols.Children.Add($left); [void]$cols.Children.Add($right)
    [void]$grid.Children.Add($cols)
    # Accent line along the bottom
    $line = New-Object System.Windows.Controls.Border; $line.Height = 8; $line.VerticalAlignment = 'Bottom'
    $line.Background = $window.FindResource('AccentGradient')
    [void]$grid.Children.Add($line)
    $card.Child = $grid
    $size = New-Object System.Windows.Size 1200, 630
    $card.Measure($size); $card.Arrange((New-Object System.Windows.Rect $size)); $card.UpdateLayout()
    $bmp = New-Object System.Windows.Media.Imaging.RenderTargetBitmap 1200, 630, 96, 96, ([System.Windows.Media.PixelFormats]::Pbgra32)
    $bmp.Render($card)
    $bmp.Freeze()
    $bmp
}
function Save-ScoreCard([string]$file) {
    $bmp = New-ScoreCard
    $enc = New-Object System.Windows.Media.Imaging.PngBitmapEncoder
    $enc.Frames.Add([System.Windows.Media.Imaging.BitmapFrame]::Create($bmp))
    $fs = [IO.File]::Create($file)
    try { $enc.Save($fs) } finally { $fs.Close() }
    $bmp
}
$ui.ScoreShare.Add_Click({
    if ($ui.ScoreValue.Text -notmatch '^\d+$') { Set-Status (T 'score.share.wait'); return }
    try {
        $dir = Join-Path ([Environment]::GetFolderPath('MyPictures')) 'Akati OS'
        if (!(Test-Path -LiteralPath $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
        $file = Join-Path $dir ('Akati Score {0}.png' -f (Get-Date).ToString('yyyy-MM-dd HHmm'))
        $bmp = Save-ScoreCard $file
        try { [System.Windows.Clipboard]::SetImage($bmp) } catch { }
        Start-Process explorer.exe -ArgumentList "/select,`"$file`""
        Set-Status (T 'score.share.done')
    } catch { Set-Status $_.Exception.Message }
})
