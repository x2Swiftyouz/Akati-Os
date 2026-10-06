<#
.SYNOPSIS
    Akati OS desktop menu: right-click the desktop > Akati OS.
.DESCRIPTION
    -Install   (administrator) builds the menu in HKLM\SOFTWARE\Classes\DesktopBackground\Shell\AkatiOS and
               registers the task "\AkatiOS\Akati OS menu" for the signed-in user (highest rights), so the
               items that need administrator rights run without a UAC prompt. Setup and Akati OS Center run it.
    -Remove    (administrator) removes the menu and the task.
    -Action    one menu item, run as the user: freeram, boost, bios, flushdns, explorer.
    -Elevated  started by the task: runs the item saved in HKCU\Software\AkatiOS\Center\MenuAction. Only the
               fixed items freeram, boost and bios are accepted.
    Menu texts follow the language of Akati OS Center. "My apps" lists what Akati OS Center saved in
    HKCU\Software\AkatiOS\Center\MenuApps (installed gaming apps) and the games in "My games".
#>
param (
    [switch]$Install,
    [switch]$Remove,
    [string]$Action,
    [switch]$Elevated
)

$windir    = [Environment]::GetFolderPath('Windows')
$appDir    = $PSScriptRoot
$center    = Join-Path $appDir 'AkatiCenter.ps1'
$icon      = Join-Path $windir 'AtlasModules\Other\akatios-folder.ico'
$ps        = Join-Path $windir 'System32\WindowsPowerShell\v1.0\powershell.exe'
$menuKey   = 'HKLM:\SOFTWARE\Classes\DesktopBackground\Shell\AkatiOS'
$userKey   = 'HKCU:\Software\AkatiOS\Center'
$taskPath  = '\AkatiOS\'
$taskName  = 'Akati OS menu'

$lang = try { (Get-ItemProperty -Path $userKey -Name Language -ErrorAction Stop).Language } catch { 'en' }
$texts = @{
    en = @{
        root = 'Akati OS'; freeram = 'Free up RAM'; center = 'Open Akati OS Center'; apps = 'My apps'; appsmore = 'Gaming apps...'
        boostOn = 'Stop Game boost'; boostOff = 'Start Game boost'; clean = 'Clean junk files'; flushdns = 'Flush DNS cache'
        explorer = 'Restart Explorer'; ping = 'Ping test'; bios = 'Restart into BIOS (UEFI)'
        freed = 'Freed {0} of RAM'; dnsdone = 'DNS cache cleared'; biosask = 'Restart now and open the BIOS (UEFI) settings? Save your work first.'
        biosfail = 'This PC cannot restart into the BIOS from Windows (needs UEFI).'; failed = 'Did not work: {0}'
        boostStarted = 'Game boost on'; boostStopped = 'Game boost off'
    }
    th = @{
        root = 'Akati OS'; freeram = 'ล้าง RAM'; center = 'เปิด Akati OS Center'; apps = 'แอปของฉัน'; appsmore = 'แอปเกม...'
        boostOn = 'หยุดบูสต์เกม'; boostOff = 'เริ่มบูสต์เกม'; clean = 'ล้างไฟล์ขยะ'; flushdns = 'ล้าง DNS cache'
        explorer = 'รีสตาร์ต Explorer'; ping = 'ทดสอบปิง'; bios = 'รีสตาร์ตเข้า BIOS (UEFI)'
        freed = 'คืน RAM ได้ {0}'; dnsdone = 'ล้าง DNS cache แล้ว'; biosask = 'รีสตาร์ตตอนนี้แล้วเข้าหน้าตั้งค่า BIOS (UEFI) ใช่ไหม บันทึกงานก่อน'
        biosfail = 'เครื่องนี้รีสตาร์ตเข้า BIOS จาก Windows ไม่ได้ (ต้องเป็น UEFI)'; failed = 'ไม่สำเร็จ: {0}'
        boostStarted = 'เปิดบูสต์เกมแล้ว'; boostStopped = 'ปิดบูสต์เกมแล้ว'
    }
}
if (!$texts.ContainsKey($lang)) { $lang = 'en' }
function T([string]$key) { $texts[$lang][$key] }

