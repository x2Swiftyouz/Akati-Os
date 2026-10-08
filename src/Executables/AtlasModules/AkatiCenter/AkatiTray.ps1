<#
.SYNOPSIS
    Akati OS icon in the notification area (next to the clock).
.DESCRIPTION
    Runs as the signed-in user without administrator rights, started at sign-in by the task
    "\AkatiOS\Akati OS tray". Pointing at the icon shows CPU and RAM use; its menu has the same tools as
    the desktop menu (AkatiMenu.ps1 runs them). Automatic Game boost: when "AutoBoost" is on in
    HKCU\Software\AkatiOS\Center and a game from My games is running, it starts Game boost, and stops it
    again when no such game runs any more (only if it started it itself).
    -Install   (administrator) registers the sign-in task for this user and starts the icon now.
    -Remove    (administrator) stops the icon and removes the task.
#>
param (
    [switch]$Install,
    [switch]$Remove
)

$windir     = [Environment]::GetFolderPath('Windows')
$ps         = Join-Path $windir 'System32\WindowsPowerShell\v1.0\powershell.exe'
$menuScript = Join-Path $PSScriptRoot 'AkatiMenu.ps1'
$center     = Join-Path $PSScriptRoot 'AkatiCenter.ps1'
$iconFile   = Join-Path $windir 'AtlasModules\Other\akatios-folder.ico'
$userKey    = 'HKCU:\Software\AkatiOS\Center'
$taskPath   = '\AkatiOS\'
$taskName   = 'Akati OS tray'

