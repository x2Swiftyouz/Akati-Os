# Akati OS options guide

What each option on the Akati OS setup pages does. The "Learn more" links in AME Wizard open this page.
คู่มือตัวเลือกในหน้าติดตั้ง Akati OS ภาษาไทยอยู่ใต้ภาษาอังกฤษในแต่ละหัวข้อ

Most options can be changed later in **Akati OS Center > Tweaks** (all AtlasOS settings, with search).
ตัวเลือกส่วนใหญ่เปลี่ยนทีหลังได้ใน Akati OS Center > ปรับแต่ง (รวมการตั้งค่าทั้งหมดของ AtlasOS ค้นหาได้)

> If you play online games with anti-cheat (for example Valorant or FACEIT), keep the recommended defaults. Some anti-cheat systems need Windows security features such as Core Isolation (VBS), TPM 2.0 or Secure Boot.
>
> ถ้าเล่นเกมออนไลน์ที่มี anti-cheat (เช่น Valorant, FACEIT) ให้ใช้ค่าแนะนำ เพราะบางระบบต้องการให้ฟีเจอร์ความปลอดภัยของ Windows เปิดอยู่

## Defender

- **Enable Defender (recommended)**: keeps Microsoft Defender antivirus.
- **Disable Defender**: removes Defender. Your PC has no antivirus unless you install one. For advanced users only.

**ภาษาไทย**: เปิด Defender (แนะนำ) คือเก็บโปรแกรมป้องกันไวรัสของ Windows ไว้ ส่วนปิด Defender คือเอาออก เครื่องจะไม่มีโปรแกรมป้องกันไวรัสจนกว่าจะติดตั้งเอง เหมาะกับผู้ใช้ที่รู้ว่ากำลังทำอะไรเท่านั้น
Change later: Akati OS Center > Tweaks > Security > Defender

## Mitigations

- **Default Windows Mitigations (recommended)**: keeps CPU security mitigations (Spectre, Meltdown and others).
- **Disable All Mitigations**: can improve performance on older CPUs, but reduces security and can make modern CPUs slower.

**ภาษาไทย**: ค่าแนะนำคือคงระบบป้องกันช่องโหว่ CPU ไว้ การปิดอาจทำให้ CPU รุ่นเก่าเร็วขึ้นเล็กน้อย แต่ปลอดภัยน้อยลง และ CPU รุ่นใหม่อาจช้าลง
Change later: Akati OS Center > Tweaks > Security > Mitigations

## Automatic updates

- **Disable Automatic Windows Updates** (default): Windows does not install updates by itself. You still get update notifications. Install updates yourself in Settings, regularly.
- **Enable Automatic Windows Updates**: the normal Windows behaviour.

**ภาษาไทย**: ค่าเริ่มต้นคือปิดการอัปเดตอัตโนมัติ Windows จะแค่แจ้งเตือน คุณต้องเข้า Settings ไปอัปเดตเองเป็นประจำ เพราะอัปเดตความปลอดภัยสำคัญมาก
Change later: Akati OS Center > Tweaks > General Configuration > Automatic Updates

## General options

- **Disable Hibernation** (ticked): turns off hibernation and saves disk space. Shut down and restart work normally. (AtlasOS always turns off Fast Startup.)
- **Maximum Performance (Disable Power Saving)** (ticked): uses the "Atlas Power Scheme" and turns off power saving features. Best for desktops. On a laptop it uses more battery and makes it warmer.
- **Disable Core Isolation (may break anti-cheat games)** (not ticked): turns off Virtualization Based Security. Can give a little more performance, but reduces security and some anti-cheat systems may not start.

**ภาษาไทย**
- ปิด Hibernation (ติ๊กไว้): ปิดโหมดไฮเบอร์เนต ประหยัดพื้นที่ดิสก์ ปิดเครื่องและรีสตาร์ตได้ตามปกติ (Fast Startup ถูก AtlasOS ปิดเสมออยู่แล้ว)
- Maximum Performance (ติ๊กไว้): ใช้ power plan ประสิทธิภาพสูงสุดและปิดการประหยัดพลังงาน เหมาะกับคอมตั้งโต๊ะ ถ้าเป็นโน้ตบุ๊กจะเปลืองแบตและร้อนขึ้น
- ปิด Core Isolation (ไม่ติ๊ก): อาจเร็วขึ้นเล็กน้อย แต่ปลอดภัยน้อยลง และเกมที่มี anti-cheat บางเกมอาจเปิดไม่ได้