function Format-Size([double]$bytes) {
    if ($bytes -ge 1GB) { return '{0:N1} GB' -f ($bytes / 1GB) }
    return '{0:N0} MB' -f ($bytes / 1MB)
}

# A small message near the bottom right that closes by itself (notifications may be turned off)
function Show-Note([string]$text) {
    Add-Type -AssemblyName System.Windows.Forms, System.Drawing
    $form = New-Object System.Windows.Forms.Form
    $form.FormBorderStyle = 'None'; $form.ShowInTaskbar = $false; $form.TopMost = $true; $form.StartPosition = 'Manual'
    $form.BackColor = [System.Drawing.Color]::FromArgb(44, 44, 46); $form.Opacity = 0.96
    $label = New-Object System.Windows.Forms.Label
    $label.Text = $text; $label.AutoSize = $true; $label.ForeColor = [System.Drawing.Color]::White
    $label.Font = New-Object System.Drawing.Font('Segoe UI', 11); $label.Padding = '18,12,18,12'
    $form.Controls.Add($label)
    $form.AutoSize = $true; $form.AutoSizeMode = 'GrowAndShrink'
    $area = [System.Windows.Forms.Screen]::PrimaryScreen.WorkingArea
    $form.Add_Shown({ $this.Location = New-Object System.Drawing.Point ($area.Right - $this.Width - 16), ($area.Bottom - $this.Height - 16) })
    $timer = New-Object System.Windows.Forms.Timer
    $timer.Interval = 2200; $timer.Add_Tick({ $form.Close() }); $timer.Start()
    [void]$form.ShowDialog()
}

