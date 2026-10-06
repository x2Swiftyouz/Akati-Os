# Akati OS

Personal Windows 11 playbook for [AME Wizard](https://ameliorated.io), focused on gaming performance, privacy, debloat and a custom theme.

Akati OS is based on [AtlasOS](https://github.com/Atlas-OS/Atlas) v0.5.0 and is licensed under GPL-3.0. It is **not** an official AtlasOS project.

## ภาษาไทย

Akati OS คือ playbook สำหรับ Windows 11 เน้นเล่นเกม ความเป็นส่วนตัว ลบแอปที่ไม่ใช้ และธีมของตัวเอง ดัดแปลงจาก AtlasOS v0.5.0 (GPL-3.0) ไม่ใช่โปรเจกต์ทางการของ AtlasOS

## Requirements

- Windows 11 24H2 (build 26100), 25H2 (build 26200) or 26H2 (build 26300)
- Windows 11 26H1 (build 28000, for some new devices only) is not supported
- Internet connection during setup
- A valid Windows license (this playbook does not activate Windows)

## Features

- All AtlasOS v0.5.0 performance, privacy and debloat tweaks
- Akati OS Dark and Akati OS Light themes, wallpapers and lock screen
- No apps are installed during setup: install them when you want from Akati OS Center. Optional (ticked by default): remove the Microsoft Store, turn off unused services (printing, search indexing, SuperFetch, network discovery, MSDTC), notifications and Xbox Game Bar, timer resolution 0.5 ms, the Sticky Keys shortcuts, an Akati OS desktop right-click menu and an icon next to the clock (free up RAM, your apps, Game boost and more, and Game boost that starts by itself with your games)
- Visual C++ and DirectX runtimes are always installed (from AtlasOS)
- **Akati OS Center** app, the one place for everything: install and update gaming apps (Steam, Epic Games Launcher, EA app, Ubisoft Connect, Battle.net, Riot Client, GOG GALAXY, Rockstar Games Launcher, Discord, OBS Studio, MSI Afterburner), GPU driver links, **Game boost** (one-click Game Mode, ping test, startup apps), gaming tweaks, cleaner, themes, accent colors, wallpapers, Akati OS cursor and sounds, live CPU/RAM/GPU usage, problem report, update check and **Tweaks** with every AtlasOS setting in English and Thai (no Atlas folder shortcut)
- Gaming tweaks in Akati OS Center: Hardware-accelerated GPU scheduling and Optimizations for windowed games
- Akati OS Slideshow theme and a Windows Terminal color scheme
- Defaults: Maximum Performance and Disable Hibernation are checked

## Install

1. Back up your files. This playbook cannot be fully undone. To go back, reinstall Windows.
2. Test in a virtual machine first.
3. Download `AkatiOS_v1.4.1.apbx` from Releases and check its SHA256 hash against `SHA256SUMS.txt`.
4. Open AME Wizard and drag the `.apbx` file into it.
5. Follow the setup pages.

## Anti-cheat games

Some anti-cheat systems (for example Valorant Vanguard and FACEIT) need Defender, Core Isolation (VBS), TPM 2.0 or Secure Boot. Keep the recommended defaults if you play these games.

## Build from source

The playbook source is in `src/`. The `.apbx` file is a zip archive of it with the password `malte`. From the repository root:

```
.\build.ps1     # Windows, needs 7-Zip
./build.sh      # Linux/macOS, needs 7z or zip
```

The output is `dist/AkatiOS_v<version>.apbx` and `dist/SHA256SUMS.txt`.

## Credits

- [AtlasOS](https://github.com/Atlas-OS/Atlas) team, for the base playbook
- [Ameliorated](https://ameliorated.io), for AME Wizard

See `CREDITS.txt` for the list of changes from AtlasOS.
