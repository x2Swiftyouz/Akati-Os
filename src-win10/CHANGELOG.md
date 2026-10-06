# Changelog: Akati OS for Windows 10

## v1.4.1

### Added
- Setup page **Input and latency** (all ticked): timer resolution 0.5 ms (AtlasOS script), Sticky Keys / Filter Keys shortcuts off, and **Akati OS on the desktop right-click menu**: free up RAM, open Akati OS Center, my apps, start or stop Game boost, clean junk files, ping test, flush DNS cache, restart Explorer, restart into BIOS. Free up RAM, Game boost and BIOS run through a task of the signed-in user, without a UAC prompt each time
- Akati OS Center > Tweaks: new sections **Input and latency**, **Network** (DNS: Automatic / Cloudflare / Google, Nagle's algorithm, network adapter power saving and interrupt moderation), **Display and graphics** (highest screen refresh rate, multiplane overlay, GPU MSI mode) and **Memory and system** (memory compression with advice by RAM, core isolation, startup app delay). The Dashboard shows the screen refresh rate
- Game boost: frees up standby memory, and **My games**: high CPU priority, the dedicated graphics card and an optional Defender folder exclusion for each game you add
- Gaming apps: **Riot Client** (VALORANT; League of Legends and TFT from Riot Client, official installer checked for Riot's signature), **GOG GALAXY**, **Rockstar Games Launcher** and **MSI Afterburner**
- Setup option **Turn off unused services** (ticked by default, on the Microsoft Store page): runs the unchanged AtlasOS scripts that turn off printing, search indexing, SuperFetch (SysMain) and network discovery, and disables the Distributed Transaction Coordinator (MSDTC), so fewer processes run in the background. Untick it if you use a printer or share files at home; each one can be turned on again in Akati OS Center > Tweaks
- Setup page **Notifications and Game Bar** (both ticked by default): turns off Windows notifications and Xbox Game Bar (Win+G, background clip recording, controller button). Both can be turned on again in Windows Settings; Game Mode is not changed

### Changed
- Gaming apps in Akati OS Center look like the App Store: **Get** / **Open** / **Update** buttons and a progress ring, a colored letter tile for apps that are not installed, sections (game launchers, chat and streaming, tools) with a short description of each app, **...** with Open folder and Uninstall, and the version and age of the GPU driver. Installed apps show their version and size. Installed apps move to an **Installed** section at the top; a badge shows where each installer comes from (WinGet or the official site); no tick boxes any more (several **Get** clicks wait in a queue); **Get Steam and Discord** in one click; app updates are checked when the page opens and **Update all** shows how many
- Dashboard in Akati OS Center: live graphs for CPU, RAM and GPU, the busiest apps by CPU or by memory (with a Quit button; Akati OS Center shows by its own name), CPU and RAM turn orange from 85% and red from 95%, a drive with less than 15% free has a shortcut to the Cleaner, the GPU card is hidden when Windows reports no GPU usage (virtual machines), status chips (Game boost, power plan, Defender, uptime), download/upload speed and ping, every drive with free space, a greeting with the clock, and an automatic update check in the version card. Game boost can be started from the quick actions
- Cleaner in Akati OS Center cleans more: Windows Update downloads, error reports, setup logs, thumbnail cache and the web caches of Discord, Steam and Epic; browser and GPU shader caches can be ticked too. Each row says what it removes; no cookies, passwords or settings
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
