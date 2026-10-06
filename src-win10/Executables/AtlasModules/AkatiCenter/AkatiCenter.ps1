<#
.SYNOPSIS
    Akati OS Center: dashboard, gaming apps, game boost, tweaks, cleaner, themes, system settings and updates.
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
        'greet.morning' = 'Good morning'; 'greet.afternoon' = 'Good afternoon'; 'greet.evening' = 'Good evening'; 'greet.night' = 'Good night'
        'update.checking' = 'Checking for updates...'
        'chip.boost.on' = 'Game boost on'; 'chip.boost.off' = 'Game boost off'; 'chip.power' = 'Power: {0}'; 'chip.days' = '{0}d {1}h'; 'chip.hours' = '{0}h {1}m'
        'chip.defender.on' = 'Defender on'; 'chip.defender.off' = 'Defender off'; 'chip.uptime' = 'Up {0}'
        'disk.title' = 'Storage'; 'disk.free' = '{0} free of {1}'; 'disk.local' = 'Local Disk'
        'net.title' = 'Network'; 'net.down' = 'DOWNLOAD'; 'net.up' = 'UPLOAD'; 'net.ping' = 'PING (SG)'
        'top.title' = 'Using the most CPU'; 'top.end' = 'Quit'; 'top.confirm' = 'Quit {0}? Unsaved work in it is lost.'
        'status.ended' = '{0} was closed'
        'quick.boost' = 'Game boost'; 'quick.boost.d' = 'Start or stop it here'
        'quick.clean' = 'Clean temp files'; 'quick.clean.d' = 'Free up disk space'
        'quick.update' = 'Check for updates'; 'quick.update.d' = 'Compare with GitHub'
        'quick.system' = 'Tweaks'; 'quick.system.d' = 'Gaming and AtlasOS settings'
        'tweaks.gaming' = 'Gaming'; 'tweaks.system' = 'System (AtlasOS)'
        'nav.system' = 'System settings'; 'system.title' = 'System settings'
        'system.sub' = 'All AtlasOS settings. A button applies that option; scripts open in a window that explains what they change. The default badge marks the Akati OS default.'
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
        'tweaks.sub' = 'Gaming switches show the current state of your PC; turn one off again if games run worse. Below are all AtlasOS settings.'
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
        'clean.dumps' = 'Crash dumps and error reports'; 'clean.recycle' = 'Recycle Bin'
        'clean.update' = 'Windows Update downloads'; 'clean.logs' = 'Windows setup logs'; 'clean.thumbs' = 'Thumbnail cache'
        'clean.apps' = 'Discord, Steam and Epic caches'; 'clean.browser' = 'Browser caches'; 'clean.shaders' = 'GPU shader caches'
        'clean.temp.d' = 'Files apps leave in your Temp folder'; 'clean.wintemp.d' = 'C:\Windows\Temp'
        'clean.update.d' = 'Update files that are already installed (Windows downloads them again if needed)'
        'clean.dumps.d' = 'Crash dumps and Windows Error Reporting files'; 'clean.logs.d' = 'CBS, DISM and setup logs'
        'clean.thumbs.d' = 'Picture previews in File Explorer, made again when needed'
        'clean.apps.d' = 'Web caches only; your logins and settings stay'
        'clean.browser.d' = 'Brave, Edge, Chrome and Firefox. No cookies or passwords. Pages load slower once'
        'clean.shaders.d' = 'NVIDIA, AMD, Intel and DirectX. Games stutter once while they build them again'
        'clean.recycle.d' = 'Deleted files in the Recycle Bin'
        'tw.hags' = 'Hardware-accelerated GPU scheduling'; 'tw.hags.d' = 'Lets the GPU manage its own memory. Needs a supported GPU and driver.'
        'tw.windowed' = 'Optimizations for windowed games'; 'tw.windowed.d' = 'Lower latency for DirectX 10/11 games in windowed and borderless mode.'
        'tw.gamemode' = 'Game Mode'; 'tw.gamemode.d' = 'Windows gives games priority and pauses some background work while you play.'
        'tw.maxperf' = 'Maximum Performance power plan'; 'tw.maxperf.d' = 'Atlas Power Scheme with power saving off. Best for desktops, uses more battery on laptops.'
        'tw.hibernation' = 'Hibernation'; 'tw.hibernation.d' = 'Off saves disk space. Shut down and restart work normally.'
        'tw.store' = 'Microsoft Store'; 'tw.store.d' = 'Needed by the Xbox app and Game Pass. Installing it again can take a minute.'
        'theme.dark' = 'Akati OS Dark'; 'theme.light' = 'Akati OS Light'; 'theme.slideshow' = 'Akati OS Slideshow'
        'theme.slideshow.d' = 'Wallpaper changes every 30 minutes'
        'nav.boost' = 'Game boost'
        'cancel' = 'Cancel'; 'cancelling' = 'Cancelling...'; 'queued' = 'Waiting in the queue'; 'preparing' = 'Starting...'
        'update' = 'Update'; 'updating' = 'Updating...'; 'updateavailable' = 'Update available'; 'selfupdate' = 'updates itself'
        'apps.check' = 'Check for updates'; 'apps.updateall' = 'Update all'; 'apps.installselected' = 'Install selected'
        'apps.hint' = 'Tick apps to install several at once. They install one after another.'
        'stage.winget' = 'Installing with WinGet...'; 'stage.download' = 'Downloading'; 'stage.install' = 'Installing...'
        'stage.user' = 'Installing for your account...'; 'stage.finish' = 'Finishing...'
        'status.cancelled' = '{0}: cancelled'; 'status.updating' = 'Updating {0}...'; 'status.updated' = '{0} updated'
        'status.updatefailed' = '{0} could not be updated'; 'status.checkingapps' = 'Checking WinGet for app updates...'
        'status.updatesfound' = '{0} update(s) available'; 'status.noupdates' = 'All apps are up to date'
        'status.nowinget' = 'WinGet is not installed'
        'gpu.detected' = 'Found in this PC: {0}'; 'gpu.none' = 'No NVIDIA, AMD or Intel graphics card found (virtual machine?).'
        'boost.title' = 'Game boost'
        'boost.sub' = 'One click before you play. Stop puts everything back the way it was, also after a restart.'
        'boost.mode' = 'Game Mode'; 'boost.off' = 'Off'; 'boost.on' = 'On since {0}'; 'boost.start' = 'Start'; 'boost.stop' = 'Stop'
        'boost.power' = 'Switch to the highest performance power plan'
        'boost.apps' = 'Close background apps'; 'boost.noapps' = 'none running now'
        'boost.notify' = 'Turn off notifications'
        'status.booston' = 'Game boost is on. Have fun!'; 'status.boostoff' = 'Game boost is off, your settings are back'
        'ping.title' = 'Ping to game servers'
        'ping.sub' = 'Connection time to the cloud data centers where many games run their Asian servers. Lower is better: under 60 ms is great.'
        'ping.start' = 'Start test'; 'ping.stop' = 'Stop'; 'ping.timeout' = 'no reply'
        'ping.bkk' = 'Thailand (Bangkok)'; 'ping.sin' = 'Singapore'; 'ping.hkg' = 'Hong Kong'; 'ping.tyo' = 'Japan (Tokyo)'
        'startup.title' = 'Startup apps'
        'startup.sub' = 'Apps that start when you sign in. Fewer apps means a faster start and more free RAM for games.'
        'startup.empty' = 'No startup apps.'
        'status.startupon' = '{0} starts with Windows'; 'status.startupoff' = '{0} no longer starts with Windows'
        'system.default' = 'default'
        'restore.title' = 'Create a restore point first'; 'restore.open' = 'System Restore'
        'restore.sub' = 'Once, before the first change you make here. Needs System Restore to be on.'
        'status.restoring' = 'Creating a restore point...'
        'status.restore.made' = 'Restore point created'
        'status.restore.recent' = 'No new restore point: Windows made one less than 24 hours ago'
        'status.restore.off' = 'No restore point: System Restore is off. Turn it on with the System Restore button (Configure > Turn on system protection).'
        'status.boostpartial' = 'Game boost is on, but these steps failed: {0}'
        'status.sound.play' = 'Playing: {0}'
        'report.title' = 'Report a problem'
        'report.sub' = 'Saves one .zip on your desktop with the Akati OS logs and PC details. No personal files; your user name and PC name are removed. Attach it to a GitHub issue.'
        'report.button' = 'Create problem report'; 'report.issues' = 'GitHub issues'
        'status.report' = 'Creating the problem report...'; 'status.reportdone' = 'Saved on your desktop: {0}'; 'status.reportfailed' = 'Could not create the report'
        'accent.title' = 'Accent color'
        'accent.sub' = 'Used by Akati OS Center, the Windows accent color (highlights, buttons and links; Start and taskbar only when "Show accent color" is on in Settings) and the Akati OS Terminal colors.'
        'accent.purple' = 'Purple'; 'accent.blue' = 'Blue'; 'accent.cyan' = 'Cyan'; 'accent.green' = 'Green'
        'accent.pink' = 'Pink'; 'accent.red' = 'Red'; 'accent.orange' = 'Orange'
        'status.accent' = 'Accent color: {0}. Some parts of Windows change after you sign in again.'
        'wall.title' = 'Wallpapers'; 'wall.sub' = 'Click a picture to use it as your desktop background.'
        'status.wallpaper' = 'Wallpaper: {0}'
        'style.title' = 'Cursor and sounds'
        'style.sub' = 'The Akati OS pointer and system sounds. You can go back to the Windows ones at any time.'
        'style.cursor' = 'Cursor'; 'style.sounds' = 'Sounds'; 'style.akati' = 'Akati OS'; 'style.windows' = 'Windows'
        'style.nosound' = 'No sounds'; 'style.preview' = 'Play'
        'status.cursor.akati' = 'Akati OS cursor is on'; 'status.cursor.windows' = 'Windows cursor is back'
        'status.sound.akati' = 'Akati OS sounds are on'; 'status.sound.windows' = 'Windows sounds are on'; 'status.sound.none' = 'Sounds are off'
        'welcome.title' = 'Welcome to Akati OS'; 'welcome.sub' = 'Three quick steps. You can change everything later.'
        'welcome.lang' = 'Language'; 'welcome.apps' = 'Install your gaming apps'; 'welcome.apps.d' = 'Steam, Discord, Epic and more'
        'welcome.look' = 'Pick a theme and accent color'; 'welcome.look.d' = 'Dark, light, slideshow and 7 colors'
        'welcome.open' = 'Open'; 'welcome.done' = 'Get started'
        'welcome.keys' = 'Tip: Ctrl+1 to Ctrl+7 switch pages, Ctrl+F searches the settings.'
        'lang' = 'ภาษาไทย'
    }
    th = @{
        'admin' = 'โหมดผู้ดูแลระบบ'; 'menu' = 'เมนู'
        'nav.dashboard' = 'แดชบอร์ด'; 'nav.gaming' = 'แอปเกม'; 'nav.tweaks' = 'ปรับแต่ง'
        'nav.cleaner' = 'ล้างไฟล์ขยะ'; 'nav.appearance' = 'ธีม'; 'nav.about' = 'เกี่ยวกับ'
        'welcome' = 'ยินดีต้อนรับ'; 'version' = 'เวอร์ชัน AKATI OS'
        'cpu' = 'การใช้ CPU'; 'ram' = 'การใช้ RAM'; 'gpu' = 'การใช้ GPU'
        'quick' = 'ทางลัด'
        'greet.morning' = 'สวัสดีตอนเช้า'; 'greet.afternoon' = 'สวัสดีตอนบ่าย'; 'greet.evening' = 'สวัสดีตอนเย็น'; 'greet.night' = 'สวัสดีตอนค่ำ'
        'update.checking' = 'กำลังตรวจอัปเดต...'
        'chip.boost.on' = 'บูสต์เกมเปิดอยู่'; 'chip.boost.off' = 'บูสต์เกมปิดอยู่'; 'chip.power' = 'แผนพลังงาน: {0}'; 'chip.days' = '{0} วัน {1} ชม.'; 'chip.hours' = '{0} ชม. {1} นาที'
        'chip.defender.on' = 'Defender เปิดอยู่'; 'chip.defender.off' = 'Defender ปิดอยู่'; 'chip.uptime' = 'เปิดเครื่องมา {0}'
        'disk.title' = 'พื้นที่เก็บข้อมูล'; 'disk.free' = 'ว่าง {0} จาก {1}'; 'disk.local' = 'ดิสก์ในเครื่อง'
        'net.title' = 'เครือข่าย'; 'net.down' = 'ดาวน์โหลด'; 'net.up' = 'อัปโหลด'; 'net.ping' = 'ปิง (สิงคโปร์)'
        'top.title' = 'แอปที่ใช้ CPU มากที่สุด'; 'top.end' = 'ปิด'; 'top.confirm' = 'ปิด {0} ใช่ไหม งานที่ยังไม่ได้บันทึกในแอปนี้จะหายไป'
        'status.ended' = 'ปิด {0} แล้ว'
        'quick.boost' = 'บูสต์เกม'; 'quick.boost.d' = 'เปิดหรือปิดได้ที่นี่'
        'quick.clean' = 'ล้างไฟล์ชั่วคราว'; 'quick.clean.d' = 'เพิ่มพื้นที่ดิสก์'
        'quick.update' = 'ตรวจอัปเดต'; 'quick.update.d' = 'เทียบกับ GitHub'
        'quick.system' = 'ปรับแต่ง'; 'quick.system.d' = 'เกมและการตั้งค่า AtlasOS'
        'tweaks.gaming' = 'เกม'; 'tweaks.system' = 'ระบบ (AtlasOS)'
        'nav.system' = 'ตั้งค่าระบบ'; 'system.title' = 'ตั้งค่าระบบ'
        'system.sub' = 'การตั้งค่าทั้งหมดของ AtlasOS กดปุ่มเพื่อใช้ตัวเลือกนั้น สคริปต์จะเปิดในหน้าต่างที่อธิบายว่าเปลี่ยนอะไร ป้าย ค่าเริ่มต้น คือค่าที่ Akati OS ใช้ หน้าต่างของสคริปต์เป็นภาษาอังกฤษตาม AtlasOS'
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
        'tweaks.sub' = 'สวิตช์เกมแสดงสถานะจริงของเครื่อง ถ้าเปิดแล้วเกมแย่ลงให้ปิดกลับ ด้านล่างคือการตั้งค่าทั้งหมดของ AtlasOS'
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
        'clean.dumps' = 'Crash dump และรายงานข้อผิดพลาด'; 'clean.recycle' = 'ถังขยะ'
        'clean.update' = 'ไฟล์ดาวน์โหลดของ Windows Update'; 'clean.logs' = 'Log การติดตั้งของ Windows'; 'clean.thumbs' = 'แคชภาพย่อ'
        'clean.apps' = 'แคชของ Discord, Steam และ Epic'; 'clean.browser' = 'แคชเบราว์เซอร์'; 'clean.shaders' = 'แคช shader ของการ์ดจอ'
        'clean.temp.d' = 'ไฟล์ที่แอปทิ้งไว้ในโฟลเดอร์ Temp'; 'clean.wintemp.d' = 'C:\Windows\Temp'
        'clean.update.d' = 'ไฟล์อัปเดตที่ติดตั้งไปแล้ว (Windows โหลดใหม่เองถ้าต้องใช้)'
        'clean.dumps.d' = 'Crash dump และไฟล์ Windows Error Reporting'; 'clean.logs.d' = 'Log ของ CBS, DISM และการติดตั้ง'
        'clean.thumbs.d' = 'ภาพตัวอย่างใน File Explorer สร้างใหม่เองเมื่อเปิดดู'
        'clean.apps.d' = 'เฉพาะแคชเว็บ การล็อกอินและการตั้งค่ายังอยู่'
        'clean.browser.d' = 'Brave, Edge, Chrome และ Firefox ไม่ลบคุกกี้หรือรหัสผ่าน หน้าเว็บโหลดช้าลงครั้งแรก'
        'clean.shaders.d' = 'NVIDIA, AMD, Intel และ DirectX เกมจะกระตุกครั้งแรกระหว่างสร้างใหม่'
        'clean.recycle.d' = 'ไฟล์ที่ลบไว้ในถังขยะ'
        'tw.hags' = 'Hardware-accelerated GPU scheduling'; 'tw.hags.d' = 'ให้การ์ดจอจัดการหน่วยความจำเอง ต้องใช้การ์ดจอและไดรเวอร์ที่รองรับ'
        'tw.windowed' = 'Optimizations for windowed games'; 'tw.windowed.d' = 'ลด latency ของเกม DirectX 10/11 ที่เล่นแบบหน้าต่างหรือ borderless'
        'tw.gamemode' = 'Game Mode'; 'tw.gamemode.d' = 'Windows ให้ความสำคัญกับเกมและพักงานเบื้องหลังบางอย่างระหว่างเล่น'
        'tw.maxperf' = 'Power plan ประสิทธิภาพสูงสุด'; 'tw.maxperf.d' = 'Atlas Power Scheme และปิดการประหยัดพลังงาน เหมาะกับคอมตั้งโต๊ะ โน้ตบุ๊กจะเปลืองแบต'
        'tw.hibernation' = 'Hibernation'; 'tw.hibernation.d' = 'ปิดไว้ช่วยประหยัดพื้นที่ดิสก์ ปิดเครื่องและรีสตาร์ตได้ตามปกติ'
        'tw.store' = 'Microsoft Store'; 'tw.store.d' = 'แอป Xbox และ Game Pass ต้องใช้ การติดตั้งกลับอาจใช้เวลาประมาณ 1 นาที'
        'theme.dark' = 'Akati OS Dark'; 'theme.light' = 'Akati OS Light'; 'theme.slideshow' = 'Akati OS Slideshow'
        'theme.slideshow.d' = 'เปลี่ยน wallpaper ทุก 30 นาที'
        'nav.boost' = 'บูสต์เกม'
        'cancel' = 'ยกเลิก'; 'cancelling' = 'กำลังยกเลิก...'; 'queued' = 'รอคิว'; 'preparing' = 'กำลังเริ่ม...'
        'update' = 'อัปเดต'; 'updating' = 'กำลังอัปเดต...'; 'updateavailable' = 'มีอัปเดต'; 'selfupdate' = 'อัปเดตตัวเอง'
        'apps.check' = 'ตรวจอัปเดต'; 'apps.updateall' = 'อัปเดตทั้งหมด'; 'apps.installselected' = 'ติดตั้งที่เลือก'
        'apps.hint' = 'ติ๊กหลายแอปเพื่อติดตั้งทีเดียว ระบบจะติดตั้งให้ทีละตัว'
        'stage.winget' = 'กำลังติดตั้งด้วย WinGet...'; 'stage.download' = 'กำลังดาวน์โหลด'; 'stage.install' = 'กำลังติดตั้ง...'
        'stage.user' = 'กำลังติดตั้งให้บัญชีของคุณ...'; 'stage.finish' = 'กำลังจบการติดตั้ง...'
        'status.cancelled' = '{0}: ยกเลิกแล้ว'; 'status.updating' = 'กำลังอัปเดต {0}...'; 'status.updated' = 'อัปเดต {0} แล้ว'
        'status.updatefailed' = 'อัปเดต {0} ไม่สำเร็จ'; 'status.checkingapps' = 'กำลังตรวจอัปเดตแอปจาก WinGet...'
        'status.updatesfound' = 'มีอัปเดต {0} รายการ'; 'status.noupdates' = 'แอปทั้งหมดเป็นเวอร์ชันล่าสุด'
        'status.nowinget' = 'ไม่มี WinGet ในเครื่อง'
        'gpu.detected' = 'ตรวจพบในเครื่อง: {0}'; 'gpu.none' = 'ไม่พบการ์ดจอ NVIDIA, AMD หรือ Intel (อาจเป็น VM)'
        'boost.title' = 'บูสต์เกม'
        'boost.sub' = 'กดครั้งเดียวก่อนเล่นเกม กดหยุดแล้วทุกอย่างจะกลับเป็นเหมือนเดิม แม้รีสตาร์ตเครื่องไปแล้ว'
        'boost.mode' = 'โหมดเกม'; 'boost.off' = 'ปิดอยู่'; 'boost.on' = 'เปิดตั้งแต่ {0}'; 'boost.start' = 'เริ่ม'; 'boost.stop' = 'หยุด'
        'boost.power' = 'เปลี่ยนเป็น power plan ประสิทธิภาพสูงสุด'
        'boost.apps' = 'ปิดแอปเบื้องหลัง'; 'boost.noapps' = 'ตอนนี้ไม่มีที่เปิดอยู่'
        'boost.notify' = 'ปิดการแจ้งเตือน'
        'status.booston' = 'เปิดบูสต์เกมแล้ว ขอให้สนุก!'; 'status.boostoff' = 'ปิดบูสต์เกมแล้ว การตั้งค่ากลับเป็นเหมือนเดิม'
        'ping.title' = 'ปิงไปเซิร์ฟเวอร์เกม'
        'ping.sub' = 'เวลาเชื่อมต่อไปศูนย์ข้อมูลคลาวด์ที่เกมออนไลน์หลายเกมใช้วางเซิร์ฟเวอร์เอเชีย ยิ่งต่ำยิ่งดี ต่ำกว่า 60 ms ถือว่าดีมาก'
        'ping.start' = 'เริ่มทดสอบ'; 'ping.stop' = 'หยุด'; 'ping.timeout' = 'ไม่ตอบ'
        'ping.bkk' = 'ไทย (กรุงเทพฯ)'; 'ping.sin' = 'สิงคโปร์'; 'ping.hkg' = 'ฮ่องกง'; 'ping.tyo' = 'ญี่ปุ่น (โตเกียว)'
        'startup.title' = 'แอปที่เปิดตอนบูต'
        'startup.sub' = 'แอปที่เปิดเองตอนเข้าสู่ระบบ ยิ่งน้อยเครื่องยิ่งเปิดเร็ว และเหลือ RAM ให้เกมมากขึ้น'
        'startup.empty' = 'ไม่มีแอปที่เปิดตอนบูต'
        'status.startupon' = '{0} จะเปิดพร้อม Windows'; 'status.startupoff' = '{0} จะไม่เปิดพร้อม Windows แล้ว'
        'system.default' = 'ค่าเริ่มต้น'
        'restore.title' = 'สร้างจุดคืนค่าก่อนเปลี่ยน'; 'restore.open' = 'System Restore'
        'restore.sub' = 'สร้างครั้งเดียวก่อนการเปลี่ยนแปลงแรกในหน้านี้ ต้องเปิด System Restore ไว้'
        'status.restoring' = 'กำลังสร้างจุดคืนค่า...'
        'status.restore.made' = 'สร้างจุดคืนค่าแล้ว'
        'status.restore.recent' = 'ไม่ได้สร้างจุดคืนค่าใหม่ เพราะ Windows สร้างไว้แล้วในช่วง 24 ชั่วโมง'
        'status.restore.off' = 'สร้างจุดคืนค่าไม่ได้ เพราะ System Restore ปิดอยู่ เปิดได้ที่ปุ่ม System Restore (Configure > Turn on system protection)'
        'status.boostpartial' = 'เปิดบูสต์เกมแล้ว แต่ขั้นเหล่านี้ไม่สำเร็จ: {0}'
        'status.sound.play' = 'กำลังเล่น: {0}'
        'report.title' = 'แจ้งปัญหา'
        'report.sub' = 'บันทึกไฟล์ .zip ไฟล์เดียวไว้บนเดสก์ท็อป มี log ของ Akati OS และข้อมูลเครื่อง ไม่มีไฟล์ส่วนตัว และลบชื่อผู้ใช้กับชื่อเครื่องออกแล้ว แนบไฟล์นี้ใน GitHub issue'
        'report.button' = 'สร้างรายงานปัญหา'; 'report.issues' = 'GitHub issues'
        'status.report' = 'กำลังสร้างรายงานปัญหา...'; 'status.reportdone' = 'บันทึกไว้บนเดสก์ท็อปแล้ว: {0}'; 'status.reportfailed' = 'สร้างรายงานไม่สำเร็จ'
        'accent.title' = 'สีหลัก'
        'accent.sub' = 'ใช้กับ Akati OS Center, สีเน้นของ Windows (ไฮไลต์ ปุ่ม และลิงก์ ส่วน Start และ taskbar จะเปลี่ยนเมื่อเปิด "แสดงสีเน้น" ใน Settings) และสีของ Terminal แบบ Akati OS'
        'accent.purple' = 'ม่วง'; 'accent.blue' = 'น้ำเงิน'; 'accent.cyan' = 'ฟ้า'; 'accent.green' = 'เขียว'
        'accent.pink' = 'ชมพู'; 'accent.red' = 'แดง'; 'accent.orange' = 'ส้ม'
        'status.accent' = 'สีหลัก: {0} บางส่วนของ Windows จะเปลี่ยนหลังออกจากระบบแล้วเข้าใหม่'
        'wall.title' = 'วอลเปเปอร์'; 'wall.sub' = 'คลิกรูปเพื่อใช้เป็นพื้นหลังเดสก์ท็อป'
        'status.wallpaper' = 'เปลี่ยนวอลเปเปอร์เป็น {0} แล้ว'
        'style.title' = 'เคอร์เซอร์และเสียง'
        'style.sub' = 'เคอร์เซอร์และเสียงระบบของ Akati OS เปลี่ยนกลับเป็นของ Windows ได้ทุกเมื่อ'
        'style.cursor' = 'เคอร์เซอร์'; 'style.sounds' = 'เสียง'; 'style.akati' = 'Akati OS'; 'style.windows' = 'Windows'
        'style.nosound' = 'ไม่มีเสียง'; 'style.preview' = 'ลองฟัง'
        'status.cursor.akati' = 'ใช้เคอร์เซอร์ Akati OS แล้ว'; 'status.cursor.windows' = 'กลับไปใช้เคอร์เซอร์ Windows แล้ว'
        'status.sound.akati' = 'ใช้เสียง Akati OS แล้ว'; 'status.sound.windows' = 'ใช้เสียง Windows แล้ว'; 'status.sound.none' = 'ปิดเสียงระบบแล้ว'
        'welcome.title' = 'ยินดีต้อนรับสู่ Akati OS'; 'welcome.sub' = '3 ขั้นสั้น ๆ เปลี่ยนทีหลังได้ทุกอย่าง'
        'welcome.lang' = 'ภาษา'; 'welcome.apps' = 'ติดตั้งแอปเกม'; 'welcome.apps.d' = 'Steam, Discord, Epic และอื่น ๆ'
        'welcome.look' = 'เลือกธีมและสีหลัก'; 'welcome.look.d' = 'ธีมมืด สว่าง สไลด์โชว์ และ 7 สี'
        'welcome.open' = 'เปิด'; 'welcome.done' = 'เริ่มใช้งาน'
        'welcome.keys' = 'ทิป: Ctrl+1 ถึง Ctrl+7 สลับหน้า, Ctrl+F ค้นหาการตั้งค่า'
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
function Format-Size([double]$bytes) {
    if ($bytes -ge 1GB) { return '{0:N1} GB' -f ($bytes / 1GB) }
    if ($bytes -ge 1MB) { return '{0:N0} MB' -f ($bytes / 1MB) }
    if ($bytes -ge 1KB) { return '{0:N0} KB' -f ($bytes / 1KB) }
    return '0 KB'
}

function Get-RegValue($path, $name) { (Get-ItemProperty -Path $path -Name $name -ErrorAction SilentlyContinue).$name }

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
    foreach ($d in @(Get-CimInstance Win32_LogicalDisk -Filter 'DriveType=3' -ErrorAction SilentlyContinue | Sort-Object DeviceID)) {
        if (!$d.Size) { continue }
        $used = 100 * ($d.Size - $d.FreeSpace) / $d.Size
        $row = New-Object System.Windows.Controls.StackPanel
        $row.Margin = '0,0,0,10'
        $top = New-Object System.Windows.Controls.Grid
        $name = New-Text ("$($d.DeviceID)  " + $(if ($d.VolumeName) { $d.VolumeName } else { T 'disk.local' })) 13 'SemiBold'
        $free = New-Text ((T 'disk.free') -f (Format-Size $d.FreeSpace), (Format-Size $d.Size)) 12
        $free.Foreground = $window.FindResource('MutedBrush'); $free.HorizontalAlignment = 'Right'
        [void]$top.Children.Add($name); [void]$top.Children.Add($free)
        $bar = New-Object System.Windows.Controls.ProgressBar
        $bar.Style = $window.FindResource('Meter'); $bar.Margin = '0,6,0,0'; $bar.Value = $used
        if ($used -ge 90) { $bar.Foreground = '#FF453A' }
        [void]$row.Children.Add($top); [void]$row.Children.Add($bar)
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
                $stats.Top = @($groups | Sort-Object { $_.Cpu }, { $_.Ram } -Descending | Select-Object -First 5 | ForEach-Object {
                    $_.Cpu = [Math]::Round($_.Cpu / $cores, 1)
                    $_.Path = try { (Get-Process -Id $_.Pids[0] -ErrorAction Stop).Path } catch { $null }
                    $_
                })
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

# Status chips: Game boost, power plan, Defender, time since start
function New-Chip([string]$text, $dot) {
    $b = New-Object System.Windows.Controls.Border
    $b.CornerRadius = 12; $b.Background = '#2E2E30'; $b.Padding = '10,4'; $b.Margin = '0,0,8,6'
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
    foreach ($p in @($stats.Top)) {
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
        $label = if ($p.Pids.Count -gt 1) { '{0} ({1})' -f $p.Name, $p.Pids.Count } else { $p.Name }
        $row = New-Row ([string][char]0xE7C4) $label $null $right $null
        $row.Sub.Visibility = 'Collapsed'
        if ($p.Path) {
            if (!$script:iconCache.ContainsKey($p.Path)) { $script:iconCache[$p.Path] = Get-FileIcon @($p.Path) }
            Set-RowIcon $row $script:iconCache[$p.Path]
        }
        [void]$ui.TopList.Children.Add($row.Row)
    }
    Update-Separators $ui.TopList
}

# ---------------------------------------------------------------------------------------------
# Gaming apps
# ---------------------------------------------------------------------------------------------
# Id: WinGet package (used for updates). SelfUpdate: the app updates itself. Exe: where its icon comes from.
$apps = @(
    @{ Key = 'Steam';     Name = 'Steam';               Glyph = [char]0xE7FC; Path = "${env:ProgramFiles(x86)}\Steam\steam.exe"; SelfUpdate = $true
       Exe = @("${env:ProgramFiles(x86)}\Steam\steam.exe") }
    @{ Key = 'Discord';   Name = 'Discord';             Glyph = [char]0xE8BD; Path = "$env:LOCALAPPDATA\Discord\packages\RELEASES"; SelfUpdate = $true
       Exe = @("$env:LOCALAPPDATA\Discord\app-*\Discord.exe") }
    @{ Key = 'Epic';      Name = 'Epic Games Launcher'; Glyph = [char]0xE7FC; Path = "${env:ProgramFiles(x86)}\Epic Games\Launcher"; Id = 'EpicGames.EpicGamesLauncher'
       Exe = @("${env:ProgramFiles(x86)}\Epic Games\Launcher\Portal\Binaries\Win64\EpicGamesLauncher.exe", "${env:ProgramFiles(x86)}\Epic Games\Launcher\Portal\Binaries\Win32\EpicGamesLauncher.exe") }
    @{ Key = 'EA';        Name = 'EA app';              Glyph = [char]0xE7FC; Path = "$env:ProgramFiles\Electronic Arts\EA Desktop"; Id = 'ElectronicArts.EADesktop'
       Exe = @("$env:ProgramFiles\Electronic Arts\EA Desktop\EA Desktop\EADesktop.exe") }
    @{ Key = 'Ubisoft';   Name = 'Ubisoft Connect';     Glyph = [char]0xE7FC; Path = "${env:ProgramFiles(x86)}\Ubisoft\Ubisoft Game Launcher"; Id = 'Ubisoft.Connect'
       Exe = @("${env:ProgramFiles(x86)}\Ubisoft\Ubisoft Game Launcher\UbisoftConnect.exe", "${env:ProgramFiles(x86)}\Ubisoft\Ubisoft Game Launcher\upc.exe") }
    @{ Key = 'BattleNet'; Name = 'Battle.net';          Glyph = [char]0xE7FC; Path = "$env:ProgramFiles\Battle.net"; Path2 = "${env:ProgramFiles(x86)}\Battle.net"; Id = 'Blizzard.BattleNet'
       Exe = @("$env:ProgramFiles\Battle.net\Battle.net Launcher.exe", "${env:ProgramFiles(x86)}\Battle.net\Battle.net Launcher.exe", "$env:ProgramFiles\Battle.net\Battle.net.exe") }
    @{ Key = 'OBS';       Name = 'OBS Studio';          Glyph = [char]0xE714; Path = "$env:ProgramFiles\obs-studio"; Id = 'OBSProject.OBSStudio'
       Exe = @("$env:ProgramFiles\obs-studio\bin\64bit\obs64.exe") }
)

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
    $icon.Width = 30; $icon.Height = 30; $icon.CornerRadius = 7; $icon.Background = '#3A3A3C'; $icon.Margin = '0,0,12,0'
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
        $child.BorderBrush = '#38383A'
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

# State of a row: idle, queued, install, update. Only one install or update runs at a time
# (installers and WinGet do not like to run side by side), the others wait in the queue.
$progressDir = Join-Path $env:LOCALAPPDATA 'AkatiOS\Logs'
function Update-AppRow($app) {
    $installed = Test-App $app
    $btn = $app.Button
    # No tick box for apps that are installed, installing or waiting in the queue
    $busy = $app.State -ne 'idle'
    $app.Check.Visibility = if ($installed -or $busy) { 'Hidden' } else { 'Visible' }
    if ($installed -or $busy) { $app.Check.IsChecked = $false }
    switch ($app.State) {
        'install' { $btn.Content = T 'cancel'; $btn.Style = $window.FindResource('Secondary'); $btn.IsEnabled = $true; $app.Bar.Visibility = 'Visible'; return }
        'update'  { $btn.Content = T 'cancel'; $btn.Style = $window.FindResource('Secondary'); $btn.IsEnabled = $true; $app.Bar.Visibility = 'Visible'; $app.Bar.IsIndeterminate = $true; $app.Sub.Text = T 'updating'; return }
        'queued'  { $btn.Content = T 'cancel'; $btn.Style = $window.FindResource('Secondary'); $btn.IsEnabled = $true; $app.Bar.Visibility = 'Collapsed'; $app.Sub.Text = T 'queued'; $app.Sub.Foreground = $window.FindResource('MutedBrush'); return }
    }
    $app.Bar.Visibility = 'Collapsed'
    $btn.Style = $window.FindResource('Primary')
    if ($installed -and $app.HasUpdate) {
        $app.Sub.Text = T 'updateavailable'; $app.Sub.Foreground = $window.FindResource('Accent2')
        $btn.Content = T 'update'; $btn.IsEnabled = $true
    } elseif ($installed) {
        $app.Sub.Text = if ($app.SelfUpdate) { (T 'installed') + ' · ' + (T 'selfupdate') } else { T 'installed' }
        $app.Sub.Foreground = $window.FindResource('Good')
        $btn.Content = T 'installed'; $btn.IsEnabled = $false
    } else {
        $app.Sub.Text = T 'notinstalled'; $app.Sub.Foreground = $window.FindResource('MutedBrush')
        $btn.Content = T 'install'; $btn.IsEnabled = $true
    }
    if ($installed -and !$app.HasIcon) {
        $image = Get-FileIcon $app.Exe
        if ($image) { Set-RowIcon $app.RowParts $image; $app.HasIcon = $true }
    }
}

function Update-AppsToolbar {
    $selected = @($apps | Where-Object { $_.Check.IsChecked -and $_.State -eq 'idle' })
    $ui.InstallSelectedButton.IsEnabled = $selected.Count -gt 0
    $ui.UpdateAllButton.IsEnabled = [bool]@($apps | Where-Object { $_.HasUpdate -and $_.State -eq 'idle' }).Count
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
    $next.Bar.IsIndeterminate = $true; $next.Bar.Value = 0
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
            elseif ((Get-LastOutput $r) -eq 0) { $app.HasUpdate = $false; Set-Status ((T 'status.updated') -f $app.Name) }
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
        Get-Process -Name 'DiscordSetup' -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
    }
}

# Progress written by GAMEAPPS.ps1: "<stage>|<percent>", percent is -1 when unknown
function Update-AppProgress {
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
            $app.Bar.IsIndeterminate = $false; $app.Bar.Value = $percent
            $app.Sub.Text = (T 'stage.download') + " $percent%"
        } else {
            $app.Bar.IsIndeterminate = $true
            $app.Sub.Text = T "stage.$stage"
        }
    }
}

