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
| `playbook.conf` | W11, W10 | Name (`AkatiOS` / `AkatiOS10`), title, version, own UniqueId, descriptions, own Git and install guide links, AtlasOS website/donate/Git links removed, "Learn more" links point to [OPTIONS.md](OPTIONS.md); `IsChecked` defaults; anti-cheat warnings; gaming app pages, GPU driver page, gaming tweaks page. W11: `UpgradableFrom` removed, build 26300 added, OOBE text. W10: build 19045 only, Windows 10 end of support warning |
| `playbook.png`, `Executables/user.png` | W11, W10 | Akati OS images |
| `Configuration/custom.yml` | W11, W10 | Runs `tweaks\misc\install-game-apps.yml` and `tweaks\misc\akati-extras.yml` after `atlas\start.yml`. W11: one status text |
| `Configuration/atlas/start.yml` | W11 | One status text |
| `Configuration/tweaks/misc/config-oem-information.yml` | W11, W10 | Shows "Akati OS" version, AtlasOS support links removed, writes the version to `HKLM\SOFTWARE\AkatiOS` (used by the update checker) |
| `Configuration/tweaks/qol/appearance/atlas-theme.yml` | W11, W10 | Default theme is `akatios-dark.theme` |
| `Executables/AtlasModules/Scripts/newUsers.ps1` | W11 | Default theme for new users is `akatios-dark.theme` |
| `Executables/AtlasModules/Scripts/Modules/Themes/Themes.psm1` | W11, W10 | Akati OS themes in `Set-ThemeMRU` (AtlasOS themes removed), default lock screen image |
| `Executables/AtlasModules/Scripts/Modules/Qol/Qol.psm1` | W11 | `Set-AtlasTheme` uses `akatios-dark.theme` |

## Removed files

The AtlasOS wallpapers and themes are removed, so the Atlas logo is not used: `Executables/AtlasModules/Wallpapers/atlas-*.png`, `lockscreen*.png` and `Executables/Themes/atlas-*.theme`.

## New files

| File | Purpose |
|---|---|
| `Configuration/tweaks/misc/install-game-apps.yml` | Runs `GAMEAPPS.ps1` for each gaming app the user ticked; creates GPU driver download shortcuts (`.url`) on the Public Desktop |
| `Configuration/tweaks/misc/akati-extras.yml` | Optional gaming tweaks (registry values, only if ticked) and the Windows Terminal color scheme |
| `Executables/AtlasModules/Scripts/GAMEAPPS.ps1` | Installs one gaming app (see below). Stays on disk so apps can be installed later |
| `Executables/AtlasModules/Scripts/AkatiUpdate.ps1` | Update checker, only runs when the user opens it (see below) |
| `Executables/AtlasModules/Other/AkatiOS/terminal-fragment.json` | Windows Terminal color scheme and profile, copied to `%ProgramData%\Microsoft\Windows Terminal\Fragments\AkatiOS` |
| `Executables/AtlasDesktop/Akati OS/` | Akati OS folder: install gaming apps later, switch themes, GPU driver links, check for updates, links |
| `Executables/Themes/akatios-dark.theme`, `akatios-light.theme`, `akatios-slideshow.theme` | Themes |
| `Executables/AtlasModules/Wallpapers/akatios-*.png` | Wallpapers and lock screen |
| `README.md`, `CHANGELOG.md`, `CREDITS.txt` | Documentation and credits |

## Gaming tweaks (registry)

Only applied if ticked on the gaming tweaks page. Both are off by default.

| Option | Registry value | Playbook |
|---|---|---|
| Hardware-accelerated GPU scheduling | `HKLM\SYSTEM\CurrentControlSet\Control\GraphicsDrivers` `HwSchMode` = 2 | W11, W10 |
| Optimizations for windowed games | `HKCU\Software\Microsoft\DirectX\UserGpuPreferences` `DirectXUserGlobalSettings` = `SwapEffectUpgradeEnable=1;` | W11 |

## What GAMEAPPS.ps1 downloads and runs

Only apps the user ticks on the setup pages are installed, or the app the user picks later in `AtlasDesktop\Akati OS\Install Gaming Apps`.

1. **WinGet first** (`winget install --id <Id> --exact --silent`). WinGet checks the installer hash from the WinGet manifest.
2. **Fallback, only for Steam and Discord**, if WinGet is missing or fails: the installer is downloaded with `curl.exe` from the vendor's own URL and run silently:

| App | WinGet Id | Fallback URL |
|---|---|---|
| Steam | `Valve.Steam` | `https://cdn.akamai.steamstatic.com/client/installer/SteamSetup.exe` (`/S`) |
| Discord | `Discord.Discord` | `https://discord.com/api/downloads/distributions/app/installers/latest?channel=stable&platform=win&arch=x64` (`-s`) |
| Epic Games Launcher | `EpicGames.EpicGamesLauncher` | none |
| EA app | `ElectronicArts.EADesktop` | none |
| Ubisoft Connect | `Ubisoft.Connect` | none |
| Battle.net | `Blizzard.BattleNet` | none |
| OBS Studio | `OBSProject.OBSStudio` | none |

## What AkatiUpdate.ps1 does

It runs only when the user opens `AtlasDesktop\Akati OS\Check for Updates.cmd`. It reads the latest release from `https://api.github.com/repos/x2Swiftyouz/Akati-Os/releases/latest`, compares it with the installed version and, if the user agrees, opens the release page in the browser. It does not download or install anything and does not run on a schedule.

No other downloads were added. All other downloads (7-Zip, Visual C++, DirectX, browsers, Atlas Toolbox) come from the unchanged AtlasOS `SOFTWARE.ps1`.
