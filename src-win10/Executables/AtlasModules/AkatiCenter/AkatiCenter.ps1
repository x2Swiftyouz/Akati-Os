<#
.SYNOPSIS
    Akati OS Center: dashboard, gaming apps, game boost, tweaks, cleaner, themes, system settings and updates.
.DESCRIPTION
    A WPF window written in PowerShell, so every line can be read. It runs on Windows PowerShell 5.1
    (Windows 10 and 11) and needs administrator rights for installs and tweaks.
    -Screenshot <folder> renders every page to PNG and exits (used by CI). -Root points to a source
    "Executables" folder instead of the installed %windir% layout.
    -Page <name> opens that page (desktop menu), -Ping also starts the ping test on the Game boost page.
    -Boost toggle|on|off starts or stops Game boost without a window (desktop menu and tray, through the elevated task).
#>
param (
    [string]$Screenshot,
    [string]$Root,
    [string]$Page,
    [switch]$Ping,
    [ValidateSet('', 'toggle', 'on', 'off')][string]$Boost
)

$ErrorActionPreference = 'Stop'
# Startup timing: printed in screenshot mode (CI), to see which part makes the window slow to open
$script:clock = [Diagnostics.Stopwatch]::StartNew(); $script:marks = New-Object System.Collections.ArrayList
function Add-Mark([string]$name) { [void]$script:marks.Add(('{0,6} ms  {1}' -f $script:clock.ElapsedMilliseconds, $name)) }
Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase

# ---------------------------------------------------------------------------------------------
# Paths
# ---------------------------------------------------------------------------------------------
$windir = [Environment]::GetFolderPath('Windows')
if ($Root) {
    $Root = (Resolve-Path -LiteralPath $Root).Path
    $modules   = Join-Path $Root 'AtlasModules'
    $desktop   = Join-Path $Root 'AtlasDesktop'
    $themesDir = Join-Path $Root 'Themes'
} else {
    $modules   = Join-Path $windir 'AtlasModules'
    $desktop   = Join-Path $windir 'AtlasDesktop'
    $themesDir = Join-Path $windir 'Resources\Themes'
}
$appDir     = $PSScriptRoot
$wallpapers = Join-Path $modules 'Wallpapers'
$gameApps   = Join-Path $modules 'Scripts\GAMEAPPS.ps1'
$repo       = 'x2Swiftyouz/Akati-Os'

# ---------------------------------------------------------------------------------------------
# Run as administrator (installs and tweaks change system settings)
# ---------------------------------------------------------------------------------------------
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (!$Screenshot -and !$isAdmin) {
    try {
        $forward = if ($Page -match '^\w+$') { " -Page $Page" + $(if ($Ping) { ' -Ping' } else { '' }) } else { '' }
        Start-Process powershell.exe -Verb RunAs -WindowStyle Hidden -ArgumentList "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$PSCommandPath`"$forward"
    } catch { }
    exit
}

# ---------------------------------------------------------------------------------------------
# Splash: a small window on its own thread, shown at once while the main window is built
# ---------------------------------------------------------------------------------------------
$splash = [hashtable]::Synchronized(@{})
if (!$Screenshot -and !$Boost) {
    $splashRs = [runspacefactory]::CreateRunspace(); $splashRs.ApartmentState = 'STA'; $splashRs.ThreadOptions = 'ReuseThread'; $splashRs.Open()
    $splashPs = [PowerShell]::Create(); $splashPs.Runspace = $splashRs
    [void]$splashPs.AddScript({
        param($state, $logo)
        Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase
        $w = New-Object System.Windows.Window
        $w.WindowStyle = 'None'; $w.AllowsTransparency = $true; $w.Background = 'Transparent'; $w.ResizeMode = 'NoResize'
        $w.Width = 300; $w.Height = 190; $w.WindowStartupLocation = 'CenterScreen'; $w.ShowInTaskbar = $false; $w.Topmost = $true
        $card = New-Object System.Windows.Controls.Border
        $card.Background = '#1C1C1E'; $card.BorderBrush = '#38383A'; $card.BorderThickness = '1'; $card.CornerRadius = 16; $card.Padding = '24'
        $stack = New-Object System.Windows.Controls.StackPanel; $stack.VerticalAlignment = 'Center'
        try {
            $img = New-Object System.Windows.Controls.Image; $img.Width = 56; $img.Height = 56; $img.Margin = '0,0,0,12'
            $img.Source = New-Object System.Windows.Media.Imaging.BitmapImage (New-Object Uri $logo)
            [void]$stack.Children.Add($img)
        } catch { }
        $title = New-Object System.Windows.Controls.TextBlock
        $title.Text = 'Akati OS Center'; $title.Foreground = 'White'; $title.FontSize = 16; $title.FontWeight = 'SemiBold'; $title.HorizontalAlignment = 'Center'
        $bar = New-Object System.Windows.Controls.ProgressBar
        $bar.IsIndeterminate = $true; $bar.Height = 3; $bar.Margin = '30,16,30,0'; $bar.Foreground = '#A35CF0'; $bar.Background = '#38383A'; $bar.BorderThickness = '0'
        [void]$stack.Children.Add($title); [void]$stack.Children.Add($bar)
        $card.Child = $stack; $w.Content = $card
        $state.Dispatcher = [System.Windows.Threading.Dispatcher]::CurrentDispatcher
        $w.Show()
        [System.Windows.Threading.Dispatcher]::Run()
    }).AddArgument($splash).AddArgument((Join-Path $PSScriptRoot 'logo.png'))
    $splashHandle = $splashPs.BeginInvoke()
}
function Close-Splash { if ($splash.Dispatcher) { try { $splash.Dispatcher.InvokeShutdown() } catch { }; $splash.Dispatcher = $null } }
# An error while the window is built must not leave the splash on screen
trap { Close-Splash; break }

# ---------------------------------------------------------------------------------------------
# Strings (English and Thai)
# ---------------------------------------------------------------------------------------------
# Texts in English and Thai (a separate file, so this one stays readable)
. (Join-Path $appDir 'AkatiCenter.strings.ps1')
# Small functions without windows (tested by tools/test-logic.ps1)
. (Join-Path $appDir 'AkatiCenter.logic.ps1')

$settingsKey = 'HKCU:\Software\AkatiOS\Center'
$lang = (Get-ItemProperty -Path $settingsKey -Name Language -ErrorAction SilentlyContinue).Language
# The languages of Akati OS Center, in their own names; the first start picks the Windows language when it is one of them
$languages = [ordered]@{ en = 'English'; th = 'ภาษาไทย'; vi = 'Tiếng Việt'; id = 'Bahasa Indonesia' }
$cultures = @{ en = 'en-US'; th = 'th-TH'; vi = 'vi-VN'; id = 'id-ID' }
if ($lang -notin $languages.Keys) { $two = (Get-Culture).TwoLetterISOLanguageName; $lang = if ($languages.Contains($two)) { $two } else { 'en' } }
function T([string]$key) {
    $value = $strings[$lang][$key]
    if (!$value) { $value = $strings['en'][$key] }
    if (!$value) { $value = $key }
    return $value
}
# Dates and numbers in the window language (th-TH uses the Buddhist year, like Thai Windows)
function Get-LangCulture { [Globalization.CultureInfo]::GetCultureInfo($cultures[$lang]) }

