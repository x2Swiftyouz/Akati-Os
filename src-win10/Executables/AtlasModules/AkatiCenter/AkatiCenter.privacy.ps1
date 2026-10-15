<#
.SYNOPSIS
    Akati OS Center: Privacy status (Tweaks, read only) and the check for what Windows Update turned back on (Health).
    Dot-sourced by AkatiCenter.ps1 (runs in its scope: $ui, $window, T and the other parts).
#>
# ---------------------------------------------------------------------------------------------
# Privacy status: what Windows may collect right now, read from the registry and the DiagTrack service. Nothing here
# changes a setting: Change opens the matching AtlasOS setting on the Tweaks page, Settings the Windows Settings page.
# ---------------------------------------------------------------------------------------------
Add-Mark 'Privacy status and Windows Update check'
$privacyItems = @(
    @{ Id = 'telemetry'; Glyph = 0xE9D9; Settings = 'ms-settings:privacy-feedback' }
    @{ Id = 'adid'; Glyph = 0xE8EC; Settings = 'ms-settings:privacy-general' }
    @{ Id = 'location'; Glyph = 0xE81D; Atlas = 'Location' }
    @{ Id = 'activity'; Glyph = 0xE81C; Settings = 'ms-settings:privacy-activityhistory' }
    @{ Id = 'recall'; Glyph = 0xE722; Atlas = 'Recall'; Build = 26100 }
    @{ Id = 'copilot'; Glyph = 0xE8BD; Atlas = 'Microsoft Copilot'; Build = 22000 }
    @{ Id = 'tailored'; Glyph = 0xE946; Settings = 'ms-settings:privacy-feedback' }
    @{ Id = 'speech'; Glyph = 0xE720; Settings = 'ms-settings:privacy-speech' }
    @{ Id = 'appdiag'; Glyph = 0xE71D; Settings = 'ms-settings:privacy-appdiagnostics' }
)
$consentKey = 'SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore'
function Get-PrivacyValues {
    $v = @{
        AllowTelemetry  = Get-RegValue 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection' 'AllowTelemetry'
        AllowTelemetry2 = Get-RegValue 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\DataCollection' 'AllowTelemetry'
        DiagTrackStart  = Get-RegValue "$servicesKey\DiagTrack" 'Start'
        AdEnabled       = Get-RegValue 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\AdvertisingInfo' 'Enabled'
        AdPolicy        = Get-RegValue 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\AdvertisingInfo' 'DisabledByGroupPolicy'
        LocationPolicy  = Get-RegValue 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\LocationAndSensors' 'DisableLocation'
        LocationMachine = Get-RegValue "HKLM:\$consentKey\location" 'Value'
        LocationUser    = Get-RegValue "HKCU:\$consentKey\location" 'Value'
        ActivityFeed    = Get-RegValue 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\System' 'EnableActivityFeed'
        PublishActivities = Get-RegValue 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\System' 'PublishUserActivities'
        RecallMachine   = Get-RegValue 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsAI' 'DisableAIDataAnalysis'
        RecallUser      = Get-RegValue 'HKCU:\SOFTWARE\Policies\Microsoft\Windows\WindowsAI' 'DisableAIDataAnalysis'
        RecallAllow     = Get-RegValue 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsAI' 'AllowRecallEnablement'
        CopilotUser     = Get-RegValue 'HKCU:\Software\Policies\Microsoft\Windows\WindowsCopilot' 'TurnOffWindowsCopilot'
        CopilotMachine  = Get-RegValue 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsCopilot' 'TurnOffWindowsCopilot'
        Tailored        = Get-RegValue 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Privacy' 'TailoredExperiencesWithDiagnosticDataEnabled'
        TailoredPolicy  = Get-RegValue 'HKCU:\SOFTWARE\Policies\Microsoft\Windows\CloudContent' 'DisableTailoredExperiencesWithDiagnosticData'
        SpeechAccepted  = Get-RegValue 'HKCU:\SOFTWARE\Microsoft\Speech_OneCore\Settings\OnlineSpeechPrivacy' 'HasAccepted'
        SpeechPolicy    = Get-RegValue 'HKLM:\SOFTWARE\Policies\Microsoft\InputPersonalization' 'AllowInputPersonalization'
        AppDiagPolicy   = Get-RegValue 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\AppPrivacy' 'LetAppsGetDiagnosticInfo'
        AppDiagMachine  = Get-RegValue "HKLM:\$consentKey\appDiagnostics" 'Value'
        AppDiagUser     = Get-RegValue "HKCU:\$consentKey\appDiagnostics" 'Value'
    }
    $v.DiagTrackStatus = try { [string](Get-Service -Name DiagTrack -ErrorAction Stop).Status } catch { '' }
    $v
}
# Screenshot mode: a sample PC (Akati OS defaults, with location and online speech left on), not the CI runner
$privacySample = @{ AllowTelemetry = 0; DiagTrackStart = 4; DiagTrackStatus = 'Stopped'; AdEnabled = 0; AdPolicy = 1; LocationMachine = 'Allow'
                    ActivityFeed = 0; PublishActivities = 0; RecallMachine = 1; CopilotUser = 1; Tailored = 0; TailoredPolicy = 1; SpeechAccepted = 1
                    AppDiagMachine = 'Deny' }
