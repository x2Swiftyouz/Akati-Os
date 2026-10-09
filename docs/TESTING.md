# Akati OS: checklist ทดสอบใน VM

ใช้ทดสอบ playbook ทุกครั้งก่อนออก release ทดสอบบน Windows 11 ทั้ง 3 เวอร์ชันที่ประกาศว่ารองรับ:

| เวอร์ชัน | Build | หมายเหตุ |
|---|---|---|
| 24H2 | 26100 | Atlas ทางการรองรับ |
| 25H2 | 26200 | Atlas ทางการรองรับ |
| 26H2 | 26300 | **Akati เพิ่มเอง Atlas ไม่รองรับ** เสี่ยงที่สุด |
| Windows 10 22H2 | 19045 | ใช้ไฟล์ `AkatiOS-Win10_v<version>.apbx` (ฐาน Atlas 0.4.1) ต้องลง Windows ใหม่ (fresh install) |

จุดเสี่ยงที่ต้องดูเป็นพิเศษ (มีเครื่องหมาย ⚠️ ในรายการด้านล่าง):
1. `IsChecked` ใน `playbook.conf` (Atlas ทางการไม่เคยใช้)
2. หน้าเลือกแอปเกม 3 หน้า และ `GAMEAPPS.ps1`
3. หน้าเลือกการ์ดจอ (v1.2.0 โหลดไม่ได้เพราะหน้านี้มี 4 ตัวเลือก ตั้งแต่ v1.2.1 เป็น checkbox 3 ตัว)
4. build 26300

---

## 0. เตรียมครั้งเดียว

### ISO
- [ ] 24H2 และ 25H2: โหลดจาก https://www.microsoft.com/software-download/windows11 เท่านั้น
- [ ] 26H2: ถ้ายังไม่มี ISO ทางการ ใช้ Windows Insider Preview ISO จาก https://www.microsoft.com/software-download/windowsinsiderpreviewiso (ต้องล็อกอิน Insider)
- [ ] Windows 10 22H2: https://www.microsoft.com/software-download/windows10 (ใช้ Media Creation Tool สร้าง ISO) ไม่ต้องมี TPM
- [ ] จด build ของแต่ละ ISO ไว้ในตารางผลทดสอบท้ายไฟล์

### สร้าง VM (เลือกอย่างใดอย่างหนึ่ง)

**Hyper-V** (Windows Pro/Enterprise)
- Generation 2, เปิด Secure Boot (template: Microsoft Windows), เปิด TPM
- 4 vCPU, RAM 8 GB (ปิด Dynamic Memory), ดิสก์ 64 GB
- Network: Default Switch (ต้องมีอินเทอร์เน็ต)

**VirtualBox 7.x**
- Type: Windows 11 (64-bit), เปิด EFI, TPM 2.0 และ Secure Boot
- 4 CPU, RAM 8 GB, ดิสก์ 64 GB, Network: NAT

### ติดตั้ง Windows ใน VM
- [ ] ติดตั้งแบบปกติ ใช้ local account (ต้องเป็น ISO ของ **Windows 11** ไม่ใช่ Windows 10)
- [ ] เช็ก build: เปิด PowerShell แล้วรัน
  ```powershell
  (Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion') | Select-Object DisplayVersion, CurrentBuild, UBR
  ```
- [ ] Windows Update จนไม่เหลืออัปเดต แล้วรีสตาร์ต (playbook ต้องการ `NoPendingUpdates`)
- [ ] ติดตั้ง AME Wizard เวอร์ชันล่าสุดจาก https://ameliorated.io
- [ ] **สร้าง checkpoint/snapshot ชื่อ `clean-<build>`** ทุกการทดสอบจะเริ่มจาก snapshot นี้

### เตรียมไฟล์ playbook
- [ ] build จาก repo: `.\build.ps1` (หรือ `./build.sh`)
- [ ] ก๊อป `dist\AkatiOS-Win11_v<version>.apbx` และ `dist\SHA256SUMS.txt` เข้า VM
- [ ] ตรวจ hash ใน VM:
  ```powershell
  (Get-FileHash .\AkatiOS-Win11_v1.6.0.apbx -Algorithm SHA256).Hash.ToLower()
  Get-Content .\SHA256SUMS.txt
  ```
  สองค่าต้องตรงกัน

