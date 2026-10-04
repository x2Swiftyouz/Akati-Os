# Changelog: Akati OS for Windows 10

## v1.3.0

First Windows 10 version of Akati OS, based on AtlasOS v0.4.1 (Windows 10 22H2, build 19045).
It has the same Akati OS changes as the Windows 11 version v1.3.0.

### Added
- Akati OS Dark, Light and Slideshow themes (the slideshow changes the wallpaper every 30 minutes), wallpapers, lock screen, playbook icon and default user picture
- Setup pages for gaming software: Steam, Epic Games Launcher, EA app, Ubisoft Connect, Battle.net, Discord, OBS Studio
- GPU driver download shortcut page (NVIDIA, AMD, Intel)
- Optional gaming tweaks page (off by default): Hardware-accelerated GPU scheduling
- Akati OS folder in `AtlasDesktop`: install gaming apps later, switch themes, GPU driver links, Check for Updates, GitHub and options guide links
- Update checker (`Check for Updates` in the Akati OS folder): compares the installed version with the latest GitHub release, downloads nothing
- Windows Terminal "Akati OS" color scheme and profile
- Options guide (`docs/OPTIONS.md`, English and Thai). The "Learn more" links on the setup pages open it
- Warnings about anti-cheat games on the Defender and Core Isolation options
- Warnings in the playbook description: back up your files, Windows 10 is out of support

### Changed
- Playbook name (AkatiOS10), version and UniqueId; supports Windows 10 22H2 (19045) only
- Boot menu shows "Akati OS 10 v1.3.0", Settings and winver show "Akati OS v1.3.0"; the version is also saved to `HKLM\SOFTWARE\AkatiOS`
- Maximum Performance and Disable Hibernation are checked by default
- Install guide and Git links point to the Akati OS GitHub page

### Removed
- AtlasOS wallpapers and themes (no Atlas logo)
- AtlasOS website, donate, Git and support links from playbook.conf and OEM information