# A small green "Off" or amber "On"
function New-PrivacyBadge([bool]$off) {
    $b = New-Object System.Windows.Controls.Border
    $b.CornerRadius = 6; $b.Padding = '9,2'; $b.BorderThickness = '1'; $b.VerticalAlignment = 'Center'; $b.MinWidth = 44
    $back, $fore = if ($off) { 'Fill', 'Good' } else { 'WarnSoft', 'Warn' }
    $b.SetResourceReference([System.Windows.Controls.Border]::BackgroundProperty, $back)
    $b.SetResourceReference([System.Windows.Controls.Border]::BorderBrushProperty, $back)
    $t = New-Text (T $(if ($off) { 'privacy.off' } else { 'privacy.on' })) 11.5 'SemiBold'; $t.HorizontalAlignment = 'Center'
    $t.SetResourceReference([System.Windows.Controls.TextBlock]::ForegroundProperty, $fore)
    $b.Child = $t
    $b
}
function Get-PrivacyNote([string]$id, [bool]$off, $v) {
    if ($off -or $id -ne 'telemetry') { return T "privacy.$id.$(if ($off) { 'off' } else { 'on' })" }
    $policy = @($v.AllowTelemetry, $v.AllowTelemetry2) | Where-Object { $null -ne $_ } | Select-Object -First 1
    $level = if ($null -ne $policy) { [string]$policy } else { T 'privacy.notset' }
    $svc = if ([int]$v.DiagTrackStart -eq 4) { 'disabled' } elseif ($v.DiagTrackStatus -eq 'Running') { 'running' } elseif ($v.DiagTrackStatus) { 'stopped' } else { 'missing' }
    (T 'privacy.telemetry.on') -f $level, (T "privacy.svc.$svc")
}
function Show-Privacy {
    $v = if ($Screenshot) { $privacySample } else { Get-PrivacyValues }
    $ui.PrivacyList.Children.Clear()
    foreach ($p in $privacyItems) {
        if ($p.Build -and $build -lt $p.Build -and !$Screenshot) { continue }
        $off = [bool](Test-PrivacyOff $p.Id $v)
        $right = New-Object System.Windows.Controls.StackPanel; $right.Orientation = 'Horizontal'
        [void]$right.Children.Add((New-PrivacyBadge $off))
        $go = New-Object System.Windows.Controls.Button
        $go.Style = $window.FindResource('Pill'); $go.Padding = '12,4'; $go.Margin = '10,0,0,0'; $go.MinWidth = 0; $go.Tag = $p
        $go.Content = T $(if ($p.Atlas) { 'privacy.change' } else { 'privacy.settings' })
        $go.ToolTip = T $(if ($p.Atlas) { 'privacy.change.tip' } else { 'privacy.settings.tip' })
        $go.Add_Click({ $p = $this.Tag; if ($p.Atlas) { Show-AtlasSetting $p.Atlas } else { Start-Process $p.Settings } })
        [void]$right.Children.Add($go)
        $row = New-Row ([string][char]$p.Glyph) (T "privacy.$($p.Id)") $null $right $null
        $row.Sub.Text = Get-PrivacyNote $p.Id $off $v
        [void]$ui.PrivacyList.Children.Add($row.Row)
    }
    Update-Separators $ui.PrivacyList
}
# Opens an AtlasOS setting on the Tweaks page: the System list filtered to it, the row scrolled into view
function Show-AtlasSetting([string]$folder) {
    if (!$ui.SystemList.Children.Count) { Show-SystemList }
    $ui.SystemSearch.Text = $folder
    $row = $null
    foreach ($c in $script:systemCards) { foreach ($r in $c.Rows) { if (!$row -and $r.Visibility -eq 'Visible') { $row = $r } } }
    if ($row) { Show-Element 'tweaks' $row } else { $ui.NavTweaks.IsChecked = $true }
}
$ui.PrivacyRefresh.Add_Click({ Show-Privacy })

