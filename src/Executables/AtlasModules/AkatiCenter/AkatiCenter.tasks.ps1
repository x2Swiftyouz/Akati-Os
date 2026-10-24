<#
.SYNOPSIS
    Akati OS Center: Tweaks > Scheduled task helper: tasks that run in the background, each with a short explanation and
    a badge (Safe to turn off, Careful, Keep on, Unknown), like the Service helper. Only Safe and Careful ones get a switch.
    Dot-sourced by AkatiCenter.ps1 (runs in its scope: $ui, $window, T and the other parts).
#>
# ---------------------------------------------------------------------------------------------
# The list: full task path -> level and the text (task.d.<text>, and for Careful task.b.<text>: what stops working).
# A * in the name matches the updaters and reporters that add an ID to their name. Tasks not in the list show
# "Unknown, leave it". Test-TaskProtected (AkatiCenter.logic.ps1: Defender, TPM, sign-in, security, Akati OS, and
# Windows Update while it installs) wins over the list.
# ---------------------------------------------------------------------------------------------
Add-Mark 'Scheduled task helper'
$taskInfo = [ordered]@{
    # Safe to turn off: telemetry, reports and features a gaming PC does not use
    '\Microsoft\Windows\Application Experience\Microsoft Compatibility Appraiser' = @('safe', 'appraiser')
    '\Microsoft\Windows\Application Experience\Microsoft Compatibility Appraiser Exp' = @('safe', 'appraiser')
    '\Microsoft\Windows\Application Experience\AitAgent' = @('safe', 'appraiser')
    '\Microsoft\Windows\Application Experience\ProgramDataUpdater' = @('safe', 'pdu')
    '\Microsoft\Windows\Application Experience\StartupAppTask' = @('safe', 'startupapp')
    '\Microsoft\Windows\Application Experience\PcaPatchDbTask' = @('safe', 'pca')
    '\Microsoft\Windows\Application Experience\PcaWallpaperAppDetect' = @('safe', 'pca')
    '\Microsoft\Windows\Application Experience\MareBackup' = @('safe', 'marebackup')
    '\Microsoft\Windows\Autochk\Proxy' = @('safe', 'autochk')
    '\Microsoft\Windows\Customer Experience Improvement Program\Consolidator' = @('safe', 'ceip')
    '\Microsoft\Windows\Customer Experience Improvement Program\UsbCeip' = @('safe', 'ceip')
    '\Microsoft\Windows\Customer Experience Improvement Program\KernelCeipTask' = @('safe', 'ceip')
    '\Microsoft\Windows\DiskDiagnostic\Microsoft-Windows-DiskDiagnosticDataCollector' = @('safe', 'diskdiag')
    '\Microsoft\Windows\DiskFootprint\Diagnostics' = @('safe', 'diskfoot')
    '\Microsoft\Windows\Feedback\Siuf\DmClient' = @('safe', 'feedback')
    '\Microsoft\Windows\Feedback\Siuf\DmClientOnScenarioDownload' = @('safe', 'feedback')
    '\Microsoft\Windows\Windows Error Reporting\QueueReporting' = @('safe', 'wer')
    '\Microsoft\Windows\Maps\MapsUpdateTask' = @('safe', 'maps')
    '\Microsoft\Windows\Maps\MapsToastTask' = @('safe', 'maps')
    '\Microsoft\Windows\PI\Sqm-Tasks' = @('safe', 'sqm')
    '\Microsoft\Windows\NetTrace\GatherNetworkInfo' = @('safe', 'nettrace')
    '\Microsoft\Windows\Device Information\Device' = @('safe', 'devinfo')
    '\Microsoft\Windows\Device Information\Device User' = @('safe', 'devinfo')
    '\Microsoft\Windows\Power Efficiency Diagnostics\AnalyzeSystem' = @('safe', 'powerdiag')
    '\Microsoft\Windows\RetailDemo\CleanupOfflineContent' = @('safe', 'retail')
    '\Microsoft\Windows\Maintenance\WinSAT' = @('safe', 'winsat')
    '\Microsoft\Windows\Diagnosis\RecommendedTroubleshootingScanner' = @('safe', 'troubleshoot')
    '\Microsoft\Windows\Printing\EduPrintProv' = @('safe', 'eduprint')
    '\Microsoft\Windows\Windows Media Sharing\UpdateLibrary' = @('safe', 'mediashare')
    '\Microsoft\Office\OfficeTelemetryAgentLogOn2016' = @('safe', 'officetel')
    '\Microsoft\Office\OfficeTelemetryAgentFallBack2016' = @('safe', 'officetel')
    '\NvTmRep_*' = @('safe', 'nvtel')
    # Careful: something stops working
    '\Microsoft\Windows\DiskDiagnostic\Microsoft-Windows-DiskDiagnosticResolver' = @('careful', 'diskwarn')
    '\Microsoft\XblGameSave\XblGameSaveTask' = @('careful', 'xblsave')
    '\Microsoft\Windows\Location\Notifications' = @('careful', 'location')
    '\Microsoft\Windows\Location\WindowsActionDialog' = @('careful', 'location')
    '\Microsoft\Windows\Speech\SpeechModelDownloadTask' = @('careful', 'speech')
    '\Microsoft\Windows\Diagnosis\Scheduled' = @('careful', 'diagsched')
    '\Microsoft\Windows\FileHistory\File History (maintenance mode)' = @('careful', 'filehistory')
    '\Microsoft\Windows\Shell\FamilySafetyMonitor' = @('careful', 'family')
    '\Microsoft\Windows\Shell\FamilySafetyRefreshTask' = @('careful', 'family')
    '\Microsoft\Windows\Work Folders\Work Folders Logon Synchronization' = @('careful', 'workfolders')
    '\Microsoft\Windows\Work Folders\Work Folders Maintenance Work' = @('careful', 'workfolders')
    '\Microsoft\Windows\Mobile Broadband Accounts\MNO Metadata Parser' = @('careful', 'mobile')
    '\Microsoft\Windows\Time Synchronization\SynchronizeTime' = @('careful', 'timesync')
    '\Microsoft\Windows\Time Synchronization\ForceSynchronizeTime' = @('careful', 'timesync')
    '\MicrosoftEdgeUpdateTaskMachineCore*' = @('careful', 'edgeupdate')
    '\MicrosoftEdgeUpdateTaskMachineUA*' = @('careful', 'edgeupdate')
    '\GoogleUpdateTaskMachineCore*' = @('careful', 'googleupdate')
    '\GoogleUpdateTaskMachineUA*' = @('careful', 'googleupdate')
    # Keep on: Windows needs them to stay healthy
    '\Microsoft\Windows\Defrag\ScheduledDefrag' = @('keep', 'defrag')
    '\Microsoft\Windows\Registry\RegIdleBackup' = @('keep', 'regbackup')
    '\Microsoft\Windows\SystemRestore\SR' = @('keep', 'restore')
    '\Microsoft\Windows\TaskScheduler\Regular Maintenance' = @('keep', 'maint')
    '\Microsoft\Windows\Chkdsk\ProactiveScan' = @('keep', 'chkdsk')
    '\Microsoft\Windows\Servicing\StartComponentCleanup' = @('keep', 'cleanup')
    '\Microsoft\Windows\WindowsUpdate\Scheduled Start' = @('keep', 'wu')
    '\Microsoft\Windows\UpdateOrchestrator\Schedule Scan' = @('keep', 'wu')
    '\Microsoft\Windows\InstallService\ScanForUpdates' = @('keep', 'storeupdate')
    '\Microsoft\Windows\Clip\License Validation' = @('keep', 'license')
    '\Microsoft\Windows\Wininet\CacheTask' = @('keep', 'wininet')
}
function Get-TaskInfo([string]$path, [bool]$updating) {
    $i = Find-TaskEntry $taskInfo $path
    if (Test-TaskProtected $path $updating) { return @{ Level = 'keep'; Text = $(if ($i) { $i[1] } else { '' }); Protected = $true } }
    if (!$i) { return @{ Level = 'unknown'; Text = '' } }
    @{ Level = $i[0]; Text = $i[1] }
}
# The tasks that are on (ready or running), and the tasks of the list that are off (so they can be turned on again)
$taskWork = {
    param([string[]]$listed)
    try { $all = @(Get-ScheduledTask -ErrorAction Stop) } catch { return @{ Error = $_.Exception.Message } }
    $list = @(foreach ($t in $all) {
        $path = [string]$t.TaskPath + [string]$t.TaskName
        $state = [string]$t.State
        $inList = $false; foreach ($k in $listed) { if ($path -like $k) { $inList = $true; break } }
        if ($state -eq 'Disabled' -and !$inList) { continue }
        @{ Path = $path; Folder = [string]$t.TaskPath; Name = [string]$t.TaskName; State = $state }
    })
    @{ List = $list; Updating = [bool](Get-Process -Name 'TiWorker', 'TrustedInstaller' -ErrorAction SilentlyContinue) }
}
# Screenshot mode: a sample PC
$taskSample = @{ Updating = $false; List = @(
    @{ Path = '\Microsoft\Windows\Application Experience\Microsoft Compatibility Appraiser'; Folder = '\Microsoft\Windows\Application Experience\'; Name = 'Microsoft Compatibility Appraiser'; State = 'Disabled' }
    @{ Path = '\Microsoft\Windows\Customer Experience Improvement Program\Consolidator'; Folder = '\Microsoft\Windows\Customer Experience Improvement Program\'; Name = 'Consolidator'; State = 'Ready' }
    @{ Path = '\Microsoft\Windows\Maps\MapsUpdateTask'; Folder = '\Microsoft\Windows\Maps\'; Name = 'MapsUpdateTask'; State = 'Ready' }
    @{ Path = '\Microsoft\XblGameSave\XblGameSaveTask'; Folder = '\Microsoft\XblGameSave\'; Name = 'XblGameSaveTask'; State = 'Ready' }
    @{ Path = '\Microsoft\Windows\Time Synchronization\SynchronizeTime'; Folder = '\Microsoft\Windows\Time Synchronization\'; Name = 'SynchronizeTime'; State = 'Ready' }
    @{ Path = '\Microsoft\Windows\Defrag\ScheduledDefrag'; Folder = '\Microsoft\Windows\Defrag\'; Name = 'ScheduledDefrag'; State = 'Ready' }
    @{ Path = '\Microsoft\Windows\Windows Defender\Windows Defender Scheduled Scan'; Folder = '\Microsoft\Windows\Windows Defender\'; Name = 'Windows Defender Scheduled Scan'; State = 'Ready' }
    @{ Path = '\Microsoft\Windows\TPM\Tpm-Maintenance'; Folder = '\Microsoft\Windows\TPM\'; Name = 'Tpm-Maintenance'; State = 'Ready' }
    @{ Path = '\Vendor\Launcher Updater'; Folder = '\Vendor\'; Name = 'Launcher Updater'; State = 'Ready' }) }
function Get-TaskStateText($t) {
    $state = T $(switch ($t.State) { 'Disabled' { 'task.state.disabled' } 'Running' { 'task.state.running' } default { 'task.state.ready' } })
    "$state  ·  $($t.Folder.TrimEnd('\'))"
}
$script:taskRows = @{}
function Show-Tasks {
    $ui.TaskList.Children.Clear(); $script:taskRows = @{}
    $res = $script:taskResult
    if ($res -isnot [hashtable]) { $ui.TaskState.Text = T 'task.loading'; return }
    if ($res.Error) { $ui.TaskState.Text = (T 'task.error') -f $res.Error; return }
    $updating = [bool]$res.Updating
    $order = @{ safe = 0; careful = 1; keep = 2; unknown = 3 }
    $items = @(foreach ($t in @($res.List | Where-Object { $_ -is [hashtable] })) { $i = Get-TaskInfo $t.Path $updating; @{ T = $t; I = $i; Order = $order[$i.Level] } })
    foreach ($x in @($items | Sort-Object { $_.Order }, { $_.T.Name })) {
        $t = $x.T; $i = $x.I
        $right = New-Object System.Windows.Controls.Border
        if (Test-TaskChangeable $t.Path $i.Level $updating) {
            $right = New-Object System.Windows.Controls.CheckBox
            $right.Style = $window.FindResource('Switch'); $right.IsChecked = $t.State -ne 'Disabled'
            $right.Tag = @{ Path = $t.Path; Level = $i.Level; Text = $i.Text; Name = $t.Name }
            $right.Add_Click({ Invoke-TaskSwitch $this })
        }
        $row = New-Row ([string][char]0xE787) $t.Name $null $right $null
        $desc = if ($i.Protected) { T 'task.protected.d' } elseif ($i.Text) { T "task.d.$($i.Text)" } else { T 'svc.unknown.d' }
        if ($i.Protected -and $updating -and $t.Path -match '\\(UpdateOrchestrator|WindowsUpdate)\\') { $desc = T 'task.updating' }
        $row.Sub.Text = $desc
        $line = New-Object System.Windows.Controls.WrapPanel
        [void]$line.Children.Add((New-SvcBadge $i.Level))
        $st = New-Text (Get-TaskStateText $t) 11.5; $st.Margin = '0,6,0,0'; $st.VerticalAlignment = 'Center'
        $st.SetResourceReference([System.Windows.Controls.TextBlock]::ForegroundProperty, 'MutedBrush')
        [void]$line.Children.Add($st)
        $panel = $row.Sub.Parent
        $panel.Children.Insert($panel.Children.IndexOf($row.Sub) + 1, $line)
        $row.Row.Tag = ("$($t.Path) $desc " + (T "svc.lvl.$($i.Level)")).ToLowerInvariant()
        [void]$ui.TaskList.Children.Add($row.Row)
        $script:taskRows[$t.Path] = @{ Row = $row.Row; Toggle = $right; State = $st; T = $t }
    }
    Update-TaskFilter
}
function Update-TaskFilter {
    $q = $ui.TaskSearch.Text.Trim().ToLowerInvariant()
    $ui.TaskSearchHint.Visibility = if ($q) { 'Collapsed' } else { 'Visible' }
    $shown = 0
    foreach ($r in $ui.TaskList.Children) {
        $match = !$q -or ([string]$r.Tag).Contains($q)
        $r.Visibility = if ($match) { 'Visible' } else { 'Collapsed' }
        if ($match) { $shown++ }
    }
    if ($script:taskResult -is [hashtable] -and !$script:taskResult.Error) { $ui.TaskState.Text = (T 'task.count') -f $shown }
    Update-Separators $ui.TaskList
}
$ui.TaskSearch.Add_TextChanged({ Update-TaskFilter })
# Loaded when the list is opened the first time (reading every task takes a second or two)
function Start-TaskList {
    if ($Screenshot) { $script:taskResult = $taskSample; Show-Tasks; return }
    $script:taskResult = $null; Show-Tasks
    Start-Work $taskWork @(, [string[]]@($taskInfo.Keys)) { param($r) $script:taskResult = Get-LastOutput $r; Show-Tasks } $null
}
$ui.TaskShow.Add_Click({
    $show = $ui.TaskPanel.Visibility -ne 'Visible'
    $ui.TaskPanel.Visibility = if ($show) { 'Visible' } else { 'Collapsed' }
    $ui.TaskShowText.Text = T $(if ($show) { 'svc.hide' } else { 'task.show' })
    if ($show -and !$script:taskResult) { Start-TaskList }
})
function Invoke-TaskSwitch($toggle) {
    $i = $toggle.Tag; $on = [bool]$toggle.IsChecked
    if (!$on -and $i.Level -eq 'careful' -and !$Screenshot) {
        $ask = Show-Ask ((T 'task.ask') -f $i.Name) 'YesNo' 'Warning' @(T "task.b.$($i.Text)") (T 'svc.ask.note')
        if ($ask -ne 'Yes') { $toggle.IsChecked = $true; return }
    }
    Set-TaskEnabled $i.Path $on
}
# Turns a task on or off (in the background) with history and Undo. Never a protected task.
function Set-TaskEnabled([string]$path, [bool]$on, [switch]$Quiet) {
    $updating = $script:taskResult -is [hashtable] -and [bool]$script:taskResult.Updating
    if (Test-TaskProtected $path $updating) { return }
    $i = $path.LastIndexOf('\')
    $folder = $path.Substring(0, $i + 1); $name = $path.Substring($i + 1)
    Start-Work {
        param($folder, $name, $on)
        try {
            if ($on) { Enable-ScheduledTask -TaskPath $folder -TaskName $name -ErrorAction Stop | Out-Null } else { Disable-ScheduledTask -TaskPath $folder -TaskName $name -ErrorAction Stop | Out-Null }
            [string](Get-ScheduledTask -TaskPath $folder -TaskName $name -ErrorAction Stop).State
        } catch { 'error:' + $_.Exception.Message }
    } @($folder, $name, $on) {
        param($r, $c)
        $state = [string](Get-LastOutput $r)
        $row = $script:taskRows[$c.Path]
        if ($state -like 'error:*' -or !$state) {
            Set-Status ((T 'task.failed') -f $c.Name, $state.Substring([Math]::Min(6, $state.Length)))
            if ($row -and $row.Toggle -is [System.Windows.Controls.CheckBox]) { $row.Toggle.IsChecked = $row.T.State -ne 'Disabled' }
            return
        }
        if ($row) { $row.T.State = $state; $row.State.Text = Get-TaskStateText $row.T; if ($row.Toggle -is [System.Windows.Controls.CheckBox]) { $row.Toggle.IsChecked = $state -ne 'Disabled' } }
        Add-ChangeHistory "task:$($c.Path)" $(if ($c.On) { '1,0' } else { '0,1' })
        $msg = (T $(if ($c.On) { 'toast.on' } else { 'toast.off' })) -f $c.Name
        Add-Log 'TweakLog' $msg; Set-Status $msg
        if (!$c.Quiet) { Show-Toast $msg @{ Action = { param($u) Set-TaskEnabled $u.Path (!$u.On) -Quiet }; Path = $c.Path; On = $c.On } }
    } @{ Path = $path; Name = $name; On = $on; Quiet = [bool]$Quiet }
}
# Undo in the change history: only while the task is still as the change left it (when the list knows it)
function Test-TaskUndo([string]$path, [string]$to) {
    $row = $script:taskRows[$path]
    if (!$row) { return $true }
    ($row.T.State -ne 'Disabled') -eq ($to -eq '1')
}