---

## 1. รอบทดสอบ

ทำทุกรอบโดยเริ่มจาก snapshot `clean-<build>`

| รอบ | ตั้งค่า | ทำบน |
|---|---|---|
| **A: ค่าเริ่มต้น** | ไม่แตะอะไรเลย กด Next ทุกหน้า | 24H2, 25H2, 26H2 |
| **B: ติ๊กทุกอย่าง** | ติ๊ก Disable Core Isolation แล้วติดตั้งแอปเกมทุกตัวจาก Akati OS Center | 25H2 อย่างน้อย 1 เครื่อง |
| **C: เอาออกทุกอย่าง** | เอาติ๊ก Remove Microsoft Store, Hibernation และ Maximum Performance ออก | 24H2 หรือ 26H2 |
| **W10: Windows 10** | ค่าเริ่มต้นทั้งหมด ใช้ `AkatiOS-Win10_v<version>.apbx` | Windows 10 22H2 |

รอบ W10 ใช้ checklist เดียวกันทั้งหมด ยกเว้น: บูตเมนูต้องเป็น `Akati OS 10 v<version>`, ไม่มีการตั้ง ThemeMRU (Windows 10 ไม่ใช้) และใน AME Wizard ต้องไม่ยอมรันไฟล์ Windows 10 บน Windows 11 และกลับกัน

---

## 2. ระหว่างรัน AME Wizard

### ก่อนเริ่ม
- [ ] ลาก `.apbx` เข้า AME Wizard แล้วโหลดได้ ไม่ขึ้น error (ถ้าขึ้น "There is an error in XML document" ให้จดบรรทัดและข้อความไว้ แล้วเพิ่มกฎนั้นใน `tools/check-playbook.py`)
- [ ] ⚠️ 26H2: AME Wizard ยอมรับ build 26300 ไม่ขึ้นว่า unsupported
- [ ] หน้า Requirements ทำตามที่ AME Wizard บอกได้ครบ (ปิด Defender, เสียบปลั๊ก, อินเทอร์เน็ต ฯลฯ)
- [ ] จดไว้ว่าขึ้นป้าย "Malicious Playbook" หรือไม่ (ใช้ประกอบข้อความถึง Ameliorated)

### ข้อความในหน้าต่าง ๆ
- [ ] Title แสดง `Akati OS v1.6.0`
- [ ] Description มีคำเตือนให้สำรองไฟล์และข้อความ "Not an official AtlasOS project"
- [ ] หน้า Defender มีคำเตือน anti-cheat (Valorant, FACEIT)
- [ ] ลิงก์ "Install guide" เปิด https://github.com/x2Swiftyouz/Akati-Os#readme

### ⚠️ ค่าเริ่มต้นของ checkbox (ทดสอบ `IsChecked`)
ดูตอนเปิดหน้าครั้งแรก **ก่อนกดอะไร** แล้วจดสิ่งที่เห็นจริง

| หน้า | ตัวเลือก | ควรเป็น | เห็นจริง |
|---|---|---|---|
| ตัวเลือกทั่วไป | Disable Hibernation | ☑ | |
| ตัวเลือกทั่วไป | Maximum Performance | ☑ | |
| ตัวเลือกทั่วไป | Disable Core Isolation (may break anti-cheat games) | ☐ | |
| Microsoft Store | Remove Microsoft Store | ☑ | |
| Microsoft Store | Turn off unused services | ☑ | |
| Notifications and Game Bar | Turn off notifications | ☑ | |
| Notifications and Game Bar | Turn off Xbox Game Bar | ☑ | |

ตัวเลือกจาก Atlas ที่ไม่มี `IsChecked` ให้จดไว้ด้วยว่าเริ่มต้นเป็นแบบไหน ใช้ดูว่า AME Wizard ตั้งค่า default เป็นอะไร:

| ตัวเลือก | เห็นจริง |
|---|---|
| Remove Snipping Tool App | |
| Remove Microsoft Edge | |
| Install a Browser | |

