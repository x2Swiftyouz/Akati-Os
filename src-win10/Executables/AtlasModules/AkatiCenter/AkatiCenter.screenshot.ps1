<#
.SYNOPSIS
    Akati OS Center: Screenshot mode (CI): every page in both languages to PNG.
    Dot-sourced by AkatiCenter.ps1 (runs in its scope: $ui, $window, T and the other parts).
#>
# ---------------------------------------------------------------------------------------------
# Screenshot mode (CI): render every page in both languages to PNG and exit
# ---------------------------------------------------------------------------------------------
Add-Mark 'Screenshot mode'
if ($Screenshot) {
    Add-Mark 'Ready (before screenshots)'
    Write-Host 'Startup timing:'; $script:marks | ForEach-Object { Write-Host "  $_" }
    New-Item -ItemType Directory -Path $Screenshot -Force | Out-Null
    # Sample week and score history (the CI runner has none)
    Save-Setting WeekStart (Get-WeekStart (Get-Date)); Save-Setting WeekCleanBytes '1932735283'; Save-Setting WeekBoostMinutes '415'; Save-Setting WeekBoosts '6'
    Save-Setting ScoreHistory ([string[]]@(0..13 | ForEach-Object { '{0}={1}' -f (Get-Date).Date.AddDays($_ - 13).ToString('yyyy-MM-dd', [Globalization.CultureInfo]::InvariantCulture), (72 + [int](12 * $_ / 13) + @(0, 2, -1, 1)[$_ % 4]) }))
    Save-Setting LastBoost ('{0}|83|2|4' -f (Get-Date).AddHours(-2).ToString('s', [Globalization.CultureInfo]::InvariantCulture))
    Update-BoostCard
    $stats.Run = $false
    # A minute of sample usage for the lines in the CPU and RAM cards (CI takes one sample only)
    $size = New-Object System.Windows.Size $window.Width, $window.Height
    $window.Content.Measure($size); $window.Content.Arrange((New-Object System.Windows.Rect $size)); $window.Content.UpdateLayout()
    for ($i = 0; $i -lt 39; $i++) {
        Update-Spark 'Cpu' (14 + 9 * [Math]::Sin($i / 3.0) + 5 * [Math]::Sin($i * 1.7))
        Update-Spark 'Ram' (34 + 3 * [Math]::Sin($i / 6.0))
        Update-Spark 'Gpu' (55 + 20 * [Math]::Sin($i / 4.0))
    }
    & $statsSample $stats
    # Sample ping: the CI runner is far from Singapore
    $stats.Ping = 18
    Update-Stats
    $rootEl = $window.Content
    # Sample PC details: these screenshots go on the website and in the README, not the CI runner's name and Windows Server
    $ui.EditionText.Text = 'Windows 11'; $ui.AboutVersion.Text = "$version  ·  Windows 11"
    $ui.PcName.Text = 'GAMING-PC'; $ui.OsLine.Text = 'Windows 11 Pro  ·  25H2'
    $ui.CpuName.Text = 'AMD Ryzen 7 7800X3D 8-Core Processor'; $ui.GpuName.Text = 'NVIDIA GeForce RTX 4070'
    function Save-Shot([string]$file) {
        $size = New-Object System.Windows.Size $window.Width, $window.Height
        $rootEl.Measure($size)
        $rootEl.Arrange((New-Object System.Windows.Rect $size))
        $rootEl.UpdateLayout()
        $bmp = New-Object System.Windows.Media.Imaging.RenderTargetBitmap ([int]$window.Width), ([int]$window.Height), 96, 96, ([System.Windows.Media.PixelFormats]::Pbgra32)
        $bmp.Render($rootEl)
        $enc = New-Object System.Windows.Media.Imaging.PngBitmapEncoder
        $enc.Frames.Add([System.Windows.Media.Imaging.BitmapFrame]::Create($bmp))
        $fs = [IO.File]::Create((Join-Path $Screenshot $file))
        $enc.Save($fs); $fs.Close()
    }
    foreach ($l in 'en', 'th') {
        $script:lang = $l
        Update-Language
        $ui.UpdateHint.Text = (T 'update.latest') -f $version; $ui.UpdateDot.Fill = $window.FindResource('Good')
        foreach ($p in $pages) {
            $ui["Nav$(Get-PageId $p)"].IsChecked = $true
            Show-Page $p
            if ($p -eq 'cleaner') { $ui.CleanTotal.Text = '0 KB' }
            if ($p -eq 'gaming') {
                # Show the progress bar and queue states once
                $apps[2].State = 'install'; Update-AppRow $apps[2]; Set-Ring $apps[2].Ring 45; $apps[2].Sub.Text = (T 'stage.download') + ' 45%'; $apps[2].Sub.Foreground = $window.FindResource('Accent2')
                $apps[3].State = 'queued'; Update-AppRow $apps[3]
            }
            if ($p -eq 'tweaks') { $ui.SystemList.Measure((New-Object System.Windows.Size 800, 10000)) }
            Save-Shot "$p-$l.png"
            if ($p -eq 'gaming') { foreach ($i in 2, 3) { $apps[$i].State = 'idle'; Update-AppRow $apps[$i] } }
            if ($p -eq 'gaming') {
                # The "..." menu on its own (a menu opens in a popup, outside the window)
                try {
                    $menu = New-AppMenu $apps[0]
                    $menu.Measure((New-Object System.Windows.Size ([double]::PositiveInfinity), ([double]::PositiveInfinity)))
                    $menu.Arrange((New-Object System.Windows.Rect $menu.DesiredSize)); $menu.UpdateLayout()
                    $mb = New-Object System.Windows.Media.Imaging.RenderTargetBitmap ([int][Math]::Ceiling($menu.ActualWidth)), ([int][Math]::Ceiling($menu.ActualHeight)), 96, 96, ([System.Windows.Media.PixelFormats]::Pbgra32)
                    $mb.Render($menu)
                    $me = New-Object System.Windows.Media.Imaging.PngBitmapEncoder
                    $me.Frames.Add([System.Windows.Media.Imaging.BitmapFrame]::Create($mb))
                    $mf = [IO.File]::Create((Join-Path $Screenshot "menu-$l.png")); $me.Save($mf); $mf.Close()
                } catch { Write-Host "Menu screenshot failed: $($_.Exception.Message)" }
            }
            if ($p -eq 'appearance' -or $p -eq 'tweaks' -or $p -eq 'boost' -or $p -eq 'gaming' -or $p -eq 'health' -or $p -eq 'dashboard') {
                # The lower part of long pages
                $sv = $ui["Page$(Get-PageId $p)"]
                if ($p -eq 'tweaks') {
                    # The middle of the page: the Network, Display and Memory sections
                    $sv.UpdateLayout(); $sv.ScrollToVerticalOffset(560); $sv.UpdateLayout()
                    Save-Shot "$p-$l-mid.png"
                    # The Services section
                    $top = $tweakLists['services'].TranslatePoint((New-Object System.Windows.Point 0, 0), $sv.Content).Y
                    $sv.ScrollToVerticalOffset([Math]::Max(0, $top - 60)); $sv.UpdateLayout()
                    Save-Shot "$p-$l-services.png"
                }
                if ($p -eq 'appearance') {
                    # The look and text size cards
                    $top = $ui.Zoom100.TranslatePoint((New-Object System.Windows.Point 0, 0), $sv.Content).Y
                    $sv.UpdateLayout(); $sv.ScrollToVerticalOffset([Math]::Max(0, $top - 260)); $sv.UpdateLayout()
                    Save-Shot "$p-$l-mid.png"
                }
                if ($p -eq 'boost') {
                    # My games with one game (CI runner: Notepad) and the FiveM card
                    if (!(Test-Path $gamesKey)) { New-Item -Path $gamesKey -Force | Out-Null }
                    Set-ItemProperty -Path $gamesKey -Name (Join-Path $windir 'notepad.exe') -Value 1 -Type DWord -Force
                    Set-GameProfile (Join-Path $windir 'notepad.exe') 'boost' 1; Set-GameProfile (Join-Path $windir 'notepad.exe') 'hvci' 0
                    Show-Games
                    $top = $ui.GamesList.TranslatePoint((New-Object System.Windows.Point 0, 0), $sv.Content).Y
                    $sv.UpdateLayout(); $sv.ScrollToVerticalOffset([Math]::Max(0, $top - 80)); $sv.UpdateLayout()
                    Save-Shot "$p-$l-mid.png"
                }
                $sv.UpdateLayout(); $sv.ScrollToVerticalOffset(100000); $sv.UpdateLayout()
                Save-Shot "$p-$l-2.png"
                $sv.ScrollToVerticalOffset(0)
            }
        }
        $ui.NavDashboard.IsChecked = $true
        $ui.Welcome.Visibility = 'Visible'
        Save-Shot "welcome-$l.png"
        $ui.Welcome.Visibility = 'Collapsed'
        Show-WhatsNew; Save-Shot "whatsnew-$l.png"; $ui.WhatsNew.Visibility = 'Collapsed'
        Open-Spotlight; $ui.SpotlightBox.Text = 'dns'; Save-Shot "spotlight-$l.png"; Close-Spotlight
        # Narrow sidebar, restart bar, the message after a change and one "What it changes" box open
        Set-Compact $true; $ui.RestartBar.Visibility = 'Visible'; Show-Toast ((T 'toast.on') -f (T 'tw.timer')) @{}
        $link = @($tweaks | Where-Object { $_.Key -eq 'timer' } | ForEach-Object { $_.Sub.Parent.Children } | Where-Object { $_.Tag -eq 't:tw.details' })[0]
        $box = if ($link) { Switch-Details $link }
        $ui.NavTweaks.IsChecked = $true; Save-Shot "extras-$l.png"
        Start-Tour; $script:tourStep = 1; Show-TourStep; Save-Shot "tour-$l.png"; $ui.Tour.Visibility = 'Collapsed'
        Set-Compact $false; $ui.RestartBar.Visibility = 'Collapsed'; $ui.Toast.Visibility = 'Collapsed'; if ($box) { $box.Visibility = 'Collapsed' }
    }
    # Vietnamese and Indonesian: a few pages, to see that the texts fit
    foreach ($l in 'vi', 'id') {
        $script:lang = $l
        Update-Language
        $ui.UpdateHint.Text = (T 'update.latest') -f $version; $ui.UpdateDot.Fill = $window.FindResource('Good')
        foreach ($p in 'dashboard', 'boost', 'health', 'tweaks') { $ui["Nav$(Get-PageId $p)"].IsChecked = $true; Show-Page $p; Save-Shot "$p-$l.png" }
        $ui.Welcome.Visibility = 'Visible'; Save-Shot "welcome-$l.png"; $ui.Welcome.Visibility = 'Collapsed'
    }
    $script:lang = 'en'; Update-Language
    # Accent colors recolor the window
    Set-CenterAccent $accents[1]; $ui.NavGaming.IsChecked = $true; Save-Shot 'accent-blue.png'
    Set-CenterAccent $accents[6]; $ui.NavBoost.IsChecked = $true; Save-Shot 'accent-orange.png'
    Set-CenterAccent $accents[0]
    # Sidebar numbers, the keyboard shortcuts, Choose apps, Find my games and the share picture
    $script:navBadges['Gaming'] = 2; $script:navBadges['Health'] = 1; Update-NavBadges
    $ui.NavBoost.IsChecked = $true
    Show-BoostApps; $ui.BoostAppsPanel.Visibility = 'Visible'
    Show-GameScan @(@{ Name = 'Counter-Strike 2'; Path = 'D:\SteamLibrary\steamapps\common\Counter-Strike Global Offensive\game\bin\win64\cs2.exe'; Store = 'Steam' }
                    @{ Name = 'Fortnite'; Path = 'C:\Program Files\Epic Games\Fortnite\FortniteGame\Binaries\Win64\FortniteClient-Win64-Shipping.exe'; Store = 'Epic Games' })
    $sv = $ui.PageBoost; $sv.UpdateLayout(); $sv.ScrollToVerticalOffset(0); $sv.UpdateLayout(); Save-Shot 'boost-en-choose.png'
    $top = $ui.GameScanPanel.TranslatePoint((New-Object System.Windows.Point 0, 0), $sv.Content).Y
    $sv.ScrollToVerticalOffset([Math]::Max(0, $top - 140)); $sv.UpdateLayout(); Save-Shot 'boost-en-scan.png'
    $sv.ScrollToVerticalOffset(0); $ui.BoostAppsPanel.Visibility = 'Collapsed'; $ui.GameScanPanel.Visibility = 'Collapsed'
    Show-Keys; Save-Shot 'keys-en.png'; $ui.Keys.Visibility = 'Collapsed'
    # CPU balance and process rules with sample settings
    Save-Setting ProcessRules ([string[]]@('chrome|BelowNormal|', 'obs64||12'))
    Save-Setting BalanceLog ([string[]]@("$((Get-Date).AddMinutes(-5).ToString('s'))|chrome|41", "$((Get-Date).AddMinutes(-42).ToString('s'))|OneDrive|33"))
    $ui.BalanceOn.IsChecked = $true; Show-Rules; Show-BalLog
    $top = $ui.BalanceOn.TranslatePoint((New-Object System.Windows.Point 0, 0), $sv.Content).Y
    $sv.ScrollToVerticalOffset([Math]::Max(0, $top - 40)); $sv.UpdateLayout(); Save-Shot 'boost-en-balance.png'; $sv.ScrollToVerticalOffset(0)
    try { [void](Save-ScoreCard (Join-Path $Screenshot 'share-card.png')) } catch { Write-Host "Share picture failed: $($_.Exception.Message)" }
    $script:navBadges['Gaming'] = 0; $script:navBadges['Health'] = 0; Update-NavBadges
    # Tweaks > Interrupts: the devices of the CI runner and a sample benchmark
    $ui.NavTweaks.IsChecked = $true
    $ui.IrqShow.RaiseEvent((New-Object System.Windows.RoutedEventArgs ([System.Windows.Controls.Primitives.ButtonBase]::ClickEvent)))
    $n = [Math]::Min(8, [Environment]::ProcessorCount)
    Show-IrqCores ([double[]]@(@(0..($n - 1) | ForEach-Object { 100000 - 900 * (($_ * 5) % 7) }) + @(0..($n - 1) | ForEach-Object { 40 + 10 * ($_ % 3) }) +
                               @(0..($n - 1) | ForEach-Object { if ($_ -eq 0) { 2.4 } else { 0.2 + 0.15 * (($_ * 5) % 7) } })))
    $sv = $ui.PageTweaks; $sv.UpdateLayout()
    $top = $ui.IrqPanel.TranslatePoint((New-Object System.Windows.Point 0, 0), $sv.Content).Y
    $sv.ScrollToVerticalOffset([Math]::Max(0, $top - 150)); $sv.UpdateLayout(); Save-Shot 'tweaks-en-irq.png'
    $sv.ScrollToVerticalOffset($top + 260); $sv.UpdateLayout(); Save-Shot 'tweaks-en-irq2.png'
    $sv.ScrollToVerticalOffset(0)
    # The light look
    Set-CenterLook 'light'
    foreach ($p in 'dashboard', 'gaming', 'tweaks') { $ui["Nav$(Get-PageId $p)"].IsChecked = $true; Save-Shot "light-$p.png" }
    Set-CenterLook 'dark'
    # The Akati OS cursors must load in Windows
    foreach ($c in Get-ChildItem -LiteralPath $akatiCursors -File) {
        if ([AkatiOS.Native]::LoadCursorFromFile($c.FullName) -eq [IntPtr]::Zero) { Write-Output "Windows cannot load the cursor $($c.Name)"; $script:exitNow = 1; return }
        Write-Output "Cursor OK: $($c.Name)"
    }
    Write-Output "Screenshots saved to $Screenshot"
    $script:exitNow = 0; return
}

