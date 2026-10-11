<#
.SYNOPSIS
    Akati OS Center and the icon next to the clock (AkatiTray.ps1): code both use, without windows. The switches
    the signed-in user can change without administrator rights, the game profile state, the change history and
    the check for what Windows Update turned back on.
    Dot-sourced by AkatiCenter.ps1 and AkatiTray.ps1, after AkatiCenter.logic.ps1. Also loaded in background work.
#>
$sharedKey = 'HKCU:\Software\AkatiOS\Center'
function Read-RegValue($path, $name) { (Get-ItemProperty -Path $path -Name $name -ErrorAction SilentlyContinue).$name }

# ---------------------------------------------------------------------------------------------
# Switches in HKCU: the same Get and Set as on the Tweaks page (AkatiCenter.tweaks.ps1 uses these blocks), so the
# icon next to the clock, which runs as the user without administrator rights, can set them for a game profile
# ---------------------------------------------------------------------------------------------
$userTweaks = [ordered]@{
    gamemode = @{
        Get = { (Read-RegValue 'HKCU:\Software\Microsoft\GameBar' 'AutoGameModeEnabled') -ne 0 }
        Set = { param($on)
                if (!(Test-Path 'HKCU:\Software\Microsoft\GameBar')) { New-Item -Path 'HKCU:\Software\Microsoft\GameBar' -Force | Out-Null }
                Set-ItemProperty -Path 'HKCU:\Software\Microsoft\GameBar' -Name AutoGameModeEnabled -Value $(if ($on) { 1 } else { 0 }) -Type DWord -Force } }
    windowed = @{
        Get = { (Read-RegValue 'HKCU:\Software\Microsoft\DirectX\UserGpuPreferences' 'DirectXUserGlobalSettings') -match 'SwapEffectUpgradeEnable=1' }
        Set = { param($on)
                $dx = 'HKCU:\Software\Microsoft\DirectX\UserGpuPreferences'
                if (!(Test-Path $dx)) { New-Item -Path $dx -Force | Out-Null }
                $parts = @((Read-RegValue $dx 'DirectXUserGlobalSettings') -split ';' | Where-Object { $_ -and $_ -notlike 'SwapEffectUpgradeEnable=*' })
                $parts += "SwapEffectUpgradeEnable=$(if ($on) { 1 } else { 0 })"
                Set-ItemProperty -Path $dx -Name DirectXUserGlobalSettings -Value (($parts -join ';') + ';') -Type String -Force } }
    mouseaccel = @{
        Get = { (Read-RegValue 'HKCU:\Control Panel\Mouse' 'MouseSpeed') -ne '0' }
        Set = { param($on)
                $v = if ($on) { '1', '6', '10' } else { '0', '0', '0' }
                Set-ItemProperty -Path 'HKCU:\Control Panel\Mouse' -Name MouseSpeed -Value $v[0] -Type String -Force
                Set-ItemProperty -Path 'HKCU:\Control Panel\Mouse' -Name MouseThreshold1 -Value $v[1] -Type String -Force
                Set-ItemProperty -Path 'HKCU:\Control Panel\Mouse' -Name MouseThreshold2 -Value $v[2] -Type String -Force
                # Applies now, not only after the next sign-in (SPI_SETMOUSE)
                if (!('AkatiOS.Mouse' -as [type])) { Add-Type -Namespace AkatiOS -Name Mouse -MemberDefinition '[DllImport("user32.dll")] public static extern bool SystemParametersInfo(int action, int param, int[] values, int flags);' }
                [void][AkatiOS.Mouse]::SystemParametersInfo(4, 0, [int[]]@([int]$v[1], [int]$v[2], [int]$v[0]), 3) } }
    ducking = @{
        Get = { (Read-RegValue 'HKCU:\Software\Microsoft\Multimedia\Audio' 'UserDuckingPreference') -ne 3 }
        Set = { param($on)
                if ($on) { Remove-ItemProperty -Path 'HKCU:\Software\Microsoft\Multimedia\Audio' -Name UserDuckingPreference -ErrorAction SilentlyContinue }
                else {
                    if (!(Test-Path 'HKCU:\Software\Microsoft\Multimedia\Audio')) { New-Item -Path 'HKCU:\Software\Microsoft\Multimedia\Audio' -Force | Out-Null }
                    Set-ItemProperty -Path 'HKCU:\Software\Microsoft\Multimedia\Audio' -Name UserDuckingPreference -Value 3 -Type DWord -Force
                } } }
    keydelay = @{
        Get = { (Read-RegValue 'HKCU:\Control Panel\Keyboard' 'KeyboardDelay') -eq '0' }
        Set = { param($on) Set-ItemProperty -Path 'HKCU:\Control Panel\Keyboard' -Name KeyboardDelay -Value $(if ($on) { '0' } else { '1' }) -Type String -Force } }
    startdelay = @{
        Get = { (Read-RegValue 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Serialize' 'StartupDelayInMSec') -ne 0 }
        Set = { param($on)
                $sk = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Serialize'
                if ($on) { Remove-ItemProperty -Path $sk -Name StartupDelayInMSec, WaitForIdleState -ErrorAction SilentlyContinue }
                else {
                    if (!(Test-Path $sk)) { New-Item -Path $sk -Force | Out-Null }
                    Set-ItemProperty -Path $sk -Name StartupDelayInMSec -Value 0 -Type DWord -Force
                    Set-ItemProperty -Path $sk -Name WaitForIdleState -Value 0 -Type DWord -Force
                } } }
}

# The change history of the Health page: the last 30 changes, newest first ("time|key|state")
function Add-HistoryLine([string]$key, [string]$state) {
    try {
        if (!(Test-Path $sharedKey)) { New-Item -Path $sharedKey -Force | Out-Null }
        $list = @("$((Get-Date).ToString('s'))|$key|$state") + @(Read-RegValue $sharedKey 'History' | Where-Object { $_ })
        Set-ItemProperty -Path $sharedKey -Name History -Value ([string[]]@($list | Select-Object -First 30)) -Type MultiString -Force
    } catch { }
}

# ---------------------------------------------------------------------------------------------
# Game profile state (setting GameTweaks, see ConvertFrom-GameTweakState): kept until the game closes, so a crash or a
# restart can still put the switches back when Akati OS Center or the icon next to the clock starts
# ---------------------------------------------------------------------------------------------
function Get-GameTweakState { ConvertFrom-GameTweakState ([string](Read-RegValue $sharedKey 'GameTweaks')) }
function Save-GameTweakState($state) {
    try {
        if ($null -eq $state -or !$state.Prev.Count) { Remove-ItemProperty -Path $sharedKey -Name GameTweaks -ErrorAction SilentlyContinue; return }
        if (!(Test-Path $sharedKey)) { New-Item -Path $sharedKey -Force | Out-Null }
        Set-ItemProperty -Path $sharedKey -Name GameTweaks -Value (ConvertTo-GameTweakState $state.By $state.Time $state.Path $state.Prev) -Type String -Force
    } catch { }
}
# A game of My games is running (FiveM.exe starts the game as FiveM_<build>_GTAProcess.exe)
function Test-GameRunning([string]$path) {
    $name = [IO.Path]::GetFileNameWithoutExtension($path)
    $names = @($name); if ($name -eq 'FiveM') { $names += 'FiveM_*GTAProcess' }
    [bool](Get-Process -Name $names -ErrorAction SilentlyContinue | Select-Object -First 1)
}

# ---------------------------------------------------------------------------------------------
# After Windows Update: the policies in the baseline (ConvertFrom-WuEntry) and reading the current state of the
# baseline entries. Only reads; works without administrator rights (the icon next to the clock checks once a week).
# ---------------------------------------------------------------------------------------------
$wuPolicies = [ordered]@{
    telemetry = @{ Path = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection'; Name = 'AllowTelemetry'; Value = 0 }
    adid      = @{ Path = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\AdvertisingInfo'; Name = 'DisabledByGroupPolicy'; Value = 1 }
    activity  = @{ Path = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\System'; Name = 'EnableActivityFeed'; Value = 0 }
    copilot   = @{ Path = 'HKCU:\Software\Policies\Microsoft\Windows\WindowsCopilot'; Name = 'TurnOffWindowsCopilot'; Value = 1; Atlas = 'AI Features\Microsoft Copilot' }
    recall    = @{ Path = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsAI'; Name = 'DisableAIDataAnalysis'; Value = 1; Atlas = 'AI Features\Recall' }
    tailored  = @{ Path = 'HKCU:\Software\Policies\Microsoft\Windows\CloudContent'; Name = 'DisableTailoredExperiencesWithDiagnosticData'; Value = 1 }
}
# Apps that can be removed without being in the AtlasOS list (the "Remove Microsoft Store" setup option)
$wuExtraApps = @('Microsoft.WindowsStore')
function Get-InstalledAppNames {
    $names = @{}
    # Some trimmed Windows builds cannot load the Appx module: then no app counts as installed (nothing is listed)
    try { foreach ($a in @(Get-AppxPackage -ErrorAction Stop)) { $names[[string]$a.Name] = $true } } catch { }
    $names
}
# key -> current value as text: a service start type ('' when the service is missing), '1' / '0' for an installed app,
# a policy value ('' when missing)
function Read-WuCurrent([string[]]$baseline) {
    $now = @{}; $apps = $null
    foreach ($e in @($baseline)) {
        $p = ConvertFrom-WuEntry $e
        if (!$p) { continue }
        switch ($p.Kind) {
            'svc' { $v = Read-RegValue "HKLM:\SYSTEM\CurrentControlSet\Services\$($p.Id)" 'Start'; $now[$p.Key] = if ($null -eq $v) { '' } else { [string]$v } }
            'pol' { $d = $wuPolicies[$p.Id]; $v = if ($d) { Read-RegValue $d.Path $d.Name } else { $null }; $now[$p.Key] = if ($null -eq $v) { '' } else { [string]$v } }
            'app' { if ($null -eq $apps) { $apps = Get-InstalledAppNames }; $now[$p.Key] = if ($apps.ContainsKey($p.Id)) { '1' } else { '0' } }
        }
    }
    $now
}
# The first baseline: the services of $services that are turned off now, the apps the setup removed (AtlasOS lists
# them under AppxAllUserStore\Deprovisioned, so Windows does not install them for new users) and are still not
# installed, and the policies that have the Akati OS value now
function New-WuBaseline([string[]]$services) {
    $list = New-Object System.Collections.ArrayList
    foreach ($s in @($services | Select-Object -Unique)) {
        if ((Read-RegValue "HKLM:\SYSTEM\CurrentControlSet\Services\$s" 'Start') -eq 4) { [void]$list.Add("svc:$s=4") }
    }
    $apps = Get-InstalledAppNames
    $removed = @(Get-ChildItem -Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Appx\AppxAllUserStore\Deprovisioned' -ErrorAction SilentlyContinue | ForEach-Object { ($_.PSChildName -split '_')[0] }) + $wuExtraApps
    foreach ($name in @($removed | Select-Object -Unique)) {
        if ($name -match '^[\w.\-]+$' -and !$apps.ContainsKey($name)) { [void]$list.Add("app:$name") }
    }
    foreach ($id in $wuPolicies.Keys) {
        $d = $wuPolicies[$id]; $v = Read-RegValue $d.Path $d.Name
        if ($null -ne $v -and [string]$v -eq [string]$d.Value) { [void]$list.Add("pol:$id=$($d.Value)") }
    }
    , [string[]]@($list)
}