function New-PsCommand([string]$arguments) { "`"$ps`" -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden $arguments" }

# Builds the whole menu again (texts, Game boost state, apps)
function Build-Menu {
    if (Test-Path $menuKey) { Remove-Item -Path $menuKey -Recurse -Force }
    New-Item -Path "$menuKey\shell" -Force | Out-Null
    Set-ItemProperty -Path $menuKey -Name MUIVerb -Value (T 'root')
    Set-ItemProperty -Path $menuKey -Name Icon -Value $icon
    Set-ItemProperty -Path $menuKey -Name SubCommands -Value ''
    $boostOn = [bool](Get-ItemProperty -Path "$userKey\Boost" -Name Active -ErrorAction SilentlyContinue).Active
    $centerCmd = New-PsCommand "-File `"$center`""
    $menuCmd = New-PsCommand "-File `"$PSCommandPath`""
    # Name, text, command, icon, separator before
    $items = @(
        @('01freeram',  (T 'freeram'),  "$menuCmd -Action freeram",  $null, $false)
        @('02center',   (T 'center'),   $centerCmd,                  $icon, $false)
        @('03apps',     (T 'apps'),     $null,                       $null, $false)
        @('04boost',    $(if ($boostOn) { T 'boostOn' } else { T 'boostOff' }), "$menuCmd -Action boost", $null, $true)
        @('05clean',    (T 'clean'),    "$centerCmd -Page cleaner",  $null, $false)
        @('06ping',     (T 'ping'),     "$centerCmd -Page boost -Ping", $null, $false)
        @('07flushdns', (T 'flushdns'), "$menuCmd -Action flushdns", $null, $true)
        @('08explorer', (T 'explorer'), "$menuCmd -Action explorer", $null, $false)
        @('09bios',     (T 'bios'),     "$menuCmd -Action bios",     $null, $true)
    )
    foreach ($i in $items) {
        $key = "$menuKey\shell\$($i[0])"
        New-Item -Path $key -Force | Out-Null
        Set-ItemProperty -Path $key -Name MUIVerb -Value $i[1]
        if ($i[3]) { Set-ItemProperty -Path $key -Name Icon -Value $i[3] }
        if ($i[4]) { Set-ItemProperty -Path $key -Name CommandFlags -Value 0x20 -Type DWord }   # separator before
        if ($i[2]) { New-Item -Path "$key\command" -Force | Out-Null; Set-ItemProperty -Path "$key\command" -Name '(default)' -Value $i[2] }
    }
    # My apps: installed gaming apps (saved by Akati OS Center as "name|command|icon") and My games
    $apps = "$menuKey\shell\03apps"
    Set-ItemProperty -Path $apps -Name SubCommands -Value ''
    New-Item -Path "$apps\shell" -Force | Out-Null
    $list = @((Get-ItemProperty -Path $userKey -Name MenuApps -ErrorAction SilentlyContinue).MenuApps)
    $games = @(if (Test-Path "$userKey\Games") { (Get-Item "$userKey\Games").Property })
    foreach ($g in $games) {
        if (Test-Path -LiteralPath $g) { $list += '{0}|"{1}"|{1}' -f [IO.Path]::GetFileNameWithoutExtension($g), $g }
    }
    $n = 0
    foreach ($entry in $list) {
        if (!$entry) { continue }
        $name, $command, $appIcon = $entry -split '\|', 3
        $n++
        $key = "$apps\shell\{0:D2}" -f $n
        New-Item -Path "$key\command" -Force | Out-Null
        Set-ItemProperty -Path $key -Name MUIVerb -Value $name
        if ($appIcon) { Set-ItemProperty -Path $key -Name Icon -Value $appIcon }
        Set-ItemProperty -Path "$key\command" -Name '(default)' -Value $command
    }
    $key = "$apps\shell\99more"
    New-Item -Path "$key\command" -Force | Out-Null
    Set-ItemProperty -Path $key -Name MUIVerb -Value (T 'appsmore')
    Set-ItemProperty -Path $key -Name Icon -Value $icon
    if ($n) { Set-ItemProperty -Path $key -Name CommandFlags -Value 0x20 -Type DWord }
    Set-ItemProperty -Path "$key\command" -Name '(default)' -Value "$centerCmd -Page gaming"
}

# The task that runs the items needing administrator rights, for the signed-in user, without a UAC prompt
function Register-MenuTask {
    $user = "$env:USERDOMAIN\$env:USERNAME"
    $action = New-ScheduledTaskAction -Execute $ps -Argument "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$PSCommandPath`" -Elevated"
    $principal = New-ScheduledTaskPrincipal -UserId $user -LogonType Interactive -RunLevel Highest
    $settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -ExecutionTimeLimit (New-TimeSpan -Minutes 2) -MultipleInstances IgnoreNew
    Register-ScheduledTask -TaskPath $taskPath -TaskName $taskName -Action $action -Principal $principal -Settings $settings -Force | Out-Null
}

# Runs an item through the task and waits for its message
function Invoke-Elevated([string]$item) {
    New-Item -Path $userKey -Force -ErrorAction SilentlyContinue | Out-Null
    Set-ItemProperty -Path $userKey -Name MenuAction -Value $item
    Remove-ItemProperty -Path $userKey -Name MenuResult -ErrorAction SilentlyContinue
    & schtasks.exe /run /tn "$taskPath$taskName" *> $null
    $deadline = (Get-Date).AddSeconds(30)
    do {
        Start-Sleep -Milliseconds 300
        $result = (Get-ItemProperty -Path $userKey -Name MenuResult -ErrorAction SilentlyContinue).MenuResult
    } while (!$result -and (Get-Date) -lt $deadline)
    if ($result) { Show-Note $result }
}

function Get-StandbyBytes {
    try {
        $m = Get-CimInstance Win32_PerfRawData_PerfOS_Memory -ErrorAction Stop
        [double]$m.StandbyCacheNormalPriorityBytes + [double]$m.StandbyCacheReserveBytes + [double]$m.StandbyCacheCoreBytes
    } catch { 0 }
}

if ($Install) { Build-Menu; Register-MenuTask; exit 0 }
if ($Remove) {
    Remove-Item -Path $menuKey -Recurse -Force -ErrorAction SilentlyContinue
    Unregister-ScheduledTask -TaskPath $taskPath -TaskName $taskName -Confirm:$false -ErrorAction SilentlyContinue
    exit 0
}

