<#
.SYNOPSIS
    Akati OS Center: Gaming apps: install, update and open the launchers and tools.
    Dot-sourced by AkatiCenter.ps1 (runs in its scope: $ui, $window, T and the other parts).
#>
# ---------------------------------------------------------------------------------------------
# Gaming apps
# ---------------------------------------------------------------------------------------------
Add-Mark 'Gaming apps'
# Id: WinGet package (used for updates). SelfUpdate: the app updates itself. Exe: where its icon comes from.
# Cat: section on the page (an installed app moves to "Installed" at the top). Source: where the installer
# comes from (WinGet, or the official site for Discord and Riot). Mono and Color: the tile shown until the app is installed (then its own icon).
# Arp: the DisplayName of its entry in Apps & features, for Uninstall.
$apps = @(
    @{ Key = 'Steam';      Cat = 'launchers'; Name = 'Steam';                   Mono = 'S';  Color = '#2A475E'; Arp = 'Steam'; SelfUpdate = $true
       Path = "${env:ProgramFiles(x86)}\Steam\steam.exe"; Exe = @("${env:ProgramFiles(x86)}\Steam\steam.exe") }
    @{ Key = 'Epic';       Cat = 'launchers'; Name = 'Epic Games Launcher';     Mono = 'E';  Color = '#4A4A4F'; Arp = 'Epic Games Launcher'; Id = 'EpicGames.EpicGamesLauncher'
       Path = "${env:ProgramFiles(x86)}\Epic Games\Launcher"
       Exe = @("${env:ProgramFiles(x86)}\Epic Games\Launcher\Portal\Binaries\Win64\EpicGamesLauncher.exe", "${env:ProgramFiles(x86)}\Epic Games\Launcher\Portal\Binaries\Win32\EpicGamesLauncher.exe") }
    @{ Key = 'EA';         Cat = 'launchers'; Name = 'EA app';                  Mono = 'EA'; Color = '#E5383B'; Arp = 'EA app'; Id = 'ElectronicArts.EADesktop'
       Path = "$env:ProgramFiles\Electronic Arts\EA Desktop"; Exe = @("$env:ProgramFiles\Electronic Arts\EA Desktop\EA Desktop\EADesktop.exe") }
    @{ Key = 'Ubisoft';    Cat = 'launchers'; Name = 'Ubisoft Connect';         Mono = 'U';  Color = '#0A6CD6'; Arp = 'Ubisoft Connect'; Id = 'Ubisoft.Connect'
       Path = "${env:ProgramFiles(x86)}\Ubisoft\Ubisoft Game Launcher"
       Exe = @("${env:ProgramFiles(x86)}\Ubisoft\Ubisoft Game Launcher\UbisoftConnect.exe", "${env:ProgramFiles(x86)}\Ubisoft\Ubisoft Game Launcher\upc.exe") }
    @{ Key = 'BattleNet';  Cat = 'launchers'; Name = 'Battle.net';              Mono = 'B';  Color = '#148EFF'; Arp = 'Battle.net'; Id = 'Blizzard.BattleNet'
       Path = "$env:ProgramFiles\Battle.net"; Path2 = "${env:ProgramFiles(x86)}\Battle.net"
       Exe = @("$env:ProgramFiles\Battle.net\Battle.net Launcher.exe", "${env:ProgramFiles(x86)}\Battle.net\Battle.net Launcher.exe", "$env:ProgramFiles\Battle.net\Battle.net.exe") }
    @{ Key = 'Riot';       Cat = 'launchers'; Name = 'Riot Client (VALORANT)';  Mono = 'R';  Color = '#D13639'; Arp = 'VALORANT'; SelfUpdate = $true; Source = 'official'
       Path = "$env:SystemDrive\Riot Games\Riot Client\RiotClientServices.exe"; Exe = @("$env:SystemDrive\Riot Games\Riot Client\RiotClientServices.exe") }
    @{ Key = 'GOG';        Cat = 'launchers'; Name = 'GOG GALAXY';              Mono = 'G';  Color = '#86328A'; Arp = 'GOG GALAXY*'; Id = 'GOG.Galaxy'
       Path = "${env:ProgramFiles(x86)}\GOG Galaxy\GalaxyClient.exe"; Exe = @("${env:ProgramFiles(x86)}\GOG Galaxy\GalaxyClient.exe") }
    @{ Key = 'Rockstar';   Cat = 'launchers'; Name = 'Rockstar Games Launcher'; Mono = 'RS'; Color = '#C98A0B'; Arp = 'Rockstar Games Launcher'; Id = 'RockstarGames.Launcher'
       Path = "$env:ProgramFiles\Rockstar Games\Launcher\Launcher.exe"; Exe = @("$env:ProgramFiles\Rockstar Games\Launcher\Launcher.exe") }
    @{ Key = 'Discord';    Cat = 'social';    Name = 'Discord';                 Mono = 'D';  Color = '#5865F2'; Arp = 'Discord'; SelfUpdate = $true; Source = 'official'
       Path = "$env:LOCALAPPDATA\Discord\packages\RELEASES"; Exe = @("$env:LOCALAPPDATA\Discord\app-*\Discord.exe") }
    @{ Key = 'OBS';        Cat = 'social';    Name = 'OBS Studio';              Mono = 'O';  Color = '#5C5C66'; Arp = 'OBS Studio*'; Id = 'OBSProject.OBSStudio'
       Path = "$env:ProgramFiles\obs-studio"; Exe = @("$env:ProgramFiles\obs-studio\bin\64bit\obs64.exe") }
    @{ Key = 'Afterburner'; Cat = 'tools';    Name = 'MSI Afterburner';         Mono = 'A';  Color = '#B3202A'; Arp = 'MSI Afterburner*'; Id = 'Guru3D.Afterburner'
       Path = "${env:ProgramFiles(x86)}\MSI Afterburner\MSIAfterburner.exe"; Exe = @("${env:ProgramFiles(x86)}\MSI Afterburner\MSIAfterburner.exe") }
)
$appCats = 'installed', 'launchers', 'social', 'tools'

