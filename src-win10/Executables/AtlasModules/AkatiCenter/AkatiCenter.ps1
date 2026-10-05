<#
.SYNOPSIS
    Akati OS Center: dashboard, gaming apps, tweaks, cleaner, themes and updates for Akati OS.
.DESCRIPTION
    A WPF window written in PowerShell, so every line can be read. It runs on Windows PowerShell 5.1
    (Windows 10 and 11) and needs administrator rights for installs and tweaks.
    -Screenshot <folder> renders every page to PNG and exits (used by CI). -Root points to a source
    "Executables" folder instead of the installed %windir% layout.
#>
param (
    [string]$Screenshot,
    [string]$Root
)

$ErrorActionPreference = 'Stop'
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
        Start-Process powershell.exe -Verb RunAs -WindowStyle Hidden -ArgumentList "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$PSCommandPath`""
    } catch { }
    exit
}

# ---------------------------------------------------------------------------------------------
# Strings (English and Thai)
# ---------------------------------------------------------------------------------------------
$strings = @{
    en = @{
        'admin' = 'Administrator mode'; 'menu' = 'MENU'
        'nav.dashboard' = 'Dashboard'; 'nav.gaming' = 'Gaming apps'; 'nav.tweaks' = 'Tweaks'
        'nav.cleaner' = 'Cleaner'; 'nav.appearance' = 'Appearance'; 'nav.about' = 'About'
        'welcome' = 'Welcome back'; 'version' = 'AKATI OS VERSION'
        'cpu' = 'CPU USAGE'; 'ram' = 'RAM USAGE'; 'gpu' = 'GPU USAGE'
        'quick' = 'Quick actions'
        'quick.clean' = 'Clean temp files'; 'quick.clean.d' = 'Free up disk space'
        'quick.update' = 'Check for updates'; 'quick.update.d' = 'Compare with GitHub'
        'quick.system' = 'System settings'; 'quick.system.d' = 'All other settings'
        'nav.system' = 'System settings'; 'system.title' = 'System settings'
        'system.sub' = 'All AtlasOS settings. A button applies that option; scripts open in a window that explains what they change. (default) marks the Akati OS default.'
        'system.search' = 'Search settings'; 'system.links' = 'Links and tools'
        'system.cat.Software' = 'Software'; 'system.cat.Drivers' = 'Drivers'; 'system.cat.General Configuration' = 'General'
        'system.cat.Interface Tweaks' = 'Interface'; 'system.cat.Windows Settings' = 'Windows Settings'
        'system.cat.Advanced Configuration' = 'Advanced'; 'system.cat.Security' = 'Security'
        'system.cat.Additional Tools' = 'Additional tools'; 'system.cat.Troubleshooting' = 'Troubleshooting'; 'system.cat.AtlasOS' = 'AtlasOS'
        'status.applied' = 'Applied: {0}'; 'status.opened' = 'Opened: {0}'
        'gaming.title' = 'Gaming apps'
        'gaming.sub' = 'Akati OS does not install apps during setup. Install them here, from official sources (WinGet, or the official installer for Steam and Discord).'
        'gpu.title' = 'GPU drivers'; 'gpu.sub' = 'Opens the official driver download page.'
        'tweaks.title' = 'Tweaks'
        'tweaks.sub' = 'Each switch shows the current state of your PC. Turn a tweak off again if games run worse.'
        'cleaner.title' = 'Cleaner'; 'cleaner.sub' = 'Deletes temporary files. Files that are in use are skipped.'
        'cleaner.total' = 'SELECTED'; 'cleaner.scan' = 'Scan'; 'cleaner.clean' = 'Clean now'
        'appearance.title' = 'Appearance'; 'appearance.sub' = 'Pick an Akati OS theme. Windows applies it right away.'
        'links' = 'Links'; 'link.options' = 'Options guide'; 'credits' = 'Credits'
        'credits.text' = 'Akati OS is based on AtlasOS by the Atlas team and is licensed under GPL-3.0. It is not an official AtlasOS project. AME Wizard by Ameliorated.'
        'ready' = 'Ready'
        'installed' = 'Installed'; 'notinstalled' = 'Not installed'; 'install' = 'Install'; 'installing' = 'Installing...'
        'apply' = 'Apply'; 'active' = 'Active'
        'restart' = 'Restart to apply'
        'status.installing' = 'Installing {0}...'; 'status.installed' = '{0} installed'; 'status.notinstalled' = '{0} was not installed. Get it from its official website.'
        'status.tweak' = 'Applying: {0}...'; 'status.tweakdone' = '{0}: done'
        'status.scanning' = 'Scanning...'; 'status.cleaning' = 'Cleaning...'; 'status.cleaned' = 'Freed {0}'
        'status.theme' = 'Theme applied: {0}'
        'status.checking' = 'Checking for updates...'
        'update.latest' = 'You have the latest version ({0}).'
        'update.ahead' = 'Your version is newer than the latest release ({0}): test build.'
        'update.new' = 'New version available: {0}. A new version needs a fresh Windows install.'
        'update.error' = 'Could not reach GitHub.'
        'update.open' = 'Open release page'
        'clean.temp' = 'Temporary files (your account)'; 'clean.wintemp' = 'Windows temporary files'
        'clean.dumps' = 'Crash dumps'; 'clean.recycle' = 'Recycle Bin'
        'tw.hags' = 'Hardware-accelerated GPU scheduling'; 'tw.hags.d' = 'Lets the GPU manage its own memory. Needs a supported GPU and driver.'
        'tw.windowed' = 'Optimizations for windowed games'; 'tw.windowed.d' = 'Lower latency for DirectX 10/11 games in windowed and borderless mode.'
        'tw.gamemode' = 'Game Mode'; 'tw.gamemode.d' = 'Windows gives games priority and pauses some background work while you play.'
        'tw.maxperf' = 'Maximum Performance power plan'; 'tw.maxperf.d' = 'Atlas Power Scheme with power saving off. Best for desktops, uses more battery on laptops.'
        'tw.hibernation' = 'Hibernation'; 'tw.hibernation.d' = 'Off saves disk space. Shut down and restart work normally.'
        'tw.store' = 'Microsoft Store'; 'tw.store.d' = 'Needed by the Xbox app and Game Pass. Installing it again can take a minute.'
        'theme.dark' = 'Akati OS Dark'; 'theme.light' = 'Akati OS Light'; 'theme.slideshow' = 'Akati OS Slideshow'
        'theme.slideshow.d' = 'Wallpaper changes every 30 minutes'
        'lang' = 'ภาษาไทย'
    }
    th = @{
        'admin' = 'โหมดผู้ดูแลระบบ'; 'menu' = 'เมนู'
        'nav.dashboard' = 'แดชบอร์ด'; 'nav.gaming' = 'แอปเกม'; 'nav.tweaks' = 'ปรับแต่ง'
        'nav.cleaner' = 'ล้างไฟล์ขยะ'; 'nav.appearance' = 'ธีม'; 'nav.about' = 'เกี่ยวกับ'
        'welcome' = 'ยินดีต้อนรับ'; 'version' = 'เวอร์ชัน AKATI OS'
        'cpu' = 'การใช้ CPU'; 'ram' = 'การใช้ RAM'; 'gpu' = 'การใช้ GPU'
        'quick' = 'ทางลัด'
        'quick.clean' = 'ล้างไฟล์ชั่วคราว'; 'quick.clean.d' = 'เพิ่มพื้นที่ดิสก์'
        'quick.update' = 'ตรวจอัปเดต'; 'quick.update.d' = 'เทียบกับ GitHub'
        'quick.system' = 'ตั้งค่าระบบ'; 'quick.system.d' = 'การตั้งค่าอื่น ๆ ทั้งหมด'
        'nav.system' = 'ตั้งค่าระบบ'; 'system.title' = 'ตั้งค่าระบบ'
        'system.sub' = 'การตั้งค่าทั้งหมดของ AtlasOS กดปุ่มเพื่อใช้ตัวเลือกนั้น สคริปต์จะเปิดในหน้าต่างที่อธิบายว่าเปลี่ยนอะไร (default) คือค่าเริ่มต้นของ Akati OS ชื่อตัวเลือกเป็นภาษาอังกฤษตาม AtlasOS'
        'system.search' = 'ค้นหาการตั้งค่า'; 'system.links' = 'ลิงก์และเครื่องมือ'
        'system.cat.Software' = 'ซอฟต์แวร์'; 'system.cat.Drivers' = 'ไดรเวอร์'; 'system.cat.General Configuration' = 'ทั่วไป'
        'system.cat.Interface Tweaks' = 'หน้าตา'; 'system.cat.Windows Settings' = 'การตั้งค่า Windows'
        'system.cat.Advanced Configuration' = 'ขั้นสูง'; 'system.cat.Security' = 'ความปลอดภัย'
        'system.cat.Additional Tools' = 'เครื่องมือเพิ่มเติม'; 'system.cat.Troubleshooting' = 'แก้ปัญหา'; 'system.cat.AtlasOS' = 'AtlasOS'
        'status.applied' = 'ใช้แล้ว: {0}'; 'status.opened' = 'เปิดแล้ว: {0}'
        'gaming.title' = 'แอปเกม'
        'gaming.sub' = 'Akati OS ไม่ได้ติดตั้งแอปให้ตอนลง กดติดตั้งได้ที่นี่ โหลดจากแหล่งทางการ (WinGet หรือตัวติดตั้งทางการของ Steam และ Discord)'
        'gpu.title' = 'ไดรเวอร์การ์ดจอ'; 'gpu.sub' = 'เปิดหน้าดาวน์โหลดไดรเวอร์ทางการ'
        'tweaks.title' = 'ปรับแต่ง'
        'tweaks.sub' = 'สวิตช์แสดงสถานะจริงของเครื่อง ถ้าเปิดแล้วเกมแย่ลงให้ปิดกลับ'
        'cleaner.title' = 'ล้างไฟล์ขยะ'; 'cleaner.sub' = 'ลบไฟล์ชั่วคราว ไฟล์ที่กำลังใช้งานอยู่จะถูกข้าม'
        'cleaner.total' = 'ที่เลือกไว้'; 'cleaner.scan' = 'สแกน'; 'cleaner.clean' = 'ล้างเลย'
        'appearance.title' = 'ธีม'; 'appearance.sub' = 'เลือกธีมของ Akati OS แล้ว Windows จะเปลี่ยนให้ทันที'
        'links' = 'ลิงก์'; 'link.options' = 'คู่มือตัวเลือก'; 'credits' = 'เครดิต'
        'credits.text' = 'Akati OS ดัดแปลงจาก AtlasOS ของทีม Atlas ใช้สัญญาอนุญาต GPL-3.0 ไม่ใช่โปรเจกต์ทางการของ AtlasOS ใช้งานผ่าน AME Wizard ของ Ameliorated'
        'ready' = 'พร้อมใช้งาน'
        'installed' = 'ติดตั้งแล้ว'; 'notinstalled' = 'ยังไม่ได้ติดตั้ง'; 'install' = 'ติดตั้ง'; 'installing' = 'กำลังติดตั้ง...'
        'apply' = 'ใช้ธีมนี้'; 'active' = 'ใช้อยู่'
        'restart' = 'รีสตาร์ตเพื่อให้มีผล'
        'status.installing' = 'กำลังติดตั้ง {0}...'; 'status.installed' = 'ติดตั้ง {0} แล้ว'; 'status.notinstalled' = 'ติดตั้ง {0} ไม่สำเร็จ ให้ติดตั้งจากเว็บไซต์ทางการ'
        'status.tweak' = 'กำลังปรับ: {0}...'; 'status.tweakdone' = '{0}: เรียบร้อย'
        'status.scanning' = 'กำลังสแกน...'; 'status.cleaning' = 'กำลังล้าง...'; 'status.cleaned' = 'ล้างได้ {0}'
        'status.theme' = 'เปลี่ยนธีมเป็น {0} แล้ว'
        'status.checking' = 'กำลังตรวจอัปเดต...'
        'update.latest' = 'ใช้เวอร์ชันล่าสุดอยู่แล้ว ({0})'
        'update.ahead' = 'เวอร์ชันในเครื่องใหม่กว่า release ล่าสุด ({0}) เป็นตัวทดสอบ'
        'update.new' = 'มีเวอร์ชันใหม่: {0} ต้องลง Windows ใหม่พร้อมไฟล์ .apbx ตัวใหม่'
        'update.error' = 'เชื่อมต่อ GitHub ไม่ได้'
        'update.open' = 'เปิดหน้า release'
        'clean.temp' = 'ไฟล์ชั่วคราว (บัญชีของคุณ)'; 'clean.wintemp' = 'ไฟล์ชั่วคราวของ Windows'
        'clean.dumps' = 'ไฟล์ crash dump'; 'clean.recycle' = 'ถังขยะ'
        'tw.hags' = 'Hardware-accelerated GPU scheduling'; 'tw.hags.d' = 'ให้การ์ดจอจัดการหน่วยความจำเอง ต้องใช้การ์ดจอและไดรเวอร์ที่รองรับ'
        'tw.windowed' = 'Optimizations for windowed games'; 'tw.windowed.d' = 'ลด latency ของเกม DirectX 10/11 ที่เล่นแบบหน้าต่างหรือ borderless'
        'tw.gamemode' = 'Game Mode'; 'tw.gamemode.d' = 'Windows ให้ความสำคัญกับเกมและพักงานเบื้องหลังบางอย่างระหว่างเล่น'
        'tw.maxperf' = 'Power plan ประสิทธิภาพสูงสุด'; 'tw.maxperf.d' = 'Atlas Power Scheme และปิดการประหยัดพลังงาน เหมาะกับคอมตั้งโต๊ะ โน้ตบุ๊กจะเปลืองแบต'
        'tw.hibernation' = 'Hibernation'; 'tw.hibernation.d' = 'ปิดไว้ช่วยประหยัดพื้นที่ดิสก์ ปิดเครื่องและรีสตาร์ตได้ตามปกติ'
        'tw.store' = 'Microsoft Store'; 'tw.store.d' = 'แอป Xbox และ Game Pass ต้องใช้ การติดตั้งกลับอาจใช้เวลาประมาณ 1 นาที'
        'theme.dark' = 'Akati OS Dark'; 'theme.light' = 'Akati OS Light'; 'theme.slideshow' = 'Akati OS Slideshow'
        'theme.slideshow.d' = 'เปลี่ยน wallpaper ทุก 30 นาที'
        'lang' = 'English'
    }
}

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
    $ui.StatusText.Text = $text
    $ui.StatusDot.Fill = if ($busy) { $window.FindResource('Accent2') } else { $window.FindResource('Good') }
}

