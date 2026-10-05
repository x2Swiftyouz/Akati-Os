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
| `Configuration/custom.yml` | W11, W10 | Runs `tweaks\misc\akati-extras.yml` after `atlas\start.yml`. W11: one status text |
| `Configuration/atlas/start.yml` | W11 | One status text |
| `Configuration/tweaks/misc/config-oem-information.yml` | W11, W10 | Shows "Akati OS" version, AtlasOS support links removed, writes the version to `HKLM\SOFTWARE\AkatiOS` (used by the update checker) |
| `Configuration/tweaks/qol/appearance/atlas-theme.yml` | W11, W10 | Default theme is `akatios-dark.theme` |
| `Executables/AtlasModules/Scripts/newUsers.ps1` | W11 | Default theme for new users is `akatios-dark.theme` |
| `Executables/AtlasModules/Scripts/Modules/Themes/Themes.psm1` | W11, W10 | Akati OS themes in `Set-ThemeMRU` (AtlasOS themes removed), default lock screen image |
| `Executables/AtlasModules/Scripts/Modules/Qol/Qol.psm1` | W11 | `Set-AtlasTheme` uses `akatios-dark.theme` |
| `Executables/SHORTCUTS.ps1` | W11, W10 | No Atlas folder shortcut on the desktop or in the Start menu (the settings are in Akati OS Center > System settings). The folder `C:\Windows\AtlasDesktop` itself stays, AtlasOS scripts use it |

## Removed files

The AtlasOS wallpapers and themes are removed, so the Atlas logo is not used: `Executables/AtlasModules/Wallpapers/atlas-*.png`, `lockscreen*.png`, `Executables/Themes/atlas-*.theme` and the folder icon `Executables/AtlasModules/Other/atlas-folder.ico`.

## New files

| File | Purpose |
|---|---|
| `Configuration/tweaks/misc/akati-extras.yml` | Microsoft Store removal (option `remove-store`, `!appx` family `Microsoft.WindowsStore*`), the Windows Terminal color scheme and the Akati OS Center shortcuts |
| `Executables/AtlasModules/Scripts/GAMEAPPS.ps1` | Installs one gaming app when the user clicks Install in Akati OS Center (see below) |
| `Executables/AtlasModules/Other/AkatiOS/terminal-fragment.json` | Windows Terminal color scheme and profile, copied to `%ProgramData%\Microsoft\Windows Terminal\Fragments\AkatiOS` |
| `Executables/AtlasModules/AkatiCenter/` | Akati OS Center app: `AkatiCenter.ps1` (PowerShell + WPF), `AkatiCenter.xaml` (window layout), `logo.png`. Shortcuts are created by `akati-extras.yml` |
| `Executables/Themes/akatios-dark.theme`, `akatios-light.theme`, `akatios-slideshow.theme` | Themes |
| `Executables/AtlasModules/Wallpapers/akatios-*.png` | Wallpapers and lock screen |
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
2. **Fallback, only for Steam and Discord**, if WinGet is missing or fails: the installer is downloaded with `curl.exe` from the vendor's own URL and run silently:

| App | WinGet Id | Fallback URL |
|---|---|---|
| Steam | `Valve.Steam` | `https://cdn.akamai.steamstatic.com/client/installer/SteamSetup.exe` (`/S`) |
| Discord | not used | `https://discord.com/api/downloads/distributions/app/installers/latest?channel=stable&platform=win&arch=x64` (always, no switches, see below) |
| Epic Games Launcher | `EpicGames.EpicGamesLauncher` | none |
| EA app | `ElectronicArts.EADesktop` | none |
| Ubisoft Connect | `Ubisoft.Connect` | none |
| Battle.net | `Blizzard.BattleNet` | none |
| OBS Studio | `OBSProject.OBSStudio` | none |

Discord is never installed silently (no WinGet, no `-s`): after a silent install its first start quits without moving the install to its new updater, and every later start fails with "Attempt to install host that is currently running". `GAMEAPPS.ps1` writes a log to `%LOCALAPPDATA%\AkatiOS\Logs\GAMEAPPS-<app>.log`. `GAMEAPPS.ps1` still has `-AtSignIn` (a scheduled task that installs an app as the user after the next sign-in), which setup no longer uses. When `GAMEAPPS.ps1` runs elevated (from Akati OS Center), it installs Discord through a one-time scheduled task `AkatiOS Install Discord` that runs the same script as the signed-in user with limited rights, waits for it and deletes the task.

## What Akati OS Center does

It runs only when the user opens it and asks for administrator rights. Everything it changes is listed here:

- **Gaming apps**: runs `GAMEAPPS.ps1 -App <name>` (see above)
- **Tweaks**: the registry values in [Gaming tweaks](#gaming-tweaks-registry), plus Game Mode (`HKCU\Software\Microsoft\GameBar` `AutoGameModeEnabled`), and runs the unchanged AtlasOS scripts in `AtlasDesktop\3. General Configuration\Power-saving` and `\Hibernation` with `/silent`
- **Cleaner**: deletes the contents of `%TEMP%`, `%windir%\Temp`, `%LOCALAPPDATA%\CrashDumps` and empties the Recycle Bin, only for the items the user ticks
- **Microsoft Store switch**: off removes the `Microsoft.WindowsStore` package for all users; on runs `wsreset -i`, which installs it again
- **Appearance**: opens an Akati OS `.theme` file, which Windows applies
- **System settings**: lists every file in `C:\Windows\AtlasDesktop` (the unchanged AtlasOS settings), one row per folder. A `.reg` file is imported with `reg import`, a `.cmd` script opens in a console window (the AtlasOS script explains the change), links and other files are opened. Nothing runs until the user clicks a button
- **Update check**: reads `https://api.github.com/repos/x2Swiftyouz/Akati-Os/releases/latest`, compares it with the installed version and can open the release page. It does not download or install anything and does not run on a schedule
- Saves the chosen language to `HKCU\Software\AkatiOS\Center`
- Reads usage with CIM (`Win32_PerfFormattedData_*`); nothing is sent anywhere

No other downloads were added. All other downloads (7-Zip, Visual C++, DirectX, browsers, Atlas Toolbox) come from the unchanged AtlasOS `SOFTWARE.ps1`.