ถ้าค่าที่เห็นไม่ตรงกับคอลัมน์ "ควรเป็น" แปลว่า `IsChecked` ไม่ทำงาน ให้หยุดแล้วแจ้งพร้อมภาพหน้าจอ

### ระหว่างติดตั้ง
- [ ] ไม่มีหน้าเลือกแอปเกม และไม่มีขั้น "Installing Steam" หรือ "Installing Discord" (แอปติดตั้งจาก Akati OS Center)
- [ ] มีขั้น "Turning off unused services" และไม่ค้าง (ไม่มีหน้าต่าง "Press any key")
- [ ] ไม่มีขั้นไหนค้างเกิน 10 นาที
- [ ] ติดตั้งจบและรีสตาร์ตเองได้
- [ ] จดเวลาที่ใช้ทั้งหมด (ตั้งไว้ 15 นาที)

---

## 3. หลังติดตั้ง

รันทุกคำสั่งใน PowerShell แบบ Run as administrator

### บูตและความเสถียร
- [ ] บูตเข้า Windows ได้ ไม่วนรีบูต
- [ ] รีสตาร์ตอีก 2 ครั้งแล้วยังปกติ
- [ ] ไม่มี error ร้ายแรงใหม่ใน Event Viewer (Windows Logs > System, Critical)

### ชื่อและเวอร์ชัน
```powershell
bcdedit /enum '{current}' | Select-String description
Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\OEMInformation'
```
- [ ] บูตเมนูเป็น `Akati OS 11 v1.6.0`
- [ ] `Model` = `Akati OS v1.6.0`, `Manufacturer` = `Akati OS`
- [ ] ไม่มี `SupportURL` และ `SupportPhone`
- [ ] `winver` และ Settings > System > About แสดง Akati OS v1.6.0

### ธีม
```powershell
Get-ChildItem "$env:windir\Resources\Themes\akatios-*.theme"
Get-ChildItem "$env:windir\AtlasModules\Wallpapers\akatios-*.png"
(Get-ItemProperty 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes').CurrentTheme
```
- [ ] มีไฟล์ธีม 2 ไฟล์ และรูปภาพ 3 ไฟล์
- [ ] `CurrentTheme` ชี้ไปที่ `akatios-dark.theme`
- [ ] Wallpaper เป็นของ Akati OS และ lock screen เป็น `akatios-lockscreen.png`
- [ ] Settings > Personalization > Themes มี Akati OS Dark และ Akati OS Light อยู่บนสุด สลับไปมาได้
- [ ] รูปผู้ใช้เริ่มต้นเป็นของ Akati OS
- [ ] ไม่เห็นโลโก้ Atlas ที่ wallpaper, lock screen หรือรูปผู้ใช้
- [ ] สร้าง user ใหม่ (`net user test Test1234! /add`) แล้วล็อกอิน: user ใหม่ได้ธีม Akati OS Dark ด้วย

### ตัวเลือกทั่วไป
```powershell
powercfg /a
powercfg /getactivescheme
Get-CimInstance -Namespace root\Microsoft\Windows\DeviceGuard -ClassName Win32_DeviceGuard | Select-Object VirtualizationBasedSecurityStatus
```
| ตรวจ | ติ๊กไว้ | ไม่ได้ติ๊ก |
|---|---|---|
| Hibernation | `powercfg /a` ขึ้นว่า Hibernation ไม่พร้อมใช้งาน | Hibernation ยังมีอยู่ |
| Maximum Performance | scheme ชื่อ `Akati OS Power Scheme` | scheme เป็น Balanced (`381b4222-...`) |
| Core Isolation | `VirtualizationBasedSecurityStatus` = 0 | ค่าเท่ากับก่อนติดตั้ง |

- [ ] รอบ A: ผลตรงกับคอลัมน์ "ติ๊กไว้" สำหรับ Hibernation และ Maximum Performance และ Core Isolation ไม่ถูกปิด
- [ ] รอบ B: Core Isolation ถูกปิด
- [ ] รอบ C: ผลตรงกับคอลัมน์ "ไม่ได้ติ๊ก"

