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

# Pictures are decoded once per size. Small sizes of the wallpapers come from AkatiCenter\thumbs (480 px wide JPEGs
# made by tools/make-assets.py), so the Appearance page does not decode ten full-size wallpapers when the app starts.
# (Not in the Wallpapers folder: the Windows slideshow shows every picture under it.)
$script:images = @{}
function Get-Image([string]$path, [int]$decodeWidth = 0) {
    $key = "$path|$decodeWidth"
    if ($script:images.ContainsKey($key)) { return $script:images[$key] }
    if ($decodeWidth -gt 0 -and $decodeWidth -le 480 -and (Split-Path $path) -eq $wallpapers) {
        $thumb = Join-Path (Join-Path $appDir 'thumbs') ([IO.Path]::GetFileNameWithoutExtension($path) + '.jpg')
        if (Test-Path -LiteralPath $thumb) { $path = $thumb }
    }
    if (!(Test-Path -LiteralPath $path)) { return $null }
    $img = New-Object System.Windows.Media.Imaging.BitmapImage
    $img.BeginInit()
    $img.CacheOption = 'OnLoad'
    if ($decodeWidth -gt 0) { $img.DecodePixelWidth = $decodeWidth }
    $img.UriSource = New-Object System.Uri $path
    $img.EndInit()
    $img.Freeze()
    $script:images[$key] = $img
    return $img
}

# C# helpers (Windows API) are compiled once and kept in the cache folder next to this script, instead of every
# start (each compile takes about half a second). The folder is under the Windows folder, where only administrators
# can write, so nobody else can swap the DLL this elevated app loads. The file name holds a hash of the source, so a
# new version compiles again. When the folder cannot be written, the code is compiled in memory as before.
$codeCache = Join-Path $appDir 'cache'
function Import-Code([string]$name, [string]$source) {
    $sha = [Security.Cryptography.SHA256]::Create()
    $hash = -join @($sha.ComputeHash([Text.Encoding]::UTF8.GetBytes($source))[0..7] | ForEach-Object { $_.ToString('x2') })
    $dll = Join-Path $codeCache "$name-$hash.dll"
    # Not in screenshot mode: CI runs from the source folder, which the build packs into the playbook
    if (!$Screenshot -and !(Test-Path -LiteralPath $dll)) {
        try {
            if (!(Test-Path -LiteralPath $codeCache)) { New-Item -ItemType Directory -Path $codeCache -Force | Out-Null }
            Get-ChildItem -LiteralPath $codeCache -Filter "$name-*.dll" -ErrorAction SilentlyContinue | Remove-Item -Force -ErrorAction SilentlyContinue
            Add-Type -TypeDefinition $source -OutputAssembly $dll -OutputType Library -ErrorAction Stop
        } catch { }
    }
    if (!$Screenshot -and (Test-Path -LiteralPath $dll)) { try { Add-Type -Path $dll -ErrorAction Stop; return } catch { } }
    Add-Type -TypeDefinition $source
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
               MutedBrush = '#98989D'; Good = '#5FD38D'; CardBorderHover = '#4C4C50'; MicaRoot = '#D01C1C1E'; MicaSidebar = '#90232325' }
    light = @{ Text = '#1D1D1F'; Text2 = '#1D1D1F'; Text3 = '#3C3C43'; RootBg = '#F5F5F7'; SidebarBg = '#E9E9EE'; CardBg = '#FFFFFF'; CardBorder = '#DEDEE3'
               Line = '#E1E1E6'; Fill = '#EDEDF1'; FillHover = '#E0E0E5'; Field = '#E2E2E7'; Popup = '#FFFFFF'; Handle = '#B8B8BE'; SegmentOn = '#FFFFFF'
               MutedBrush = '#6E6E73'; Good = '#1F9D57'; CardBorderHover = '#C8C8CF'; MicaRoot = '#D0F5F5F7'; MicaSidebar = '#90E9E9EE' }
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

