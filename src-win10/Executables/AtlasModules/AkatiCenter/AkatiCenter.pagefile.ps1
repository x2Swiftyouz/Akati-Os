<#
.SYNOPSIS
    Akati OS Center: Tweaks > Page file: how Windows uses a drive as extra memory, with three choices: Let Windows
    manage (recommended), a custom size for the RAM of this PC, or another fixed drive. Never "no page file".
    Dot-sourced by AkatiCenter.ps1 (runs in its scope: $ui, $window, T and the other parts).
#>
# The setup is the PagingFiles value (ConvertFrom-PagingFiles, AkatiCenter.logic.ps1); Windows reads it at start, so every
# change needs a restart. Each change goes to the change history ("pagefile", "<new>,<before>", lines joined with ;) with Undo.
Add-Mark 'Page file'
$pagingKey = 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management'
# What Windows reports now (Win32_ComputerSystem, Win32_PageFileSetting, Win32_PageFileUsage), the RAM and the fixed drives
$pfWork = {
    $r = @{ Ram = 0; Auto = $false; Settings = @(); Usage = @(); Drives = @(); Lines = @(); System = [string]$env:SystemDrive }
    try { $cs = Get-CimInstance Win32_ComputerSystem -ErrorAction Stop; $r.Ram = [double]$cs.TotalPhysicalMemory; $r.Auto = [bool]$cs.AutomaticManagedPagefile } catch { }
    try { $r.Settings = @(Get-CimInstance Win32_PageFileSetting -ErrorAction Stop | ForEach-Object { @{ Name = [string]$_.Name; Min = [int]$_.InitialSize; Max = [int]$_.MaximumSize } }) } catch { }
    try { $r.Usage = @(Get-CimInstance Win32_PageFileUsage -ErrorAction Stop | ForEach-Object { @{ Name = [string]$_.Name; Size = [int]$_.AllocatedBaseSize } }) } catch { }
    $r.Lines = [string[]]@((Get-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management' -Name PagingFiles -ErrorAction SilentlyContinue).PagingFiles)
    # SSD or hard disk for each drive letter
    $kinds = @{}
    try {
        $disks = @(Get-PhysicalDisk -ErrorAction Stop)
        foreach ($p in @(Get-Partition -ErrorAction Stop | Where-Object { $_.DriveLetter })) {
            $d = @($disks | Where-Object { [string]$_.DeviceId -eq [string]$p.DiskNumber })[0]
            if ($d) { $kinds["$($p.DriveLetter):".ToUpperInvariant()] = @{ Bus = [string]$d.BusType; Media = [string]$d.MediaType } }
        }
    } catch { }
    $r.Drives = @(Get-CimInstance Win32_LogicalDisk -Filter 'DriveType=3' -ErrorAction SilentlyContinue | ForEach-Object {
        $k = $kinds[([string]$_.DeviceID).ToUpperInvariant()]
        @{ Id = ([string]$_.DeviceID).ToUpperInvariant(); Size = [double]$_.Size; Free = [double]$_.FreeSpace; Bus = $(if ($k) { $k.Bus } else { '' }); Media = $(if ($k) { $k.Media } else { '' }) }
    })
    $r
}
# Screenshot mode: a sample PC (16 GB, a custom size on C:, an NVMe and a hard disk)
$pfSample = @{ Ram = 16GB; Auto = $false; System = 'C:'; Lines = @('C:\pagefile.sys 4096 8192')
    Settings = @(@{ Name = 'C:\pagefile.sys'; Min = 4096; Max = 8192 }); Usage = @(@{ Name = 'C:\pagefile.sys'; Size = 4096 })
    Drives = @(@{ Id = 'C:'; Size = 1TB; Free = 412GB; Bus = 'NVMe'; Media = 'SSD' }, @{ Id = 'D:'; Size = 2TB; Free = 1.3TB; Bus = 'SATA'; Media = 'HDD' }) }
$script:pfResult = $null
$script:pfDrive = $null

# The setup as text: "Windows manages it", "C: 4096 to 8192 MB", "D: size picked by Windows"
function Format-PageFileSetup($setup) {
    if ($setup.Auto) { return T 'pf.state.auto' }
    $files = @($setup.Files)
    if (!$files.Count) { return T 'pf.state.none' }
    (@(foreach ($f in $files) { if ($f.Max -gt 0) { (T 'pf.state.custom') -f $f.Drive, $f.Min, $f.Max } else { (T 'pf.state.system') -f $f.Drive } }) -join ', ')
}
function Get-PfDriveKind($d) { Get-DiskKind $d.Bus $d.Media }
function Show-PageFile {
    $r = $script:pfResult
    if ($r -isnot [hashtable]) { $ui.PfState.Text = T 'pf.loading'; $ui.PfSize.Text = ''; return }
    # Windows: automatic, or the settings (none: no page file)
    $setup = @{ Auto = $r.Auto; Files = @(foreach ($s in @($r.Settings)) { if ($s.Name -match '^([A-Za-z]:)') { @{ Drive = $Matches[1].ToUpperInvariant(); Min = $s.Min; Max = $s.Max } } }) }
    $script:pfSetup = $setup
    $ui.PfState.Text = Format-PageFileSetup $setup
    $sizes = @($r.Usage | Where-Object { $_.Size -gt 0 } | ForEach-Object { '{0} {1:N0} MB' -f (($_.Name -split '\\')[0]).ToUpperInvariant(), $_.Size })
    $ui.PfSize.Text = if ($sizes.Count) { (T 'pf.state.size') -f ($sizes -join ', ') } else { '' }
    $ui.PfSize.Visibility = if ($sizes.Count) { 'Visible' } else { 'Collapsed' }
    $ui.PfWarn.Visibility = if (!$setup.Auto -and !@($setup.Files).Count) { 'Visible' } else { 'Collapsed' }
    $ui.PfRam.Text = if ($r.Ram -gt 0) { '{0} GB' -f [Math]::Round($r.Ram / 1GB) } else { '-' }
    $sug = Get-PageFileSuggestion $r.Ram
    $ui.PfSuggest.Text = (T 'pf.custom.d') -f $ui.PfRam.Text, $sug.Min, $sug.Max
    # The boxes: the custom size now, or the suggestion
    $custom = @($setup.Files | Where-Object { $_.Max -gt 0 })[0]
    if (!$ui.PfMin.IsKeyboardFocusWithin -and !$ui.PfMax.IsKeyboardFocusWithin) {
        $ui.PfMin.Text = [string]$(if ($custom) { $custom.Min } else { $sug.Min })
        $ui.PfMax.Text = [string]$(if ($custom) { $custom.Max } else { $sug.Max })
    }
    # Fixed drives, SSDs first, then by letter. The drives the page file is on now are left out.
    $now = @($setup.Files | ForEach-Object { $_.Drive })
    $ui.PfDrives.Children.Clear()
    $drives = @($r.Drives | Where-Object { $_.Id -and ($setup.Auto -or $_.Id -notin $now -or $now.Count -gt 1) } |
        Sort-Object { if ((Get-PfDriveKind $_) -in 'NVMe', 'SSD') { 0 } else { 1 } }, { $_.Id })
    foreach ($d in $drives) {
        $kind = Get-PfDriveKind $d
        $rb = New-Object System.Windows.Controls.RadioButton
        $rb.Style = $window.FindResource('Segment'); $rb.GroupName = 'PfDrive'; $rb.Tag = $d; $rb.Margin = '0,0,6,6'
        $rb.Content = (@($d.Id, $kind, ((T 'pf.drive.free') -f (Format-Size $d.Free))) | Where-Object { $_ }) -join '  '
        $rb.IsChecked = $script:pfDrive -eq $d.Id
        $rb.Add_Checked({ $script:pfDrive = $this.Tag.Id })
        $b = New-Object System.Windows.Controls.Border
        $b.SetResourceReference([System.Windows.Controls.Border]::BackgroundProperty, 'Field')
        $b.SetResourceReference([System.Windows.Controls.Border]::BorderBrushProperty, 'Line')
        $b.BorderThickness = '1'; $b.CornerRadius = 7; $b.Padding = '2'; $b.Margin = '0,0,8,6'; $b.Child = $rb; $rb.Margin = '0'
        [void]$ui.PfDrives.Children.Add($b)
    }
    if (!$drives.Count) { $t = New-Text (T 'pf.move.none') 12; $t.SetResourceReference([System.Windows.Controls.TextBlock]::ForegroundProperty, 'MutedBrush'); [void]$ui.PfDrives.Children.Add($t) }
    $ui.PfMove.IsEnabled = $drives.Count -gt 0
}
# Read in the background, once when the Tweaks page opens and after each change
function Start-PageFileLoad {
    if ($Screenshot) { $script:pfResult = $pfSample; Show-PageFile; return }
    if ($script:pfLoading) { return }
    $script:pfLoading = $true
    Start-Work $pfWork @() { param($r) $script:pfLoading = $false; $script:pfResult = Get-LastOutput $r; Show-PageFile } $null
}

# Writes a new setup (lines of PagingFiles) after the question; a restore point first when that is on in System
function Request-PageFile([string[]]$lines, [string]$question, [string[]]$bullets) {
    $before = [string[]]@(Get-RegValue $pagingKey 'PagingFiles' | Where-Object { $_ })
    if (($before -join ';') -eq ($lines -join ';')) { Set-Status (T 'pf.same'); return }
    if ((Show-Ask $question 'YesNo' 'Question' (@($bullets) + @(T 'pf.b.restart')) (T 'pf.ask.note')) -ne 'Yes') { return }
    if ($ui.RestoreToggle.IsChecked -and !$script:restoreDone) {
        $script:restoreDone = $true
        New-RestorePoint 'pagefile' { param($result, $l) Set-PageFile $l } $lines
        return
    }
    Set-PageFile $lines
}
function Set-PageFile([string[]]$lines, [switch]$Quiet) {
    $before = [string[]]@(Get-RegValue $pagingKey 'PagingFiles' | Where-Object { $_ })
    # Never no page file
    if (!@($lines | Where-Object { $_ }).Count) { return }
    try { Set-ItemProperty -Path $pagingKey -Name PagingFiles -Value ([string[]]$lines) -Type MultiString -Force -ErrorAction Stop }
    catch { Set-Status $_.Exception.Message; return }
    Add-ChangeHistory 'pagefile' ('{0},{1}' -f ($lines -join ';'), ($before -join ';'))
    $msg = (T 'pf.done') -f (Format-PageFileSetup (ConvertFrom-PagingFiles $lines))
    Add-Log 'TweakLog' $msg; Set-Status $msg
    Set-RestartNeeded
    if (!$Quiet -and @($before).Count) { Show-Toast $msg @{ Action = { param($u) Set-PageFile $u.Before -Quiet }; Before = $before } }
    Start-PageFileLoad
}
$ui.PfAuto.Add_Click({ Request-PageFile @('?:\pagefile.sys') (T 'pf.ask.auto') @() })
$ui.PfCustom.Add_Click({
    $min = 0; $max = 0
    if (![int]::TryParse($ui.PfMin.Text.Trim(), [ref]$min) -or ![int]::TryParse($ui.PfMax.Text.Trim(), [ref]$max)) { Show-Message (T 'pf.err.number') 'Warning'; return }
    # On the drive the page file is on now (the Windows drive when Windows manages it)
    $r = $script:pfResult
    $drive = @($script:pfSetup.Files | ForEach-Object { $_.Drive })[0]
    if (!$drive) { $drive = if ($r -and $r.System) { ([string]$r.System).ToUpperInvariant() } else { 'C:' } }
    $free = @($r.Drives | Where-Object { $_.Id -eq $drive } | ForEach-Object { $_.Free / 1MB })[0]
    # The space the page file uses now counts as free
    $used = @($r.Usage | Where-Object { $_.Name -like "$drive*" } | ForEach-Object { $_.Size })[0]
    $err = Test-PageFileSize $min $max $(if ($null -ne $free) { $free + [double]$used } else { -1 })
    if ($err) { Show-Message (T $err) 'Warning'; return }
    $bullets = @(); if ($min -lt 4096) { $bullets += T 'pf.b.small' }
    Request-PageFile (ConvertTo-PagingFiles @{ Auto = $false; Files = @(@{ Drive = $drive; Min = $min; Max = $max }) }) ((T 'pf.ask.custom') -f $drive, $min, $max) $bullets
})
$ui.PfMove.Add_Click({
    $r = $script:pfResult
    $d = @($r.Drives | Where-Object { $_.Id -eq $script:pfDrive })[0]
    if (!$d) { Show-Message (T 'pf.move.pick') 'Information'; return }
    # A custom size stays (if the drive has room); otherwise Windows picks the size there
    $custom = @($script:pfSetup.Files | Where-Object { $_.Max -gt 0 })[0]
    $min = 0; $max = 0
    if ($custom -and !(Test-PageFileSize $custom.Min $custom.Max ($d.Free / 1MB))) { $min = $custom.Min; $max = $custom.Max }
    $bullets = @()
    if ($d.Id -ne ([string]$r.System).ToUpperInvariant()) { $bullets += (T 'pf.b.dump') -f $r.System }
    if ((Get-PfDriveKind $d) -eq 'HDD') { $bullets += T 'pf.b.hdd' }
    Request-PageFile (ConvertTo-PagingFiles @{ Auto = $false; Files = @(@{ Drive = $d.Id; Min = $min; Max = $max }) }) ((T 'pf.ask.move') -f $d.Id) $bullets
})
# Undo from Health > Change history: back to the setup before (not when that was no page file)
function Undo-PageFile([string]$from) {
    $lines = [string[]]@($from -split ';' | Where-Object { $_ })
    if (!$lines.Count) { return }
    $text = Format-PageFileSetup (ConvertFrom-PagingFiles $lines)
    if ((Show-Ask ((T 'history.pf') -f $text) 'YesNo' 'Question' @(T 'pf.b.restart')) -ne 'Yes') { return }
    Set-PageFile $lines -Quiet
}
