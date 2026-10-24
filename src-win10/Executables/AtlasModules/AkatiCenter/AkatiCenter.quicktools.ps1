<#
.SYNOPSIS
    Akati OS Center: Quick tools: the Windows tools people open most, one card each, and an activity log.
    Dot-sourced by AkatiCenter.ps1 (runs in its scope: $ui, $window, T and the other parts).
#>
# ---------------------------------------------------------------------------------------------
# Quick tools
# ---------------------------------------------------------------------------------------------
Add-Mark 'Quick tools'
# Key: the texts qt.<key> and qt.<key>.d. Run: what starts (File and Arguments for Start-Process), or Action: a
# script block run here (short) or in the background. Words: more search words for Ctrl+K.
$quickTools = @(
    @{ Key = 'taskmgr';   Glyph = [char]0xE9D9; File = 'taskmgr.exe';                      Words = 'task manager processes' }
    @{ Key = 'devmgmt';   Glyph = [char]0xE772; File = 'devmgmt.msc';                      Words = 'device manager drivers' }
    @{ Key = 'perf';      Glyph = [char]0xE945; File = 'SystemPropertiesPerformance.exe';  Words = 'performance options visual effects virtual memory' }
    @{ Key = 'flushdns';  Glyph = [char]0xE774; Command = 'ipconfig /flushdns';            Words = 'dns flush ipconfig' }
    @{ Key = 'services';  Glyph = [char]0xE912; File = 'services.msc';                     Words = 'services' }
    @{ Key = 'diskmgmt';  Glyph = [char]0xEDA2; File = 'diskmgmt.msc';                     Words = 'disk management partition' }
    @{ Key = 'eventvwr';  Glyph = [char]0xE7BA; File = 'eventvwr.msc';                     Words = 'event viewer logs errors' }
    @{ Key = 'msconfig';  Glyph = [char]0xE770; File = 'msconfig.exe';                     Words = 'system configuration msconfig boot' }
    @{ Key = 'ncpa';      Glyph = [char]0xE839; File = 'control.exe'; Arguments = 'ncpa.cpl';     Words = 'network connections adapters ncpa' }
    @{ Key = 'sound';     Glyph = [char]0xE767; File = 'control.exe'; Arguments = 'mmsys.cpl';    Words = 'sound audio playback recording mmsys' }
    @{ Key = 'power';     Glyph = [char]0xE945; File = 'control.exe'; Arguments = 'powercfg.cpl'; Words = 'power options plan powercfg' }
    @{ Key = 'winupdate'; Glyph = [char]0xE895; File = 'ms-settings:windowsupdate';        Words = 'windows update' }
    @{ Key = 'resmon';    Glyph = [char]0xE9F9; File = 'resmon.exe';                       Words = 'resource monitor' }
    @{ Key = 'msinfo';    Glyph = [char]0xE946; File = 'msinfo32.exe';                     Words = 'system information msinfo' }
    @{ Key = 'dxdiag';    Glyph = [char]0xE7F4; File = 'dxdiag.exe';                       Words = 'directx diagnostic dxdiag graphics' }
    @{ Key = 'display';   Glyph = [char]0xE7F8; File = 'ms-settings:display';              Words = 'display screen resolution scale' }
    @{ Key = 'startup';   Glyph = [char]0xE7E8; File = 'ms-settings:startupapps';          Words = 'startup apps' }
    @{ Key = 'freeram';   Glyph = [char]0xE964; Action = 'freeram';                        Words = 'ram memory standby' }
    @{ Key = 'mousetest'; Glyph = [char]0xE962; Action = 'mousetest'; Run = 'WM_INPUT';     Words = 'mouse polling rate report rate hz'; Intents = @('mouse') }
)

# Runs one tool and writes it to the activity log. Programs start on their own; Flush DNS runs in the background
# and its result goes to the log.
function Invoke-QuickTool($qt) {
    $name = T "qt.$($qt.Key)"
    try {
        if ($qt.Command) {
            Add-Log 'ToolsLog' ((T 'qt.running') -f $name)
            Set-Status ((T 'qt.running') -f $name) $true
            Start-Work { param($cmd) $exe, $arg = $cmd -split ' ', 2; (& $exe $arg 2>&1 | Out-String).Trim() } @($qt.Command) {
                param($r, $ctx)
                $out = [string](Get-LastOutput $r)
                # ipconfig prints a header and one line of result: keep the lines with text
                $lines = @($out -split "`r?`n" | ForEach-Object { $_.Trim() } | Where-Object { $_ -and $_ -notmatch '^Windows IP' })
                Add-Log 'ToolsLog' ('{0}: {1}' -f $ctx, $(if ($lines.Count) { $lines -join ' ' } else { T 'qt.done' }))
                Set-Status ((T 'qt.finished') -f $ctx)
            } $name
            return
        }
        if ($qt.Action -eq 'mousetest') { Show-MouseTest; return }
        if ($qt.Action -eq 'freeram') { Invoke-FreeRam; Add-Log 'ToolsLog' ('{0}: {1}' -f $name, $ui.StatusText.Text); return }
        if ($qt.Arguments) { Start-Process -FilePath $qt.File -ArgumentList $qt.Arguments } else { Start-Process -FilePath $qt.File }
        Add-Log 'ToolsLog' ((T 'qt.opened') -f $name, $(if ($qt.Arguments) { "$($qt.File) $($qt.Arguments)" } else { $qt.File }))
        Set-Status ((T 'qt.opened') -f $name, $qt.File)
    } catch {
        Add-Log 'ToolsLog' ('{0}: {1}' -f $name, $_.Exception.Message)
        Set-Status $_.Exception.Message
    }
}