ใน VM บางเครื่อง VBS ปิดอยู่แล้วตั้งแต่ก่อนติดตั้ง ให้จดค่าก่อนรัน playbook ไว้ด้วย

### ⚠️ แอปเกม (ติดตั้งจาก Akati OS Center > แอปเกม)
- [ ] หลังติดตั้ง playbook ไม่มีแอปเกมในเครื่อง (Steam, Discord ฯลฯ)
- [ ] กดติดตั้ง Steam: วงแหวนความคืบหน้าขึ้นแทนปุ่ม ติดตั้งได้ ปุ่มเปลี่ยนเป็น "เปิด" ไอคอนเปลี่ยนจากตัวอักษร S เป็นไอคอนจริงของ Steam กด "เปิด" แล้ว Steam เปิดขึ้นมา
- [ ] Riot Client: หน้าต่างติดตั้ง VALORANT ของ Riot ขึ้นมา (ข้อความในแอปบอกให้กด Install) กด Install แล้วแถวเปลี่ยนเป็นติดตั้งแล้ว
- [ ] GOG GALAXY, Rockstar Games Launcher, MSI Afterburner ติดตั้งได้และเปิดได้
- [ ] แอปที่ติดตั้งเสร็จย้ายไปหมวด "ติดตั้งแล้ว" ด้านบน ถอนแล้วกลับไปหมวดเดิม
- [ ] ปุ่ม "ติดตั้ง Steam และ Discord" ติดตั้งทั้งสองตัวต่อกัน แล้วปุ่มเป็นสีจาง
- [ ] เปิดหน้าแอปเกมครั้งแรก แถบล่างขึ้น "กำลังตรวจอัปเดต" เอง ถ้ามีอัปเดต ปุ่มเป็น "อัปเดตทั้งหมด (n)"
- [ ] ปุ่ม ... ของแอปที่ติดตั้งแล้ว: "เปิดโฟลเดอร์" เปิดโฟลเดอร์ของแอป "ถอนการติดตั้ง" ถามก่อน แล้วตัวถอนการติดตั้งของแอปเปิดขึ้น หลังถอนเสร็จแถวกลับเป็น "ติดตั้ง" และไอคอนตัวอักษร
- [ ] การ์ดไดรเวอร์การ์ดจอ (เครื่องจริงเท่านั้น): บอกเวอร์ชันและวันที่ของไดรเวอร์ ถ้าเก่ากว่า 6 เดือนเป็นตัวสีส้ม
- [ ] ข้อความล่างสุดของหน้าต่างกลับเป็น "พร้อมใช้งาน" เมื่อเปลี่ยนหน้า (ยกเว้นงานที่ยังทำอยู่ เช่น กำลังติดตั้ง)
- [ ] กดติดตั้ง Discord: มีหน้าต่างเล็กของ Discord ขึ้น แล้ว Discord เปิดถึงหน้าล็อกอิน Quit แล้วเปิดใหม่จาก Desktop ต้อง**ไม่มี** error "Attempt to install host that is currently running"
- [ ] Discord ติดตั้งให้ user ที่ใช้อยู่ (`%LOCALAPPDATA%\Discord`) ไม่ไปอยู่ในโปรไฟล์ admin อื่น ถ้าไม่ผ่านดู log ที่ `%LOCALAPPDATA%\AkatiOS\Logs\GAMEAPPS-Discord.log` และ `GAMEAPPS-Discord-user.log` (ส่วนที่ติดตั้งในบัญชีผู้ใช้)
- [ ] รอบ B: ติดตั้งครบทุกตัว (Epic, EA, Ubisoft, Battle.net ใน `C:\Program Files\Battle.net`, OBS) และเปิดได้
- [ ] หน้า "Remove Microsoft Store" ติ๊กไว้เป็นค่าเริ่มต้น หลังติดตั้ง Microsoft Store ต้องไม่มีใน Start menu และ taskbar แต่แอปเกมยังติดตั้งจาก Center ได้
- [ ] "Turn off unused services" (ติ๊กไว้): หลังรีสตาร์ต `Get-Service Spooler, WSearch, SysMain, SSDPSRV | Select Name, Status, StartType` ต้องเป็น Stopped / Disabled ทั้งหมด และช่องค้นหาใน Start ยังหาแอปเจอ
- [ ] หน้า setup "Input and latency" ติ๊กไว้ทั้งสองข้อ หลังติดตั้ง: Task Scheduler มี "Force Timer Resolution" และ MeasureSleep.exe วัดได้ประมาณ 0.5 ms กด Shift 5 ครั้งต้องไม่มีหน้าต่าง Sticky Keys
- [ ] คลิกขวาที่ Desktop มีเมนู Akati OS: ล้าง RAM ขึ้นข้อความ "คืน RAM ได้ ..." มุมขวาล่างโดยไม่มี UAC, แอปของฉันเปิดแอปได้, เริ่ม/หยุดบูสต์เกมสลับได้และชื่อเมนูเปลี่ยน, ล้างไฟล์ขยะ/ทดสอบปิงเปิดหน้าใน Center, ล้าง DNS ขึ้นข้อความ, รีสตาร์ต Explorer ใช้ได้, รีสตาร์ตเข้า BIOS ถามก่อน (กด No)
- [ ] ไอคอน Akati OS ข้างนาฬิกา: ชี้แล้วเห็น CPU/RAM, คลิกขวามีเมนู, เปิด "บูสต์เกมอัตโนมัติ" แล้วเปิดเกมใน "เกมของฉัน" บูสต์เกมต้องเริ่มเอง ปิดเกมแล้วหยุดเอง
- [ ] Ctrl+K: พิมพ์ "dns" ขึ้น DNS server และ ล้าง DNS cache, Enter แล้วไปที่แถวนั้น (มีแถบสีกะพริบ), พิมพ์ภาษาไทยก็หาเจอ
- [ ] ธีม > หน้าตา Akati OS Center: สว่าง/มืด/อัตโนมัติ เปลี่ยนทันทีทั้งหน้าต่าง (Win11: Mica ยังโปร่ง)
- [ ] อัปเดตจากเวอร์ชันก่อน: หน้าต่าง "มีอะไรใหม่" ขึ้นครั้งเดียว ปรับแต่ง > คืนค่าเริ่มต้นของ Windows ถามก่อนแล้วสวิตช์กลับ
- [ ] Center เปิด: หน้าต่างเล็ก Akati OS Center ขึ้นทันที แล้วหน้าต่างหลักตามมา
- [ ] Center > ปรับแต่ง: มีหมวด อินพุตและ latency / เครือข่าย / หน้าจอและกราฟิก / หน่วยความจำและระบบ สวิตช์ timer resolution เปิดอยู่ เปลี่ยน DNS เป็น Cloudflare แล้ว `ipconfig /all` แสดง 1.1.1.1 กลับเป็นอัตโนมัติได้
- [ ] ถ้าจอตั้งไว้ต่ำกว่าค่าสูงสุด แถวอัตรารีเฟรชมีปุ่ม "ใช้ xxx Hz" กดแล้วจอเปลี่ยน และชิปบน Dashboard แสดงค่าใหม่
- [ ] บูสต์เกม > เกมของฉัน: เพิ่ม .exe ของเกม แถวขึ้นพร้อม "ความสำคัญสูง" และ "การ์ดจอแยก" เปิดอยู่ ลบแล้วค่ากลับ (ดู `HKLM\...\Image File Execution Options\<game>.exe`)
- [ ] Settings > System > Notifications: "Get notifications from apps" ปิดอยู่ และ Settings > Gaming > Game Bar ปิดอยู่ (เปิดกลับได้ ไม่เป็นสีเทา)
- [ ] Akati OS Center > ปรับแต่ง > เปิดสวิตช์ Microsoft Store แล้ว Store กลับมา (อาจใช้เวลาประมาณ 1 นาที)