function New-Text([string]$text, [double]$size = 13, [string]$weight = 'Normal', [string]$tag = $null) {
    $tb = New-Object System.Windows.Controls.TextBlock
    $tb.Text = $text; $tb.FontSize = $size; $tb.FontWeight = $weight; $tb.TextWrapping = 'Wrap'
    if ($tag) { $tb.Tag = $tag }
    return $tb
}

# Icon of a program file as a WPF image (the real app icon instead of a glyph)
Add-Type -AssemblyName System.Drawing
function Get-FileIcon([string[]]$paths) {
    foreach ($pattern in $paths) {
        $file = Get-Item -Path $pattern -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending | Select-Object -First 1
        if (!$file) { continue }
        try {
            $icon = [System.Drawing.Icon]::ExtractAssociatedIcon($file.FullName)
            $src = [System.Windows.Interop.Imaging]::CreateBitmapSourceFromHIcon($icon.Handle, [System.Windows.Int32Rect]::Empty, [System.Windows.Media.Imaging.BitmapSizeOptions]::FromEmptyOptions())
            $icon.Dispose()
            $src.Freeze()
            return $src
        } catch { }
    }
    return $null
}

# A list row: icon, title, sub text, optional progress bar and the control on the right.
# $left (optional) goes before the icon, for example a check box.
function New-Row([string]$glyph, [string]$title, [string]$titleTag, [System.Windows.UIElement]$right, [string]$subTag, [System.Windows.UIElement]$left = $null) {
    $border = New-Object System.Windows.Controls.Border
    $border.Padding = '14,10'; $border.Background = [System.Windows.Media.Brushes]::Transparent
    $grid = New-Object System.Windows.Controls.Grid
    foreach ($w in 'Auto', 'Auto', '*', 'Auto') { $c = New-Object System.Windows.Controls.ColumnDefinition; $c.Width = $w; $grid.ColumnDefinitions.Add($c) }
    if ($left) { $left.Margin = '0,0,14,0'; $left.VerticalAlignment = 'Center'; [void]$grid.Children.Add($left) }
    $icon = New-Object System.Windows.Controls.Border
    $icon.Width = 30; $icon.Height = 30; $icon.CornerRadius = 7; $icon.SetResourceReference([System.Windows.Controls.Border]::BackgroundProperty, 'Fill'); $icon.Margin = '0,0,12,0'
    $g = New-Text $glyph 16; $g.Style = $window.FindResource('Glyph'); $g.HorizontalAlignment = 'Center'; $g.SetResourceReference([System.Windows.Controls.TextBlock]::ForegroundProperty, 'Accent2')
    $icon.Child = $g
    [System.Windows.Controls.Grid]::SetColumn($icon, 1)
    $text = New-Object System.Windows.Controls.StackPanel
    $text.VerticalAlignment = 'Center'
    $t = New-Text $title 14 'SemiBold' $titleTag
    $s = New-Text '' 12 'Normal' $subTag; $s.Foreground = $window.FindResource('MutedBrush'); $s.Margin = '0,2,12,0'
    $bar = New-Object System.Windows.Controls.ProgressBar
    $bar.Style = $window.FindResource('Progress'); $bar.Margin = '0,8,16,2'; $bar.Visibility = 'Collapsed'
    [void]$text.Children.Add($t); [void]$text.Children.Add($s); [void]$text.Children.Add($bar)
    [System.Windows.Controls.Grid]::SetColumn($text, 2)
    [System.Windows.Controls.Grid]::SetColumn($right, 3)
    $right.VerticalAlignment = 'Center'
    [void]$grid.Children.Add($icon); [void]$grid.Children.Add($text); [void]$grid.Children.Add($right)
    $border.Child = $grid
    return @{ Row = $border; Sub = $s; Title = $t; Icon = $icon; Bar = $bar }
}

# Thin lines between the rows of a grouped list (macOS style): every visible row but the first
function Update-Separators($panel) {
    $first = $true
    foreach ($child in $panel.Children) {
        if ($child -isnot [System.Windows.Controls.Border] -or $child.Visibility -ne 'Visible') { continue }
        $child.SetResourceReference([System.Windows.Controls.Border]::BorderBrushProperty, 'Line')
        $child.BorderThickness = if ($first) { '0' } else { '0,1,0,0' }
        $first = $false
    }
}

function Set-RowIcon($row, $image) {
    if (!$image) { return }
    $img = New-Object System.Windows.Controls.Image
    $img.Source = $image; $img.Width = 26; $img.Height = 26
    [System.Windows.Media.RenderOptions]::SetBitmapScalingMode($img, 'HighQuality')
    $row.Icon.Child = $img
}

function Test-App($app) {
    if (Test-Path -LiteralPath $app.Path) { return $true }
    if ($app.Path2 -and (Test-Path -LiteralPath $app.Path2)) { return $true }
    return $false
}