# ---------------------------------------------------------------------------------------------
# Window
# ---------------------------------------------------------------------------------------------
Add-Mark 'Window'
[xml]$xaml = Get-Content -LiteralPath (Join-Path $appDir 'AkatiCenter.xaml') -Raw -Encoding UTF8
$window = [Windows.Markup.XamlReader]::Load((New-Object System.Xml.XmlNodeReader $xaml))
$ui = @{}
$xaml.SelectNodes('//*[@*[local-name()="Name"]]') | ForEach-Object {
    $name = $_.GetAttribute('Name', 'http://schemas.microsoft.com/winfx/2006/xaml')
    if ($name) { $ui[$name] = $window.FindName($name) }
}

function Get-Image([string]$path, [int]$decodeWidth = 0) {
    if (!(Test-Path -LiteralPath $path)) { return $null }
    $img = New-Object System.Windows.Media.Imaging.BitmapImage
    $img.BeginInit()
    $img.CacheOption = 'OnLoad'
    if ($decodeWidth -gt 0) { $img.DecodePixelWidth = $decodeWidth }
    $img.UriSource = New-Object System.Uri $path
    $img.EndInit()
    $img.Freeze()
    return $img
}

$logoPath = Join-Path $appDir 'logo.png'
$ui.LogoImage.Source = Get-Image $logoPath 128
$ui.AboutLogo.Source = Get-Image $logoPath 256
$ui.BrandImage.Source = Get-Image (Join-Path $wallpapers 'akatios-lockscreen.png') 600
$ui.HeroImage.Source = Get-Image (Join-Path $wallpapers 'akatios-lockscreen.png') 1200
try { $window.Icon = Get-Image $logoPath 64 } catch { }

# Apply strings to every element with Tag="t:<key>"
function Set-Language {
    $stack = New-Object System.Collections.Stack
    $stack.Push($window)
    while ($stack.Count) {
        $node = $stack.Pop()
        if ($node -is [System.Windows.FrameworkElement] -and $node.Tag -is [string] -and $node.Tag.StartsWith('t:')) {
            $text = T $node.Tag.Substring(2)
            if ($node -is [System.Windows.Controls.TextBlock]) { $node.Text = $text }
            elseif ($node -is [System.Windows.Controls.ContentControl]) { $node.Content = $text }
        }
        if ($node -is [System.Windows.DependencyObject]) {
            foreach ($child in [System.Windows.LogicalTreeHelper]::GetChildren($node)) {
                if ($child -is [System.Windows.DependencyObject]) { $stack.Push($child) }
            }
        }
    }
    $ui.LangLabel.Text = T 'lang'
    $ui.PageTitle.Text = T "nav.$script:page"
}

function Set-Status([string]$text, [bool]$busy = $false) {
    $script:statusBusy = $busy
    $ui.StatusText.Text = $text
    $ui.StatusDot.Fill = if ($busy) { $window.FindResource('Accent2') } else { $window.FindResource('Good') }
}

