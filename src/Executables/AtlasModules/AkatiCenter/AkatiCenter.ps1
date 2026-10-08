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

$settingsKey = 'HKCU:\Software\AkatiOS\Center'
$lang = (Get-ItemProperty -Path $settingsKey -Name Language -ErrorAction SilentlyContinue).Language
if ($lang -notin 'en', 'th') { $lang = if ((Get-Culture).TwoLetterISOLanguageName -eq 'th') { 'th' } else { 'en' } }
function T([string]$key) {
    $value = $strings[$lang][$key]
    if (!$value) { $value = $strings['en'][$key] }
    if (!$value) { $value = $key }
    return $value
}

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
# Dashboard: system info and live usage
# ---------------------------------------------------------------------------------------------
Add-Mark 'Dashboard'
function Format-Size([double]$bytes) {
    if ($bytes -ge 1GB) { return '{0:N1} GB' -f ($bytes / 1GB) }
    if ($bytes -ge 1MB) { return '{0:N0} MB' -f ($bytes / 1MB) }
    if ($bytes -ge 1KB) { return '{0:N0} KB' -f ($bytes / 1KB) }
    return '0 KB'
}


$akati = Get-ItemProperty -Path 'HKLM:\SOFTWARE\AkatiOS' -ErrorAction SilentlyContinue
$version = if ($akati.Version) { $akati.Version } else { 'v1.4.1' }
$build = [Environment]::OSVersion.Version.Build
$edition = if ($akati.Edition) { $akati.Edition } elseif ($build -ge 22000) { 'Windows 11' } else { 'Windows 10' }
$ui.VersionBig.Text = $version
$ui.EditionText.Text = $edition
$ui.AboutVersion.Text = "$version  ·  $edition"
$ui.FooterVersion.Text = "Akati OS $version"
$ui.PcName.Text = $env:COMPUTERNAME

try {
    $os = Get-CimInstance Win32_OperatingSystem
    $cv = Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion'
    $ui.OsLine.Text = "$($os.Caption)  ·  $($cv.DisplayVersion)  ·  Build $($cv.CurrentBuild).$($cv.UBR)"
    $ui.CpuName.Text = ((Get-CimInstance Win32_Processor | Select-Object -First 1).Name -replace '\s+', ' ').Trim()
    $gpus = Get-CimInstance Win32_VideoController | Where-Object { $_.Name -notmatch 'Basic Display|Remote' }
    $ui.GpuName.Text = if ($gpus) { ($gpus | Select-Object -First 1).Name } else { (Get-CimInstance Win32_VideoController | Select-Object -First 1).Name }
    $ui.RamName.Text = Format-Size ([double]$os.TotalVisibleMemorySize * 1KB)
} catch { }

# Storage: every local drive with a bar
function Show-Disks {
    $ui.DisksPanel.Children.Clear()
    # .NET instead of Win32_LogicalDisk: on some trimmed Windows builds (imOS) WMI returns drives without a size
    foreach ($d in @([IO.DriveInfo]::GetDrives() | Where-Object { $_.DriveType -eq 'Fixed' -and $_.IsReady } | Sort-Object Name)) {
        if (!$d.TotalSize) { continue }
        $used = 100 * ($d.TotalSize - $d.TotalFreeSpace) / $d.TotalSize
        $row = New-Object System.Windows.Controls.StackPanel
        $row.Margin = '0,0,0,10'
        $top = New-Object System.Windows.Controls.Grid
        $name = New-Text ("$($d.Name.TrimEnd('\'))  " + $(if ($d.VolumeLabel) { $d.VolumeLabel } else { T 'disk.local' })) 13 'SemiBold'
        $free = New-Text ((T 'disk.free') -f (Format-Size $d.TotalFreeSpace), (Format-Size $d.TotalSize)) 12
        $free.Foreground = $window.FindResource('MutedBrush'); $free.HorizontalAlignment = 'Right'
        [void]$top.Children.Add($name); [void]$top.Children.Add($free)
        $bar = New-Object System.Windows.Controls.ProgressBar
        $bar.Style = $window.FindResource('Meter'); $bar.Margin = '0,6,0,0'; $bar.Value = $used
        if ($used -ge 90) { $bar.Foreground = '#FF453A' }
        [void]$row.Children.Add($top); [void]$row.Children.Add($bar)
        # Less than 15% free: a shortcut to the Cleaner
        if ($d.TotalFreeSpace / $d.TotalSize -lt 0.15) {
            $clean = New-Object System.Windows.Controls.Button
            $clean.Style = $window.FindResource('Pill'); $clean.Content = T 'disk.clean'; $clean.HorizontalAlignment = 'Left'; $clean.Margin = '0,8,0,0'
            $clean.Add_Click({ $ui.NavCleaner.IsChecked = $true })
            [void]$row.Children.Add($clean)
        }
        [void]$ui.DisksPanel.Children.Add($row)
    }
}

# Usage is read in a background runspace so the window never stutters
$stats = [hashtable]::Synchronized(@{ Cpu = 0; Ram = 0; RamUsed = 0; RamTotal = 0; Gpu = -1; Run = $true; N = 0; Seq = 0
    Down = -1; Up = -1; Ping = -1; Top = $null; TopSeq = 0; Defender = -1; Boot = $null; Self = $PID })
$statsSample = {
    param($stats)
        $n = $stats.N; $stats.N = $n + 1
        try {
            $stats.Cpu = [int](Get-CimInstance Win32_PerfFormattedData_PerfOS_Processor -Filter "Name='_Total'").PercentProcessorTime
            $os = Get-CimInstance Win32_OperatingSystem
            $stats.RamTotal = [double]$os.TotalVisibleMemorySize * 1KB
            $stats.RamUsed = $stats.RamTotal - [double]$os.FreePhysicalMemory * 1KB
            $stats.Ram = [int](100 * $stats.RamUsed / $stats.RamTotal)
        } catch { }
        try {
            $engines = Get-CimInstance Win32_PerfFormattedData_GPUPerformanceCounters_GPUEngine -ErrorAction Stop |
                Where-Object { $_.Name -like '*engtype_3D*' }
            $sum = ($engines | Measure-Object -Property UtilizationPercentage -Sum).Sum
            $stats.Gpu = [int][Math]::Min(100, [double]$sum)
        } catch { $stats.Gpu = -1 }
        # Network speed (all adapters)
        try {
            $nics = @(Get-CimInstance Win32_PerfFormattedData_Tcpip_NetworkInterface -ErrorAction Stop)
            $stats.Down = [double]($nics | Measure-Object -Property BytesReceivedPersec -Sum).Sum
            $stats.Up = [double]($nics | Measure-Object -Property BytesSentPersec -Sum).Sum
        } catch { }
        # The apps using the most CPU, every 3rd sample
        if ($n % 3 -eq 0) {
            try {
                $cores = [Environment]::ProcessorCount
                # Processes with the same name are added together, like the groups in Task Manager
                $groups = Get-CimInstance Win32_PerfFormattedData_PerfProc_Process -ErrorAction Stop |
                    Where-Object { $_.Name -notin '_Total', 'Idle', 'System', 'Memory Compression', 'Registry' -and $_.IDProcess -gt 4 } |
                    Group-Object { $_.Name -replace '#\d+$', '' } | ForEach-Object {
                        @{ Name = $_.Name; Pids = @($_.Group | ForEach-Object { [int]$_.IDProcess })
                           Cpu = [double]($_.Group | Measure-Object -Property PercentProcessorTime -Sum).Sum
                           Ram = [double]($_.Group | Measure-Object -Property WorkingSetPrivate -Sum).Sum }
                    }
                foreach ($g in $groups) { $g.Cpu = [Math]::Round($g.Cpu / $cores, 1) }
                # Two lists: by CPU and by memory (the page shows one of them)
                $byCpu = @($groups | Sort-Object { $_.Cpu }, { $_.Ram } -Descending | Select-Object -First 5)
                $byRam = @($groups | Sort-Object { $_.Ram } -Descending | Select-Object -First 5)
                foreach ($g in @($byCpu + $byRam)) {
                    if (!$g.ContainsKey('Path')) { $g.Path = try { (Get-Process -Id $g.Pids[0] -ErrorAction Stop).Path } catch { $null } }
                }
                $stats.TopRam = $byRam
                $stats.Top = $byCpu
                $stats.TopSeq++
            } catch { }
        }
        # Ping to Singapore every 6th sample (TCP connect, like Game boost)
        if ($n % 6 -eq 0) {
            $ms = -1
            try {
                $ip = [Net.Dns]::GetHostAddresses('dynamodb.ap-southeast-1.amazonaws.com') | Where-Object { $_.AddressFamily -eq 'InterNetwork' } | Select-Object -First 1
                $c = New-Object Net.Sockets.TcpClient; $sw = [Diagnostics.Stopwatch]::StartNew()
                if ($c.ConnectAsync($ip, 443).Wait(2000) -and $c.Connected) { $ms = [int]$sw.Elapsed.TotalMilliseconds }
                $c.Close()
            } catch { }
            $stats.Ping = $ms
        }
        if ($n -eq 0) {
            try { $stats.Boot = (Get-CimInstance Win32_OperatingSystem).LastBootUpTime } catch { }
            try { $stats.Defender = if ((Get-MpComputerStatus -ErrorAction Stop).RealTimeProtectionEnabled) { 1 } else { 0 } } catch { $stats.Defender = 0 }
        }
        $stats.Seq++
}
$statsWork = "param(`$stats)`n`$sample = {$statsSample}`nwhile (`$stats.Run) { & `$sample `$stats; Start-Sleep -Milliseconds 1500 }"
$statsPs = [PowerShell]::Create()
[void]$statsPs.AddScript($statsWork).AddArgument($stats)

# Last 60 seconds of usage (40 samples of 1.5 s), drawn as a line in each card
$script:history = @{ Cpu = New-Object System.Collections.ArrayList; Ram = New-Object System.Collections.ArrayList; Gpu = New-Object System.Collections.ArrayList }
$script:lastSeq = -1; $script:lastTopSeq = -1; $script:chipsAt = [datetime]::MinValue
function Update-Spark([string]$key, [double]$value) {
    $h = $script:history[$key]
    [void]$h.Add([Math]::Max(0, [Math]::Min(100, $value)))
    while ($h.Count -gt 40) { $h.RemoveAt(0) }
    $canvas = $ui["${key}Spark"]
    $w = if ($canvas.ActualWidth -gt 0) { $canvas.ActualWidth } else { 220 }
    $pts = New-Object System.Windows.Media.PointCollection
    for ($i = 0; $i -lt $h.Count; $i++) { $pts.Add((New-Object System.Windows.Point ($w - ($h.Count - 1 - $i) * $w / 39), (36 - 34 * $h[$i] / 100))) }
    $ui["${key}Line"].Points = $pts
}

function Format-Speed([double]$bytesPerSec) {
    if ($bytesPerSec -lt 0) { return '-' }
    $bits = $bytesPerSec * 8
    if ($bits -ge 1e6) { return '{0:N1} Mb/s' -f ($bits / 1e6) }
    return '{0:N0} Kb/s' -f ($bits / 1e3)
}

function Update-Stats {
    $ui.CpuValue.Text = "$($stats.Cpu)%"; $ui.CpuBar.Value = $stats.Cpu
    $ui.RamValue.Text = "$($stats.Ram)%"; $ui.RamBar.Value = $stats.Ram
    if ($stats.RamTotal) { $ui.RamDetail.Text = '{0} / {1}' -f (Format-Size $stats.RamUsed), (Format-Size $stats.RamTotal) }
    if ($stats.Gpu -ge 0) { $ui.GpuValue.Text = "$($stats.Gpu)%"; $ui.GpuBar.Value = $stats.Gpu } else { $ui.GpuValue.Text = '-'; $ui.GpuBar.Value = 0 }
    Set-Level $ui.CpuValue $ui.CpuBar $stats.Cpu
    Set-Level $ui.RamValue $ui.RamBar $stats.Ram
    Set-Level $ui.GpuValue $ui.GpuBar ([Math]::Max(0, $stats.Gpu))
    # No graphics card that Windows reports usage for (virtual machines): CPU and RAM share the row
    $gpuShown = $stats.Gpu -ge 0 -and @($gpuNames).Count -gt 0
    $ui.GpuCard.Visibility = if ($gpuShown) { 'Visible' } else { 'Collapsed' }
    $ui.UsageGrid.Columns = if ($gpuShown) { 3 } else { 2 }
    if ($stats.Seq -ne $script:lastSeq) {
        $script:lastSeq = $stats.Seq
        Update-Spark 'Cpu' $stats.Cpu; Update-Spark 'Ram' $stats.Ram; Update-Spark 'Gpu' ([Math]::Max(0, $stats.Gpu))
        $ui.NetDown.Text = Format-Speed $stats.Down
        $ui.NetUp.Text = Format-Speed $stats.Up
        if ($stats.Ping -ge 0) {
            $ui.NetPing.Text = "$($stats.Ping) ms"
            $ui.NetPing.Foreground = if ($stats.Ping -lt 60) { $window.FindResource('Good') } elseif ($stats.Ping -lt 120) { '#F2C55C' } else { '#F2557A' }
        } else { $ui.NetPing.Text = '-' }
    }
    if ($stats.TopSeq -ne $script:lastTopSeq -and $stats.Top) { $script:lastTopSeq = $stats.TopSeq; Show-TopApps }
    Update-Clock
    if ((Get-Date) -gt $script:chipsAt) { $script:chipsAt = (Get-Date).AddSeconds(10); Update-Chips }
    if ((Get-Date) -gt $script:netInfoAt) { $script:netInfoAt = (Get-Date).AddSeconds(60); Start-NetInfo }
}

# Orange from 85%, red from 95% (the number and the bar)
function Set-Level($text, $bar, [double]$value) {
    $color = if ($value -ge 95) { '#FF453A' } elseif ($value -ge 85) { '#FF9F0A' } else { $null }
    if ($color) { $text.Foreground = $color; $bar.Foreground = $color }
    else { $text.ClearValue([System.Windows.Controls.TextBlock]::ForegroundProperty); $bar.ClearValue([System.Windows.Controls.Control]::ForegroundProperty) }
}

# Greeting and clock like macOS
function Update-Clock {
    $now = Get-Date
    $h = $now.Hour
    $ui.Greeting.Text = T $(if ($h -ge 5 -and $h -lt 12) { 'greet.morning' } elseif ($h -lt 17 -and $h -ge 12) { 'greet.afternoon' } elseif ($h -ge 17 -and $h -lt 21) { 'greet.evening' } else { 'greet.night' })
    $ui.ClockTime.Text = $now.ToString('HH:mm')
    $culture = [Globalization.CultureInfo]::GetCultureInfo($(if ($lang -eq 'th') { 'th-TH' } else { 'en-US' }))
    $ui.ClockDate.Text = $now.ToString('ddd d MMMM', $culture)
}

# Network card: the connected adapter (Wi-Fi or Ethernet), its link speed and IP address, read in the background
function Start-NetInfo {
    Start-Work {
        $a = Get-NetAdapter -Physical -ErrorAction SilentlyContinue | Where-Object Status -eq 'Up' | Sort-Object { $_.NdisPhysicalMedium -ne 9 } | Select-Object -First 1
        if (!$a) { return '' }
        $kind = if ($a.NdisPhysicalMedium -eq 9 -or $a.PhysicalMediaType -match '802\.11') { 'Wi-Fi' } else { 'Ethernet' }
        $ip = (Get-NetIPAddress -InterfaceIndex $a.ifIndex -AddressFamily IPv4 -ErrorAction SilentlyContinue | Select-Object -First 1).IPAddress
        (@($kind, $a.LinkSpeed, $ip) | Where-Object { $_ }) -join ' · '
    } @() { param($r, $c) $ui.NetInfo.Text = [string](Get-LastOutput $r) } $null
}

# Status chips: Game boost, power plan, Defender, time since start
function New-Chip([string]$text, $dot) {
    $b = New-Object System.Windows.Controls.Border
    $b.CornerRadius = 12; $b.SetResourceReference([System.Windows.Controls.Border]::BackgroundProperty, 'Field'); $b.Padding = '10,4'; $b.Margin = '0,0,8,6'
    $sp = New-Object System.Windows.Controls.StackPanel; $sp.Orientation = 'Horizontal'
    $e = New-Object System.Windows.Shapes.Ellipse; $e.Width = 7; $e.Height = 7; $e.Margin = '0,0,7,0'; $e.VerticalAlignment = 'Center'; $e.Fill = $dot
    $t = New-Text $text 12
    [void]$sp.Children.Add($e); [void]$sp.Children.Add($t)
    $b.Child = $sp
    return $b
}
function Update-Chips {
    $ui.StatusChips.Children.Clear()
    $good = $window.FindResource('Good'); $muted = $window.FindResource('MutedBrush')
    $boost = Test-Boost
    [void]$ui.StatusChips.Children.Add((New-Chip (T $(if ($boost) { 'chip.boost.on' } else { 'chip.boost.off' })) $(if ($boost) { $good } else { $muted })))
    $plan = if ([string](powercfg /getactivescheme) -match '\((.+)\)\s*$') { $Matches[1] } else { '-' }
    [void]$ui.StatusChips.Children.Add((New-Chip ((T 'chip.power') -f $plan) $window.FindResource('Accent2')))
    # Screen refresh rate, orange when the screen can do more
    if ($script:screenNow -gt 1) {
        if ($script:screenMax -gt $script:screenNow) { [void]$ui.StatusChips.Children.Add((New-Chip ((T 'chip.hzlow') -f $script:screenNow, $script:screenMax) '#FF9F0A')) }
        else { [void]$ui.StatusChips.Children.Add((New-Chip ((T 'chip.hz') -f $script:screenNow) $muted)) }
    }
    if ($stats.Defender -ge 0) {
        [void]$ui.StatusChips.Children.Add((New-Chip (T $(if ($stats.Defender -eq 1) { 'chip.defender.on' } else { 'chip.defender.off' })) $(if ($stats.Defender -eq 1) { $good } else { '#FF9F0A' })))
    }
    if ($stats.Boot) {
        $up = (Get-Date) - $stats.Boot
        $text = if ($up.TotalDays -ge 1) { (T 'chip.days') -f [int][Math]::Floor($up.TotalDays), $up.Hours } else { (T 'chip.hours') -f $up.Hours, $up.Minutes }
        [void]$ui.StatusChips.Children.Add((New-Chip ((T 'chip.uptime') -f $text) $muted))
    }
}