# App Store style progress ring on the button: the arc shows the percentage, the square means Stop.
# Unknown percentage: a short arc that turns. Waiting in the queue: the ring without an arc.
function New-Ring {
    $grid = New-Object System.Windows.Controls.Grid
    $grid.Width = 28; $grid.Height = 28
    $track = New-Object System.Windows.Shapes.Ellipse
    $track.SetResourceReference([System.Windows.Shapes.Shape]::StrokeProperty, 'FillHover'); $track.StrokeThickness = 2.5
    $arc = New-Object System.Windows.Shapes.Path
    $arc.StrokeThickness = 2.5; $arc.StrokeStartLineCap = 'Round'; $arc.StrokeEndLineCap = 'Round'
    $arc.SetResourceReference([System.Windows.Shapes.Shape]::StrokeProperty, 'Accent2')
    $spin = New-Object System.Windows.Media.RotateTransform
    $arc.RenderTransformOrigin = '0.5,0.5'; $arc.RenderTransform = $spin
    $stop = New-Object System.Windows.Shapes.Rectangle
    $stop.Width = 8; $stop.Height = 8; $stop.RadiusX = 1.5; $stop.RadiusY = 1.5
    $stop.SetResourceReference([System.Windows.Shapes.Shape]::FillProperty, 'Accent2')
    [void]$grid.Children.Add($track); [void]$grid.Children.Add($arc); [void]$grid.Children.Add($stop)
    return @{ Root = $grid; Arc = $arc; Spin = $spin; Spinning = $false }
}
# $percent: 0-100, -1 unknown (turning), -2 waiting (no arc)
function Set-Ring($ring, [int]$percent) {
    $turn = $percent -eq -1
    if ($turn -ne $ring.Spinning) {
        if ($turn) {
            $anim = New-Object System.Windows.Media.Animation.DoubleAnimation 0, 360, (New-Object System.Windows.Duration ([TimeSpan]::FromSeconds(1)))
            $anim.RepeatBehavior = [System.Windows.Media.Animation.RepeatBehavior]::Forever
            $ring.Spin.BeginAnimation([System.Windows.Media.RotateTransform]::AngleProperty, $anim)
        } else { $ring.Spin.BeginAnimation([System.Windows.Media.RotateTransform]::AngleProperty, $null); $ring.Spin.Angle = 0 }
        $ring.Spinning = $turn
    }
    if ($percent -eq -2) { $ring.Arc.Data = $null; return }
    $value = if ($turn) { 25 } else { [Math]::Max(2, [Math]::Min(100, $percent)) }
    $r = 12.75; $c = 14
    if ($value -ge 100) { $ring.Arc.Data = New-Object System.Windows.Media.EllipseGeometry (New-Object System.Windows.Point $c, $c), $r, $r; return }
    $a = [Math]::PI * 2 * $value / 100
    $end = New-Object System.Windows.Point ($c + $r * [Math]::Sin($a)), ($c - $r * [Math]::Cos($a))
    $seg = New-Object System.Windows.Media.ArcSegment $end, (New-Object System.Windows.Size $r, $r), 0, ($value -gt 50), ([System.Windows.Media.SweepDirection]::Clockwise), $true
    $fig = New-Object System.Windows.Media.PathFigure
    $fig.StartPoint = New-Object System.Windows.Point $c, ($c - $r)
    $fig.Segments.Add($seg)
    $geo = New-Object System.Windows.Media.PathGeometry
    $geo.Figures.Add($fig)
    $ring.Arc.Data = $geo
}

# State of a row: idle, queued, install, update. Only one install or update runs at a time
# (installers and WinGet do not like to run side by side), the others wait in the queue.
$progressDir = Join-Path $env:LOCALAPPDATA 'AkatiOS\Logs'
function Update-AppRow($app) {
    # The rows are made when the page first opens (Initialize-Apps)
    if (!$app.Button) { return }
    $installed = Test-App $app
    $btn = $app.Button
    $busy = $app.State -ne 'idle'
    # Version and size are read again after an install or uninstall
    if ($installed -ne $app.WasInstalled) { $app.Details = $null; $app.WasInstalled = $installed }
    # An app being installed stays in its section until it is done
    $app.IsInstalled = $installed -and $app.State -notin 'install', 'queued'
    Update-AppGroups
    $app.More.Visibility = if ($installed -and !$busy -and !$app.Uninstalling) { 'Visible' } else { 'Collapsed' }
    $app.Bar.Visibility = 'Collapsed'
    if ($busy) {
        $btn.Style = $window.FindResource('Bare'); $btn.Padding = '4'; $btn.MinWidth = 0; $btn.Content = $app.Ring.Root; $btn.IsEnabled = $true
        $btn.ToolTip = T 'cancel'
        switch ($app.State) {
            'update' { Set-Ring $app.Ring -1; $app.Sub.Text = T 'updating'; $app.Sub.Foreground = $window.FindResource('Accent2') }
            'queued' { Set-Ring $app.Ring -2; $app.Sub.Text = T 'queued'; $app.Sub.Foreground = $window.FindResource('MutedBrush') }
        }
        return
    }
    Set-Ring $app.Ring -2
    $btn.ToolTip = $null; $btn.ClearValue([System.Windows.Controls.Control]::PaddingProperty); $btn.ClearValue([System.Windows.FrameworkElement]::MinWidthProperty)
    $btn.IsEnabled = !$app.Uninstalling
    if ($app.Uninstalling) {
        $app.Sub.Text = T 'uninstalling'; $app.Sub.Foreground = $window.FindResource('Accent2')
        $btn.Style = $window.FindResource('Pill'); $btn.Content = T 'open'
    } elseif ($installed -and $app.HasUpdate) {
        $app.Sub.Text = T 'updateavailable'; $app.Sub.Foreground = $window.FindResource('Accent2')
        $btn.Style = $window.FindResource('PillAccent'); $btn.Content = T 'update'
    } elseif ($installed) {
        $parts = @(T 'installed')
        $details = Get-AppDetails $app
        if ($details) { $parts += $details }
        if ($app.SelfUpdate) { $parts += T 'selfupdate' }
        $app.Sub.Text = $parts -join ' · '
        $app.Sub.Foreground = $window.FindResource('Good')
        $btn.Style = $window.FindResource('Pill'); $btn.Content = T 'open'
    } else {
        $app.Sub.Text = T "app.desc.$($app.Key)"; $app.Sub.Foreground = $window.FindResource('MutedBrush')
        $btn.Style = $window.FindResource('Pill'); $btn.Content = T 'get'
    }
    if ($installed -and !$app.HasIcon) {
        $image = Get-FileIcon $app.Exe
        if ($image) { $app.RowParts.Icon.SetResourceReference([System.Windows.Controls.Border]::BackgroundProperty, 'Fill'); Set-RowIcon $app.RowParts $image; $app.HasIcon = $true }
    } elseif (!$installed -and $app.HasIcon) {
        # Uninstalled: back to the letter tile
        $app.RowParts.Icon.Background = $app.Color; $app.RowParts.Icon.Child = $app.Tile; $app.HasIcon = $false
    }
}