foreach ($app in $apps) {
    $btn = New-Object System.Windows.Controls.Button
    $btn.Style = $window.FindResource('Primary'); $btn.MinWidth = 120
    $check = New-Object System.Windows.Controls.CheckBox
    $check.Style = $window.FindResource('Tick')
    $check.Add_Click({ Update-AppsToolbar })
    $row = New-Row ([string]$app.Glyph) $app.Name $null $btn $null $check
    $app.Sub = $row.Sub; $app.Button = $btn; $app.Check = $check; $app.Bar = $row.Bar; $app.RowParts = $row
    $app.State = 'idle'; $app.HasUpdate = $false
    $btn.Tag = $app
    $btn.Add_Click({
        $a = $this.Tag
        if ($a.State -ne 'idle') { Stop-AppJob $a; return }
        if ((Test-App $a) -and $a.HasUpdate) { Add-AppToQueue $a 'update' } else { Add-AppToQueue $a 'install' }
    })
    [void]$ui.AppsList.Children.Add($row.Row)
    Update-AppRow $app
}
Update-AppsToolbar
Update-Separators $ui.AppsList

$ui.InstallSelectedButton.Add_Click({
    foreach ($a in $apps) { if ($a.Check.IsChecked -and $a.State -eq 'idle') { $a.Check.IsChecked = $false; Add-AppToQueue $a 'install' } }
    Update-AppsToolbar
})
$ui.UpdateAllButton.Add_Click({
    foreach ($a in $apps) { if ($a.HasUpdate -and $a.State -eq 'idle') { Add-AppToQueue $a 'update' } }
    Update-AppsToolbar
})

