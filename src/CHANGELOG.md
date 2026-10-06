# Changelog

## v1.4.1

### Added
- Setup option **Turn off unused services** (ticked by default, on the Microsoft Store page): runs the unchanged AtlasOS scripts that turn off printing, search indexing, SuperFetch (SysMain) and network discovery, so fewer processes run in the background. Untick it if you use a printer or share files at home; each one can be turned on again in Akati OS Center > Tweaks
- Setup page **Notifications and Game Bar** (both ticked by default): turns off Windows notifications and Xbox Game Bar (Win+G, background clip recording, controller button). Both can be turned on again in Windows Settings; Game Mode is not changed

### Changed
- Dashboard in Akati OS Center: live graphs for CPU, RAM and GPU, the apps that use the most CPU (with a Quit button), status chips (Game boost, power plan, Defender, uptime), download/upload speed and ping, every drive with free space, a greeting with the clock, and an automatic update check in the version card. Game boost can be started from the quick actions
- Cleaner in Akati OS Center cleans more: Windows Update downloads, error reports, setup logs, thumbnail cache and the web caches of Discord, Steam and Epic; browser and GPU shader caches can be ticked too. Each row says what it removes; no cookies, passwords or settings
- Windows 11: Atlas Toolbox is no longer offered (setup page, install step and the installer script in the Atlas folder are removed)
- Akati OS Center looks like macOS System Settings: colored icons in the sidebar, grouped lists with thin separators and gray section headings, macOS-style switches and buttons, neutral dark colors (the accent color stays)
- The System settings page is now part of **Tweaks**: gaming switches on top, then every AtlasOS setting with search and the restore point. Ctrl+1 to Ctrl+7 switch pages, Ctrl+F opens the search in Tweaks

### Fixed
- **Check for updates** in Akati OS Center always said "Could not reach GitHub" (the answer from GitHub was read wrong). It also works now when the GitHub API limit is reached

## v1.4.0

### Known issues
- AME Wizard 0.8.4 shows "This Playbook was detected as intentionally malicious, and has been reported to Ameliorated" for Akati OS (also for v1.3.x). Akati OS is not meant to be malicious: the full source is in this repository and every change from AtlasOS is listed in `docs/CHANGES-FROM-ATLAS.md`. Ameliorated is being contacted to find out why; whatever they report will be fixed. Nothing was changed to get around AME Wizard's checks
- AME Wizard needs Microsoft Defender real-time protection turned off before it starts, otherwise it stops with "Could not initialize process"

### Added
- **Game boost** page in Akati OS Center:
  - **Game Mode** in one click: switches to the highest performance power plan, closes background apps (OneDrive, Teams, Spotify, Phone Link, Dropbox, Google Drive, Skype) and turns notifications off. Stop puts everything back, also after a restart
  - **Ping test** to cloud data centers near Thailand (Bangkok, Singapore, Hong Kong, Tokyo), with a live graph
  - **Startup apps**: turn apps that start at sign-in on or off, like the Startup tab of Task Manager
- Gaming apps:
  - the real icon of each installed app
  - a progress bar with the download percentage, and a Cancel button
  - tick several apps and install them in one go (one after another)
  - **Check for updates** and **Update all** with WinGet (Steam and Discord update themselves)
  - the GPU driver button of the graphics card in the PC is highlighted
- System settings:
  - Thai and English names and a short explanation for each AtlasOS setting
  - short button labels (Enable / Disable) and a **default** badge
  - a restore point is created before the first change (can be turned off)
- Appearance:
  - 7 **accent colors** for Akati OS Center, the Windows accent color and the Akati OS Terminal colors
  - wallpaper picker and 4 new wallpapers (Aurora, Sunset, Ocean, Mist), also in the Slideshow theme
  - **Akati OS cursor** (arrow and busy cursors) and **Akati OS sounds**, or back to the Windows ones, or no sounds
- About: **Create problem report** saves a .zip on the desktop with the Akati OS logs and PC details (user name and PC name removed)
- Welcome screen the first time Akati OS Center opens (language, gaming apps, theme)
- Keyboard shortcuts: Ctrl+1 to Ctrl+8 switch pages, Ctrl+F searches the system settings, Esc
- Pages fade in
- Window buttons like macOS at the top left: close, minimize and full screen (fills the screen, the taskbar stays visible). Double-click the top bar for full screen too
- The window fits on small screens (it was cut off on a 1024 x 768 screen)
- Akati OS Dark and Light wallpapers: "Akati OS" is in the middle, without the "performance · privacy · clean" line
- `tools/make-assets.py` draws the new wallpapers, cursors and sounds from code (no third-party art)
- Windows 11: Mica backdrop (the see-through background of Windows 11 apps) in Akati OS Center

## v1.3.1

### Changed
- **Akati OS Center is the one place for everything.** Setup no longer installs gaming apps: Steam, Discord, Epic Games Launcher, EA app, Ubisoft Connect, Battle.net and OBS Studio are installed from Akati OS Center > Gaming apps. The gaming apps pages are removed from setup; the Remove Microsoft Store page stays
- New **System settings** page in Akati OS Center with every AtlasOS setting (the whole Atlas folder), grouped and searchable
- No "Atlas" shortcut on the desktop or in the Start menu, and the Akati OS folder in `AtlasDesktop` is removed (its tools are in Akati OS Center). `AtlasDesktop` stays on disk because AtlasOS scripts use it
- `AkatiUpdate.ps1` is removed; the update check is in Akati OS Center

### Fixed
- Discord works again when installed from Akati OS Center (known issue of v1.3.0). The cause was the silent install: after `DiscordSetup.exe -s` (also used by WinGet), the first start of Discord quits at once without moving the install to its new updater, and every later start fails with "A fatal Javascript error occured: Attempt to install host that is currently running". It was not caused by an AtlasOS tweak (`tools/discord-probe.ps1` compared stock Windows and Akati OS). Discord is now installed with its normal installer, which shows a small Discord window and opens Discord when it is done

### Added
- `tools/discord-probe.ps1`: collects Discord install state, Discord logs and the Windows settings AtlasOS changes, to compare two PCs

## v1.3.0

### Known issues
- Discord is not installed automatically. On Akati OS, Discord (from discord.com or WinGet) shows "A fatal Javascript error occured: Attempt to install host that is currently running" on its first start, while it works on stock Windows. The AtlasOS tweak that causes it is not found yet (Long paths is not the cause). The setup page, Akati OS Center and `Akati OS\Install Gaming Apps\Download Discord` open the Discord download page instead

### Fixed
- WinGet exit codes were read wrongly (an empty exit code), so `GAMEAPPS.ps1` thought installs had failed and ran the Steam installer a second time. It now reads the exit code correctly and checks whether an app is already installed

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
- Fewer setup pages: a new gaming apps page with "Recommended" (Steam, remove the Microsoft Store) skips the app pages; "Choose apps myself" shows them. The GPU driver page is removed (the links are in `Akati OS\GPU Drivers`)
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
