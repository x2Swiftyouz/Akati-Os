<#
.SYNOPSIS
    Akati OS icon in the notification area (next to the clock).
.DESCRIPTION
    Runs as the signed-in user without administrator rights, started at sign-in by the task
    "\AkatiOS\Akati OS tray". Pointing at the icon shows CPU and RAM use; its menu has the same tools as
    the desktop menu (AkatiMenu.ps1 runs them). Automatic Game boost: when "AutoBoost" is on in
    HKCU\Software\AkatiOS\Center and a game from My games is running, it starts Game boost, and stops it
    again when no such game runs any more (only if it started it itself). Games with "Keep off CPU 0" in
    their profile get every CPU except CPU 0. Ctrl+Alt+B starts or stops Game boost and Ctrl+Alt+R frees
    up RAM (unless "Hotkeys" is 0).
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

# The signed-in user the task is for. AME Wizard can run this as SYSTEM (USERNAME is then the computer
# account, for example "PC$"), so the user is taken from Windows (console user, else the owner of Explorer)
function Get-SignedInUser {
    if ([Security.Principal.WindowsIdentity]::GetCurrent().User.Value -ne 'S-1-5-18' -and $env:USERNAME -notlike '*$') {
        return "$env:USERDOMAIN\$env:USERNAME"
    }
    $user = (Get-CimInstance Win32_ComputerSystem -ErrorAction SilentlyContinue).UserName
    if ($user) { return $user }
    foreach ($p in @(Get-CimInstance Win32_Process -Filter "Name='explorer.exe'" -ErrorAction SilentlyContinue)) {
        $owner = Invoke-CimMethod -InputObject $p -MethodName GetOwner -ErrorAction SilentlyContinue
        if ($owner.User) { return "$($owner.Domain)\$($owner.User)" }
    }
    throw 'No signed-in user found'
}

if ($Install) {
    try {
        Set-Wanted 1
        # At sign-in, as this user with normal rights, running as long as the user is signed in
        $action = New-ScheduledTaskAction -Execute $ps -Argument "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$PSCommandPath`""
        $user = Get-SignedInUser
        $trigger = New-ScheduledTaskTrigger -AtLogOn -User $user
        $principal = New-ScheduledTaskPrincipal -UserId $user -LogonType Interactive -RunLevel Limited
        $settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -ExecutionTimeLimit ([TimeSpan]::Zero) -MultipleInstances IgnoreNew
        Register-ScheduledTask -TaskPath $taskPath -TaskName $taskName -Action $action -Trigger $trigger -Principal $principal -Settings $settings -Force -ErrorAction Stop | Out-Null
        Start-ScheduledTask -TaskPath $taskPath -TaskName $taskName -ErrorAction SilentlyContinue
        Write-TrayLog "installed for $user"
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
        ac = 'Anti-cheat mode'; acValorant = 'Valorant (Core isolation on)'; acFivem = 'FiveM (Core isolation off)'
        acNote = 'Takes effect after a restart'; power = 'Power plan'
        tipKeys = 'Ctrl+Alt+B Game boost · Ctrl+Alt+R Free up RAM'
    }
    th = @{
        tip = 'Akati OS · CPU {0}% · RAM {1}%'; open = 'เปิด Akati OS Center'; freeram = 'ล้าง RAM'; apps = 'แอปของฉัน'
        boostOn = 'หยุดบูสต์เกม'; boostOff = 'เริ่มบูสต์เกม'; auto = 'บูสต์เกมอัตโนมัติ'; clean = 'ล้างไฟล์ขยะ'
        ping = 'ทดสอบปิง'; flushdns = 'ล้าง DNS cache'; quit = 'ซ่อนไอคอนนี้จนกว่าจะล็อกอินใหม่'; more = 'แอปเกม...'
        ac = 'โหมดแอนตี้ชีต'; acValorant = 'Valorant (เปิด Core isolation)'; acFivem = 'FiveM (ปิด Core isolation)'
        acNote = 'มีผลหลังรีสตาร์ท'; power = 'แผนการใช้พลังงาน'
        tipKeys = 'Ctrl+Alt+B บูสต์เกม · Ctrl+Alt+R ล้าง RAM'
    }
}
function T([string]$key) { $l = (Get-ItemProperty -Path $userKey -Name Language -ErrorAction SilentlyContinue).Language; if ($l -notin 'en', 'th') { $l = 'en' }; $texts[$l][$key] }