# Opens an installed app as the signed-in user (through Explorer), not as administrator like this window
function Get-AppExe($app) {
    foreach ($pattern in $app.Exe) {
        $file = Get-Item -Path $pattern -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending | Select-Object -First 1
        if ($file) { return $file.FullName }
    }
    return $null
}
function Open-App($app) {
    $exe = Get-AppExe $app
    if (!$exe) { return }
    Start-Process explorer.exe -ArgumentList "`"$exe`""
    Set-Status ((T 'status.opening') -f $app.Name)
}
function Open-AppFolder($app) {
    $exe = Get-AppExe $app
    $folder = if ($exe) { Split-Path $exe -Parent } elseif (Test-Path -LiteralPath $app.Path -PathType Container) { $app.Path } else { $null }
    if ($folder) { Start-Process explorer.exe -ArgumentList "`"$folder`"" }
}
# The app's entry in Apps & features: its uninstaller, version and size
function Get-ArpEntry($app) {
    foreach ($root in 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall', 'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall', 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall') {
        foreach ($key in @(Get-ChildItem -Path $root -ErrorAction SilentlyContinue)) {
            $entry = Get-ItemProperty -LiteralPath $key.PSPath -ErrorAction SilentlyContinue
            if ($entry.DisplayName -like $app.Arp -and $entry.UninstallString) { return $entry }
        }
    }
    return $null
}
# Uninstall runs the app's own uninstaller (it shows its own window)
function Find-Uninstaller($app) {
    $entry = Get-ArpEntry $app
    if ($entry) { return [string]$entry.UninstallString }
    return $null
}
# "1.0.9218 · 450 MB" for an installed app, read once (again after an install, update or uninstall)
function Get-AppDetails($app) {
    if ($null -eq $app.Details) {
        $entry = Get-ArpEntry $app
        $parts = @()
        if ($entry.DisplayVersion) { $parts += [string]$entry.DisplayVersion }
        if ($entry.EstimatedSize -gt 0) { $parts += Format-Size ([double]$entry.EstimatedSize * 1KB) }
        $app.Details = $parts -join ' · '
    }
    return $app.Details
}
function Start-Uninstall($app) {
    $answer = [System.Windows.MessageBox]::Show(((T 'uninstall.confirm') -f $app.Name), 'Akati OS Center', 'YesNo', 'Question')
    if ($answer -ne 'Yes') { return }
    $command = Find-Uninstaller $app
    if (!$command) { Set-Status ((T 'status.nouninstaller') -f $app.Name); Start-Process 'ms-settings:appsfeatures'; return }
    $app.Uninstalling = $true
    Update-AppRow $app
    Set-Status ((T 'uninstalling')) $true
    Start-Work {
        param($command)
        # cmd.exe runs the command line exactly as Apps & features would (quotes and switches included)
        $p = Start-Process cmd.exe -ArgumentList "/c `"$command`"" -WindowStyle Hidden -PassThru
        $p.WaitForExit()
    } @($command) {
        param($r, $app)
        $app.Uninstalling = $false
        if (Test-App $app) { Set-Status (T 'ready') } else { Set-Status ((T 'status.uninstalled') -f $app.Name) }
        Update-AppRow $app; Update-AppsToolbar
    } $app
}

function Update-AppsToolbar {
    $count = @($apps | Where-Object { $_.HasUpdate -and $_.State -eq 'idle' }).Count
    $ui.UpdateAllButton.IsEnabled = $count -gt 0
    $ui.UpdateAllText.Text = if ($count) { (T 'apps.updatecount') -f $count } else { T 'apps.updateall' }
    $ui.StarterButton.IsEnabled = [bool]@($apps | Where-Object { $_.Key -in 'Steam', 'Discord' -and $_.State -eq 'idle' -and !(Test-App $_) }).Count
}

# Moves the rows: installed apps to "Installed" at the top, the others to their section, in the order of $apps
function Update-AppGroups {
    if (!$script:appsReady) { return }
    $key = ($apps | ForEach-Object { [int][bool]$_.IsInstalled }) -join ''
    if ($key -eq $script:appGroupsKey) { return }
    $script:appGroupsKey = $key
    Request-MenuUpdate
    foreach ($g in $appGroups.Values) { $g.List.Children.Clear() }
    foreach ($a in $apps) {
        $target = if ($a.IsInstalled) { 'installed' } else { $a.Cat }
        [void]$appGroups[$target].List.Children.Add($a.RowParts.Row)
    }
    foreach ($g in $appGroups.Values) {
        $shown = if ($g.List.Children.Count) { 'Visible' } else { 'Collapsed' }
        $g.Head.Visibility = $shown; $g.Card.Visibility = $shown
        Update-Separators $g.List
    }
}

function Start-NextApp {
    # Discord keeps updating itself after its installer ("finish"); the next app does not wait for that
    if (@($apps | Where-Object { $_.State -in 'install', 'update' -and $_.Stage -ne 'finish' }).Count) { return }
    $next = $apps | Where-Object { $_.State -eq 'queued' } | Select-Object -First 1
    if (!$next) { Set-Status (T 'ready'); return }
    $mode = if ($next.QueuedMode) { $next.QueuedMode } else { 'install' }
    $next.State = $mode; $next.Stage = $null
    $next.Shared = [hashtable]::Synchronized(@{ Pid = 0 })
    $progressFile = Join-Path $progressDir "GAMEAPPS-$($next.Key).progress"
    Remove-Item -LiteralPath $progressFile -Force -ErrorAction SilentlyContinue
    Set-Ring $next.Ring -1
    $next.Sub.Text = if ($mode -eq 'update') { T 'updating' } else { T 'preparing' }
    $next.Sub.Foreground = $window.FindResource('Accent2')
    Update-AppRow $next
    Update-AppsToolbar
    if ($mode -eq 'update') {
        Set-Status ((T 'status.updating') -f $next.Name) $true
        Start-Work {
            param($id, $shared)
            $p = Start-Process winget -ArgumentList @('upgrade', '--id', $id, '--exact', '--source', 'winget', '--silent', '--accept-package-agreements', '--accept-source-agreements', '--disable-interactivity') -WindowStyle Hidden -PassThru
            $null = $p.Handle; $shared.Pid = $p.Id
            $p.WaitForExit()
            $p.ExitCode
        } @($next.Id, $next.Shared) {
            param($r, $app)
            $app.State = 'idle'
            if ($app.Cancelled) { $app.Cancelled = $false; Set-Status ((T 'status.cancelled') -f $app.Name) }
            elseif ((Get-LastOutput $r) -eq 0) { $app.HasUpdate = $false; $app.Details = $null; Set-Status ((T 'status.updated') -f $app.Name) }
            else { Set-Status ((T 'status.updatefailed') -f $app.Name) }
            Update-AppRow $app; Update-AppsToolbar; Start-NextApp
        } $next
    } else {
        Set-Status ((T 'status.installing') -f $next.Name) $true
        Start-Work {
            param($script, $key, $shared)
            $p = Start-Process powershell.exe -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$script`" -App $key" -WindowStyle Hidden -PassThru
            $null = $p.Handle; $shared.Pid = $p.Id
            $p.WaitForExit()
        } @($gameApps, $next.Key, $next.Shared) {
            param($r, $app)
            $app.State = 'idle'
            if ($app.Cancelled) { $app.Cancelled = $false; Set-Status ((T 'status.cancelled') -f $app.Name) }
            elseif (Test-App $app) { Set-Status ((T 'status.installed') -f $app.Name) }
            else { Set-Status ((T 'status.notinstalled') -f $app.Name) }
            Update-AppRow $app; Update-AppsToolbar; Start-NextApp
        } $next
    }
}