# ---------------------------------------------------------------------------------------------
# Background work: runs a script block in another runspace, then calls back on the UI thread
# ---------------------------------------------------------------------------------------------
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
    if ($last -is [psobject]) { $last = $last.psobject.BaseObject }
    return $last
}
function Receive-Work {
    foreach ($job in @($script:jobs)) {
        if ($job.Handle.IsCompleted) {
            $result = $null
            try { $result = $job.PS.EndInvoke($job.Handle) } catch { $result = $null }
            $job.PS.Dispose()
            $script:jobs.Remove($job)
            if ($job.Done) { & $job.Done $result $job.Context }
        }
    }
}

# ---------------------------------------------------------------------------------------------
# Dashboard: system info and live usage
# ---------------------------------------------------------------------------------------------
function Format-Size([double]$bytes) {
    if ($bytes -ge 1GB) { return '{0:N1} GB' -f ($bytes / 1GB) }
    if ($bytes -ge 1MB) { return '{0:N0} MB' -f ($bytes / 1MB) }
    if ($bytes -ge 1KB) { return '{0:N0} KB' -f ($bytes / 1KB) }
    return '0 KB'
}

$akati = Get-ItemProperty -Path 'HKLM:\SOFTWARE\AkatiOS' -ErrorAction SilentlyContinue
$version = if ($akati.Version) { $akati.Version } else { 'v1.3.1' }
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
    $disk = Get-CimInstance Win32_LogicalDisk -Filter "DeviceID='C:'"
    $ui.DiskName.Text = '{0} / {1}' -f (Format-Size $disk.FreeSpace), (Format-Size $disk.Size)
} catch { }

