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
        $run = if ($qt.Command) { $qt.Command } elseif ($qt.Arguments) { $qt.Arguments } elseif ($qt.File) { $qt.File } else { 'PurgeStandbyList' }
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