# The apps using the most CPU, with Quit (not for Windows itself or this window)
$protected = 'csrss', 'wininit', 'winlogon', 'services', 'lsass', 'smss', 'svchost', 'dwm', 'explorer', 'MsMpEng', 'fontdrvhost', 'sihost', 'ctfmon', 'audiodg', 'spoolsv', 'SecurityHealthService', 'NisSrv', 'conhost', 'WmiPrvSE', 'RuntimeBroker', 'taskhostw', 'dllhost', 'StartMenuExperienceHost', 'SearchHost', 'TextInputHost', 'ShellExperienceHost', 'vmtoolsd', 'vm3dservice'
$script:iconCache = @{}
function Show-TopApps {
    $ui.TopList.Children.Clear()
    $list = if ($ui.TopByRam.IsChecked) { $stats.TopRam } else { $stats.Top }
    foreach ($p in @($list)) {
        if (!$p) { continue }
        $right = New-Object System.Windows.Controls.StackPanel; $right.Orientation = 'Horizontal'
        $cpu = New-Text ('{0:N1}%' -f $p.Cpu) 13 'SemiBold'; $cpu.MinWidth = 60; $cpu.TextAlignment = 'Right'; $cpu.VerticalAlignment = 'Center'
        $ram = New-Text (Format-Size $p.Ram) 12; $ram.Foreground = $window.FindResource('MutedBrush'); $ram.MinWidth = 70; $ram.TextAlignment = 'Right'; $ram.VerticalAlignment = 'Center'; $ram.Margin = '0,0,14,0'
        [void]$right.Children.Add($ram); [void]$right.Children.Add($cpu)
        if ($p.Pids -notcontains $stats.Self -and $p.Name -notin $protected) {
            $btn = New-Object System.Windows.Controls.Button
            $btn.Style = $window.FindResource('Secondary'); $btn.Margin = '14,0,0,0'; $btn.Content = T 'top.end'; $btn.Tag = $p
            $btn.Add_Click({
                $t = $this.Tag
                $answer = [System.Windows.MessageBox]::Show(((T 'top.confirm') -f $t.Name), 'Akati OS Center', 'YesNo', 'Question')
                if ($answer -eq 'Yes') {
                    try { Stop-Process -Id $t.Pids -Force -ErrorAction Stop; Set-Status ((T 'status.ended') -f $t.Name) } catch { Set-Status $_.Exception.Message }
                }
            })
            [void]$right.Children.Add($btn)
        } else {
            $spacer = New-Object System.Windows.Controls.Border; $spacer.Width = 76
            [void]$right.Children.Add($spacer)
        }
        # This window runs in powershell.exe: show it by its own name and logo
        $self = $p.Pids -contains $stats.Self
        $label = if ($self) { T 'top.self' } elseif ($p.Pids.Count -gt 1) { '{0} ({1})' -f $p.Name, $p.Pids.Count } else { $p.Name }
        $row = New-Row ([string][char]0xE7C4) $label $null $right $null
        $row.Sub.Visibility = 'Collapsed'
        if ($self) {
            if (!$script:selfIcon) { $script:selfIcon = Get-Image $logoPath 64 }
            Set-RowIcon $row $script:selfIcon
        } elseif ($p.Path) {
            if (!$script:iconCache.ContainsKey($p.Path)) { $script:iconCache[$p.Path] = Get-FileIcon @($p.Path) }
            Set-RowIcon $row $script:iconCache[$p.Path]
        }
        [void]$ui.TopList.Children.Add($row.Row)
    }
    Update-Separators $ui.TopList
}

$ui.TopByCpu.Add_Checked({ Show-TopApps })
$ui.TopByRam.Add_Checked({ Show-TopApps })

