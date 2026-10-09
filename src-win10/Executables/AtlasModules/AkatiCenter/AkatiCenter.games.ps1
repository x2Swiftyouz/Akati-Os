<#
.SYNOPSIS
    Akati OS Center: My games, game profiles and Play, the FPS test and FiveM.
    Dot-sourced by AkatiCenter.ps1 (runs in its scope: $ui, $window, T and the other parts).
#>
# ---------------------------------------------------------------------------------------------
# Game boost > My games: settings for each game the user adds (its .exe)
#   High priority: Image File Execution Options\<exe>\PerfOptions CpuPriorityClass = 3
#   Dedicated GPU: DirectX\UserGpuPreferences <path> = GpuPreference=2;
#   Skip Defender: Defender exclusion for the game folder
# The list itself is kept in HKCU\Software\AkatiOS\Center\Games. Removing a game undoes all three.
# ---------------------------------------------------------------------------------------------
Add-Mark 'Game boost > My games'
$gamesKey = 'HKCU:\Software\AkatiOS\Center\Games'
$ifeoKey = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Image File Execution Options'
function Get-GameOption([string]$path, [string]$kind, $exclusions) {
    switch ($kind) {
        'cpu' { return (Get-RegValue "$ifeoKey\$(Split-Path $path -Leaf)\PerfOptions" 'CpuPriorityClass') -eq 3 }
        'gpu' { return (Get-RegValue $dxKey $path) -match 'GpuPreference=2' }
        'defender' { return @($exclusions) -contains (Split-Path $path -Parent) }
    }
}
function Set-GameOption([string]$path, [string]$kind, [bool]$on) {
    switch ($kind) {
        'cpu' {
            $k = "$ifeoKey\$(Split-Path $path -Leaf)\PerfOptions"
            if ($on) { if (!(Test-Path $k)) { New-Item -Path $k -Force | Out-Null }; Set-ItemProperty -Path $k -Name CpuPriorityClass -Value 3 -Type DWord -Force }
            else { Remove-ItemProperty -Path $k -Name CpuPriorityClass -ErrorAction SilentlyContinue }
        }
        'gpu' {
            if ($on) { if (!(Test-Path $dxKey)) { New-Item -Path $dxKey -Force | Out-Null }; Set-ItemProperty -Path $dxKey -Name $path -Value 'GpuPreference=2;' -Type String -Force }
            else { Remove-ItemProperty -Path $dxKey -Name $path -ErrorAction SilentlyContinue }
        }
        'defender' {
            if ($on) { Add-MpPreference -ExclusionPath (Split-Path $path -Parent) -ErrorAction Stop }
            else { Remove-MpPreference -ExclusionPath (Split-Path $path -Parent) -ErrorAction SilentlyContinue }
        }
    }
}
# Game profile, in HKCU\Software\AkatiOS\Center\GameProfiles as "<path>|<name>":
#   boost = 1: Play starts Game boost first
#   core0 = 1: the icon next to the clock keeps the game off CPU 0 (where Windows handles most interrupts)
#   hvci  = 1 / 0: the game needs Memory integrity on (Valorant) / off (FiveM); Play offers to switch it
$profilesKey = "$settingsKey\GameProfiles"
function Get-GameProfile([string]$path, [string]$name) { Get-RegValue $profilesKey "$path|$name" }
function Set-GameProfile([string]$path, [string]$name, $value) {
    if (!(Test-Path $profilesKey)) { New-Item -Path $profilesKey -Force | Out-Null }
    if ($null -eq $value) { Remove-ItemProperty -Path $profilesKey -Name "$path|$name" -ErrorAction SilentlyContinue }
    else { Set-ItemProperty -Path $profilesKey -Name "$path|$name" -Value ([int]$value) -Type DWord -Force }
}
function Get-HvciText($value) { T $(switch ($value) { 1 { 'games.hvci.on' } 0 { 'games.hvci.off' } default { 'games.hvci.any' } }) }
# Play: Memory integrity as the game needs it, Game boost if wanted, then the game, as the user (not elevated)
function Start-Game([string]$path) {
    $name = [IO.Path]::GetFileNameWithoutExtension($path)
    $need = Get-GameProfile $path 'hvci'
    if ($null -ne $need -and ([bool]$need) -ne ((Get-RegValue $hvciKey 'Enabled') -eq 1)) {
        $ask = (T 'games.hvciask') -f $name, (T $(if ($need) { 'games.on' } else { 'games.off' }))
        if ([System.Windows.MessageBox]::Show($ask, 'Akati OS Center', 'YesNo', 'Question') -eq 'Yes') { Set-AntiCheat ([bool]$need); return }
    }
    if ((Get-GameProfile $path 'boost') -eq 1 -and !(Test-Boost)) {
        try { Start-Boost; Show-BoostEffect } catch { }
        Update-BoostCard
    }
    Start-Process explorer.exe -ArgumentList "`"$path`""
    Set-Status ((T 'status.gamestarted') -f $name)
}
function Show-Games {
    $ui.GamesList.Children.Clear()
    $paths = @(if (Test-Path $gamesKey) { (Get-Item $gamesKey).Property })
    # Defender exclusions are read once per refresh (null when Defender is off)
    $exclusions = try { @((Get-MpPreference -ErrorAction Stop).ExclusionPath) } catch { $null }
    foreach ($path in $paths) {
        $chips = New-Object System.Windows.Controls.WrapPanel; $chips.Margin = '0,6,0,0'
        foreach ($kind in 'cpu', 'gpu', 'defender') {
            $chip = New-Object System.Windows.Controls.CheckBox
            $chip.Style = $window.FindResource('Chip'); $chip.Content = T "games.$kind"; $chip.Margin = '0,0,6,6'
            $chip.Tag = @{ Path = $path; Kind = $kind }
            $chip.IsChecked = Get-GameOption $path $kind $exclusions
            if ($kind -eq 'defender' -and $null -eq $exclusions) { $chip.IsEnabled = $false; $chip.ToolTip = T 'games.nodefender' }
            $chip.Add_Click({
                $t = $this.Tag
                try { Set-GameOption $t.Path $t.Kind ([bool]$this.IsChecked) } catch { $this.IsChecked = !$this.IsChecked; Set-Status $_.Exception.Message }
            })
            [void]$chips.Children.Add($chip)
        }
        foreach ($kind in 'boost', 'core0') {
            $chip = New-Object System.Windows.Controls.CheckBox
            $chip.Style = $window.FindResource('Chip'); $chip.Content = T "games.$kind"; $chip.Margin = '0,0,6,6'; $chip.ToolTip = T "games.$kind.tip"
            $chip.Tag = @{ Path = $path; Kind = $kind }
            $chip.IsChecked = (Get-GameProfile $path $kind) -eq 1
            $chip.Add_Click({ $t = $this.Tag; Set-GameProfile $t.Path $t.Kind $(if ($this.IsChecked) { 1 } else { $null }) })
            [void]$chips.Children.Add($chip)
        }
        # Memory integrity: any > on > off > any
        $hv = New-Object System.Windows.Controls.Button
        $hv.Style = $window.FindResource('Pill'); $hv.Padding = '10,3'; $hv.Margin = '0,0,6,6'; $hv.FontSize = 12
        $hv.Content = Get-HvciText (Get-GameProfile $path 'hvci'); $hv.Tag = $path; $hv.ToolTip = T 'games.hvci.tip'
        $hv.Add_Click({
            $now = Get-GameProfile $this.Tag 'hvci'
            $next = switch ($now) { 1 { 0 } 0 { $null } default { 1 } }
            Set-GameProfile $this.Tag 'hvci' $next
            $this.Content = Get-HvciText $next
        })
        [void]$chips.Children.Add($hv)

        $right = New-Object System.Windows.Controls.StackPanel; $right.Orientation = 'Horizontal'
        $play = New-Object System.Windows.Controls.Button
        $play.Style = $window.FindResource('PillAccent'); $play.Padding = '14,5'; $play.Tag = $path
        $pc = New-Object System.Windows.Controls.StackPanel; $pc.Orientation = 'Horizontal'
        $pg = New-Text ([string][char]0xE768) 11; $pg.Style = $window.FindResource('Glyph'); $pg.Margin = '0,0,6,0'; $pg.VerticalAlignment = 'Center'
        [void]$pc.Children.Add($pg); [void]$pc.Children.Add((New-Text (T 'games.play') 13 'SemiBold'))
        $play.Content = $pc
        $play.Add_Click({ Start-Game $this.Tag })
        [void]$right.Children.Add($play)
        $remove = New-Object System.Windows.Controls.Button
        $remove.Style = $window.FindResource('Bare'); $remove.Padding = '7'; $remove.Margin = '4,0,0,0'; $remove.ToolTip = T 'games.remove'; $remove.Tag = $path
        $x = New-Text ([string][char]0xE711) 12; $x.Style = $window.FindResource('Glyph'); $remove.Content = $x
        $remove.Add_Click({
            $path = $this.Tag
            foreach ($kind in 'cpu', 'gpu', 'defender') { try { Set-GameOption $path $kind $false } catch { } }
            foreach ($kind in 'boost', 'core0', 'hvci') { Set-GameProfile $path $kind $null }
            Remove-ItemProperty -Path $gamesKey -Name $path -ErrorAction SilentlyContinue
            Set-Status ((T 'status.gameremoved') -f [IO.Path]::GetFileNameWithoutExtension($path))
            Show-Games
            Request-MenuUpdate
        })
        [void]$right.Children.Add($remove)
        $name = try { (Get-Item -LiteralPath $path -ErrorAction Stop).VersionInfo.FileDescription } catch { $null }
        if (!$name) { $name = [IO.Path]::GetFileNameWithoutExtension($path) }
        $row = New-Row ([string][char]0xE7FC) $name $null $right $null
        $row.Sub.Text = Split-Path $path -Parent
        # Play time, counted by the icon next to the clock
        $played = [double](Get-RegValue "$settingsKey\PlayTime" $path)
        if ($played -ge 60) {
            $h = [Math]::Floor($played / 3600); $m = [Math]::Floor(($played % 3600) / 60)
            $text = if ($h -ge 1) { (T 'games.hours') -f $h, $m } else { (T 'games.minutes') -f $m }
            $last = Get-RegValue "$settingsKey\PlayTime" "$path|last"
            if ($last) {
                $c = (Get-LangCulture)
                try { $text += ' · ' + ((T 'games.last') -f [datetime]::ParseExact($last, 'yyyy-MM-dd', [Globalization.CultureInfo]::InvariantCulture).ToString('d MMM', $c)) } catch { }
            }
            $row.Sub.Text += ' · ' + ((T 'games.played') -f $text)
        }
        $panel = $row.Sub.Parent
        $panel.Children.Insert($panel.Children.IndexOf($row.Sub) + 1, $chips)
        $icon = Get-FileIcon @($path)
        if ($icon) { Set-RowIcon $row $icon }
        [void]$ui.GamesList.Children.Add($row.Row)
    }
    $ui.GamesEmpty.Visibility = if ($paths.Count) { 'Collapsed' } else { 'Visible' }
    Update-Separators $ui.GamesList
}
function Add-Game([string]$path) {
    if (!(Test-Path $gamesKey)) { New-Item -Path $gamesKey -Force | Out-Null }
    Set-ItemProperty -Path $gamesKey -Name $path -Value 1 -Type DWord -Force
    # High priority and the dedicated GPU at once; skipping Defender is the user's choice
    foreach ($kind in 'cpu', 'gpu') { try { Set-GameOption $path $kind $true } catch { } }
    Set-Status ((T 'status.gameadded') -f [IO.Path]::GetFileNameWithoutExtension($path))
    Show-Games
    Request-MenuUpdate
}

# Welcome > Your main game: where each game installs by default (Steam games in any Steam library)
function Find-MainGame([string]$key) {
    $paths = switch ($key) {
        'valorant' { @('C:\Riot Games\VALORANT\live\VALORANT.exe') }
        'fivem'    { @((Join-Path $env:LOCALAPPDATA 'FiveM\FiveM.exe')) }
        'fortnite' { @((Join-Path ${env:ProgramFiles} 'Epic Games\Fortnite\FortniteGame\Binaries\Win64\FortniteClient-Win64-Shipping.exe')) }
        'cs2' {
            $steam = Get-RegValue 'HKCU:\Software\Valve\Steam' 'SteamPath'
            $libs = @(if ($steam) { $steam })
            $vdf = if ($steam) { Join-Path $steam 'steamapps\libraryfolders.vdf' }
            if ($vdf -and (Test-Path -LiteralPath $vdf)) {
                foreach ($m in [regex]::Matches((Get-Content -LiteralPath $vdf -Raw), '"path"\s+"([^"]+)"')) { $libs += $m.Groups[1].Value -replace '\\\\', '\' }
            }
            @($libs | ForEach-Object { Join-Path $_ 'steamapps\common\Counter-Strike Global Offensive\game\bin\win64\cs2.exe' })
        }
        default { @() }
    }
    foreach ($p in $paths) { if ($p -and (Test-Path -LiteralPath $p)) { return (Resolve-Path -LiteralPath $p).Path } }
    return $null
}
# Adds the main game to My games with Game boost on Play, and starts Game boost by itself when it opens.
# FiveM needs Memory integrity off, so Play offers to switch it (the other games leave it as it is).
function Set-MainGame([string]$key) {
    $path = Find-MainGame $key
    if (!$path) { Set-Status (T 'status.maingame.none'); return }
    Add-Game $path
    Set-GameProfile $path 'boost' 1
    if ($key -eq 'fivem') { Set-GameProfile $path 'hvci' 0 }
    Save-Setting AutoBoost 1; $ui.BoostAuto.IsChecked = $true
    Show-Games
    Set-Status ((T 'status.maingame') -f [IO.Path]::GetFileNameWithoutExtension($path))
}

# FPS test: PresentMon by Intel (downloaded once from its GitHub releases, only if signed by Intel) records
# the frame times of the game for 30 seconds. Average FPS and the 1% low (the 99th percentile frame time)
$presentMonDir = Join-Path $env:ProgramData 'AkatiOS\PresentMon'
function Get-RunningGame {
    foreach ($path in @(if (Test-Path $gamesKey) { (Get-Item $gamesKey).Property })) {
        $name = [IO.Path]::GetFileNameWithoutExtension($path)
        $names = @($name); if ($name -eq 'FiveM') { $names += 'FiveM_*GTAProcess' }
        $p = Get-Process -Name $names -ErrorAction SilentlyContinue | Sort-Object WorkingSet64 -Descending | Select-Object -First 1
        if ($p) { return @{ Path = $path; Name = $name; Exe = "$($p.ProcessName).exe" } }
    }
}
$fpsWork = {
    param($dir, $exe, $seconds)
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    $pm = Join-Path $dir 'PresentMon.exe'
    try {
        if (!(Test-Path $pm)) {
            New-Item -ItemType Directory -Path $dir -Force | Out-Null
            $rel = Invoke-RestMethod -Uri 'https://api.github.com/repos/GameTechDev/PresentMon/releases/latest' -Headers @{ 'User-Agent' = 'AkatiOS-Center' } -UseBasicParsing -TimeoutSec 30
            $asset = @($rel.assets | Where-Object { $_.name -match '^PresentMon-[\d.]+-x64\.exe$' })[0]
            if (!$asset) { return @{ Error = 'fps.nodownload' } }
            $tmp = Join-Path $dir 'download.tmp'
            Invoke-WebRequest -Uri $asset.browser_download_url -OutFile $tmp -UseBasicParsing -TimeoutSec 120
            $sig = Get-AuthenticodeSignature -FilePath $tmp
            if ($sig.Status -ne 'Valid' -or $sig.SignerCertificate.Subject -notlike '*Intel Corporation*') { Remove-Item $tmp -Force; return @{ Error = 'fps.signature' } }
            Move-Item $tmp $pm -Force
        }
    } catch { return @{ Error = 'fps.nodownload' } }
    $csv = Join-Path $dir 'last.csv'
    Remove-Item $csv -Force -ErrorAction SilentlyContinue
    $pmArgs = "--process_name `"$exe`" --output_file `"$csv`" --timed $seconds --terminate_after_timed --no_console_stats --stop_existing_session --session_name AkatiOS"
    Start-Process -FilePath $pm -ArgumentList $pmArgs -WindowStyle Hidden -Wait
    if (!(Test-Path $csv)) { return @{ Error = 'fps.nodata' } }
    $rows = @(Import-Csv $csv)
    if (!$rows.Count) { return @{ Error = 'fps.nodata' } }
    # PresentMon 1.x calls the frame time MsBetweenPresents, 2.x FrameTime
    $names = $rows[0].PSObject.Properties.Name
    $col = @('FrameTime', 'MsBetweenPresents', 'MsBetweenAppStart') | Where-Object { $names -contains $_ } | Select-Object -First 1
    if (!$col) { return @{ Error = 'fps.nodata' } }
    $ft = New-Object System.Collections.Generic.List[double]
    foreach ($r in $rows) { $v = 0.0; if ([double]::TryParse($r.$col, [Globalization.NumberStyles]::Float, [Globalization.CultureInfo]::InvariantCulture, [ref]$v) -and $v -gt 0 -and $v -lt 1000) { $ft.Add($v) } }
    if ($ft.Count -lt 30) { return @{ Error = 'fps.nodata' } }
    @{ FrameTimes = $ft.ToArray() }
}
# Results: "time|game|avg|1% low|boost", newest first, the last 12
function Show-FpsResults {
    $ui.FpsList.Children.Clear()
    $c = (Get-LangCulture)
    $list = @(Get-RegValue $settingsKey 'FpsResults' | Where-Object { $_ })
    foreach ($item in $list) {
        $time, $name, $avg, $low, $boost = $item -split '\|'
        $when = try { [datetime]::ParseExact($time, 's', [Globalization.CultureInfo]::InvariantCulture).ToString('d MMM HH:mm', $c) } catch { $time }
        $text = (T 'fps.result') -f $name, $avg, $low, (T $(if ($boost -eq '1') { 'fps.boost.on' } else { 'fps.boost.off' })), $when
        # Compared with the newest result of the same game with Game boost the other way
        $other = $list | Where-Object { ($_ -split '\|')[1] -eq $name -and ($_ -split '\|')[4] -ne $boost } | Select-Object -First 1
        if ($other -and $item -eq ($list | Where-Object { ($_ -split '\|')[1] -eq $name } | Select-Object -First 1)) {
            $o = [double](($other -split '\|')[2])
            if ($o -gt 0) {
                $diff = [int][Math]::Round(100 * ([double]$avg - $o) / $o)
                $text += ' · ' + ((T $(if ($boost -eq '1') { 'fps.diff.boost' } else { 'fps.diff.noboost' })) -f $(if ($diff -ge 0) { "+$diff" } else { "$diff" }))
            }
        }
        $tb = New-Text $text 13; $tb.Margin = '0,4,0,0'
        [void]$ui.FpsList.Children.Add($tb)
    }
}
$ui.FpsStart.Add_Click({
    $g = Get-RunningGame
    if (!$g) { $ui.FpsState.Text = T 'fps.nogame'; return }
    $ui.FpsStart.IsEnabled = $false
    $ui.FpsState.Text = (T 'fps.running') -f $g.Name
    Set-Status $ui.FpsState.Text $true
    Start-Work $fpsWork @($presentMonDir, $g.Exe, 30) {
        param($r, $g)
        $ui.FpsStart.IsEnabled = $true
        $res = Get-LastOutput $r
        if ($res -is [hashtable] -and $res.FrameTimes) { $res = Get-FpsStats $res.FrameTimes }
        if ($res -isnot [hashtable] -or $res.Error) {
            $ui.FpsState.Text = T $(if ($res -is [hashtable] -and $res.Error) { $res.Error } else { 'fps.nodata' }); Set-Status $ui.FpsState.Text; return
        }
        $entry = '{0}|{1}|{2}|{3}|{4}' -f (Get-Date).ToString('s'), $g.Name, $res.Avg, $res.Low, [int](Test-Boost)
        $list = @($entry) + @(Get-RegValue $settingsKey 'FpsResults' | Where-Object { $_ })
        if (!(Test-Path $settingsKey)) { New-Item -Path $settingsKey -Force | Out-Null }
        Set-ItemProperty -Path $settingsKey -Name FpsResults -Value ([string[]]@($list | Select-Object -First 12)) -Type MultiString -Force
        $ui.FpsState.Text = (T 'fps.done') -f $res.Frames
        Set-Status ((T 'fps.result.short') -f $g.Name, $res.Avg, $res.Low)
        Show-FpsResults
    } $g
})
Show-FpsResults

