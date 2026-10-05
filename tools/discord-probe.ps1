# Collects what is needed to find which AtlasOS tweak breaks Discord ("Attempt to install host that is
# currently running"). Run it as the normal user (not as administrator) on a PC where Discord was installed
# and started once, on stock Windows and on Akati OS, then compare the two reports.
#
#   irm https://raw.githubusercontent.com/x2Swiftyouz/Akati-Os/claude/akati-os-playbook-ua7w3f/tools/discord-probe.ps1 | iex
#
# The report is saved to the VMware shared Downloads folder if there is one, otherwise to the Desktop.
# It only reads; it changes nothing.

$ErrorActionPreference = 'SilentlyContinue'
$out = New-Object System.Collections.Generic.List[string]
function Add([string]$title, $value) {
    $out.Add("=== $title")
    if ($null -eq $value) { $out.Add('(none)') } else { $out.Add(($value | Out-String -Width 250).TrimEnd()) }
    $out.Add('')
}
function Reg($path, $name) { (Get-ItemProperty -Path $path -Name $name).$name }

$os = Get-CimInstance Win32_OperatingSystem
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
Add 'System' ([ordered]@{
    Windows = "$($os.Caption) $($os.Version)"
    AkatiOS = Reg 'HKLM:\SOFTWARE\AkatiOS' 'Version'
    User = "$env:USERDOMAIN\$env:USERNAME"
    RunningAsAdmin = $isAdmin
    LocalAppData = $env:LOCALAPPDATA
    Temp = $env:TEMP
})

# Settings that AtlasOS changes and that could affect an installer or updater
$fs = 'HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem'
$uac = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System'
Add 'Settings' ([ordered]@{
    LongPathsEnabled = Reg $fs 'LongPathsEnabled'
    NtfsDisable8dot3NameCreation = Reg $fs 'NtfsDisable8dot3NameCreation'
    NtfsDisableLastAccessUpdate = Reg $fs 'NtfsDisableLastAccessUpdate'
    FTH = Reg 'HKLM:\SOFTWARE\Microsoft\FTH' 'Enabled'
    PCA_DisableEngine = Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\AppCompat' 'DisableEngine'
    PCA_AITEnable = Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\AppCompat' 'AITEnable'
    SvcHostSplitThresholdInKB = Reg 'HKLM:\SYSTEM\CurrentControlSet\Control' 'SvcHostSplitThresholdInKB'
    Win32PrioritySeparation = Reg 'HKLM:\SYSTEM\CurrentControlSet\Control\PriorityControl' 'Win32PrioritySeparation'
    EnableLUA = Reg $uac 'EnableLUA'
    ConsentPromptBehaviorAdmin = Reg $uac 'ConsentPromptBehaviorAdmin'
    PromptOnSecureDesktop = Reg $uac 'PromptOnSecureDesktop'
    BackgroundApps = Reg 'HKCU:\Software\Microsoft\Windows\CurrentVersion\BackgroundAccessApplications' 'GlobalUserDisabled'
    LetAppsRunInBackground = Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\AppPrivacy' 'LetAppsRunInBackground'
})
Add 'fsutil 8dot3name' (& fsutil.exe 8dot3name query C: 2>&1)
Add 'System mitigations' (Get-ProcessMitigation -System | Select-Object DEP, ASLR, CFG, SEHOP, Heap | Format-List | Out-String)
Add 'Services AtlasOS disables' (Get-Service -Name OneSyncSvc*, TrkWks, PcaSvc, DiagTrack, WerSvc, wercplsupport, NetBT, BITS, WinHttpAutoProxySvc, CryptSvc |
    Select-Object Name, Status, StartType | Format-Table -AutoSize)

# Discord itself
$local = Join-Path $env:LOCALAPPDATA 'Discord'
$roaming = Join-Path $env:APPDATA 'discord'
Add 'Discord install folder' (Get-ChildItem $local -Force | Select-Object Mode, Length, LastWriteTime, Name | Format-Table -AutoSize)
Add 'Discord app folders' (Get-ChildItem $local -Directory -Filter 'app-*' | ForEach-Object { "$($_.Name): $((Get-ChildItem $_.FullName -Recurse -File).Count) files" })
Add 'Discord packages' (Get-ChildItem (Join-Path $local 'packages') -Force | Select-Object Length, Name | Format-Table -AutoSize)
Add 'Discord RELEASES' (Get-Content (Join-Path $local 'packages\RELEASES'))
Add 'Discord data folder' (Get-ChildItem $roaming -Force | Select-Object Mode, Length, LastWriteTime, Name | Format-Table -AutoSize)
Add 'Discord .db and .json files' (Get-ChildItem $local, $roaming -Recurse -Force -Include *.db, *.db-*, settings.json, *.json -Depth 2 |
    Select-Object Length, LastWriteTime, FullName | Format-Table -AutoSize)
Add 'Discord uninstall registry' (Get-ItemProperty 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\Discord' |
    Select-Object DisplayName, DisplayVersion, InstallLocation, UninstallString | Format-List | Out-String)
Add 'Discord processes' (Get-Process Discord, Update | Select-Object Id, Name, Path, StartTime | Format-Table -AutoSize)

# Discord logs: the last lines, and every line that mentions the updater or an error
foreach ($log in Get-ChildItem $local, $roaming -Recurse -Force -Include *.log -Depth 3) {
    $lines = Get-Content $log.FullName
    $out.Add("=== Log $($log.FullName) ($($log.Length) bytes)")
    $out.AddRange([string[]]@($lines | Select-String -Pattern 'error|fail|host|inconsistent|updater|install' | Select-Object -Last 40 | ForEach-Object { "  ! $($_.Line)" }))
    $out.Add('  --- last lines:')
    $out.AddRange([string[]]@($lines | Select-Object -Last 25 | ForEach-Object { "  $_" }))
    $out.Add('')
}

$name = "discord-probe-$env:COMPUTERNAME-$(Get-Date -Format 'yyyyMMdd-HHmmss').txt"
$dir = '\\vmware-host\Shared Folders\Downloads'
if (!(Test-Path $dir)) { $dir = [Environment]::GetFolderPath('Desktop') }
$file = Join-Path $dir $name
$out | Set-Content -Path $file -Encoding UTF8
Write-Host "Report saved: $file" -ForegroundColor Green