# ---------------------------------------------------------------------------------------------
# After Windows Update: a baseline of what Akati OS and AtlasOS turned off (WuBaseline, see ConvertFrom-WuEntry), made
# once from the state of this PC: the services of the lists below that are off, the apps the setup removed and the
# policies with the Akati OS value. Each start compares it with the PC (and the icon next to the clock once a week, read
# only). What the user turns on in Akati OS Center is kept in WuKeep and never listed; what Akati OS Center turns off
# joins the baseline.
# ---------------------------------------------------------------------------------------------
$sharedFile = Join-Path $appDir 'AkatiCenter.shared.ps1'
$wuSeedServices = [string[]]@(@($serviceGroups.Values | ForEach-Object { $_.Keys }) + @('DiagTrack', 'dmwappushservice', 'TrkWks', 'PcaSvc', 'WerSvc',
    'wercplsupport', 'UCPD', 'diagnosticshub.standardcollector.service', 'MSDTC', 'SysMain', 'WSearch', 'RemoteRegistry'))
# The Tweaks switches that turn services off ($serviceGroups) and the AtlasOS settings (folder) for baseline entries
$wuTweakServices = @{ extrasvc = 'extra'; svcxbox = 'xbox'; svciphelper = 'iphelper'; svchello = 'hello'; svcscanner = 'scanner'; svchotspot = 'hotspot'
                      svcnotify = 'notify'; svccdp = 'cdp'; svcprint = 'print'; svcbt = 'bluetooth'; svcwu = 'wu'; svctime = 'time'; svcdo = 'dosvc' }
$wuAtlasKeys = @{ 'Recall' = @('pol:recall'); 'Microsoft Copilot' = @('pol:copilot'); 'Printing' = @('svc:Spooler', 'svc:PrintNotify'); 'Superfetch' = @('svc:SysMain')
                  'Search Indexing' = @('svc:WSearch'); 'Bluetooth' = @('svc:bthserv', 'svc:BTAGService', 'svc:BthAvctpSvc'); 'Microsoft Store' = @('app:Microsoft.WindowsStore') }