# Which installed apps have a newer version in WinGet (Steam and Discord update themselves)
$ui.CheckUpdatesButton.Add_Click({
    if (!(Get-Command winget -ErrorAction SilentlyContinue)) { Set-Status (T 'status.nowinget'); return }
    $this.IsEnabled = $false
    Set-Status (T 'status.checkingapps') $true
    # One WinGet query per app: "list --upgrade-available" finds the app only when a newer version exists
    # (the table of "winget upgrade" cuts long names, so it is not parsed)
    $ids = @($apps | Where-Object { $_.Id -and (Test-App $_) } | ForEach-Object { $_.Id })
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
        if ($count) { Set-Status ((T 'status.updatesfound') -f $count) } else { Set-Status (T 'status.noupdates') }
    }
})

# GPU drivers: highlight the vendor of the graphics card in this PC
$gpuNames = @(try { Get-CimInstance Win32_VideoController | Where-Object { $_.Name -notmatch 'Basic Display|Remote|Virtual|VMware|Hyper-V|Parsec' } | ForEach-Object { $_.Name } } catch { })
$gpuVendors = @{ GpuNvidia = 'NVIDIA|GeForce|Quadro|RTX|GTX'; GpuAmd = 'AMD|Radeon|ATI '; GpuIntel = 'Intel|Arc ' }
$script:gpuFound = @()
foreach ($k in $gpuVendors.Keys) {
    if (@($gpuNames | Where-Object { $_ -match $gpuVendors[$k] }).Count) {
        $ui[$k].Style = $window.FindResource('Primary'); $script:gpuFound += $k
    }
}
function Update-GpuText {
    $ui.GpuDetected.Text = if ($gpuNames.Count) { (T 'gpu.detected') -f ($gpuNames -join ', ') } else { T 'gpu.none' }
}
Update-GpuText
$ui.GpuNvidia.Add_Click({ Start-Process 'https://www.nvidia.com/en-us/drivers/' })
$ui.GpuAmd.Add_Click({ Start-Process 'https://www.amd.com/en/support/download/drivers.html' })
$ui.GpuIntel.Add_Click({ Start-Process 'https://www.intel.com/content/www/us/en/download-center/home.html' })