function Add-AppToQueue($app, [string]$mode = 'install') {
    if ($app.State -ne 'idle') { return }
    $app.State = 'queued'; $app.QueuedMode = $mode
    Update-AppRow $app
    Start-NextApp
}

function Stop-AppJob($app) {
    if ($app.State -eq 'queued') { $app.State = 'idle'; Update-AppRow $app; Update-AppsToolbar; return }
    $app.Cancelled = $true
    $app.Button.IsEnabled = $false
    $app.Sub.Text = T 'cancelling'
    # Stop the script and everything it started (WinGet, curl, the installer)
    if ($app.Shared -and $app.Shared.Pid) { & taskkill.exe /PID $app.Shared.Pid /T /F *> $null }
    if ($app.Key -eq 'Discord') {
        # Discord installs through a scheduled task as the signed-in user
        Stop-ScheduledTask -TaskName 'AkatiOS Install Discord' -ErrorAction SilentlyContinue
        Unregister-ScheduledTask -TaskName 'AkatiOS Install Discord' -Confirm:$false -ErrorAction SilentlyContinue
        Get-Process -Name 'DiscordSetup', 'Discord-Setup' -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
    }
}

# Progress written by GAMEAPPS.ps1: "<stage>|<percent>", percent is -1 when unknown
function Update-AppProgress {
    # While an app installs or updates, the status bar says so (another message may have replaced it)
    $running = $apps | Where-Object { $_.State -in 'install', 'update' -and !$_.Cancelled } | Select-Object -First 1
    if ($running -and !$script:statusBusy) {
        Set-Status ((T $(if ($running.State -eq 'update') { 'status.updating' } else { 'status.installing' })) -f $running.Name) $true
    }
    foreach ($app in $apps) {
        if ($app.State -ne 'install' -or $app.Cancelled) { continue }
        $line = $null
        try { $line = [IO.File]::ReadAllText((Join-Path $progressDir "GAMEAPPS-$($app.Key).progress")) } catch { }
        if (!$line) { continue }
        $stage, $percent = $line.Trim() -split '\|'
        $percent = [int]$percent
        if ($stage -ne $app.Stage) {
            $app.Stage = $stage
            if ($stage -eq 'finish') { Start-NextApp }
        }
        if ($stage -eq 'download' -and $percent -ge 0) {
            Set-Ring $app.Ring $percent
            $app.Sub.Text = (T 'stage.download') + " $percent%"
        } else {
            Set-Ring $app.Ring -1
            $app.Sub.Text = T "stage.$stage"
        }
    }
}