### VC++ และ DirectX (Atlas ติดตั้งให้ทุกรอบ)
```powershell
Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*','HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*' |
    Where-Object DisplayName -like '*Visual C++*' | Select-Object DisplayName
Test-Path "$env:windir\System32\d3dx9_43.dll"
```
- [ ] มี Visual C++ 2015+ x64 และ x86 (และเวอร์ชันเก่า)
- [ ] `d3dx9_43.dll` มีอยู่ (`True`)
- [ ] รอบ C ก็ต้องมีทั้งสองอย่าง

### Akati OS extras (v1.3.0)
- [ ] **ไม่มี**ทางลัด "Atlas" บน Desktop และใน Start menu และไม่มีโฟลเดอร์ `C:\Windows\AtlasDesktop\Akati OS`
- [ ] ตั้งความละเอียด VM เป็น 1024×768 (4:3): ตัวอักษร "Akati OS" บน wallpaper ต้องไม่ถูกตัดขอบ
- [ ] ไม่มีภาพหรือธีมที่มีโลโก้ Atlas: `Get-ChildItem "$env:windir\AtlasModules\Wallpapers", "$env:windir\Resources\Themes" | Select-Object Name` ต้องไม่มีไฟล์ `atlas-*` หรือ `lockscreen*`
- [ ] `Get-ItemProperty 'HKLM:\SOFTWARE\AkatiOS'` มี `Version` และ `Edition` ถูกต้อง
- [ ] Akati OS Center > ธีม: Akati OS Light สลับเป็นธีมสว่าง และ Akati OS Slideshow ทำให้ wallpaper เปลี่ยนเอง (ตั้งเวลาไว้ 30 นาที)
- [ ] Akati OS Center > เกี่ยวกับ > ตรวจอัปเดต แสดงเวอร์ชันในเครื่องและเวอร์ชันล่าสุดบน GitHub ไม่มี error
- [ ] Akati OS Center > ปรับแต่ง (ส่วนระบบ): มีทุกหมวดของ Atlas (Software ถึง Troubleshooting และ AtlasOS) ช่องค้นหากรองได้ (ลองพิมพ์ "hibernation")
- [ ] ปรับแต่ง (ส่วนระบบ): กดปุ่ม `.reg` (เช่น Lock Screen > Hide Lock Screen) แถบสถานะขึ้น "ใช้แล้ว" กดปุ่ม `.cmd` (เช่น Hibernation > Enable Hibernation) เปิดหน้าต่างสคริปต์ของ Atlas
- [ ] Windows Terminal (ถ้ามี): Settings > Color schemes มี "Akati OS" และมีโปรไฟล์ "Windows PowerShell (Akati OS)"
- [ ] ปุ่ม "Learn more" ในหน้าติดตั้งเปิด `docs/OPTIONS.md` ไปยังหัวข้อที่ถูกต้อง