# ---------------------------------------------------------------------------------------------
# Game boost: one click before playing, and back again afterwards. What was changed is saved in the
# registry, so Stop still works after Akati OS Center or Windows was restarted.
# ---------------------------------------------------------------------------------------------
$boostKey = 'HKCU:\Software\AkatiOS\Center\Boost'
$toastKey = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\PushNotifications'
# Background apps that are safe to close while playing (never game launchers or browsers)
$boostCandidates = 'OneDrive', 'Teams', 'ms-teams', 'Spotify', 'PhoneExperienceHost', 'Dropbox', 'GoogleDriveFS', 'Skype'
$powerSchemes = @(
    '11111111-1111-1111-1111-111111111111'   # Atlas Power Scheme (Maximum Performance)
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
        $ui.BoostIcon.Background = '#3A3A3C'
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
})

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
Update-Separators $ui.TweaksList

# ---------------------------------------------------------------------------------------------
# Cleaner
# ---------------------------------------------------------------------------------------------
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
    $preview.CornerRadius = 8; $preview.Height = 130; $preview.ClipToBounds = $true; $preview.Background = '#3A3A3C'
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
    $frame.Width = 168; $frame.Height = 95; $frame.CornerRadius = 8; $frame.Background = '#3A3A3C'
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
    'Power-saving' = @('Power saving', 'การประหยัดพลังงาน', 'Off is the Atlas Maximum Performance plan. Best for desktops.', 'ปิดคือ power plan ประสิทธิภาพสูงสุดของ Atlas เหมาะกับคอมตั้งโต๊ะ')
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
    'Default' = @('Windows default', 'ค่าของ Windows'); 'Atlas' = @('Atlas', 'แบบ Atlas'); 'Legacy' = @('Legacy', 'แบบเก่า')
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
    # Files directly in the folder: AtlasOS links
    Add-SystemCard 'AtlasOS' @(Get-Item -LiteralPath $desktop) (Get-Item -LiteralPath $desktop).FullName
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
            $disk = Get-CimInstance Win32_LogicalDisk -Filter "DeviceID='C:'"
            $lines += 'C: {0:N1} GB free of {1:N1} GB' -f ($disk.FreeSpace / 1GB), ($disk.Size / 1GB)
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
    if ($name -eq 'cleaner' -and $ui.CleanTotal.Text -eq '-') { Start-Scan }
    if ($name -eq 'boost') { Update-BoostCard }
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