# ---------------------------------------------------------------------------------------------
# Look: dark or light. The XAML uses these brushes as DynamicResource; their colors are changed in place,
# so elements that hold a brush from code change too. Mica: see-through versions of the two backgrounds.
# ---------------------------------------------------------------------------------------------
$looks = @{
    dark  = @{ Text = '#F5F5F7'; Text2 = '#EBEBF0'; Text3 = '#D1D1D6'; RootBg = '#1C1C1E'; SidebarBg = '#232325'; CardBg = '#2A2A2C'; CardBorder = '#38383A'
               Line = '#38383A'; Fill = '#3A3A3C'; FillHover = '#48484A'; Field = '#2E2E30'; Popup = '#2C2C2E'; Handle = '#5A5A5E'; SegmentOn = '#4A4A4D'
               MutedBrush = '#98989D'; Good = '#5FD38D'; MicaRoot = '#D01C1C1E'; MicaSidebar = '#90232325' }
    light = @{ Text = '#1D1D1F'; Text2 = '#1D1D1F'; Text3 = '#3C3C43'; RootBg = '#F5F5F7'; SidebarBg = '#E9E9EE'; CardBg = '#FFFFFF'; CardBorder = '#DEDEE3'
               Line = '#E1E1E6'; Fill = '#EDEDF1'; FillHover = '#E0E0E5'; Field = '#E2E2E7'; Popup = '#FFFFFF'; Handle = '#B8B8BE'; SegmentOn = '#FFFFFF'
               MutedBrush = '#6E6E73'; Good = '#1F9D57'; MicaRoot = '#D0F5F5F7'; MicaSidebar = '#90E9E9EE' }
}
function Set-ThemeBrush([string]$key, [string]$hex) {
    $color = [System.Windows.Media.ColorConverter]::ConvertFromString($hex)
    $brush = $window.Resources[$key]
    if ($brush -is [System.Windows.Media.SolidColorBrush] -and !$brush.IsFrozen) { $brush.Color = $color }
    else { $window.Resources[$key] = [System.Windows.Media.SolidColorBrush]::new($color) }
}
# Auto: the Windows app mode (Settings > Personalization > Colors)
function Get-LookName {
    $choice = Get-RegValue $settingsKey 'CenterLook'
    if ($choice -in 'dark', 'light') { return $choice }
    # By time: light from 7:00 to 19:00
    if ($choice -eq 'time') { $h = (Get-Date).Hour; if ($h -ge 7 -and $h -lt 19) { return 'light' } else { return 'dark' } }
    if ((Get-RegValue 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize' 'AppsUseLightTheme') -eq 1) { 'light' } else { 'dark' }
}
function Set-CenterLook([string]$name) {
    $script:look = $name
    $palette = $looks[$name]
    foreach ($key in $palette.Keys) { if ($key -notlike 'Mica*') { Set-ThemeBrush $key $palette[$key] } }
    if ($script:micaHwnd) {
        Set-ThemeBrush 'RootBg' $palette.MicaRoot; Set-ThemeBrush 'SidebarBg' $palette.MicaSidebar
        $dark = if ($name -eq 'dark') { 1 } else { 0 }
        [void][AkatiOS.Native]::DwmSetWindowAttribute($script:micaHwnd, 20, [ref]$dark, 4)
    }
}
function Get-RegValue($path, $name) { (Get-ItemProperty -Path $path -Name $name -ErrorAction SilentlyContinue).$name }
# Screenshot mode: dark, whatever the CI machine uses (the light look has its own screenshots)
Set-CenterLook $(if ($Screenshot) { 'dark' } else { Get-LookName })

# ---------------------------------------------------------------------------------------------
# Background work: runs a script block in another runspace, then calls back on the UI thread
# ---------------------------------------------------------------------------------------------
Add-Mark 'Background work'
$script:jobs = New-Object System.Collections.ArrayList
# $done is called as: & $done <output of $work> <$context>
function Start-Work([scriptblock]$work, [object[]]$arguments, [scriptblock]$done, $context) {
    $ps = [PowerShell]::Create()
    [void]$ps.AddScript($work.ToString())
    foreach ($a in $arguments) { [void]$ps.AddArgument($a) }
    [void]$script:jobs.Add(@{ PS = $ps; Handle = $ps.BeginInvoke(); Done = $done; Context = $context })
}
function Get-LastOutput($result) {
    if (!$result -or $result.Count -eq 0) { return $null }
    $last = $result[$result.Count - 1]
    # Unwrap strings and hashtables; a PSCustomObject keeps its properties only on the wrapper (JSON from Invoke-RestMethod)
    if ($last -is [psobject] -and $last.psobject.BaseObject -isnot [System.Management.Automation.PSCustomObject]) { $last = $last.psobject.BaseObject }
    return $last
}
function Receive-Work {
    foreach ($job in @($script:jobs)) {
        if ($job.Handle.IsCompleted) {
            $result = $null
            try { $result = $job.PS.EndInvoke($job.Handle) } catch { $result = $null }
            $job.PS.Dispose()
            $script:jobs.Remove($job)
            if ($job.Done) {
                try { & $job.Done $result $job.Context } catch { Set-Status $_.Exception.Message }
            }
        }
    }
}

# ---------------------------------------------------------------------------------------------
# The pages, one file each (dot-sourced: they share this script's variables and functions)
# ---------------------------------------------------------------------------------------------
. (Join-Path $appDir 'AkatiCenter.dashboard.ps1')
. (Join-Path $appDir 'AkatiCenter.gaming.ps1')
. (Join-Path $appDir 'AkatiCenter.boost.ps1')
if ($null -ne $script:exitNow) { exit $script:exitNow }
. (Join-Path $appDir 'AkatiCenter.tweaks.ps1')
. (Join-Path $appDir 'AkatiCenter.games.ps1')
. (Join-Path $appDir 'AkatiCenter.cleaner.ps1')
. (Join-Path $appDir 'AkatiCenter.appearance.ps1')
. (Join-Path $appDir 'AkatiCenter.system.ps1')
. (Join-Path $appDir 'AkatiCenter.health.ps1')

# ---------------------------------------------------------------------------------------------
# Navigation, title bar, language
# ---------------------------------------------------------------------------------------------
Add-Mark 'Navigation, title bar, language'
$pages = 'dashboard', 'gaming', 'boost', 'tweaks', 'health', 'cleaner', 'appearance', 'about'
$script:page = 'dashboard'
function Get-PageId([string]$p) { [Globalization.CultureInfo]::InvariantCulture.TextInfo.ToTitleCase($p) }
function Show-Page([string]$name) {
    $script:page = $name
    # Saved at once, so the next start opens it even when the app did not close normally
    if (!$Screenshot) { Save-Setting LastPage $name }
    foreach ($p in $pages) {
        $el = $ui["Page$(Get-PageId $p)"]
        if ($p -ne $name) { $el.Visibility = 'Collapsed'; continue }
        $el.Visibility = 'Visible'
        # Fade and slide in
        if (!$Screenshot) {
            $ease = New-Object System.Windows.Media.Animation.CubicEase
            $ease.EasingMode = 'EaseOut'
            $fade = New-Object System.Windows.Media.Animation.DoubleAnimation 0, 1, (New-Object System.Windows.Duration ([TimeSpan]::FromMilliseconds(220)))
            $fade.EasingFunction = $ease
            $move = New-Object System.Windows.Media.Animation.DoubleAnimation 14, 0, (New-Object System.Windows.Duration ([TimeSpan]::FromMilliseconds(260)))
            $move.EasingFunction = $ease
            $shift = New-Object System.Windows.Media.TranslateTransform
            $el.RenderTransform = $shift
            $el.BeginAnimation([System.Windows.UIElement]::OpacityProperty, $fade)
            $shift.BeginAnimation([System.Windows.Media.TranslateTransform]::YProperty, $move)
        }
    }
    $ui.PageTitle.Text = T "nav.$name"
    # A finished message belongs to the page it came from; work that still runs keeps its message
    if (!$script:statusBusy) { Set-Status (T 'ready') }
    if ($name -eq 'cleaner' -and $ui.CleanTotal.Text -eq '-') { Start-Scan }
    if ($name -eq 'boost') { Update-BoostCard }
    if ($name -eq 'health') {
        if (!$script:healthLoaded) { $script:healthLoaded = $true; Start-Health }
        Show-History; Update-WuState; Update-TempText
    }
    # Gaming apps: look for app updates once, the first time the page opens
    if ($name -eq 'gaming' -and !$script:appsChecked -and !$Screenshot) { $script:appsChecked = $true; Start-AppUpdateCheck $true }
}
foreach ($p in $pages) {
    $ui["Nav$(Get-PageId $p)"].Add_Checked({ Show-Page $this.Name.Substring(3).ToLowerInvariant() })
}

# Window buttons like macOS (top left): close, minimize, full screen. Full screen fills the work area
# (the screen without the taskbar, wherever the taskbar is). Double-click the top bar to switch too.
$script:full = $false
$script:corner = $ui.RootBorder.CornerRadius
function Switch-FullScreen {
    if ($script:full) {
        $b = $script:normalBounds
        $window.Left = $b.X; $window.Top = $b.Y; $window.Width = $b.Width; $window.Height = $b.Height
        $script:full = $false
    } else {
        $script:normalBounds = New-Object System.Windows.Rect $window.Left, $window.Top, $window.Width, $window.Height
        $a = [System.Windows.SystemParameters]::WorkArea
        $window.Left = $a.Left; $window.Top = $a.Top; $window.Width = $a.Width; $window.Height = $a.Height
        $script:full = $true
    }
    $full = $script:full
    $ui.MaxButton.Content = if ($full) { [string][char]0xE73F } else { [string][char]0xE740 }
    $ui.MaxButton.ToolTip = if ($full) { 'Exit full screen' } else { 'Full screen' }
    # Square corners and no border while the window fills the screen
    $square = $full -or $script:corner.TopLeft -eq 0
    $ui.RootBorder.CornerRadius = if ($full) { New-Object System.Windows.CornerRadius 0 } else { $script:corner }
    $ui.RootBorder.BorderThickness = New-Object System.Windows.Thickness $(if ($square) { 0 } else { 1 })
    $ui.Sidebar.CornerRadius = if ($square) { New-Object System.Windows.CornerRadius 0 } else { New-Object System.Windows.CornerRadius 14, 0, 0, 14 }
}
$moveWindow = {
    param($sender, $e)
    if ($e.ClickCount -eq 2) { Switch-FullScreen; return }
    if (!$script:full) { $window.DragMove() }
}
$ui.TitleBar.Add_MouseLeftButtonDown($moveWindow)
$ui.Lights.Add_MouseLeftButtonDown($moveWindow)
$ui.Brand.Add_MouseLeftButtonDown($moveWindow)
$ui.MinButton.Add_Click({ $window.WindowState = 'Minimized' })
$ui.MaxButton.Add_Click({ Switch-FullScreen })
$ui.CloseButton.Add_Click({ $window.Close() })

# Small screens (for example a 1024 x 768 virtual machine): the window must fit on the screen
$area = [System.Windows.SystemParameters]::WorkArea
if ($window.Width -gt $area.Width - 16) { $window.Width = [Math]::Max(640, $area.Width - 16); $window.MinWidth = [Math]::Min($window.MinWidth, $window.Width) }
if ($window.Height -gt $area.Height - 16) { $window.Height = [Math]::Max(480, $area.Height - 16); $window.MinHeight = [Math]::Min($window.MinHeight, $window.Height) }

# ---------------------------------------------------------------------------------------------
# What's new: once after an update (LastVersion is saved when it is closed; a new install skips it)
# ---------------------------------------------------------------------------------------------
function Show-WhatsNew {
    $ui.WhatsNewTitle.Text = (T 'new.title') -f $version
    $ui.WhatsNewList.Children.Clear()
    foreach ($i in 1..6) {
        $row = New-Object System.Windows.Controls.DockPanel; $row.Margin = '0,0,0,10'
        $dot = New-Object System.Windows.Controls.Border
        $dot.Width = 8; $dot.Height = 8; $dot.CornerRadius = 4; $dot.Margin = '2,7,12,0'; $dot.VerticalAlignment = 'Top'
        $dot.SetResourceReference([System.Windows.Controls.Border]::BackgroundProperty, 'Accent')
        [System.Windows.Controls.DockPanel]::SetDock($dot, 'Left')
        [void]$row.Children.Add($dot); [void]$row.Children.Add((New-Text (T "new.$i") 14))
        [void]$ui.WhatsNewList.Children.Add($row)
    }
    $ui.WhatsNew.Visibility = 'Visible'
}
$ui.WhatsNewDone.Add_Click({ $ui.WhatsNew.Visibility = 'Collapsed'; Save-Setting LastVersion $version })

# ---------------------------------------------------------------------------------------------
# Spotlight (Ctrl+K): one search for pages, settings, apps, games and actions
# ---------------------------------------------------------------------------------------------
# Both languages are searched, so "dns" or "ล้าง" work whatever the window language is
function Get-Both([string]$key) { ($languages.Keys | ForEach-Object { $strings[$_][$key] }) -join ' ' }
function Get-StandbyBytes {
    try { $m = Get-CimInstance Win32_PerfRawData_PerfOS_Memory -ErrorAction Stop; [double]$m.StandbyCacheNormalPriorityBytes + [double]$m.StandbyCacheReserveBytes + [double]$m.StandbyCacheCoreBytes } catch { 0 }
}
function Invoke-FreeRam {
    $before = Get-StandbyBytes
    $result = [AkatiOS.Perf]::PurgeStandbyList()
    if ($result -eq 0) { Set-Status ((T 'status.freed') -f (Format-Size ([Math]::Max(0, $before - (Get-StandbyBytes))))) } else { Set-Status "NTSTATUS $result" }
}
# Opens a page and scrolls a row into view, with a short highlight
function Show-Element([string]$page, $element) {
    $ui["Nav$(Get-PageId $page)"].IsChecked = $true
    $script:spotTarget = $element
    [void]$window.Dispatcher.BeginInvoke([action]{
        $el = $script:spotTarget
        if (!$el) { return }
        try {
            $el.BringIntoView()
            $brush = $window.FindResource('Accent').Clone(); $brush.Opacity = 0.35
            $el.Background = $brush
            $fade = New-Object System.Windows.Media.Animation.DoubleAnimation 0.35, 0, (New-Object System.Windows.Duration ([TimeSpan]::FromMilliseconds(1400)))
            $brush.BeginAnimation([System.Windows.Media.Brush]::OpacityProperty, $fade)
        } catch { Set-Status $_.Exception.Message }
    }, 'Background')
}
function Get-SpotlightItems {
    $items = New-Object System.Collections.ArrayList
    # Name: the title and other names of the item (both languages, keywords); Desc: its description
    $add = { param($text, $search, $sub, $glyph, $action, $data, $desc)
             [void]$items.Add(@{ Id = $(if ($search) { [string]$search } else { [string]$text }); Text = $text; Name = "$text $search".ToLowerInvariant(); Desc = "$desc".ToLowerInvariant(); Sub = $sub; Glyph = [string]$glyph; Action = $action; Data = $data }) }
    foreach ($p in $pages) { & $add (T "nav.$p") (Get-Both "nav.$p") (T 'spot.page') ([char]0xE8A5) { param($d) $ui["Nav$(Get-PageId $d)"].IsChecked = $true } $p }
    foreach ($t in $tweaks) {
        if (!$t.Row) { continue }
        & $add (T "tw.$($t.Key)") (Get-Both "tw.$($t.Key)") (T 'spot.setting') $t.Glyph { param($d) Show-Element 'tweaks' $d } $t.Row (Get-Both "tw.$($t.Key).d")
    }
    & $add (T 'tw.dns') ((Get-Both 'tw.dns') + ' cloudflare google 1.1.1.1 8.8.8.8') (T 'spot.setting') ([char]0xE774) { param($d) Show-Element 'tweaks' $d } $dnsRow.Row
    & $add (T 'tw.refresh') ((Get-Both 'tw.refresh') + ' hz') (T 'spot.setting') ([char]0xE7F8) { param($d) Show-Element 'tweaks' $d } $refreshRow.Row
    foreach ($a in $apps) {
        & $add $a.Name '' (T 'spot.app') ([char]0xE7FC) { param($d) if (Test-App $d) { Open-App $d } else { Show-Element 'gaming' $d.RowParts.Row } } $a (Get-Both "app.desc.$($a.Key)")
    }
    foreach ($g in @(if (Test-Path $gamesKey) { (Get-Item $gamesKey).Property })) {
        & $add ([IO.Path]::GetFileNameWithoutExtension($g)) '' (T 'spot.game') ([char]0xE7FC) { param($d) Start-Process explorer.exe -ArgumentList "`"$d`"" } $g
    }
    foreach ($ci in $cleanItems) { & $add (T "clean.$($ci.Key)") (Get-Both "clean.$($ci.Key)") (T 'nav.cleaner') $ci.Glyph { param($d) $ui.NavCleaner.IsChecked = $true } $null }
    & $add (T 'act.freeram') (Get-Both 'act.freeram') (T 'spot.action') ([char]0xE964) { param($d) Invoke-FreeRam } $null
    & $add (T 'act.flushdns') (Get-Both 'act.flushdns') (T 'spot.action') ([char]0xE774) { param($d) & ipconfig.exe /flushdns *> $null; Set-Status (T 'status.dnsflushed') } $null
    # Windows starts Explorer again by itself (AutoRestartShell), as the user and not as administrator
    & $add (T 'act.explorer') (Get-Both 'act.explorer') (T 'spot.action') ([char]0xE72C) { param($d) Stop-Process -Name explorer -Force -ErrorAction SilentlyContinue } $null
    & $add (T 'act.boost') ((Get-Both 'act.boost') + ' game mode') (T 'spot.action') ([char]0xE945) { param($d) $ui.BoostButton.RaiseEvent((New-Object System.Windows.RoutedEventArgs ([System.Windows.Controls.Primitives.ButtonBase]::ClickEvent))) } $null
    & $add (T 'act.ping') (Get-Both 'act.ping') (T 'spot.action') ([char]0xE768) { param($d) $ui.NavBoost.IsChecked = $true; $script:pingOn = $true; $script:pingNext = [datetime]::MinValue; Set-PingButton } $null
    & $add (T 'act.update') (Get-Both 'act.update') (T 'spot.action') ([char]0xE895) { param($d) $ui.NavAbout.IsChecked = $true; Start-UpdateCheck } $null
    & $add (T 'act.lang') (Get-Both 'act.lang') (T 'spot.action') ([char]0xE774) { param($d) $keys = @($languages.Keys); Set-AppLanguage $keys[([array]::IndexOf($keys, $lang) + 1) % $keys.Count] } $null
    & $add (T 'act.report') (Get-Both 'act.report') (T 'spot.action') ([char]0xE7BA) { param($d) $ui.ReportButton.RaiseEvent((New-Object System.Windows.RoutedEventArgs ([System.Windows.Controls.Primitives.ButtonBase]::ClickEvent))) } $null
    return $items
}
function Update-SpotSelection {
    for ($i = 0; $i -lt $script:spotRows.Count; $i++) {
        $row = $script:spotRows[$i]
        if ($i -eq $script:spotSel) { $row.SetResourceReference([System.Windows.Controls.Border]::BackgroundProperty, 'Accent') }
        else { $row.Background = [System.Windows.Media.Brushes]::Transparent }
    }
}
# A search word matches at the start of a word ("ram" finds "Free up RAM", not "frame"). Thai has no spaces
# between words, so a word with Thai letters matches anywhere.
# A result row; the parts of the title that match the search are bold
function Add-SpotRow($item, [string[]]$words) {
    $row = New-Object System.Windows.Controls.Border
    $row.CornerRadius = 7; $row.Padding = '10,7'; $row.Cursor = 'Hand'; $row.Background = [System.Windows.Media.Brushes]::Transparent
    $dock = New-Object System.Windows.Controls.DockPanel
    $icon = New-Object System.Windows.Controls.Border
    $icon.Width = 26; $icon.Height = 26; $icon.CornerRadius = 6; $icon.SetResourceReference([System.Windows.Controls.Border]::BackgroundProperty, 'Fill'); $icon.Margin = '0,0,12,0'
    $g = New-Text $item.Glyph 13; $g.Style = $window.FindResource('Glyph'); $g.HorizontalAlignment = 'Center'
    $g.SetResourceReference([System.Windows.Controls.TextBlock]::ForegroundProperty, 'Accent2'); $icon.Child = $g
    $sub = New-Text $item.Sub 12; $sub.Opacity = 0.7; $sub.VerticalAlignment = 'Center'
    [System.Windows.Controls.DockPanel]::SetDock($icon, 'Left'); [System.Windows.Controls.DockPanel]::SetDock($sub, 'Right')
    $title = New-Object System.Windows.Controls.TextBlock
    $title.FontSize = 14; $title.VerticalAlignment = 'Center'; $title.TextWrapping = 'NoWrap'; $title.TextTrimming = 'CharacterEllipsis'
    $text = [string]$item.Text; $lower = $text.ToLowerInvariant()
    $marks = New-Object 'bool[]' $text.Length
    foreach ($w in $words) {
        $at = if ($w -match '[฀-๿]') { $lower.IndexOf($w) } else { $m = [regex]::Match($lower, '(^|[^\p{L}\p{N}])' + [regex]::Escape($w)); if ($m.Success) { $m.Index + $m.Groups[1].Length } else { -1 } }
        if ($at -ge 0) { for ($i = $at; $i -lt [Math]::Min($text.Length, $at + $w.Length); $i++) { $marks[$i] = $true } }
    }
    $i = 0
    while ($i -lt $text.Length) {
        $j = $i; while ($j -lt $text.Length -and $marks[$j] -eq $marks[$i]) { $j++ }
        $run = New-Object System.Windows.Documents.Run ($text.Substring($i, $j - $i))
        if ($marks[$i]) { $run.FontWeight = 'Bold'; $run.SetResourceReference([System.Windows.Documents.TextElement]::ForegroundProperty, 'Accent2') }
        [void]$title.Inlines.Add($run)
        $i = $j
    }
    [void]$dock.Children.Add($icon); [void]$dock.Children.Add($sub); [void]$dock.Children.Add($title)
    $row.Child = $dock
    $row.Tag = $script:spotRows.Count
    $row.Add_MouseEnter({ $script:spotSel = $this.Tag; Update-SpotSelection })
    $row.Add_MouseLeftButtonUp({ Invoke-SpotlightItem $this.Tag })
    [void]$ui.SpotlightResults.Children.Add($row)
    $script:spotRows += $row; $script:spotList += $item
}
function Update-Spotlight {
    $text = $ui.SpotlightBox.Text.Trim()
    $q = $text.ToLowerInvariant()
    $ui.SpotlightHint.Visibility = if ($text) { 'Collapsed' } else { 'Visible' }
    $ui.SpotlightResults.Children.Clear()
    $script:spotRows = @(); $script:spotList = @()
    $words = @(if ($q) { $q -split '\s+' })
    $groups = [ordered]@{}
    if (!$q) {
        # Nothing typed: the items opened last from the search
        $recent = @(foreach ($id in @(Get-RegValue $settingsKey 'SpotRecent')) { $script:spotItems | Where-Object { $_.Id -eq $id } | Select-Object -First 1 })
        if (!$recent) { $ui.SpotlightLine.Visibility = 'Collapsed'; return }
        $groups[(T 'spot.recent')] = $recent
    } else {
        # Order: the title starts with the search, then every word in the names, then words found in the description
        $ranked = for ($i = 0; $i -lt $script:spotItems.Count; $i++) {
            $item = $script:spotItems[$i]
            if (!($words | Where-Object { !(Test-SpotWord $item.Name $_) })) { $rank = if ($item.Text.ToLowerInvariant().StartsWith($q)) { 0 } else { 1 } }
            elseif (!($words | Where-Object { !(Test-SpotWord "$($item.Name) $($item.Desc)" $_) })) { $rank = 2 }
            else { continue }
            [pscustomobject]@{ Item = $item; Rank = $rank; Index = $i }
        }
        $found = @($ranked | Sort-Object Rank, Index | Select-Object -First 8 | ForEach-Object { $_.Item })
        $found += @{ Text = (T 'spot.atlas') -f $text; Sub = (T 'tweaks.system'); Glyph = [string][char]0xE721; Data = $text
                     Action = { param($d) $ui.NavTweaks.IsChecked = $true; $ui.SystemSearch.Text = $d } }
        # Grouped by kind (Page, Setting, App...), the groups in the order of their best result
        foreach ($item in $found) {
            if (!$groups.Contains($item.Sub)) { $groups[$item.Sub] = New-Object System.Collections.ArrayList }
            [void]$groups[$item.Sub].Add($item)
        }
    }
    foreach ($key in $groups.Keys) {
        $head = New-Text $key 11 'SemiBold'; $head.Opacity = 0.6; $head.Margin = '10,6,0,2'
        [void]$ui.SpotlightResults.Children.Add($head)
        foreach ($item in $groups[$key]) { Add-SpotRow $item $words }
    }
    $ui.SpotlightLine.Visibility = 'Visible'
    $script:spotSel = 0
    Update-SpotSelection
}
function Open-Spotlight {
    $script:spotItems = Get-SpotlightItems
    $ui.SpotlightBox.Text = ''
    Update-Spotlight
    $ui.Spotlight.Visibility = 'Visible'
    [void]$ui.SpotlightBox.Focus()
}
function Close-Spotlight { $ui.Spotlight.Visibility = 'Collapsed' }
function Invoke-SpotlightItem([int]$index) {
    if ($index -lt 0 -or $index -ge $script:spotList.Count) { return }
    $item = $script:spotList[$index]
    if ($item.Id) {
        $ids = @(@($item.Id) + @(@(Get-RegValue $settingsKey 'SpotRecent') | Where-Object { $_ -and $_ -ne $item.Id }) | Select-Object -First 5)
        Save-Setting SpotRecent ([string[]]$ids)
    }
    Close-Spotlight
    try { & $item.Action $item.Data } catch { Set-Status $_.Exception.Message }
}
$ui.SpotlightButton.Add_Click({ Open-Spotlight })
$ui.SpotlightDim.Add_MouseLeftButtonDown({ Close-Spotlight })
$ui.SpotlightBox.Add_TextChanged({ Update-Spotlight })
$ui.SpotlightBox.Add_PreviewKeyDown({
    param($s, $e)
    switch ($e.Key) {
        'Down'   { if ($script:spotRows.Count) { $script:spotSel = [Math]::Min($script:spotSel + 1, $script:spotRows.Count - 1); Update-SpotSelection }; $e.Handled = $true }
        'Up'     { $script:spotSel = [Math]::Max($script:spotSel - 1, 0); Update-SpotSelection; $e.Handled = $true }
        'Return' { Invoke-SpotlightItem $script:spotSel; $e.Handled = $true }
        'Escape' { Close-Spotlight; $e.Handled = $true }
    }
})

function Save-Setting([string]$name, $value) {
    try {
        if (!(Test-Path $settingsKey)) { New-Item -Path $settingsKey -Force | Out-Null }
        Set-ItemProperty -Path $settingsKey -Name $name -Value $value -Force
    } catch { }
}
function Set-AppLanguage([string]$l) {
    $script:lang = $l
    Save-Setting Language $l
    Update-Language
}
# Narrow sidebar: icons only, the page names show as tooltips
$navButtons = @($ui.NavDashboard, $ui.NavGaming, $ui.NavBoost, $ui.NavTweaks, $ui.NavHealth, $ui.NavCleaner, $ui.NavAppearance, $ui.NavAbout)
$script:compact = $false
function Set-Compact([bool]$on) {
    $script:compact = $on
    $ui.SideColumn.Width = New-Object System.Windows.GridLength ($(if ($on) { 96 } else { 248 }))
    $vis = if ($on) { 'Collapsed' } else { 'Visible' }
    $ui.Brand.Visibility = $vis; $ui.SpotlightButton.Visibility = $vis; $ui.SideBottom.Visibility = $vis
    foreach ($b in $navButtons) {
        $label = $b.Content.Children[1]
        $label.Visibility = $vis
        $b.ToolTip = if ($on) { $label.Text } else { $null }
    }
    $ui.SidebarToggle.ToolTip = T $(if ($on) { 'side.wide' } else { 'side.narrow' })
}
$ui.SidebarToggle.Add_Click({ Set-Compact (!$script:compact); Save-Setting Compact ([int]$script:compact) })
Set-Compact ((Get-RegValue $settingsKey 'Compact') -eq 1 -and !$Screenshot)
# Language: a menu with every language in its own name
$ui.LangButton.Add_Click({
    $menu = New-Object System.Windows.Controls.ContextMenu
    foreach ($k in $languages.Keys) {
        $item = New-Object System.Windows.Controls.MenuItem
        $item.Header = $languages[$k]; $item.Tag = $k; $item.IsChecked = ($k -eq $lang)
        $item.Add_Click({ Set-AppLanguage $this.Tag })
        [void]$menu.Items.Add($item)
    }
    $menu.PlacementTarget = $this; $menu.Placement = 'Top'; $menu.IsOpen = $true
})
function Update-Language {
    Set-Language
    Show-Disks
    Update-Clock
    Update-Chips
    Update-AntiCheat
    if ($script:doctorResult) { Show-Doctor $script:doctorResult }
    if ($script:healthResult) { Show-HealthInfo $script:healthResult }
    Show-History; Update-WuState; Update-TempText; Update-Fivem
    Set-Compact $script:compact
    if ($stats.Top) { Show-TopApps }
    foreach ($a in $apps) { if ($a.State -ne 'install') { Update-AppRow $a } }
    Update-AppsToolbar
    Update-RefreshRow
    Update-TweakHints
    Show-Games
    Request-MenuUpdate
    if ($ui.WhatsNew.Visibility -eq 'Visible') { Show-WhatsNew }
    if ($ui.Tour.Visibility -eq 'Visible') { Show-TourStep }
    Show-FpsResults
    if ($script:doctorResult) { Update-Score }
    Update-AutoClean
    Update-ThemeCards
    Update-GpuText
    Update-BoostCard
    Set-PingButton
    Show-SystemList
}

# Welcome, the first time Akati OS Center opens
$ui.WelcomeLogo.Source = Get-Image $logoPath 128
function Close-Welcome {
    $ui.Welcome.Visibility = 'Collapsed'
    Save-Setting Welcomed 1
}
$ui.WelcomeEn.Add_Click({ Set-AppLanguage 'en' })
$ui.WelcomeTh.Add_Click({ Set-AppLanguage 'th' })
$ui.WelcomeVi.Add_Click({ Set-AppLanguage 'vi' })
$ui.WelcomeId.Add_Click({ Set-AppLanguage 'id' })
$ui.WelcomeApps.Add_Click({ Close-Welcome; $ui.NavGaming.IsChecked = $true })
$ui.WelcomeLook.Add_Click({ Close-Welcome; $ui.NavAppearance.IsChecked = $true })
$ui.WelcomeDone.Add_Click({ Close-Welcome; if (!(Get-RegValue $settingsKey 'TourDone')) { Start-Tour } })

# Tour: five short steps, each on its page
$tourPages = 'dashboard', 'boost', 'health', 'tweaks', 'dashboard'
$script:tourStep = -1
function Show-TourStep {
    $i = $script:tourStep
    $ui["Nav$(Get-PageId $tourPages[$i])"].IsChecked = $true
    $ui.TourStep.Text = '{0} / {1}' -f ($i + 1), $tourPages.Count
    $ui.TourTitle.Text = T "tour.$($i + 1)"
    $ui.TourText.Text = T "tour.$($i + 1).d"
    $ui.TourNext.Content = T $(if ($i -eq $tourPages.Count - 1) { 'tour.done' } else { 'tour.next' })
}
function Start-Tour { $script:tourStep = 0; $ui.Tour.Visibility = 'Visible'; Show-TourStep }
function Stop-Tour { $ui.Tour.Visibility = 'Collapsed'; $script:tourStep = -1; Save-Setting TourDone 1 }
$ui.TourNext.Add_Click({ if ($script:tourStep -ge $tourPages.Count - 1) { Stop-Tour } else { $script:tourStep++; Show-TourStep } })
$ui.TourSkip.Add_Click({ Stop-Tour })
$ui.TourStart.Add_Click({ Start-Tour })
# The welcome covers the title bar, so the window can be moved from anywhere on it
$ui.Welcome.Add_MouseLeftButtonDown({ $window.DragMove() })
if (!(Get-RegValue $settingsKey 'Welcomed') -and !$Screenshot) { $ui.Welcome.Visibility = 'Visible' }
if (!$Screenshot) {
    if (!(Get-RegValue $settingsKey 'Welcomed')) { Save-Setting LastVersion $version }
    elseif ((Get-RegValue $settingsKey 'LastVersion') -ne $version) { Show-WhatsNew }
}

# Keyboard: Ctrl+1 to Ctrl+8 switch pages, Ctrl+Tab the next page, F1 the tour, Ctrl+F searches the AtlasOS settings in Tweaks, Esc closes the welcome or clears the search
$window.Add_PreviewKeyDown({
    param($sender, $e)
    $ctrl = ([System.Windows.Input.Keyboard]::Modifiers -band [System.Windows.Input.ModifierKeys]::Control) -ne 0
    $key = [string]$e.Key
    if ($key -eq 'F1') { Start-Tour; $e.Handled = $true; return }
    if ($key -eq 'Escape') {
        if ($ui.Tour.Visibility -eq 'Visible') { Stop-Tour; $e.Handled = $true }
        elseif ($ui.Welcome.Visibility -eq 'Visible') { Close-Welcome; $e.Handled = $true }
        elseif ($ui.WhatsNew.Visibility -eq 'Visible') { $ui.WhatsNew.Visibility = 'Collapsed'; Save-Setting LastVersion $version; $e.Handled = $true }
        elseif ($ui.SystemSearch.Text) { $ui.SystemSearch.Text = ''; $e.Handled = $true }
        return
    }
    if (!$ctrl -or $ui.Welcome.Visibility -eq 'Visible') { return }
    if ($key -eq 'K') { Open-Spotlight; $e.Handled = $true; return }
    # Ctrl+Tab / Ctrl+Shift+Tab: next or previous page
    if ($key -eq 'Tab') {
        $shift = ([System.Windows.Input.Keyboard]::Modifiers -band [System.Windows.Input.ModifierKeys]::Shift) -ne 0
        $i = [array]::IndexOf($pages, $script:page) + $(if ($shift) { -1 } else { 1 })
        $ui["Nav$(Get-PageId $pages[($i + $pages.Count) % $pages.Count])"].IsChecked = $true
        $e.Handled = $true; return
    }
    if ($key -eq 'F') {
        $ui.NavTweaks.IsChecked = $true
        [void]$ui.SystemSearch.Focus(); $ui.SystemSearch.SelectAll()
        $e.Handled = $true
    } elseif ($key -match '^(D|NumPad)([1-8])$') {
        $ui["Nav$(Get-PageId $pages[[int]$Matches[2] - 1])"].IsChecked = $true
        $e.Handled = $true
    }
})

# An error in a click or a timer must not close the window: it goes to the status bar and to
# %ProgramData%\AkatiOS\AkatiCenter.log (attach it to a GitHub issue)
$window.Dispatcher.Add_UnhandledException({
    param($sender, $e)
    $e.Handled = $true
    try {
        $dir = Join-Path $env:ProgramData 'AkatiOS'
        if (!(Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
        Add-Content -Path (Join-Path $dir 'AkatiCenter.log') -Value "$(Get-Date -Format s) $($e.Exception.ToString())"
        Set-Status $e.Exception.Message
    } catch { }
})
# Keyboard focus shows an accent ring on buttons, switches, choices and lists (Tab moves between them)
$focusRing = $window.FindResource('FocusRing')
$window.Add_PreviewGotKeyboardFocus({
    param($sender, $e)
    $c = $e.NewFocus
    if (($c -is [System.Windows.Controls.Primitives.ButtonBase] -or $c -is [System.Windows.Controls.ComboBox] -or $c -is [System.Windows.Controls.ListBoxItem]) -and $c.FocusVisualStyle -ne $focusRing) {
        $c.FocusVisualStyle = $focusRing
    }
})
# Sidebar: Tab stops once, the arrow keys move between the pages
$navPanel = $ui.NavDashboard.Parent
[System.Windows.Input.KeyboardNavigation]::SetTabNavigation($navPanel, 'Once')
[System.Windows.Input.KeyboardNavigation]::SetDirectionalNavigation($navPanel, 'Cycle')

Set-Language
Show-Disks
Update-Clock
Update-Chips
Set-Status (T 'ready')
# Started from the desktop menu: open that page (and start the ping test)
# The last page opens when the window has loaded (before that, the sidebar buttons are not one group yet)
$script:startPage = [string](Get-RegValue $settingsKey 'LastPage')
if ($Page -or $Screenshot -or $script:startPage -notin $pages -or !(Get-RegValue $settingsKey 'Welcomed')) { $script:startPage = $null }
# The saved position when it is still on a screen (screens can change)
$wx = Get-RegValue $settingsKey 'WindowX'; $wy = Get-RegValue $settingsKey 'WindowY'
$desk = [System.Windows.SystemParameters]
if (!$Screenshot -and $null -ne $wx -and $null -ne $wy -and $wx -ge $desk::VirtualScreenLeft - 100 -and $wy -ge $desk::VirtualScreenTop -and
    $wx + 200 -le $desk::VirtualScreenLeft + $desk::VirtualScreenWidth -and $wy + 100 -le $desk::VirtualScreenTop + $desk::VirtualScreenHeight) {
    $window.WindowStartupLocation = 'Manual'; $window.Left = $wx; $window.Top = $wy
}
if ($Page -and $pages -contains $Page.ToLowerInvariant()) {
    $ui["Nav$(Get-PageId $Page.ToLowerInvariant())"].IsChecked = $true
    if ($Ping -and $Page -eq 'boost') { $script:pingOn = $true; $script:pingNext = [datetime]::MinValue; Set-PingButton }
}
# The desktop menu is rebuilt each time the window opens (apps, language, task for this user)
Request-MenuUpdate
# Akati Doctor once in the background a few seconds after start, for the Health chip on the Dashboard
if (!$Screenshot) {
    $doctorTimer = New-Object System.Windows.Threading.DispatcherTimer
    $doctorTimer.Interval = [TimeSpan]::FromSeconds(5)
    $doctorTimer.Add_Tick({
        $doctorTimer.Stop()
        if (!$script:doctorResult) { Start-Work $doctorWork @() { param($r) Show-Doctor (Get-LastOutput $r); Update-Chips } $null }
    })
    $doctorTimer.Start()
}

# ---------------------------------------------------------------------------------------------
# Screenshot mode (CI)
# ---------------------------------------------------------------------------------------------
. (Join-Path $appDir 'AkatiCenter.screenshot.ps1')
if ($null -ne $script:exitNow) { exit $script:exitNow }

# ---------------------------------------------------------------------------------------------
# Run
# ---------------------------------------------------------------------------------------------
Add-Mark 'Run'
# Windows 11: Mica, the see-through backdrop of Windows 11 apps, with rounded corners drawn by Windows.
# The window is then a normal (not layered) window and DWM draws the backdrop behind the glass frame.
# If Windows refuses the backdrop, the window keeps its solid background.
if ($build -ge 22000) {
    try {
        $window.AllowsTransparency = $false
        $chrome = New-Object System.Windows.Shell.WindowChrome
        $chrome.CaptionHeight = 0
        $chrome.ResizeBorderThickness = New-Object System.Windows.Thickness 0
        $chrome.GlassFrameThickness = New-Object System.Windows.Thickness -1
        $chrome.CornerRadius = New-Object System.Windows.CornerRadius 0
        $chrome.UseAeroCaptionButtons = $false
        [System.Windows.Shell.WindowChrome]::SetWindowChrome($window, $chrome)
        $ui.RootBorder.CornerRadius = New-Object System.Windows.CornerRadius 0; $ui.RootBorder.BorderThickness = New-Object System.Windows.Thickness 0
        $ui.Sidebar.CornerRadius = New-Object System.Windows.CornerRadius 0
        $script:corner = $ui.RootBorder.CornerRadius
        $window.Add_SourceInitialized({
            $hwnd = (New-Object System.Windows.Interop.WindowInteropHelper $window).Handle
            [System.Windows.Interop.HwndSource]::FromHwnd($hwnd).CompositionTarget.BackgroundColor = [System.Windows.Media.Colors]::Transparent
            $on = if ($script:look -eq 'dark') { 1 } else { 0 }; [void][AkatiOS.Native]::DwmSetWindowAttribute($hwnd, 20, [ref]$on, 4)   # dark mode
            $round = 2; [void][AkatiOS.Native]::DwmSetWindowAttribute($hwnd, 33, [ref]$round, 4)  # round corners
            $mica = 2
            if ([AkatiOS.Native]::DwmSetWindowAttribute($hwnd, 38, [ref]$mica, 4) -eq 0) {
                # See-through backgrounds of the current look (Set-CenterLook)
                $script:micaHwnd = $hwnd
                Set-CenterLook $script:look
            }
        })
    } catch { }
}

$timer = New-Object System.Windows.Threading.DispatcherTimer
$timer.Interval = [TimeSpan]::FromMilliseconds(500)
$script:lookAt = Get-Date
$timer.Add_Tick({
    Update-Stats; Receive-Work; Update-AppProgress; Update-Ping
    if ($script:menuAt -and (Get-Date) -gt $script:menuAt) { Update-DesktopMenu }
    # Auto follows Windows, By time follows the clock
    if (!$Screenshot -and (Get-Date) -gt $script:lookAt) {
        $script:lookAt = (Get-Date).AddSeconds(30)
        # A changed time zone in Windows reaches a running app only after this
        [TimeZoneInfo]::ClearCachedData()
        $n = Get-LookName; if ($n -ne $script:look) { Set-CenterLook $n }
    }
    # The window position, a few seconds after it was moved (also when Windows closes the app at shutdown)
    if ($script:posAt -and (Get-Date) -gt $script:posAt) {
        $script:posAt = $null
        if (!$script:full -and $window.WindowState -eq 'Normal') { Save-Setting WindowX ([int]$window.Left); Save-Setting WindowY ([int]$window.Top) }
    }
})
$window.Add_ContentRendered({ Close-Splash; $window.Activate() })
$window.Add_Loaded({
    if ($script:startPage) { $ui["Nav$(Get-PageId $script:startPage)"].IsChecked = $true }
    # Akati OS checks GitHub once when the window opens (one request, nothing is downloaded)
    Start-UpdateCheck
    # Icon next to the clock: wanted (setup option or Tweaks) but its sign-in task is missing, as after some
    # setups in AME Wizard: register it again
    if (!$Screenshot -and (Get-RegValue 'HKLM:\SOFTWARE\AkatiOS' 'TrayIcon') -eq 1) {
        Start-Work { param($script)
            if (!(Get-ScheduledTask -TaskPath '\AkatiOS\' -TaskName 'Akati OS tray' -ErrorAction SilentlyContinue)) {
                & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $script -Install
                return
            }
            # After an update of Akati OS the icon still runs the old script until the next sign-in: restart it
            $changed = (Get-Item -LiteralPath $script).LastWriteTime
            $old = @(Get-CimInstance Win32_Process -Filter "Name='powershell.exe'" -ErrorAction SilentlyContinue |
                Where-Object { $_.CommandLine -like '*AkatiTray.ps1*' -and $_.CommandLine -notlike '*-Install*' -and $_.CreationDate -lt $changed })
            if ($old.Count) {
                $old | ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }
                Start-ScheduledTask -TaskPath '\AkatiOS\' -TaskName 'Akati OS tray' -ErrorAction SilentlyContinue
            } } @((Join-Path $appDir 'AkatiTray.ps1'))
    }
    $script:statsHandle = $statsPs.BeginInvoke()
    $timer.Start()
})
# Where the window was and the page it showed, for the next start
$window.Add_LocationChanged({ if (!$Screenshot) { $script:posAt = (Get-Date).AddSeconds(2) } })
$window.Add_Closing({
    if ($Screenshot) { return }
    try {
        if (!$script:full -and $window.WindowState -eq 'Normal') { Save-Setting WindowX ([int]$window.Left); Save-Setting WindowY ([int]$window.Top) }
        Save-Setting LastPage $script:page
    } catch { }
})
$window.Add_Closed({
    Close-Splash
    $stats.Run = $false
    $timer.Stop()
})
[void]$window.ShowDialog()
