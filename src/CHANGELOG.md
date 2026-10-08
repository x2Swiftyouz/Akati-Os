# Changelog

## Unreleased

### Added
- **Akati Score** (0-100) on the Health page and the Dashboard: Akati Doctor, startup apps, memory in use, ping and free space, with what would raise it
- **Play time** of each game in My games (counted by the icon next to the clock) and when you last played it
- Cleaner: **Clean automatically every week** (Sundays at 12:00, or when the PC is on next; task `\AkatiOS\Akati OS clean`)
- **Tour** after the welcome (and F1 or About > Take the tour): five short steps through the main pages
- Akati OS Center look **By time** (light from 7:00 to 19:00), and Tweaks > Windows look > **Windows light by day, dark at night**
- Akati OS Center remembers where its window was and the last page
- Keyboard: an accent ring shows the focused button or switch, Tab moves between them, arrow keys move in the sidebar, Ctrl+Tab / Ctrl+Shift+Tab switch pages, F1 starts the tour
- The icon next to the clock tells you once when a new Akati OS version is out (checked a minute after sign-in and then twice a day; switch: Tweaks > System > Tell me about new versions), and shows it at the top of its menu
- GitHub issue forms for bugs and ideas (English and Thai); GitHub issues in Akati OS Center opens them

## v1.5.0

### Added
- **Performance widget**: a small bar on top of other windows and borderless games with CPU, RAM, GPU, GPU temperature (NVIDIA) and ping. Open it from the icon next to the clock or Tweaks > System; drag to move, right-click to close; it comes back at sign-in while it was open
- Appearance: **Style presets** (Neon, Ocean, Ember, Sakura, Stealth for OLED screens) set the wallpaper, accent color, Akati OS Center look, cursor and sounds in one click, and an accent color **from the wallpaper** (the most colorful hue of your desktop picture)
- Three new wallpapers: **OLED** and **OLED logo** (true black, so OLED pixels stay off) and **Ember**
- Tweaks > **Windows look**: dark mode, accent color on title bars and the taskbar, transparency effects
- Dashboard: a **Health** chip shows what Akati Doctor found (click to open the Health page)
- New **Health** page in Akati OS Center (Ctrl+5):
  - **Akati Doctor** checks the icon next to the clock, the desktop menu, the power plan, free space, a waiting restart, Memory integrity, devices with a problem and blue screens, with a button that fixes or opens each one, and **Repair Windows files** (DISM and SFC)
  - On Windows builds that do not record the startup time (imOS), a **Record the startup time** button turns the Diagnostics-Performance log on; the time shows after the next restart
  - How long Windows took to start (last and average), and the temperatures Windows reports (ACPI thermal zone, NVIDIA GPU; also as chips on the Dashboard, orange from 80 °C and red from 90 °C). No sensor driver is installed, so anti-cheats are not affected
  - Crashes of the last 30 days: blue screens with their code, sudden power loss and apps that stopped working
  - **Windows Update**: pause for 1 or 5 weeks, resume, and the date the pause ends
  - **Change history**: the last 30 switches you changed, each with Undo
  - **Backup**: saves the settings, My games with their profiles and every switch to a .json file, and restores them on a new install