# Numbers on the sidebar: app updates on Gaming apps, Akati Doctor findings on Health (hidden at 0 and in the narrow sidebar)
$script:navBadges = @{ Gaming = 0; Health = 0 }
function Update-NavBadges {
    foreach ($page in @($script:navBadges.Keys)) {
        $panel = $ui["Nav$page"].Content
        if ($panel.Children.Count -lt 3) {
            $badge = New-Object System.Windows.Controls.Border
            $badge.MinWidth = 18; $badge.Height = 18; $badge.CornerRadius = 9; $badge.Padding = '5,0'; $badge.Margin = '8,0,0,0'; $badge.VerticalAlignment = 'Center'
            $badge.SetResourceReference([System.Windows.Controls.Border]::BackgroundProperty, 'Accent')
            $num = New-Object System.Windows.Controls.TextBlock
            $num.FontSize = 11; $num.FontWeight = 'SemiBold'; $num.Foreground = [System.Windows.Media.Brushes]::White; $num.HorizontalAlignment = 'Center'; $num.VerticalAlignment = 'Center'
            $badge.Child = $num
            [void]$panel.Children.Add($badge)
        }
        $n = [int]$script:navBadges[$page]
        $b = $panel.Children[2]
        $b.Child.Text = if ($n -gt 9) { '9+' } else { [string]$n }
        $b.Visibility = if ($n -gt 0 -and !$script:compact) { 'Visible' } else { 'Collapsed' }
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
. (Join-Path $appDir 'AkatiCenter.irq.ps1')
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
# Numbers count up from 0 when a page opens (Akati Score, usage): ease-out over about 0.7 s.
# Code that updates the same text waits while it counts (Test-Counting).
$script:countUps = @{}
function Start-CountUp($box, [double]$to, [scriptblock]$format, [int]$ms = 700) {
    if (!$box) { return }
    $old = $script:countUps[$box.Name]
    if ($old) { $old.Stop(); $script:countUps.Remove($box.Name) }
    if ($Screenshot) { $box.Text = & $format $to; return }
    $t = New-Object System.Windows.Threading.DispatcherTimer
    $t.Interval = [TimeSpan]::FromMilliseconds(16)
    $t.Tag = @{ Box = $box; To = $to; Format = $format; Start = Get-Date; Ms = $ms }
    $t.Add_Tick({
        $s = $this.Tag
        $p = [Math]::Min(1, ((Get-Date) - $s.Start).TotalMilliseconds / $s.Ms)
        $s.Box.Text = & $s.Format ($s.To * (1 - [Math]::Pow(1 - $p, 3)))
        if ($p -ge 1) { $this.Stop(); $script:countUps.Remove($s.Box.Name) }
    })
    $script:countUps[$box.Name] = $t
    $box.Text = & $format 0
    $t.Start()
}
function Test-Counting($box) { $script:countUps.ContainsKey($box.Name) }
$percentText = { param($v) '{0}%' -f [int][Math]::Round($v) }
$numberText = { param($v) [string][int][Math]::Round($v) }

function Show-Page([string]$name) {
    $script:page = $name
    if ($name -eq 'tweaks') { Initialize-Tweaks }
    if ($name -eq 'gaming') { Initialize-Apps }
    if ($name -eq 'appearance') { Initialize-Appearance }
    if ($name -eq 'boost' -and !$script:startupShown) { $script:startupShown = $true; Show-StartupItems; Start-BgTasks }
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
    if ($name -eq 'dashboard') {
        Update-Week
        Start-CountUp $ui.CpuValue $stats.Cpu $percentText; Start-CountUp $ui.RamValue $stats.Ram $percentText
        if ($stats.Gpu -ge 0) { Start-CountUp $ui.GpuValue $stats.Gpu $percentText }
    }
    if ($name -eq 'health') {
        if ($ui.ScoreValue.Text -match '^\d+$') { Start-CountUp $ui.ScoreValue ([int]$ui.ScoreValue.Text) $numberText 900 }
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
    Initialize-Tweaks; Initialize-Apps
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
    & $add (T 'keys.title') ((Get-Both 'keys.title') + ' keyboard hotkeys') (T 'spot.action') ([char]0xE765) { param($d) Show-Keys } $null
    & $add (T 'irq.title') ((Get-Both 'irq.title') + ' msi affinity interrupt irq') (T 'spot.setting') ([char]0xE964) { param($d)
        if ($ui.IrqPanel.Visibility -ne 'Visible') { $ui.IrqShow.RaiseEvent((New-Object System.Windows.RoutedEventArgs ([System.Windows.Controls.Primitives.ButtonBase]::ClickEvent))) }
        Show-Element 'tweaks' $ui.IrqShow.Parent.Parent } $null
    & $add (T 'games.scan') (Get-Both 'games.scan') (T 'spot.action') ([char]0xE721) { param($d) $ui.NavBoost.IsChecked = $true; $ui.GameScanButton.RaiseEvent((New-Object System.Windows.RoutedEventArgs ([System.Windows.Controls.Primitives.ButtonBase]::ClickEvent))) } $null
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
    Update-NavBadges
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
    # The history needs the switches, which are made when first needed: only for the Health page on screen
    if ($script:page -eq 'health') { Show-History }
    Update-WuState; Update-TempText; Update-Fivem
    Update-Week; Show-ScoreChart
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
foreach ($g in 'Valorant', 'Fivem', 'Cs2', 'Fortnite', 'Other') { $ui["MainGame$g"].Add_Checked({ Save-Setting MainGame $this.Name.Substring(8).ToLowerInvariant() }) }
$ui.WelcomeDone.Add_Click({
    Close-Welcome
    $main = [string](Get-RegValue $settingsKey 'MainGame')
    if ($main -and $main -ne 'other') { Set-MainGame $main }
    if (!(Get-RegValue $settingsKey 'TourDone')) { Start-Tour }
})

# Keyboard shortcuts (the ? key, or Ctrl+K > Keyboard shortcuts)
$keyList = @(
    @('Ctrl + K', 'keys.search'), @('Ctrl + 1 ... 8', 'keys.pages'), @('Ctrl + Tab', 'keys.next'), @('Ctrl + F', 'keys.find'),
    @('Ctrl +  /  Ctrl -  /  Ctrl 0', 'keys.zoom'), @('F1', 'keys.tour'), @('Esc', 'keys.esc'), @('?', 'keys.keys'),
    @('Ctrl + Alt + B', 'keys.boost'), @('Ctrl + Alt + R', 'keys.ram')
)
function Show-Keys {
    $ui.KeysList.Children.Clear()
    foreach ($k in $keyList) {
        $row = New-Object System.Windows.Controls.DockPanel; $row.Margin = '0,0,0,8'
        $chip = New-Object System.Windows.Controls.Border
        $chip.CornerRadius = 6; $chip.Padding = '8,3'; $chip.MinWidth = 190; $chip.Margin = '0,0,14,0'
        $chip.SetResourceReference([System.Windows.Controls.Border]::BackgroundProperty, 'Fill')
        $kt = New-Text $k[0] 13 'SemiBold'; $kt.FontFamily = 'Consolas'; $chip.Child = $kt
        [System.Windows.Controls.DockPanel]::SetDock($chip, 'Left')
        $d = New-Text (T $k[1]) 13; $d.VerticalAlignment = 'Center'
        [void]$row.Children.Add($chip); [void]$row.Children.Add($d)
        [void]$ui.KeysList.Children.Add($row)
    }
    $ui.Keys.Visibility = 'Visible'
}
$ui.KeysDone.Add_Click({ $ui.Keys.Visibility = 'Collapsed' })
$ui.KeysDim.Add_MouseLeftButtonDown({ $ui.Keys.Visibility = 'Collapsed' })

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
    # ?: the keyboard shortcuts (not while typing in a text box)
    if ($key -eq 'OemQuestion' -and [System.Windows.Input.Keyboard]::FocusedElement -isnot [System.Windows.Controls.TextBox] -and $ui.Welcome.Visibility -ne 'Visible') {
        Show-Keys; $e.Handled = $true; return
    }
    if ($key -eq 'Escape') {
        if ($ui.Keys.Visibility -eq 'Visible') { $ui.Keys.Visibility = 'Collapsed'; $e.Handled = $true }
        elseif ($ui.Tour.Visibility -eq 'Visible') { Stop-Tour; $e.Handled = $true }
        elseif ($ui.Welcome.Visibility -eq 'Visible') { Close-Welcome; $e.Handled = $true }
        elseif ($ui.WhatsNew.Visibility -eq 'Visible') { $ui.WhatsNew.Visibility = 'Collapsed'; Save-Setting LastVersion $version; $e.Handled = $true }
        elseif ($ui.SystemSearch.Text) { $ui.SystemSearch.Text = ''; $e.Handled = $true }
        return
    }
    if (!$ctrl -or $ui.Welcome.Visibility -eq 'Visible') { return }
    if ($key -eq 'K') { Open-Spotlight; $e.Handled = $true; return }
    # Ctrl + / Ctrl - / Ctrl 0: text size
    if ($key -in 'OemPlus', 'Add', 'OemMinus', 'Subtract', 'D0', 'NumPad0') {
        $i = [array]::IndexOf($zoomSteps, $script:zoom)
        $z = if ($key -in 'D0', 'NumPad0') { 100 } elseif ($key -in 'OemPlus', 'Add') { $zoomSteps[[Math]::Min($i + 1, $zoomSteps.Count - 1)] } else { $zoomSteps[[Math]::Max($i - 1, 0)] }
        $ui["Zoom$z"].IsChecked = $true
        $e.Handled = $true; return
    }
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
Update-Week
Show-ScoreChart
Set-Status (T 'ready')
# Started from the desktop menu: open that page (and start the ping test)
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
        # App updates, for the number on Gaming apps (once; the page does it too when opened first)
        if (!$script:appsChecked) { $script:appsChecked = $true; Start-AppUpdateCheck $true }
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
# Windows 10: the desktop shows blurred through the window (the blur of the Windows 10 Start menu and taskbar).
# Only when "Transparency effects" is on in Windows. The blur fills the window shape, so the window gets a rounded
# shape (window region) that matches the rounded border; without it the corners turn square. If Windows refuses
# the blur, the window keeps its solid background.
elseif (!$Screenshot -and (Get-RegValue 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize' 'EnableTransparency') -ne 0) {
    try {
        Import-Code 'Blur' @'
using System;
using System.Runtime.InteropServices;
namespace AkatiOS {
    public static class Blur {
        [StructLayout(LayoutKind.Sequential)] struct AccentPolicy { public int State, Flags, Color, Animation; }
        [StructLayout(LayoutKind.Sequential)] struct CompositionData { public int Attribute; public IntPtr Data; public int Size; }
        [DllImport("user32.dll")] static extern int SetWindowCompositionAttribute(IntPtr hwnd, ref CompositionData data);
        // ACCENT_ENABLE_BLURBEHIND (3) through WCA_ACCENT_POLICY (19); true when Windows took it
        public static bool Enable(IntPtr hwnd) {
            AccentPolicy accent = new AccentPolicy(); accent.State = 3;
            int size = Marshal.SizeOf(accent);
            IntPtr ptr = Marshal.AllocHGlobal(size);
            try {
                Marshal.StructureToPtr(accent, ptr, false);
                CompositionData data = new CompositionData(); data.Attribute = 19; data.Data = ptr; data.Size = size;
                return SetWindowCompositionAttribute(hwnd, ref data) != 0;
            } finally { Marshal.FreeHGlobal(ptr); }
        }
        [DllImport("gdi32.dll")] static extern IntPtr CreateRoundRectRgn(int x1, int y1, int x2, int y2, int w, int h);
        [DllImport("gdi32.dll")] static extern bool DeleteObject(IntPtr obj);
        [DllImport("user32.dll")] static extern int SetWindowRgn(IntPtr hwnd, IntPtr rgn, bool redraw);
        // Rounded window shape in pixels (diameter 0 = the whole rectangle); Windows owns the region once it is set
        public static bool Round(IntPtr hwnd, int width, int height, int diameter) {
            IntPtr rgn = diameter > 0 ? CreateRoundRectRgn(0, 0, width + 1, height + 1, diameter, diameter) : IntPtr.Zero;
            if (SetWindowRgn(hwnd, rgn, true) != 0) return true;
            if (rgn != IntPtr.Zero) DeleteObject(rgn);
            return false;
        }
    }
}
'@
        # The rounded shape follows the size (full screen: no corners). Square corners when Windows refuses the shape.
        function Set-BlurCorners {
            if (!$script:blurHwnd) { return }
            $src = [System.Windows.PresentationSource]::FromVisual($window)
            $scale = if ($src) { $src.CompositionTarget.TransformToDevice.M11 } else { 1 }
            $w = if ($window.ActualWidth -gt 0) { $window.ActualWidth } else { $window.Width }
            $h = if ($window.ActualHeight -gt 0) { $window.ActualHeight } else { $window.Height }
            $d = if ($script:full) { 0 } else { [int][Math]::Round(2 * $script:corner.TopLeft * $scale) }
            if (![AkatiOS.Blur]::Round($script:blurHwnd, [int][Math]::Round($w * $scale), [int][Math]::Round($h * $scale), $d)) {
                $ui.RootBorder.CornerRadius = New-Object System.Windows.CornerRadius 0
                $ui.Sidebar.CornerRadius = New-Object System.Windows.CornerRadius 0
                $script:corner = $ui.RootBorder.CornerRadius
            }
        }
        $window.Add_SourceInitialized({
            $hwnd = (New-Object System.Windows.Interop.WindowInteropHelper $window).Handle
            if ([AkatiOS.Blur]::Enable($hwnd)) {
                $script:micaHwnd = $hwnd
                $script:blurHwnd = $hwnd
                Set-CenterLook $script:look
                Set-BlurCorners
            }
        })
        $window.Add_SizeChanged({ Set-BlurCorners })
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
$window.Add_ContentRendered({
    Close-Splash; $window.Activate()
    # How long each part took on this PC: %ProgramData%\AkatiOS\AkatiCenter-startup.log (the problem report includes it)
    Add-Mark 'Window shown'
    try {
        $dir = Join-Path $env:ProgramData 'AkatiOS'
        if (!(Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
        Set-Content -Path (Join-Path $dir 'AkatiCenter-startup.log') -Value (@("$(Get-Date -Format s)  Akati OS $version  build $build") + @($script:marks)) -Encoding UTF8
    } catch { }
})
$window.Add_Loaded({
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
    } catch { }
})
$window.Add_Closed({
    Close-Splash
    $stats.Run = $false
    $timer.Stop()
})
[void]$window.ShowDialog()
