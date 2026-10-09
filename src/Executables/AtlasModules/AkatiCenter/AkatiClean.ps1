<#
.SYNOPSIS
    Akati OS cleaner: the list of junk files (dot-sourced by AkatiCenter.ps1) and the weekly automatic clean.
.DESCRIPTION
    -CleanNow       cleans the items that are ticked by default in Akati OS Center (not the browser and shader
                    caches, not the Recycle Bin) and saves the date and the freed space in
                    HKCU\Software\AkatiOS\Center (AutoCleanLast, AutoCleanBytes)
    -RegisterTask   (administrator) the task "\AkatiOS\Akati OS clean": every Sunday at 12:00 as the signed-in user,
                    or as soon as the PC is on after that time
    -RemoveTask     removes the task
#>
param (
    [switch]$CleanNow,
    [switch]$RegisterTask,
    [switch]$RemoveTask
)
if (!$windir) { $windir = [Environment]::GetFolderPath('Windows') }

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
    # Shader caches of DirectX and the graphics drivers: the games build them again (the first minutes stutter a little),
    # which fixes stutter and graphics errors after a driver update
    @{ Key = 'shaders'; Glyph = [char]0xE7F4; Off = $true
       Folders = @((Join-Path $env:LOCALAPPDATA 'D3DSCache'), (Join-Path $env:LOCALAPPDATA 'NVIDIA\DXCache'), (Join-Path $env:LOCALAPPDATA 'NVIDIA\GLCache'),
                   (Join-Path $env:USERPROFILE 'AppData\LocalLow\NVIDIA\PerDriverVersion\DXCache'), (Join-Path $env:USERPROFILE 'AppData\LocalLow\NVIDIA\PerDriverVersion\GLCache'),
                   (Join-Path $env:ProgramData 'NVIDIA Corporation\NV_Cache'),
                   (Join-Path $env:LOCALAPPDATA 'AMD\DxCache'), (Join-Path $env:LOCALAPPDATA 'AMD\DxcCache'), (Join-Path $env:LOCALAPPDATA 'AMD\GLCache'),
                   (Join-Path $env:LOCALAPPDATA 'AMD\VkCache'), (Join-Path $env:LOCALAPPDATA 'Intel\ShaderCache')) }
    @{ Key = 'recycle'; Glyph = [char]0xE74D; Recycle = $true }
)

# Size of each item
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

# Deletes what the items list (used by Akati OS Center and -CleanNow)
$cleanWork = {
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
}

if ($RegisterTask) {
    # The reason of a failure is printed (Akati OS Center shows it) and written to %ProgramData%\AkatiOS\AkatiClean.log
    try {
        $ps = Join-Path $windir 'System32\WindowsPowerShell\v1.0\powershell.exe'
        $action = New-ScheduledTaskAction -Execute $ps -Argument "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$PSCommandPath`" -CleanNow"
        $trigger = New-ScheduledTaskTrigger -Weekly -DaysOfWeek Sunday -At ([datetime]::Today.AddHours(12))
        $user = [Security.Principal.WindowsIdentity]::GetCurrent().Name
        $principal = New-ScheduledTaskPrincipal -UserId $user -LogonType Interactive -RunLevel Highest
        $settings = New-ScheduledTaskSettingsSet -StartWhenAvailable -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -ExecutionTimeLimit (New-TimeSpan -Hours 1)
        Register-ScheduledTask -TaskPath '\AkatiOS\' -TaskName 'Akati OS clean' -Action $action -Trigger $trigger -Principal $principal -Settings $settings -Force -ErrorAction Stop | Out-Null
        exit 0
    } catch {
        $message = "Akati OS clean task: $($_.Exception.Message)"
        try {
            $dir = Join-Path $env:ProgramData 'AkatiOS'
            if (!(Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
            Add-Content -Path (Join-Path $dir 'AkatiClean.log') -Value "$(Get-Date -Format s) $message"
        } catch { }
        Write-Output $message
        exit 1
    }
}
if ($RemoveTask) {
    Unregister-ScheduledTask -TaskPath '\AkatiOS\' -TaskName 'Akati OS clean' -Confirm:$false -ErrorAction SilentlyContinue
    return
}
if ($CleanNow) {
    $items = @($cleanItems | Where-Object { !$_.Off -and !$_.Recycle })
    $before = & $measureWork $items
    & $cleanWork $items
    $after = & $measureWork $items
    $freed = 0
    foreach ($k in $before.Keys) { $freed += [Math]::Max(0, [double]$before[$k] - [double]$after[$k]) }
    $key = 'HKCU:\Software\AkatiOS\Center'
    if (!(Test-Path $key)) { New-Item -Path $key -Force | Out-Null }
    Set-ItemProperty -Path $key -Name AutoCleanLast -Value (Get-Date).ToString('s') -Force
    Set-ItemProperty -Path $key -Name AutoCleanBytes -Value ([string][long]$freed) -Force
}