# Desktop right-click menu (AkatiMenu.ps1): rebuilt shortly after something it shows changed
$menuScript = Join-Path $appDir 'AkatiMenu.ps1'
$menuKey = 'HKLM:\SOFTWARE\Classes\DesktopBackground\Shell\AkatiOS'
function Request-MenuUpdate { $script:menuAt = (Get-Date).AddSeconds(1) }
function Update-DesktopMenu {
    $script:menuAt = $null
    if ($Screenshot -or !(Test-Path $menuKey) -or !(Test-Path $menuScript)) { return }
    # "My apps": installed gaming apps as "name|command|icon"
    $list = @(foreach ($a in $apps) {
        if (!(Test-App $a)) { continue }
        $exe = Get-AppExe $a
        if (!$exe) { continue }
        # Discord moves to a new app-<version> folder with each update; its own launcher always works
        $command = if ($a.Key -eq 'Discord') { "`"$env:LOCALAPPDATA\Discord\Update.exe`" --processStart Discord.exe" } else { "`"$exe`"" }
        '{0}|{1}|{2}' -f $a.Name, $command, $exe
    })
    $centerKey = 'HKCU:\Software\AkatiOS\Center'
    if (!(Test-Path $centerKey)) { New-Item -Path $centerKey -Force | Out-Null }
    Set-ItemProperty -Path $centerKey -Name MenuApps -Value ([string[]]$list) -Type MultiString
    Start-Process powershell.exe -ArgumentList "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$menuScript`" -Install" -WindowStyle Hidden
}

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

# One gray heading and one grouped list per category
$appGroups = @{}
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
# Installed or uninstalled outside this window: look again when the window comes back to the front
$window.Add_Activated({ foreach ($a in $apps) { if ($a.State -eq 'idle' -and !$a.Uninstalling) { Update-AppRow $a } }; Update-AppsToolbar })

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
$gpus = @(try { Get-CimInstance Win32_VideoController | Where-Object { $_.Name -notmatch 'Basic Display|Remote|Virtual|VMware|Hyper-V|Parsec' } } catch { })
$gpuNames = @($gpus | ForEach-Object { $_.Name })
$gpuVendors = @{ GpuNvidia = 'NVIDIA|GeForce|Quadro|RTX|GTX'; GpuAmd = 'AMD|Radeon|ATI '; GpuIntel = 'Intel|Arc ' }
$script:gpuFound = @()
foreach ($k in $gpuVendors.Keys) {
    if (@($gpuNames | Where-Object { $_ -match $gpuVendors[$k] }).Count) {
        $ui[$k].Style = $window.FindResource('PillAccent'); $script:gpuFound += $k
    }
}
function Update-GpuText {
    $ui.GpuDetected.Text = if ($gpuNames.Count) { (T 'gpu.detected') -f ($gpuNames -join ', ') } else { T 'gpu.none' }
    # Installed driver version and date; older than about 6 months: a hint to look for a newer one
    $culture = [Globalization.CultureInfo]::GetCultureInfo($(if ($lang -eq 'th') { 'th-TH' } else { 'en-US' }))
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
Update-GpuText
$ui.GpuNvidia.Add_Click({ Start-Process 'https://www.nvidia.com/en-us/drivers/' })
$ui.GpuAmd.Add_Click({ Start-Process 'https://www.amd.com/en/support/download/drivers.html' })
$ui.GpuIntel.Add_Click({ Start-Process 'https://www.intel.com/content/www/us/en/download-center/home.html' })

# Screen refresh rate and the standby memory list (Windows API)
Add-Type -TypeDefinition @'
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

# ---------------------------------------------------------------------------------------------
# Game boost: one click before playing, and back again afterwards. What was changed is saved in the
# registry, so Stop still works after Akati OS Center or Windows was restarted.
# ---------------------------------------------------------------------------------------------
Add-Mark 'Game boost'
$boostKey = 'HKCU:\Software\AkatiOS\Center\Boost'
$toastKey = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\PushNotifications'
# Background apps that are safe to close while playing (never game launchers or browsers)
$boostCandidates = 'OneDrive', 'Teams', 'ms-teams', 'Spotify', 'PhoneExperienceHost', 'Dropbox', 'GoogleDriveFS', 'Skype'
$powerSchemes = @(
    '11111111-1111-1111-1111-111111111111'   # Akati OS Power Scheme (Maximum Performance)
    'e9a42b02-d5df-448d-aa00-03f14749eb61'   # Ultimate Performance
    '8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c'   # High performance
)

function Get-ActiveScheme { if ([string](powercfg /getactivescheme) -match '([0-9a-f]{8}-[0-9a-f-]{27})') { $Matches[1] } }
function Test-Boost { [bool](Get-RegValue $boostKey 'Active') }

function Update-BoostCard {
    $running = @(Get-Process -Name $boostCandidates -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Name -Unique)
    $ui.BoostAppsText.Text = if ($running.Count) { (T 'boost.apps') + ' (' + ($running -join ', ') + ')' } else { (T 'boost.apps') + ' (' + (T 'boost.noapps') + ')' }
    if (Test-Boost) {
        $since = Get-RegValue $boostKey 'Since'
        $ui.BoostState.Text = (T 'boost.on') -f $since
        $ui.BoostState.Foreground = $window.FindResource('Good')
        $ui.BoostButton.Content = T 'boost.stop'
        $ui.BoostButton.Style = $window.FindResource('Secondary')
        $ui.BoostIcon.SetResourceReference([System.Windows.Controls.Border]::BackgroundProperty, 'AccentGradient')
        foreach ($c in 'BoostPower', 'BoostApps', 'BoostNotify') { $ui[$c].IsEnabled = $false }
    } else {
        $ui.BoostState.Text = T 'boost.off'
        $ui.BoostState.Foreground = $window.FindResource('MutedBrush')
        $ui.BoostButton.Content = T 'boost.start'
        $ui.BoostButton.Style = $window.FindResource('Primary')
        $ui.BoostIcon.SetResourceReference([System.Windows.Controls.Border]::BackgroundProperty, 'Fill')
        foreach ($c in 'BoostPower', 'BoostApps', 'BoostNotify') { $ui[$c].IsEnabled = $true }
    }
}

# The notification switch is copied as it is (value and registry type), so Stop restores exactly that
$toastSubKey = 'Software\Microsoft\Windows\CurrentVersion\PushNotifications'
function Start-Boost {
    New-Item -Path $boostKey -Force | Out-Null
    # Marked as on first: if a step fails, Stop still undoes the steps that worked
    Set-ItemProperty -Path $boostKey -Name Since -Value (Get-Date -Format 'HH:mm')
    Set-ItemProperty -Path $boostKey -Name Active -Value 1 -Type DWord
    $failed = @()
    if ($ui.BoostPower.IsChecked) {
        try {
            $before = Get-ActiveScheme
            $list = [string](powercfg /list)
            $target = $powerSchemes | Where-Object { $list -match $_ } | Select-Object -First 1
            if ($target -and $before -and $target -ne $before) {
                Set-ItemProperty -Path $boostKey -Name PrevScheme -Value $before
                powercfg /setactive $target | Out-Null
            }
        } catch { $failed += 'power' }
    }
    if ($ui.BoostApps.IsChecked) {
        try {
            $closed = @()
            foreach ($p in Get-Process -Name $boostCandidates -ErrorAction SilentlyContinue) {
                $path = try { $p.Path } catch { $null }
                if ($p.Name -eq 'OneDrive' -and $path) { & $path /shutdown } else { Stop-Process -Id $p.Id -Force -ErrorAction SilentlyContinue }
                if ($path -and $closed -notcontains $path) { $closed += $path }
            }
            if ($closed.Count) { Set-ItemProperty -Path $boostKey -Name Closed -Value ([string[]]$closed) -Type MultiString }
        } catch { $failed += 'apps' }
    }
    if ($ui.BoostNotify.IsChecked) {
        try {
            $key = [Microsoft.Win32.Registry]::CurrentUser.CreateSubKey($toastSubKey)
            $old = $key.GetValue('ToastEnabled', $null, 'DoNotExpandEnvironmentNames')
            if ($null -eq $old) { Set-ItemProperty -Path $boostKey -Name PrevToastKind -Value 'none' }
            else {
                Set-ItemProperty -Path $boostKey -Name PrevToastKind -Value ([string]$key.GetValueKind('ToastEnabled'))
                Set-ItemProperty -Path $boostKey -Name PrevToast -Value ([string]$old)
            }
            $key.SetValue('ToastEnabled', 0, 'DWord')
            $key.Close()
        } catch { $failed += 'notify' }
    }
    if ($ui.BoostMemory.IsChecked) {
        # The standby list fills up again by itself, so there is nothing to undo at Stop
        try { if ([AkatiOS.Perf]::PurgeStandbyList() -ne 0) { $failed += 'memory' } } catch { $failed += 'memory' }
    }
    if ($failed.Count) { throw ((T 'status.boostpartial') -f ($failed -join ', ')) }
}

function Stop-Boost {
    try {
        $prevScheme = Get-RegValue $boostKey 'PrevScheme'
        if ($prevScheme) { powercfg /setactive $prevScheme | Out-Null }
    } catch { }
    try {
        $kind = Get-RegValue $boostKey 'PrevToastKind'
        if ($kind) {
            $key = [Microsoft.Win32.Registry]::CurrentUser.CreateSubKey($toastSubKey)
            if ($kind -eq 'none') { $key.DeleteValue('ToastEnabled', $false) }
            else {
                $text = [string](Get-RegValue $boostKey 'PrevToast')
                # A DWord comes back as the number written out; keep its 32 bits as they were
                $value = switch ($kind) {
                    'DWord' { [BitConverter]::ToInt32([BitConverter]::GetBytes([int64]$text), 0) }
                    'QWord' { [int64]$text }
                    default { $text }
                }
                $key.SetValue('ToastEnabled', $value, $kind)
            }
            $key.Close()
        }
    } catch { }
    # Open the closed apps again. explorer.exe starts them as the signed-in user, not elevated like this window.
    foreach ($path in @(Get-RegValue $boostKey 'Closed')) {
        if ($path -and (Test-Path -LiteralPath $path)) { Start-Process explorer.exe -ArgumentList "`"$path`"" }
    }
    Remove-Item -Path $boostKey -Recurse -Force -ErrorAction SilentlyContinue
}

$ui.BoostButton.Add_Click({
    try {
        if (Test-Boost) { Stop-Boost; Set-Status (T 'status.boostoff') } else { Start-Boost; Set-Status (T 'status.booston') }
    } catch { Set-Status $_.Exception.Message }
    Update-BoostCard
    Request-MenuUpdate
})
# Automatic Game boost: the tray app (AkatiTray.ps1) watches for the games in My games
$ui.BoostAuto.IsChecked = (Get-RegValue 'HKCU:\Software\AkatiOS\Center' 'AutoBoost') -eq 1
$ui.BoostAuto.Add_Click({ Save-Setting AutoBoost $(if ($this.IsChecked) { 1 } else { 0 }) })

# Desktop menu > Game boost: start or stop it without the window; the menu shows the message
if ($Boost) {
    $message = try {
        $active = Test-Boost
        if ($Boost -eq 'off' -or ($Boost -eq 'toggle' -and $active)) { if ($active) { Stop-Boost }; T 'status.boostoff' }
        else { if (!$active) { Start-Boost }; T 'status.booston' }
    } catch { $_.Exception.Message }
    $centerKey = 'HKCU:\Software\AkatiOS\Center'
    if (!(Test-Path $centerKey)) { New-Item -Path $centerKey -Force | Out-Null }
    Set-ItemProperty -Path $centerKey -Name MenuResult -Value $message
    exit
}

# Ping: TCP connect time (more reliable than ICMP, which many servers block) to cloud regions near
# Thailand. Many online games run their Asian servers in these data centers.
$pingTargets = @(
    @{ Key = 'bkk'; Host = 'dynamodb.ap-southeast-7.amazonaws.com' }
    @{ Key = 'sin'; Host = 'dynamodb.ap-southeast-1.amazonaws.com' }
    @{ Key = 'hkg'; Host = 'dynamodb.ap-east-1.amazonaws.com' }
    @{ Key = 'tyo'; Host = 'dynamodb.ap-northeast-1.amazonaws.com' }
)
$pingWork = {
    param($targets)
    $out = @{}
    foreach ($t in $targets) {
        $ms = -1
        try {
            $ip = [Net.Dns]::GetHostAddresses($t.Host) | Where-Object { $_.AddressFamily -eq 'InterNetwork' } | Select-Object -First 1
            $client = New-Object Net.Sockets.TcpClient
            $sw = [Diagnostics.Stopwatch]::StartNew()
            $task = $client.ConnectAsync($ip, 443)
            if ($task.Wait(2000) -and $client.Connected) { $ms = [int]$sw.Elapsed.TotalMilliseconds }
            $client.Close()
        } catch { }
        $out[$t.Key] = $ms
    }
    $out
}
foreach ($t in $pingTargets) {
    $right = New-Object System.Windows.Controls.StackPanel
    $right.Orientation = 'Horizontal'
    $chart = New-Object System.Windows.Controls.Canvas
    $chart.Width = 160; $chart.Height = 30; $chart.Margin = '0,0,18,0'; $chart.ClipToBounds = $true
    $line = New-Object System.Windows.Shapes.Polyline
    $line.SetResourceReference([System.Windows.Shapes.Shape]::StrokeProperty, 'Accent2'); $line.StrokeThickness = 2; $line.StrokeLineJoin = 'Round'
    [void]$chart.Children.Add($line)
    $value = New-Text '-' 18 'Bold'; $value.MinWidth = 80; $value.TextAlignment = 'Right'; $value.VerticalAlignment = 'Center'
    [void]$right.Children.Add($chart); [void]$right.Children.Add($value)
    $row = New-Row ([string][char]0xE909) (T "ping.$($t.Key)") "t:ping.$($t.Key)" $right $null
    $row.Sub.Text = $t.Host
    $t.Line = $line; $t.Value = $value; $t.History = New-Object System.Collections.ArrayList
    [void]$ui.PingList.Children.Add($row.Row)
}
$script:pingOn = $false; $script:pingBusy = $false; $script:pingNext = [datetime]::MinValue
function Set-PingButton {
    $ui.PingButtonText.Text = if ($script:pingOn) { T 'ping.stop' } else { T 'ping.start' }
    $ui.PingButtonText.Tag = if ($script:pingOn) { 't:ping.stop' } else { 't:ping.start' }
    $ui.PingGlyph.Text = if ($script:pingOn) { [string][char]0xE71A } else { [string][char]0xE768 }
}
function Update-Ping {
    if (!$script:pingOn -or $script:pingBusy -or (Get-Date) -lt $script:pingNext -or $script:page -ne 'boost') { return }
    $script:pingBusy = $true
    Start-Work $pingWork @(, @($pingTargets | ForEach-Object { @{ Key = $_.Key; Host = $_.Host } })) {
        param($r, $ctx)
        $script:pingBusy = $false; $script:pingNext = (Get-Date).AddSeconds(2)
        $res = Get-LastOutput $r
        foreach ($t in $pingTargets) {
            $ms = if ($res) { [int]$res[$t.Key] } else { -1 }
            [void]$t.History.Add($ms)
            while ($t.History.Count -gt 30) { $t.History.RemoveAt(0) }
            if ($ms -ge 0) {
                $t.Value.Text = "$ms ms"
                $t.Value.Foreground = if ($ms -lt 60) { $window.FindResource('Good') } elseif ($ms -lt 120) { '#F2C55C' } else { '#F2557A' }
            } else { $t.Value.Text = T 'ping.timeout'; $t.Value.Foreground = $window.FindResource('MutedBrush') }
            $valid = @($t.History | Where-Object { $_ -ge 0 })
            $max = [Math]::Max(50, ($valid | Measure-Object -Maximum).Maximum)
            $points = New-Object System.Windows.Media.PointCollection
            for ($i = 0; $i -lt $t.History.Count; $i++) {
                $v = $t.History[$i]; if ($v -lt 0) { $v = $max }
                $points.Add((New-Object System.Windows.Point ($i * 160 / 29), (28 - 26 * $v / $max)))
            }
            $t.Line.Points = $points
        }
    }
}
$ui.PingButton.Add_Click({ $script:pingOn = !$script:pingOn; $script:pingNext = [datetime]::MinValue; Set-PingButton; if (!$script:pingOn) { Set-Status (T 'ready') } })

# Startup apps, like the Startup tab of Task Manager: Windows keeps the on/off state in the
# StartupApproved keys (first byte even = on, odd = off) and never changes the Run entries themselves.
$approvedRoot = 'Software\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved'
function Get-StartupItems {
    $items = @()
    $sources = @(
        @{ Hive = 'HKCU'; Run = 'Software\Microsoft\Windows\CurrentVersion\Run'; Approved = 'Run' }
        @{ Hive = 'HKLM'; Run = 'Software\Microsoft\Windows\CurrentVersion\Run'; Approved = 'Run' }
        @{ Hive = 'HKLM'; Run = 'Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Run'; Approved = 'Run32' }
    )
    foreach ($src in $sources) {
        $key = Get-Item -Path "$($src.Hive):\$($src.Run)" -ErrorAction SilentlyContinue
        if (!$key) { continue }
        foreach ($name in $key.GetValueNames()) {
            if (!$name) { continue }
            $cmd = [string]$key.GetValue($name)
            $exe = if ($cmd -match '^\s*"([^"]+)"') { $Matches[1] } elseif ($cmd -match '^\s*(\S+?\.exe)') { $Matches[1] } else { $cmd }
            $items += @{ Name = $name; Command = $cmd; Exe = [Environment]::ExpandEnvironmentVariables($exe); Approved = "$($src.Hive):\$approvedRoot\$($src.Approved)" }
        }
    }
    foreach ($src in @(@{ Dir = [Environment]::GetFolderPath('Startup'); Hive = 'HKCU' }, @{ Dir = [Environment]::GetFolderPath('CommonStartup'); Hive = 'HKLM' })) {
        foreach ($f in Get-ChildItem -LiteralPath $src.Dir -File -ErrorAction SilentlyContinue | Where-Object { $_.Name -ne 'desktop.ini' }) {
            $target = $f.FullName
            if ($f.Extension -eq '.lnk') { try { $target = (New-Object -ComObject WScript.Shell).CreateShortcut($f.FullName).TargetPath } catch { } }
            $items += @{ Name = $f.Name; Command = $f.FullName; Exe = $target; Approved = "$($src.Hive):\$approvedRoot\StartupFolder" }
        }
    }
    return $items
}
function Test-StartupOn($item) {
    $data = Get-RegValue $item.Approved $item.Name
    return !($data -is [byte[]] -and $data.Count -gt 0 -and ($data[0] -band 1))
}
function Set-StartupOn($item, [bool]$on) {
    if (!(Test-Path $item.Approved)) { New-Item -Path $item.Approved -Force | Out-Null }
    $data = New-Object byte[] 12
    if ($on) { $data[0] = 2 } else { $data[0] = 3; [BitConverter]::GetBytes([DateTime]::Now.ToFileTime()).CopyTo($data, 4) }
    Set-ItemProperty -Path $item.Approved -Name $item.Name -Value $data -Type Binary
}
function Show-StartupItems {
    $ui.StartupList.Children.Clear()
    $items = @(Get-StartupItems | Sort-Object { $_.Name })
    $ui.StartupEmpty.Visibility = if ($items.Count) { 'Collapsed' } else { 'Visible' }
    foreach ($item in $items) {
        $toggle = New-Object System.Windows.Controls.CheckBox
        $toggle.Style = $window.FindResource('Switch')
        $toggle.IsChecked = Test-StartupOn $item
        $toggle.Tag = $item
        $toggle.Add_Click({
            $i = $this.Tag
            try { Set-StartupOn $i ([bool]$this.IsChecked); Set-Status ((T $(if ($this.IsChecked) { 'status.startupon' } else { 'status.startupoff' })) -f $i.Name) }
            catch { Set-Status $_.Exception.Message; $this.IsChecked = Test-StartupOn $i }
        })
        $row = New-Row ([string][char]0xE7B5) ($item.Name -replace '\.lnk$', '') $null $toggle $null
        $row.Sub.Text = $item.Command
        $row.Sub.TextTrimming = 'CharacterEllipsis'; $row.Sub.TextWrapping = 'NoWrap'
        Set-RowIcon $row (Get-FileIcon @($item.Exe))
        [void]$ui.StartupList.Children.Add($row.Row)
    }
    Update-Separators $ui.StartupList
}
Show-StartupItems
Update-BoostCard
Update-Separators $ui.PingList

# ---------------------------------------------------------------------------------------------
# Tweaks (each one reads the real state of the PC)
# ---------------------------------------------------------------------------------------------
Add-Mark 'Tweaks'
function Invoke-AtlasScript([string]$relative, [string]$pattern) {
    $file = Get-ChildItem -Path (Join-Path $desktop $relative) -Filter $pattern -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($file) { Start-Process cmd.exe -ArgumentList "/c `"`"$($file.FullName)`" /silent`"" -WindowStyle Hidden -Wait }
}

$gpuKey = 'HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers'
$dxKey = 'HKCU:\Software\Microsoft\DirectX\UserGpuPreferences'
$tcpipKey = 'HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters\Interfaces'
$dwmKey = 'HKLM:\SOFTWARE\Microsoft\Windows\Dwm'
$serializeKey = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Serialize'
$deviceGuardKey = 'HKLM:\SYSTEM\CurrentControlSet\Control\DeviceGuard'
$hvciKey = "$deviceGuardKey\Scenarios\HypervisorEnforcedCodeIntegrity"
# Flags bit 4 = the keyboard shortcut of Sticky Keys, Filter Keys (Keyboard Response) and Toggle Keys
$accessKeys = 'HKCU:\Control Panel\Accessibility\StickyKeys', 'HKCU:\Control Panel\Accessibility\Keyboard Response', 'HKCU:\Control Panel\Accessibility\ToggleKeys'
# Registry keys of the MSI setting of each real graphics card (PCI)
function Get-GpuMsiKeys {
    @($gpus | Where-Object { $_.PNPDeviceID -like 'PCI\*' } | ForEach-Object {
        "HKLM:\SYSTEM\CurrentControlSet\Enum\$($_.PNPDeviceID)\Device Parameters\Interrupt Management\MessageSignaledInterruptProperties" })
}
# Group: the section on the Tweaks page (none = Gaming). Script: an unchanged AtlasOS script in AtlasDesktop,
# run with /silent in the background. Work: a script block run in the background, param($on).
# More unused services (setup option "disable-extra-services") and their Windows default start type
$extraServices = [ordered]@{ AJRouter = 3; Fax = 3; MapsBroker = 2; PhoneSvc = 3; RetailDemo = 3; wisvc = 3; SCardSvr = 3; ScDeviceEnum = 3
    SCPolicySvc = 3; WpcMonSvc = 3; SEMgrSvc = 3; WalletService = 3; WMPNetworkSvc = 3; TroubleshootingSvc = 3 }
$servicesKey = 'HKLM:\SYSTEM\CurrentControlSet\Services'
$tweaks = @(
    @{ Key = 'hags'; Glyph = [char]0xE7F4; Restart = $true
       Get = { (Get-RegValue $gpuKey 'HwSchMode') -eq 2 }
       Set = { param($on) Set-ItemProperty -Path $gpuKey -Name HwSchMode -Value $(if ($on) { 2 } else { 1 }) -Type DWord -Force } }
    @{ Key = 'windowed'; Glyph = [char]0xE737; Win11 = $true
       Get = { (Get-RegValue $dxKey 'DirectXUserGlobalSettings') -match 'SwapEffectUpgradeEnable=1' }
       Set = { param($on)
               if (!(Test-Path $dxKey)) { New-Item -Path $dxKey -Force | Out-Null }
               $parts = @((Get-RegValue $dxKey 'DirectXUserGlobalSettings') -split ';' | Where-Object { $_ -and $_ -notlike 'SwapEffectUpgradeEnable=*' })
               $parts += "SwapEffectUpgradeEnable=$(if ($on) { 1 } else { 0 })"
               Set-ItemProperty -Path $dxKey -Name DirectXUserGlobalSettings -Value (($parts -join ';') + ';') -Type String -Force } }
    @{ Key = 'gamemode'; Glyph = [char]0xE7FC; Default = $true
       Get = { (Get-RegValue 'HKCU:\Software\Microsoft\GameBar' 'AutoGameModeEnabled') -ne 0 }
       Set = { param($on)
               if (!(Test-Path 'HKCU:\Software\Microsoft\GameBar')) { New-Item -Path 'HKCU:\Software\Microsoft\GameBar' -Force | Out-Null }
               Set-ItemProperty -Path 'HKCU:\Software\Microsoft\GameBar' -Name AutoGameModeEnabled -Value $(if ($on) { 1 } else { 0 }) -Type DWord -Force } }
    @{ Key = 'maxperf'; Glyph = [char]0xE945
       Script = @{ Folder = '3. General Configuration\Power-saving'; On = 'Disable Power-saving*.cmd'; Off = 'Default Power-saving*.cmd' }
       Get = { [string](powercfg /getactivescheme) -match '11111111-1111-1111-1111-111111111111' } }
    @{ Key = 'store'; Glyph = [char]0xE719; Slow = $true; Async = $true
       Get = { [bool](Get-AppxPackage -Name 'Microsoft.WindowsStore' -ErrorAction SilentlyContinue) } }
    @{ Key = 'hibernation'; Glyph = [char]0xE708
       Script = @{ Folder = '3. General Configuration\Hibernation'; On = 'Enable Hibernation*.cmd'; Off = 'Disable Hibernation*.cmd' }
       Get = { (Get-RegValue 'HKLM:\SYSTEM\CurrentControlSet\Control\Power' 'HibernateEnabled') -eq 1 } }

    # Input and latency
    @{ Key = 'timer'; Group = 'latency'; Glyph = [char]0xE916; Restart = $true; Async = $true; Default = $false
       Script = @{ Folder = '3. General Configuration\Timer Resolution'; On = 'Enable timer resolution*.cmd'; Off = 'Disable timer resolution*.cmd' }
       Get = { [bool](Get-ScheduledTask -TaskName 'Force Timer Resolution' -ErrorAction SilentlyContinue) } }
    @{ Key = 'access'; Group = 'latency'; Glyph = [char]0xE765; Restart = $true; Default = $true
       Get = { ([int](Get-RegValue $accessKeys[0] 'Flags') -band 4) -ne 0 }
       Set = { param($on)
               foreach ($k in $accessKeys) {
                   if (!(Test-Path $k)) { continue }
                   $flags = [int](Get-RegValue $k 'Flags')
                   $flags = if ($on) { $flags -bor 4 } else { $flags -band (-bnot 4) }
                   Set-ItemProperty -Path $k -Name Flags -Value ([string]$flags) -Type String -Force
               } } }

    # Network (the DNS row is added below)
    @{ Key = 'nagle'; Group = 'network'; Glyph = [char]0xE968; Restart = $true; Default = $true
       Get = { !@(Get-ChildItem -Path $tcpipKey -ErrorAction SilentlyContinue | Where-Object { (Get-ItemProperty -LiteralPath $_.PSPath -ErrorAction SilentlyContinue).TcpAckFrequency -eq 1 }).Count }
       Set = { param($on)
               foreach ($i in @(Get-ChildItem -Path $tcpipKey -ErrorAction SilentlyContinue)) {
                   if ($on) { Remove-ItemProperty -LiteralPath $i.PSPath -Name TcpAckFrequency, TCPNoDelay -ErrorAction SilentlyContinue }
                   else {
                       Set-ItemProperty -LiteralPath $i.PSPath -Name TcpAckFrequency -Value 1 -Type DWord -Force
                       Set-ItemProperty -LiteralPath $i.PSPath -Name TCPNoDelay -Value 1 -Type DWord -Force
                   }
               } } }
    @{ Key = 'nic'; Group = 'network'; Glyph = [char]0xE839; Async = $true; Default = $true
       Get = { $names = @(Get-NetAdapter -Physical -ErrorAction Stop | ForEach-Object { $_.Name })
               $props = @(Get-NetAdapterAdvancedProperty -Name $names -AllProperties -ErrorAction Stop | Where-Object { $_.RegistryKeyword -in '*InterruptModeration', '*EEE' })
               if (!$props.Count) { throw 'not supported' }
               [bool]@($props | Where-Object { [string]$_.RegistryValue -eq '1' }).Count }
       Work = { param($on)
                foreach ($a in @(Get-NetAdapter -Physical)) {
                    foreach ($kw in '*InterruptModeration', '*EEE') {
                        Set-NetAdapterAdvancedProperty -Name $a.Name -RegistryKeyword $kw -RegistryValue $(if ($on) { 1 } else { 0 }) -ErrorAction SilentlyContinue
                    }
                } } }

    # Display and graphics (the refresh rate row is added below)
    @{ Key = 'mpo'; Group = 'graphics'; Glyph = [char]0xE7F4; Restart = $true; Default = $true
       Get = { (Get-RegValue $dwmKey 'OverlayTestMode') -ne 5 }
       Set = { param($on)
               if ($on) { Remove-ItemProperty -Path $dwmKey -Name OverlayTestMode -ErrorAction SilentlyContinue }
               else { Set-ItemProperty -Path $dwmKey -Name OverlayTestMode -Value 5 -Type DWord -Force } } }
    @{ Key = 'msi'; Group = 'graphics'; Glyph = [char]0xE964; Restart = $true
       Get = { $keys = @(Get-GpuMsiKeys); if (!$keys.Count) { throw 'no graphics card' }
               !@($keys | Where-Object { (Get-RegValue $_ 'MSISupported') -ne 1 }).Count }
       Set = { param($on)
               foreach ($k in @(Get-GpuMsiKeys)) {
                   if (!(Test-Path $k)) { New-Item -Path $k -Force | Out-Null }
                   Set-ItemProperty -Path $k -Name MSISupported -Value $(if ($on) { 1 } else { 0 }) -Type DWord -Force
               } } }

    # Memory and system
    @{ Key = 'memcomp'; Group = 'system'; Glyph = [char]0xE964; Restart = $true; Async = $true; Default = $true
       Get = { if ((Get-Service SysMain -ErrorAction Stop).StartType -eq 'Disabled') { throw 'SysMain is off' }
               [bool](Get-MMAgent -ErrorAction Stop).MemoryCompression }
       Work = { param($on)
                try { if ($on) { Enable-MMAgent -MemoryCompression -ErrorAction Stop } else { Disable-MMAgent -MemoryCompression -ErrorAction Stop } }
                catch { $_.Exception.Message } } }
    # On: the services this Windows has are disabled (from the next start); off: their Windows default
    @{ Key = 'extrasvc'; Group = 'system'; Glyph = [char]0xE912; Restart = $true; Default = $false
       Get = { $found = @($extraServices.Keys | Where-Object { Test-Path "$servicesKey\$_" })
               $found.Count -gt 0 -and !($found | Where-Object { (Get-RegValue "$servicesKey\$_" 'Start') -ne 4 }) }
       Set = { param($on)
               foreach ($name in $extraServices.Keys) {
                   if (Test-Path "$servicesKey\$name") { Set-ItemProperty -Path "$servicesKey\$name" -Name Start -Value $(if ($on) { 4 } else { $extraServices[$name] }) -Type DWord -Force }
               } } }
    # The same two values as the AtlasOS scripts "Enable VBS" / "Disable VBS" (AtlasOS 0.4.1 for Windows 10 has no such scripts)
    @{ Key = 'vbs'; Group = 'system'; Glyph = [char]0xE72E; Restart = $true
       Get = { (Get-RegValue $hvciKey 'Enabled') -eq 1 }
       Set = { param($on)
               foreach ($k in $hvciKey, $deviceGuardKey) { if (!(Test-Path $k)) { New-Item -Path $k -Force | Out-Null } }
               Set-ItemProperty -Path $hvciKey -Name Enabled -Value $(if ($on) { 1 } else { 0 }) -Type DWord -Force
               Set-ItemProperty -Path $deviceGuardKey -Name EnableVirtualizationBasedSecurity -Value $(if ($on) { 1 } else { 0 }) -Type DWord -Force } }
    @{ Key = 'desktopmenu'; Group = 'system'; Glyph = [char]0xE700
       Get = { Test-Path $menuKey }
       Work = { param($on, $script) & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $script $(if ($on) { '-Install' } else { '-Remove' }) } }
    @{ Key = 'tray'; Group = 'system'; Glyph = [char]0xE7C4; Async = $true
       Get = { [bool](Get-ScheduledTask -TaskPath '\AkatiOS\' -TaskName 'Akati OS tray' -ErrorAction SilentlyContinue) }
       Work = { param($on, $script) & powershell.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path (Split-Path $script) 'AkatiTray.ps1') $(if ($on) { '-Install' } else { '-Remove' }) } }
    @{ Key = 'startdelay'; Group = 'system'; Glyph = [char]0xE823; Default = $true
       Get = { (Get-RegValue $serializeKey 'StartupDelayInMSec') -ne 0 }
       Set = { param($on)
               if ($on) { Remove-ItemProperty -Path $serializeKey -Name StartupDelayInMSec, WaitForIdleState -ErrorAction SilentlyContinue }
               else {
                   if (!(Test-Path $serializeKey)) { New-Item -Path $serializeKey -Force | Out-Null }
                   Set-ItemProperty -Path $serializeKey -Name StartupDelayInMSec -Value 0 -Type DWord -Force
                   Set-ItemProperty -Path $serializeKey -Name WaitForIdleState -Value 0 -Type DWord -Force
               } } }
)

# One gray heading and one grouped list per section (Gaming is in the XAML)
$tweakLists = @{ gaming = $ui.TweaksList }
foreach ($g in 'latency', 'network', 'graphics', 'system') {
    $head = New-Text (T "tw.group.$g") 13 'SemiBold' "t:tw.group.$g"
    $head.Style = $window.FindResource('Section')
    $card = New-Object System.Windows.Controls.Border
    $card.Style = $window.FindResource('Card'); $card.Padding = '0'; $card.Margin = '0,0,0,22'
    $list = New-Object System.Windows.Controls.StackPanel
    $card.Child = $list
    [void]$ui.TweakGroups.Children.Add($head); [void]$ui.TweakGroups.Children.Add($card)
    $tweakLists[$g] = $list
}

# Turns one tweak on or off (switch click, and Reset to Windows defaults)
function Invoke-Tweak($t, [bool]$on) {
    $name = T "tw.$($t.Key)"
    Set-Status ((T 'status.tweak') -f $name) $true
    $t.Toggle.IsEnabled = $false
    $context = @{ Tweak = $t; Name = $name }
    $finish = {
        param($r, $ctx)
        $tg = $ctx.Tweak.Toggle
        try { $tg.IsChecked = [bool](& $ctx.Tweak.Get) } catch { }
        $tg.IsEnabled = $true
        # A Work block returns an error message when it failed
        $err = Get-LastOutput $r
        if ($err -is [string] -and $err) { Set-Status "$($ctx.Name): $err"; return }
        $msg = (T 'status.tweakdone') -f $ctx.Name
        if ($ctx.Tweak.Restart) { $msg += ' · ' + (T 'restart') }
        Set-Status $msg
    }
    if ($t.Script) {
        # AtlasOS script, in the background; some end with "pause" even when silent, so input comes from nul
        Start-Work {
            param($desktop, $folder, $pattern)
            $file = Get-ChildItem -Path (Join-Path $desktop $folder) -Filter $pattern -ErrorAction SilentlyContinue | Select-Object -First 1
            if ($file) { Start-Process cmd.exe -ArgumentList "/c `"`"$($file.FullName)`" /silent < nul`"" -WindowStyle Hidden -Wait }
            else { "Script not found: $folder\$pattern" }
        } @($desktop, $t.Script.Folder, $(if ($on) { $t.Script.On } else { $t.Script.Off })) $finish $context
        return
    }
    if ($t.Work) {
        Start-Work $t.Work @($on, $menuScript) $finish $context
        if ($t.Key -eq 'desktopmenu' -and $on) { Request-MenuUpdate }
        return
    }
    if ($t.Key -eq 'store') {
        Start-Work {
            param($on)
            if ($on) {
                # wsreset -i installs the Microsoft Store again in the background
                Start-Process wsreset.exe -ArgumentList '-i' -WindowStyle Hidden -Wait
                $deadline = (Get-Date).AddSeconds(90)
                while (!(Get-AppxPackage -Name 'Microsoft.WindowsStore') -and (Get-Date) -lt $deadline) { Start-Sleep -Seconds 3 }
            } else {
                Get-Process -Name 'WinStore.App' -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
                Get-AppxPackage -AllUsers -Name 'Microsoft.WindowsStore' | Remove-AppxPackage -AllUsers -ErrorAction SilentlyContinue
                Get-AppxProvisionedPackage -Online | Where-Object DisplayName -eq 'Microsoft.WindowsStore' |
                    Remove-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue | Out-Null
            }
        } @($on) $finish $context
    } else {
        try { & $t.Set $on } catch { }
        & $finish $null $context
    }
}

foreach ($tw in $tweaks) {
    if ($tw.Win11 -and $build -lt 22000) { continue }
    $toggle = New-Object System.Windows.Controls.CheckBox
    $toggle.Style = $window.FindResource('Switch')
    $row = New-Row ([string]$tw.Glyph) (T "tw.$($tw.Key)") "t:tw.$($tw.Key)" $toggle "t:tw.$($tw.Key).d"
    $row.Sub.Text = T "tw.$($tw.Key).d"
    $tw.Toggle = $toggle; $tw.Sub = $row.Sub
    if ($tw.Async -and !$Screenshot) {
        # Slow to read (modules, Store, network): read in the background, the switch is filled in when done.
        # These Get blocks use only cmdlets, no variables of this script.
        $toggle.IsEnabled = $false
        Start-Work $tw.Get @() {
            param($r, $t)
            $value = Get-LastOutput $r
            if ($value -is [bool]) { $t.Toggle.IsChecked = $value; $t.Toggle.IsEnabled = $true }
            Update-TweakHints
        } $tw
    } else {
        try { $toggle.IsChecked = [bool](& $tw.Get) } catch { $toggle.IsEnabled = $false }
    }
    $toggle.Tag = $tw
    $toggle.Add_Click({ Invoke-Tweak $this.Tag ([bool]$this.IsChecked) })
    $group = if ($tw.Group) { $tw.Group } else { 'gaming' }
    $tw.Row = $row.Row
    [void]$tweakLists[$group].Children.Add($row.Row)
}

# DNS: Automatic / Cloudflare / Google on the connected network adapters (IPv4 and IPv6)
$dnsServers = @{
    cloudflare = '1.1.1.1', '1.0.0.1', '2606:4700:4700::1111', '2606:4700:4700::1001'
    google     = '8.8.8.8', '8.8.4.4', '2001:4860:4860::8888', '2001:4860:4860::8844'
}
function Set-Dns([string]$choice) {
    Set-Status ((T 'status.tweak') -f (T 'tw.dns')) $true
    Start-Work {
        param($choice, $servers)
        foreach ($i in @(Get-NetAdapter -Physical | Where-Object Status -eq 'Up')) {
            if ($choice -eq 'auto') { Set-DnsClientServerAddress -InterfaceIndex $i.ifIndex -ResetServerAddresses }
            else { Set-DnsClientServerAddress -InterfaceIndex $i.ifIndex -ServerAddresses $servers }
        }
        Clear-DnsClientCache
    } @($choice, $dnsServers[$choice]) { param($r, $c) Set-Status ((T 'status.dns') -f (T "dns.$c")) } $choice
}
function Get-DnsChoice {
    $idx = @(Get-NetAdapter -Physical -ErrorAction SilentlyContinue | Where-Object Status -eq 'Up' | ForEach-Object { $_.ifIndex })
    if (!$idx.Count) { return $null }
    $servers = @(Get-DnsClientServerAddress -InterfaceIndex $idx -AddressFamily IPv4 -ErrorAction SilentlyContinue | ForEach-Object { $_.ServerAddresses })
    if ($servers -contains '1.1.1.1') { 'cloudflare' } elseif ($servers -contains '8.8.8.8') { 'google' } else { 'auto' }
}
$dnsSegments = New-Object System.Windows.Controls.Border
$dnsSegments.SetResourceReference([System.Windows.Controls.Border]::BackgroundProperty, 'Field'); $dnsSegments.SetResourceReference([System.Windows.Controls.Border]::BorderBrushProperty, 'Line'); $dnsSegments.BorderThickness = '1'; $dnsSegments.CornerRadius = 7; $dnsSegments.Padding = '2'
$dnsPanel = New-Object System.Windows.Controls.StackPanel; $dnsPanel.Orientation = 'Horizontal'
$dnsSegments.Child = $dnsPanel
foreach ($choice in 'auto', 'cloudflare', 'google') {
    $seg = New-Object System.Windows.Controls.RadioButton
    $seg.Style = $window.FindResource('Segment'); $seg.GroupName = 'Dns'; $seg.Content = T "dns.$choice"; $seg.Tag = "t:dns.$choice"
    $seg.IsEnabled = $false
    $seg.Add_Click({ Set-Dns $this.Tag.Substring(6) })
    [void]$dnsPanel.Children.Add($seg)
}
# The adapters and their DNS servers are read in the background (the network modules load slowly)
function Set-DnsSegments($choice) {
    foreach ($seg in $dnsPanel.Children) { $seg.IsChecked = $seg.Tag -eq "t:dns.$choice"; $seg.IsEnabled = [bool]$choice }
}
if ($Screenshot) { Set-DnsSegments (Get-DnsChoice) }
else { Start-Work ([scriptblock]::Create("function Get-DnsChoice {$((Get-Item function:Get-DnsChoice).Definition)}; Get-DnsChoice")) @() { param($r, $c) Set-DnsSegments (Get-LastOutput $r) } $null }
$dnsRow = New-Row ([string][char]0xE774) (T 'tw.dns') 't:tw.dns' $dnsSegments 't:tw.dns.d'
$dnsRow.Sub.Text = T 'tw.dns.d'
$tweakLists['network'].Children.Insert(0, $dnsRow.Row)

# Screen refresh rate: the highest the primary screen can do at its resolution
$refreshButton = New-Object System.Windows.Controls.Button
$refreshButton.Style = $window.FindResource('PillAccent')
$refreshRow = New-Row ([string][char]0xE7F8) (T 'tw.refresh') 't:tw.refresh' $refreshButton $null
function Update-RefreshRow {
    try { $script:screenNow = [AkatiOS.Perf]::Current()[2]; $script:screenMax = [AkatiOS.Perf]::MaxHz() } catch { $script:screenNow = 0; $script:screenMax = 0 }
    $refreshRow.Row.Visibility = if ($script:screenMax -gt 1) { 'Visible' } else { 'Collapsed' }
    if ($script:screenMax -gt $script:screenNow) {
        $refreshRow.Sub.Text = (T 'tw.refresh.now') -f $script:screenNow, $script:screenMax
        $refreshButton.Content = (T 'tw.refresh.use') -f $script:screenMax; $refreshButton.Visibility = 'Visible'
    } else {
        $refreshRow.Sub.Text = (T 'tw.refresh.max') -f $script:screenNow
        $refreshButton.Visibility = 'Collapsed'
    }
}
$refreshButton.Add_Click({
    $result = [AkatiOS.Perf]::SetHz($script:screenMax)
    if ($result -eq 0) { Set-Status ((T 'status.refresh') -f $script:screenMax) } else { Set-Status ((T 'status.refreshfail') -f $result) }
    Update-RefreshRow; Update-Chips
})
$tweakLists['graphics'].Children.Insert(0, $refreshRow.Row)
Update-RefreshRow

# Memory compression: the advice depends on the RAM of this PC
$ramGb = try { [Math]::Round((Get-CimInstance Win32_ComputerSystem).TotalPhysicalMemory / 1GB) } catch { 0 }
function Update-TweakHints {
    $mc = $tweaks | Where-Object { $_.Key -eq 'memcomp' }
    if (!$mc.Sub) { return }
    $hint = if (!$mc.Toggle.IsEnabled) { T 'tw.memcomp.nosysmain' } elseif ($ramGb -ge 16) { (T 'tw.memcomp.off') -f $ramGb } else { (T 'tw.memcomp.on') -f $ramGb }
    $mc.Sub.Text = (T 'tw.memcomp.d') + ' ' + $hint
}
Update-TweakHints
foreach ($list in $tweakLists.Values) { Update-Separators $list }

# Reset: every tweak that has a Windows default (Default) goes back to it, and DNS to Automatic
$ui.TweaksReset.Add_Click({
    if ([System.Windows.MessageBox]::Show((T 'tweaks.resetask'), 'Akati OS Center', 'YesNo', 'Question') -ne 'Yes') { return }
    foreach ($t in $tweaks) {
        if (!$t.ContainsKey('Default') -or !$t.Toggle -or !$t.Toggle.IsEnabled) { continue }
        if ([bool]$t.Toggle.IsChecked -ne $t.Default) { $t.Toggle.IsChecked = $t.Default; Invoke-Tweak $t $t.Default }
    }
    $auto = $dnsPanel.Children | Where-Object { $_.Tag -eq 't:dns.auto' }
    if ($auto.IsEnabled -and !$auto.IsChecked) { $auto.IsChecked = $true; Set-Dns 'auto' }
    Set-Status (T 'status.reset')
})

# Game boost > Anti-cheat mode: Valorant (Vanguard) can ask for Memory integrity (HVCI) on, FiveM needs it
# off. The buttons use the Core isolation tweak; Windows changes it at the next start.
$vbsTweak = $tweaks | Where-Object { $_.Key -eq 'vbs' }
function Test-HvciRunning {
    try { 2 -in @((Get-CimInstance -Namespace 'root\Microsoft\Windows\DeviceGuard' -ClassName Win32_DeviceGuard -ErrorAction Stop).SecurityServicesRunning) }
    catch { $false }
}
function Update-AntiCheat {
    $wanted = (Get-RegValue $hvciKey 'Enabled') -eq 1
    $text = if ($wanted) { T 'ac.on' } else { T 'ac.off' }
    if ($Screenshot) { $ui.AcState.Text = $text; return }
    if ($wanted -ne (Test-HvciRunning)) { $text += '  ·  ' + (T 'ac.pending') }
    $ui.AcState.Text = $text
}
function Set-AntiCheat([bool]$on) {
    if ((Get-RegValue $hvciKey 'Enabled') -ne [int]$on) {
        $vbsTweak.Toggle.IsChecked = $on
        Invoke-Tweak $vbsTweak $on
    }
    Update-AntiCheat
    if (!$Screenshot -and $on -ne (Test-HvciRunning)) {
        if ([System.Windows.MessageBox]::Show((T 'ac.restartask'), 'Akati OS Center', 'YesNo', 'Question') -eq 'Yes') { Restart-Computer -Force }
    }
}
$ui.AcValorant.Add_Click({ Set-AntiCheat $true })
$ui.AcFiveM.Add_Click({ Set-AntiCheat $false })
Update-AntiCheat

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
function Show-Games {
    $ui.GamesList.Children.Clear()
    $paths = @(if (Test-Path $gamesKey) { (Get-Item $gamesKey).Property })
    # Defender exclusions are read once per refresh (null when Defender is off)
    $exclusions = try { @((Get-MpPreference -ErrorAction Stop).ExclusionPath) } catch { $null }
    foreach ($path in $paths) {
        $right = New-Object System.Windows.Controls.StackPanel; $right.Orientation = 'Horizontal'
        foreach ($kind in 'cpu', 'gpu', 'defender') {
            $chip = New-Object System.Windows.Controls.CheckBox
            $chip.Style = $window.FindResource('Chip'); $chip.Content = T "games.$kind"; $chip.Margin = '0,0,6,0'; $chip.VerticalAlignment = 'Center'
            $chip.Tag = @{ Path = $path; Kind = $kind }
            $chip.IsChecked = Get-GameOption $path $kind $exclusions
            if ($kind -eq 'defender' -and $null -eq $exclusions) { $chip.IsEnabled = $false; $chip.ToolTip = T 'games.nodefender' }
            $chip.Add_Click({
                $t = $this.Tag
                try { Set-GameOption $t.Path $t.Kind ([bool]$this.IsChecked) } catch { $this.IsChecked = !$this.IsChecked; Set-Status $_.Exception.Message }
            })
            [void]$right.Children.Add($chip)
        }
        $remove = New-Object System.Windows.Controls.Button
        $remove.Style = $window.FindResource('Bare'); $remove.Padding = '7'; $remove.Margin = '4,0,0,0'; $remove.ToolTip = T 'games.remove'; $remove.Tag = $path
        $x = New-Text ([string][char]0xE711) 12; $x.Style = $window.FindResource('Glyph'); $remove.Content = $x
        $remove.Add_Click({
            $path = $this.Tag
            foreach ($kind in 'cpu', 'gpu', 'defender') { try { Set-GameOption $path $kind $false } catch { } }
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
        $icon = Get-FileIcon @($path)
        if ($icon) { Set-RowIcon $row $icon }
        [void]$ui.GamesList.Children.Add($row.Row)
    }
    $ui.GamesEmpty.Visibility = if ($paths.Count) { 'Collapsed' } else { 'Visible' }
    Update-Separators $ui.GamesList
}
$ui.GameAddButton.Add_Click({
    $dialog = New-Object Microsoft.Win32.OpenFileDialog
    $dialog.Title = T 'games.pick'; $dialog.Filter = 'Games (*.exe)|*.exe'
    if (!$dialog.ShowDialog($window)) { return }
    $path = $dialog.FileName
    if (!(Test-Path $gamesKey)) { New-Item -Path $gamesKey -Force | Out-Null }
    Set-ItemProperty -Path $gamesKey -Name $path -Value 1 -Type DWord -Force
    # High priority and the dedicated GPU at once; skipping Defender is the user's choice
    foreach ($kind in 'cpu', 'gpu') { try { Set-GameOption $path $kind $true } catch { } }
    Set-Status ((T 'status.gameadded') -f [IO.Path]::GetFileNameWithoutExtension($path))
    Show-Games
    Request-MenuUpdate
})
Show-Games

# ---------------------------------------------------------------------------------------------
# Cleaner
# ---------------------------------------------------------------------------------------------
Add-Mark 'Cleaner'
# Folders: their contents are deleted (wildcards allowed). Files: these files are deleted.
# Only caches, logs and temporary files: nothing that holds settings, saves, passwords or cookies.
# Off = not ticked at first (cleaning them makes the next start of a game or browser slower).
$cleanItems = @(
    @{ Key = 'temp';    Glyph = [char]0xE8B7; Folders = @($env:TEMP) }
    @{ Key = 'wintemp'; Glyph = [char]0xE8B7; Folders = @((Join-Path $windir 'Temp')) }
    @{ Key = 'update';  Glyph = [char]0xE895; Folders = @((Join-Path $windir 'SoftwareDistribution\Download'),
                                                         (Join-Path $windir 'ServiceProfiles\NetworkService\AppData\Local\Microsoft\Windows\DeliveryOptimization\Cache')) }
    @{ Key = 'dumps';   Glyph = [char]0xE7BA; Folders = @((Join-Path $env:LOCALAPPDATA 'CrashDumps'), (Join-Path $env:LOCALAPPDATA 'Microsoft\Windows\WER'),
                                                         (Join-Path $env:ProgramData 'Microsoft\Windows\WER\ReportArchive'), (Join-Path $env:ProgramData 'Microsoft\Windows\WER\ReportQueue')) }
    @{ Key = 'logs';    Glyph = [char]0xE9F9; Files = @((Join-Path $windir 'Logs\CBS\*.log'), (Join-Path $windir 'Logs\DISM\*.log'), (Join-Path $windir 'Panther\*.log')) }
    @{ Key = 'thumbs';  Glyph = [char]0xE91B; Files = @((Join-Path $env:LOCALAPPDATA 'Microsoft\Windows\Explorer\thumbcache_*.db')) }
    @{ Key = 'apps';    Glyph = [char]0xE8BD; Folders = @((Join-Path $env:APPDATA 'discord\Cache\Cache_Data'), (Join-Path $env:APPDATA 'discord\Code Cache'), (Join-Path $env:APPDATA 'discord\GPUCache'),
                                                         (Join-Path $env:LOCALAPPDATA 'Steam\htmlcache'), (Join-Path $env:LOCALAPPDATA 'EpicGamesLauncher\Saved\webcache*')) }
    @{ Key = 'browser'; Glyph = [char]0xE774; Off = $true
       Folders = @((Join-Path $env:LOCALAPPDATA 'BraveSoftware\Brave-Browser\User Data\*\Cache\Cache_Data'), (Join-Path $env:LOCALAPPDATA 'Microsoft\Edge\User Data\*\Cache\Cache_Data'),
                   (Join-Path $env:LOCALAPPDATA 'Google\Chrome\User Data\*\Cache\Cache_Data'), (Join-Path $env:LOCALAPPDATA 'Mozilla\Firefox\Profiles\*\cache2')) }
    @{ Key = 'shaders'; Glyph = [char]0xE7F4; Off = $true
       Folders = @((Join-Path $env:LOCALAPPDATA 'D3DSCache'), (Join-Path $env:LOCALAPPDATA 'NVIDIA\DXCache'), (Join-Path $env:LOCALAPPDATA 'NVIDIA\GLCache'),
                   (Join-Path $env:LOCALAPPDATA 'AMD\DxCache'), (Join-Path $env:LOCALAPPDATA 'AMD\GLCache'), (Join-Path $env:LOCALAPPDATA 'Intel\ShaderCache')) }
    @{ Key = 'recycle'; Glyph = [char]0xE74D; Recycle = $true }
)
foreach ($ci in $cleanItems) {
    $right = New-Object System.Windows.Controls.StackPanel
    $right.Orientation = 'Horizontal'
    $size = New-Text '-' 13 'SemiBold'; $size.Margin = '0,0,18,0'; $size.VerticalAlignment = 'Center'; $size.MinWidth = 70; $size.TextAlignment = 'Right'
    $check = New-Object System.Windows.Controls.CheckBox
    $check.Style = $window.FindResource('Tick'); $check.IsChecked = !$ci.Off; $check.VerticalAlignment = 'Center'
    $check.Add_Click({ Update-CleanTotal })
    [void]$right.Children.Add($size); [void]$right.Children.Add($check)
    $row = New-Row ([string]$ci.Glyph) (T "clean.$($ci.Key)") "t:clean.$($ci.Key)" $right "t:clean.$($ci.Key).d"
    $row.Sub.Text = T "clean.$($ci.Key).d"
    $ci.SizeText = $size; $ci.Check = $check; $ci.Bytes = 0
    [void]$ui.CleanList.Children.Add($row.Row)
}
Update-Separators $ui.CleanList

function Update-CleanTotal {
    $total = 0
    foreach ($ci in $cleanItems) { if ($ci.Check.IsChecked) { $total += $ci.Bytes } }
    $ui.CleanTotal.Text = Format-Size $total
}

$measureWork = {
    param($items)
    $out = @{}
    foreach ($i in $items) {
        $sum = 0
        if ($i.Recycle) {
            try { (New-Object -ComObject Shell.Application).NameSpace(10).Items() | ForEach-Object { $sum += $_.Size } } catch { }
        }
        foreach ($f in @($i.Folders)) {
            if (!$f) { continue }
            $sum += [double](Get-ChildItem -Path $f -Recurse -Force -File -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum).Sum
        }
        foreach ($f in @($i.Files)) {
            if (!$f) { continue }
            $sum += [double](Get-ChildItem -Path $f -Force -File -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum).Sum
        }
        $out[$i.Key] = [double]$sum
    }
    $out
}

function Start-Scan([scriptblock]$then) {
    Set-Status (T 'status.scanning') $true
    $ui.ScanButton.IsEnabled = $false; $ui.CleanButton.IsEnabled = $false
    $items = @($cleanItems | ForEach-Object { @{ Key = $_.Key; Folders = $_.Folders; Files = $_.Files; Recycle = $_.Recycle } })
    Start-Work $measureWork @(, $items) {
        param($r, $ctx)
        $sizes = Get-LastOutput $r
        foreach ($ci in $cleanItems) { $ci.Bytes = if ($sizes) { [double]$sizes[$ci.Key] } else { 0 }; $ci.SizeText.Text = Format-Size $ci.Bytes }
        Update-CleanTotal
        $ui.ScanButton.IsEnabled = $true; $ui.CleanButton.IsEnabled = $true
        Set-Status (T 'ready')
        if ($ctx.Then) { & $ctx.Then }
    } @{ Then = $then }
}

function Start-Clean {
    $script:cleanBefore = 0
    $selected = @($cleanItems | Where-Object { $_.Check.IsChecked } | ForEach-Object { $script:cleanBefore += $_.Bytes; @{ Key = $_.Key; Folders = $_.Folders; Files = $_.Files; Recycle = $_.Recycle } })
    if (!$selected.Count) { return }
    Set-Status (T 'status.cleaning') $true
    $ui.ScanButton.IsEnabled = $false; $ui.CleanButton.IsEnabled = $false
    Start-Work {
        param($items)
        foreach ($i in $items) {
            if ($i.Recycle) { try { Clear-RecycleBin -Force -ErrorAction SilentlyContinue } catch { } }
            # The contents of each folder (the folder itself stays); files in use are skipped
            foreach ($f in @($i.Folders)) {
                if (!$f) { continue }
                foreach ($dir in @(Get-Item -Path $f -Force -ErrorAction SilentlyContinue | Where-Object { $_.PSIsContainer })) {
                    Get-ChildItem -LiteralPath $dir.FullName -Force -ErrorAction SilentlyContinue | Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
                }
            }
            foreach ($f in @($i.Files)) {
                if ($f) { Get-ChildItem -Path $f -Force -File -ErrorAction SilentlyContinue | Remove-Item -Force -ErrorAction SilentlyContinue }
            }
        }
    } @(, $selected) {
        param($r, $ctx)
        Start-Scan {
            $after = 0
            foreach ($ci in $cleanItems) { if ($ci.Check.IsChecked) { $after += $ci.Bytes } }
            Set-Status ((T 'status.cleaned') -f (Format-Size ([Math]::Max(0, $script:cleanBefore - $after))))
        }
    }
}

$ui.ScanButton.Add_Click({ Start-Scan })
$ui.CleanButton.Add_Click({ Start-Clean })
$ui.QuickClean.Add_Click({ $ui.NavCleaner.IsChecked = $true; Start-Scan { Start-Clean } })

# ---------------------------------------------------------------------------------------------
# Appearance
# ---------------------------------------------------------------------------------------------
Add-Mark 'Appearance'
$themes = @(
    @{ Key = 'dark';      File = 'akatios-dark.theme';      Image = 'akatios-dark.png' }
    @{ Key = 'light';     File = 'akatios-light.theme';     Image = 'akatios-light.png' }
    @{ Key = 'slideshow'; File = 'akatios-slideshow.theme'; Image = 'akatios-lockscreen.png' }
)

function Update-ThemeCards {
    $current = [string](Get-RegValue 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes' 'CurrentTheme')
    foreach ($th in $themes) {
        $active = $current -like "*$($th.File)"
        if ($active) { $th.Card.SetResourceReference([System.Windows.Controls.Border]::BorderBrushProperty, 'Accent2') } else { $th.Card.BorderBrush = $window.FindResource('CardBorder') }
        $th.Button.Content = if ($active) { T 'active' } else { T 'apply' }
    }
}

foreach ($th in $themes) {
    $card = New-Object System.Windows.Controls.Border
    $card.Style = $window.FindResource('Card'); $card.Margin = '8,0'; $card.Padding = '12'; $card.BorderThickness = 2
    $stack = New-Object System.Windows.Controls.StackPanel
    $preview = New-Object System.Windows.Controls.Border
    $preview.CornerRadius = 8; $preview.Height = 130; $preview.ClipToBounds = $true; $preview.SetResourceReference([System.Windows.Controls.Border]::BackgroundProperty, 'Fill')
    $img = New-Object System.Windows.Controls.Image
    $img.Stretch = 'UniformToFill'; $img.Source = Get-Image (Join-Path $wallpapers $th.Image) 480
    $preview.Child = $img
    $name = New-Text (T "theme.$($th.Key)") 14 'SemiBold' "t:theme.$($th.Key)"; $name.Margin = '2,12,0,0'
    $desc = New-Text '' 12; $desc.Foreground = $window.FindResource('MutedBrush'); $desc.Margin = '2,2,0,10'
    if ($th.Key -eq 'slideshow') { $desc.Tag = 't:theme.slideshow.d'; $desc.Text = T 'theme.slideshow.d' } else { $desc.Text = ' ' }
    $btn = New-Object System.Windows.Controls.Button
    $btn.Style = $window.FindResource('Secondary'); $btn.Tag = $th
    $btn.Add_Click({
        $t = $this.Tag
        $path = Join-Path $themesDir $t.File
        if (Test-Path -LiteralPath $path) { Start-Process -FilePath $path }
        Set-Status ((T 'status.theme') -f (T "theme.$($t.Key)"))
        $timer2 = New-Object System.Windows.Threading.DispatcherTimer
        $timer2.Interval = [TimeSpan]::FromSeconds(3)
        $timer2.Add_Tick({ $this.Stop(); Update-ThemeCards })
        $timer2.Start()
    })
    [void]$stack.Children.Add($preview); [void]$stack.Children.Add($name); [void]$stack.Children.Add($desc); [void]$stack.Children.Add($btn)
    $card.Child = $stack
    $th.Card = $card; $th.Button = $btn
    [void]$ui.ThemesGrid.Children.Add($card)
}
Update-ThemeCards

# Windows API: wallpaper, cursors and the "colors changed" message
Add-Type -Namespace AkatiOS -Name Native -MemberDefinition @'
[DllImport("user32.dll", CharSet = CharSet.Unicode)] public static extern bool SystemParametersInfo(int action, int param, string value, int flags);
[DllImport("user32.dll", CharSet = CharSet.Unicode)] public static extern IntPtr SendMessageTimeout(IntPtr hWnd, int msg, IntPtr wParam, string lParam, int flags, int timeout, out IntPtr result);
[DllImport("dwmapi.dll")] public static extern int DwmSetWindowAttribute(IntPtr hwnd, int attribute, ref int value, int size);
[DllImport("user32.dll", CharSet = CharSet.Unicode)] public static extern IntPtr LoadCursorFromFile(string file);
'@
function Send-SettingChange([string]$area) {
    $r = [IntPtr]::Zero
    [void][AkatiOS.Native]::SendMessageTimeout([IntPtr]0xffff, 0x1A, [IntPtr]::Zero, $area, 2, 3000, [ref]$r)
}

# Accent color: Akati OS Center, Windows (Start, taskbar, title bars) and the Akati OS Terminal colors
$accents = @(
    @{ Key = 'purple'; Base = '#8A3FD6'; Light = '#B07CF0'; G1 = '#A35CF0'; G2 = '#6C3BC8' }
    @{ Key = 'blue';   Base = '#2F6FE0'; Light = '#7AA8FF'; G1 = '#4C86F5'; G2 = '#2752C2' }
    @{ Key = 'cyan';   Base = '#0E9FB0'; Light = '#5AD8E6'; G1 = '#22B8C8'; G2 = '#0B7D99' }
    @{ Key = 'green';  Base = '#1F9D57'; Light = '#6FDC9A'; G1 = '#2DB86A'; G2 = '#178048' }
    @{ Key = 'pink';   Base = '#D13F94'; Light = '#F488C6'; G1 = '#E559A9'; G2 = '#A82E7A' }
    @{ Key = 'red';    Base = '#D6453F'; Light = '#F58C84'; G1 = '#E85A50'; G2 = '#B03530' }
    @{ Key = 'orange'; Base = '#D9771E'; Light = '#F5B15F'; G1 = '#EE9135'; G2 = '#B65F16' }
)
function ConvertTo-Color([string]$hex) { [System.Windows.Media.ColorConverter]::ConvertFromString($hex) }

# New brushes for this window. The XAML uses them as DynamicResource, so every style follows at once
# (brushes inside styles are frozen and cannot be recolored in place).
# Look picker (Appearance): Auto, Dark or Light, saved as CenterLook
$lookChoice = Get-RegValue $settingsKey 'CenterLook'
if ($lookChoice -notin 'dark', 'light') { $lookChoice = 'auto' }
$ui["Look$([Globalization.CultureInfo]::InvariantCulture.TextInfo.ToTitleCase($lookChoice))"].IsChecked = $true
foreach ($n in 'Auto', 'Dark', 'Light') {
    $ui["Look$n"].Add_Checked({ Save-Setting CenterLook $this.Name.Substring(4).ToLowerInvariant(); Set-CenterLook (Get-LookName) })
}

function Set-CenterAccent($a) {
    $res = $window.Resources
    # ::new, not New-Object: New-Object wraps the brush in a PSObject, which WPF does not accept as a brush
    $res['Accent'] = [System.Windows.Media.SolidColorBrush]::new((ConvertTo-Color $a.Base))
    $res['Accent2'] = [System.Windows.Media.SolidColorBrush]::new((ConvertTo-Color $a.Light))
    $res['AccentGradient'] = [System.Windows.Media.LinearGradientBrush]::new((ConvertTo-Color $a.G1), (ConvertTo-Color $a.G2), [System.Windows.Point]::new(0, 0), [System.Windows.Point]::new(1, 1))
}

# Windows keeps the accent as 0xAABBGGRR (and a palette of 8 shades from light to dark)
function Set-WindowsAccent($a) {
    $c = ConvertTo-Color $a.Base
    function Mix($col, [double]$t) {
        # t > 0 towards white, t < 0 towards black
        if ($t -ge 0) { [byte]($col + (255 - $col) * $t) } else { [byte]($col * (1 + $t)) }
    }
    $palette = New-Object byte[] 32
    $shades = 0.55, 0.38, 0.2, 0, -0.2, -0.38, -0.55, -0.7
    for ($i = 0; $i -lt 8; $i++) {
        $palette[$i * 4] = Mix $c.R $shades[$i]; $palette[$i * 4 + 1] = Mix $c.G $shades[$i]; $palette[$i * 4 + 2] = Mix $c.B $shades[$i]; $palette[$i * 4 + 3] = 0
    }
    $abgr = [BitConverter]::ToInt32([byte[]]@($c.R, $c.G, $c.B, 0xFF), 0)
    $dark = [BitConverter]::ToInt32([byte[]]@($palette[16], $palette[17], $palette[18], 0xFF), 0)
    $argb = [BitConverter]::ToInt32([byte[]]@($c.B, $c.G, $c.R, 0xC4), 0)
    $accentKey = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Accent'
    $dwmKey = 'HKCU:\Software\Microsoft\Windows\DWM'
    foreach ($k in $accentKey, $dwmKey) { if (!(Test-Path $k)) { New-Item -Path $k -Force | Out-Null } }
    Set-ItemProperty -Path $accentKey -Name AccentPalette -Value $palette -Type Binary
    Set-ItemProperty -Path $accentKey -Name AccentColorMenu -Value $abgr -Type DWord
    Set-ItemProperty -Path $accentKey -Name StartColorMenu -Value $dark -Type DWord
    Set-ItemProperty -Path $dwmKey -Name AccentColor -Value $abgr -Type DWord
    Set-ItemProperty -Path $dwmKey -Name ColorizationColor -Value $argb -Type DWord
    Set-ItemProperty -Path $dwmKey -Name ColorizationAfterglow -Value $argb -Type DWord
    # Use this color instead of one picked from the wallpaper
    Set-ItemProperty -Path 'HKCU:\Control Panel\Desktop' -Name AutoColorization -Value 0 -Type DWord -ErrorAction SilentlyContinue
    Send-SettingChange 'ImmersiveColorSet'
}

# The Akati OS Terminal colors are a Terminal "fragment" in ProgramData
function Set-TerminalAccent($a) {
    $fragment = Join-Path $env:ProgramData 'Microsoft\Windows Terminal\Fragments\AkatiOS\akatios.json'
    if (!(Test-Path -LiteralPath $fragment)) { return }
    $json = Get-Content -LiteralPath $fragment -Raw -Encoding UTF8 | ConvertFrom-Json
    $c = ConvertTo-Color $a.Base
    $sel = '#{0:X2}{1:X2}{2:X2}' -f [int]($c.R * 0.45), [int]($c.G * 0.45), [int]($c.B * 0.45)
    foreach ($scheme in $json.schemes) { $scheme.cursorColor = $a.Light; $scheme.selectionBackground = $sel; $scheme.purple = $a.G1; $scheme.brightPurple = $a.Light }
    # UTF-8 without BOM, like the file Windows Terminal reads
    [IO.File]::WriteAllText($fragment, ($json | ConvertTo-Json -Depth 5), (New-Object Text.UTF8Encoding $false))
}

$savedAccent = Get-RegValue $settingsKey 'Accent'
foreach ($a in $accents) {
    $sw = New-Object System.Windows.Controls.RadioButton
    $sw.Style = $window.FindResource('Swatch')
    $brush = New-Object System.Windows.Media.LinearGradientBrush (ConvertTo-Color $a.G1), (ConvertTo-Color $a.G2), 45
    $sw.Background = $brush
    $sw.Tag = $a
    $sw.ToolTip = T "accent.$($a.Key)"
    $sw.IsChecked = ($a.Key -eq $savedAccent) -or (!$savedAccent -and $a.Key -eq 'purple')
    $sw.Add_Click({
        $acc = $this.Tag
        Set-CenterAccent $acc
        Save-Setting Accent $acc.Key
        try { Set-WindowsAccent $acc; Set-TerminalAccent $acc; Set-Status ((T 'status.accent') -f (T "accent.$($acc.Key)")) }
        catch { Set-Status $_.Exception.Message }
    })
    $a.Swatch = $sw
    [void]$ui.AccentPanel.Children.Add($sw)
    if ($a.Key -eq $savedAccent) { Set-CenterAccent $a }
}

# Wallpapers: every picture in the Akati OS wallpaper folder
foreach ($file in @(Get-ChildItem -Path (Join-Path $wallpapers '*') -Include *.png, *.jpg -File -ErrorAction SilentlyContinue | Sort-Object Name)) {
    $btn = New-Object System.Windows.Controls.Button
    $btn.Cursor = 'Hand'; $btn.Margin = '0,0,12,12'; $btn.Tag = $file.FullName; $btn.ToolTip = $file.BaseName
    $btn.Template = [Windows.Markup.XamlReader]::Parse(@'
<ControlTemplate xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation" TargetType="Button">
    <Border x:Name="Bd" xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml" CornerRadius="10" BorderThickness="2" BorderBrush="Transparent" Padding="2">
        <ContentPresenter/>
    </Border>
    <ControlTemplate.Triggers>
        <Trigger Property="IsMouseOver" Value="True"><Setter TargetName="Bd" Property="BorderBrush" Value="#B07CF0"/></Trigger>
    </ControlTemplate.Triggers>
</ControlTemplate>
'@)
    $frame = New-Object System.Windows.Controls.Border
    $frame.Width = 168; $frame.Height = 95; $frame.CornerRadius = 8; $frame.SetResourceReference([System.Windows.Controls.Border]::BackgroundProperty, 'Fill')
    $brush = New-Object System.Windows.Media.ImageBrush (Get-Image $file.FullName 340)
    $brush.Stretch = 'UniformToFill'
    $frame.Background = $brush
    $btn.Content = $frame
    $btn.Add_Click({
        # SPI_SETDESKWALLPAPER, saved to the user profile and sent to all windows
        Set-ItemProperty -Path 'HKCU:\Control Panel\Desktop' -Name WallpaperStyle -Value '10'
        Set-ItemProperty -Path 'HKCU:\Control Panel\Desktop' -Name TileWallpaper -Value '0'
        [void][AkatiOS.Native]::SystemParametersInfo(0x14, 0, $this.Tag, 3)
        Set-Status ((T 'status.wallpaper') -f [IO.Path]::GetFileNameWithoutExtension($this.Tag))
    })
    [void]$ui.WallPanel.Children.Add($btn)
}

# Cursors: Akati OS arrow and busy cursors; the other pointers stay the Windows ones
$akatiCursors = Join-Path $modules 'Other\AkatiOS\Cursors'
$windowsCursors = [ordered]@{
    AppStarting = '%SystemRoot%\cursors\aero_working.ani'; Arrow = '%SystemRoot%\cursors\aero_arrow.cur'
    Hand = '%SystemRoot%\cursors\aero_link.cur'; Help = '%SystemRoot%\cursors\aero_helpsel.cur'; No = '%SystemRoot%\cursors\aero_unavail.cur'
    NWPen = '%SystemRoot%\cursors\aero_pen.cur'; SizeAll = '%SystemRoot%\cursors\aero_move.cur'; SizeNESW = '%SystemRoot%\cursors\aero_nesw.cur'
    SizeNS = '%SystemRoot%\cursors\aero_ns.cur'; SizeNWSE = '%SystemRoot%\cursors\aero_nwse.cur'; SizeWE = '%SystemRoot%\cursors\aero_ew.cur'
    UpArrow = '%SystemRoot%\cursors\aero_up.cur'; Wait = '%SystemRoot%\cursors\aero_busy.ani'; Crosshair = ''; IBeam = ''
}
function Set-Cursors([bool]$akati) {
    $key = 'HKCU:\Control Panel\Cursors'
    foreach ($name in $windowsCursors.Keys) { Set-ItemProperty -Path $key -Name $name -Value $windowsCursors[$name] -Type ExpandString }
    if ($akati) {
        foreach ($f in 'akatios-arrow.cur', 'akatios-busy.ani', 'akatios-working.ani') {
            if ([AkatiOS.Native]::LoadCursorFromFile((Join-Path $akatiCursors $f)) -eq [IntPtr]::Zero) { throw "Windows cannot load $f" }
        }
        Set-ItemProperty -Path $key -Name Arrow -Value (Join-Path $akatiCursors 'akatios-arrow.cur') -Type ExpandString
        Set-ItemProperty -Path $key -Name Wait -Value (Join-Path $akatiCursors 'akatios-busy.ani') -Type ExpandString
        Set-ItemProperty -Path $key -Name AppStarting -Value (Join-Path $akatiCursors 'akatios-working.ani') -Type ExpandString
    }
    Set-ItemProperty -Path $key -Name '(default)' -Value $(if ($akati) { 'Akati OS' } else { 'Windows Default' })
    # SPI_SETCURSORS reloads the cursors from the registry
    [void][AkatiOS.Native]::SystemParametersInfo(0x57, 0, $null, 3)
}
$ui.CursorAkati.Add_Click({ try { Set-Cursors $true; Set-Status (T 'status.cursor.akati') } catch { Set-Status $_.Exception.Message } })
$ui.CursorWindows.Add_Click({ try { Set-Cursors $false; Set-Status (T 'status.cursor.windows') } catch { Set-Status $_.Exception.Message } })

# Sounds: Akati OS sounds, the Windows sounds or none (AtlasOS turns sounds off)
$akatiSounds = Join-Path $modules 'Other\AkatiOS\Sounds'
$soundEvents = [ordered]@{
    '.Default'           = @('akatios-default.wav', 'Windows Background.wav')
    'SystemAsterisk'     = @('akatios-info.wav', 'Windows Background.wav')
    'SystemExclamation'  = @('akatios-warning.wav', 'Windows Background.wav')
    'SystemHand'         = @('akatios-error.wav', 'Windows Foreground.wav')
    'SystemNotification' = @('akatios-info.wav', 'Windows Background.wav')
    'Notification.Default' = @('akatios-notify.wav', 'Windows Notify System Generic.wav')
    'DeviceConnect'      = @('akatios-connect.wav', 'Windows Hardware Insert.wav')
    'DeviceDisconnect'   = @('akatios-disconnect.wav', 'Windows Hardware Remove.wav')
}
function Set-Sounds([string]$scheme) {
    $root = 'HKCU:\AppEvents\Schemes\Apps\.Default'
    foreach ($ev in $soundEvents.Keys) {
        $k = "$root\$ev\.Current"
        if (!(Test-Path -LiteralPath $k)) { New-Item -Path $k -Force | Out-Null }
        $value = switch ($scheme) {
            'akati'   { Join-Path $akatiSounds $soundEvents[$ev][0] }
            'windows' { Join-Path $windir "Media\$($soundEvents[$ev][1])" }
            default   { '' }
        }
        Set-ItemProperty -LiteralPath $k -Name '(default)' -Value $value
    }
    Set-ItemProperty -Path 'HKCU:\AppEvents\Schemes' -Name '(default)' -Value '.Current'
}
$ui.SoundAkati.Add_Click({ try { Set-Sounds 'akati'; Set-Status (T 'status.sound.akati') } catch { Set-Status $_.Exception.Message } })
$ui.SoundWindows.Add_Click({ try { Set-Sounds 'windows'; Set-Status (T 'status.sound.windows') } catch { Set-Status $_.Exception.Message } })
$ui.SoundNone.Add_Click({ try { Set-Sounds 'none'; Set-Status (T 'status.sound.none') } catch { Set-Status $_.Exception.Message } })
# Play the notification sound that is set now, so the three choices can be compared
$ui.SoundPreview.Add_Click({
    $f = [string](Get-ItemProperty -LiteralPath 'HKCU:\AppEvents\Schemes\Apps\.Default\Notification.Default\.Current' -ErrorAction SilentlyContinue).'(default)'
    $f = [Environment]::ExpandEnvironmentVariables($f)
    if ($f -and (Test-Path -LiteralPath $f)) {
        try { (New-Object System.Media.SoundPlayer $f).Play(); Set-Status ((T 'status.sound.play') -f [IO.Path]::GetFileNameWithoutExtension($f)) } catch { Set-Status $_.Exception.Message }
    } else { Set-Status (T 'status.sound.none') }
})

# ---------------------------------------------------------------------------------------------
# Updates and links
# ---------------------------------------------------------------------------------------------
Add-Mark 'Updates and links'
$script:releaseUrl = "https://github.com/$repo/releases"
function Start-UpdateCheck {
    Set-Status (T 'status.checking') $true
    $ui.UpdateButton.IsEnabled = $false
    Start-Work {
        param($repo)
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        $errors = @()
        try {
            return Invoke-RestMethod -Uri "https://api.github.com/repos/$repo/releases/latest" -Headers @{ 'User-Agent' = 'AkatiOS-Center' } -UseBasicParsing -TimeoutSec 20
        } catch { $errors += "api.github.com: $($_.Exception.Message)" }
        # The GitHub API allows 60 requests an hour per address; the release page redirects to the latest tag without that limit
        try {
            $req = [Net.HttpWebRequest]::Create("https://github.com/$repo/releases/latest")
            $req.Method = 'HEAD'; $req.AllowAutoRedirect = $false; $req.UserAgent = 'AkatiOS-Center'; $req.Timeout = 20000
            $res = $req.GetResponse()
            $location = $res.Headers['Location']; $res.Close()
            if ($location -match '/releases/tag/([^/?#]+)') { return [pscustomobject]@{ tag_name = [Uri]::UnescapeDataString($Matches[1]); html_url = $location } }
            $errors += "github.com: no release"
        } catch { $errors += "github.com: $($_.Exception.Message)" }
        [pscustomobject]@{ error = $errors -join ' | ' }
    } @($repo) {
        param($r, $ctx)
        $ui.UpdateButton.IsEnabled = $true
        $release = Get-LastOutput $r
        if (!$release -or !$release.tag_name) {
            $ui.UpdateStatus.Text = T 'update.error'; $ui.UpdateHint.Text = T 'update.error'; $ui.UpdateDot.Fill = $window.FindResource('MutedBrush')
            # The reason goes to the status bar, so a problem report screenshot shows it
            Set-Status ("$(T 'update.error') $($release.error)".Trim()); return
        }
        $script:releaseUrl = $release.html_url
        $newer = $false; $ahead = $false
        try {
            $newer = [version]($release.tag_name.TrimStart('v')) -gt [version]($version.TrimStart('v'))
            $ahead = [version]($version.TrimStart('v')) -gt [version]($release.tag_name.TrimStart('v'))
        } catch { $newer = $release.tag_name -ne $version }
        if ($ahead) {
            $msg = (T 'update.ahead') -f $release.tag_name
            $ui.UpdateStatus.Foreground = $window.FindResource('Good')
        } elseif ($newer) {
            $msg = (T 'update.new') -f $release.tag_name
            $ui.UpdateStatus.Foreground = $window.FindResource('Accent2')
            $ui.UpdateButton.Content = T 'update.open'
            $ui.UpdateButton.Tag = 'open'
        } else {
            $msg = (T 'update.latest') -f $release.tag_name
            $ui.UpdateStatus.Foreground = $window.FindResource('Good')
        }
        $ui.UpdateStatus.Text = $msg; $ui.UpdateHint.Text = $msg
        $ui.UpdateDot.Fill = if ($newer) { $window.FindResource('Accent2') } else { $window.FindResource('Good') }
        Set-Status $msg
    }
}
$ui.UpdateButton.Add_Click({ if ($this.Tag -eq 'open') { Start-Process $script:releaseUrl } else { Start-UpdateCheck } })
$ui.QuickUpdate.Add_Click({ $ui.NavAbout.IsChecked = $true; Start-UpdateCheck })
$ui.QuickBoost.Add_Click({
    try {
        if (Test-Boost) { Stop-Boost; Set-Status (T 'status.boostoff') } else { Start-Boost; Set-Status (T 'status.booston') }
    } catch { Set-Status $_.Exception.Message }
    Update-BoostCard; Update-Chips
})
$ui.QuickAtlas.Add_Click({ $ui.NavTweaks.IsChecked = $true })
$ui.LinkGithub.Add_Click({ Start-Process "https://github.com/$repo" })
$ui.LinkOptions.Add_Click({ Start-Process "https://github.com/$repo/blob/main/docs/OPTIONS.md" })
$ui.LinkAtlas.Add_Click({ Start-Process 'https://github.com/Atlas-OS/Atlas' })

# ---------------------------------------------------------------------------------------------
# System settings: every setting of the AtlasOS folder (AtlasDesktop), built from its folders, so
# nothing has to be copied and new AtlasOS settings show up by themselves. A folder with files is one
# row, each file is one button.
# ---------------------------------------------------------------------------------------------
Add-Mark 'System settings'
# Names and short explanations of the AtlasOS folders: English name, Thai name, English text, Thai text
$atlasInfo = @{
    'Drivers from Windows Update' = @('Drivers from Windows Update', 'ไดรเวอร์จาก Windows Update', 'Let Windows Update install drivers.', 'ให้ Windows Update ติดตั้งไดรเวอร์เอง')
    'GPU Drivers' = @('GPU driver tools', 'เครื่องมือไดรเวอร์การ์ดจอ', 'Remove old drivers (DDU) and install drivers without extras.', 'ลบไดรเวอร์เก่า (DDU) และติดตั้งไดรเวอร์แบบไม่มีของแถม')
    'Microsoft Copilot' = @('Microsoft Copilot', 'Microsoft Copilot', 'The Copilot AI assistant.', 'ผู้ช่วย AI Copilot')
    'Recall' = @('Recall', 'Recall', 'Windows Recall, which saves snapshots of your screen.', 'Recall ของ Windows ที่เก็บภาพหน้าจอไว้ค้นหาย้อนหลัง')
    'Automatic Updates' = @('Automatic updates', 'อัปเดตอัตโนมัติ', 'Windows installs updates by itself.', 'Windows ติดตั้งอัปเดตเอง')
    'Background Apps' = @('Background apps', 'แอปเบื้องหลัง', 'Store apps keep running in the background.', 'แอปจาก Store ทำงานต่อเบื้องหลัง')
    'CPU Idle' = @('CPU idle', 'CPU idle', 'Off keeps the CPU at full clock: slightly lower latency, much more heat and power. Turn it back on if you are unsure.', 'ปิดแล้ว CPU จะทำงานเต็มความเร็วตลอด latency ลดลงเล็กน้อยแต่ร้อนและกินไฟมากขึ้นมาก ถ้าไม่แน่ใจให้เปิดไว้')
    'Desktop Context Menu' = @('Idle switch in the desktop menu', 'สวิตช์ idle ในเมนูคลิกขวา', 'Adds a CPU idle switch to the right-click menu of the desktop.', 'เพิ่มสวิตช์ CPU idle ในเมนูคลิกขวาบนเดสก์ท็อป')
    'Delivery Optimization' = @('Delivery Optimization', 'Delivery Optimization', 'Shares Windows updates with other PCs.', 'แชร์ไฟล์อัปเดต Windows กับเครื่องอื่น')
    'FSO and Game Bar' = @('Fullscreen optimizations and Game Bar', 'Fullscreen optimizations และ Game Bar', 'Needed by Game Bar recording and some games.', 'จำเป็นสำหรับการอัดคลิปด้วย Game Bar และบางเกม')
    'File Sharing' = @('File sharing', 'การแชร์ไฟล์', 'Share files and printers on your network.', 'แชร์ไฟล์และเครื่องพิมพ์ในเครือข่าย')
    'Give Access To Menu' = @('"Give access to" menu', 'เมนู "Give access to"', 'Sharing entry in the right-click menu.', 'เมนูแชร์ในคลิกขวา')
    'Network Navigation Pane' = @('Network in File Explorer', 'Network ใน File Explorer', 'The Network item in the File Explorer sidebar.', 'รายการ Network ในแถบข้างของ File Explorer')
    'Hibernation' = @('Hibernation', 'ไฮเบอร์เนต', 'Off saves disk space (the size of your RAM).', 'ปิดไว้ประหยัดพื้นที่ดิสก์เท่ากับขนาด RAM')
    'Location' = @('Location', 'ตำแหน่งที่ตั้ง', 'Apps can ask for your location.', 'ให้แอปขอตำแหน่งของเครื่องได้')
    'Mobile Devices (Phone Link)' = @('Phone Link', 'Phone Link', 'Connect your phone to Windows.', 'เชื่อมมือถือกับ Windows')
    'Power-saving' = @('Power saving', 'การประหยัดพลังงาน', 'Off is the Akati OS Maximum Performance plan. Best for desktops.', 'ปิดคือ power plan ประสิทธิภาพสูงสุดของ Akati OS เหมาะกับคอมตั้งโต๊ะ')
    'Search Indexing' = @('Search indexing', 'การทำดัชนีค้นหา', 'Faster file search in exchange for some background work.', 'ค้นหาไฟล์ได้เร็วขึ้น แลกกับงานเบื้องหลังเล็กน้อย')
    'Sleep Study' = @('Sleep study', 'Sleep study', 'Diagnostics of sleep power use.', 'บันทึกการใช้พลังงานตอน sleep')
    'Sleep' = @('Sleep', 'โหมด sleep', 'Let the PC go to sleep.', 'ให้เครื่องเข้าโหมด sleep ได้')
    'Store App Archiving' = @('Store app archiving', 'เก็บแอปที่ไม่ได้ใช้', 'Windows removes Store apps you do not use.', 'Windows ลบแอปจาก Store ที่ไม่ได้ใช้ออกเอง')
    'System Restore' = @('System Restore', 'System Restore', 'Restore points to undo system changes.', 'จุดคืนค่าไว้ย้อนการเปลี่ยนแปลงระบบ')
    'Timer Resolution' = @('Timer resolution', 'Timer resolution', 'Advanced: a more precise system timer. Read the documentation first.', 'ขั้นสูง: timer ของระบบที่ละเอียดขึ้น อ่านเอกสารก่อนใช้')
    'Update Notifications' = @('Update notifications', 'แจ้งเตือนอัปเดต', 'Windows tells you about new updates.', 'Windows แจ้งเตือนเมื่อมีอัปเดต')
    'Web Search (includes Search Highlights)' = @('Web search in Start', 'ค้นหาเว็บใน Start', 'Bing results and search highlights in the Start menu search.', 'ผลจาก Bing และ search highlights ในช่องค้นหา Start')
    'Widgets (News and Interests)' = @('Widgets', 'วิดเจ็ต', 'News and weather on the taskbar.', 'ข่าวและสภาพอากาศบน taskbar')
    'Windows Spotlight' = @('Windows Spotlight', 'Windows Spotlight', 'Daily pictures from Microsoft on the lock screen.', 'รูปประจำวันจาก Microsoft บนหน้าล็อก')
    'Windows Updates' = @('Windows Update', 'Windows Update', 'Pause Windows Update or delay feature updates.', 'หยุด Windows Update หรือเลื่อนอัปเดตใหญ่')
    'Workplace' = @('Workplace', 'บัญชีที่ทำงาน', 'Work or school accounts and device management.', 'บัญชีที่ทำงานหรือโรงเรียน และการจัดการเครื่อง')
    'Alt-Tab' = @('Alt+Tab', 'Alt+Tab', 'The Alt+Tab window switcher.', 'หน้าสลับหน้าต่าง Alt+Tab')
    'Extract' = @('"Extract" menu', 'เมนู "Extract"', 'Extract entry for zip files in the right-click menu.', 'เมนูแตกไฟล์ zip ในคลิกขวา')
    'Run With Priority' = @('"Run with priority" menu', 'เมนู "Run with priority"', 'Start a program with a higher CPU priority from the right-click menu.', 'เปิดโปรแกรมด้วย CPU priority สูงขึ้นจากคลิกขวา')
    'Send To' = @('"Send to" menu', 'เมนู "Send to"', 'Removes rarely used items from the Send to menu.', 'ลบรายการที่ไม่ค่อยใช้ออกจากเมนู Send to')
    'Take Ownership' = @('"Take ownership" menu', 'เมนู "Take ownership"', 'Take ownership of files from the right-click menu.', 'ยึดสิทธิ์เป็นเจ้าของไฟล์จากคลิกขวา')
    'Terminals' = @('Terminals in the menu', 'Terminal ในเมนู', 'Open a terminal in a folder from the right-click menu.', 'เปิด terminal ในโฟลเดอร์จากคลิกขวา')
    'Windows 11' = @('Right-click menu style', 'รูปแบบเมนูคลิกขวา', 'The full classic menu or the new Windows 11 menu.', 'เมนูแบบเต็มแบบเก่า หรือเมนูใหม่ของ Windows 11')
    'Edge Swipe' = @('Edge swipe', 'ปัดจากขอบจอ', 'Touch screen swipes from the screen edge.', 'การปัดจากขอบจอบนจอสัมผัส')
    'App Icons on Thumbnails' = @('App icons on thumbnails', 'ไอคอนแอปบนภาพย่อ', 'Small app icon on file thumbnails.', 'ไอคอนแอปเล็ก ๆ บนภาพย่อของไฟล์')
    'Automatic Folder Discovery' = @('Automatic folder type', 'ตรวจชนิดโฟลเดอร์อัตโนมัติ', 'File Explorer guesses the view of each folder (slow on big folders).', 'File Explorer เดามุมมองของแต่ละโฟลเดอร์เอง (ช้าในโฟลเดอร์ใหญ่)')
    'Compact View' = @('Compact view', 'มุมมองแบบกระชับ', 'Less space between items in File Explorer.', 'ระยะห่างระหว่างรายการใน File Explorer น้อยลง')
    'Folders in This PC' = @('Folders in This PC', 'โฟลเดอร์ใน This PC', 'Desktop, Documents and other folders in This PC.', 'โฟลเดอร์ Desktop, Documents และอื่น ๆ ใน This PC')
    'Gallery' = @('Gallery', 'Gallery', 'The Gallery item in File Explorer.', 'รายการ Gallery ใน File Explorer')
    'Quick Access' = @('Quick access', 'Quick access', 'Pinned and recent folders in File Explorer.', 'โฟลเดอร์ที่ปักหมุดและที่ใช้ล่าสุดใน File Explorer')
    'Removable Drives in Sidebar' = @('USB drives in the sidebar', 'ไดรฟ์ USB ในแถบข้าง', 'Show USB drives twice in the File Explorer sidebar.', 'แสดงไดรฟ์ USB ซ้ำในแถบข้างของ File Explorer')
    'Lock Screen' = @('Lock screen', 'หน้าล็อก', 'The picture screen before sign-in.', 'หน้ารูปภาพก่อนเข้าสู่ระบบ')
    'Battery Flyout' = @('Battery flyout', 'หน้าต่างแบตเตอรี่', 'Old or new battery popup.', 'หน้าต่างแบตเตอรี่แบบเก่าหรือใหม่')
    'Date and Time Flyout' = @('Clock flyout', 'หน้าต่างนาฬิกา', 'Old or new clock and calendar popup.', 'หน้าต่างนาฬิกาและปฏิทินแบบเก่าหรือใหม่')
    'Volume Flyout' = @('Volume flyout', 'หน้าต่างเสียง', 'Old or new volume popup.', 'หน้าต่างปรับเสียงแบบเก่าหรือใหม่')
    'Shortcut Icon' = @('Shortcut arrow', 'ลูกศรบนทางลัด', 'The arrow on shortcut icons.', 'ลูกศรบนไอคอนทางลัด')
    'Shortcut Text' = @('"- Shortcut" text', 'คำว่า "- Shortcut"', 'Text added to the name of new shortcuts.', 'คำที่ต่อท้ายชื่อทางลัดใหม่')
    'Snap Layouts' = @('Snap layouts', 'Snap layouts', 'Window layouts when you hover the maximize button.', 'เค้าโครงหน้าต่างเมื่อชี้ปุ่มขยาย')
    'Start Menu' = @('Start menu replacements', 'Start menu ทางเลือก', 'Other Start menus, for example Open-Shell.', 'Start menu แบบอื่น เช่น Open-Shell')
    'Unlock Recent Items' = @('Recent items', 'ไฟล์ล่าสุด', 'Lists of recently opened files.', 'รายการไฟล์ที่เปิดล่าสุด')
    'Verbose Status Messages' = @('Detailed status messages', 'ข้อความสถานะแบบละเอียด', 'Shows what Windows does during start and shutdown.', 'แสดงว่า Windows ทำอะไรอยู่ตอนเปิดและปิดเครื่อง')
    'Visual Effects (Animations)' = @('Visual effects', 'เอฟเฟกต์ภาพ', 'Animations and shadows of Windows.', 'แอนิเมชันและเงาของ Windows')
    'Appearance' = @('Boot appearance', 'หน้าตาตอนบูต', 'Logo, spinner and boot menu style.', 'โลโก้ วงหมุน และเมนูตอนบูต')
    'Behavior' = @('Boot behavior', 'การทำงานตอนบูต', 'Advanced options, automatic repair and more.', 'ตัวเลือกขั้นสูง การซ่อมอัตโนมัติ และอื่น ๆ')
    'Boot Configuration' = @('Boot configuration', 'การตั้งค่าบูต', 'Shows the current boot settings.', 'แสดงค่าบูตปัจจุบัน')
    'Driver Configuration' = @('Driver tools', 'เครื่องมือไดรเวอร์', 'Advanced tools for interrupts and GPU affinity.', 'เครื่องมือขั้นสูงสำหรับ interrupt และ GPU affinity')
    'Microsoft Store' = @('Microsoft Store', 'Microsoft Store', 'Needed by the Xbox app and Game Pass.', 'แอป Xbox และ Game Pass ต้องใช้')
    'Process Explorer' = @('Process Explorer', 'Process Explorer', 'A more detailed Task Manager by Microsoft.', 'Task Manager แบบละเอียดของ Microsoft')
    'Bluetooth' = @('Bluetooth', 'บลูทูธ', 'Bluetooth services.', 'บริการบลูทูธ')
    'Lanman Workstation (SMB)' = @('Network drives (SMB)', 'ไดรฟ์เครือข่าย (SMB)', 'Needed for shared folders and network drives.', 'จำเป็นสำหรับโฟลเดอร์แชร์และไดรฟ์เครือข่าย')
    'Context Menu' = @('NVIDIA container menu', 'เมนู NVIDIA container', 'Desktop menu to start and stop the NVIDIA container.', 'เมนูเดสก์ท็อปสำหรับเปิดปิด NVIDIA container')
    'NVIDIA Display Container' = @('NVIDIA Display Container', 'NVIDIA Display Container', 'Needed by the NVIDIA Control Panel. Read first.', 'NVIDIA Control Panel ต้องใช้ อ่านก่อนปิด')
    'Network Discovery' = @('Network discovery', 'ค้นหาเครื่องในเครือข่าย', 'Find other PCs and devices on your network.', 'มองเห็นเครื่องและอุปกรณ์อื่นในเครือข่าย')
    'Printing' = @('Printing', 'การพิมพ์', 'Printer services.', 'บริการเครื่องพิมพ์')
    'Superfetch' = @('SysMain (Superfetch)', 'SysMain (Superfetch)', 'Preloads often used apps into RAM.', 'โหลดแอปที่ใช้บ่อยเข้า RAM ล่วงหน้า')
    'Static IP' = @('Static IP', 'IP แบบคงที่', 'Keeps the current IP address.', 'ล็อกเลข IP ปัจจุบันไว้')
    'Core Isolation (VBS)' = @('Core isolation (VBS)', 'Core isolation (VBS)', 'Some anti-cheats (Valorant, FACEIT) need it on.', 'anti-cheat บางตัว (Valorant, FACEIT) ต้องเปิดไว้')
    'Defender' = @('Microsoft Defender', 'Microsoft Defender', 'Antivirus. Some anti-cheats need it on.', 'แอนตี้ไวรัส anti-cheat บางตัวต้องเปิดไว้')
    'Hide App and Browser Control' = @('"App and browser control"', '"App and browser control"', 'Page in Windows Security.', 'หน้าใน Windows Security')
    'Security Health Tray' = @('Security tray icon', 'ไอคอน Security ที่ถาด', 'Windows Security icon next to the clock.', 'ไอคอน Windows Security ข้างนาฬิกา')
    'Mitigations' = @('Mitigations', 'Mitigations', 'CPU security mitigations. Keep the Windows defaults if you are unsure.', 'การป้องกันช่องโหว่ CPU ถ้าไม่แน่ใจให้ใช้ค่าของ Windows')
    'Fault Tolerant Heap' = @('Fault tolerant heap', 'Fault tolerant heap', 'Windows works around apps that crash often.', 'Windows แก้ทางให้แอปที่แครชบ่อย')
    'Network' = @('Reset network', 'รีเซ็ตเครือข่าย', 'Fixes internet problems.', 'แก้ปัญหาอินเทอร์เน็ต')
    'Safe Mode' = @('Safe Mode', 'Safe Mode', 'Restart in Safe Mode and back.', 'รีสตาร์ตเข้า Safe Mode และออก')
}
# Short button labels: the verb at the start of a file name, in English and Thai
$atlasVerbs = @{
    'Enable' = @('Enable', 'เปิด'); 'Disable' = @('Disable', 'ปิด'); 'Add' = @('Add', 'เพิ่ม'); 'Remove' = @('Remove', 'ลบ')
    'Show' = @('Show', 'แสดง'); 'Hide' = @('Hide', 'ซ่อน'); 'Install' = @('Install', 'ติดตั้ง'); 'Uninstall' = @('Uninstall', 'ถอนการติดตั้ง')
    'Allow' = @('Allow', 'อนุญาต'); 'Disallow' = @('Disallow', 'ไม่อนุญาต'); 'Restore' = @('Restore', 'คืนค่า'); 'Reset' = @('Reset', 'รีเซ็ต')
    'Set' = @('Set', 'ตั้งค่า'); 'Toggle' = @('Turn on or off', 'เปิดหรือปิด'); 'Unlock' = @('Unlock', 'ปลดล็อก'); 'Debloat' = @('Clean up', 'ลบรายการที่ไม่ใช้')
    'Old' = @('Old', 'แบบเก่า'); 'Modern' = @('Modern', 'แบบใหม่'); 'New' = @('New', 'แบบใหม่'); 'Minimal' = @('Minimal', 'น้อยที่สุด')
    'Default' = @('Windows default', 'ค่าของ Windows'); 'Legacy' = @('Legacy', 'แบบเก่า')
}

# "Disable Hibernation (default)" in the Hibernation row becomes "Disable": the verb alone, when the
# rest of the name only repeats the row name. Files directly in a category ($leaf empty) keep their name.
$atlasFiller = 'support', 'settings', 'service', 'services', 'context', 'menu', 'in', 'to', 'the', 'all', 'ls', 'windows'
function Get-AtlasLabel([IO.FileInfo]$file, [string]$leaf) {
    $name = $file.BaseName -replace '\s*\(default\)', '' -replace '\s+copy$', ''
    if (!$leaf -or $file.Extension -notin '.cmd', '.reg', '.ps1' -or $name -notmatch '^(\S+)\s+(.+)$' -or !$atlasVerbs.ContainsKey($Matches[1])) { return $name }
    $verb = $atlasVerbs[$Matches[1]][$(if ($lang -eq 'th') { 1 } else { 0 })]
    $rest = $Matches[2]
    $extra = if ($rest -match '(\([^)]*\))\s*$') { ' ' + $Matches[1] } else { '' }
    $leafWords = @(($leaf -replace '\([^)]*\)', '').ToLowerInvariant().Split(' ', [StringSplitOptions]::RemoveEmptyEntries))
    $left = @(($rest -replace '\([^)]*\)', '').ToLowerInvariant().Split(' ', [StringSplitOptions]::RemoveEmptyEntries) |
        Where-Object { $_ -notin $leafWords -and "${_}s" -notin $leafWords -and $_ -notin $atlasFiller })
    if ($left.Count -eq 0) { return "$verb$extra" }
    # Thai: translate the verb only for short names ("ปิด VBS"), longer ones stay as AtlasOS wrote them
    if ($lang -eq 'th' -and $rest.Split(' ').Count -le 2) { return "$verb $rest" }
    return $name
}

# A restore point before the first change, once per window (Windows allows one every 24 hours by default)
$script:restoreDone = $false
$restoreSetting = Get-RegValue $settingsKey 'RestorePoint'
$ui.RestoreToggle.IsChecked = ($restoreSetting -ne 0)
$ui.RestoreToggle.Add_Click({
    try {
        if (!(Test-Path $settingsKey)) { New-Item -Path $settingsKey -Force | Out-Null }
        Set-ItemProperty -Path $settingsKey -Name RestorePoint -Value $(if ($this.IsChecked) { 1 } else { 0 }) -Type DWord
    } catch { }
})
# System Protection: turn System Restore on for a drive, or open System Restore from there
$ui.RestoreOpen.Add_Click({ Start-Process SystemPropertiesProtection.exe })

function Invoke-AtlasItem([IO.FileInfo]$file) {
    $changes = $file.Extension.ToLowerInvariant() -in '.reg', '.cmd', '.ps1'
    if ($changes -and $ui.RestoreToggle.IsChecked -and !$script:restoreDone) {
        $script:restoreDone = $true
        Set-Status (T 'status.restoring') $true
        Start-Work {
            try {
                $before = @(Get-ComputerRestorePoint -ErrorAction Stop).Count
                Checkpoint-Computer -Description 'Akati OS Center' -RestorePointType MODIFY_SETTINGS -ErrorAction Stop -WarningAction SilentlyContinue
                if (@(Get-ComputerRestorePoint).Count -gt $before) { 'made' } else { 'recent' }
            } catch { 'off' }
        } @() {
            param($r, $f)
            $result = Get-LastOutput $r
            Set-Status (T "status.restore.$result")
            Invoke-AtlasFile $f
        } $file
        return
    }
    Invoke-AtlasFile $file
}

function Invoke-AtlasFile([IO.FileInfo]$file) {
    $name = $file.BaseName
    switch ($file.Extension.ToLowerInvariant()) {
        '.reg' {
            Start-Process reg.exe -ArgumentList "import `"$($file.FullName)`"" -WindowStyle Hidden -Wait
            Set-Status ((T 'status.applied') -f $name)
        }
        '.cmd' {
            # AtlasOS scripts explain what they change and wait for a key, so they get a visible window
            Start-Process cmd.exe -ArgumentList "/c `"`"$($file.FullName)`"`"" -WorkingDirectory $file.DirectoryName
            Set-Status ((T 'status.opened') -f $name)
        }
        '.ps1' {
            Start-Process powershell.exe -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$($file.FullName)`"" -WorkingDirectory $file.DirectoryName
            Set-Status ((T 'status.opened') -f $name)
        }
        default {
            Start-Process -FilePath $file.FullName
            Set-Status ((T 'status.opened') -f $name)
        }
    }
}

function New-AtlasButton([IO.FileInfo]$file, [string]$leaf) {
    $btn = New-Object System.Windows.Controls.Button
    $btn.Style = $window.FindResource('Secondary'); $btn.Margin = '0,6,8,0'
    $content = New-Object System.Windows.Controls.StackPanel
    $content.Orientation = 'Horizontal'
    if ($file.Extension -in '.url', '.lnk', '.exe') {
        $g = New-Text ([string][char]0xE8A7) 12; $g.Style = $window.FindResource('Glyph'); $g.FontSize = 12; $g.Margin = '0,0,8,0'
        [void]$content.Children.Add($g)
    }
    [void]$content.Children.Add((New-Text (Get-AtlasLabel $file $leaf) 13))
    if ($file.BaseName -match '\(default\)') {
        $badge = New-Object System.Windows.Controls.Border
        $badge.Style = $window.FindResource('Badge'); $badge.Margin = '8,0,0,0'
        $bt = New-Text (T 'system.default') 10 'SemiBold'; $bt.SetResourceReference([System.Windows.Controls.TextBlock]::ForegroundProperty, 'Accent2')
        $badge.Child = $bt
        [void]$content.Children.Add($badge)
    }
    $btn.Content = $content; $btn.ToolTip = $file.Name; $btn.Tag = $file
    $btn.Add_Click({ Invoke-AtlasItem $this.Tag })
    return $btn
}

$script:systemCards = New-Object System.Collections.ArrayList
function Add-SystemCard([string]$key, [System.IO.DirectoryInfo[]]$dirs, [string]$topPath) {
    $card = New-Object System.Windows.Controls.Border
    $card.Style = $window.FindResource('Card'); $card.Margin = '0,0,0,22'; $card.Padding = '0'
    $stack = New-Object System.Windows.Controls.StackPanel
    $head = New-Text (T "system.cat.$key")
    $head.Style = $window.FindResource('Section')
    $rows = New-Object System.Collections.ArrayList
    $li = if ($lang -eq 'th') { 1 } else { 0 }
    foreach ($d in $dirs) {
        $files = @(Get-ChildItem -LiteralPath $d.FullName -File -ErrorAction SilentlyContinue | Where-Object { $_.Extension -ne '.xml' } | Sort-Object Name)
        if ($files.Count -eq 0) { continue }
        $row = New-Object System.Windows.Controls.Border
        $row.Padding = '14,10'; $row.Background = [System.Windows.Media.Brushes]::Transparent
        $rowStack = New-Object System.Windows.Controls.StackPanel
        $info = $null; $desc = ''
        if ($d.FullName -eq $topPath) {
            $title = T 'system.links'
        } else {
            $info = $atlasInfo[$d.Name]
            $title = if ($info) { $info[$li] } else { $d.Name }
            if ($info) { $desc = $info[2 + $li] }
            $parent = $d.Parent.FullName
            if ($parent -ne $topPath) {
                $pInfo = $atlasInfo[$d.Parent.Name]
                $pTitle = if ($pInfo) { $pInfo[$li] } else { $d.Parent.Name }
                $title = $pTitle + ' › ' + $title
            }
        }
        $label = New-Text $title 14 'SemiBold'
        [void]$rowStack.Children.Add($label)
        if ($desc) {
            $dt = New-Text $desc 12; $dt.Foreground = $window.FindResource('MutedBrush'); $dt.Margin = '0,2,0,0'
            [void]$rowStack.Children.Add($dt)
        }
        $wrap = New-Object System.Windows.Controls.WrapPanel
        $leaf = if ($d.FullName -eq $topPath) { '' } else { $d.Name }
        foreach ($f in $files) { [void]$wrap.Children.Add((New-AtlasButton $f $leaf)) }
        [void]$rowStack.Children.Add($wrap)
        $row.Child = $rowStack
        # Search in both languages and in the original AtlasOS names
        $words = @($key, (T "system.cat.$key"), $d.Name, $title, $desc) + @($files | ForEach-Object { $_.BaseName })
        if ($info) { $words += $info }
        $row.Tag = ($words -join ' ').ToLowerInvariant()
        [void]$stack.Children.Add($row)
        [void]$rows.Add($row)
    }
    if ($rows.Count -eq 0) { return }
    $card.Child = $stack
    Update-Separators $stack
    [void]$ui.SystemList.Children.Add($head)
    [void]$ui.SystemList.Children.Add($card)
    [void]$script:systemCards.Add(@{ Card = $card; Head = $head; Rows = $rows; Stack = $stack })
}

function Show-SystemList {
    $ui.SystemList.Children.Clear()
    $script:systemCards.Clear()
    if (!(Test-Path -LiteralPath $desktop)) { return }
    foreach ($top in Get-ChildItem -LiteralPath $desktop -Directory | Sort-Object Name) {
        $key = $top.Name -replace '^\d+\.\s*', ''
        $dirs = @($top) + @(Get-ChildItem -LiteralPath $top.FullName -Directory -Recurse | Sort-Object FullName)
        Add-SystemCard $key $dirs $top.FullName
    }
    # Files directly in the folder: links
    Add-SystemCard 'AkatiOS' @(Get-Item -LiteralPath $desktop) (Get-Item -LiteralPath $desktop).FullName
    Update-SystemFilter
}

function Update-SystemFilter {
    $q = $ui.SystemSearch.Text.Trim().ToLowerInvariant()
    $ui.SystemSearchHint.Visibility = if ($q) { 'Collapsed' } else { 'Visible' }
    foreach ($c in $script:systemCards) {
        $shown = 0
        foreach ($r in $c.Rows) {
            $match = !$q -or $r.Tag.Contains($q)
            $r.Visibility = if ($match) { 'Visible' } else { 'Collapsed' }
            if ($match) { $shown++ }
        }
        $c.Card.Visibility = if ($shown) { 'Visible' } else { 'Collapsed' }
        $c.Head.Visibility = $c.Card.Visibility
        Update-Separators $c.Stack
    }
}
$ui.SystemSearch.Add_TextChanged({ Update-SystemFilter })
Show-SystemList

# ---------------------------------------------------------------------------------------------
# Problem report: one zip on the desktop with the Akati OS logs and PC details
# ---------------------------------------------------------------------------------------------
Add-Mark 'Problem report'
$ui.IssuesButton.Add_Click({ Start-Process "https://github.com/$repo/issues" })
$ui.ReportButton.Add_Click({
    $this.IsEnabled = $false
    Set-Status (T 'status.report') $true
    $appState = ($apps | ForEach-Object { '{0}: {1}' -f $_.Name, $(if (Test-App $_) { 'installed' } else { 'not installed' }) }) -join "`r`n"
    Start-Work {
        param($version, $edition, $appState, $logs, $desktopDir)
        $stamp = Get-Date -Format 'yyyyMMdd-HHmm'
        $work = Join-Path $env:TEMP "AkatiOS-report-$stamp"
        New-Item -ItemType Directory -Path $work -Force | Out-Null
        $lines = @("Akati OS problem report, $(Get-Date -Format 'yyyy-MM-dd HH:mm')", '')
        $lines += "Akati OS: $version ($edition)"
        try {
            $os = Get-CimInstance Win32_OperatingSystem
            $cv = Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion'
            $lines += "Windows: $($os.Caption) $($cv.DisplayVersion) build $($cv.CurrentBuild).$($cv.UBR), $($os.OSArchitecture)"
            $lines += "Language: $((Get-Culture).Name), UI $((Get-UICulture).Name)"
            $lines += "CPU: $((Get-CimInstance Win32_Processor | Select-Object -First 1).Name)"
            $lines += 'GPU: ' + ((Get-CimInstance Win32_VideoController | ForEach-Object { "$($_.Name) (driver $($_.DriverVersion))" }) -join '; ')
            $lines += 'RAM: {0:N1} GB' -f ($os.TotalVisibleMemorySize / 1MB)
            $disk = [IO.DriveInfo]::new('C')
            $lines += 'C: {0:N1} GB free of {1:N1} GB' -f ($disk.TotalFreeSpace / 1GB), ($disk.TotalSize / 1GB)
            $lines += "Power plan: $([string](powercfg /getactivescheme))"
        } catch { $lines += "System info error: $($_.Exception.Message)" }
        $lines += "WinGet: $(try { (& winget --version) 2>$null } catch { 'not found' })"
        $lines += '', 'Gaming apps:', $appState
        $lines | Set-Content -Path (Join-Path $work 'system.txt') -Encoding UTF8
        if (Test-Path $logs) { Copy-Item -Path (Join-Path $logs '*.log') -Destination $work -ErrorAction SilentlyContinue }
        # No personal data: remove the user name and the PC name from every file
        foreach ($f in Get-ChildItem -LiteralPath $work -File) {
            $text = [IO.File]::ReadAllText($f.FullName)
            $text = $text -replace [regex]::Escape($env:USERNAME), '<user>' -replace [regex]::Escape($env:COMPUTERNAME), '<pc>'
            [IO.File]::WriteAllText($f.FullName, $text)
        }
        $zip = Join-Path $desktopDir "AkatiOS-report-$stamp.zip"
        Compress-Archive -Path (Join-Path $work '*') -DestinationPath $zip -Force
        Remove-Item -LiteralPath $work -Recurse -Force -ErrorAction SilentlyContinue
        $zip
    } @($version, $edition, $appState, $progressDir, [Environment]::GetFolderPath('Desktop')) {
        param($r, $ctx)
        $ui.ReportButton.IsEnabled = $true
        $zip = Get-LastOutput $r
        if ($zip -and (Test-Path -LiteralPath $zip)) {
            Set-Status ((T 'status.reportdone') -f (Split-Path $zip -Leaf))
            Start-Process explorer.exe -ArgumentList "/select,`"$zip`""
        } else { Set-Status (T 'status.reportfailed') }
    }
})

# ---------------------------------------------------------------------------------------------
# Navigation, title bar, language
# ---------------------------------------------------------------------------------------------
Add-Mark 'Navigation, title bar, language'
$pages = 'dashboard', 'gaming', 'boost', 'tweaks', 'cleaner', 'appearance', 'about'
$script:page = 'dashboard'
function Get-PageId([string]$p) { [Globalization.CultureInfo]::InvariantCulture.TextInfo.ToTitleCase($p) }
function Show-Page([string]$name) {
    $script:page = $name
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
function Get-Both([string]$key) { "$($strings.en[$key]) $($strings.th[$key])" }
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
        $el.BringIntoView()
        $brush = $window.FindResource('Accent').Clone(); $brush.Opacity = 0.35
        $el.Background = $brush
        $fade = New-Object System.Windows.Media.Animation.DoubleAnimation 0.35, 0, (New-Object System.Windows.Duration ([TimeSpan]::FromMilliseconds(1400)))
        $brush.BeginAnimation([System.Windows.Media.Brush]::OpacityProperty, $fade)
    }, 'Background')
}
function Get-SpotlightItems {
    $items = New-Object System.Collections.ArrayList
    $add = { param($text, $search, $sub, $glyph, $action, $data)
             [void]$items.Add(@{ Text = $text; Search = "$text $search".ToLowerInvariant(); Sub = $sub; Glyph = [string]$glyph; Action = $action; Data = $data }) }
    foreach ($p in $pages) { & $add (T "nav.$p") (Get-Both "nav.$p") (T 'spot.page') ([char]0xE8A5) { param($d) $ui["Nav$(Get-PageId $d)"].IsChecked = $true } $p }
    foreach ($t in $tweaks) {
        if (!$t.Row) { continue }
        & $add (T "tw.$($t.Key)") ((Get-Both "tw.$($t.Key)") + ' ' + (Get-Both "tw.$($t.Key).d")) (T 'spot.setting') $t.Glyph { param($d) Show-Element 'tweaks' $d } $t.Row
    }
    & $add (T 'tw.dns') ((Get-Both 'tw.dns') + ' cloudflare google 1.1.1.1 8.8.8.8') (T 'spot.setting') ([char]0xE774) { param($d) Show-Element 'tweaks' $d } $dnsRow.Row
    & $add (T 'tw.refresh') ((Get-Both 'tw.refresh') + ' hz') (T 'spot.setting') ([char]0xE7F8) { param($d) Show-Element 'tweaks' $d } $refreshRow.Row
    foreach ($a in $apps) {
        & $add $a.Name (Get-Both "app.desc.$($a.Key)") (T 'spot.app') ([char]0xE7FC) { param($d) if (Test-App $d) { Open-App $d } else { Show-Element 'gaming' $d.RowParts.Row } } $a
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
    & $add (T 'act.lang') (Get-Both 'act.lang') (T 'spot.action') ([char]0xE774) { param($d) Set-AppLanguage $(if ($lang -eq 'th') { 'en' } else { 'th' }) } $null
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
function Update-Spotlight {
    $text = $ui.SpotlightBox.Text.Trim()
    $q = $text.ToLowerInvariant()
    $ui.SpotlightHint.Visibility = if ($text) { 'Collapsed' } else { 'Visible' }
    $ui.SpotlightResults.Children.Clear()
    $script:spotRows = @(); $script:spotList = @()
    if (!$q) { $ui.SpotlightLine.Visibility = 'Collapsed'; return }
    $words = $q -split '\s+'
    $found = @($script:spotItems | Where-Object { $s = $_.Search; !($words | Where-Object { $s -notlike "*$_*" }) })
    # Names that start with the search come first
    $found = @($found | Sort-Object { if ($_.Text.ToLowerInvariant().StartsWith($q)) { 0 } else { 1 } } | Select-Object -First 8)
    $found += @{ Text = (T 'spot.atlas') -f $text; Sub = (T 'tweaks.system'); Glyph = [string][char]0xE721; Data = $text
                 Action = { param($d) $ui.NavTweaks.IsChecked = $true; $ui.SystemSearch.Text = $d } }
    foreach ($item in $found) {
        $row = New-Object System.Windows.Controls.Border
        $row.CornerRadius = 7; $row.Padding = '10,7'; $row.Cursor = 'Hand'; $row.Background = [System.Windows.Media.Brushes]::Transparent
        $dock = New-Object System.Windows.Controls.DockPanel
        $icon = New-Object System.Windows.Controls.Border
        $icon.Width = 26; $icon.Height = 26; $icon.CornerRadius = 6; $icon.SetResourceReference([System.Windows.Controls.Border]::BackgroundProperty, 'Fill'); $icon.Margin = '0,0,12,0'
        $g = New-Text $item.Glyph 13; $g.Style = $window.FindResource('Glyph'); $g.HorizontalAlignment = 'Center'
        $g.SetResourceReference([System.Windows.Controls.TextBlock]::ForegroundProperty, 'Accent2'); $icon.Child = $g
        $sub = New-Text $item.Sub 12; $sub.Opacity = 0.7; $sub.VerticalAlignment = 'Center'
        [System.Windows.Controls.DockPanel]::SetDock($icon, 'Left'); [System.Windows.Controls.DockPanel]::SetDock($sub, 'Right')
        $title = New-Text $item.Text 14; $title.VerticalAlignment = 'Center'; $title.TextWrapping = 'NoWrap'; $title.TextTrimming = 'CharacterEllipsis'
        [void]$dock.Children.Add($icon); [void]$dock.Children.Add($sub); [void]$dock.Children.Add($title)
        $row.Child = $dock
        $row.Tag = $script:spotRows.Count
        $row.Add_MouseEnter({ $script:spotSel = $this.Tag; Update-SpotSelection })
        $row.Add_MouseLeftButtonUp({ Invoke-SpotlightItem $this.Tag })
        [void]$ui.SpotlightResults.Children.Add($row)
        $script:spotRows += $row; $script:spotList += $item
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
$ui.LangButton.Add_Click({ Set-AppLanguage $(if ($lang -eq 'th') { 'en' } else { 'th' }) })
function Update-Language {
    Set-Language
    Show-Disks
    Update-Clock
    Update-Chips
    if ($stats.Top) { Show-TopApps }
    foreach ($a in $apps) { if ($a.State -ne 'install') { Update-AppRow $a } }
    Update-AppsToolbar
    Update-RefreshRow
    Update-TweakHints
    Show-Games
    Request-MenuUpdate
    if ($ui.WhatsNew.Visibility -eq 'Visible') { Show-WhatsNew }
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
$ui.WelcomeApps.Add_Click({ Close-Welcome; $ui.NavGaming.IsChecked = $true })
$ui.WelcomeLook.Add_Click({ Close-Welcome; $ui.NavAppearance.IsChecked = $true })
$ui.WelcomeDone.Add_Click({ Close-Welcome })
# The welcome covers the title bar, so the window can be moved from anywhere on it
$ui.Welcome.Add_MouseLeftButtonDown({ $window.DragMove() })
if (!(Get-RegValue $settingsKey 'Welcomed') -and !$Screenshot) { $ui.Welcome.Visibility = 'Visible' }
if (!$Screenshot) {
    if (!(Get-RegValue $settingsKey 'Welcomed')) { Save-Setting LastVersion $version }
    elseif ((Get-RegValue $settingsKey 'LastVersion') -ne $version) { Show-WhatsNew }
}

# Keyboard: Ctrl+1 to Ctrl+7 switch pages, Ctrl+F searches the AtlasOS settings in Tweaks, Esc closes the welcome or clears the search
$window.Add_PreviewKeyDown({
    param($sender, $e)
    $ctrl = ([System.Windows.Input.Keyboard]::Modifiers -band [System.Windows.Input.ModifierKeys]::Control) -ne 0
    $key = [string]$e.Key
    if ($key -eq 'Escape') {
        if ($ui.Welcome.Visibility -eq 'Visible') { Close-Welcome; $e.Handled = $true }
        elseif ($ui.WhatsNew.Visibility -eq 'Visible') { $ui.WhatsNew.Visibility = 'Collapsed'; Save-Setting LastVersion $version; $e.Handled = $true }
        elseif ($ui.SystemSearch.Text) { $ui.SystemSearch.Text = ''; $e.Handled = $true }
        return
    }
    if (!$ctrl -or $ui.Welcome.Visibility -eq 'Visible') { return }
    if ($key -eq 'K') { Open-Spotlight; $e.Handled = $true; return }
    if ($key -eq 'F') {
        $ui.NavTweaks.IsChecked = $true
        [void]$ui.SystemSearch.Focus(); $ui.SystemSearch.SelectAll()
        $e.Handled = $true
    } elseif ($key -match '^(D|NumPad)([1-7])$') {
        $ui["Nav$(Get-PageId $pages[[int]$Matches[2] - 1])"].IsChecked = $true
        $e.Handled = $true
    }
})

Set-Language
Show-Disks
Update-Clock
Update-Chips
Set-Status (T 'ready')
# Started from the desktop menu: open that page (and start the ping test)
if ($Page -and $pages -contains $Page.ToLowerInvariant()) {
    $ui["Nav$(Get-PageId $Page.ToLowerInvariant())"].IsChecked = $true
    if ($Ping -and $Page -eq 'boost') { $script:pingOn = $true; $script:pingNext = [datetime]::MinValue; Set-PingButton }
}
# The desktop menu is rebuilt each time the window opens (apps, language, task for this user)
Request-MenuUpdate

# ---------------------------------------------------------------------------------------------
# Screenshot mode (CI): render every page in both languages to PNG and exit
# ---------------------------------------------------------------------------------------------
Add-Mark 'Screenshot mode'
if ($Screenshot) {
    Add-Mark 'Ready (before screenshots)'
    Write-Host 'Startup timing:'; $script:marks | ForEach-Object { Write-Host "  $_" }
    New-Item -ItemType Directory -Path $Screenshot -Force | Out-Null
    $stats.Run = $false
    & $statsSample $stats
    Update-Stats
    $rootEl = $window.Content
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
            if ($p -eq 'appearance' -or $p -eq 'tweaks' -or $p -eq 'boost' -or $p -eq 'gaming') {
                # The lower part of long pages
                $sv = $ui["Page$(Get-PageId $p)"]
                if ($p -eq 'tweaks') {
                    # The middle of the page: the Network, Display and Memory sections
                    $sv.UpdateLayout(); $sv.ScrollToVerticalOffset(560); $sv.UpdateLayout()
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
    }
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
        if ([AkatiOS.Native]::LoadCursorFromFile($c.FullName) -eq [IntPtr]::Zero) { Write-Output "Windows cannot load the cursor $($c.Name)"; exit 1 }
        Write-Output "Cursor OK: $($c.Name)"
    }
    Write-Output "Screenshots saved to $Screenshot"
    exit 0
}

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
$timer.Add_Tick({ Update-Stats; Receive-Work; Update-AppProgress; Update-Ping; if ($script:menuAt -and (Get-Date) -gt $script:menuAt) { Update-DesktopMenu } })
$window.Add_ContentRendered({ Close-Splash; $window.Activate() })
$window.Add_Loaded({
    # Akati OS checks GitHub once when the window opens (one request, nothing is downloaded)
    Start-UpdateCheck
    # Icon next to the clock: wanted (setup option or Tweaks) but its sign-in task is missing, as after some
    # setups in AME Wizard: register it again
    if (!$Screenshot -and (Get-RegValue 'HKLM:\SOFTWARE\AkatiOS' 'TrayIcon') -eq 1) {
        Start-Work { param($script)
            if (!(Get-ScheduledTask -TaskPath '\AkatiOS\' -TaskName 'Akati OS tray' -ErrorAction SilentlyContinue)) {
                & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $script -Install
            } } @((Join-Path $appDir 'AkatiTray.ps1'))
    }
    $script:statsHandle = $statsPs.BeginInvoke()
    $timer.Start()
})
$window.Add_Closed({
    Close-Splash
    $stats.Run = $false
    $timer.Stop()
})
[void]$window.ShowDialog()
