# Changelog

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