# Keyboard: Ctrl+1 to Ctrl+7 switch pages, Ctrl+F searches the AtlasOS settings in Tweaks, Esc closes the welcome or clears the search
$window.Add_PreviewKeyDown({
    param($sender, $e)
    $ctrl = ([System.Windows.Input.Keyboard]::Modifiers -band [System.Windows.Input.ModifierKeys]::Control) -ne 0
    $key = [string]$e.Key
    if ($key -eq 'Escape') {
        if ($ui.Welcome.Visibility -eq 'Visible') { Close-Welcome; $e.Handled = $true }
        elseif ($ui.SystemSearch.Text) { $ui.SystemSearch.Text = ''; $e.Handled = $true }
        return
    }
    if (!$ctrl -or $ui.Welcome.Visibility -eq 'Visible') { return }
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

# ---------------------------------------------------------------------------------------------
# Screenshot mode (CI): render every page in both languages to PNG and exit
# ---------------------------------------------------------------------------------------------
if ($Screenshot) {
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
                $apps[2].State = 'install'; $apps[2].Bar.IsIndeterminate = $false; $apps[2].Bar.Value = 45; $apps[2].Sub.Text = (T 'stage.download') + ' 45%'; Update-AppRow $apps[2]
                $apps[3].State = 'queued'; Update-AppRow $apps[3]
                $apps[4].Check.IsChecked = $true; Update-AppsToolbar
            }
            if ($p -eq 'tweaks') { $ui.SystemList.Measure((New-Object System.Windows.Size 800, 10000)) }
            Save-Shot "$p-$l.png"
            if ($p -eq 'gaming') { foreach ($i in 2, 3) { $apps[$i].State = 'idle'; Update-AppRow $apps[$i] }; $apps[4].Check.IsChecked = $false }
            if ($p -eq 'appearance' -or $p -eq 'tweaks' -or $p -eq 'boost') {
                # The lower part of long pages
                $sv = $ui["Page$(Get-PageId $p)"]
                $sv.UpdateLayout(); $sv.ScrollToVerticalOffset(100000); $sv.UpdateLayout()
                Save-Shot "$p-$l-2.png"
                $sv.ScrollToVerticalOffset(0)
            }
        }
        $ui.NavDashboard.IsChecked = $true
        $ui.Welcome.Visibility = 'Visible'
        Save-Shot "welcome-$l.png"
        $ui.Welcome.Visibility = 'Collapsed'
    }
    # Accent colors recolor the window
    Set-CenterAccent $accents[1]; $ui.NavGaming.IsChecked = $true; Save-Shot 'accent-blue.png'
    Set-CenterAccent $accents[6]; $ui.NavBoost.IsChecked = $true; Save-Shot 'accent-orange.png'
    Set-CenterAccent $accents[0]
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
            $on = 1; [void][AkatiOS.Native]::DwmSetWindowAttribute($hwnd, 20, [ref]$on, 4)        # dark mode
            $round = 2; [void][AkatiOS.Native]::DwmSetWindowAttribute($hwnd, 33, [ref]$round, 4)  # round corners
            $mica = 2
            if ([AkatiOS.Native]::DwmSetWindowAttribute($hwnd, 38, [ref]$mica, 4) -eq 0) {
                $ui.RootBorder.Background = '#D01C1C1E'
                $ui.Sidebar.Background = '#90232325'
            }
        })
    } catch { }
}

$timer = New-Object System.Windows.Threading.DispatcherTimer
$timer.Interval = [TimeSpan]::FromMilliseconds(500)
$timer.Add_Tick({ Update-Stats; Receive-Work; Update-AppProgress; Update-Ping })
$window.Add_Loaded({
    # Akati OS checks GitHub once when the window opens (one request, nothing is downloaded)
    Start-UpdateCheck
    $script:statsHandle = $statsPs.BeginInvoke()
    $timer.Start()
})
$window.Add_Closed({
    $stats.Run = $false
    $timer.Stop()
})
[void]$window.ShowDialog()