function Start-Hidden([string]$file, [string]$arguments) {
    Start-Process -FilePath $ps -ArgumentList "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$file`" $arguments" -WindowStyle Hidden
}
function Test-Boost { [bool](Get-ItemProperty -Path "$userKey\Boost" -Name Active -ErrorAction SilentlyContinue).Active }
function Get-Setting([string]$name) { (Get-ItemProperty -Path $userKey -Name $name -ErrorAction SilentlyContinue).$name }
# Core isolation (HVCI) setting: on for Valorant (Vanguard), off for FiveM
function Get-Hvci {
    (Get-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\DeviceGuard\Scenarios\HypervisorEnforcedCodeIntegrity' -Name Enabled -ErrorAction SilentlyContinue).Enabled -eq 1
}
# Processes of the games in My games. FiveM.exe starts the game as FiveM_<build>_GTAProcess.exe
function Get-GameProcess([string[]]$names) {
    if (!$names) { return }
    $list = @($names)
    if ($list -contains 'FiveM') { $list += 'FiveM_*GTAProcess' }
    Get-Process -Name $list -ErrorAction SilentlyContinue
}
# Power plans from powercfg: GUID, name and whether it is the active one (works in any Windows language)
function Get-PowerPlan {
    foreach ($line in @(& powercfg.exe /list 2>$null)) {
        if ($line -match '([0-9a-fA-F-]{36})\s+\((.+)\)(\s*\*)?') {
            [pscustomobject]@{ Guid = $Matches[1]; Name = $Matches[2]; Active = [bool]$Matches[3] }
        }
    }
}

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
    $auto = & $add (T 'auto') { $on = !((Get-Setting 'AutoBoost') -eq 1); if (!(Test-Path $userKey)) { New-Item -Path $userKey -Force -ErrorAction SilentlyContinue | Out-Null }; Set-ItemProperty -Path $userKey -Name AutoBoost -Value $(if ($on) { 1 } else { 0 }) }
    $auto.Checked = (Get-Setting 'AutoBoost') -eq 1
    # Anti-cheat mode: the same as the buttons in Akati OS Center (AkatiMenu.ps1 asks for administrator rights)
    $ac = New-Object System.Windows.Forms.ToolStripMenuItem (T 'ac')
    $hvci = Get-Hvci
    $v = $ac.DropDownItems.Add((T 'acValorant')); $v.Checked = $hvci; $v.Add_Click({ Start-Hidden $menuScript '-Action hvcion' })
    $f = $ac.DropDownItems.Add((T 'acFivem')); $f.Checked = !$hvci; $f.Add_Click({ Start-Hidden $menuScript '-Action hvcioff' })
    [void]$ac.DropDownItems.Add('-')
    $note = $ac.DropDownItems.Add((T 'acNote')); $note.Enabled = $false
    [void]$menu.Items.Add($ac)
    # Power plan: switching does not need administrator rights
    $power = New-Object System.Windows.Forms.ToolStripMenuItem (T 'power')
    foreach ($plan in @(Get-PowerPlan)) {
        $p = $power.DropDownItems.Add($plan.Name); $p.Checked = $plan.Active; $p.Tag = $plan.Guid
        $p.Add_Click({ & powercfg.exe /setactive $this.Tag 2>$null | Out-Null })
    }
    if ($power.DropDownItems.Count) { [void]$menu.Items.Add($power) }
    [void](& $add (T 'clean') { Start-Hidden $center '-Page cleaner' })
    [void](& $add (T 'ping') { Start-Hidden $center '-Page boost -Ping' })
    [void](& $add (T 'flushdns') { Start-Hidden $menuScript '-Action flushdns' })
    [void]$menu.Items.Add('-')
    [void](& $add (T 'quit') { $notify.Visible = $false; [System.Windows.Forms.Application]::Exit() })
    # An empty menu is cancelled before Opening: it has items now
    $e.Cancel = $false
})
$notify.ContextMenuStrip = $menu