function Save-List([string]$name, [string[]]$list) {
    if (@($list | Where-Object { $_ }).Count) { Save-Setting $name ([string[]]@($list | Where-Object { $_ })) }
    else { Remove-ItemProperty -Path $settingsKey -Name $name -ErrorAction SilentlyContinue }
}
# $userOn: the user turned these on in Akati OS Center (never turn them off again); else Akati OS Center turned them off
function Update-WuTrack([string[]]$keys, [bool]$userOn) {
    if ($Screenshot) { return }
    $keep = @(Get-RegValue $settingsKey 'WuKeep' | Where-Object { $_ })
    $base = @(Get-RegValue $settingsKey 'WuBaseline' | Where-Object { $_ })
    $seeded = [bool](Get-RegValue $settingsKey 'WuSeeded')
    foreach ($k in $keys) {
        $p = ConvertFrom-WuEntry $k
        if (!$p) { continue }
        if ($userOn) { if ($k -notin $keep) { $keep += $k }; continue }
        $keep = @($keep | Where-Object { $_ -ne $k })
        if (!$seeded) { continue }
        $entry = switch ($p.Kind) { 'svc' { "$k=4" } 'pol' { "$k=$($wuPolicies[$p.Id].Value)" } default { $k } }
        $base = Set-WuEntry $base $entry
    }
    Save-List WuKeep $keep
    if ($seeded) { Save-List WuBaseline $base }
}
# Called by Add-History for every switch change
function Update-WuTrackTweak([string]$key, [bool]$on) {
    if ($wuTweakServices.ContainsKey($key)) { Update-WuTrack ([string[]]@($serviceGroups[$wuTweakServices[$key]].Keys | ForEach-Object { "svc:$_" })) (!$on) }
    elseif ($key -eq 'store') { Update-WuTrack @('app:Microsoft.WindowsStore') $on }
}
# Called when an AtlasOS setting runs from the Tweaks page: Enable / Allow / Install turn on, Disable / Remove turn off
function Update-WuTrackAtlas([IO.FileInfo]$file) {
    $keys = $wuAtlasKeys[$file.Directory.Name]
    if (!$keys -or $file.BaseName -notmatch '^(\w+)') { return }
    $verb = $Matches[1]
    if ($verb -in 'Enable', 'Allow', 'Install', 'Show') { Update-WuTrack $keys $true }
    elseif ($verb -in 'Disable', 'Remove', 'Uninstall', 'Hide') { Update-WuTrack $keys $false }
}
# A policy of $wuPolicies set to $value ('' removes it), with history and Undo in the change history
function Set-WuPolicy([string]$id, [string]$value) {
    $d = $wuPolicies[$id]
    if (!$d) { return }
    $from = [string](Get-RegValue $d.Path $d.Name)
    try {
        if ($value -eq '') { Remove-ItemProperty -Path $d.Path -Name $d.Name -ErrorAction SilentlyContinue }
        else {
            if (!(Test-Path $d.Path)) { New-Item -Path $d.Path -Force | Out-Null }
            Set-ItemProperty -Path $d.Path -Name $d.Name -Value ([int]$value) -Type DWord -Force
        }
    } catch { Set-Status $_.Exception.Message; return }
    Add-ChangeHistory "pol:$id" "$value,$from"
    Update-WuTrack @("pol:$id") ($value -ne [string]$d.Value)
}
$wuCheckWork = {
    param($logic, $shared, [string[]]$baseline, [string[]]$seed)
    . $logic; . $shared
    $seeded = $false
    if ($seed.Count) { $baseline = New-WuBaseline $seed; $seeded = $true }
    $now = Read-WuCurrent $baseline
    $names = @{}
    foreach ($e in @($baseline)) {
        $p = ConvertFrom-WuEntry $e
        if ($p -and $p.Kind -eq 'svc') { try { $names[$p.Id] = [string](Get-Service -Name $p.Id -ErrorAction Stop).DisplayName } catch { } }
    }
    @{ Baseline = [string[]]@($baseline); Seeded = $seeded; Now = $now; Names = $names }
}
$script:wuBack = @(); $script:wuNames = @{}
function Get-WuItemText($f) {
    switch ($f.Kind) {
        'svc' { (T 'wuback.svc') -f $(if ($script:wuNames[$f.Id]) { $script:wuNames[$f.Id] } else { $f.Id }) }
        'app' { (T 'wuback.app') -f $f.Id }
        default { (T 'wuback.pol') -f (T "wu.pol.$($f.Id)") }
    }
}
function Show-WuBack($found) {
    $script:wuBack = @($found | Where-Object { $_ })
    $ui.WuBackList.Children.Clear()
    foreach ($f in $script:wuBack) {
        $t = New-Text ([string][char]0x2022 + '  ' + (Get-WuItemText $f)) 13; $t.Margin = '0,1,0,1'; $t.TextWrapping = 'Wrap'
        [void]$ui.WuBackList.Children.Add($t)
    }
    $ui.WuBackSub.Text = (T 'wuback.sub') -f $script:wuBack.Count
    $ui.WuBackCard.Visibility = if ($script:wuBack.Count) { 'Visible' } else { 'Collapsed' }
    Update-HealthBadge
}
# Screenshot mode: a sample of what a feature update can turn back on
$wuSample = @((ConvertFrom-WuEntry 'svc:DiagTrack=4'), (ConvertFrom-WuEntry 'svc:MapsBroker=4'), (ConvertFrom-WuEntry 'app:Microsoft.BingNews'), (ConvertFrom-WuEntry 'pol:recall=1'))
function Start-WuCheck([switch]$Manual) {
    if ($Screenshot) { $script:wuNames = @{ DiagTrack = 'Connected User Experiences and Telemetry'; MapsBroker = 'Downloaded Maps Manager' }; Show-WuBack $wuSample; return }
    $base = [string[]]@(Get-RegValue $settingsKey 'WuBaseline' | Where-Object { $_ })
    $seed = if (!(Get-RegValue $settingsKey 'WuSeeded')) { $wuSeedServices } else { [string[]]@() }
    Start-Work $wuCheckWork @($logicFile, $sharedFile, $base, $seed) {
        param($r, $manual)
        $res = Get-LastOutput $r
        if ($res -isnot [hashtable]) { return }
        if ($res.Seeded) { Save-Setting WuSeeded 1; Save-List WuBaseline $res.Baseline }
        $script:wuNames = $res.Names
        $keep = [string[]]@(Get-RegValue $settingsKey 'WuKeep' | Where-Object { $_ })
        $found = @(Compare-WuBaseline $res.Baseline $res.Now $keep)
        Show-WuBack $found
        if ($manual -and !$found.Count) { Set-Status (T 'wuback.none') }
    } ([bool]$Manual)
}
# Apps are removed in the background, for every user, like the Microsoft Store switch
$wuRemoveAppsWork = {
    param([string[]]$names)
    foreach ($n in $names) {
        Get-AppxPackage -AllUsers -Name $n -ErrorAction SilentlyContinue | Remove-AppxPackage -AllUsers -ErrorAction SilentlyContinue
        Get-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue | Where-Object { $_.DisplayName -eq $n } | Remove-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue | Out-Null
    }
}
$ui.WuBackFix.Add_Click({
    $items = @($script:wuBack)
    if (!$items.Count) { return }
    $lines = @($items | ForEach-Object { Get-WuItemText $_ })
    if ((Show-Ask (T 'wuback.ask') 'YesNo' 'Question' $lines (T 'wuback.note')) -ne 'Yes') { return }
    $apps = @(); $services = $false
    foreach ($f in $items) {
        switch ($f.Kind) {
            'svc' { Set-ServiceStart $f.Id 4 -Quiet; $services = $true }
            'pol' { Set-WuPolicy $f.Id ([string]$wuPolicies[$f.Id].Value) }
            'app' {
                if ($f.Id -eq 'Microsoft.WindowsStore') {
                    Initialize-Tweaks
                    $t = Find-Tweak 'store'
                    if ($t -and $t.Toggle) { $t.Toggle.IsChecked = $false; Invoke-Tweak $t $false; Add-History 'store' $false }
                } else { $apps += $f.Id }
            }
        }
    }
    if ($services) { Set-RestartNeeded }
    $msg = (T 'wuback.done') -f $items.Count
    Set-Status $msg; Add-Log 'TweakLog' $msg
    Show-WuBack @()
    if ($apps.Count) {
        Start-Work $wuRemoveAppsWork @(, [string[]]$apps) { param($r, $names) foreach ($n in $names) { Add-ChangeHistory "app:$n" 'removed' }; Start-WuCheck } $apps
    } else { Start-WuCheck }
})
