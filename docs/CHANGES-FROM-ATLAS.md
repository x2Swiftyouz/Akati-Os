# Changes from AtlasOS

Akati OS is a modified version of the AtlasOS playbook (GPL-3.0). It is not an official AtlasOS project.

There are two playbooks:

| Playbook | Source | File | Base |
|---|---|---|---|
| Windows 11 (24H2, 25H2, 26H2) | `src/` | `AkatiOS_v<version>.apbx` | AtlasOS tag `0.5.0-hotfix`, commit `6cbd1a3` |
| Windows 10 22H2 | `src-win10/` | `AkatiOS-Win10_v<version>.apbx` | AtlasOS tag `0.4.1`, commit `16533c1` |

Both use [Atlas-OS/Atlas](https://github.com/Atlas-OS/Atlas), folder `src/playbook`. Every file not listed below is identical to the AtlasOS base (ignoring CRLF/LF line endings).

## Check it yourself

```sh
git clone https://github.com/Atlas-OS/Atlas atlas
git clone https://github.com/x2Swiftyouz/Akati-Os akati

git -C atlas checkout 0.5.0-hotfix
diff -rq --strip-trailing-cr atlas/src/playbook akati/src          # Windows 11

git -C atlas checkout 0.4.1
diff -rq --strip-trailing-cr atlas/src/playbook akati/src-win10    # Windows 10
```

Use `diff -ru` instead of `diff -rq` for the full diff.

## Changed files

W11 = Windows 11 playbook, W10 = Windows 10 playbook.

| File | In | Change |
|---|---|---|
| `playbook.conf` | W11, W10 | Name (`AkatiOS` / `AkatiOS10`), title, version, own UniqueId, descriptions, own Git and install guide links, AtlasOS website/donate/Git links removed, "Learn more" links point to [OPTIONS.md](OPTIONS.md); `IsChecked` defaults; anti-cheat warnings; Remove Microsoft Store page (no gaming app pages: apps are installed from Akati OS Center). W11: `UpgradableFrom` removed, build 26300 added, OOBE text. W10: build 19045 only, Windows 10 end of support warning |
| `playbook.png`, `Executables/user.png` | W11, W10 | Akati OS images |
| `Configuration/custom.yml` | W11, W10 | Runs `tweaks\misc\akati-extras.yml` after `atlas\start.yml`, and `tweaks\misc\akati-services.yml` after all other tasks. W11: one status text |
| `Configuration/atlas/start.yml` | W11 | One status text; the optional Atlas Toolbox install is removed |
| `Configuration/tweaks/misc/config-oem-information.yml` | W11, W10 | Shows "Akati OS" version, AtlasOS support links removed, writes the version to `HKLM\SOFTWARE\AkatiOS` (used by the update checker) |
| `Configuration/tweaks/qol/appearance/atlas-theme.yml` | W11, W10 | Default theme is `akatios-dark.theme` |
| `Executables/AtlasModules/Scripts/newUsers.ps1` | W11 | Default theme for new users is `akatios-dark.theme` |
| `Executables/AtlasModules/Scripts/Modules/Themes/Themes.psm1` | W11, W10 | Akati OS themes in `Set-ThemeMRU` (AtlasOS themes removed), default lock screen image |
| `Executables/AtlasModules/Scripts/Modules/Qol/Qol.psm1` | W11 | `Set-AtlasTheme` uses `akatios-dark.theme` |
| `Executables/SHORTCUTS.ps1` | W11, W10 | No Atlas folder shortcut on the desktop or in the Start menu (the settings are in Akati OS Center > Tweaks). The folder `C:\Windows\AtlasDesktop` itself stays, AtlasOS scripts use it |

## Removed files

The AtlasOS wallpapers and themes are removed, so the Atlas logo is not used: `Executables/AtlasModules/Wallpapers/atlas-*.png`, `lockscreen*.png`, `Executables/Themes/atlas-*.theme` and the folder icon `Executables/AtlasModules/Other/atlas-folder.ico`.

W11: the Atlas Toolbox is not offered: the setup page "Install Atlas Toolbox" (`install-toolbox`), its install step and `AtlasDesktop\Install AtlasOS Toolbox.cmd` with `AtlasModules\Scripts\installToolbox.ps1` are removed. `SOFTWARE.ps1` is unchanged.

## New files

| File | Purpose |
|---|---|
| `Configuration/tweaks/misc/akati-services.yml` | Unused services (option `disable-unused-services`), run as the last task of `custom.yml` because `atlas\services.yml` turns minimal search indexing back on: the unchanged AtlasOS scripts Disable Printing, Disable SuperFetch, Disable Network Discovery Services (`/silent`) and Disable Search Indexing (as TrustedInstaller), input from `nul` because some end with `pause`; and `HKLM\SYSTEM\CurrentControlSet\Services\MSDTC` `Start` = 4 (Distributed Transaction Coordinator disabled, default 3); timer resolution (option `enable-timer-resolution`): the unchanged AtlasOS script `Enable timer resolution.cmd` (`/silent`) |
| `Configuration/tweaks/misc/akati-extras.yml` | Microsoft Store removal (option `remove-store`, `!appx` family `Microsoft.WindowsStore*`), notifications off (option `disable-notifications`: `HKCU\...\PushNotifications` `ToastEnabled` = 0), Xbox Game Bar off (option `disable-game-bar`: the user values of the AtlasOS task `disable-game-bar.yml` — `GameDVR_Enabled`, `AppCaptureEnabled`, `UseNexusForGameBarEnabled`, `ShowStartupPanel`, `GamePanelStartupTipIndex` — without its `AllowGameDVR` policies, so Settings can turn it on again), Sticky Keys, Filter Keys and Toggle Keys shortcuts off (option `disable-accessibility-shortcuts`: `HKCU\Control Panel\Accessibility\StickyKeys`, `Keyboard Response`, `ToggleKeys` `Flags` = 506, 122, 58, the Windows defaults without the shortcut bit), the Windows Terminal color scheme, the Akati OS Center shortcuts the desktop menu (option `desktop-menu`: `AkatiMenu.ps1 -Install`) and the icon next to the clock (option `tray-icon`: `AkatiTray.ps1 -Install`) |
| `Executables/AtlasModules/Scripts/GAMEAPPS.ps1` | Installs one gaming app when the user clicks Install in Akati OS Center (see below) |
| `Executables/AtlasModules/Other/AkatiOS/terminal-fragment.json` | Windows Terminal color scheme and profile, copied to `%ProgramData%\Microsoft\Windows Terminal\Fragments\AkatiOS` |
| `Executables/AtlasModules/AkatiCenter/` | Akati OS Center app: `AkatiCenter.ps1` (PowerShell + WPF), `AkatiCenter.xaml` (window layout), `logo.png`; `AkatiCenter.strings.ps1` (all texts in English and Thai); `AkatiTray.ps1` is the Akati OS icon in the notification area (runs as the user with normal rights from the sign-in task `\AkatiOS\Akati OS tray`, which `-Install` registers; reads CPU and RAM with CIM; the automatic Game boost runs `AkatiMenu.ps1 -Action booston/boostoff` when a game from My games starts or ends); `AkatiMenu.ps1` builds the desktop right-click menu `HKLM\SOFTWARE\Classes\DesktopBackground\Shell\AkatiOS`, registers the task `\AkatiOS\Akati OS menu` (signed-in user, highest rights; it only runs the fixed items Free up RAM, Game boost and Restart into BIOS, `shutdown /r /fw`) and runs the menu items. Shortcuts are created by `akati-extras.yml` |
| `Executables/Themes/akatios-dark.theme`, `akatios-light.theme`, `akatios-slideshow.theme` | Themes |
| `Executables/AtlasModules/Wallpapers/akatios-*.png` | Wallpapers and lock screen (Aurora, Sunset, Ocean and Mist are drawn by `tools/make-assets.py`) |
| `Executables/AtlasModules/Other/AkatiOS/Cursors/` | Akati OS arrow and busy cursors (`.cur`, `.ani`), drawn by `tools/make-assets.py`. Only used when the user picks them in Akati OS Center |
| `Executables/AtlasModules/Other/AkatiOS/Sounds/` | Akati OS system sounds (`.wav`), made by `tools/make-assets.py`. Only used when the user picks them in Akati OS Center |
| `Executables/AtlasModules/Other/akatios-folder.ico` | Icon of the Akati OS Center shortcuts |
| `README.md`, `CHANGELOG.md`, `CREDITS.txt` | Documentation and credits |

## Gaming tweaks (registry)

Not set during setup. Only set when the user turns them on in Akati OS Center.

| Option | Registry value | Playbook |
|---|---|---|
| Hardware-accelerated GPU scheduling | `HKLM\SYSTEM\CurrentControlSet\Control\GraphicsDrivers` `HwSchMode` = 2 | W11, W10 |
| Optimizations for windowed games | `HKCU\Software\Microsoft\DirectX\UserGpuPreferences` `DirectXUserGlobalSettings` = `SwapEffectUpgradeEnable=1;` | W11 |

## What GAMEAPPS.ps1 downloads and runs

Setup installs no gaming apps. `GAMEAPPS.ps1` runs only when the user clicks Install for an app in Akati OS Center > Gaming apps.

1. **WinGet first** (`winget install --id <Id> --exact --source winget --silent`). WinGet checks the installer hash from the WinGet manifest.
2. **Fallback, only for Steam, Discord and Riot**, if WinGet is missing or fails: the installer is downloaded with `curl.exe` from the vendor's own URL and run silently (Steam):

| App | WinGet Id | Fallback URL |
|---|---|---|
| Steam | `Valve.Steam` | `https://cdn.akamai.steamstatic.com/client/installer/SteamSetup.exe` (`/S`) |
| Discord | not used | `https://discord.com/api/downloads/distributions/app/installers/latest?channel=stable&platform=win&arch=x64` (always, no switches, see below) |
| Epic Games Launcher | `EpicGames.EpicGamesLauncher` | none |
| EA app | `ElectronicArts.EADesktop` | none |
| Ubisoft Connect | `Ubisoft.Connect` | none |
| Battle.net | `Blizzard.BattleNet` | none |
| OBS Studio | `OBSProject.OBSStudio` | none |
| Riot Client (VALORANT) | not used (WinGet has only full game packages) | `https://valorant.secure.dyn.riotcdn.net/channels/public/x/installer/current/live.live.ap.exe` (always; runs only if its Authenticode signature is valid and signed by Riot Games; no switches, the user clicks Install in its window) |
| GOG GALAXY | `GOG.Galaxy` | none |
| Rockstar Games Launcher | `RockstarGames.Launcher` | none |
| MSI Afterburner | `Guru3D.Afterburner` | none |

Discord is never installed silently (no WinGet, no `-s`): after a silent install its first start quits without moving the install to its new updater, and every later start fails with "Attempt to install host that is currently running". `GAMEAPPS.ps1` writes a log to `%LOCALAPPDATA%\AkatiOS\Logs\GAMEAPPS-<app>.log` (`GAMEAPPS-<app>-user.log` when it runs without admin rights, for example the user part of the Discord install). `GAMEAPPS.ps1` still has `-AtSignIn` (a scheduled task that installs an app as the user after the next sign-in), which setup no longer uses. When `GAMEAPPS.ps1` runs elevated (from Akati OS Center), it installs Discord through a one-time scheduled task `AkatiOS Install Discord` that runs the same script as the signed-in user with limited rights, waits for it and deletes the task.

## What Akati OS Center does

It runs only when the user opens it and asks for administrator rights. Everything it changes is listed here:

- **Gaming apps**: runs `GAMEAPPS.ps1 -App <name>` (see above), one app at a time; Cancel stops that script and what it started (`taskkill /T`, and the `AkatiOS Install Discord` task). `GAMEAPPS.ps1` writes its progress to `%LOCALAPPDATA%\AkatiOS\Logs\GAMEAPPS-<app>.progress`. **Check for updates** (also once, the first time the page opens in a window) runs `winget list --id <id> --upgrade-available` for each installed app and **Update** runs `winget upgrade --id <id> --silent` (not for Steam and Discord, which update themselves). **Open** starts an installed app through `explorer.exe` (as the signed-in user, not elevated); **Open folder** opens its folder; **Uninstall** asks first, then runs the `UninstallString` of the app's entry in `...\CurrentVersion\Uninstall` (HKLM, HKLM WOW6432Node, HKCU) with `cmd.exe /c`, so the app's own uninstaller opens (if none is found, Settings > Apps opens). The GPU names, driver versions and driver dates come from `Win32_VideoController`
- **Game boost**: Start saves what it changes in `HKCU\Software\AkatiOS\Center\Boost` and then, for the ticked items: activates the first power plan found of Atlas Power Scheme, Ultimate Performance or High performance (`powercfg /setactive`); closes OneDrive (`/shutdown`), Teams, Spotify, Phone Link, Dropbox, Google Drive and Skype; sets `HKCU\Software\Microsoft\Windows\CurrentVersion\PushNotifications` `ToastEnabled` to 0. Stop sets the old power plan and `ToastEnabled` again, starts the closed apps again (through `explorer.exe`, not elevated) and deletes the key
- **Ping**: only while the test runs and the page is open, a TCP connection to port 443 of `dynamodb.<region>.amazonaws.com` (ap-southeast-7, ap-southeast-1, ap-east-1, ap-northeast-1) every 2 seconds. No data is sent
- **Startup apps**: reads the `Run` keys (HKCU, HKLM, HKLM WOW6432Node) and the Startup folders; a switch writes the on/off value to `...\Explorer\StartupApproved\Run`, `Run32` or `StartupFolder`, like Task Manager. The startup entries themselves are not changed
- **Tweaks**: the registry values in [Gaming tweaks](#gaming-tweaks-registry), plus Game Mode (`HKCU\Software\Microsoft\GameBar` `AutoGameModeEnabled`), and runs the unchanged AtlasOS scripts in `AtlasDesktop\3. General Configuration\Power-saving`, `\Hibernation` and `\Timer Resolution` with `/silent`. More switches, only when the user clicks them:
  - Sticky Keys shortcuts: bit 4 of `Flags` in `HKCU\Control Panel\Accessibility\StickyKeys`, `Keyboard Response`, `ToggleKeys`
  - DNS: `Set-DnsClientServerAddress` on the connected physical adapters (Cloudflare `1.1.1.1`, `1.0.0.1`, `2606:4700:4700::1111`, `::1001`; Google `8.8.8.8`, `8.8.4.4`, `2001:4860:4860::8888`, `::8844`; Automatic = `-ResetServerAddresses`), then `Clear-DnsClientCache`
  - Nagle: `TcpAckFrequency` = 1 and `TCPNoDelay` = 1 in every `HKLM\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters\Interfaces\{...}` (on = values removed)
  - Network adapter: `Set-NetAdapterAdvancedProperty` `*InterruptModeration` and `*EEE` = 0 or 1 on physical adapters
  - Refresh rate: `ChangeDisplaySettingsEx` on the main screen with the highest rate `EnumDisplaySettings` lists for its resolution
  - MPO: `HKLM\SOFTWARE\Microsoft\Windows\Dwm` `OverlayTestMode` = 5 (on = value removed)
  - GPU MSI mode: `MSISupported` = 1 or 0 in `HKLM\SYSTEM\CurrentControlSet\Enum\<GPU>\Device Parameters\Interrupt Management\MessageSignaledInterruptProperties` of each PCI graphics card from `Win32_VideoController`
  - Memory compression: `Enable-MMAgent` / `Disable-MMAgent -MemoryCompression`
  - Core isolation: `HKLM\SYSTEM\CurrentControlSet\Control\DeviceGuard\Scenarios\HypervisorEnforcedCodeIntegrity` `Enabled` and `...\DeviceGuard` `EnableVirtualizationBasedSecurity` = 1 or 0 (the same values as the AtlasOS VBS scripts)
  - Startup delay: `HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Serialize` `StartupDelayInMSec` and `WaitForIdleState` = 0 (on = values removed)
- **Game boost > standby memory**: `NtSetSystemInformation(SystemMemoryListInformation, MemoryPurgeStandbyList)` after enabling `SeProfileSingleProcessPrivilege` for its own process; nothing to undo
- **Game boost > My games**: the list is kept in `HKCU\Software\AkatiOS\Center\Games`. High priority: `HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Image File Execution Options\<game>.exe\PerfOptions` `CpuPriorityClass` = 3; Dedicated GPU: `HKCU\Software\Microsoft\DirectX\UserGpuPreferences` `<path>` = `GpuPreference=2;`; Skip Defender: `Add-MpPreference -ExclusionPath <game folder>`. Removing a game removes all three
- **Cleaner**: only for the items the user ticks, deletes the contents of `%TEMP%`, `%windir%\Temp`, `%windir%\SoftwareDistribution\Download` and the Delivery Optimization cache, `%LOCALAPPDATA%\CrashDumps` and the WER report folders, the CBS/DISM/Panther `*.log` files, `thumbcache_*.db`, the web caches of Discord, Steam and Epic (`Cache_Data`, `Code Cache`, `GPUCache`, `htmlcache`, `webcache*`), the browser caches of Brave, Edge, Chrome (`Cache_Data`) and Firefox (`cache2`), the GPU shader caches (`D3DSCache`, NVIDIA/AMD `DXCache`/`GLCache`, Intel `ShaderCache`) and empties the Recycle Bin. Browser and shader caches are not ticked at first. No cookies, passwords, settings or saves are touched; files in use are skipped
- **Microsoft Store switch**: off removes the `Microsoft.WindowsStore` package for all users; on runs `wsreset -i`, which installs it again
- **Appearance**: opens an Akati OS `.theme` file, which Windows applies
- **Tweaks > System (AtlasOS)**: lists every file in `C:\Windows\AtlasDesktop` (the unchanged AtlasOS settings), one row per folder, with English and Thai names. A `.reg` file is imported with `reg import`, a `.cmd` script opens in a console window (the AtlasOS script explains the change), links and other files are opened. Nothing runs until the user clicks a button. Before the first `.reg`, `.cmd` or `.ps1` in a window, `Checkpoint-Computer` creates a restore point (switch on the page, saved as `RestorePoint` in `HKCU\Software\AkatiOS\Center`); System Restore is not turned on if it is off
- **Accent color**: `HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Accent` (`AccentPalette`, `AccentColorMenu`, `StartColorMenu`), `HKCU\Software\Microsoft\Windows\DWM` (`AccentColor`, `ColorizationColor`, `ColorizationAfterglow`), `HKCU\Control Panel\Desktop` `AutoColorization` = 0, and the colors in `%ProgramData%\Microsoft\Windows Terminal\Fragments\AkatiOS\akatios.json`
- **Wallpapers**: `SystemParametersInfo(SPI_SETDESKWALLPAPER)` with Fill
- **Cursor**: `HKCU\Control Panel\Cursors` (Akati OS: `Arrow`, `Wait`, `AppStarting`; the other pointers are the Windows ones), then `SPI_SETCURSORS`
- **Sounds**: `HKCU\AppEvents\Schemes\Apps\.Default\<event>\.Current` for `.Default`, `SystemAsterisk`, `SystemExclamation`, `SystemHand`, `SystemNotification`, `Notification.Default`, `DeviceConnect`, `DeviceDisconnect`: Akati OS sounds, the Windows sounds in `%windir%\Media`, or none
- **Problem report**: writes `AkatiOS-report-<date>.zip` on the desktop with `system.txt` (Windows, CPU, GPU, RAM, disk, power plan, WinGet version, app states) and the logs in `%LOCALAPPDATA%\AkatiOS\Logs`, with the user name and PC name replaced. Nothing is uploaded
- **Update check**: reads `https://api.github.com/repos/x2Swiftyouz/Akati-Os/releases/latest`, (if that fails, for example because of the API limit of 60 requests an hour, it reads where `https://github.com/x2Swiftyouz/Akati-Os/releases/latest` redirects to), compares it with the installed version and can open the release page. It runs once each time the window opens; it does not download or install anything and does not run on a schedule
- **Dashboard**: reads usage, network speed (`Win32_PerfFormattedData_Tcpip_NetworkInterface`) and the busiest processes (`Win32_PerfFormattedData_PerfProc_Process`) with CIM, the drives with `Win32_LogicalDisk`, the power plan with `powercfg /getactivescheme` and real-time protection with `Get-MpComputerStatus`. While the window is open it measures ping with a TCP connection to port 443 of `dynamodb.ap-southeast-1.amazonaws.com` about every 9 seconds (no data is sent). Processes with the same name are shown as one row. **Quit** on an app asks first and then ends its processes (`Stop-Process`); Windows processes and Akati OS Center itself have no Quit button
- Saves the language, accent color, "welcome shown", the look (`CenterLook`), the automatic Game boost (`AutoBoost`) and the last version it showed What's new for (`LastVersion`) to `HKCU\Software\AkatiOS\Center`
- **Search (Ctrl+K)** actions: Free up RAM (as Game boost), Flush DNS cache (`ipconfig /flushdns`), Restart Explorer (stops `explorer.exe`, Windows starts it again). **Network card**: `Get-NetAdapter -Physical` and `Get-NetIPAddress` (read only). **Reset to Windows defaults**: the same switches as listed above, and DNS Automatic
- Windows 11: Mica backdrop with `DwmSetWindowAttribute` (on its own window only)
- Reads usage with CIM (`Win32_PerfFormattedData_*`); nothing is sent anywhere

No other downloads were added. All other downloads (7-Zip, Visual C++, DirectX, browsers) come from the unchanged AtlasOS `SOFTWARE.ps1`.