# Keys that work in any app and game: Ctrl+Alt+B Game boost, Ctrl+Alt+R Free up RAM
$hotkeys = $null
if ((Get-Setting 'Hotkeys') -ne 0) {
    try {
        Add-Type -ReferencedAssemblies System.Windows.Forms -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
using System.Windows.Forms;
public class AkatiHotkeys : NativeWindow, IDisposable {
    [DllImport("user32.dll")] static extern bool RegisterHotKey(IntPtr hWnd, int id, uint modifiers, uint key);
    [DllImport("user32.dll")] static extern bool UnregisterHotKey(IntPtr hWnd, int id);
    public Action<int> Pressed;
    public AkatiHotkeys() { CreateHandle(new CreateParams()); }
    // Ctrl (2) + Alt (1), no repeat while held (0x4000)
    public bool Add(int id, uint key) { return RegisterHotKey(Handle, id, 0x4003, key); }
    protected override void WndProc(ref Message m) {
        if (m.Msg == 0x0312 && Pressed != null) { Pressed(m.WParam.ToInt32()); }
        base.WndProc(ref m);
    }
    public void Dispose() { UnregisterHotKey(Handle, 1); UnregisterHotKey(Handle, 2); DestroyHandle(); }
}
'@
        $hotkeys = New-Object AkatiHotkeys
        $hotkeys.Pressed = [Action[int]] {
            param($id)
            if ($id -eq 1) { Start-Hidden $menuScript '-Action boost' } elseif ($id -eq 2) { Start-Hidden $menuScript '-Action freeram' }
        }
        # Another app may already use the keys: then that key does nothing here
        [void]$hotkeys.Add(1, 0x42)
        [void]$hotkeys.Add(2, 0x52)
    } catch { $hotkeys = $null }
}

# CPU and RAM for the tooltip, and the automatic Game boost, every 3 seconds
$script:autoStarted = $null
$script:affinityDone = @{}
$timer = New-Object System.Windows.Forms.Timer
$timer.Interval = 3000
$timer.Add_Tick({
    try {
        $cpu = [int](Get-CimInstance Win32_PerfFormattedData_PerfOS_Processor -Filter "Name='_Total'").PercentProcessorTime
        $os = Get-CimInstance Win32_OperatingSystem
        $ram = [int](100 * ($os.TotalVisibleMemorySize - $os.FreePhysicalMemory) / $os.TotalVisibleMemorySize)
        $notify.Text = (T 'tip') -f $cpu, $ram
    } catch { }
    # Keep off CPU 0: once for each game process (the user can change it again in Task Manager)
    try {
        $core0 = @(if (Test-Path "$userKey\GameProfiles") {
            $profiles = Get-ItemProperty -Path "$userKey\GameProfiles"
            foreach ($prop in $profiles.PSObject.Properties) {
                if ($prop.Name -like '*|core0' -and $prop.Value -eq 1) { [IO.Path]::GetFileNameWithoutExtension($prop.Name.Substring(0, $prop.Name.Length - 6)) }
            }
        })
        $cpus = [Environment]::ProcessorCount
        if ($core0.Count -and $cpus -ge 2 -and $cpus -le 62) {
            $mask = [long][Math]::Pow(2, $cpus) - 2
            foreach ($p in @(Get-GameProcess $core0)) {
                if ($script:affinityDone.ContainsKey($p.Id)) { continue }
                $script:affinityDone[$p.Id] = $true
                # Games with a protected anti-cheat do not allow it: they are left as they are
                try { $p.ProcessorAffinity = [IntPtr]$mask } catch { }
            }
        }
    } catch { }
    if ((Get-Setting 'AutoBoost') -ne 1) { $script:autoStarted = $null; return }
    $games = @(if (Test-Path "$userKey\Games") { (Get-Item "$userKey\Games").Property | ForEach-Object { [IO.Path]::GetFileNameWithoutExtension($_) } })
    if (!$games.Count) { return }
    $running = Get-GameProcess $games | Select-Object -First 1
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
if ($hotkeys) { $hotkeys.Dispose() }
$notify.Dispose()
$mutex.ReleaseMutex()
