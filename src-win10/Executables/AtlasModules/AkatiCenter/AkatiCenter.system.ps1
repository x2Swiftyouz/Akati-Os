<#
.SYNOPSIS
    Akati OS Center: Updates, links, every AtlasOS setting (System) and the problem report.
    Dot-sourced by AkatiCenter.ps1 (runs in its scope: $ui, $window, T and the other parts).
#>
# ---------------------------------------------------------------------------------------------
# Updates and links
# ---------------------------------------------------------------------------------------------
Add-Mark 'Updates and links'
$script:releaseUrl = "https://github.com/$repo/releases"
function Start-UpdateCheck {
    Set-Status (T 'status.checking') $true
    $ui.UpdateButton.IsEnabled = $false
    Start-Work {
        param($repo)
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        $errors = @()
        try {
            return Invoke-RestMethod -Uri "https://api.github.com/repos/$repo/releases/latest" -Headers @{ 'User-Agent' = 'AkatiOS-Center' } -UseBasicParsing -TimeoutSec 20
        } catch { $errors += "api.github.com: $($_.Exception.Message)" }
        # The GitHub API allows 60 requests an hour per address; the release page redirects to the latest tag without that limit
        try {
            $req = [Net.HttpWebRequest]::Create("https://github.com/$repo/releases/latest")
            $req.Method = 'HEAD'; $req.AllowAutoRedirect = $false; $req.UserAgent = 'AkatiOS-Center'; $req.Timeout = 20000
            $res = $req.GetResponse()
            $location = $res.Headers['Location']; $res.Close()
            if ($location -match '/releases/tag/([^/?#]+)') { return [pscustomobject]@{ tag_name = [Uri]::UnescapeDataString($Matches[1]); html_url = $location } }
            $errors += "github.com: no release"
        } catch { $errors += "github.com: $($_.Exception.Message)" }
        [pscustomobject]@{ error = $errors -join ' | ' }
    } @($repo) {
        param($r, $ctx)
        $ui.UpdateButton.IsEnabled = $true
        $release = Get-LastOutput $r
        if (!$release -or !$release.tag_name) {
            $ui.UpdateStatus.Text = T 'update.error'; $ui.UpdateHint.Text = T 'update.error'; $ui.UpdateDot.Fill = $window.FindResource('MutedBrush')
            # The reason goes to the status bar, so a problem report screenshot shows it
            Set-Status ("$(T 'update.error') $($release.error)".Trim()); return
        }
        $script:releaseUrl = $release.html_url
        $newer = $false; $ahead = $false
        try {
            $newer = [version]($release.tag_name.TrimStart('v')) -gt [version]($version.TrimStart('v'))
            $ahead = [version]($version.TrimStart('v')) -gt [version]($release.tag_name.TrimStart('v'))
        } catch { $newer = $release.tag_name -ne $version }
        if ($ahead) {
            $msg = (T 'update.ahead') -f $release.tag_name
            $ui.UpdateStatus.Foreground = $window.FindResource('Good')
        } elseif ($newer) {
            $msg = (T 'update.new') -f $release.tag_name
            $ui.UpdateStatus.Foreground = $window.FindResource('Accent2')
            $ui.UpdateButton.Content = T 'update.open'
            $ui.UpdateButton.Tag = 'open'
            $ui.UpdateDownload.Tag = $release.tag_name; $ui.UpdateDownload.Visibility = 'Visible'
        } else {
            $msg = (T 'update.latest') -f $release.tag_name
            $ui.UpdateStatus.Foreground = $window.FindResource('Good')
        }
        $ui.UpdateStatus.Text = $msg; $ui.UpdateHint.Text = $msg
        $ui.UpdateDot.Fill = if ($newer) { $window.FindResource('Accent2') } else { $window.FindResource('Good') }
        Set-Status $msg
    }
}
$ui.UpdateButton.Add_Click({ if ($this.Tag -eq 'open') { Start-Process $script:releaseUrl } else { Start-UpdateCheck } })
$ui.QuickUpdate.Add_Click({ $ui.NavAbout.IsChecked = $true; Start-UpdateCheck })
# Download the update: the .apbx for this Windows into Downloads, checked against SHA256SUMS.txt of the release.
# AME Wizard installs it (Akati OS Center cannot run a playbook itself)
$ui.UpdateDownload.Add_Click({
    $tag = [string]$this.Tag
    $name = 'AkatiOS-{0}_{1}.apbx' -f $(if ($build -ge 22000) { 'Win11' } else { 'Win10' }), $tag
    $this.IsEnabled = $false
    Set-Status ((T 'update.downloading') -f $name) $true
    Start-Work {
        param($repo, $tag, $name)
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        $ProgressPreference = 'SilentlyContinue'
        $base = "https://github.com/$repo/releases/download/$tag"
        $file = Join-Path (Join-Path $env:USERPROFILE 'Downloads') $name
        try {
            $sums = (Invoke-WebRequest -Uri "$base/SHA256SUMS.txt" -UseBasicParsing -TimeoutSec 30).Content
            if ($sums -is [byte[]]) { $sums = [Text.Encoding]::UTF8.GetString($sums) }
            $line = @($sums -split "`n" | Where-Object { $_ -match [regex]::Escape($name) })[0]
            $expected = if ($line) { ($line.Trim() -split '\s+')[0].ToLowerInvariant() } else { '' }
            if (!$expected) { return @{ Error = 'update.badhash' } }
            Invoke-WebRequest -Uri "$base/$name" -OutFile $file -UseBasicParsing -TimeoutSec 900
            if ((Get-FileHash -LiteralPath $file -Algorithm SHA256).Hash.ToLowerInvariant() -ne $expected) {
                Remove-Item -LiteralPath $file -Force -ErrorAction SilentlyContinue
                return @{ Error = 'update.badhash' }
            }
            @{ File = $file }
        } catch { @{ Error = 'update.dlfail'; Message = $_.Exception.Message } }
    } @($repo, $tag, $name) {
        param($r, $name)
        $ui.UpdateDownload.IsEnabled = $true
        $res = Get-LastOutput $r
        if ($res -isnot [hashtable] -or $res.Error) {
            $key = if ($res -is [hashtable] -and $res.Error) { $res.Error } else { 'update.dlfail' }
            Set-Status ((T $key) -f $(if ($res -is [hashtable]) { $res.Message } else { '' })); return
        }
        Set-Status ((T 'update.downloaded') -f $name)
        Start-Process explorer.exe -ArgumentList "/select,`"$($res.File)`""
        [void][System.Windows.MessageBox]::Show(((T 'update.howto') -f $name), 'Akati OS Center', 'OK', 'Information')
    } $name
})
$ui.QuickBoost.Add_Click({
    try {
        if (Test-Boost) { Stop-Boost; Set-Status (T 'status.boostoff') } else { Start-Boost; Set-Status (T 'status.booston'); Show-BoostEffect }
    } catch { Set-Status $_.Exception.Message }
    Update-BoostCard; Update-Chips
})
$ui.QuickAtlas.Add_Click({ $ui.NavTweaks.IsChecked = $true })
$ui.LinkGithub.Add_Click({ Start-Process "https://github.com/$repo" })
$ui.LinkOptions.Add_Click({ Start-Process "https://github.com/$repo/blob/main/docs/OPTIONS.md" })
$ui.LinkAtlas.Add_Click({ Start-Process 'https://github.com/Atlas-OS/Atlas' })

# ---------------------------------------------------------------------------------------------
# System settings: every setting of the AtlasOS folder (AtlasDesktop), built from its folders, so
# nothing has to be copied and new AtlasOS settings show up by themselves. A folder with files is one
# row, each file is one button.
# ---------------------------------------------------------------------------------------------
Add-Mark 'System settings'
# Names and short explanations of the AtlasOS folders: English name, Thai name, English text, Thai text
$atlasInfo = @{
    'Drivers from Windows Update' = @('Drivers from Windows Update', 'ไดรเวอร์จาก Windows Update', 'Let Windows Update install drivers.', 'ให้ Windows Update ติดตั้งไดรเวอร์เอง')
    'GPU Drivers' = @('GPU driver tools', 'เครื่องมือไดรเวอร์การ์ดจอ', 'Remove old drivers (DDU) and install drivers without extras.', 'ลบไดรเวอร์เก่า (DDU) และติดตั้งไดรเวอร์แบบไม่มีของแถม')
    'Microsoft Copilot' = @('Microsoft Copilot', 'Microsoft Copilot', 'The Copilot AI assistant.', 'ผู้ช่วย AI Copilot')
    'Recall' = @('Recall', 'Recall', 'Windows Recall, which saves snapshots of your screen.', 'Recall ของ Windows ที่เก็บภาพหน้าจอไว้ค้นหาย้อนหลัง')
    'Automatic Updates' = @('Automatic updates', 'อัปเดตอัตโนมัติ', 'Windows installs updates by itself.', 'Windows ติดตั้งอัปเดตเอง')
    'Background Apps' = @('Background apps', 'แอปเบื้องหลัง', 'Store apps keep running in the background.', 'แอปจาก Store ทำงานต่อเบื้องหลัง')
    'CPU Idle' = @('CPU idle', 'CPU idle', 'Off keeps the CPU at full clock: slightly lower latency, much more heat and power. Turn it back on if you are unsure.', 'ปิดแล้ว CPU จะทำงานเต็มความเร็วตลอด latency ลดลงเล็กน้อยแต่ร้อนและกินไฟมากขึ้นมาก ถ้าไม่แน่ใจให้เปิดไว้')
    'Desktop Context Menu' = @('Idle switch in the desktop menu', 'สวิตช์ idle ในเมนูคลิกขวา', 'Adds a CPU idle switch to the right-click menu of the desktop.', 'เพิ่มสวิตช์ CPU idle ในเมนูคลิกขวาบนเดสก์ท็อป')
    'Delivery Optimization' = @('Delivery Optimization', 'Delivery Optimization', 'Shares Windows updates with other PCs.', 'แชร์ไฟล์อัปเดต Windows กับเครื่องอื่น')
    'FSO and Game Bar' = @('Fullscreen optimizations and Game Bar', 'Fullscreen optimizations และ Game Bar', 'Needed by Game Bar recording and some games.', 'จำเป็นสำหรับการอัดคลิปด้วย Game Bar และบางเกม')
    'File Sharing' = @('File sharing', 'การแชร์ไฟล์', 'Share files and printers on your network.', 'แชร์ไฟล์และเครื่องพิมพ์ในเครือข่าย')
    'Give Access To Menu' = @('"Give access to" menu', 'เมนู "Give access to"', 'Sharing entry in the right-click menu.', 'เมนูแชร์ในคลิกขวา')
    'Network Navigation Pane' = @('Network in File Explorer', 'Network ใน File Explorer', 'The Network item in the File Explorer sidebar.', 'รายการ Network ในแถบข้างของ File Explorer')
    'Hibernation' = @('Hibernation', 'ไฮเบอร์เนต', 'Off saves disk space (the size of your RAM).', 'ปิดไว้ประหยัดพื้นที่ดิสก์เท่ากับขนาด RAM')
    'Location' = @('Location', 'ตำแหน่งที่ตั้ง', 'Apps can ask for your location.', 'ให้แอปขอตำแหน่งของเครื่องได้')
    'Mobile Devices (Phone Link)' = @('Phone Link', 'Phone Link', 'Connect your phone to Windows.', 'เชื่อมมือถือกับ Windows')
    'Power-saving' = @('Power saving', 'การประหยัดพลังงาน', 'Off is the Akati OS Maximum Performance plan. Best for desktops.', 'ปิดคือ power plan ประสิทธิภาพสูงสุดของ Akati OS เหมาะกับคอมตั้งโต๊ะ')
    'Search Indexing' = @('Search indexing', 'การทำดัชนีค้นหา', 'Faster file search in exchange for some background work.', 'ค้นหาไฟล์ได้เร็วขึ้น แลกกับงานเบื้องหลังเล็กน้อย')
    'Sleep Study' = @('Sleep study', 'Sleep study', 'Diagnostics of sleep power use.', 'บันทึกการใช้พลังงานตอน sleep')
    'Sleep' = @('Sleep', 'โหมด sleep', 'Let the PC go to sleep.', 'ให้เครื่องเข้าโหมด sleep ได้')
    'Store App Archiving' = @('Store app archiving', 'เก็บแอปที่ไม่ได้ใช้', 'Windows removes Store apps you do not use.', 'Windows ลบแอปจาก Store ที่ไม่ได้ใช้ออกเอง')
    'System Restore' = @('System Restore', 'System Restore', 'Restore points to undo system changes.', 'จุดคืนค่าไว้ย้อนการเปลี่ยนแปลงระบบ')
    'Timer Resolution' = @('Timer resolution', 'Timer resolution', 'Advanced: a more precise system timer. Read the documentation first.', 'ขั้นสูง: timer ของระบบที่ละเอียดขึ้น อ่านเอกสารก่อนใช้')
    'Update Notifications' = @('Update notifications', 'แจ้งเตือนอัปเดต', 'Windows tells you about new updates.', 'Windows แจ้งเตือนเมื่อมีอัปเดต')
    'Web Search (includes Search Highlights)' = @('Web search in Start', 'ค้นหาเว็บใน Start', 'Bing results and search highlights in the Start menu search.', 'ผลจาก Bing และ search highlights ในช่องค้นหา Start')
    'Widgets (News and Interests)' = @('Widgets', 'วิดเจ็ต', 'News and weather on the taskbar.', 'ข่าวและสภาพอากาศบน taskbar')
    'Windows Spotlight' = @('Windows Spotlight', 'Windows Spotlight', 'Daily pictures from Microsoft on the lock screen.', 'รูปประจำวันจาก Microsoft บนหน้าล็อก')
    'Windows Updates' = @('Windows Update', 'Windows Update', 'Pause Windows Update or delay feature updates.', 'หยุด Windows Update หรือเลื่อนอัปเดตใหญ่')
    'Workplace' = @('Workplace', 'บัญชีที่ทำงาน', 'Work or school accounts and device management.', 'บัญชีที่ทำงานหรือโรงเรียน และการจัดการเครื่อง')
    'Alt-Tab' = @('Alt+Tab', 'Alt+Tab', 'The Alt+Tab window switcher.', 'หน้าสลับหน้าต่าง Alt+Tab')
    'Extract' = @('"Extract" menu', 'เมนู "Extract"', 'Extract entry for zip files in the right-click menu.', 'เมนูแตกไฟล์ zip ในคลิกขวา')
    'Run With Priority' = @('"Run with priority" menu', 'เมนู "Run with priority"', 'Start a program with a higher CPU priority from the right-click menu.', 'เปิดโปรแกรมด้วย CPU priority สูงขึ้นจากคลิกขวา')
    'Send To' = @('"Send to" menu', 'เมนู "Send to"', 'Removes rarely used items from the Send to menu.', 'ลบรายการที่ไม่ค่อยใช้ออกจากเมนู Send to')
    'Take Ownership' = @('"Take ownership" menu', 'เมนู "Take ownership"', 'Take ownership of files from the right-click menu.', 'ยึดสิทธิ์เป็นเจ้าของไฟล์จากคลิกขวา')
    'Terminals' = @('Terminals in the menu', 'Terminal ในเมนู', 'Open a terminal in a folder from the right-click menu.', 'เปิด terminal ในโฟลเดอร์จากคลิกขวา')
    'Windows 11' = @('Right-click menu style', 'รูปแบบเมนูคลิกขวา', 'The full classic menu or the new Windows 11 menu.', 'เมนูแบบเต็มแบบเก่า หรือเมนูใหม่ของ Windows 11')
    'Edge Swipe' = @('Edge swipe', 'ปัดจากขอบจอ', 'Touch screen swipes from the screen edge.', 'การปัดจากขอบจอบนจอสัมผัส')
    'App Icons on Thumbnails' = @('App icons on thumbnails', 'ไอคอนแอปบนภาพย่อ', 'Small app icon on file thumbnails.', 'ไอคอนแอปเล็ก ๆ บนภาพย่อของไฟล์')
    'Automatic Folder Discovery' = @('Automatic folder type', 'ตรวจชนิดโฟลเดอร์อัตโนมัติ', 'File Explorer guesses the view of each folder (slow on big folders).', 'File Explorer เดามุมมองของแต่ละโฟลเดอร์เอง (ช้าในโฟลเดอร์ใหญ่)')
    'Compact View' = @('Compact view', 'มุมมองแบบกระชับ', 'Less space between items in File Explorer.', 'ระยะห่างระหว่างรายการใน File Explorer น้อยลง')
    'Folders in This PC' = @('Folders in This PC', 'โฟลเดอร์ใน This PC', 'Desktop, Documents and other folders in This PC.', 'โฟลเดอร์ Desktop, Documents และอื่น ๆ ใน This PC')
    'Gallery' = @('Gallery', 'Gallery', 'The Gallery item in File Explorer.', 'รายการ Gallery ใน File Explorer')
    'Quick Access' = @('Quick access', 'Quick access', 'Pinned and recent folders in File Explorer.', 'โฟลเดอร์ที่ปักหมุดและที่ใช้ล่าสุดใน File Explorer')
    'Removable Drives in Sidebar' = @('USB drives in the sidebar', 'ไดรฟ์ USB ในแถบข้าง', 'Show USB drives twice in the File Explorer sidebar.', 'แสดงไดรฟ์ USB ซ้ำในแถบข้างของ File Explorer')
    'Lock Screen' = @('Lock screen', 'หน้าล็อก', 'The picture screen before sign-in.', 'หน้ารูปภาพก่อนเข้าสู่ระบบ')
    'Battery Flyout' = @('Battery flyout', 'หน้าต่างแบตเตอรี่', 'Old or new battery popup.', 'หน้าต่างแบตเตอรี่แบบเก่าหรือใหม่')
    'Date and Time Flyout' = @('Clock flyout', 'หน้าต่างนาฬิกา', 'Old or new clock and calendar popup.', 'หน้าต่างนาฬิกาและปฏิทินแบบเก่าหรือใหม่')
    'Volume Flyout' = @('Volume flyout', 'หน้าต่างเสียง', 'Old or new volume popup.', 'หน้าต่างปรับเสียงแบบเก่าหรือใหม่')
    'Shortcut Icon' = @('Shortcut arrow', 'ลูกศรบนทางลัด', 'The arrow on shortcut icons.', 'ลูกศรบนไอคอนทางลัด')
    'Shortcut Text' = @('"- Shortcut" text', 'คำว่า "- Shortcut"', 'Text added to the name of new shortcuts.', 'คำที่ต่อท้ายชื่อทางลัดใหม่')
    'Snap Layouts' = @('Snap layouts', 'Snap layouts', 'Window layouts when you hover the maximize button.', 'เค้าโครงหน้าต่างเมื่อชี้ปุ่มขยาย')
    'Start Menu' = @('Start menu replacements', 'Start menu ทางเลือก', 'Other Start menus, for example Open-Shell.', 'Start menu แบบอื่น เช่น Open-Shell')
    'Unlock Recent Items' = @('Recent items', 'ไฟล์ล่าสุด', 'Lists of recently opened files.', 'รายการไฟล์ที่เปิดล่าสุด')
    'Verbose Status Messages' = @('Detailed status messages', 'ข้อความสถานะแบบละเอียด', 'Shows what Windows does during start and shutdown.', 'แสดงว่า Windows ทำอะไรอยู่ตอนเปิดและปิดเครื่อง')
    'Visual Effects (Animations)' = @('Visual effects', 'เอฟเฟกต์ภาพ', 'Animations and shadows of Windows.', 'แอนิเมชันและเงาของ Windows')
    'Appearance' = @('Boot appearance', 'หน้าตาตอนบูต', 'Logo, spinner and boot menu style.', 'โลโก้ วงหมุน และเมนูตอนบูต')
    'Behavior' = @('Boot behavior', 'การทำงานตอนบูต', 'Advanced options, automatic repair and more.', 'ตัวเลือกขั้นสูง การซ่อมอัตโนมัติ และอื่น ๆ')
    'Boot Configuration' = @('Boot configuration', 'การตั้งค่าบูต', 'Shows the current boot settings.', 'แสดงค่าบูตปัจจุบัน')
    'Driver Configuration' = @('Driver tools', 'เครื่องมือไดรเวอร์', 'Advanced tools for interrupts and GPU affinity.', 'เครื่องมือขั้นสูงสำหรับ interrupt และ GPU affinity')
    'Microsoft Store' = @('Microsoft Store', 'Microsoft Store', 'Needed by the Xbox app and Game Pass.', 'แอป Xbox และ Game Pass ต้องใช้')
    'Process Explorer' = @('Process Explorer', 'Process Explorer', 'A more detailed Task Manager by Microsoft.', 'Task Manager แบบละเอียดของ Microsoft')
    'Bluetooth' = @('Bluetooth', 'บลูทูธ', 'Bluetooth services.', 'บริการบลูทูธ')
    'Lanman Workstation (SMB)' = @('Network drives (SMB)', 'ไดรฟ์เครือข่าย (SMB)', 'Needed for shared folders and network drives.', 'จำเป็นสำหรับโฟลเดอร์แชร์และไดรฟ์เครือข่าย')
    'Context Menu' = @('NVIDIA container menu', 'เมนู NVIDIA container', 'Desktop menu to start and stop the NVIDIA container.', 'เมนูเดสก์ท็อปสำหรับเปิดปิด NVIDIA container')
    'NVIDIA Display Container' = @('NVIDIA Display Container', 'NVIDIA Display Container', 'Needed by the NVIDIA Control Panel. Read first.', 'NVIDIA Control Panel ต้องใช้ อ่านก่อนปิด')
    'Network Discovery' = @('Network discovery', 'ค้นหาเครื่องในเครือข่าย', 'Find other PCs and devices on your network.', 'มองเห็นเครื่องและอุปกรณ์อื่นในเครือข่าย')
    'Printing' = @('Printing', 'การพิมพ์', 'Printer services.', 'บริการเครื่องพิมพ์')
    'Superfetch' = @('SysMain (Superfetch)', 'SysMain (Superfetch)', 'Preloads often used apps into RAM.', 'โหลดแอปที่ใช้บ่อยเข้า RAM ล่วงหน้า')
    'Static IP' = @('Static IP', 'IP แบบคงที่', 'Keeps the current IP address.', 'ล็อกเลข IP ปัจจุบันไว้')
    'Core Isolation (VBS)' = @('Core isolation (VBS)', 'Core isolation (VBS)', 'Some anti-cheats (Valorant, FACEIT) need it on.', 'anti-cheat บางตัว (Valorant, FACEIT) ต้องเปิดไว้')
    'Defender' = @('Microsoft Defender', 'Microsoft Defender', 'Antivirus. Some anti-cheats need it on.', 'แอนตี้ไวรัส anti-cheat บางตัวต้องเปิดไว้')
    'Hide App and Browser Control' = @('"App and browser control"', '"App and browser control"', 'Page in Windows Security.', 'หน้าใน Windows Security')
    'Security Health Tray' = @('Security tray icon', 'ไอคอน Security ที่ถาด', 'Windows Security icon next to the clock.', 'ไอคอน Windows Security ข้างนาฬิกา')
    'Mitigations' = @('Mitigations', 'Mitigations', 'CPU security mitigations. Keep the Windows defaults if you are unsure.', 'การป้องกันช่องโหว่ CPU ถ้าไม่แน่ใจให้ใช้ค่าของ Windows')
    'Fault Tolerant Heap' = @('Fault tolerant heap', 'Fault tolerant heap', 'Windows works around apps that crash often.', 'Windows แก้ทางให้แอปที่แครชบ่อย')
    'Network' = @('Reset network', 'รีเซ็ตเครือข่าย', 'Fixes internet problems.', 'แก้ปัญหาอินเทอร์เน็ต')
    'Safe Mode' = @('Safe Mode', 'Safe Mode', 'Restart in Safe Mode and back.', 'รีสตาร์ตเข้า Safe Mode และออก')
}
# Short button labels: the verb at the start of a file name, in English and Thai
$atlasVerbs = @{
    'Enable' = @('Enable', 'เปิด'); 'Disable' = @('Disable', 'ปิด'); 'Add' = @('Add', 'เพิ่ม'); 'Remove' = @('Remove', 'ลบ')
    'Show' = @('Show', 'แสดง'); 'Hide' = @('Hide', 'ซ่อน'); 'Install' = @('Install', 'ติดตั้ง'); 'Uninstall' = @('Uninstall', 'ถอนการติดตั้ง')
    'Allow' = @('Allow', 'อนุญาต'); 'Disallow' = @('Disallow', 'ไม่อนุญาต'); 'Restore' = @('Restore', 'คืนค่า'); 'Reset' = @('Reset', 'รีเซ็ต')
    'Set' = @('Set', 'ตั้งค่า'); 'Toggle' = @('Turn on or off', 'เปิดหรือปิด'); 'Unlock' = @('Unlock', 'ปลดล็อก'); 'Debloat' = @('Clean up', 'ลบรายการที่ไม่ใช้')
    'Old' = @('Old', 'แบบเก่า'); 'Modern' = @('Modern', 'แบบใหม่'); 'New' = @('New', 'แบบใหม่'); 'Minimal' = @('Minimal', 'น้อยที่สุด')
    'Default' = @('Windows default', 'ค่าของ Windows'); 'Legacy' = @('Legacy', 'แบบเก่า')
}

# "Disable Hibernation (default)" in the Hibernation row becomes "Disable": the verb alone, when the
# rest of the name only repeats the row name. Files directly in a category ($leaf empty) keep their name.
$atlasFiller = 'support', 'settings', 'service', 'services', 'context', 'menu', 'in', 'to', 'the', 'all', 'ls', 'windows'
function Get-AtlasLabel([IO.FileInfo]$file, [string]$leaf) {
    $name = $file.BaseName -replace '\s*\(default\)', '' -replace '\s+copy$', ''
    if (!$leaf -or $file.Extension -notin '.cmd', '.reg', '.ps1' -or $name -notmatch '^(\S+)\s+(.+)$' -or !$atlasVerbs.ContainsKey($Matches[1])) { return $name }
    $verb = $atlasVerbs[$Matches[1]][$(if ($lang -eq 'th') { 1 } else { 0 })]
    $rest = $Matches[2]
    $extra = if ($rest -match '(\([^)]*\))\s*$') { ' ' + $Matches[1] } else { '' }
    $leafWords = @(($leaf -replace '\([^)]*\)', '').ToLowerInvariant().Split(' ', [StringSplitOptions]::RemoveEmptyEntries))
    $left = @(($rest -replace '\([^)]*\)', '').ToLowerInvariant().Split(' ', [StringSplitOptions]::RemoveEmptyEntries) |
        Where-Object { $_ -notin $leafWords -and "${_}s" -notin $leafWords -and $_ -notin $atlasFiller })
    if ($left.Count -eq 0) { return "$verb$extra" }
    # Thai: translate the verb only for short names ("ปิด VBS"), longer ones stay as AtlasOS wrote them
    if ($lang -eq 'th' -and $rest.Split(' ').Count -le 2) { return "$verb $rest" }
    return $name
}

# A restore point before the first change, once per window (Windows allows one every 24 hours by default)
$script:restoreDone = $false
$restoreSetting = Get-RegValue $settingsKey 'RestorePoint'
$ui.RestoreToggle.IsChecked = ($restoreSetting -ne 0)
$ui.RestoreToggle.Add_Click({
    try {
        if (!(Test-Path $settingsKey)) { New-Item -Path $settingsKey -Force | Out-Null }
        Set-ItemProperty -Path $settingsKey -Name RestorePoint -Value $(if ($this.IsChecked) { 1 } else { 0 }) -Type DWord
    } catch { }
})
# System Protection: turn System Restore on for a drive, or open System Restore from there
$ui.RestoreOpen.Add_Click({ Start-Process SystemPropertiesProtection.exe })

function Invoke-AtlasItem([IO.FileInfo]$file) {
    $changes = $file.Extension.ToLowerInvariant() -in '.reg', '.cmd', '.ps1'
    if ($changes -and $ui.RestoreToggle.IsChecked -and !$script:restoreDone) {
        $script:restoreDone = $true
        Set-Status (T 'status.restoring') $true
        Start-Work {
            try {
                $before = @(Get-ComputerRestorePoint -ErrorAction Stop).Count
                Checkpoint-Computer -Description 'Akati OS Center' -RestorePointType MODIFY_SETTINGS -ErrorAction Stop -WarningAction SilentlyContinue
                if (@(Get-ComputerRestorePoint).Count -gt $before) { 'made' } else { 'recent' }
            } catch { 'off' }
        } @() {
            param($r, $f)
            $result = Get-LastOutput $r
            Set-Status (T "status.restore.$result")
            Invoke-AtlasFile $f
        } $file
        return
    }
    Invoke-AtlasFile $file
}

function Invoke-AtlasFile([IO.FileInfo]$file) {
    $name = $file.BaseName
    switch ($file.Extension.ToLowerInvariant()) {
        '.reg' {
            Start-Process reg.exe -ArgumentList "import `"$($file.FullName)`"" -WindowStyle Hidden -Wait
            Set-Status ((T 'status.applied') -f $name)
        }
        '.cmd' {
            # AtlasOS scripts explain what they change and wait for a key, so they get a visible window
            Start-Process cmd.exe -ArgumentList "/c `"`"$($file.FullName)`"`"" -WorkingDirectory $file.DirectoryName
            Set-Status ((T 'status.opened') -f $name)
        }
        '.ps1' {
            Start-Process powershell.exe -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$($file.FullName)`"" -WorkingDirectory $file.DirectoryName
            Set-Status ((T 'status.opened') -f $name)
        }
        default {
            Start-Process -FilePath $file.FullName
            Set-Status ((T 'status.opened') -f $name)
        }
    }
}

function New-AtlasButton([IO.FileInfo]$file, [string]$leaf) {
    $btn = New-Object System.Windows.Controls.Button
    $btn.Style = $window.FindResource('Secondary'); $btn.Margin = '0,6,8,0'
    $content = New-Object System.Windows.Controls.StackPanel
    $content.Orientation = 'Horizontal'
    if ($file.Extension -in '.url', '.lnk', '.exe') {
        $g = New-Text ([string][char]0xE8A7) 12; $g.Style = $window.FindResource('Glyph'); $g.FontSize = 12; $g.Margin = '0,0,8,0'
        [void]$content.Children.Add($g)
    }
    [void]$content.Children.Add((New-Text (Get-AtlasLabel $file $leaf) 13))
    if ($file.BaseName -match '\(default\)') {
        $badge = New-Object System.Windows.Controls.Border
        $badge.Style = $window.FindResource('Badge'); $badge.Margin = '8,0,0,0'
        $bt = New-Text (T 'system.default') 10 'SemiBold'; $bt.SetResourceReference([System.Windows.Controls.TextBlock]::ForegroundProperty, 'Accent2')
        $badge.Child = $bt
        [void]$content.Children.Add($badge)
    }
    $btn.Content = $content; $btn.ToolTip = $file.Name; $btn.Tag = $file
    $btn.Add_Click({ Invoke-AtlasItem $this.Tag })
    return $btn
}

$script:systemCards = New-Object System.Collections.ArrayList
function Add-SystemCard([string]$key, [System.IO.DirectoryInfo[]]$dirs, [string]$topPath) {
    $card = New-Object System.Windows.Controls.Border
    $card.Style = $window.FindResource('Card'); $card.Margin = '0,0,0,22'; $card.Padding = '0'
    $stack = New-Object System.Windows.Controls.StackPanel
    $head = New-Text (T "system.cat.$key")
    $head.Style = $window.FindResource('Section')
    $rows = New-Object System.Collections.ArrayList
    $li = if ($lang -eq 'th') { 1 } else { 0 }
    foreach ($d in $dirs) {
        $files = @(Get-ChildItem -LiteralPath $d.FullName -File -ErrorAction SilentlyContinue | Where-Object { $_.Extension -ne '.xml' } | Sort-Object Name)
        if ($files.Count -eq 0) { continue }
        $row = New-Object System.Windows.Controls.Border
        $row.Padding = '14,10'; $row.Background = [System.Windows.Media.Brushes]::Transparent
        $rowStack = New-Object System.Windows.Controls.StackPanel
        $info = $null; $desc = ''
        if ($d.FullName -eq $topPath) {
            $title = T 'system.links'
        } else {
            $info = $atlasInfo[$d.Name]
            $title = if ($info) { $info[$li] } else { $d.Name }
            if ($info) { $desc = $info[2 + $li] }
            $parent = $d.Parent.FullName
            if ($parent -ne $topPath) {
                $pInfo = $atlasInfo[$d.Parent.Name]
                $pTitle = if ($pInfo) { $pInfo[$li] } else { $d.Parent.Name }
                $title = $pTitle + ' › ' + $title
            }
        }
        $label = New-Text $title 14 'SemiBold'
        [void]$rowStack.Children.Add($label)
        if ($desc) {
            $dt = New-Text $desc 12; $dt.Foreground = $window.FindResource('MutedBrush'); $dt.Margin = '0,2,0,0'
            [void]$rowStack.Children.Add($dt)
        }
        $wrap = New-Object System.Windows.Controls.WrapPanel
        $leaf = if ($d.FullName -eq $topPath) { '' } else { $d.Name }
        foreach ($f in $files) { [void]$wrap.Children.Add((New-AtlasButton $f $leaf)) }
        [void]$rowStack.Children.Add($wrap)
        $row.Child = $rowStack
        # Search in both languages and in the original AtlasOS names
        $words = @($key, (T "system.cat.$key"), $d.Name, $title, $desc) + @($files | ForEach-Object { $_.BaseName })
        if ($info) { $words += $info }
        $row.Tag = ($words -join ' ').ToLowerInvariant()
        [void]$stack.Children.Add($row)
        [void]$rows.Add($row)
    }
    if ($rows.Count -eq 0) { return }
    $card.Child = $stack
    Update-Separators $stack
    [void]$ui.SystemList.Children.Add($head)
    [void]$ui.SystemList.Children.Add($card)
    [void]$script:systemCards.Add(@{ Card = $card; Head = $head; Rows = $rows; Stack = $stack })
}

function Show-SystemList {
    $ui.SystemList.Children.Clear()
    $script:systemCards.Clear()
    if (!(Test-Path -LiteralPath $desktop)) { return }
    foreach ($top in Get-ChildItem -LiteralPath $desktop -Directory | Sort-Object Name) {
        $key = $top.Name -replace '^\d+\.\s*', ''
        $dirs = @($top) + @(Get-ChildItem -LiteralPath $top.FullName -Directory -Recurse | Sort-Object FullName)
        Add-SystemCard $key $dirs $top.FullName
    }
    # Files directly in the folder: links
    Add-SystemCard 'AkatiOS' @(Get-Item -LiteralPath $desktop) (Get-Item -LiteralPath $desktop).FullName
    Update-SystemFilter
}

function Update-SystemFilter {
    $q = $ui.SystemSearch.Text.Trim().ToLowerInvariant()
    $ui.SystemSearchHint.Visibility = if ($q) { 'Collapsed' } else { 'Visible' }
    foreach ($c in $script:systemCards) {
        $shown = 0
        foreach ($r in $c.Rows) {
            $match = !$q -or $r.Tag.Contains($q)
            $r.Visibility = if ($match) { 'Visible' } else { 'Collapsed' }
            if ($match) { $shown++ }
        }
        $c.Card.Visibility = if ($shown) { 'Visible' } else { 'Collapsed' }
        $c.Head.Visibility = $c.Card.Visibility
        Update-Separators $c.Stack
    }
}
$ui.SystemSearch.Add_TextChanged({ Update-SystemFilter })
# Hundreds of AtlasOS scripts: the list is built once the window is shown and idle, not before it opens
if ($Screenshot) { Show-SystemList }
else { $window.Add_ContentRendered({ [void]$window.Dispatcher.BeginInvoke([Action]{ if (!$ui.SystemList.Children.Count) { Show-SystemList } }, [System.Windows.Threading.DispatcherPriority]::ApplicationIdle) }) }

# ---------------------------------------------------------------------------------------------
# Problem report: one zip on the desktop with the Akati OS logs and PC details
# ---------------------------------------------------------------------------------------------
Add-Mark 'Problem report'
$ui.IssuesButton.Add_Click({ Start-Process "https://github.com/$repo/issues/new/choose" })
$ui.ReportButton.Add_Click({
    $this.IsEnabled = $false
    Set-Status (T 'status.report') $true
    $appState = ($apps | ForEach-Object { '{0}: {1}' -f $_.Name, $(if (Test-App $_) { 'installed' } else { 'not installed' }) }) -join "`r`n"
    Start-Work {
        param($version, $edition, $appState, $logs, $desktopDir)
        $stamp = Get-Date -Format 'yyyyMMdd-HHmm'
        $work = Join-Path $env:TEMP "AkatiOS-report-$stamp"
        New-Item -ItemType Directory -Path $work -Force | Out-Null
        $lines = @("Akati OS problem report, $(Get-Date -Format 'yyyy-MM-dd HH:mm')", '')
        $lines += "Akati OS: $version ($edition)"
        try {
            $os = Get-CimInstance Win32_OperatingSystem
            $cv = Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion'
            $lines += "Windows: $($os.Caption) $($cv.DisplayVersion) build $($cv.CurrentBuild).$($cv.UBR), $($os.OSArchitecture)"
            $lines += "Language: $((Get-Culture).Name), UI $((Get-UICulture).Name)"
            $lines += "CPU: $((Get-CimInstance Win32_Processor | Select-Object -First 1).Name)"
            $lines += 'GPU: ' + ((Get-CimInstance Win32_VideoController | ForEach-Object { "$($_.Name) (driver $($_.DriverVersion))" }) -join '; ')
            $lines += 'RAM: {0:N1} GB' -f ($os.TotalVisibleMemorySize / 1MB)
            $disk = [IO.DriveInfo]::new('C')
            $lines += 'C: {0:N1} GB free of {1:N1} GB' -f ($disk.TotalFreeSpace / 1GB), ($disk.TotalSize / 1GB)
            $lines += "Power plan: $([string](powercfg /getactivescheme))"
        } catch { $lines += "System info error: $($_.Exception.Message)" }
        $lines += "WinGet: $(try { (& winget --version) 2>$null } catch { 'not found' })"
        $lines += '', 'Gaming apps:', $appState
        $lines | Set-Content -Path (Join-Path $work 'system.txt') -Encoding UTF8
        if (Test-Path $logs) { Copy-Item -Path (Join-Path $logs '*.log') -Destination $work -ErrorAction SilentlyContinue }
        # Logs of Akati OS Center, the icon next to the clock and the automatic clean
        Copy-Item -Path (Join-Path $env:ProgramData 'AkatiOS\*.log') -Destination $work -ErrorAction SilentlyContinue
        # No personal data: remove the user name and the PC name from every file
        foreach ($f in Get-ChildItem -LiteralPath $work -File) {
            $text = [IO.File]::ReadAllText($f.FullName)
            $text = $text -replace [regex]::Escape($env:USERNAME), '<user>' -replace [regex]::Escape($env:COMPUTERNAME), '<pc>'
            [IO.File]::WriteAllText($f.FullName, $text)
        }
        $zip = Join-Path $desktopDir "AkatiOS-report-$stamp.zip"
        Compress-Archive -Path (Join-Path $work '*') -DestinationPath $zip -Force
        Remove-Item -LiteralPath $work -Recurse -Force -ErrorAction SilentlyContinue
        $zip
    } @($version, $edition, $appState, $progressDir, [Environment]::GetFolderPath('Desktop')) {
        param($r, $ctx)
        $ui.ReportButton.IsEnabled = $true
        $zip = Get-LastOutput $r
        if ($zip -and (Test-Path -LiteralPath $zip)) {
            Set-Status ((T 'status.reportdone') -f (Split-Path $zip -Leaf))
            Start-Process explorer.exe -ArgumentList "/select,`"$zip`""
        } else { Set-Status (T 'status.reportfailed') }
    }
})