# The "..." menu of an installed app
function New-AppMenu($app) {
    $menu = New-Object System.Windows.Controls.ContextMenu
    $menu.Style = $window.FindResource('MacMenu')
    foreach ($item in @(@{ Text = T 'openfolder'; Action = 'folder' }, @{ Text = T 'uninstall'; Action = 'uninstall' })) {
        $mi = New-Object System.Windows.Controls.MenuItem
        # Uninstall in red, like a destructive action in macOS
        $mi.Style = $window.FindResource($(if ($item.Action -eq 'uninstall') { 'MacMenuDanger' } else { 'MacMenuItem' }))
        $mi.Header = $item.Text; $mi.Tag = @{ App = $app; Action = $item.Action }
        $mi.Add_Click({ if ($this.Tag.Action -eq 'folder') { Open-AppFolder $this.Tag.App } else { Start-Uninstall $this.Tag.App } })
        [void]$menu.Items.Add($mi)
    }
    return $menu
}

# The rows are made the first time something needs them (the Gaming apps page, Ctrl+K), not when the app
# starts: reading the version and size of each installed app from Apps & features took about half a second.
$appGroups = @{}
function Initialize-Apps {
    if ($script:appsReady) { return }
    # One gray heading and one grouped list per category
    foreach ($cat in $appCats) {
        $head = New-Text (T "apps.cat.$cat") 13 'SemiBold' "t:apps.cat.$cat"
        $head.Style = $window.FindResource('Section')
        $card = New-Object System.Windows.Controls.Border
        $card.Style = $window.FindResource('Card'); $card.Padding = '0'; $card.Margin = '0,0,0,20'
        $list = New-Object System.Windows.Controls.StackPanel
        $card.Child = $list
        [void]$ui.AppsGroups.Children.Add($head); [void]$ui.AppsGroups.Children.Add($card)
        $appGroups[$cat] = @{ Head = $head; Card = $card; List = $list }
    }
    foreach ($app in $apps) {
        $btn = New-Object System.Windows.Controls.Button
        $btn.Style = $window.FindResource('Pill')
        $more = New-Object System.Windows.Controls.Button
        $more.Style = $window.FindResource('Bare'); $more.Padding = '7'; $more.Margin = '0,0,8,0'; $more.ToolTip = T 'more'
        $dots = New-Text ([string][char]0xE712) 14; $dots.Style = $window.FindResource('Glyph'); $more.Content = $dots
        $right = New-Object System.Windows.Controls.StackPanel; $right.Orientation = 'Horizontal'
        [void]$right.Children.Add($more); [void]$right.Children.Add($btn)
        $row = New-Row ([string][char]0xE7FC) $app.Name $null $right $null
        # Small badge after the name: where the installer comes from
        $source = if ($app.Source) { $app.Source } else { 'winget' }
        $badge = New-Object System.Windows.Controls.Border
        $badge.CornerRadius = 4; $badge.SetResourceReference([System.Windows.Controls.Border]::BackgroundProperty, 'Fill'); $badge.Padding = '5,1'; $badge.Margin = '8,0,0,0'; $badge.VerticalAlignment = 'Center'
        $badgeText = New-Text (T "src.$source") 10 'SemiBold' "t:src.$source"; $badgeText.Foreground = $window.FindResource('MutedBrush')
        $badge.Child = $badgeText
        $titleLine = New-Object System.Windows.Controls.StackPanel; $titleLine.Orientation = 'Horizontal'
        $textPanel = $row.Title.Parent
        $textPanel.Children.Remove($row.Title)
        [void]$titleLine.Children.Add($row.Title); [void]$titleLine.Children.Add($badge)
        $textPanel.Children.Insert(0, $titleLine)
        # Letter tile until the app is installed (no logos)
        $tile = New-Text $app.Mono $(if ($app.Mono.Length -gt 1) { 11 } else { 14 }) 'Bold'
        $tile.Foreground = 'White'; $tile.HorizontalAlignment = 'Center'; $tile.VerticalAlignment = 'Center'
        $row.Icon.Background = $app.Color; $row.Icon.Child = $tile
        $app.Tile = $tile; $app.Ring = New-Ring
        $app.Sub = $row.Sub; $app.Button = $btn; $app.More = $more; $app.Bar = $row.Bar; $app.RowParts = $row
        $app.State = 'idle'; $app.HasUpdate = $false; $app.Uninstalling = $false
        $btn.Tag = $app; $more.Tag = $app
        $btn.Add_Click({
            $a = $this.Tag
            if ($a.State -ne 'idle') { Stop-AppJob $a; return }
            if (Test-App $a) { if ($a.HasUpdate) { Add-AppToQueue $a 'update' } else { Open-App $a } } else { Add-AppToQueue $a 'install' }
        })
        $more.Add_Click({
            $menu = New-AppMenu $this.Tag
            $menu.PlacementTarget = $this; $menu.Placement = 'Bottom'; $menu.IsOpen = $true
        })
        Update-AppRow $app
    }
    $script:appsReady = $true
    Update-AppGroups
    Update-AppsToolbar
}
if ($Screenshot) { Initialize-Apps } else { Update-AppsToolbar }
# Installed or uninstalled outside this window: look again when the window comes back to the front
$window.Add_Activated({ if ($script:appsReady) { foreach ($a in $apps) { if ($a.State -eq 'idle' -and !$a.Uninstalling) { Update-AppRow $a } }; Update-AppsToolbar } })

