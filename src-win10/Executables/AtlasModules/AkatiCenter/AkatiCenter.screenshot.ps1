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
            if ($p -eq 'appearance' -or $p -eq 'tweaks' -or $p -eq 'boost' -or $p -eq 'gaming' -or $p -eq 'health') {
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
        $box = @($tweaks | Where-Object { $_.Key -eq 'timer' } | ForEach-Object { $_.Sub.Parent.Children } | Where-Object { $_ -is [System.Windows.Controls.TextBox] })[0]
        if ($box) { $box.Visibility = 'Visible' }
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