### Akati OS Center
- [ ] มีทางลัด "Akati OS Center" บน Desktop และใน Start menu ไอคอนเป็น "A" ของ Akati
- [ ] เปิดแล้วขอสิทธิ์ admin (UAC) แล้วหน้าต่างขึ้น ไม่มีหน้าต่าง PowerShell ค้าง
- [ ] แดชบอร์ด: ชื่อเครื่อง, Windows, CPU, GPU, RAM, ดิสก์ ถูกต้อง และตัวเลข CPU/RAM/GPU ขยับทุก 1-2 วินาที
- [ ] แอปเกม: แอปที่ติดตั้งแล้วขึ้น "Installed" กด Install แอปที่ยังไม่มี (เช่น OBS) แล้วติดตั้งได้ สถานะเปลี่ยนเป็น Installed
- [ ] ปรับแต่ง: สวิตช์ตรงกับสถานะจริง (เช่น Hibernation ปิด, Maximum Performance เปิด ถ้าใช้ค่าเริ่มต้น) ลองสลับ Hibernation แล้วเช็กด้วย `powercfg /a`
- [ ] ล้างไฟล์ขยะ: สแกนแล้วขึ้นขนาด กด "ล้างเลย" แล้วขึ้นว่าล้างได้เท่าไร
- [ ] ธีม: กด Apply แต่ละธีมแล้ว Windows เปลี่ยนธีม การ์ดที่ใช้อยู่มีกรอบสีม่วง
- [ ] เกี่ยวกับ: กดตรวจอัปเดตแล้วขึ้นเวอร์ชันล่าสุด
- [ ] ปุ่มภาษา: สลับไทย/อังกฤษได้ ปิดแล้วเปิดใหม่ยังจำภาษาเดิม
- [ ] ปุ่มมุมซ้ายบนแบบ Mac: แดงปิด, เหลืองย่อ, เขียวเต็มจอ (ไม่บัง taskbar) กดเขียวอีกครั้งกลับขนาดเดิม ดับเบิลคลิกแถบด้านบนก็สลับได้ ลากหน้าต่างด้วยแถบด้านบนได้
- [ ] จอ 1024×768: หน้าต่างอยู่ในจอทั้งหมด ไม่มีส่วนไหนหลุดขอบ
- [ ] เปิดครั้งแรกมีหน้าต้อนรับ 3 ขั้น ปุ่มภาษาเปลี่ยนภาษาได้ กด "เริ่มใช้งาน" แล้วเปิดครั้งต่อไปไม่ขึ้นอีก
- [ ] Windows 11: พื้นหลังของ Center โปร่งเห็นสีวอลเปเปอร์จาง ๆ (Mica) และมุมหน้าต่างโค้ง ไม่มีขอบดำ