Change later: Akati OS Center > Tweaks > General Configuration (Hibernation, Power-saving) and Akati OS Center > Tweaks > Security > Core Isolation (VBS)

## Software options

- **Remove Snipping Tool App**: removes the Snipping Tool app.
- **Remove Microsoft Edge**: removes Edge. Install another browser first, or tick "Install a Browser".
- **Install a Browser**: shows the browser page (see [Web browsers](#web-browsers)).

**ภาษาไทย**: เลือกเอา Snipping Tool หรือ Microsoft Edge ออก ถ้าเอา Edge ออกให้ติ๊ก "Install a Browser" ด้วย จะได้มีเบราว์เซอร์ใช้

## Web browsers

Brave, LibreWolf and Firefox are privacy friendly. Chrome is not recommended for privacy. The browser is downloaded from its official website and its settings are not changed.

**ภาษาไทย**: Brave, LibreWolf และ Firefox เน้นความเป็นส่วนตัว ไม่แนะนำ Chrome เบราว์เซอร์โหลดจากเว็บไซต์ทางการและไม่ได้แก้การตั้งค่าใด ๆ

## Gaming apps

Akati OS does not install gaming apps during setup. Install them when you want in **Akati OS Center > Gaming apps**: game launchers (Steam, Epic Games Launcher, EA app, Ubisoft Connect, Battle.net, Riot Client with VALORANT, GOG GALAXY, Rockstar Games Launcher), chat and streaming (Discord, OBS Studio) and tools (MSI Afterburner). They are installed with WinGet, which checks each installer. If WinGet is not available, Steam is downloaded from its official website. Discord is always downloaded from discord.com and installed with its normal installer (a silent install breaks Discord), as the signed-in user; it opens when it is done. Riot Client is installed with Riot's official VALORANT (Asia Pacific) installer, only when it is signed by Riot Games; its window opens and you click Install (League of Legends and TFT are added from Riot Client). Installed apps move to **Installed** at the top and have **Open**; the **...** button has **Open folder** and **Uninstall** (runs the app's own uninstaller). Click **Get** on several apps and they install one after another; **Get Steam and Discord** does both in one click. App updates are checked with WinGet the first time the page opens.
Visual C++ and DirectX runtimes are always installed during setup.

**ภาษาไทย**: Akati OS ไม่ติดตั้งแอปเกมให้ตอนลง กดติดตั้งเองได้ใน Akati OS Center > แอปเกม (Steam, Epic, EA, Ubisoft, Battle.net, Riot Client/VALORANT, GOG GALAXY, Rockstar, Discord, OBS, MSI Afterburner) ติดตั้งผ่าน WinGet ซึ่งตรวจไฟล์ติดตั้งทุกครั้ง ถ้าไม่มี WinGet จะโหลด Steam จากเว็บไซต์ทางการ ส่วน Discord โหลดจาก discord.com และติดตั้งแบบปกติเสมอ แล้วเปิดขึ้นมาเองเมื่อเสร็จ Riot Client ใช้ตัวติดตั้ง VALORANT (เอเชียแปซิฟิก) ทางการของ Riot ซึ่งตรวจลายเซ็น Riot Games ก่อนรัน แล้วกด Install ในหน้าต่างของมัน แอปที่ติดตั้งแล้วมีปุ่ม "เปิด" และปุ่ม ... สำหรับเปิดโฟลเดอร์หรือถอนการติดตั้ง

## GPU drivers

Akati OS does not install GPU drivers. **Akati OS Center > Gaming apps** has buttons that open the NVIDIA, AMD and Intel driver download pages. It shows the version and date of the installed driver and says when it is more than 6 months old.

**ภาษาไทย**: Akati OS ไม่ติดตั้งไดรเวอร์การ์ดจอให้ ในหน้าแอปเกมของ Akati OS Center มีปุ่มเปิดหน้าโหลดไดรเวอร์ NVIDIA, AMD และ Intel และบอกเวอร์ชันกับวันที่ของไดรเวอร์ที่ใช้อยู่ ถ้าเก่ากว่า 6 เดือนจะเตือน

## Microsoft Store and unused services

**Remove Microsoft Store** is ticked by default. Without the Store you cannot install Store apps, and the **Xbox app and Xbox Game Pass do not work**. Gaming apps from Akati OS still install, because they use WinGet. To get the Store back, open Akati OS Center > Tweaks and turn on **Microsoft Store**, or run `wsreset -i` as administrator.

**ภาษาไทย**: "Remove Microsoft Store" ติ๊กไว้เป็นค่าเริ่มต้น ถ้าลบ Store จะติดตั้งแอปจาก Store ไม่ได้ และ**แอป Xbox กับ Game Pass จะใช้ไม่ได้** แอปเกมของ Akati OS ยังติดตั้งได้ตามปกติเพราะใช้ WinGet ถ้าต้องการ Store กลับมา เปิด Akati OS Center > ปรับแต่ง แล้วเปิดสวิตช์ Microsoft Store หรือรัน `wsreset -i` แบบผู้ดูแลระบบ

**Turn off unused services** is ticked by default. It runs the unchanged AtlasOS scripts that turn off services most gaming PCs do not use, so fewer processes run in the background:

| Service | Turn off if | Turn it on again |
|---|---|---|
| Printing (Print Spooler) | you have no printer | Akati OS Center > Tweaks > Printing > Enable |
| Search indexing (Windows Search) | you rarely search inside files; Start search still finds apps and settings, file search is slower | Tweaks > Search indexing > Minimal or Enable |
| SuperFetch (SysMain) | Windows is on an SSD | Tweaks > SysMain (Superfetch) > Enable |
| Network discovery (SSDP, NetBIOS helper, function discovery) | you do not browse other PCs or printers on your home network | Tweaks > Network discovery > Enable |
| Distributed Transaction Coordinator (MSDTC), not an AtlasOS script: `Start` = 4 | you do not run database or server software that needs it (games and normal apps do not) | `sc config msdtc start= demand` as administrator |

Untick it if you use a printer or share files between PCs at home. A restart (setup restarts at the end) applies the changes.

**ภาษาไทย**: "Turn off unused services" ติ๊กไว้เป็นค่าเริ่มต้น จะรันสคริปต์เดิมของ AtlasOS เพื่อปิดบริการที่เครื่องเล่นเกมส่วนใหญ่ไม่ได้ใช้ ได้แก่ การพิมพ์ (Print Spooler), การทำดัชนีค้นหา (Windows Search; ช่องค้นหาใน Start ยังหาแอปและการตั้งค่าได้ แต่ค้นหาไฟล์ช้าลง), SuperFetch (SysMain), การค้นหาเครื่องในเครือข่าย และ MSDTC (บริการที่ใช้กับโปรแกรมฐานข้อมูล/เซิร์ฟเวอร์ เกมไม่ได้ใช้) ถ้าใช้เครื่องพิมพ์หรือแชร์ไฟล์ในบ้านให้เอาติ๊กออก หรือเปิดกลับทีหลังได้ใน Akati OS Center > ปรับแต่ง

## Notifications and Game Bar

**Turn off notifications** (ticked by default) turns off the "Get notifications from apps and other senders" switch, so no pop-ups appear while you play. Windows Security warnings and messages from Discord or Steam are not shown as pop-ups either. Turn it on again in Settings > System > Notifications.

**Turn off Xbox Game Bar** (ticked by default) turns off Game Bar (Win+G) and its background clip recording, and the controller button that opens it. Game Mode and fullscreen optimizations stay as they are. Turn it on again in Settings > Gaming > Game Bar.

**ภาษาไทย**: "Turn off notifications" (ติ๊กไว้) ปิดสวิตช์ "Get notifications from apps and other senders" จะไม่มีป๊อปอัปเด้งระหว่างเล่นเกม รวมถึงคำเตือนของ Windows Security และข้อความจาก Discord หรือ Steam ด้วย เปิดกลับได้ที่ Settings > System > Notifications ส่วน "Turn off Xbox Game Bar" (ติ๊กไว้) ปิด Game Bar (Win+G) การอัดคลิปเบื้องหลัง และปุ่มเปิดจากจอย ไม่แตะ Game Mode เปิดกลับได้ที่ Settings > Gaming > Game Bar

## Input and latency

**Force 0.5 ms timer resolution** (ticked by default) runs the unchanged AtlasOS script "Enable timer resolution": Windows wakes up more often, so games keep a steadier frame time and lower input delay. It uses a little more power. Check it with `MeasureSleep.exe` in `C:\Windows\AtlasDesktop\3. General Configuration\Timer Resolution`.

**Turn off Sticky Keys and Filter Keys shortcuts** (ticked by default): pressing Shift 5 times or holding Shift in a game no longer opens a window. The accessibility features themselves still work from Settings > Accessibility > Keyboard.

Both can be changed later in **Akati OS Center > Tweaks > Input and latency**.

**ภาษาไทย**: "Force 0.5 ms timer resolution" (ติ๊กไว้) รันสคริปต์ "Enable timer resolution" ของ AtlasOS ทำให้เฟรมเกมนิ่งขึ้นและ input delay ลดลง ใช้ไฟเพิ่มเล็กน้อย ส่วน "Turn off Sticky Keys and Filter Keys shortcuts" (ติ๊กไว้) กด Shift 5 ครั้งหรือกดค้างในเกมจะไม่มีหน้าต่างเด้ง ฟีเจอร์ช่วยการเข้าถึงยังใช้ได้จาก Settings เปลี่ยนทีหลังได้ใน Akati OS Center > ปรับแต่ง > อินพุตและ latency

## Gaming tweaks

These are not on the setup pages. Turn them on in **Akati OS Center > Tweaks** if you want them. They do not help every PC. Try them and turn them off if games run worse.

- **Hardware-accelerated GPU scheduling**: lets the GPU manage its own memory. Needs a supported GPU and driver (for example NVIDIA GTX 10 series or newer, AMD RX 5000 series or newer). Applies after a restart. Turn off in Settings > System > Display > Graphics > Change default graphics settings.
- **Optimizations for windowed games** (Windows 11 only): lower latency for DirectX 10/11 games in windowed and borderless mode. Turn off in Settings > System > Display > Graphics > Change default graphics settings.

**ภาษาไทย**: ไม่มีในหน้าติดตั้งแล้ว เปิดได้ใน Akati OS Center > ปรับแต่ง เพราะไม่ได้ช่วยทุกเครื่อง ถ้าเปิดแล้วเกมแย่ลงให้ปิดกลับ
- Hardware-accelerated GPU scheduling: ให้การ์ดจอจัดการหน่วยความจำเอง ต้องใช้การ์ดจอและไดรเวอร์ที่รองรับ มีผลหลังรีสตาร์ต
- Optimizations for windowed games (เฉพาะ Windows 11): ลด latency ของเกม DirectX 10/11 ที่เล่นแบบหน้าต่างหรือ borderless

## More tweaks in Akati OS Center

**Akati OS Center > Tweaks** also has these sections. Each switch shows the current state of your PC (on = the Windows default unless written otherwise); turn one back if games run worse.

| Section | Switch | What it does |
|---|---|---|
| Input and latency | Timer resolution 0.5 ms | See [Input and latency](#input-and-latency) |
| | Sticky Keys and Filter Keys shortcuts | See [Input and latency](#input-and-latency) |
| Network | DNS server | Automatic, Cloudflare (1.1.1.1) or Google (8.8.8.8) on the connected network adapters. Faster web lookups; it does not change ping in games |
| | Nagle's algorithm | Off can lower delay in some older online games; most games already turn it off themselves |
| | Network adapter power saving and interrupt moderation | Off: slightly lower network delay, a little more CPU. The connection drops for a few seconds when changed |
| Display and graphics | Screen refresh rate | Shows the refresh rate of the main screen and sets the highest it can do (many screens run at 60 Hz until changed) |
| | Multiplane overlay (MPO) | Off fixes flickering and stutter on some PCs; leave it on otherwise |
| | GPU MSI mode | Message signaled interrupts for the graphics card: lower latency. Most new cards already use it |
| Memory and system | Memory compression | Advice by RAM: off with 16 GB or more, on with less. Needs SysMain (SuperFetch) on |
| | Core isolation (VBS and Memory integrity) | Off can make games up to about 10% faster but removes some malware protection; some anti-cheat needs it on |
| | Delay for startup apps | Off: apps that start at sign-in open right away |

**Game boost** can also free up standby memory (the file cache Windows keeps in RAM) when it starts, which helps PCs with little RAM. **My games** on the Game boost page: add a game's .exe to give it high CPU priority and the dedicated graphics card (laptops with two graphics chips), and optionally let Defender skip its folder. Removing the game puts all three back.

**ภาษาไทย**: หน้าปรับแต่งของ Akati OS Center มีหมวดเพิ่ม: อินพุตและ latency (timer resolution, ปุ่มลัด Sticky Keys), เครือข่าย (DNS, Nagle, การประหยัดไฟของการ์ดแลน), หน้าจอและกราฟิก (อัตรารีเฟรชสูงสุด, MPO, MSI mode ของการ์ดจอ), หน่วยความจำและระบบ (Memory compression แนะนำตาม RAM, Core isolation, หน่วงเวลาแอปตอนล็อกอิน) บูสต์เกมคืน standby memory ได้ และ "เกมของฉัน" ใช้เพิ่มไฟล์ .exe ของเกมเพื่อให้ CPU ความสำคัญสูง ใช้การ์ดจอแยก และเลือกให้ Defender ข้ามโฟลเดอร์เกมได้ ลบเกมออกแล้วทุกอย่างกลับเหมือนเดิม

## Akati OS Center

The **Akati OS Center** app (desktop and Start menu) is the one place for everything Akati OS adds: live CPU, RAM and GPU usage, gaming apps (with updates) and GPU driver links, **Game boost** (one-click Game Mode, ping test, startup apps), tweaks (the switches show the real state of your PC), temp file cleaner, themes (Dark, Light, Slideshow), accent colors, wallpapers, Akati OS cursor and sounds, **Tweaks** (gaming switches and every AtlasOS setting, with search and a restore point first), a problem report and the update check. There is no Atlas folder shortcut any more; the files stay in `C:\Windows\AtlasDesktop` because AtlasOS scripts use them. It asks for administrator rights. Switch between English and Thai at the bottom left.

Windows Terminal also gets an **Akati OS** color scheme and a "Windows PowerShell (Akati OS)" profile.

**ภาษาไทย**: แอป Akati OS Center (บน Desktop และ Start menu) รวมทุกอย่างของ Akati OS ไว้ที่เดียว: ดูการใช้ CPU, RAM, GPU แบบเรียลไทม์, ติดตั้งและอัปเดตแอปเกม ลิงก์ไดรเวอร์การ์ดจอ, **บูสต์เกม** (โหมดเกมปุ่มเดียว ทดสอบปิง จัดการแอปที่เปิดตอนบูต), ปรับแต่ง (สวิตช์แสดงสถานะจริงของเครื่อง), ล้างไฟล์ชั่วคราว, ธีม (มืด, สว่าง, สไลด์โชว์) สีหลัก วอลเปเปอร์ เคอร์เซอร์และเสียงของ Akati OS, **ปรับแต่ง** (สวิตช์เกมและการตั้งค่าทั้งหมดของ AtlasOS ค้นหาได้ และสร้างจุดคืนค่าก่อน), สร้างรายงานปัญหา และตรวจอัปเดต ไม่มีทางลัดโฟลเดอร์ Atlas แล้ว ไฟล์ยังอยู่ที่ `C:\Windows\AtlasDesktop` เพราะสคริปต์ของ AtlasOS ใช้อยู่ ต้องใช้สิทธิ์ผู้ดูแลระบบ เปลี่ยนภาษาไทย/อังกฤษได้ที่มุมซ้ายล่าง Windows Terminal จะมีธีมสี Akati OS และโปรไฟล์ "Windows PowerShell (Akati OS)" ด้วย
