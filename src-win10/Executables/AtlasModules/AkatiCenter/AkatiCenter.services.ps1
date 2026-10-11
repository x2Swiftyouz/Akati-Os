<#
.SYNOPSIS
    Akati OS Center: Tweaks > Service helper: running and automatic services, each with a short explanation and a
    badge (Safe to turn off, Careful, Keep on, Unknown). Only Safe and Careful ones get a switch.
    Dot-sourced by AkatiCenter.ps1 (runs in its scope: $ui, $window, T and the other parts).
#>
# ---------------------------------------------------------------------------------------------
# The list: level and the Windows default start type (2 automatic, 3 manual), used when a service is turned on again.
# The third value, when there is one, is the service whose text is shared (svc.d.<name> and, for Careful, svc.b.<name>:
# what stops working). Services not in the list show "Unknown, leave it". Services of $criticalServices
# (AkatiCenter.logic.ps1: RPC, DCOM, WMI, Defender, the firewall...) are never offered, whatever the list says, and
# neither is Windows Update while it installs.
# ---------------------------------------------------------------------------------------------
Add-Mark 'Service helper'
$svcInfo = [ordered]@{
    # Safe to turn off on a gaming PC
    DiagTrack = @('safe', 2); dmwappushservice = @('safe', 3); MapsBroker = @('safe', 2); RetailDemo = @('safe', 3); Fax = @('safe', 3)
    WMPNetworkSvc = @('safe', 3); wisvc = @('safe', 3); WerSvc = @('safe', 3); wercplsupport = @('safe', 3); PcaSvc = @('safe', 2)
    TrkWks = @('safe', 2); RemoteRegistry = @('safe', 3); AJRouter = @('safe', 3); WalletService = @('safe', 3); SEMgrSvc = @('safe', 3)
    TroubleshootingSvc = @('safe', 3); WinRM = @('safe', 3); RemoteAccess = @('safe', 3); MSDTC = @('safe', 3); Wecsvc = @('safe', 3)
    diagsvc = @('safe', 3); PhoneSvc = @('safe', 3); MozillaMaintenance = @('safe', 3); QWAVE = @('safe', 3); PeerDistSvc = @('safe', 3)
    NetTcpPortSharing = @('safe', 3)
    # Careful: something stops working
    WpcMonSvc = @('careful', 3); edgeupdate = @('careful', 2); edgeupdatem = @('careful', 3, 'edgeupdate'); gupdate = @('careful', 2)
    gupdatem = @('careful', 3, 'gupdate'); lfsvc = @('careful', 3); SharedAccess = @('careful', 3); icssvc = @('careful', 3); SCardSvr = @('careful', 3)
    TermService = @('careful', 3); SessionEnv = @('careful', 3, 'TermService'); UmRdpService = @('careful', 3, 'TermService'); SysMain = @('careful', 2)
    WSearch = @('careful', 2); Spooler = @('careful', 2); PrintNotify = @('careful', 3, 'Spooler'); XblAuthManager = @('careful', 3)
    XblGameSave = @('careful', 3); XboxNetApiSvc = @('careful', 3); XboxGipSvc = @('careful', 3); WbioSrvc = @('careful', 3); stisvc = @('careful', 3)
    TabletInputService = @('careful', 3); iphlpsvc = @('careful', 2); CDPSvc = @('careful', 2); WpnService = @('careful', 2); bthserv = @('careful', 3)
    BTAGService = @('careful', 3, 'bthserv'); BthAvctpSvc = @('careful', 3, 'bthserv'); FDResPub = @('careful', 3); fdPHost = @('careful', 3, 'FDResPub')
    SSDPSRV = @('careful', 3); upnphost = @('careful', 3, 'SSDPSRV'); lmhosts = @('careful', 3); RasMan = @('careful', 3); SstpSvc = @('careful', 3, 'RasMan')
    seclogon = @('careful', 3); SensorService = @('careful', 3); SensrSvc = @('careful', 3, 'SensorService'); SensorDataService = @('careful', 3, 'SensorService')
    NvContainerLocalSystem = @('careful', 2); W32Time = @('careful', 3); DPS = @('careful', 2); WdiServiceHost = @('careful', 3, 'DPS')
    WdiSystemHost = @('careful', 3, 'DPS'); wuauserv = @('careful', 3); BITS = @('careful', 3)
    # Keep on: Windows or common hardware needs them
    Themes = @('keep', 2); WlanSvc = @('keep', 2); LanmanWorkstation = @('keep', 2); ShellHWDetection = @('keep', 2); InstallService = @('keep', 3)
    TokenBroker = @('keep', 3); FrameServer = @('keep', 3); UsoSvc = @('keep', 2); DusmSvc = @('keep', 2); WaaSMedicSvc = @('keep', 3)
}
function Get-SvcInfo([string]$name) {
    if ($name -in $criticalServices) { return @{ Level = 'keep'; Default = 0; Text = $(if ($strings['en'].ContainsKey("svc.d.$name")) { $name } else { '' }) } }
    $i = $svcInfo[$name]
    if (!$i) { return @{ Level = 'unknown'; Default = 0; Text = '' } }
    @{ Level = $i[0]; Default = $i[1]; Text = $(if ($i.Count -gt 2) { $i[2] } else { $name }) }
}
function Get-ServiceLabel([string]$name) {
    if ($script:svcResult) { $s = @($script:svcResult.List | Where-Object { $_.Name -eq $name })[0]; if ($s -and $s.Display) { return $s.Display } }
    try { [string](Get-Service -Name $name -ErrorAction Stop).DisplayName } catch { $name }
}
# Running or automatic services, and the ones of the list that are off (so they can be turned on again).
# Per-user copies (name_1a2b3c) are left out. Updating: Windows Update is installing (TiWorker, TrustedInstaller).
$svcWork = {
    param([string[]]$listed)
    $list = @(Get-CimInstance Win32_Service -ErrorAction SilentlyContinue | Where-Object {
            $_.Name -notmatch '_[0-9a-f]{4,}$' -and ($_.State -eq 'Running' -or $_.StartMode -eq 'Auto' -or $listed -contains $_.Name) } | ForEach-Object {
            $reg = Get-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\$($_.Name)" -ErrorAction SilentlyContinue
            @{ Name = [string]$_.Name; Display = [string]$_.DisplayName; State = [string]$_.State; Start = [int]$reg.Start; Delayed = [int]$reg.DelayedAutostart -eq 1 }
        })
    @{ List = $list; Updating = [bool](Get-Process -Name 'TiWorker', 'TrustedInstaller' -ErrorAction SilentlyContinue) }
}
# Screenshot mode: a sample PC
$svcSample = @{ Updating = $false; List = @(
    @{ Name = 'DiagTrack'; Display = 'Connected User Experiences and Telemetry'; State = 'Stopped'; Start = 4; Delayed = $false }
    @{ Name = 'MapsBroker'; Display = 'Downloaded Maps Manager'; State = 'Stopped'; Start = 2; Delayed = $true }
    @{ Name = 'SysMain'; Display = 'SysMain'; State = 'Running'; Start = 2; Delayed = $false }
    @{ Name = 'Spooler'; Display = 'Print Spooler'; State = 'Running'; Start = 2; Delayed = $false }
    @{ Name = 'XblAuthManager'; Display = 'Xbox Live Auth Manager'; State = 'Stopped'; Start = 3; Delayed = $false }
    @{ Name = 'Themes'; Display = 'Themes'; State = 'Running'; Start = 2; Delayed = $false }
    @{ Name = 'RpcSs'; Display = 'Remote Procedure Call (RPC)'; State = 'Running'; Start = 2; Delayed = $false }
    @{ Name = 'NVDisplay.ContainerLocalSystem'; Display = 'NVIDIA Display Container LS'; State = 'Running'; Start = 2; Delayed = $false }
    @{ Name = 'Steam Client Service'; Display = 'Steam Client Service'; State = 'Running'; Start = 3; Delayed = $false }) }