### Akati OS Center v1.6.0
- [ ] แอปเกม: แอปที่ติดตั้งแล้วแสดงไอคอนจริง กดติดตั้ง Steam แล้วมีแถบดาวน์โหลดเป็น % กดยกเลิกระหว่างติดตั้งได้ และกลับเป็น "ติดตั้ง"
- [ ] แอปเกม: ติ๊ก 2 แอป (เช่น OBS กับ Epic) แล้วกด "ติดตั้งที่เลือก" ตัวที่สองขึ้น "รอคิว" แล้วติดตั้งต่อเองหลังตัวแรกเสร็จ
- [ ] แอปเกม: "ตรวจอัปเดต" ไม่มี error (ขึ้นว่าแอปเป็นเวอร์ชันล่าสุด หรือมีปุ่ม "อัปเดต")
- [ ] ไดรเวอร์การ์ดจอ: บนเครื่องจริงปุ่มของยี่ห้อการ์ดจอเป็นสีม่วง ใน VM ขึ้นว่าไม่พบการ์ดจอ
- [ ] บูสต์เกม: กด "เริ่ม" แล้ว `powercfg /getactivescheme` เป็น plan ประสิทธิภาพสูง กด "หยุด" แล้วกลับเป็น plan เดิม
- [ ] บูสต์เกม: กด "เริ่มทดสอบ" แล้วปิงขึ้นเป็น ms ทั้ง 4 ที่ และกราฟขยับ
- [ ] บูสต์เกม: ปิดสวิตช์ของแอปที่เปิดตอนบูต 1 ตัว แล้ว Task Manager > Startup ขึ้นเป็น Disabled ตรงกัน
- [ ] ปรับแต่ง (ส่วนระบบ): ชื่อหัวข้อเป็นภาษาไทย ปุ่มสั้นเป็น "เปิด" / "ปิด" ตัวที่เป็นค่าเริ่มต้นมีป้าย "ค่าเริ่มต้น"
- [ ] ปรับแต่ง (ส่วนระบบ): กดปุ่มแรกแล้วขึ้น "กำลังสร้างจุดคืนค่า..." ก่อน และ System Restore (`rstrui`) มีจุดคืนค่า "Akati OS Center" (ถ้า System Restore เปิดอยู่)
- [ ] ธีม: เลือกสีหลักสีฟ้า ปุ่มใน Center เปลี่ยนสีทันที และสีเน้นของ Windows (Settings > Personalization > Colors) เป็นสีนั้น
- [ ] ธีม: กดวอลเปเปอร์ Aurora แล้วพื้นหลังเปลี่ยน
- [ ] ธีม: เคอร์เซอร์ "Akati OS" แล้วลูกศรมีขอบม่วง กด "Windows" แล้วกลับเป็นแบบเดิม
- [ ] ธีม: เสียง "Akati OS" แล้ว "ลองฟัง" มีเสียง เสียบ USB แล้วมีเสียง connect กด "ไม่มีเสียง" แล้วเงียบ
- [ ] เกี่ยวกับ: "สร้างรายงานปัญหา" ได้ไฟล์ .zip บนเดสก์ท็อป ข้างในไม่มีชื่อผู้ใช้และชื่อเครื่อง
- [ ] คีย์ลัด: Ctrl+2 ไปหน้าแอปเกม, Ctrl+F ไปช่องค้นหาในหน้าปรับแต่ง, Esc ล้างคำค้น