if ($Elevated) {
    $item = (Get-ItemProperty -Path $userKey -Name MenuAction -ErrorAction SilentlyContinue).MenuAction
    Remove-ItemProperty -Path $userKey -Name MenuAction -ErrorAction SilentlyContinue
    $result = $null
    switch ($item) {
        'freeram' {
            # Same as Game boost: empty the standby list (NtSetSystemInformation, MemoryPurgeStandbyList)
            Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
public static class AkatiMenuMemory {
    [StructLayout(LayoutKind.Sequential, Pack = 4)] struct TOKEN_PRIVILEGES { public int Count; public long Luid; public int Attributes; }
    [DllImport("advapi32.dll", SetLastError = true)] static extern bool OpenProcessToken(IntPtr process, int access, out IntPtr token);
    [DllImport("advapi32.dll", SetLastError = true, CharSet = CharSet.Unicode)] static extern bool LookupPrivilegeValue(string system, string name, out long luid);
    [DllImport("advapi32.dll", SetLastError = true)] static extern bool AdjustTokenPrivileges(IntPtr token, bool disableAll, ref TOKEN_PRIVILEGES state, int length, IntPtr previous, IntPtr returnLength);
    [DllImport("kernel32.dll")] static extern IntPtr GetCurrentProcess();
    [DllImport("kernel32.dll")] static extern bool CloseHandle(IntPtr handle);
    [DllImport("ntdll.dll")] static extern int NtSetSystemInformation(int infoClass, ref int info, int length);
    public static int Purge() {
        IntPtr token;
        if (!OpenProcessToken(GetCurrentProcess(), 0x28, out token)) return -1;
        try {
            TOKEN_PRIVILEGES tp = new TOKEN_PRIVILEGES();
            tp.Count = 1; tp.Attributes = 2;
            if (!LookupPrivilegeValue(null, "SeProfileSingleProcessPrivilege", out tp.Luid)) return -2;
            if (!AdjustTokenPrivileges(token, false, ref tp, 0, IntPtr.Zero, IntPtr.Zero)) return -3;
        } finally { CloseHandle(token); }
        int command = 4;
        return NtSetSystemInformation(80, ref command, 4);
    }
}
'@
            $before = Get-StandbyBytes
            $status = [AkatiMenuMemory]::Purge()
            $result = if ($status -eq 0) { (T 'freed') -f (Format-Size ([Math]::Max(0, $before - (Get-StandbyBytes)))) } else { (T 'failed') -f $status }
        }
        'boost' {
            # Akati OS Center starts or stops Game boost without opening its window, and writes MenuResult
            & $ps -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File $center -ToggleBoost
            Build-Menu
        }
        'bios' {
            & shutdown.exe /r /fw /t 0 *> $null
            if ($LASTEXITCODE -ne 0) { $result = T 'biosfail' }
        }
    }
    if ($result) { Set-ItemProperty -Path $userKey -Name MenuResult -Value $result }
    exit 0
}

switch ($Action) {
    'freeram'  { Invoke-Elevated 'freeram' }
    'boost'    { Invoke-Elevated 'boost' }
    'bios' {
        Add-Type -AssemblyName PresentationFramework
        if ([System.Windows.MessageBox]::Show((T 'biosask'), 'Akati OS', 'YesNo', 'Warning') -eq 'Yes') { Invoke-Elevated 'bios' }
    }
    'flushdns' {
        & ipconfig.exe /flushdns *> $null
        Show-Note $(if ($LASTEXITCODE -eq 0) { T 'dnsdone' } else { (T 'failed') -f $LASTEXITCODE })
    }
    'explorer' {
        # The same as the AtlasOS script "Restart Explorer.cmd"
        Stop-Process -Name explorer -Force -ErrorAction SilentlyContinue
        Start-Sleep -Milliseconds 800
        if (!(Get-Process -Name explorer -ErrorAction SilentlyContinue)) { Start-Process (Join-Path $windir 'explorer.exe') }
    }
}
