# Akati OS options guide

What each option on the Akati OS setup pages does. The "Learn more" links in AME Wizard open this page.
คู่มือตัวเลือกในหน้าติดตั้ง Akati OS ภาษาไทยอยู่ใต้ภาษาอังกฤษในแต่ละหัวข้อ

Most options can be changed later in **Akati OS Center > System settings** (all AtlasOS settings, with search).
ตัวเลือกส่วนใหญ่เปลี่ยนทีหลังได้ใน Akati OS Center > ตั้งค่าระบบ (รวมการตั้งค่าทั้งหมดของ AtlasOS ค้นหาได้)

> If you play online games with anti-cheat (for example Valorant or FACEIT), keep the recommended defaults. Some anti-cheat systems need Windows security features such as Core Isolation (VBS), TPM 2.0 or Secure Boot.
>
> ถ้าเล่นเกมออนไลน์ที่มี anti-cheat (เช่น Valorant, FACEIT) ให้ใช้ค่าแนะนำ เพราะบางระบบต้องการให้ฟีเจอร์ความปลอดภัยของ Windows เปิดอยู่

## Defender

- **Enable Defender (recommended)**: keeps Microsoft Defender antivirus.
- **Disable Defender**: removes Defender. Your PC has no antivirus unless you install one. For advanced users only.

**ภาษาไทย**: เปิด Defender (แนะนำ) คือเก็บโปรแกรมป้องกันไวรัสของ Windows ไว้ ส่วนปิด Defender คือเอาออก เครื่องจะไม่มีโปรแกรมป้องกันไวรัสจนกว่าจะติดตั้งเอง เหมาะกับผู้ใช้ที่รู้ว่ากำลังทำอะไรเท่านั้น
Change later: Akati OS Center > System settings > Security > Defender

## Mitigations

- **Default Windows Mitigations (recommended)**: keeps CPU security mitigations (Spectre, Meltdown and others).
- **Disable All Mitigations**: can improve performance on older CPUs, but reduces security and can make modern CPUs slower.

**ภาษาไทย**: ค่าแนะนำคือคงระบบป้องกันช่องโหว่ CPU ไว้ การปิดอาจทำให้ CPU รุ่นเก่าเร็วขึ้นเล็กน้อย แต่ปลอดภัยน้อยลง และ CPU รุ่นใหม่อาจช้าลง
Change later: Akati OS Center > System settings > Security > Mitigations

## Automatic updates

- **Disable Automatic Windows Updates** (default): Windows does not install updates by itself. You still get update notifications. Install updates yourself in Settings, regularly.
- **Enable Automatic Windows Updates**: the normal Windows behaviour.

**ภาษาไทย**: ค่าเริ่มต้นคือปิดการอัปเดตอัตโนมัติ Windows จะแค่แจ้งเตือน คุณต้องเข้า Settings ไปอัปเดตเองเป็นประจำ เพราะอัปเดตความปลอดภัยสำคัญมาก
Change later: Akati OS Center > System settings > General Configuration > Automatic Updates

## General options

- **Disable Hibernation** (ticked): turns off hibernation and saves disk space. Shut down and restart work normally. (AtlasOS always turns off Fast Startup.)
- **Maximum Performance (Disable Power Saving)** (ticked): uses the "Atlas Power Scheme" and turns off power saving features. Best for desktops. On a laptop it uses more battery and makes it warmer.
- **Disable Core Isolation (may break anti-cheat games)** (not ticked): turns off Virtualization Based Security. Can give a little more performance, but reduces security and some anti-cheat systems may not start.