### โฟลเดอร์ Atlas
- [ ] ไม่มีทางลัดบนเดสก์ท็อป แต่โฟลเดอร์ `C:\Windows\AtlasDesktop` ยังอยู่ (สคริปต์ของ Atlas ใช้)
- [ ] ลองสลับตัวเลือก 1 อย่างจาก Akati OS Center > ปรับแต่ง (ส่วนระบบ) (เช่น Power-saving) แล้วทำงานได้

---

## 4. ทดสอบเพิ่มเติม (ทำเมื่อมีเวลา)

### กรณีไม่มี WinGet: ใช้ลิงก์ทางการแทน
Windows Sandbox ไม่มี WinGet จึงใช้ทดสอบทางสำรองของ `GAMEAPPS.ps1` ได้
- [ ] เปิด Windows Sandbox แล้วก๊อป `src\Executables\GAMEAPPS.ps1` เข้าไป
- [ ] รัน:
  ```powershell
  powershell -ExecutionPolicy Bypass -File .\GAMEAPPS.ps1 -App Steam
  powershell -ExecutionPolicy Bypass -File .\GAMEAPPS.ps1 -App Epic
  ```
- [ ] Steam ดาวน์โหลดจากลิงก์ทางการและติดตั้งได้
- [ ] Epic ขึ้นข้อความ "skipped. Install it later from its official website." ไม่ error

### ไม่มีอินเทอร์เน็ตกลางทาง
- [ ] เริ่มรัน playbook แล้วตัดเน็ตตอนขึ้น "Installing software" (7-Zip, Visual C++, DirectX ของ Atlas): setup ต้องทำต่อจนจบ
- [ ] Akati OS Center > แอปเกม ตอนไม่มีเน็ต: กดติดตั้งแล้วขึ้นว่าติดตั้งไม่สำเร็จ ไม่ค้าง

### build ที่ไม่รองรับ
- [ ] (ถ้ามี ISO 26H1 / 28000) AME Wizard ต้องไม่ยอมรัน playbook

---

## 5. เก็บ log เมื่อเจอปัญหา

log ของ AME Wizard อยู่ที่ `C:\ProgramData\AME\Logs` (แต่ละครั้งที่รันได้โฟลเดอร์ใหม่)

```powershell
$log = Get-ChildItem 'C:\ProgramData\AME\Logs' -Directory | Sort-Object LastWriteTime -Descending | Select-Object -First 1
Compress-Archive -Path $log.FullName -DestinationPath "$env:USERPROFILE\Desktop\akati-log.zip"
Select-String -Path "$($log.FullName)\*" -Pattern 'error|GAMEAPPS|exception' | Select-Object -First 50
```

แนบ `akati-log.zip`, ภาพหน้าจอ และข้อมูลจากตารางด้านล่าง

---

## 6. ตารางผลทดสอบ

คัดลอกตารางนี้ทุกครั้งที่ทดสอบ release ใหม่

**Playbook**: Akati OS v____ SHA256: ________ AME Wizard: v____

| Windows | Build.UBR | รอบ | ผ่าน/ไม่ผ่าน | เวลา | หมายเหตุ |
|---|---|---|---|---|---|
| 24H2 | 26100.____ | A | | | |
| 25H2 | 26200.____ | A | | | |
| 26H2 | 26300.____ | A | | | |
| Windows 10 22H2 | 19045.____ | W10 | | | |
| 25H2 | 26200.____ | B | | | |
| ____ | ____ | C | | | |
| ____ | ____ | D | | | |

**ขึ้นป้าย Malicious Playbook หรือไม่**: ____

**release ได้เมื่อ**: รอบ A ผ่านทั้ง 3 build, รอบ B และ C ผ่าน และ `IsChecked` ตรงตามตารางทุกตัว
ถ้า 26H2 ไม่ผ่าน ให้เอา `26300` ออกจาก `SupportedBuilds` ก่อน release
