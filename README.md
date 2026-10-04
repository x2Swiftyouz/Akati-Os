# Akati OS

Personal Windows 11 playbook for [AME Wizard](https://ameliorated.io), focused on gaming performance, privacy, debloat and a custom theme.

Akati OS is based on [AtlasOS](https://github.com/Atlas-OS/Atlas) v0.5.0 and is licensed under GPL-3.0. It is **not** an official AtlasOS project. Every change from AtlasOS is listed in [docs/CHANGES-FROM-ATLAS.md](docs/CHANGES-FROM-ATLAS.md).

> ⚠️ Back up your files first. A playbook cannot be fully undone: to go back, reinstall Windows. Test in a virtual machine first.

## ภาษาไทย

Akati OS คือ playbook สำหรับ Windows 11 เน้นเล่นเกม ความเป็นส่วนตัว ลบแอปที่ไม่ใช้ และธีมของตัวเอง ดัดแปลงจาก AtlasOS v0.5.0 (GPL-3.0) ไม่ใช่โปรเจกต์ทางการของ AtlasOS

- โหลดไฟล์ `.apbx` จากหน้า [Releases](../../releases/latest) แล้วตรวจ SHA256 ก่อนใช้ (ดูวิธีด้านล่าง)
- **สำรองไฟล์ก่อน** ย้อนกลับไม่ได้ทั้งหมด ถ้าจะกลับต้องลง Windows ใหม่
- ทดสอบใน VM ก่อนใช้กับเครื่องจริง ดู [docs/TESTING.md](docs/TESTING.md)

## Requirements

- Windows 11 24H2 (build 26100), 25H2 (build 26200) or 26H2 (build 26300)
- Windows 11 26H1 (build 28000, for some new devices only) is not supported
- Internet connection during setup
- A valid Windows license (this playbook does not activate Windows)

## Features

- All AtlasOS v0.5.0 performance, privacy and debloat tweaks
- Akati OS Dark and Akati OS Light themes, wallpapers and lock screen
- Optional setup pages for gaming software: Steam, Epic Games Launcher, EA app, Ubisoft Connect, Battle.net, Discord and OBS Studio (installed with WinGet)
- Visual C++ and DirectX runtimes are always installed (from AtlasOS)
- GPU driver download shortcut for NVIDIA, AMD or Intel
- Defaults: Maximum Performance and Disable Hibernation are checked

## Install

1. Back up your files.
2. Download `AkatiOS_v<version>.apbx` and `SHA256SUMS.txt` from [Releases](../../releases/latest).
3. Check the hash in PowerShell. The two values must match:
   ```powershell
   (Get-FileHash .\AkatiOS_v1.2.0.apbx -Algorithm SHA256).Hash.ToLower()
   Get-Content .\SHA256SUMS.txt
   ```
4. Open AME Wizard and drag the `.apbx` file into it.
5. Follow the setup pages.

## Anti-cheat games

Some anti-cheat systems (for example Valorant Vanguard and FACEIT) need Defender, Core Isolation (VBS), TPM 2.0 or Secure Boot. Keep the recommended defaults if you play these games.

## Build from source

The playbook source is in `src/`. The `.apbx` file is a zip archive of it with the password `malte` (the AME Wizard default). From the repository root:

```
.\build.ps1     # Windows, needs 7-Zip (winget install 7zip.7zip)
./build.sh      # Linux/macOS, needs 7z or zip
```

The output is `dist/AkatiOS_v<version>.apbx` and `dist/SHA256SUMS.txt`.

Every push also builds the playbook on GitHub Actions. The `.apbx` is under **Artifacts** on the run page.

## Release (maintainer)

1. Update the version everywhere: `src/playbook.conf` (`Title`, `Version`), `src/Configuration/tweaks/misc/config-oem-information.yml` (`$version`), `src/CREDITS.txt`, `src/README.md`, `README.md` and a new `## v<version>` section in `src/CHANGELOG.md`.
2. Run the checklist in [docs/TESTING.md](docs/TESTING.md).
3. Merge to `main`, then tag and push:
   ```
   git tag v1.2.0
   git push origin v1.2.0
   ```
4. GitHub Actions checks that the tag matches `playbook.conf`, builds the `.apbx` and publishes the release with `SHA256SUMS.txt`. Release notes come from `CHANGELOG.md`.

## Documentation

- [docs/TESTING.md](docs/TESTING.md): VM test checklist (24H2, 25H2, 26H2)
- [docs/CHANGES-FROM-ATLAS.md](docs/CHANGES-FROM-ATLAS.md): every change from AtlasOS and what `GAMEAPPS.ps1` downloads
- [src/CHANGELOG.md](src/CHANGELOG.md): changes per version

## License and credits

GPL-3.0, see [LICENSE](LICENSE). Source of this modified version must stay available.

- [AtlasOS](https://github.com/Atlas-OS/Atlas) team, for the base playbook (GPL-3.0)
- [Ameliorated](https://ameliorated.io), for AME Wizard
