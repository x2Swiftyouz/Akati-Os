# Changes from AtlasOS

Akati OS is a modified version of the AtlasOS playbook (GPL-3.0). It is not an official AtlasOS project.

There are two playbooks:

- **Windows 11** (`src/`, `AkatiOS_v<version>.apbx`): based on AtlasOS `0.5.0-hotfix`. Described below.
- **Windows 10** (`src-win10/`, `AkatiOS-Win10_v<version>.apbx`): based on AtlasOS `0.4.1`. See [Windows 10 playbook](#windows-10-playbook).

- **Base**: [Atlas-OS/Atlas](https://github.com/Atlas-OS/Atlas), tag `0.5.0-hotfix`, commit `6cbd1a3`, folder `src/playbook`
- **Akati OS source**: `src/` in this repository

Every file not listed below is identical to the AtlasOS base (ignoring CRLF/LF line endings).

## Check it yourself

```sh
git clone https://github.com/Atlas-OS/Atlas atlas
git -C atlas checkout 0.5.0-hotfix
git clone https://github.com/x2Swiftyouz/Akati-Os akati
diff -rq --strip-trailing-cr atlas/src/playbook akati/src
diff -ru --strip-trailing-cr atlas/src/playbook akati/src   # full diff
```

## Changed files

| File | Change |
|---|---|
| `playbook.conf` | Name, title, version, UniqueId, descriptions, own Git and install guide links; AtlasOS website/donate/Git links and `UpgradableFrom` removed; build 26300 added; `IsChecked` defaults; anti-cheat warnings; gaming app pages; GPU driver page |
| `playbook.png` | Akati OS icon |
| `Configuration/custom.yml` | Runs `tweaks\misc\install-game-apps.yml` after `atlas\start.yml`; one status text |
| `Configuration/atlas/start.yml` | One status text |
| `Configuration/tweaks/misc/config-oem-information.yml` | Shows "Akati OS" version; AtlasOS support links removed |
| `Configuration/tweaks/qol/appearance/atlas-theme.yml` | Default theme is `akatios-dark.theme` |
| `Executables/AtlasModules/Scripts/newUsers.ps1` | Default theme for new users is `akatios-dark.theme` |
| `Executables/AtlasModules/Scripts/Modules/Themes/Themes.psm1` | Akati OS themes in `Set-ThemeMRU`; default lock screen image |
| `Executables/user.png` | Akati OS default user picture |

## New files

| File | Purpose |
|---|---|
| `Configuration/tweaks/misc/install-game-apps.yml` | Runs `GAMEAPPS.ps1` for each gaming app the user ticked; creates a GPU driver download shortcut (`.url`) on the Public Desktop |
| `Executables/GAMEAPPS.ps1` | Installs one gaming app (see below) |
| `Executables/Themes/akatios-dark.theme`, `akatios-light.theme` | Themes |
| `Executables/AtlasModules/Wallpapers/akatios-*.png` | Wallpapers and lock screen |
| `README.md`, `CHANGELOG.md`, `CREDITS.txt` | Documentation and credits |

## What GAMEAPPS.ps1 downloads and runs

Only apps the user ticks on the setup pages are installed.

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

No other downloads were added. All other downloads (7-Zip, Visual C++, DirectX, browsers, Atlas Toolbox) come from the unchanged AtlasOS `SOFTWARE.ps1`.

## Windows 10 playbook

- **Base**: [Atlas-OS/Atlas](https://github.com/Atlas-OS/Atlas), tag `0.4.1`, commit `16533c1`, folder `src/playbook`
- **Akati OS source**: `src-win10/` in this repository

```sh
git -C atlas checkout 0.4.1
diff -rq --strip-trailing-cr atlas/src/playbook akati/src-win10
```

Every file not listed below is identical to AtlasOS 0.4.1 (ignoring CRLF/LF line endings).

| File | Change |
|---|---|
| `playbook.conf` | Name `AkatiOS10`, title, version, own UniqueId, descriptions with a Windows 10 end of support warning, own Git and install guide links; AtlasOS website/donate/Git links removed; supports build 19045 only (AtlasOS 0.4.1 also listed 26100); `IsChecked` defaults; anti-cheat warnings; gaming app pages; GPU driver page |
| `playbook.png`, `Executables/user.png` | Akati OS images |
| `Configuration/custom.yml` | Runs `tweaks\misc\install-game-apps.yml` after `atlas\start.yml` |
| `Configuration/tweaks/misc/config-oem-information.yml` | Shows "Akati OS" version; AtlasOS support links removed |
| `Configuration/tweaks/qol/appearance/atlas-theme.yml` | Default theme is `akatios-dark.theme` |
| `Executables/AtlasModules/Scripts/Modules/Themes/Themes.psm1` | Akati OS themes in `Set-ThemeMRU`; default lock screen image |
| New files | Same as the Windows 11 playbook: `install-game-apps.yml`, `GAMEAPPS.ps1`, `akatios-*.theme`, `akatios-*.png`, `README.md`, `CHANGELOG.md`, `CREDITS.txt` |

`GAMEAPPS.ps1` is the same file as in the Windows 11 playbook (see above).