- Tweaks > Input and latency: **Mouse acceleration** (Enhance pointer precision, applies at once), **Lower other sounds during calls** and **Short key repeat delay**
- **My games, one click to play**: each game has a **Play** button and its own profile: start Game boost first, keep the game off CPU 0 (the icon next to the clock does it while the game runs) and the Memory integrity setting it needs (on for Valorant, off for FiveM; Play offers to switch and restart)
- Game boost > **FiveM**: finds FiveM, clears its cache folders (game files and settings stay), opens its folder, adds it to My games, and tests the connection time to your server (IP or IP:port)
- Icon next to the clock: **Anti-cheat mode** and **Power plan** submenus, and keys that work in games: **Ctrl+Alt+B** starts or stops Game boost, **Ctrl+Alt+R** frees up RAM (switch in Tweaks > System). Automatic Game boost also notices the FiveM game process
- Starting Game boost plays a short sound and the icon pulses (can be turned off on the Game boost page)
- Setup option **Turn off more unused services** (ticked, on the Microsoft Store page): maps, phone, smart card, payments and NFC, wallet, parental controls, retail demo, Windows Insider, AllJoyn, fax, media sharing and recommended troubleshooting. Switch in Akati OS Center > Tweaks to turn them off or back to the Windows defaults. Also WAP Push, Remote Desktop, WinRM, smart card certificates, Hyper-V guest services and the Edge updaters
- Akati OS Center > Tweaks > **Services**: switches for Xbox services, IP Helper, Windows Hello biometrics, scanners and cameras (WIA), Mobile hotspot, the notification service and Connected Devices (not changed during setup)
- Game boost > **Anti-cheat mode**: Valorant mode turns Memory integrity (HVCI) on, FiveM mode turns it off, shows the current state and offers a restart
- **Akati OS icon next to the clock** (setup option on the Notifications page, ticked; switch in Tweaks): CPU and RAM when you point at it, a menu with your apps and tools, and the **automatic Game boost**: it starts when a game from My games opens and stops when the game closes (Game boost page)
- **Search everything with Ctrl+K** (or the search field in the sidebar): pages, settings, gaming apps, your games and actions such as free up RAM, flush DNS or start Game boost, in English and Thai
- **Light look** for Akati OS Center: Appearance > Akati OS Center look (Auto follows Windows, Dark, Light), also with Mica on Windows 11
- **What's new** window once after an update, **Reset to Windows defaults** for the tweaks, and the network card shows Wi-Fi or Ethernet, the link speed and the IP address
- Akati OS Center opens faster: a small window shows right away while it loads, and slow checks (Microsoft Store, network adapter, DNS, memory compression) run in the background
- Setup page **Input and latency** (all ticked): timer resolution 0.5 ms (AtlasOS script), Sticky Keys / Filter Keys shortcuts off, and **Akati OS on the desktop right-click menu**: free up RAM, open Akati OS Center, my apps, start or stop Game boost, clean junk files, ping test, flush DNS cache, restart Explorer, restart into BIOS. Free up RAM, Game boost and BIOS run through a task of the signed-in user, without a UAC prompt each time
- Akati OS Center > Tweaks: new sections **Input and latency**, **Network** (DNS: Automatic / Cloudflare / Google, Nagle's algorithm, network adapter power saving and interrupt moderation), **Display and graphics** (highest screen refresh rate, multiplane overlay, GPU MSI mode) and **Memory and system** (memory compression with advice by RAM, core isolation, startup app delay). The Dashboard shows the screen refresh rate
- Game boost: frees up standby memory, and **My games**: high CPU priority, the dedicated graphics card and an optional Defender folder exclusion for each game you add
- Gaming apps: **Riot Client** (VALORANT; League of Legends and TFT from Riot Client, official installer checked for Riot's signature), **GOG GALAXY**, **Rockstar Games Launcher** and **MSI Afterburner**
- Setup option **Turn off unused services** (ticked by default, on the Microsoft Store page): runs the unchanged AtlasOS scripts that turn off printing, search indexing, SuperFetch (SysMain) and network discovery, and disables the Distributed Transaction Coordinator (MSDTC), so fewer processes run in the background. Untick it if you use a printer or share files at home; each one can be turned on again in Akati OS Center > Tweaks
- Setup page **Notifications and Game Bar** (both ticked by default): turns off Windows notifications and Xbox Game Bar (Win+G, background clip recording, controller button). Both can be turned on again in Windows Settings; Game Mode is not changed

### Changed
- The `.apbx` files are 7z archives (password `malte`) as the AME Wizard docs describe, instead of zip archives. They are also about a quarter smaller
- Ctrl+K search: names come before descriptions, and a word only matches at the start of a word, so "ram" finds Free up RAM first and no longer finds settings that only mention "frame"
- New Akati OS logo: a white peak with a play arrow on a purple to pink tile, the same in AME Wizard (`playbook.png`), Akati OS Center, the shortcuts, the icon next to the clock, the desktop menu and the default account picture. Drawn from code by `tools/make-assets.py logos`
- The Windows 11 file is now `AkatiOS-Win11_v<version>.apbx` and shows as **AkatiOS11** / "Akati OS v<version> for Windows 11" in AME Wizard, so it is clear which file is for Windows 11 and which for Windows 10 (`AkatiOS-Win10_v<version>.apbx`, **AkatiOS10**). The README has a table of which file to use
- **Akati OS names everywhere you look**: the power plan is "Akati OS Power Scheme", script windows and setup texts say Akati OS, the setup pages point to Akati OS Center (Tweaks) instead of the Atlas folder, the Tweaks section is just "System", and the links to the AtlasOS website, Discord and documentation are removed from the settings (one link to the Akati OS GitHub page instead). The credit to AtlasOS (GPL-3.0) stays in CREDITS.txt, the README, the setup description and the About page
- Gaming apps in Akati OS Center look like the App Store: **Get** / **Open** / **Update** buttons and a progress ring, a colored letter tile for apps that are not installed, sections (game launchers, chat and streaming, tools) with a short description of each app, **...** with Open folder and Uninstall, and the version and age of the GPU driver. Installed apps show their version and size. Installed apps move to an **Installed** section at the top; a badge shows where each installer comes from (WinGet or the official site); no tick boxes any more (several **Get** clicks wait in a queue); **Get Steam and Discord** in one click; app updates are checked when the page opens and **Update all** shows how many
- Dashboard in Akati OS Center: live graphs for CPU, RAM and GPU, the busiest apps by CPU or by memory (with a Quit button; Akati OS Center shows by its own name), CPU and RAM turn orange from 85% and red from 95%, a drive with less than 15% free has a shortcut to the Cleaner, the GPU card is hidden when Windows reports no GPU usage (virtual machines), status chips (Game boost, power plan, Defender, uptime), download/upload speed and ping, every drive with free space, a greeting with the clock, and an automatic update check in the version card. Game boost can be started from the quick actions
- Cleaner in Akati OS Center cleans more: Windows Update downloads, error reports, setup logs, thumbnail cache and the web caches of Discord, Steam and Epic; browser and GPU shader caches can be ticked too. Each row says what it removes; no cookies, passwords or settings
- Windows 11: Atlas Toolbox is no longer offered (setup page, install step and the installer script in the Atlas folder are removed)
- Akati OS Center looks like macOS System Settings: colored icons in the sidebar, grouped lists with thin separators and gray section headings, macOS-style switches and buttons, neutral dark colors (the accent color stays)
- The System settings page is now part of **Tweaks**: gaming switches on top, then every AtlasOS setting with search and the restore point. Ctrl+1 to Ctrl+8 switch pages, Ctrl+F opens the search in Tweaks

### Fixed
- Anti-cheat mode on Windows builds that cannot report Memory integrity (no DeviceGuard WMI provider, seen on imOS 10): it no longer shows "restart to apply" forever, and asks for a restart only after a change
- The search field in the Akati OS Center sidebar stayed "Search" in Thai. `tools/test-center.ps1` now also fails on texts placed where the language switch cannot reach them
- The Akati OS icon next to the clock and the desktop menu task were not set up during setup: AME Wizard runs that step as SYSTEM, so the task was registered for the computer account ("No mapping between account names and security IDs"). The tasks are now registered for the signed-in user
- Settings of Akati OS Center (language, My games, automatic Game boost) were erased when a desktop menu item ran with administrator rights or when automatic Game boost was switched in the tray menu; the setup also erased the "icon wanted" mark when it wrote the version. Existing registry keys are no longer recreated
- Setup on Windows builds without `fthsvc.dll` (seen on imOS 10) showed "There was a problem starting fthsvc.dll". The Fault Tolerant Heap reset now only runs when the file exists; FTH is still turned off
- The Akati OS icon next to the clock was sometimes not set up by AME Wizard (seen on imOS 10), so it did not start after sign-in. Setup now also marks it as wanted, and Akati OS Center sets it up again when it opens. Errors of the setup go to `%ProgramData%\AkatiOS\AkatiTray.log`
- The Storage card in Akati OS Center was empty on Windows builds where WMI returns drives without a size (seen on imOS 10). Drives are now read with .NET
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