$ui.StarterButton.Add_Click({
    foreach ($a in $apps) { if ($a.Key -in 'Steam', 'Discord' -and $a.State -eq 'idle' -and !(Test-App $a)) { Add-AppToQueue $a 'install' } }
    Update-AppsToolbar
})
$ui.UpdateAllButton.Add_Click({
    foreach ($a in $apps) { if ($a.HasUpdate -and $a.State -eq 'idle') { Add-AppToQueue $a 'update' } }
    Update-AppsToolbar
})

# Which installed apps have a newer version in WinGet (Steam and Discord update themselves)
# $quiet: the automatic check when the page opens; it says nothing when there is nothing to update
function Start-AppUpdateCheck([bool]$quiet = $false) {
    if (!(Get-Command winget -ErrorAction SilentlyContinue)) { if (!$quiet) { Set-Status (T 'status.nowinget') }; return }
    $ids = @($apps | Where-Object { $_.Id -and (Test-App $_) } | ForEach-Object { $_.Id })
    if ($quiet -and !$ids.Count) { return }
    $ui.CheckUpdatesButton.IsEnabled = $false
    Set-Status (T 'status.checkingapps') $true
    # One WinGet query per app: "list --upgrade-available" finds the app only when a newer version exists
    # (the table of "winget upgrade" cuts long names, so it is not parsed)
    Start-Work {
        param($ids)
        $found = @{}
        foreach ($id in $ids) {
            & winget list --id $id --exact --upgrade-available --source winget --accept-source-agreements --disable-interactivity *> $null
            $found[$id] = ($LASTEXITCODE -eq 0)
        }
        $found
    } @(, $ids) {
        param($r, $ctx)
        $ui.CheckUpdatesButton.IsEnabled = $true
        $found = Get-LastOutput $r
        $count = 0
        foreach ($a in $apps) {
            $a.HasUpdate = [bool]($a.Id -and $found -and $found[$a.Id])
            if ($a.HasUpdate) { $count++ }
            if ($a.State -eq 'idle') { Update-AppRow $a }
        }
        Update-AppsToolbar
        if ($count) { Set-Status ((T 'status.updatesfound') -f $count) } elseif ($ctx) { Set-Status (T 'ready') } else { Set-Status (T 'status.noupdates') }
    } $quiet
}
$ui.CheckUpdatesButton.Add_Click({ Start-AppUpdateCheck })

# GPU drivers: highlight the vendor of the graphics card in this PC
# The graphics cards are read in the background (WMI takes a moment); until then the card shows no text
$gpuQuery = { @(try { Get-CimInstance Win32_VideoController | Where-Object { $_.Name -notmatch 'Basic Display|Remote|Virtual|VMware|Hyper-V|Parsec' } } catch { }) }
$gpus = @(); $gpuNames = @(); $script:gpusLoaded = $false
$gpuVendors = @{ GpuNvidia = 'NVIDIA|GeForce|Quadro|RTX|GTX'; GpuAmd = 'AMD|Radeon|ATI '; GpuIntel = 'Intel|Arc ' }
$script:gpuFound = @()
function Set-Gpus($list) {
    $script:gpus = @($list | Where-Object { $_ })
    $script:gpuNames = @($script:gpus | ForEach-Object { $_.Name })
    $script:gpusLoaded = $true
    foreach ($k in $gpuVendors.Keys) {
        if (@($script:gpuNames | Where-Object { $_ -match $gpuVendors[$k] }).Count) {
            $ui[$k].Style = $window.FindResource('PillAccent'); $script:gpuFound += $k
        }
    }
    Update-GpuText
}
function Update-GpuText {
    if (!$script:gpusLoaded) { $ui.GpuDetected.Text = ''; $ui.GpuDriver.Visibility = 'Collapsed'; return }
    $ui.GpuDetected.Text = if ($gpuNames.Count) { (T 'gpu.detected') -f ($gpuNames -join ', ') } else { T 'gpu.none' }
    # Installed driver version and date; older than about 6 months: a hint to look for a newer one
    $culture = (Get-LangCulture)
    $lines = @(); $old = $false
    foreach ($g in $gpus) {
        if (!$g.DriverVersion -or !$g.DriverDate) { continue }
        $lines += (T 'gpu.driver') -f $g.Name, $g.DriverVersion, $g.DriverDate.ToString('d MMMM yyyy', $culture)
        if (((Get-Date) - $g.DriverDate).TotalDays -gt 180) { $old = $true }
    }
    if ($old) { $lines += T 'gpu.old' }
    $ui.GpuDriver.Text = $lines -join "`n"
    $ui.GpuDriver.Visibility = if ($lines.Count) { 'Visible' } else { 'Collapsed' }
    if ($old) { $ui.GpuDriver.Foreground = '#FF9F0A' } else { $ui.GpuDriver.Foreground = $window.FindResource('MutedBrush') }
}
if ($Screenshot) { Set-Gpus (& $gpuQuery) } else { Update-GpuText; Start-Work $gpuQuery @() { param($r) Set-Gpus @($r) } $null }
$ui.GpuNvidia.Add_Click({ Start-Process 'https://www.nvidia.com/en-us/drivers/' })
$ui.GpuAmd.Add_Click({ Start-Process 'https://www.amd.com/en/support/download/drivers.html' })
$ui.GpuIntel.Add_Click({ Start-Process 'https://www.intel.com/content/www/us/en/download-center/home.html' })