function Get-SvcStateText($s) {
    $state = T $(if ($s.State -eq 'Running') { 'svc.state.running' } else { 'svc.state.stopped' })
    $start = if ($s.Start -eq 2 -and $s.Delayed) { T 'svc.start.delayed' } elseif ($s.Start -in 2, 3, 4) { T "svc.start.$($s.Start)" } else { T 'svc.start.other' }
    "$state  ·  $start"
}
function New-SvcBadge([string]$level) {
    $b = New-Object System.Windows.Controls.Border
    $b.CornerRadius = 6; $b.Padding = '7,1'; $b.Margin = '0,6,8,0'; $b.BorderThickness = '1'; $b.VerticalAlignment = 'Center'
    $back, $fore = switch ($level) { 'safe' { 'Fill', 'Good' } 'careful' { 'WarnSoft', 'Warn' } 'keep' { 'AccentSoft', 'AccentText' } default { 'Fill', 'MutedBrush' } }
    $b.SetResourceReference([System.Windows.Controls.Border]::BackgroundProperty, $back)
    $b.SetResourceReference([System.Windows.Controls.Border]::BorderBrushProperty, $(if ($level -eq 'keep') { 'AccentLine' } else { $back }))
    $t = New-Text (T "svc.lvl.$level") 10.5 'SemiBold'
    $t.SetResourceReference([System.Windows.Controls.TextBlock]::ForegroundProperty, $fore)
    $b.Child = $t
    $b
}
$script:svcRows = @{}
function Show-Services {
    $ui.SvcList.Children.Clear(); $script:svcRows = @{}
    $res = $script:svcResult
    if ($res -isnot [hashtable]) { $ui.SvcState.Text = T 'svc.loading'; return }
    $order = @{ safe = 0; careful = 1; keep = 2; unknown = 3 }
    $items = @(foreach ($s in @($res.List | Where-Object { $_ -is [hashtable] })) { $i = Get-SvcInfo $s.Name; @{ S = $s; I = $i; Order = $order[$i.Level] } })
    foreach ($x in @($items | Sort-Object { $_.Order }, { $_.S.Display })) {
        $s = $x.S; $i = $x.I
        $right = New-Object System.Windows.Controls.Border
        if (Test-ServiceChangeable $s.Name $i.Level ([bool]$res.Updating)) {
            $right = New-Object System.Windows.Controls.CheckBox
            $right.Style = $window.FindResource('Switch'); $right.IsChecked = $s.Start -ne 4
            $right.Tag = @{ Name = $s.Name; Level = $i.Level; Default = $i.Default; Text = $i.Text; Display = $s.Display }
            $right.Add_Click({ Invoke-ServiceSwitch $this })
        }
        $row = New-Row ([string][char]0xE912) $(if ($s.Display) { $s.Display } else { $s.Name }) $null $right $null
        $desc = if ($i.Text) { T "svc.d.$($i.Text)" } elseif ($i.Level -eq 'keep') { T 'svc.critical.d' } else { T 'svc.unknown.d' }
        if ($s.Name -eq 'wuauserv' -and $res.Updating) { $desc += ' ' + (T 'svc.updating') }
        $row.Sub.Text = $desc
        $line = New-Object System.Windows.Controls.WrapPanel
        [void]$line.Children.Add((New-SvcBadge $i.Level))
        $st = New-Text (Get-SvcStateText $s) 11.5; $st.Margin = '0,6,0,0'; $st.VerticalAlignment = 'Center'
        $st.SetResourceReference([System.Windows.Controls.TextBlock]::ForegroundProperty, 'MutedBrush')
        [void]$line.Children.Add($st)
        $panel = $row.Sub.Parent
        $panel.Children.Insert($panel.Children.IndexOf($row.Sub) + 1, $line)
        $row.Row.Tag = ("$($s.Name) $($s.Display) $desc " + (T "svc.lvl.$($i.Level)")).ToLowerInvariant()
        [void]$ui.SvcList.Children.Add($row.Row)
        $script:svcRows[$s.Name] = @{ Row = $row.Row; Toggle = $right; State = $st; S = $s }
    }
    Update-SvcFilter
}
function Update-SvcFilter {
    $q = $ui.SvcSearch.Text.Trim().ToLowerInvariant()
    $ui.SvcSearchHint.Visibility = if ($q) { 'Collapsed' } else { 'Visible' }
    $shown = 0
    foreach ($r in $ui.SvcList.Children) {
        $match = !$q -or ([string]$r.Tag).Contains($q)
        $r.Visibility = if ($match) { 'Visible' } else { 'Collapsed' }
        if ($match) { $shown++ }
    }
    if ($script:svcResult) { $ui.SvcState.Text = (T 'svc.count') -f $shown }
    Update-Separators $ui.SvcList
}
$ui.SvcSearch.Add_TextChanged({ Update-SvcFilter })
function Start-ServiceList {
    if ($Screenshot) { $script:svcResult = $svcSample; Show-Services; return }
    $script:svcResult = $null; Show-Services
    Start-Work $svcWork @(, [string[]]@($svcInfo.Keys)) { param($r) $script:svcResult = Get-LastOutput $r; Show-Services } $null
}
$ui.SvcShow.Add_Click({
    $show = $ui.SvcPanel.Visibility -ne 'Visible'
    $ui.SvcPanel.Visibility = if ($show) { 'Visible' } else { 'Collapsed' }
    $ui.SvcShowText.Text = T $(if ($show) { 'svc.hide' } else { 'svc.show' })
    if ($show -and !$script:svcResult) { Start-ServiceList }
})
# The state and the switch of one row after a change
function Update-ServiceRow([string]$name) {
    $r = $script:svcRows[$name]
    if (!$r) { return }
    $r.S.Start = [int](Get-RegValue "$servicesKey\$name" 'Start')
    try { $r.S.State = [string](Get-Service -Name $name -ErrorAction Stop).Status } catch { }
    $r.State.Text = Get-SvcStateText $r.S
    if ($r.Toggle -is [System.Windows.Controls.CheckBox]) { $r.Toggle.IsChecked = $r.S.Start -ne 4 }
}
function Invoke-ServiceSwitch($toggle) {
    $i = $toggle.Tag; $on = [bool]$toggle.IsChecked
    if (!$on -and $i.Level -eq 'careful' -and !$Screenshot) {
        $ask = Show-Ask ((T 'svc.ask') -f $i.Display) 'YesNo' 'Warning' @(T "svc.b.$($i.Text)") (T 'svc.ask.note')
        if ($ask -ne 'Yes') { $toggle.IsChecked = $true; return }
    }
    Set-ServiceStart $i.Name $(if ($on) { $i.Default } else { 4 })
}
# Sets the start type of a service (4 = turned off) with history, Undo, and the Windows Update check lists. A service
# turned off is also stopped now (not the services that depend on it); one turned on as automatic is started.
function Set-ServiceStart([string]$name, [int]$to, [switch]$Quiet) {
    if ($name -in $criticalServices -or $to -notin 2, 3, 4) { return }
    $key = "$servicesKey\$name"
    if (!(Test-Path $key)) { return }
    $from = [int](Get-RegValue $key 'Start')
    if ($from -eq $to) { Update-ServiceRow $name; return }
    try { Set-ItemProperty -Path $key -Name Start -Value $to -Type DWord -Force -ErrorAction Stop }
    catch { Set-Status "$name`: $($_.Exception.Message)"; Update-ServiceRow $name; return }
    Add-ChangeHistory "svc:$name" "$to,$from"
    Update-WuTrack @("svc:$name") ($to -ne 4)
    $msg = (T $(if ($to -eq 4) { 'toast.off' } else { 'toast.on' })) -f (Get-ServiceLabel $name)
    Add-Log 'TweakLog' $msg; Set-Status $msg
    if (!$Quiet -and $from -in 2, 3, 4) { Show-Toast $msg @{ Action = { param($u) Set-ServiceStart $u.Name $u.From }; Name = $name; From = $from } }
    Update-ServiceRow $name
    Start-Work {
        param($n, $to)
        try { if ($to -eq 4) { Stop-Service -Name $n -ErrorAction Stop } elseif ($to -eq 2) { Start-Service -Name $n -ErrorAction Stop } } catch { }
    } @($name, $to) { param($r, $n) Update-ServiceRow $n } $name
}