**ภาษาไทย**
- ปิด Hibernation (ติ๊กไว้): ปิดโหมดไฮเบอร์เนต ประหยัดพื้นที่ดิสก์ ปิดเครื่องและรีสตาร์ตได้ตามปกติ (Fast Startup ถูก AtlasOS ปิดเสมออยู่แล้ว)
- Maximum Performance (ติ๊กไว้): ใช้ power plan ประสิทธิภาพสูงสุดและปิดการประหยัดพลังงาน เหมาะกับคอมตั้งโต๊ะ ถ้าเป็นโน้ตบุ๊กจะเปลืองแบตและร้อนขึ้น
- ปิด Core Isolation (ไม่ติ๊ก): อาจเร็วขึ้นเล็กน้อย แต่ปลอดภัยน้อยลง และเกมที่มี anti-cheat บางเกมอาจเปิดไม่ได้

Change later: Akati OS Center > System settings > General Configuration (Hibernation, Power-saving) and Akati OS Center > System settings > Security > Core Isolation (VBS)

## Software options

- **Remove Snipping Tool App**: removes the Snipping Tool app.
- **Remove Microsoft Edge**: removes Edge. Install another browser first, or tick "Install a Browser".
- **Install a Browser**: shows the browser page (see [Web browsers](#web-browsers)).

**ภาษาไทย**: เลือกเอา Snipping Tool หรือ Microsoft Edge ออก ถ้าเอา Edge ออกให้ติ๊ก "Install a Browser" ด้วย จะได้มีเบราว์เซอร์ใช้

## Web browsers

Brave, LibreWolf and Firefox are privacy friendly. Chrome is not recommended for privacy. The browser is downloaded from its official website and its settings are not changed.

**ภาษาไทย**: Brave, LibreWolf และ Firefox เน้นความเป็นส่วนตัว ไม่แนะนำ Chrome เบราว์เซอร์โหลดจากเว็บไซต์ทางการและไม่ได้แก้การตั้งค่าใด ๆ

## Gaming apps

Akati OS does not install gaming apps during setup. Install them when you want in **Akati OS Center > Gaming apps**: Steam, Epic Games Launcher, EA app, Ubisoft Connect, Battle.net, Discord and OBS Studio. They are installed with WinGet, which checks each installer. If WinGet is not available, Steam is downloaded from its official website. Discord is always downloaded from discord.com and installed with its normal installer (a silent install breaks Discord), as the signed-in user; it opens when it is done.
Visual C++ and DirectX runtimes are always installed during setup.

**ภาษาไทย**: Akati OS ไม่ติดตั้งแอปเกมให้ตอนลง กดติดตั้งเองได้ใน Akati OS Center > แอปเกม (Steam, Epic, EA, Ubisoft, Battle.net, Discord, OBS) ติดตั้งผ่าน WinGet ซึ่งตรวจไฟล์ติดตั้งทุกครั้ง ถ้าไม่มี WinGet จะโหลด Steam จากเว็บไซต์ทางการ ส่วน Discord โหลดจาก discord.com และติดตั้งแบบปกติเสมอ แล้วเปิดขึ้นมาเองเมื่อเสร็จ

## GPU drivers

Akati OS does not install GPU drivers. **Akati OS Center > Gaming apps** has buttons that open the NVIDIA, AMD and Intel driver download pages.

**ภาษาไทย**: Akati OS ไม่ติดตั้งไดรเวอร์การ์ดจอให้ ในหน้าแอปเกมของ Akati OS Center มีปุ่มเปิดหน้าโหลดไดรเวอร์ NVIDIA, AMD และ Intel

## Microsoft Store

**Remove Microsoft Store** is ticked by default. Without the Store you cannot install Store apps, and the **Xbox app and Xbox Game Pass do not work**. Gaming apps from Akati OS still install, because they use WinGet. To get the Store back, open Akati OS Center > Tweaks and turn on **Microsoft Store**, or run `wsreset -i` as administrator.

**ภาษาไทย**: "Remove Microsoft Store" ติ๊กไว้เป็นค่าเริ่มต้น ถ้าลบ Store จะติดตั้งแอปจาก Store ไม่ได้ และ**แอป Xbox กับ Game Pass จะใช้ไม่ได้** แอปเกมของ Akati OS ยังติดตั้งได้ตามปกติเพราะใช้ WinGet ถ้าต้องการ Store กลับมา เปิด Akati OS Center > ปรับแต่ง แล้วเปิดสวิตช์ Microsoft Store หรือรัน `wsreset -i` แบบผู้ดูแลระบบ

## Gaming tweaks

These are not on the setup pages. Turn them on in **Akati OS Center > Tweaks** if you want them. They do not help every PC. Try them and turn them off if games run worse.

- **Hardware-accelerated GPU scheduling**: lets the GPU manage its own memory. Needs a supported GPU and driver (for example NVIDIA GTX 10 series or newer, AMD RX 5000 series or newer). Applies after a restart. Turn off in Settings > System > Display > Graphics > Change default graphics settings.
- **Optimizations for windowed games** (Windows 11 only): lower latency for DirectX 10/11 games in windowed and borderless mode. Turn off in Settings > System > Display > Graphics > Change default graphics settings.

**ภาษาไทย**: ไม่มีในหน้าติดตั้งแล้ว เปิดได้ใน Akati OS Center > ปรับแต่ง เพราะไม่ได้ช่วยทุกเครื่อง ถ้าเปิดแล้วเกมแย่ลงให้ปิดกลับ
- Hardware-accelerated GPU scheduling: ให้การ์ดจอจัดการหน่วยความจำเอง ต้องใช้การ์ดจอและไดรเวอร์ที่รองรับ มีผลหลังรีสตาร์ต
- Optimizations for windowed games (เฉพาะ Windows 11): ลด latency ของเกม DirectX 10/11 ที่เล่นแบบหน้าต่างหรือ borderless

## Akati OS Center

The **Akati OS Center** app (desktop and Start menu) is the one place for everything Akati OS adds: live CPU, RAM and GPU usage, gaming apps (with updates) and GPU driver links, **Game boost** (one-click Game Mode, ping test, startup apps), tweaks (the switches show the real state of your PC), temp file cleaner, themes (Dark, Light, Slideshow), accent colors, wallpapers, Akati OS cursor and sounds, **System settings** (every AtlasOS setting, with search and a restore point first), a problem report and the update check. There is no Atlas folder shortcut any more; the files stay in `C:\Windows\AtlasDesktop` because AtlasOS scripts use them. It asks for administrator rights. Switch between English and Thai at the bottom left.

Windows Terminal also gets an **Akati OS** color scheme and a "Windows PowerShell (Akati OS)" profile.

**ภาษาไทย**: แอป Akati OS Center (บน Desktop และ Start menu) รวมทุกอย่างของ Akati OS ไว้ที่เดียว: ดูการใช้ CPU, RAM, GPU แบบเรียลไทม์, ติดตั้งและอัปเดตแอปเกม ลิงก์ไดรเวอร์การ์ดจอ, **บูสต์เกม** (โหมดเกมปุ่มเดียว ทดสอบปิง จัดการแอปที่เปิดตอนบูต), ปรับแต่ง (สวิตช์แสดงสถานะจริงของเครื่อง), ล้างไฟล์ชั่วคราว, ธีม (มืด, สว่าง, สไลด์โชว์) สีหลัก วอลเปเปอร์ เคอร์เซอร์และเสียงของ Akati OS, **ตั้งค่าระบบ** (การตั้งค่าทั้งหมดของ AtlasOS ค้นหาได้ และสร้างจุดคืนค่าก่อน), สร้างรายงานปัญหา และตรวจอัปเดต ไม่มีทางลัดโฟลเดอร์ Atlas แล้ว ไฟล์ยังอยู่ที่ `C:\Windows\AtlasDesktop` เพราะสคริปต์ของ AtlasOS ใช้อยู่ ต้องใช้สิทธิ์ผู้ดูแลระบบ เปลี่ยนภาษาไทย/อังกฤษได้ที่มุมซ้ายล่าง Windows Terminal จะมีธีมสี Akati OS และโปรไฟล์ "Windows PowerShell (Akati OS)" ด้วย
