<#
.SYNOPSIS
    Akati OS Center: Tweaks: every switch reads the real state of the PC.
    Dot-sourced by AkatiCenter.ps1 (runs in its scope: $ui, $window, T and the other parts).
#>
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
    # The Gaming apps page reads the graphics cards in the background; read them here when that is not done yet
    if (!$script:gpusLoaded) { Set-Gpus (& $gpuQuery) }
    @($gpus | Where-Object { $_.PNPDeviceID -like 'PCI\*' } | ForEach-Object {
        "HKLM:\SYSTEM\CurrentControlSet\Enum\$($_.PNPDeviceID)\Device Parameters\Interrupt Management\MessageSignaledInterruptProperties" })
}
# Group: the section on the Tweaks page (none = Gaming). Script: an unchanged AtlasOS script in AtlasDesktop,
# run with /silent in the background. Work: a script block run in the background, param($on).
# Windows services Akati OS can turn off (Start = 4), each with its Windows default start type (2 automatic,
# 3 manual). extra: the setup option "disable-extra-services" and one switch; the others: one switch each.
# Services this Windows does not have are skipped, so no empty service keys are made.
$serviceGroups = @{
    extra    = [ordered]@{ AJRouter = 3; Fax = 3; MapsBroker = 2; PhoneSvc = 3; RetailDemo = 3; wisvc = 3; SCardSvr = 3; ScDeviceEnum = 3
                           SCPolicySvc = 3; WpcMonSvc = 3; SEMgrSvc = 3; WalletService = 3; WMPNetworkSvc = 3; TroubleshootingSvc = 3
                           dmwappushservice = 3; TermService = 3; SessionEnv = 3; UmRdpService = 3; WinRM = 3; CertPropSvc = 3
                           vmickvpexchange = 3; vmicguestinterface = 3; vmicshutdown = 3; vmicheartbeat = 3; vmicvmsession = 3
                           vmicrdv = 3; vmictimesync = 3; vmicvss = 3; edgeupdate = 2; edgeupdatem = 3 }
    xbox     = [ordered]@{ XblAuthManager = 3; XblGameSave = 3; XboxNetApiSvc = 3; XboxGipSvc = 3 }
    iphelper = @{ iphlpsvc = 2 }
    hello    = @{ WbioSrvc = 3 }
    scanner  = @{ stisvc = 3 }
    hotspot  = @{ SharedAccess = 3 }
    notify   = @{ WpnService = 2 }
    cdp      = @{ CDPSvc = 2 }
}
$servicesKey = 'HKLM:\SYSTEM\CurrentControlSet\Services'
$edgePolicyKey = 'HKLM:\SOFTWARE\Policies\Microsoft\Edge'
function Test-ServicesOff($group) {
    $found = @($group.Keys | Where-Object { Test-Path "$servicesKey\$_" })
    $found.Count -gt 0 -and !($found | Where-Object { (Get-RegValue "$servicesKey\$_" 'Start') -ne 4 })
}
function Set-ServicesOff($group, [bool]$off) {
    foreach ($name in $group.Keys) {
        if (Test-Path "$servicesKey\$name") { Set-ItemProperty -Path "$servicesKey\$name" -Name Start -Value $(if ($off) { 4 } else { $group[$name] }) -Type DWord -Force }
    }
}
$personalizeKey = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize'
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
    @{ Key = 'maxperf'; Glyph = [char]0xE945; Async = $true
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
    # Tweaks > Services: on = turned off from the next start, off = back to the Windows default start type
    @{ Key = 'extrasvc'; Group = 'services'; Glyph = [char]0xE912; Restart = $true; Default = $false
       Get = { Test-ServicesOff $serviceGroups.extra }; Set = { param($on) Set-ServicesOff $serviceGroups.extra $on } }
    @{ Key = 'svcxbox'; Group = 'services'; Glyph = [char]0xE7FC; Restart = $true; Default = $false
       Get = { Test-ServicesOff $serviceGroups.xbox }; Set = { param($on) Set-ServicesOff $serviceGroups.xbox $on } }
    @{ Key = 'svciphelper'; Group = 'services'; Glyph = [char]0xE968; Restart = $true; Default = $false
       Get = { Test-ServicesOff $serviceGroups.iphelper }; Set = { param($on) Set-ServicesOff $serviceGroups.iphelper $on } }
    @{ Key = 'svchello'; Group = 'services'; Glyph = [char]0xE928; Restart = $true; Default = $false
       Get = { Test-ServicesOff $serviceGroups.hello }; Set = { param($on) Set-ServicesOff $serviceGroups.hello $on } }
    @{ Key = 'svcscanner'; Group = 'services'; Glyph = [char]0xE722; Restart = $true; Default = $false
       Get = { Test-ServicesOff $serviceGroups.scanner }; Set = { param($on) Set-ServicesOff $serviceGroups.scanner $on } }
    @{ Key = 'svchotspot'; Group = 'services'; Glyph = [char]0xE88A; Restart = $true; Default = $false
       Get = { Test-ServicesOff $serviceGroups.hotspot }; Set = { param($on) Set-ServicesOff $serviceGroups.hotspot $on } }
    @{ Key = 'svcnotify'; Group = 'services'; Glyph = [char]0xEA8F; Restart = $true; Default = $false
       Get = { Test-ServicesOff $serviceGroups.notify }; Set = { param($on) Set-ServicesOff $serviceGroups.notify $on } }
    @{ Key = 'svccdp'; Group = 'services'; Glyph = [char]0xE8EA; Restart = $true; Default = $false
       Get = { Test-ServicesOff $serviceGroups.cdp }; Set = { param($on) Set-ServicesOff $serviceGroups.cdp $on } }
    # Microsoft Edge keeps running after its last window is closed (background mode) and starts with Windows to open
    # faster (startup boost). The two Edge policies turn both off; removing them gives the Edge defaults back.
    @{ Key = 'edgebg'; Group = 'services'; Glyph = [char]0xE774; Default = $false
       Get = { (Get-RegValue $edgePolicyKey 'StartupBoostEnabled') -eq 0 -and (Get-RegValue $edgePolicyKey 'BackgroundModeEnabled') -eq 0 }
       Set = { param($on)
               if ($on) {
                   if (!(Test-Path $edgePolicyKey)) { New-Item -Path $edgePolicyKey -Force | Out-Null }
                   Set-ItemProperty -Path $edgePolicyKey -Name StartupBoostEnabled -Value 0 -Type DWord -Force
                   Set-ItemProperty -Path $edgePolicyKey -Name BackgroundModeEnabled -Value 0 -Type DWord -Force
               } else { Remove-ItemProperty -Path $edgePolicyKey -Name StartupBoostEnabled, BackgroundModeEnabled -ErrorAction SilentlyContinue } } }
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
    # Read by the icon next to the clock (AkatiTray.ps1), which is restarted to pick up the change
    @{ Key = 'hotkeys'; Group = 'system'; Glyph = [char]0xE765; Default = $true
       Get = { (Get-RegValue $settingsKey 'Hotkeys') -ne 0 }
       Set = { param($on)
               Save-Setting Hotkeys ([int]$on)
               if (Get-ScheduledTask -TaskPath '\AkatiOS\' -TaskName 'Akati OS tray' -ErrorAction SilentlyContinue) {
                   Stop-ScheduledTask -TaskPath '\AkatiOS\' -TaskName 'Akati OS tray' -ErrorAction SilentlyContinue
                   Start-ScheduledTask -TaskPath '\AkatiOS\' -TaskName 'Akati OS tray' -ErrorAction SilentlyContinue
               } } }
    @{ Key = 'mouseaccel'; Group = 'latency'; Glyph = [char]0xE962; Default = $true
       Get = { (Get-RegValue 'HKCU:\Control Panel\Mouse' 'MouseSpeed') -ne '0' }
       Set = { param($on)
               $v = if ($on) { '1', '6', '10' } else { '0', '0', '0' }
               Set-ItemProperty -Path 'HKCU:\Control Panel\Mouse' -Name MouseSpeed -Value $v[0] -Type String -Force
               Set-ItemProperty -Path 'HKCU:\Control Panel\Mouse' -Name MouseThreshold1 -Value $v[1] -Type String -Force
               Set-ItemProperty -Path 'HKCU:\Control Panel\Mouse' -Name MouseThreshold2 -Value $v[2] -Type String -Force
               # Applies now, not only after the next sign-in (SPI_SETMOUSE)
               if (!('AkatiOS.Mouse' -as [type])) { Add-Type -Namespace AkatiOS -Name Mouse -MemberDefinition '[DllImport("user32.dll")] public static extern bool SystemParametersInfo(int action, int param, int[] values, int flags);' }
               [void][AkatiOS.Mouse]::SystemParametersInfo(4, 0, [int[]]@([int]$v[1], [int]$v[2], [int]$v[0]), 3) } }
    @{ Key = 'ducking'; Group = 'latency'; Glyph = [char]0xE767; Default = $true
       Get = { (Get-RegValue 'HKCU:\Software\Microsoft\Multimedia\Audio' 'UserDuckingPreference') -ne 3 }
       Set = { param($on)
               if ($on) { Remove-ItemProperty -Path 'HKCU:\Software\Microsoft\Multimedia\Audio' -Name UserDuckingPreference -ErrorAction SilentlyContinue }
               else {
                   if (!(Test-Path 'HKCU:\Software\Microsoft\Multimedia\Audio')) { New-Item -Path 'HKCU:\Software\Microsoft\Multimedia\Audio' -Force | Out-Null }
                   Set-ItemProperty -Path 'HKCU:\Software\Microsoft\Multimedia\Audio' -Name UserDuckingPreference -Value 3 -Type DWord -Force
               } } }
    @{ Key = 'keydelay'; Group = 'latency'; Glyph = [char]0xE92E; Default = $false
       Get = { (Get-RegValue 'HKCU:\Control Panel\Keyboard' 'KeyboardDelay') -eq '0' }
       Set = { param($on) Set-ItemProperty -Path 'HKCU:\Control Panel\Keyboard' -Name KeyboardDelay -Value $(if ($on) { '0' } else { '1' }) -Type String -Force } }
    @{ Key = 'widget'; Group = 'system'; Glyph = [char]0xE9D9; Default = $false
       Get = { (Get-RegValue $settingsKey 'Widget') -eq 1 }
       Set = { param($on)
               $running = @(Get-CimInstance Win32_Process -Filter "Name='powershell.exe'" -ErrorAction SilentlyContinue | Where-Object { $_.CommandLine -like '*AkatiWidget.ps1*' })
               if ($on -and !$running.Count) { Start-Process -FilePath powershell.exe -ArgumentList "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$(Join-Path $appDir 'AkatiWidget.ps1')`"" -WindowStyle Hidden }
               if (!$on) { $running | ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue } }
               Save-Setting Widget ([int]$on) } }
    @{ Key = 'darkmode'; Group = 'looks'; Glyph = [char]0xE708; Default = $false
       Get = { (Get-RegValue $personalizeKey 'AppsUseLightTheme') -eq 0 }
       Set = { param($on)
               if (!(Test-Path $personalizeKey)) { New-Item -Path $personalizeKey -Force | Out-Null }
               Set-ItemProperty -Path $personalizeKey -Name AppsUseLightTheme -Value ([int]!$on) -Type DWord -Force
               Set-ItemProperty -Path $personalizeKey -Name SystemUsesLightTheme -Value ([int]!$on) -Type DWord -Force
               Send-SettingChange 'ImmersiveColorSet' } }
    @{ Key = 'accentbars'; Group = 'looks'; Glyph = [char]0xE790; Default = $false
       Get = { (Get-RegValue 'HKCU:\Software\Microsoft\Windows\DWM' 'ColorPrevalence') -eq 1 }
       Set = { param($on)
               Set-ItemProperty -Path 'HKCU:\Software\Microsoft\Windows\DWM' -Name ColorPrevalence -Value ([int]$on) -Type DWord -Force
               if (!(Test-Path $personalizeKey)) { New-Item -Path $personalizeKey -Force | Out-Null }
               Set-ItemProperty -Path $personalizeKey -Name ColorPrevalence -Value ([int]$on) -Type DWord -Force
               Send-SettingChange 'ImmersiveColorSet' } }
    @{ Key = 'schedtheme'; Group = 'looks'; Glyph = [char]0xE706; Default = $false
       Get = { (Get-RegValue $settingsKey 'ScheduleTheme') -eq 1 }
       Set = { param($on) Save-Setting ScheduleTheme ([int]$on) } }
    @{ Key = 'transparency'; Group = 'looks'; Glyph = [char]0xE727; Default = $true
       Get = { (Get-RegValue $personalizeKey 'EnableTransparency') -ne 0 }
       Set = { param($on)
               if (!(Test-Path $personalizeKey)) { New-Item -Path $personalizeKey -Force | Out-Null }
               Set-ItemProperty -Path $personalizeKey -Name EnableTransparency -Value ([int]$on) -Type DWord -Force
               Send-SettingChange 'ImmersiveColorSet' } }
    @{ Key = 'updatenotify'; Group = 'system'; Glyph = [char]0xE895; Default = $true
       Get = { (Get-RegValue $settingsKey 'UpdateNotify') -ne 0 }
       Set = { param($on) Save-Setting UpdateNotify ([int]$on) } }
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
foreach ($g in 'latency', 'network', 'graphics', 'system', 'looks', 'services') {
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
        if ($ctx.Tweak.Restart) { $msg += ' · ' + (T 'restart'); Set-RestartNeeded }
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

# A bar in the title bar when a change needs a restart, with "Restart now"
function Set-RestartNeeded { if (!$Screenshot) { $ui.RestartBar.Visibility = 'Visible' } }
$ui.RestartNow.Add_Click({
    if ([System.Windows.MessageBox]::Show((T 'restart.ask'), 'Akati OS Center', 'YesNo', 'Question') -eq 'Yes') { Restart-Computer -Force }
})

# A short message at the bottom of the page after a switch changed, with Undo
$script:toastUndo = $null
$toastTimer = New-Object System.Windows.Threading.DispatcherTimer
$toastTimer.Interval = [TimeSpan]::FromSeconds(6)
$toastTimer.Add_Tick({ $toastTimer.Stop(); $ui.Toast.Visibility = 'Collapsed' })
function Show-Toast([string]$text, $undo) {
    $ui.ToastText.Text = $text
    $script:toastUndo = $undo
    $ui.ToastUndo.Visibility = if ($undo) { 'Visible' } else { 'Collapsed' }
    $ui.Toast.Visibility = 'Visible'
    $toastTimer.Stop(); $toastTimer.Start()
}
$ui.ToastUndo.Add_Click({
    $u = $script:toastUndo; $script:toastUndo = $null
    $toastTimer.Stop(); $ui.Toast.Visibility = 'Collapsed'
    if ($u) { $u.Tweak.Toggle.IsChecked = $u.Before; Invoke-Tweak $u.Tweak $u.Before; Add-History $u.Tweak.Key $u.Before }
})

# "What it changes" under a switch: the PowerShell the switch runs, or the AtlasOS scripts it starts
function Format-Code([scriptblock]$block) {
    $lines = @($block.ToString().Trim("`r", "`n") -split "`r?`n")
    $indent = @($lines | Select-Object -Skip 1 | Where-Object { $_.Trim() } | ForEach-Object { $_.Length - $_.TrimStart().Length } | Measure-Object -Minimum).Minimum
    if ($indent) { $lines = @($lines[0].Trim()) + @($lines | Select-Object -Skip 1 | ForEach-Object { if ($_.Length -ge $indent) { $_.Substring($indent) } else { $_.TrimStart() } }) }
    ($lines -join "`r`n").Trim()
}
# The code box is made the first time the link is clicked (40 boxes at start made the Tweaks page slow to build)
function Add-Details($row, [string]$code) {
    $link = New-Text (T 'tw.details') 12 'Normal' 't:tw.details'
    $link.SetResourceReference([System.Windows.Controls.TextBlock]::ForegroundProperty, 'Accent2')
    $link.Cursor = 'Hand'; $link.Margin = '0,4,0,0'; $link.HorizontalAlignment = 'Left'
    $link.DataContext = $code
    $link.Add_MouseLeftButtonUp({ [void](Switch-Details $this) })
    $panel = $row.Sub.Parent
    $panel.Children.Insert($panel.Children.IndexOf($row.Sub) + 1, $link)
}
# Shows or hides the code under a "What it changes" link (makes the box the first time); returns the box
function Switch-Details($link) {
    $b = $link.DataContext
    if ($b -is [string]) {
        $box = New-Object System.Windows.Controls.TextBox
        $box.Text = $b; $box.IsReadOnly = $true; $box.FontFamily = 'Cascadia Mono, Consolas'; $box.FontSize = 11
        $box.TextWrapping = 'Wrap'; $box.Margin = '0,6,16,2'; $box.Padding = '8,6'; $box.BorderThickness = '0'; $box.Visibility = 'Collapsed'
        $box.SetResourceReference([System.Windows.Controls.Control]::BackgroundProperty, 'Field')
        $box.SetResourceReference([System.Windows.Controls.Control]::ForegroundProperty, 'Text2')
        $panel = $link.Parent
        $panel.Children.Insert($panel.Children.IndexOf($link) + 1, $box)
        $link.DataContext = $box; $b = $box
    }
    $b.Visibility = if ($b.Visibility -eq 'Visible') { 'Collapsed' } else { 'Visible' }
    $b
}

# The switches are made the first time something needs them (the Tweaks page, Ctrl+K, the history, backup,
# Akati Doctor, the anti-cheat buttons), not when the app starts: 45 rows took about a second.
function Initialize-Tweaks {
    if ($script:tweaksBuilt) { return }
    $script:tweaksBuilt = $true
    foreach ($tw in $tweaks) {
        if ($tw.Win11 -and $build -lt 22000) { continue }
        $toggle = New-Object System.Windows.Controls.CheckBox
        $toggle.Style = $window.FindResource('Switch')
        $row = New-Row ([string]$tw.Glyph) (T "tw.$($tw.Key)") "t:tw.$($tw.Key)" $toggle "t:tw.$($tw.Key).d"
        $row.Sub.Text = T "tw.$($tw.Key).d"
        $tw.Toggle = $toggle; $tw.Sub = $row.Sub
        $code = if ($tw.Script) { "AtlasDesktop\$($tw.Script.Folder)\$($tw.Script.On)`r`nAtlasDesktop\$($tw.Script.Folder)\$($tw.Script.Off)" }
                elseif ($tw.Work) { Format-Code $tw.Work } elseif ($tw.Set) { Format-Code $tw.Set } else { '' }
        if ($code) { Add-Details $row $code }
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
        $toggle.Add_Click({
            $t = $this.Tag; $on = [bool]$this.IsChecked
            Invoke-Tweak $t $on
            Add-History $t.Key $on
            Show-Toast ((T $(if ($on) { 'toast.on' } else { 'toast.off' })) -f (T "tw.$($t.Key)")) @{ Tweak = $t; Before = !$on }
        })
        $group = if ($tw.Group) { $tw.Group } else { 'gaming' }
        $tw.Row = $row.Row
        [void]$tweakLists[$group].Children.Add($row.Row)
    }
    foreach ($list in $tweakLists.Values) { Update-Separators $list }
    Update-TweakHints
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
# Without WMI (the first WMI query of the app takes about a second)
$ramGb = try { Add-Type -AssemblyName Microsoft.VisualBasic; [Math]::Round((New-Object Microsoft.VisualBasic.Devices.ComputerInfo).TotalPhysicalMemory / 1GB) } catch { 0 }
function Update-TweakHints {
    $mc = $tweaks | Where-Object { $_.Key -eq 'memcomp' }
    if (!$mc.Sub) { return }
    $hint = if (!$mc.Toggle.IsEnabled) { T 'tw.memcomp.nosysmain' } elseif ($ramGb -ge 16) { (T 'tw.memcomp.off') -f $ramGb } else { (T 'tw.memcomp.on') -f $ramGb }
    $mc.Sub.Text = (T 'tw.memcomp.d') + ' ' + $hint
}
foreach ($list in $tweakLists.Values) { Update-Separators $list }
if ($Screenshot) { Initialize-Tweaks }

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
    Set-RestartNeeded
})

# Game boost > Anti-cheat mode: Valorant (Vanguard) can ask for Memory integrity (HVCI) on, FiveM needs it
# off. The buttons use the Core isolation tweak; Windows changes it at the next start.
$vbsTweak = $tweaks | Where-Object { $_.Key -eq 'vbs' }
# $true / $false while Windows runs; $null when Windows cannot report it (the DeviceGuard WMI provider is
# missing on some trimmed builds, for example imOS 10: "Provider load failure")
function Test-HvciRunning {
    try { 2 -in @((Get-CimInstance -Namespace 'root\Microsoft\Windows\DeviceGuard' -ClassName Win32_DeviceGuard -ErrorAction Stop).SecurityServicesRunning) }
    catch { $null }
}
function Update-AntiCheat {
    $wanted = (Get-RegValue $hvciKey 'Enabled') -eq 1
    $text = if ($wanted) { T 'ac.on' } else { T 'ac.off' }
    if ($Screenshot) { $ui.AcState.Text = $text; return }
    $running = Test-HvciRunning
    if ($null -ne $running -and $wanted -ne $running) { $text += '  ·  ' + (T 'ac.pending') }
    $ui.AcState.Text = $text
}
function Set-AntiCheat([bool]$on) {
    Initialize-Tweaks
    $changed = ((Get-RegValue $hvciKey 'Enabled') -eq 1) -ne $on
    if ($changed) {
        $vbsTweak.Toggle.IsChecked = $on
        Invoke-Tweak $vbsTweak $on
    }
    Update-AntiCheat
    if ($Screenshot) { return }
    # A restart is needed when what runs differs; when Windows cannot tell, when the setting just changed
    $running = Test-HvciRunning
    $ask = if ($null -ne $running) { $on -ne $running } else { $changed }
    if ($ask) { Set-RestartNeeded }
    if ($ask -and [System.Windows.MessageBox]::Show((T 'ac.restartask'), 'Akati OS Center', 'YesNo', 'Question') -eq 'Yes') { Restart-Computer -Force }
}
$ui.AcValorant.Add_Click({ Set-AntiCheat $true })
$ui.AcFiveM.Add_Click({ Set-AntiCheat $false })
Update-AntiCheat