# FiveM: installed per user in %LOCALAPPDATA%\FiveM
$fivemDir = Join-Path $env:LOCALAPPDATA 'FiveM'
$fivemExe = Join-Path $fivemDir 'FiveM.exe'
$fivemData = Join-Path $fivemDir 'FiveM.app\data'
function Update-Fivem {
    $found = Test-Path -LiteralPath $fivemExe
    $ui.FivemState.Text = if ($found) { (T 'fivem.found') -f $fivemDir } else { T 'fivem.none' }
    foreach ($b in $ui.FivemClear, $ui.FivemOpen, $ui.FivemAdd) { $b.IsEnabled = $found }
    $ui.FivemServerHint.Visibility = if ($ui.FivemServer.Text) { 'Collapsed' } else { 'Visible' }
}
$ui.FivemServer.Text = [string](Get-RegValue $settingsKey 'FivemServer')
$ui.FivemServer.Add_TextChanged({ $ui.FivemServerHint.Visibility = if ($this.Text) { 'Collapsed' } else { 'Visible' } })
$ui.FivemOpen.Add_Click({ Start-Process explorer.exe -ArgumentList "`"$fivemDir`"" })
$ui.FivemAdd.Add_Click({ Add-Game $fivemExe; Set-Status (T 'fivem.added') })
# The cache folders FiveM rebuilds by itself; game files, settings and saved data stay
$ui.FivemClear.Add_Click({
    if (Get-Process -Name 'FiveM*' -ErrorAction SilentlyContinue) { Set-Status (T 'fivem.running'); return }
    $bytes = 0
    foreach ($name in 'cache', 'server-cache', 'server-cache-priv') {
        $dir = Join-Path $fivemData $name
        if (!(Test-Path -LiteralPath $dir)) { continue }
        $bytes += [double](Get-ChildItem -LiteralPath $dir -Recurse -File -Force -ErrorAction SilentlyContinue | Measure-Object Length -Sum).Sum
        Remove-Item -LiteralPath $dir -Recurse -Force -ErrorAction SilentlyContinue
    }
    Set-Status ((T 'fivem.cleared') -f (Format-Size $bytes))
})
# Connection time: TCP connect to the server (FiveM uses port 30120 when none is given), the average of 3 tries
$ui.FivemPing.Add_Click({
    $server = $ui.FivemServer.Text.Trim()
    if (!$server) { return }
    Save-Setting FivemServer $server
    $ui.FivemPing.IsEnabled = $false; $ui.FivemResult.Text = '...'
    Start-Work {
        param($server)
        $hostName, $port = $server -split ':', 2
        if (!$port) { $port = 30120 }
        $times = foreach ($i in 1..3) {
            $client = New-Object System.Net.Sockets.TcpClient
            $watch = [Diagnostics.Stopwatch]::StartNew()
            try {
                $wait = $client.BeginConnect($hostName, [int]$port, $null, $null)
                if ($wait.AsyncWaitHandle.WaitOne(3000) -and $client.Connected) { [int]$watch.ElapsedMilliseconds }
            } catch { } finally { $client.Close() }
        }
        if ($times) { [int](($times | Measure-Object -Average).Average) } else { -1 }
    } @($server) {
        param($r, $server)
        $ms = Get-LastOutput $r
        $ui.FivemResult.Text = if ($ms -ge 0) { (T 'fivem.result') -f $server, $ms } else { (T 'fivem.fail') -f $server }
        $ui.FivemPing.IsEnabled = $true
    } $server
})
Update-Fivem
$ui.GameAddButton.Add_Click({
    $dialog = New-Object Microsoft.Win32.OpenFileDialog
    $dialog.Title = T 'games.pick'; $dialog.Filter = 'Games (*.exe)|*.exe'
    if (!$dialog.ShowDialog($window)) { return }
    Add-Game $dialog.FileName
})
Show-Games