# The cards are made the first time the page opens
function Initialize-QuickTools {
    if ($script:toolsBuilt) { return }
    $script:toolsBuilt = $true
    foreach ($qt in $quickTools) {
        $b = New-Object System.Windows.Controls.Button
        $b.Style = $window.FindResource('Tile'); $b.Margin = '5'; $b.Tag = $qt
        $dock = New-Object System.Windows.Controls.DockPanel
        $box = New-Object System.Windows.Controls.Border
        $box.Style = $window.FindResource('IconBox'); $box.Margin = '0,0,12,0'; $box.VerticalAlignment = 'Top'
        $g = New-Text ([string]$qt.Glyph) 15; $g.Style = $window.FindResource('TileGlyph'); $box.Child = $g
        [System.Windows.Controls.DockPanel]::SetDock($box, 'Left')
        $text = New-Object System.Windows.Controls.StackPanel
        $title = New-Text (T "qt.$($qt.Key)") 13 'SemiBold' "t:qt.$($qt.Key)"; $title.TextWrapping = 'NoWrap'; $title.TextTrimming = 'CharacterEllipsis'
        $sub = New-Text (T "qt.$($qt.Key).d") 12 'Normal' "t:qt.$($qt.Key).d"; $sub.Style = $window.FindResource('Muted'); $sub.Margin = '0,2,0,0'
        # What runs, in the small monospace font
        $run = if ($qt.Command) { $qt.Command } elseif ($qt.Arguments) { $qt.Arguments } elseif ($qt.File) { $qt.File } elseif ($qt.Run) { $qt.Run } else { 'PurgeStandbyList' }
        $cmd = New-Text $run 11; $cmd.Style = $window.FindResource('MonoText'); $cmd.Margin = '0,5,0,0'; $cmd.Opacity = 0.85
        [void]$text.Children.Add($title); [void]$text.Children.Add($sub); [void]$text.Children.Add($cmd)
        [void]$dock.Children.Add($box); [void]$dock.Children.Add($text)
        $b.Content = $dock
        $b.Add_Click({ Invoke-QuickTool $this.Tag })
        [void]$ui.ToolsGrid.Children.Add($b)
    }
    Update-ToolsColumns
}
# Two, three or four cards in a row, by the width of the page
function Update-ToolsColumns {
    $w = $ui.PageQuicktools.ActualWidth
    $ui.ToolsGrid.Columns = if ($w -ge 1000) { 4 } elseif ($w -ge 640 -or $w -le 0) { 3 } else { 2 }
}
$ui.PageQuicktools.Add_SizeChanged({ Update-ToolsColumns })
$ui.ToolsLogClear.Add_Click({ Clear-Log 'ToolsLog' })