# Usage is read in a background runspace so the window never stutters
$stats = [hashtable]::Synchronized(@{ Cpu = 0; Ram = 0; RamUsed = 0; RamTotal = 0; Gpu = -1; Run = $true })
$statsSample = {
    param($stats)
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
}
$statsWork = "param(`$stats)`n`$sample = {$statsSample}`nwhile (`$stats.Run) { & `$sample `$stats; Start-Sleep -Milliseconds 1500 }"
$statsPs = [PowerShell]::Create()
[void]$statsPs.AddScript($statsWork).AddArgument($stats)

function Update-Stats {
    $ui.CpuValue.Text = "$($stats.Cpu)%"; $ui.CpuBar.Value = $stats.Cpu
    $ui.RamValue.Text = "$($stats.Ram)%"; $ui.RamBar.Value = $stats.Ram
    if ($stats.RamTotal) { $ui.RamDetail.Text = '{0} / {1}' -f (Format-Size $stats.RamUsed), (Format-Size $stats.RamTotal) }
    if ($stats.Gpu -ge 0) { $ui.GpuValue.Text = "$($stats.Gpu)%"; $ui.GpuBar.Value = $stats.Gpu } else { $ui.GpuValue.Text = '-'; $ui.GpuBar.Value = 0 }
}

# ---------------------------------------------------------------------------------------------
# Gaming apps
# ---------------------------------------------------------------------------------------------
$apps = @(
    @{ Key = 'Steam';     Name = 'Steam';               Glyph = [char]0xE7FC; Path = "${env:ProgramFiles(x86)}\Steam\steam.exe" }
    @{ Key = 'Discord';   Name = 'Discord';             Glyph = [char]0xE8BD; Path = "$env:LOCALAPPDATA\Discord\packages\RELEASES" }
    @{ Key = 'Epic';      Name = 'Epic Games Launcher'; Glyph = [char]0xE7FC; Path = "${env:ProgramFiles(x86)}\Epic Games\Launcher" }
    @{ Key = 'EA';        Name = 'EA app';              Glyph = [char]0xE7FC; Path = "$env:ProgramFiles\Electronic Arts\EA Desktop" }
    @{ Key = 'Ubisoft';   Name = 'Ubisoft Connect';     Glyph = [char]0xE7FC; Path = "${env:ProgramFiles(x86)}\Ubisoft\Ubisoft Game Launcher" }
    @{ Key = 'BattleNet'; Name = 'Battle.net';          Glyph = [char]0xE7FC; Path = "$env:ProgramFiles\Battle.net"; Path2 = "${env:ProgramFiles(x86)}\Battle.net" }
    @{ Key = 'OBS';       Name = 'OBS Studio';          Glyph = [char]0xE714; Path = "$env:ProgramFiles\obs-studio" }
)