# Screen refresh rate and the standby memory list (Windows API)
Import-Code 'Perf' @'
using System;
using System.Runtime.InteropServices;
namespace AkatiOS {
    // Display refresh rate (primary screen) and the standby memory list
    public static class Perf {
        [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
        public struct DEVMODE {
            [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 32)] public string dmDeviceName;
            public short dmSpecVersion, dmDriverVersion, dmSize, dmDriverExtra;
            public int dmFields, dmPositionX, dmPositionY, dmDisplayOrientation, dmDisplayFixedOutput;
            public short dmColor, dmDuplex, dmYResolution, dmTTOption, dmCollate;
            [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 32)] public string dmFormName;
            public short dmLogPixels;
            public int dmBitsPerPel, dmPelsWidth, dmPelsHeight, dmDisplayFlags, dmDisplayFrequency;
            public int dmICMMethod, dmICMIntent, dmMediaType, dmDitherType, dmReserved1, dmReserved2, dmPanningWidth, dmPanningHeight;
        }
        [DllImport("user32.dll", CharSet = CharSet.Unicode)] static extern bool EnumDisplaySettings(string device, int mode, ref DEVMODE dm);
        [DllImport("user32.dll", CharSet = CharSet.Unicode)] static extern int ChangeDisplaySettingsEx(string device, ref DEVMODE dm, IntPtr hwnd, int flags, IntPtr param);

        static DEVMODE NewMode() { DEVMODE dm = new DEVMODE(); dm.dmSize = (short)Marshal.SizeOf(typeof(DEVMODE)); return dm; }
        // Width, height and refresh rate now (0 when unknown)
        public static int[] Current() {
            DEVMODE dm = NewMode();
            if (!EnumDisplaySettings(null, -1, ref dm)) return new int[] { 0, 0, 0 };
            return new int[] { dm.dmPelsWidth, dm.dmPelsHeight, dm.dmDisplayFrequency };
        }
        // Highest refresh rate at the current resolution and color depth
        public static int MaxHz() {
            DEVMODE cur = NewMode();
            if (!EnumDisplaySettings(null, -1, ref cur)) return 0;
            int max = 0;
            DEVMODE dm = NewMode();
            for (int i = 0; EnumDisplaySettings(null, i, ref dm); i++) {
                if (dm.dmPelsWidth == cur.dmPelsWidth && dm.dmPelsHeight == cur.dmPelsHeight && dm.dmBitsPerPel == cur.dmBitsPerPel && dm.dmDisplayFrequency > max) max = dm.dmDisplayFrequency;
                dm = NewMode();
            }
            return max;
        }
        // 0 = done (DISP_CHANGE_SUCCESSFUL); saved for the next start too
        public static int SetHz(int hz) {
            DEVMODE dm = NewMode();
            if (!EnumDisplaySettings(null, -1, ref dm)) return -1;
            dm.dmDisplayFrequency = hz;
            dm.dmFields = 0x400000; // DM_DISPLAYFREQUENCY
            return ChangeDisplaySettingsEx(null, ref dm, IntPtr.Zero, 1, IntPtr.Zero); // CDS_UPDATEREGISTRY
        }

        [StructLayout(LayoutKind.Sequential, Pack = 4)]
        struct TOKEN_PRIVILEGES { public int Count; public long Luid; public int Attributes; }
        [DllImport("advapi32.dll", SetLastError = true)] static extern bool OpenProcessToken(IntPtr process, int access, out IntPtr token);
        [DllImport("advapi32.dll", SetLastError = true, CharSet = CharSet.Unicode)] static extern bool LookupPrivilegeValue(string system, string name, out long luid);
        [DllImport("advapi32.dll", SetLastError = true)] static extern bool AdjustTokenPrivileges(IntPtr token, bool disableAll, ref TOKEN_PRIVILEGES state, int length, IntPtr previous, IntPtr returnLength);
        [DllImport("kernel32.dll")] static extern IntPtr GetCurrentProcess();
        [DllImport("kernel32.dll")] static extern bool CloseHandle(IntPtr handle);
        [DllImport("ntdll.dll")] static extern int NtSetSystemInformation(int infoClass, ref int info, int length);
        // Empties the standby list (file cache Windows keeps in RAM), like RAMMap "Empty Standby List".
        // Needs administrator rights. Returns the NTSTATUS, 0 = done.
        public static int PurgeStandbyList() {
            IntPtr token;
            if (!OpenProcessToken(GetCurrentProcess(), 0x28, out token)) return -1; // TOKEN_ADJUST_PRIVILEGES | TOKEN_QUERY
            try {
                TOKEN_PRIVILEGES tp = new TOKEN_PRIVILEGES();
                tp.Count = 1; tp.Attributes = 2; // SE_PRIVILEGE_ENABLED
                if (!LookupPrivilegeValue(null, "SeProfileSingleProcessPrivilege", out tp.Luid)) return -2;
                if (!AdjustTokenPrivileges(token, false, ref tp, 0, IntPtr.Zero, IntPtr.Zero)) return -3;
            } finally { CloseHandle(token); }
            int command = 4; // MemoryPurgeStandbyList
            return NtSetSystemInformation(80, ref command, 4); // SystemMemoryListInformation
        }
    }
}
'@