# ---------------------------------------------------------------------------------------------
# Network use per app: the open connections of each process, every 2 seconds while this page is on screen.
# Windows has no reliable per-app byte counter without event tracing (the I/O counters of a process also count
# disk and other I/O), so the list shows what Windows does know: TCP connections, the remote addresses they go to,
# and UDP ports (games often use UDP).
# ---------------------------------------------------------------------------------------------
$netUseWork = {
    $by = @{}
    $entry = { param($id) if (!$by.ContainsKey($id)) { $by[$id] = @{ Conn = 0; Remote = @{}; Udp = 0 } }; $by[$id] }
    try { $tcp = @(Get-NetTCPConnection -State Established -ErrorAction Stop) } catch { return @{ Error = $_.Exception.Message } }
    foreach ($c in $tcp) {
        $remote = [string]$c.RemoteAddress
        if ($remote -in '127.0.0.1', '::1' -or [int]$c.OwningProcess -le 4) { continue }
        $e = & $entry ([int]$c.OwningProcess)
        $e.Conn++; $e.Remote[$remote] = $true
    }
    try {
        foreach ($u in @(Get-NetUDPEndpoint -ErrorAction Stop)) {
            if ([string]$u.LocalAddress -in '127.0.0.1', '::1' -or [int]$u.OwningProcess -le 4) { continue }
            $e = & $entry ([int]$u.OwningProcess); $e.Udp++
        }
    } catch { }
    $list = @(foreach ($id in $by.Keys) {
        $p = Get-Process -Id $id -ErrorAction SilentlyContinue
        if (!$p) { continue }
        $path = try { [string]$p.Path } catch { '' }
        @{ Id = $id; Name = $p.ProcessName; Session = [int]$p.SessionId; Path = $path; Conn = $by[$id].Conn; Remote = $by[$id].Remote.Count; Udp = $by[$id].Udp }
    })
    @{ List = @($list | Sort-Object { $_.Conn }, { $_.Udp }, { $_.Remote } -Descending | Select-Object -First 15); Total = $list.Count }
}
$script:netRows = @{}; $script:netIcons = @{}
$script:netBusy = $false; $script:netNext = [datetime]::MinValue
# Akati OS Center ends a process only after asking, never a Windows or protected one (Test-ProtectedProcess)
function Test-NetEndable($p) { $p.Id -ne $PID -and !(Test-ProtectedProcess $p.Name $p.Session $p.Path $windir) }
function Show-NetUse($res) {
    $script:netResult = $res
    if ($res -isnot [hashtable]) { $ui.NetUseEmpty.Text = T 'netuse.loading'; $ui.NetUseEmpty.Visibility = 'Visible'; return }
    if ($res.Error) { $ui.NetUseEmpty.Text = (T 'netuse.error') -f $res.Error; $ui.NetUseEmpty.Visibility = 'Visible'; $ui.NetUseList.Children.Clear(); return }
    $list = @($res.List | Where-Object { $_ })
    $ui.NetUseEmpty.Text = T 'netuse.none'
    $ui.NetUseEmpty.Visibility = if ($list.Count) { 'Collapsed' } else { 'Visible' }
    $ui.NetUseCount.Text = (T 'netuse.count') -f [int]$res.Total
    $ui.NetUseList.Children.Clear()
    $seen = @{}
    foreach ($p in $list) {
        # The rows stay between refreshes (the same process keeps its row, its icon and its button)
        $key = '{0}|{1}' -f $p.Id, $p.Name
        $seen[$key] = $true
        $row = $script:netRows[$key]
        if (!$row) {
            $right = New-Object System.Windows.Controls.StackPanel; $right.Orientation = 'Horizontal'
            $count = New-Text '' 12; $count.Style = $window.FindResource('MonoText'); $count.FontSize = 12; $count.VerticalAlignment = 'Center'
            [void]$right.Children.Add($count)
            $endable = Test-NetEndable $p
            if ($endable) {
                $end = New-Object System.Windows.Controls.Button
                $end.Style = $window.FindResource('Pill'); $end.Padding = '12,4'; $end.Margin = '12,0,0,0'; $end.Content = T 'netuse.end'; $end.Tag = $p
                $end.Add_Click({ Stop-NetApp $this.Tag })
                [void]$right.Children.Add($end)
            }
            $row = New-Row ([string][char]0xE774) $p.Name $null $right $null
            $row.Num = $count
            if ($p.Path) {
                if (!$script:netIcons.ContainsKey($p.Path)) { $script:netIcons[$p.Path] = Get-FileIcon @($p.Path) }
                Set-RowIcon $row $script:netIcons[$p.Path]
            }
            if (!$endable) { $row.Row.ToolTip = T 'netuse.protected' }
            $script:netRows[$key] = $row
        }
        $row.Title.Text = $p.Name
        $row.Sub.Text = (T 'netuse.row') -f $p.Conn, $p.Remote, $p.Udp
        $row.Num.Text = "PID $($p.Id)"
        [void]$ui.NetUseList.Children.Add($row.Row)
    }
    foreach ($k in @($script:netRows.Keys)) { if (!$seen.ContainsKey($k)) { $script:netRows.Remove($k) } }
    Update-Separators $ui.NetUseList
}
# Called by the window timer: every 2 seconds, only while Quick tools is on screen and the window is not minimized
function Update-NetUse {
    if ($Screenshot -or $script:netBusy -or $script:page -ne 'quicktools' -or $window.WindowState -eq 'Minimized' -or (Get-Date) -lt $script:netNext) { return }
    $script:netBusy = $true
    if (!$script:netResult) { Show-NetUse $null }
    Start-Work $netUseWork @() {
        param($r)
        $script:netBusy = $false; $script:netNext = (Get-Date).AddSeconds(2)
        if ($script:page -eq 'quicktools') { Show-NetUse (Get-LastOutput $r) }
    } $null
}
function Stop-NetApp($p) {
    # Checked again: the list can be up to 2 seconds old
    $now = Get-Process -Id $p.Id -ErrorAction SilentlyContinue
    if (!$now -or $now.ProcessName -ne $p.Name -or !(Test-NetEndable $p)) { Set-Status ((T 'netuse.gone') -f $p.Name); return }
    if ((Show-Ask ((T 'netuse.end.ask') -f $p.Name, $p.Id) 'YesNo' 'Warning' @() (T 'netuse.end.note')) -ne 'Yes') { return }
    try {
        Stop-Process -Id $p.Id -Force -ErrorAction Stop
        Set-Status ((T 'netuse.ended') -f $p.Name)
        Add-Log 'ToolsLog' ((T 'netuse.ended') -f $p.Name)
        $script:netNext = [datetime]::MinValue
    } catch { Set-Status $_.Exception.Message }
}