function New-Text([string]$text, [double]$size = 13, [string]$weight = 'Normal', [string]$tag = $null) {
    $tb = New-Object System.Windows.Controls.TextBlock
    $tb.Text = $text; $tb.FontSize = $size; $tb.FontWeight = $weight; $tb.TextWrapping = 'Wrap'
    if ($tag) { $tb.Tag = $tag }
    return $tb
}

function New-Row([string]$glyph, [string]$title, [string]$titleTag, [System.Windows.UIElement]$right, [string]$subTag) {
    $border = New-Object System.Windows.Controls.Border
    $border.Padding = '14,12'; $border.CornerRadius = 10; $border.Margin = '0,2'
    $grid = New-Object System.Windows.Controls.Grid
    foreach ($w in 'Auto', '*', 'Auto') { $c = New-Object System.Windows.Controls.ColumnDefinition; $c.Width = $w; $grid.ColumnDefinitions.Add($c) }
    $icon = New-Object System.Windows.Controls.Border
    $icon.Width = 38; $icon.Height = 38; $icon.CornerRadius = 10; $icon.Background = '#241C30'; $icon.Margin = '0,0,14,0'
    $g = New-Text $glyph 16; $g.Style = $window.FindResource('Glyph'); $g.HorizontalAlignment = 'Center'; $g.Foreground = $window.FindResource('Accent2')
    $icon.Child = $g
    $text = New-Object System.Windows.Controls.StackPanel
    $text.VerticalAlignment = 'Center'
    $t = New-Text $title 14 'SemiBold' $titleTag
    $s = New-Text '' 12 'Normal' $subTag; $s.Foreground = $window.FindResource('MutedBrush'); $s.Margin = '0,2,12,0'
    [void]$text.Children.Add($t); [void]$text.Children.Add($s)
    [System.Windows.Controls.Grid]::SetColumn($text, 1)
    [System.Windows.Controls.Grid]::SetColumn($right, 2)
    $right.VerticalAlignment = 'Center'
    [void]$grid.Children.Add($icon); [void]$grid.Children.Add($text); [void]$grid.Children.Add($right)
    $border.Child = $grid
    $border.Add_MouseEnter({ $this.Background = '#1C1626' })
    $border.Add_MouseLeave({ $this.Background = $null })
    return @{ Row = $border; Sub = $s }
}

function Test-App($app) {
    if (Test-Path -LiteralPath $app.Path) { return $true }
    if ($app.Path2 -and (Test-Path -LiteralPath $app.Path2)) { return $true }
    return $false
}