# HKLM\SOFTWARE\AkatiOS TrayIcon = 1: the icon is wanted. Akati OS Center registers the task again when it is
# missing (setup in AME Wizard did not always register it)
$machineKey = 'HKLM:\SOFTWARE\AkatiOS'
function Set-Wanted([int]$value) {
    if (!(Test-Path $machineKey)) { New-Item -Path $machineKey -Force | Out-Null }
    Set-ItemProperty -Path $machineKey -Name TrayIcon -Value $value -Type DWord
}
# Errors of -Install and -Remove go to %ProgramData%\AkatiOS\AkatiTray.log
function Write-TrayLog([string]$text) {
    try {
        $dir = Join-Path $env:ProgramData 'AkatiOS'
        if (!(Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
        Add-Content -Path (Join-Path $dir 'AkatiTray.log') -Value "$(Get-Date -Format s) $env:USERDOMAIN\$env:USERNAME $text"
    } catch { }
}

if ($Install) {
    try {
        Set-Wanted 1
        # At sign-in, as this user with normal rights, running as long as the user is signed in
        $action = New-ScheduledTaskAction -Execute $ps -Argument "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$PSCommandPath`""
        $trigger = New-ScheduledTaskTrigger -AtLogOn -User "$env:USERDOMAIN\$env:USERNAME"
        $principal = New-ScheduledTaskPrincipal -UserId "$env:USERDOMAIN\$env:USERNAME" -LogonType Interactive -RunLevel Limited
        $settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -ExecutionTimeLimit ([TimeSpan]::Zero) -MultipleInstances IgnoreNew
        Register-ScheduledTask -TaskPath $taskPath -TaskName $taskName -Action $action -Trigger $trigger -Principal $principal -Settings $settings -Force -ErrorAction Stop | Out-Null
        Start-ScheduledTask -TaskPath $taskPath -TaskName $taskName -ErrorAction SilentlyContinue
        Write-TrayLog 'installed'
        exit 0
    } catch {
        Write-TrayLog "install failed: $($_.Exception.Message)"
        exit 1
    }
}
if ($Remove) {
    try { Set-Wanted 0 } catch { Write-TrayLog "remove: $($_.Exception.Message)" }
    Stop-ScheduledTask -TaskPath $taskPath -TaskName $taskName -ErrorAction SilentlyContinue
    Unregister-ScheduledTask -TaskPath $taskPath -TaskName $taskName -Confirm:$false -ErrorAction SilentlyContinue
    Get-CimInstance Win32_Process -Filter "Name='powershell.exe'" -ErrorAction SilentlyContinue |
        Where-Object { $_.CommandLine -like '*AkatiTray.ps1*' -and $_.CommandLine -notlike '*-Remove*' } |
        ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }
    exit 0
}

# One icon per user
$mutex = New-Object System.Threading.Mutex($false, 'Local\AkatiOSTray')
if (!$mutex.WaitOne(0)) { exit 0 }

Add-Type -AssemblyName System.Windows.Forms, System.Drawing

$lang = try { (Get-ItemProperty -Path $userKey -Name Language -ErrorAction Stop).Language } catch { 'en' }
$texts = @{
    en = @{
        tip = 'Akati OS · CPU {0}% · RAM {1}%'; open = 'Open Akati OS Center'; freeram = 'Free up RAM'; apps = 'My apps'
        boostOn = 'Stop Game boost'; boostOff = 'Start Game boost'; auto = 'Automatic Game boost'; clean = 'Clean junk files'
        ping = 'Ping test'; flushdns = 'Flush DNS cache'; quit = 'Hide this icon until the next sign-in'; more = 'Gaming apps...'
    }
    th = @{
        tip = 'Akati OS · CPU {0}% · RAM {1}%'; open = 'เปิด Akati OS Center'; freeram = 'ล้าง RAM'; apps = 'แอปของฉัน'
        boostOn = 'หยุดบูสต์เกม'; boostOff = 'เริ่มบูสต์เกม'; auto = 'บูสต์เกมอัตโนมัติ'; clean = 'ล้างไฟล์ขยะ'
        ping = 'ทดสอบปิง'; flushdns = 'ล้าง DNS cache'; quit = 'ซ่อนไอคอนนี้จนกว่าจะล็อกอินใหม่'; more = 'แอปเกม...'
    }
}
function T([string]$key) { $l = (Get-ItemProperty -Path $userKey -Name Language -ErrorAction SilentlyContinue).Language; if ($l -notin 'en', 'th') { $l = 'en' }; $texts[$l][$key] }

function Start-Hidden([string]$file, [string]$arguments) {
    Start-Process -FilePath $ps -ArgumentList "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$file`" $arguments" -WindowStyle Hidden
}
function Test-Boost { [bool](Get-ItemProperty -Path "$userKey\Boost" -Name Active -ErrorAction SilentlyContinue).Active }
function Get-Setting([string]$name) { (Get-ItemProperty -Path $userKey -Name $name -ErrorAction SilentlyContinue).$name }

$notify = New-Object System.Windows.Forms.NotifyIcon
try { $notify.Icon = New-Object System.Drawing.Icon $iconFile } catch { $notify.Icon = [System.Drawing.SystemIcons]::Application }
$notify.Text = 'Akati OS'
$notify.Visible = $true
$notify.Add_MouseClick({ param($s, $e) if ($e.Button -eq 'Left') { Start-Hidden $center '' } })

# The menu is built each time it opens, so it shows the current state, apps and language
$menu = New-Object System.Windows.Forms.ContextMenuStrip
$menu.Add_Opening({
    param($sender, $e)
    $menu.Items.Clear()
    $add = { param($text, $click) $item = $menu.Items.Add($text); if ($click) { $item.Add_Click($click) }; $item }
    [void](& $add (T 'open') { Start-Hidden $center '' })
    [void]$menu.Items.Add('-')
    [void](& $add (T 'freeram') { Start-Hidden $menuScript '-Action freeram' })
    # My apps: the same list as the desktop menu ("name|command|icon") and the games in My games
    $apps = New-Object System.Windows.Forms.ToolStripMenuItem (T 'apps')
    $list = @(Get-Setting 'MenuApps')
    foreach ($g in @(if (Test-Path "$userKey\Games") { (Get-Item "$userKey\Games").Property })) { $list += '{0}|"{1}"|{1}' -f [IO.Path]::GetFileNameWithoutExtension($g), $g }
    foreach ($entry in $list) {
        if (!$entry) { continue }
        $name, $command, $appIcon = $entry -split '\|', 3
        $sub = $apps.DropDownItems.Add($name)
        try { if ($appIcon -and (Test-Path -LiteralPath $appIcon)) { $sub.Image = ([System.Drawing.Icon]::ExtractAssociatedIcon($appIcon)).ToBitmap() } } catch { }
        $sub.Tag = $command
        $sub.Add_Click({ Start-Process cmd.exe -ArgumentList "/c start `"`" $($this.Tag)" -WindowStyle Hidden })
    }
    if ($apps.DropDownItems.Count) { [void]$apps.DropDownItems.Add('-') }
    $more = $apps.DropDownItems.Add((T 'more')); $more.Add_Click({ Start-Hidden $center '-Page gaming' })
    [void]$menu.Items.Add($apps)
    [void]$menu.Items.Add('-')
    [void](& $add $(if (Test-Boost) { T 'boostOn' } else { T 'boostOff' }) { Start-Hidden $menuScript '-Action boost' })
    $auto = & $add (T 'auto') { $on = !((Get-Setting 'AutoBoost') -eq 1); New-Item -Path $userKey -Force -ErrorAction SilentlyContinue | Out-Null; Set-ItemProperty -Path $userKey -Name AutoBoost -Value $(if ($on) { 1 } else { 0 }) }
    $auto.Checked = (Get-Setting 'AutoBoost') -eq 1
    [void](& $add (T 'clean') { Start-Hidden $center '-Page cleaner' })
    [void](& $add (T 'ping') { Start-Hidden $center '-Page boost -Ping' })
    [void](& $add (T 'flushdns') { Start-Hidden $menuScript '-Action flushdns' })
    [void]$menu.Items.Add('-')
    [void](& $add (T 'quit') { $notify.Visible = $false; [System.Windows.Forms.Application]::Exit() })
    # An empty menu is cancelled before Opening: it has items now
    $e.Cancel = $false
})
$notify.ContextMenuStrip = $menu

# CPU and RAM for the tooltip, and the automatic Game boost, every 3 seconds
$script:autoStarted = $null
$timer = New-Object System.Windows.Forms.Timer
$timer.Interval = 3000
$timer.Add_Tick({
    try {
        $cpu = [int](Get-CimInstance Win32_PerfFormattedData_PerfOS_Processor -Filter "Name='_Total'").PercentProcessorTime
        $os = Get-CimInstance Win32_OperatingSystem
        $ram = [int](100 * ($os.TotalVisibleMemorySize - $os.FreePhysicalMemory) / $os.TotalVisibleMemorySize)
        $notify.Text = (T 'tip') -f $cpu, $ram
    } catch { }
    if ((Get-Setting 'AutoBoost') -ne 1) { $script:autoStarted = $null; return }
    $games = @(if (Test-Path "$userKey\Games") { (Get-Item "$userKey\Games").Property | ForEach-Object { [IO.Path]::GetFileNameWithoutExtension($_) } })
    if (!$games.Count) { return }
    $running = Get-Process -Name $games -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($running -and !$script:autoStarted -and !(Test-Boost)) {
        $script:autoStarted = $running.Name
        Start-Hidden $menuScript '-Action booston'
    } elseif (!$running -and $script:autoStarted) {
        # Only a boost this icon started is stopped again
        $script:autoStarted = $null
        if (Test-Boost) { Start-Hidden $menuScript '-Action boostoff' }
    }
})
$timer.Start()

[System.Windows.Forms.Application]::Run()
$timer.Stop()
$notify.Dispose()
$mutex.ReleaseMutex()
