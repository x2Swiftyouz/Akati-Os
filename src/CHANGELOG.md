# Changelog

## v1.3.0

### Fixed
- Discord showed "A fatal Javascript error occured: Attempt to install host that is currently running" after setup. `GAMEAPPS.ps1` read the WinGet exit code wrongly, thought the install had failed and ran the Discord (and Steam) installer a second time. It now reads the exit code correctly and checks whether the app is already installed. Discord updates itself right after installing, and setup restarted the PC in the middle of that update. Setup now installs Discord at the first sign-in after the restart (RunOnce), as the user. Akati OS Center installs it as the signed-in user without admin rights (a one-time scheduled task)

### Added
- Option to remove the Microsoft Store (ticked by default). The Xbox app and Game Pass need it; install it again from Akati OS Center (Tweaks)
- **Akati OS Center** app (desktop and Start menu shortcut, also in the Akati OS folder): dashboard with live CPU, RAM and GPU usage and system info, install gaming apps, tweaks with switches that show the real state (GPU scheduling, windowed games optimizations, Game Mode, Maximum Performance, Hibernation), temp file cleaner, theme picker, update check, English and Thai. Written in PowerShell and WPF, so the source can be read; no `.exe`
- Akati OS for Windows 10 22H2 (build 19045): a separate playbook, `AkatiOS-Win10_v1.3.0.apbx`, based on AtlasOS v0.4.1 (the last AtlasOS version that supports Windows 10). Source in `src-win10/`
- Akati OS folder in `AtlasDesktop`: install gaming apps later, switch themes (Dark, Light, Slideshow), GPU driver links, Check for Updates, GitHub and options guide links
- Akati OS Slideshow theme: the wallpaper changes every 30 minutes
- Update checker (`Check for Updates` in the Akati OS folder): compares the installed version with the latest GitHub release, downloads nothing
- Windows Terminal "Akati OS" color scheme and profile
- Options guide (`docs/OPTIONS.md`, English and Thai). The "Learn more" links on the setup pages open it

### Changed
- Fewer setup pages: a new gaming apps page with "Recommended" (Steam, Discord, remove the Microsoft Store) skips the app pages; "Choose apps myself" shows them. The GPU driver page is removed (the links are in `Akati OS\GPU Drivers`)
- AtlasOS wallpapers and themes removed, so the Atlas logo is no longer used. The `.apbx` file is much smaller
- `GAMEAPPS.ps1` moved to `AtlasModules\Scripts` so it stays on disk after setup
- Installed version is saved to `HKLM\SOFTWARE\AkatiOS`
- Setup screen (OOBE) text describes Akati OS
- The "Akati OS" text on the wallpapers moved inwards, so it is not cut off on 4:3 and 5:4 screens
- The Atlas folder shortcut on the desktop and in the Start menu uses the Akati OS icon instead of the Atlas logo

## v1.2.1

### Fixed
- AME Wizard could not load v1.2.0: "RadioPage with a TopLine or BottomLine must not have more than 3 options". The GPU driver page is now a checkbox page with NVIDIA, AMD and Intel (leave all unticked to skip)

### Added
- `tools/check-playbook.py` and the build scripts check playbook.conf pages before building

## v1.2.0

### Changed
- Gaming app pages regrouped: game stores (Steam, Epic, EA), more game stores (Ubisoft, Battle.net), chat and recording (Discord, OBS)
- Install guide link in playbook.conf points to the Akati OS GitHub page instead of the AtlasOS docs
- Added the Akati OS GitHub source link (Git) to playbook.conf
- Boot menu, Settings and winver show "Akati OS v1.2.0"
- Theme files use CRLF line endings

### Removed
- Visual C++ Runtime and DirectX Runtime options: AtlasOS already installs them on every setup (SOFTWARE.ps1)

## v1.1.0

### Added
- Support for Windows 11 version 26H2 (build 26300)

## v1.0.0

First release of Akati OS, based on AtlasOS v0.5.0.

### Added
- Akati OS Dark and Akati OS Light themes, wallpapers, lock screen, playbook icon and default user picture
- Setup pages for gaming software: Visual C++ Runtime, DirectX Runtime, Steam, Discord, Epic Games Launcher, EA app, Ubisoft Connect, Battle.net, OBS Studio
- GPU driver download shortcut page (NVIDIA, AMD, Intel)
- Warnings about anti-cheat games on the Defender and Core Isolation options
- Backup warning in the playbook description

### Changed
- Playbook name, version and UniqueId
- Setup status texts "Installing Atlas Toolbox (optional)" and "Deleting old system folders"
- Boot menu, Settings and winver show "Akati OS v1.0.0"
- Maximum Performance and Disable Hibernation are checked by default

### Removed
- AtlasOS website, donate, Git and support links from playbook.conf and OEM information