function Update-AppRow($app) {
    $installed = Test-App $app
    $app.Sub.Text = if ($installed) { T 'installed' } else { T 'notinstalled' }
    $app.Sub.Foreground = if ($installed) { $window.FindResource('Good') } else { $window.FindResource('MutedBrush') }
    $app.Button.Content = if ($installed) { T 'installed' } else { T 'install' }
    $app.Button.IsEnabled = !$installed
}

foreach ($app in $apps) {
    $btn = New-Object System.Windows.Controls.Button
    $btn.Style = $window.FindResource('Primary'); $btn.MinWidth = 120
    $row = New-Row ([string]$app.Glyph) $app.Name $null $btn $null
    $app.Sub = $row.Sub; $app.Button = $btn
    $btn.Tag = $app
    $btn.Add_Click({
        $a = $this.Tag
        $this.IsEnabled = $false; $this.Content = T 'installing'
        Set-Status ((T 'status.installing') -f $a.Name) $true
        Start-Work {
            param($script, $key)
            Start-Process powershell.exe -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$script`" -App $key" -WindowStyle Hidden -Wait
        } @($gameApps, $a.Key) {
            param($r, $app)
            Update-AppRow $app
            if (Test-App $app) { Set-Status ((T 'status.installed') -f $app.Name) } else { Set-Status ((T 'status.notinstalled') -f $app.Name) }
        } $a
    })
    [void]$ui.AppsList.Children.Add($row.Row)
    Update-AppRow $app
}

$ui.GpuNvidia.Add_Click({ Start-Process 'https://www.nvidia.com/en-us/drivers/' })
$ui.GpuAmd.Add_Click({ Start-Process 'https://www.amd.com/en/support/download/drivers.html' })
$ui.GpuIntel.Add_Click({ Start-Process 'https://www.intel.com/content/www/us/en/download-center/home.html' })

# ---------------------------------------------------------------------------------------------
# Tweaks (each one reads the real state of the PC)
# ---------------------------------------------------------------------------------------------
function Get-RegValue($path, $name) { (Get-ItemProperty -Path $path -Name $name -ErrorAction SilentlyContinue).$name }
function Invoke-AtlasScript([string]$relative, [string]$pattern) {
    $file = Get-ChildItem -Path (Join-Path $desktop $relative) -Filter $pattern -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($file) { Start-Process cmd.exe -ArgumentList "/c `"`"$($file.FullName)`" /silent`"" -WindowStyle Hidden -Wait }
}

$gpuKey = 'HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers'
$dxKey = 'HKCU:\Software\Microsoft\DirectX\UserGpuPreferences'
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
    @{ Key = 'gamemode'; Glyph = [char]0xE7FC
       Get = { (Get-RegValue 'HKCU:\Software\Microsoft\GameBar' 'AutoGameModeEnabled') -ne 0 }
       Set = { param($on)
               if (!(Test-Path 'HKCU:\Software\Microsoft\GameBar')) { New-Item -Path 'HKCU:\Software\Microsoft\GameBar' -Force | Out-Null }
               Set-ItemProperty -Path 'HKCU:\Software\Microsoft\GameBar' -Name AutoGameModeEnabled -Value $(if ($on) { 1 } else { 0 }) -Type DWord -Force } }
    @{ Key = 'maxperf'; Glyph = [char]0xE945; Slow = $true
       Get = { [string](powercfg /getactivescheme) -match '11111111-1111-1111-1111-111111111111' }
       Set = { param($on) if ($on) { Invoke-AtlasScript '3. General Configuration\Power-saving' 'Disable Power-saving*.cmd' } else { Invoke-AtlasScript '3. General Configuration\Power-saving' 'Default Power-saving*.cmd' } } }
    @{ Key = 'store'; Glyph = [char]0xE719; Slow = $true
       Get = { [bool](Get-AppxPackage -Name 'Microsoft.WindowsStore' -ErrorAction SilentlyContinue) } }
    @{ Key = 'hibernation'; Glyph = [char]0xE708; Slow = $true
       Get = { (Get-RegValue 'HKLM:\SYSTEM\CurrentControlSet\Control\Power' 'HibernateEnabled') -eq 1 }
       Set = { param($on) if ($on) { Invoke-AtlasScript '3. General Configuration\Hibernation' 'Enable Hibernation*.cmd' } else { Invoke-AtlasScript '3. General Configuration\Hibernation' 'Disable Hibernation*.cmd' } } }
)

foreach ($tw in $tweaks) {
    if ($tw.Win11 -and $build -lt 22000) { continue }
    $toggle = New-Object System.Windows.Controls.CheckBox
    $toggle.Style = $window.FindResource('Switch')
    $row = New-Row ([string]$tw.Glyph) (T "tw.$($tw.Key)") "t:tw.$($tw.Key)" $toggle "t:tw.$($tw.Key).d"
    $row.Sub.Text = T "tw.$($tw.Key).d"
    $tw.Toggle = $toggle; $tw.Sub = $row.Sub
    try { $toggle.IsChecked = [bool](& $tw.Get) } catch { $toggle.IsEnabled = $false }
    $toggle.Tag = $tw
    $toggle.Add_Click({
        $t = $this.Tag
        $on = [bool]$this.IsChecked
        $name = T "tw.$($t.Key)"
        Set-Status ((T 'status.tweak') -f $name) $true
        $this.IsEnabled = $false
        $context = @{ Tweak = $t; Name = $name }
        $finish = {
            param($r, $ctx)
            $tg = $ctx.Tweak.Toggle
            try { $tg.IsChecked = [bool](& $ctx.Tweak.Get) } catch { }
            $tg.IsEnabled = $true
            $msg = (T 'status.tweakdone') -f $ctx.Name
            if ($ctx.Tweak.Restart) { $msg += ' · ' + (T 'restart') }
            Set-Status $msg
        }
        if ($t.Slow) {
            # Atlas scripts take a few seconds: run them in the background
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
                return
            }
            Start-Work {
                param($desktop, $relative, $pattern)
                $file = Get-ChildItem -Path (Join-Path $desktop $relative) -Filter $pattern -ErrorAction SilentlyContinue | Select-Object -First 1
                if ($file) { Start-Process cmd.exe -ArgumentList "/c `"`"$($file.FullName)`" /silent`"" -WindowStyle Hidden -Wait }
            } $(
                if ($t.Key -eq 'maxperf') { @($desktop, '3. General Configuration\Power-saving', $(if ($on) { 'Disable Power-saving*.cmd' } else { 'Default Power-saving*.cmd' })) }
                else { @($desktop, '3. General Configuration\Hibernation', $(if ($on) { 'Enable Hibernation*.cmd' } else { 'Disable Hibernation*.cmd' })) }
            ) $finish $context
        } else {
            try { & $t.Set $on } catch { }
            & $finish $null $context
        }
    })
    [void]$ui.TweaksList.Children.Add($row.Row)
}

# ---------------------------------------------------------------------------------------------
# Cleaner
# ---------------------------------------------------------------------------------------------
$cleanItems = @(
    @{ Key = 'temp';    Glyph = [char]0xE8B7; Path = $env:TEMP }
    @{ Key = 'wintemp'; Glyph = [char]0xE8B7; Path = (Join-Path $windir 'Temp') }
    @{ Key = 'dumps';   Glyph = [char]0xE7BA; Path = (Join-Path $env:LOCALAPPDATA 'CrashDumps') }
    @{ Key = 'recycle'; Glyph = [char]0xE74D; Path = $null }
)
foreach ($ci in $cleanItems) {
    $right = New-Object System.Windows.Controls.StackPanel
    $right.Orientation = 'Horizontal'
    $size = New-Text '-' 13 'SemiBold'; $size.Margin = '0,0,18,0'; $size.VerticalAlignment = 'Center'; $size.MinWidth = 70; $size.TextAlignment = 'Right'
    $check = New-Object System.Windows.Controls.CheckBox
    $check.Style = $window.FindResource('Tick'); $check.IsChecked = $true; $check.VerticalAlignment = 'Center'
    $check.Add_Click({ Update-CleanTotal })
    [void]$right.Children.Add($size); [void]$right.Children.Add($check)
    $row = New-Row ([string]$ci.Glyph) (T "clean.$($ci.Key)") "t:clean.$($ci.Key)" $right $null
    $row.Sub.Text = if ($ci.Path) { $ci.Path } else { '' }
    $ci.SizeText = $size; $ci.Check = $check; $ci.Bytes = 0
    [void]$ui.CleanList.Children.Add($row.Row)
}

function Update-CleanTotal {
    $total = 0
    foreach ($ci in $cleanItems) { if ($ci.Check.IsChecked) { $total += $ci.Bytes } }
    $ui.CleanTotal.Text = Format-Size $total
}

$measureWork = {
    param($items)
    $out = @{}
    foreach ($i in $items) {
        if ($i.Path) {
            $sum = (Get-ChildItem -LiteralPath $i.Path -Recurse -Force -File -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum).Sum
        } else {
            $sum = 0
            try { (New-Object -ComObject Shell.Application).NameSpace(10).Items() | ForEach-Object { $sum += $_.Size } } catch { }
        }
        $out[$i.Key] = [double]$sum
    }
    $out
}

function Start-Scan([scriptblock]$then) {
    Set-Status (T 'status.scanning') $true
    $ui.ScanButton.IsEnabled = $false; $ui.CleanButton.IsEnabled = $false
    $items = @($cleanItems | ForEach-Object { @{ Key = $_.Key; Path = $_.Path } })
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
    $selected = @($cleanItems | Where-Object { $_.Check.IsChecked } | ForEach-Object { $script:cleanBefore += $_.Bytes; @{ Key = $_.Key; Path = $_.Path } })
    if (!$selected.Count) { return }
    Set-Status (T 'status.cleaning') $true
    $ui.ScanButton.IsEnabled = $false; $ui.CleanButton.IsEnabled = $false
    Start-Work {
        param($items)
        foreach ($i in $items) {
            if ($i.Path) {
                Get-ChildItem -LiteralPath $i.Path -Force -ErrorAction SilentlyContinue | Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
            } else {
                try { Clear-RecycleBin -Force -ErrorAction SilentlyContinue } catch { }
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
$themes = @(
    @{ Key = 'dark';      File = 'akatios-dark.theme';      Image = 'akatios-dark.png' }
    @{ Key = 'light';     File = 'akatios-light.theme';     Image = 'akatios-light.png' }
    @{ Key = 'slideshow'; File = 'akatios-slideshow.theme'; Image = 'akatios-lockscreen.png' }
)

function Update-ThemeCards {
    $current = [string](Get-RegValue 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes' 'CurrentTheme')
    foreach ($th in $themes) {
        $active = $current -like "*$($th.File)"
        $th.Card.BorderBrush = if ($active) { $window.FindResource('Accent2') } else { $window.FindResource('CardBorder') }
        $th.Button.Content = if ($active) { T 'active' } else { T 'apply' }
    }
}

foreach ($th in $themes) {
    $card = New-Object System.Windows.Controls.Border
    $card.Style = $window.FindResource('Card'); $card.Margin = '8,0'; $card.Padding = '12'; $card.BorderThickness = 2
    $stack = New-Object System.Windows.Controls.StackPanel
    $preview = New-Object System.Windows.Controls.Border
    $preview.CornerRadius = 8; $preview.Height = 130; $preview.ClipToBounds = $true; $preview.Background = '#241C30'
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

# ---------------------------------------------------------------------------------------------
# Updates and links
# ---------------------------------------------------------------------------------------------
$script:releaseUrl = "https://github.com/$repo/releases"
function Start-UpdateCheck {
    Set-Status (T 'status.checking') $true
    $ui.UpdateButton.IsEnabled = $false
    Start-Work {
        param($repo)
        try {
            [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
            Invoke-RestMethod -Uri "https://api.github.com/repos/$repo/releases/latest" -Headers @{ 'User-Agent' = 'AkatiOS-Center' } -TimeoutSec 20
        } catch { $null }
    } @($repo) {
        param($r, $ctx)
        $ui.UpdateButton.IsEnabled = $true
        $release = Get-LastOutput $r
        if (!$release -or !$release.tag_name) {
            $ui.UpdateStatus.Text = T 'update.error'; $ui.UpdateHint.Text = ''
            Set-Status (T 'update.error'); return
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
        Set-Status $msg
    }
}
$ui.UpdateButton.Add_Click({ if ($this.Tag -eq 'open') { Start-Process $script:releaseUrl } else { Start-UpdateCheck } })
$ui.QuickUpdate.Add_Click({ $ui.NavAbout.IsChecked = $true; Start-UpdateCheck })
$ui.QuickAtlas.Add_Click({ $ui.NavSystem.IsChecked = $true })
$ui.LinkGithub.Add_Click({ Start-Process "https://github.com/$repo" })
$ui.LinkOptions.Add_Click({ Start-Process "https://github.com/$repo/blob/main/docs/OPTIONS.md" })
$ui.LinkAtlas.Add_Click({ Start-Process 'https://github.com/Atlas-OS/Atlas' })

# ---------------------------------------------------------------------------------------------
# System settings: every setting of the AtlasOS folder (AtlasDesktop), built from its folders, so
# nothing has to be copied and new AtlasOS settings show up by themselves. A folder with files is one
# row, each file is one button.
# ---------------------------------------------------------------------------------------------
function Invoke-AtlasItem([IO.FileInfo]$file) {
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

$script:systemCards = New-Object System.Collections.ArrayList
function Add-SystemCard([string]$key, [string]$title, [System.IO.DirectoryInfo[]]$dirs, [string]$topPath) {
    $card = New-Object System.Windows.Controls.Border
    $card.Style = $window.FindResource('Card'); $card.Margin = '0,0,0,16'
    $stack = New-Object System.Windows.Controls.StackPanel
    $head = New-Text $title 16 'SemiBold' "t:system.cat.$key"
    $head.Text = T "system.cat.$key"; $head.Margin = '0,0,0,6'
    [void]$stack.Children.Add($head)
    $rows = New-Object System.Collections.ArrayList
    foreach ($d in $dirs) {
        $files = @(Get-ChildItem -LiteralPath $d.FullName -File -ErrorAction SilentlyContinue | Where-Object { $_.Extension -ne '.xml' } | Sort-Object Name)
        if ($files.Count -eq 0) { continue }
        $row = New-Object System.Windows.Controls.Border
        $row.Padding = '10,8'; $row.CornerRadius = 8; $row.Margin = '-10,2'
        $rowStack = New-Object System.Windows.Controls.StackPanel
        if ($d.FullName -eq $topPath) {
            $label = New-Text (T 'system.links') 13 'SemiBold' 't:system.links'
            $rel = ''
        } else {
            $rel = $d.FullName.Substring($topPath.Length + 1).Replace('\', ' > ')
            $label = New-Text $rel 13 'SemiBold'
        }
        $label.Foreground = $window.FindResource('Accent2')
        [void]$rowStack.Children.Add($label)
        $wrap = New-Object System.Windows.Controls.WrapPanel
        foreach ($f in $files) {
            $btn = New-Object System.Windows.Controls.Button
            $btn.Style = $window.FindResource('Secondary'); $btn.Margin = '0,6,8,0'
            $btn.Content = $f.BaseName; $btn.ToolTip = $f.Name; $btn.Tag = $f
            $btn.Add_Click({ Invoke-AtlasItem $this.Tag })
            [void]$wrap.Children.Add($btn)
        }
        [void]$rowStack.Children.Add($wrap)
        $row.Child = $rowStack
        $row.Add_MouseEnter({ $this.Background = '#1C1626' })
        $row.Add_MouseLeave({ $this.Background = $null })
        $row.Tag = ("$title $key $rel " + (($files | ForEach-Object { $_.BaseName }) -join ' ')).ToLowerInvariant()
        [void]$stack.Children.Add($row)
        [void]$rows.Add($row)
    }
    if ($rows.Count -eq 0) { return }
    $card.Child = $stack
    [void]$ui.SystemList.Children.Add($card)
    [void]$script:systemCards.Add(@{ Card = $card; Rows = $rows })
}

if (Test-Path -LiteralPath $desktop) {
    foreach ($top in Get-ChildItem -LiteralPath $desktop -Directory | Sort-Object Name) {
        $key = $top.Name -replace '^\d+\.\s*', ''
        $dirs = @($top) + @(Get-ChildItem -LiteralPath $top.FullName -Directory -Recurse | Sort-Object FullName)
        Add-SystemCard $key $key $dirs $top.FullName
    }
    # Files directly in the folder: AtlasOS links (and the Atlas Toolbox installer on Windows 11)
    Add-SystemCard 'AtlasOS' 'AtlasOS' @(Get-Item -LiteralPath $desktop) (Get-Item -LiteralPath $desktop).FullName
}

$ui.SystemSearch.Add_TextChanged({
    $q = $this.Text.Trim().ToLowerInvariant()
    $ui.SystemSearchHint.Visibility = if ($q) { 'Collapsed' } else { 'Visible' }
    foreach ($c in $script:systemCards) {
        $shown = 0
        foreach ($r in $c.Rows) {
            $match = !$q -or $r.Tag.Contains($q)
            $r.Visibility = if ($match) { 'Visible' } else { 'Collapsed' }
            if ($match) { $shown++ }
        }
        $c.Card.Visibility = if ($shown) { 'Visible' } else { 'Collapsed' }
    }
})

# ---------------------------------------------------------------------------------------------
# Navigation, title bar, language
# ---------------------------------------------------------------------------------------------
$pages = 'dashboard', 'gaming', 'tweaks', 'cleaner', 'appearance', 'system', 'about'
$script:page = 'dashboard'
function Show-Page([string]$name) {
    $script:page = $name
    foreach ($p in $pages) {
        $id = [Globalization.CultureInfo]::InvariantCulture.TextInfo.ToTitleCase($p)
        $ui["Page$id"].Visibility = if ($p -eq $name) { 'Visible' } else { 'Collapsed' }
    }
    $ui.PageTitle.Text = T "nav.$name"
    if ($name -eq 'cleaner' -and $ui.CleanTotal.Text -eq '-') { Start-Scan }
}
foreach ($p in $pages) {
    $id = [Globalization.CultureInfo]::InvariantCulture.TextInfo.ToTitleCase($p)
    $ui["Nav$id"].Add_Checked({ Show-Page $this.Name.Substring(3).ToLowerInvariant() })
}

$ui.TitleBar.Add_MouseLeftButtonDown({ $window.DragMove() })
$ui.MinButton.Add_Click({ $window.WindowState = 'Minimized' })
$ui.CloseButton.Add_Click({ $window.Close() })
$ui.LangButton.Add_Click({
    $script:lang = if ($lang -eq 'th') { 'en' } else { 'th' }
    try {
        if (!(Test-Path $settingsKey)) { New-Item -Path $settingsKey -Force | Out-Null }
        Set-ItemProperty -Path $settingsKey -Name Language -Value $lang -Force
    } catch { }
    Update-Language
})
function Update-Language {
    Set-Language
    foreach ($a in $apps) { Update-AppRow $a }
    Update-ThemeCards
}

Set-Language
Set-Status (T 'ready')

# ---------------------------------------------------------------------------------------------
# Screenshot mode (CI): render every page in both languages to PNG and exit
# ---------------------------------------------------------------------------------------------
if ($Screenshot) {
    New-Item -ItemType Directory -Path $Screenshot -Force | Out-Null
    $stats.Run = $false
    & $statsSample $stats
    Update-Stats
    $rootEl = $window.Content
    foreach ($l in 'en', 'th') {
        $script:lang = $l
        foreach ($p in $pages) {
            $id = [Globalization.CultureInfo]::InvariantCulture.TextInfo.ToTitleCase($p)
            $ui["Nav$id"].IsChecked = $true
            Show-Page $p
            Update-Language
            if ($p -eq 'cleaner') { $ui.CleanTotal.Text = '0 KB' }
            $size = New-Object System.Windows.Size $window.Width, $window.Height
            $rootEl.Measure($size)
            $rootEl.Arrange((New-Object System.Windows.Rect $size))
            $rootEl.UpdateLayout()
            $bmp = New-Object System.Windows.Media.Imaging.RenderTargetBitmap ([int]$window.Width), ([int]$window.Height), 96, 96, ([System.Windows.Media.PixelFormats]::Pbgra32)
            $bmp.Render($rootEl)
            $enc = New-Object System.Windows.Media.Imaging.PngBitmapEncoder
            $enc.Frames.Add([System.Windows.Media.Imaging.BitmapFrame]::Create($bmp))
            $fs = [IO.File]::Create((Join-Path $Screenshot "$p-$l.png"))
            $enc.Save($fs); $fs.Close()
        }
    }
    Write-Output "Screenshots saved to $Screenshot"
    exit 0
}

# ---------------------------------------------------------------------------------------------
# Run
# ---------------------------------------------------------------------------------------------
$timer = New-Object System.Windows.Threading.DispatcherTimer
$timer.Interval = [TimeSpan]::FromMilliseconds(500)
$timer.Add_Tick({ Update-Stats; Receive-Work })
$window.Add_Loaded({
    $script:statsHandle = $statsPs.BeginInvoke()
    $timer.Start()
})
$window.Add_Closed({
    $stats.Run = $false
    $timer.Stop()
})
[void]$window.ShowDialog()
