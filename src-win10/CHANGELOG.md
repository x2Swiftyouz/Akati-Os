# Changelog: Akati OS for Windows 10

## v1.3.0

First Windows 10 version of Akati OS, based on AtlasOS v0.4.1 (Windows 10 22H2, build 19045).
It has the same Akati OS changes as the Windows 11 version v1.3.0.

### Known issues
- Discord is not installed automatically. On Akati OS, Discord (from discord.com or WinGet) shows "A fatal Javascript error occured: Attempt to install host that is currently running" on its first start, while it works on stock Windows. The AtlasOS tweak that causes it is not found yet (Long paths is not the cause). The setup page, Akati OS Center and `Akati OS\Install Gaming Apps\Download Discord` open the Discord download page instead

### Added
- Option to remove the Microsoft Store (ticked by default). The Xbox app and Game Pass need it; install it again from Akati OS Center (Tweaks)
- **Akati OS Center** app (desktop and Start menu shortcut, also in the Akati OS folder): dashboard with live CPU, RAM and GPU usage and system info, install gaming apps, tweaks with switches that show the real state (GPU scheduling, Game Mode, Maximum Performance, Hibernation), temp file cleaner, theme picker, update check, English and Thai. Written in PowerShell and WPF, so the source can be read; no `.exe`
- Akati OS Dark, Light and Slideshow themes (the slideshow changes the wallpaper every 30 minutes), wallpapers, lock screen, playbook icon and default user picture
- Gaming apps page: "Recommended" installs Steam and removes the Microsoft Store; "Choose apps myself" shows pages for Steam, Epic Games Launcher, EA app, Ubisoft Connect, Battle.net, OBS Studio and the Microsoft Store
- Akati OS folder in `AtlasDesktop`: install gaming apps later, switch themes, GPU driver links, Check for Updates, GitHub and options guide links
- Update checker (`Check for Updates` in the Akati OS folder): compares the installed version with the latest GitHub release, downloads nothing
- Windows Terminal "Akati OS" color scheme and profile
- Options guide (`docs/OPTIONS.md`, English and Thai). The "Learn more" links on the setup pages open it
- Warnings about anti-cheat games on the Defender and Core Isolation options
- Warnings in the playbook description: back up your files, Windows 10 is out of support

### Fixed
- WinGet exit codes were read wrongly (an empty exit code), so `GAMEAPPS.ps1` thought installs had failed and ran the Steam installer a second time. It now reads the exit code correctly and checks whether an app is already installed

### Changed
- Playbook name (AkatiOS10), version and UniqueId; supports Windows 10 22H2 (19045) only
- Boot menu shows "Akati OS 10 v1.3.0", Settings and winver show "Akati OS v1.3.0"; the version is also saved to `HKLM\SOFTWARE\AkatiOS`
- Maximum Performance and Disable Hibernation are checked by default
- Install guide and Git links point to the Akati OS GitHub page
- The "Akati OS" text on the wallpapers moved inwards, so it is not cut off on 4:3 and 5:4 screens
- The Atlas folder shortcut on the desktop and in the Start menu uses the Akati OS icon instead of the Atlas logo

### Removed
- AtlasOS wallpapers, themes and folder icon (no Atlas logo)
- AtlasOS website, donate, Git and support links from playbook.conf and OEM information
