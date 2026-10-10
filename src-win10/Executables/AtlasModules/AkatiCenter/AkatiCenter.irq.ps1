<#
.SYNOPSIS
    Akati OS Center: Tweaks > Interrupts: MSI mode, MSI limit, interrupt priority and CPU affinity of each PCI device,
    with a core benchmark, a backup of each device before its first change, and Undo.
    Dot-sourced by AkatiCenter.ps1 (runs in its scope: $ui, $window, T and the other parts).
#>
# ---------------------------------------------------------------------------------------------
# Windows keeps these per device under Enum\<device>\Device Parameters\Interrupt Management:
#   MessageSignaledInterruptProperties: MSISupported (1 on, 0 off), MessageNumberLimit (how many messages)
#   Affinity Policy: DevicePolicy (0 Windows decides, 4 the processors in AssignmentSetOverride, 5 spread over all),
#                    DevicePriority (0 undefined, 1 low, 2 normal, 3 high), AssignmentSetOverride (bit n = CPU n)
# Only what the user changed is written. The values of a device are saved in HKLM\SOFTWARE\AkatiOS\Interrupts
# before its first change, and Undo puts them back exactly (also in Safe Mode).
# ---------------------------------------------------------------------------------------------
Add-Mark 'Interrupts'
$irqBackupKey = 'HKLM:\SOFTWARE\AkatiOS\Interrupts'
$irqValues = @(@('MessageSignaledInterruptProperties', 'MSISupported'), @('MessageSignaledInterruptProperties', 'MessageNumberLimit'),
               @('Affinity Policy', 'DevicePolicy'), @('Affinity Policy', 'DevicePriority'), @('Affinity Policy', 'AssignmentSetOverride'))
function Get-IrqKey([string]$id) { "HKLM:\SYSTEM\CurrentControlSet\Enum\$id\Device Parameters\Interrupt Management" }
function Get-IrqBackupName([string]$id) { $id -replace '\\', '#' }

# The PCI devices and what Windows knows about their interrupts, read in the background
$irqWork = {
    $out = @{ Devices = @(); Cores = 0; Logical = 0 }
    try {
        $cpu = @(Get-CimInstance Win32_Processor -ErrorAction Stop)
        $out.Cores = [int]($cpu | Measure-Object NumberOfCores -Sum).Sum
        $out.Logical = [int]($cpu | Measure-Object NumberOfLogicalProcessors -Sum).Sum
    } catch { }
    $devices = @(Get-CimInstance Win32_PnPEntity -ErrorAction SilentlyContinue | Where-Object { $_.PNPDeviceID -like 'PCI\*' -and $_.PNPClass -and $_.PNPClass -notin 'SoftwareDevice', 'Processor' })
    $ids = [string[]]@($devices | ForEach-Object { $_.PNPDeviceID })
    $props = @{}
    if ($ids.Count) {
        foreach ($p in @(Get-PnpDeviceProperty -InstanceId $ids -KeyName 'DEVPKEY_PciDevice_InterruptSupport', 'DEVPKEY_PciDevice_InterruptMessageMaximum' -ErrorAction SilentlyContinue)) {
            $props["$($p.InstanceId)|$($p.KeyName)"] = $p.Data
        }
    }
    $out.Devices = @(foreach ($d in $devices) {
        $id = $d.PNPDeviceID
        $base = "HKLM:\SYSTEM\CurrentControlSet\Enum\$id\Device Parameters\Interrupt Management"
        $msi = Get-ItemProperty -LiteralPath "$base\MessageSignaledInterruptProperties" -ErrorAction SilentlyContinue
        $aff = Get-ItemProperty -LiteralPath "$base\Affinity Policy" -ErrorAction SilentlyContinue
        $mask = [uint64]0
        if ($aff.AssignmentSetOverride -is [byte[]]) {
            $buf = New-Object byte[] 8; $b = [byte[]]$aff.AssignmentSetOverride
            [Array]::Copy($b, $buf, [Math]::Min(8, $b.Length)); $mask = [BitConverter]::ToUInt64($buf, 0)
        }
        # Bridges, chipset and management parts (class System) go to "Other PCI devices"
        @{ Id = $id; Name = [string]$d.Name; Class = [string]$d.PNPClass; Other = $d.PNPClass -eq 'System'
           Support = [int]$props["$id|DEVPKEY_PciDevice_InterruptSupport"]; Max = [int]$props["$id|DEVPKEY_PciDevice_InterruptMessageMaximum"]
           Msi = $(if ($null -ne $msi.MSISupported) { [int]$msi.MSISupported } else { -1 })
           Limit = [int]$msi.MessageNumberLimit; Policy = [int]$aff.DevicePolicy; Priority = [int]$aff.DevicePriority; Mask = $mask }
    })
    $out
}

# Core benchmark (C#): the same small piece of work on one logical processor at a time
Import-Code 'Cores' @'
using System;
using System.Diagnostics;
using System.Runtime.InteropServices;
using System.Threading;
namespace AkatiOS {
    public static class Cores {
        [DllImport("kernel32.dll")] static extern IntPtr GetCurrentThread();
        [DllImport("kernel32.dll")] static extern UIntPtr SetThreadAffinityMask(IntPtr thread, UIntPtr mask);
        [DllImport("kernel32.dll")] static extern int GetThreadPriority(IntPtr thread);
        [DllImport("kernel32.dll")] static extern bool SetThreadPriority(IntPtr thread, int priority);
        // The thread runs at time critical priority, so only interrupts, deferred calls (DPCs) and real time threads can
        // take the processor away. Result, three parts of cpus values: work units per second, the longest pause in
        // microseconds, and the share of the time taken away (interrupt load, %), averaged over the rounds.
        // Each round visits every processor in a new random order, for ms milliseconds each.
        public static double[] Run(int cpus, int rounds, int ms) {
            double[] result = new double[cpus * 3];
            Random random = new Random();
            IntPtr thread = GetCurrentThread();
            UIntPtr first = UIntPtr.Zero;
            int oldPriority = GetThreadPriority(thread);
            Thread.BeginThreadAffinity();
            SetThreadPriority(thread, 15);
            try {
                for (int r = 0; r < rounds; r++) {
                    int[] order = new int[cpus];
                    for (int i = 0; i < cpus; i++) order[i] = i;
                    for (int i = cpus - 1; i > 0; i--) { int j = random.Next(i + 1); int t = order[i]; order[i] = order[j]; order[j] = t; }
                    foreach (int cpu in order) {
                        UIntPtr previous = SetThreadAffinityMask(thread, new UIntPtr(1UL << cpu));
                        if (first == UIntPtr.Zero) first = previous;
                        Thread.Sleep(1);
                        Stopwatch watch = Stopwatch.StartNew();
                        long end = Stopwatch.Frequency * ms / 1000, units = 0, worst = 0, last = 0, shortest = long.MaxValue;
                        long[] gaps = new long[200000]; int count = 0;
                        double x = 1.0001;
                        while (true) {
                            for (int k = 0; k < 200; k++) { x = x * 1.0000001 + 0.0000001; }
                            units++;
                            long now = watch.ElapsedTicks;
                            long gap = now - last;
                            if (gap > worst) worst = gap;
                            if (gap > 0 && gap < shortest) shortest = gap;
                            if (count < gaps.Length) gaps[count++] = gap;
                            last = now;
                            if (now >= end) break;
                        }
                        if (x < 0) units++;
                        // Time taken away: every step that took much longer than the shortest one
                        long stolen = 0;
                        for (int i = 1; i < count; i++) { if (gaps[i] > shortest * 4) stolen += gaps[i] - shortest; }
                        result[cpu] += units * 1000.0 / ms / rounds / 10;
                        result[cpus + cpu] += worst * 1000000.0 / Stopwatch.Frequency / rounds;
                        result[2 * cpus + cpu] += 100.0 * stolen / Math.Max(1, last) / rounds;
                    }
                }
            } finally {
                SetThreadPriority(thread, oldPriority);
                if (first != UIntPtr.Zero) SetThreadAffinityMask(thread, first);
                Thread.EndThreadAffinity();
            }
            return result;
        }
    }
}
'@

# Backup and Undo
function Save-IrqBackup($d) {
    $name = Get-IrqBackupName $d.Id
    if (!(Test-Path $irqBackupKey)) { New-Item -Path $irqBackupKey -Force | Out-Null }
    if ($null -ne (Get-RegValue $irqBackupKey $name)) { return }
    $base = Get-IrqKey $d.Id
    $values = @{}
    foreach ($v in $irqValues) {
        $value = (Get-ItemProperty -LiteralPath "$base\$($v[0])" -Name $v[1] -ErrorAction SilentlyContinue).($v[1])
        if ($null -ne $value) { $values["$($v[0])|$($v[1])"] = if ($value -is [byte[]]) { 'hex:' + [BitConverter]::ToString($value) } else { [string]$value } }
    }
    Set-ItemProperty -Path $irqBackupKey -Name $name -Value ($values | ConvertTo-Json -Compress) -Type String
}
function Restore-Irq([string]$id) {
    $name = Get-IrqBackupName $id
    $json = Get-RegValue $irqBackupKey $name
    if ($null -eq $json) { return }
    $saved = $json | ConvertFrom-Json
    $base = Get-IrqKey $id
    foreach ($v in $irqValues) {
        $key = "$base\$($v[0])"
        $value = $saved.("$($v[0])|$($v[1])")
        if ($null -eq $value) { Remove-ItemProperty -LiteralPath $key -Name $v[1] -ErrorAction SilentlyContinue; continue }
        if (!(Test-Path -LiteralPath $key)) { New-Item -Path $key -Force | Out-Null }
        if ($value -like 'hex:*') {
            $bytes = [byte[]]@($value.Substring(4).Split('-') | Where-Object { $_ } | ForEach-Object { [Convert]::ToByte($_, 16) })
            Set-ItemProperty -LiteralPath $key -Name $v[1] -Value $bytes -Type Binary
        } else { Set-ItemProperty -LiteralPath $key -Name $v[1] -Value ([int]$value) -Type DWord }
    }
    Remove-ItemProperty -Path $irqBackupKey -Name $name -ErrorAction SilentlyContinue
}
function Test-IrqBackup([string]$id) { $null -ne (Get-RegValue $irqBackupKey (Get-IrqBackupName $id)) }

# Writes only what differs from the device now
function Write-Irq($d, $w) {
    $base = Get-IrqKey $d.Id
    $msiKey = "$base\MessageSignaledInterruptProperties"; $affKey = "$base\Affinity Policy"
    $msiNow = $d.Msi -eq 1
    $msiChange = ($d.Support -band 6) -and ($w.Msi -ne $msiNow -or $w.Limit -ne $d.Limit)
    $affChange = $w.Policy -ne $d.Policy -or ($w.Policy -eq 4 -and $w.Mask -ne $d.Mask) -or $w.Priority -ne $d.Priority
    if (!$msiChange -and !$affChange) { return $false }
    Save-IrqBackup $d
    if ($msiChange) {
        if (!(Test-Path -LiteralPath $msiKey)) { New-Item -Path $msiKey -Force | Out-Null }
        if ($w.Msi -ne $msiNow) { Set-ItemProperty -LiteralPath $msiKey -Name MSISupported -Value ([int]$w.Msi) -Type DWord }
        if ($w.Msi -and $w.Limit -gt 0) { Set-ItemProperty -LiteralPath $msiKey -Name MessageNumberLimit -Value ([int]$w.Limit) -Type DWord }
        else { Remove-ItemProperty -LiteralPath $msiKey -Name MessageNumberLimit -ErrorAction SilentlyContinue }
    }
    if ($affChange) {
        if (!(Test-Path -LiteralPath $affKey)) { New-Item -Path $affKey -Force | Out-Null }
        Set-ItemProperty -LiteralPath $affKey -Name DevicePolicy -Value ([int]$w.Policy) -Type DWord
        if ($w.Policy -eq 4) { Set-ItemProperty -LiteralPath $affKey -Name AssignmentSetOverride -Value ([BitConverter]::GetBytes([uint64]$w.Mask)) -Type Binary }
        else { Remove-ItemProperty -LiteralPath $affKey -Name AssignmentSetOverride -ErrorAction SilentlyContinue }
        if ($w.Priority -gt 0) { Set-ItemProperty -LiteralPath $affKey -Name DevicePriority -Value ([int]$w.Priority) -Type DWord }
        else { Remove-ItemProperty -LiteralPath $affKey -Name DevicePriority -ErrorAction SilentlyContinue }
    }
    $true
}

# ---------------------------------------------------------------------------------------------
# The list
# ---------------------------------------------------------------------------------------------
$irqGlyphs = @{ Display = 0xE7F4; Net = 0xE968; USB = 0xE88E; SCSIAdapter = 0xEDA2; HDC = 0xEDA2; MEDIA = 0xE767; Bluetooth = 0xE702 }
$irqOrder = @{ Display = 0; Net = 1; USB = 2; MEDIA = 3; SCSIAdapter = 4; HDC = 5 }
function Get-IrqAffText($w) {
    switch ($w.Policy) {
        0 { T 'irq.aff.default' }
        5 { T 'irq.aff.spread' }
        4 { 'CPU ' + ((ConvertFrom-CpuMask $w.Mask) -join ', ') }
        default { (T 'irq.aff.other') -f $w.Policy }
    }
}
function Get-IrqSub($d) {
    $msi = switch ($d.Msi) { 1 { T 'irq.msi.on' } 0 { T 'irq.msi.off' } default { T 'irq.msi.default' } }
    # Friendly names for the common device classes; others as Windows names them
    $class = switch ($d.Class) { 'Display' { T 'irq.class.display' } 'Net' { T 'irq.class.net' } 'USB' { 'USB' } 'MEDIA' { T 'irq.class.audio' }
                                 { $_ -in 'SCSIAdapter', 'HDC' } { T 'irq.class.storage' } default { $d.Class } }
    $parts = @($class, $msi)
    $modes = Get-IrqModes $d.Support
    if ($modes) { $parts += $modes }
    $parts += Get-IrqAffText @{ Policy = $d.Policy; Mask = $d.Mask }
    $parts -join '  ·  '
}
function Update-IrqControls($d) {
    $c = $d.Ctl
    $c.Msi.IsChecked = $d.Want.Msi
    $c.Limit.Text = if ($d.Want.Limit -gt 0) { [string]$d.Want.Limit } else { '' }
    $c.Limit.IsEnabled = $d.Want.Msi -and ($d.Support -band 6)
    $c.Prio.Content = T "irq.prio.$($d.Want.Priority)"
    $c.Aff.Content = Get-IrqAffText $d.Want
    $c.Suggest.Visibility = if ($script:irqBest -and $d.Class -in 'Display', 'Net', 'USB') { 'Visible' } else { 'Collapsed' }
    $c.Undo.Visibility = if (Test-IrqBackup $d.Id) { 'Visible' } else { 'Collapsed' }
    $c.Row.Sub.Text = Get-IrqSub $d
}
function New-IrqWant($d) { @{ Msi = $d.Msi -eq 1; Limit = $d.Limit; Policy = $d.Policy; Mask = $d.Mask; Priority = $d.Priority } }
# Affinity menu: Windows decides, spread over all, or the ticked processors
function Show-IrqAffMenu($d, $button) {
    $menu = New-Object System.Windows.Controls.ContextMenu
    $menu.Style = $window.FindResource('MacMenu')
    foreach ($p in 0, 5) {
        $mi = New-Object System.Windows.Controls.MenuItem
        $mi.Style = $window.FindResource('MacMenuItem'); $mi.Header = T $(if ($p -eq 0) { 'irq.aff.default' } else { 'irq.aff.spread' })
        $mi.IsCheckable = $true; $mi.IsChecked = $d.Want.Policy -eq $p; $mi.Tag = @{ D = $d; Policy = $p }
        $mi.Add_Click({ $t = $this.Tag; $t.D.Want.Policy = $t.Policy; $t.D.Want.Mask = [uint64]0; Update-IrqControls $t.D })
        [void]$menu.Items.Add($mi)
    }
    [void]$menu.Items.Add((New-Object System.Windows.Controls.Separator))
    $n = [Math]::Min(64, [Environment]::ProcessorCount)
    $chosen = if ($d.Want.Policy -eq 4) { @(ConvertFrom-CpuMask $d.Want.Mask) } else { @() }
    for ($i = 0; $i -lt $n; $i++) {
        $mi = New-Object System.Windows.Controls.MenuItem
        $mi.Style = $window.FindResource('MacMenuItem'); $mi.Header = "CPU $i"
        if ($script:irqBest -and $i -eq $script:irqBest[0]) { $mi.Header = "CPU $i  ·  " + (T 'irq.best') }
        $mi.IsCheckable = $true; $mi.StaysOpenOnClick = $true; $mi.IsChecked = $i -in $chosen; $mi.Tag = @{ D = $d; Cpu = $i }
        $mi.Add_Click({
            $t = $this.Tag; $w = $t.D.Want
            $cpus = if ($w.Policy -eq 4) { @(ConvertFrom-CpuMask $w.Mask) } else { @() }
            $cpus = if ($this.IsChecked) { @($cpus) + $t.Cpu } else { @($cpus | Where-Object { $_ -ne $t.Cpu }) }
            $w.Mask = ConvertTo-CpuMask $cpus
            $w.Policy = if ($w.Mask) { 4 } else { 0 }
            Update-IrqControls $t.D
        })
        [void]$menu.Items.Add($mi)
    }
    $menu.PlacementTarget = $button; $menu.Placement = 'Bottom'; $menu.IsOpen = $true
}
function Show-IrqDevices($data) {
    $ui.IrqList.Children.Clear()
    $script:irqHt = $data.Logical -gt $data.Cores -and $data.Cores -gt 0
    if ($data.Cores) {
        $ui.IrqHtText.Text = T $(if ($script:irqHt) { 'irq.ht.on' } else { 'irq.ht.off' }); $ui.IrqHt.Visibility = 'Visible'
    }
    $list = @($data.Devices | Where-Object { $_ -is [hashtable] } | Sort-Object { if ($irqOrder.ContainsKey($_.Class)) { $irqOrder[$_.Class] } else { 9 } }, { $_.Name })
    $script:irqDevices = $list
    # Other PCI devices: a closed group at the end
    $otherList = New-Object System.Windows.Controls.StackPanel; $otherList.Visibility = 'Collapsed'
    $otherHead = New-Object System.Windows.Controls.Button
    $otherHead.Style = $window.FindResource('Bare'); $otherHead.HorizontalContentAlignment = 'Stretch'; $otherHead.Padding = '14,10'; $otherHead.Tag = $otherList
    $oh = New-Object System.Windows.Controls.DockPanel
    $chev = New-Text ([string][char]0xE70D) 12; $chev.Style = $window.FindResource('Glyph'); [System.Windows.Controls.DockPanel]::SetDock($chev, 'Right'); $chev.VerticalAlignment = 'Center'
    $ohText = New-Object System.Windows.Controls.StackPanel
    [void]$ohText.Children.Add((New-Text (T 'irq.other') 14 'SemiBold'))
    $ohSub = New-Text (T 'irq.other.d') 12; $ohSub.Foreground = $window.FindResource('MutedBrush'); [void]$ohText.Children.Add($ohSub)
    [void]$oh.Children.Add($chev); [void]$oh.Children.Add($ohText); $otherHead.Content = $oh
    $otherHead.Add_Click({ $this.Tag.Visibility = if ($this.Tag.Visibility -eq 'Visible') { 'Collapsed' } else { 'Visible' } })
    foreach ($d in $list) {
        $d.Want = New-IrqWant $d
        $controls = New-Object System.Windows.Controls.WrapPanel; $controls.Margin = '0,8,0,0'
        $msi = New-Object System.Windows.Controls.CheckBox
        $msi.Style = $window.FindResource('Chip'); $msi.Content = 'MSI'; $msi.Margin = '0,0,6,6'; $msi.Tag = $d
        $msi.IsEnabled = [bool]($d.Support -band 6); $msi.ToolTip = T 'irq.msi.tip'
        $msi.Add_Click({ $this.Tag.Want.Msi = [bool]$this.IsChecked; Update-IrqControls $this.Tag })
        $limitBox = New-Object System.Windows.Controls.StackPanel; $limitBox.Orientation = 'Horizontal'; $limitBox.Margin = '0,0,6,6'
        $limitLabel = New-Text (T 'irq.limit') 12; $limitLabel.VerticalAlignment = 'Center'; $limitLabel.Margin = '4,0,6,0'; $limitLabel.Foreground = $window.FindResource('MutedBrush')
        $limit = New-Object System.Windows.Controls.TextBox
        $limit.Width = 48; $limit.Padding = '6,3'; $limit.VerticalContentAlignment = 'Center'; $limit.Tag = $d; $limit.ToolTip = T 'irq.limit.tip'
        foreach ($p in @(@('Background', 'Field'), @('Foreground', 'Text2'), @('CaretBrush', 'Text2'), @('BorderBrush', 'Line'))) {
            $limit.SetResourceReference([System.Windows.Controls.TextBox]::($p[0] + 'Property'), $p[1])
        }
        $limit.Add_TextChanged({
            $v = 0; [void][int]::TryParse($this.Text, [ref]$v)
            if ($this.Tag.Max -gt 0 -and $v -gt $this.Tag.Max) { $v = $this.Tag.Max }
            $this.Tag.Want.Limit = [Math]::Max(0, $v)
        })
        [void]$limitBox.Children.Add($limitLabel); [void]$limitBox.Children.Add($limit)
        if ($d.Max -gt 0) { $mx = New-Text ((T 'irq.max') -f $d.Max) 11; $mx.VerticalAlignment = 'Center'; $mx.Margin = '6,0,0,0'; $mx.Foreground = $window.FindResource('MutedBrush'); [void]$limitBox.Children.Add($mx) }
        $prio = New-Object System.Windows.Controls.Button
        $prio.Style = $window.FindResource('Pill'); $prio.Padding = '10,3'; $prio.Margin = '0,0,6,6'; $prio.FontSize = 12; $prio.Tag = $d; $prio.ToolTip = T 'irq.prio.tip'
        $prio.Add_Click({ $w = $this.Tag.Want; $w.Priority = ($w.Priority + 1) % 4; Update-IrqControls $this.Tag })
        $aff = New-Object System.Windows.Controls.Button
        $aff.Style = $window.FindResource('Pill'); $aff.Padding = '10,3'; $aff.Margin = '0,0,6,6'; $aff.FontSize = 12; $aff.Tag = $d; $aff.ToolTip = T 'irq.aff.tip'
        $aff.Add_Click({ Show-IrqAffMenu $this.Tag $this })
        $suggest = New-Object System.Windows.Controls.Button
        $suggest.Style = $window.FindResource('Pill'); $suggest.Padding = '10,3'; $suggest.Margin = '0,0,6,6'; $suggest.FontSize = 12; $suggest.Tag = $d
        $suggest.Content = T 'irq.suggest'; $suggest.ToolTip = T 'irq.suggest.tip'
        $suggest.Add_Click({ Set-IrqSuggested $this.Tag })
        $apply = New-Object System.Windows.Controls.Button
        $apply.Style = $window.FindResource('PillAccent'); $apply.Padding = '12,3'; $apply.Margin = '0,0,6,6'; $apply.FontSize = 12; $apply.Tag = $d; $apply.Content = T 'irq.apply'
        $apply.Add_Click({ Invoke-IrqApply $this.Tag })
        $undo = New-Object System.Windows.Controls.Button
        $undo.Style = $window.FindResource('Pill'); $undo.Padding = '10,3'; $undo.Margin = '0,0,6,6'; $undo.FontSize = 12; $undo.Tag = $d; $undo.Content = T 'toast.undo'
        $undo.Add_Click({ Restore-Irq $this.Tag.Id; Set-Status ((T 'irq.undone') -f $this.Tag.Name); Set-RestartNeeded; Start-IrqLoad })
        foreach ($x in $msi, $limitBox, $prio, $aff, $suggest, $apply, $undo) { [void]$controls.Children.Add($x) }
        $glyph = if ($irqGlyphs.ContainsKey($d.Class)) { $irqGlyphs[$d.Class] } else { 0xE964 }
        $row = New-Row ([string][char]$glyph) $d.Name $null (New-Object System.Windows.Controls.Border) $null
        $row.Sub.TextWrapping = 'Wrap'
        $panel = $row.Sub.Parent
        $panel.Children.Insert($panel.Children.IndexOf($row.Sub) + 1, $controls)
        $d.Ctl = @{ Row = $row; Msi = $msi; Limit = $limit; Prio = $prio; Aff = $aff; Suggest = $suggest; Undo = $undo }
        Update-IrqControls $d
        if ($d.Other) { [void]$otherList.Children.Add($row.Row) } else { [void]$ui.IrqList.Children.Add($row.Row) }
    }
    if (!$list.Count) { [void]$ui.IrqList.Children.Add((New-Text (T 'irq.none') 13)) }
    Update-Separators $ui.IrqList
    if ($otherList.Children.Count) {
        Update-Separators $otherList
        $line = New-Object System.Windows.Controls.Border; $line.Height = 1; $line.SetResourceReference([System.Windows.Controls.Border]::BackgroundProperty, 'Line')
        [void]$ui.IrqList.Children.Add($line); [void]$ui.IrqList.Children.Add($otherHead); [void]$ui.IrqList.Children.Add($otherList)
    }
    $ui.IrqUndoAll.Visibility = if ((Test-Path $irqBackupKey) -and @((Get-Item $irqBackupKey).Property).Count) { 'Visible' } else { 'Collapsed' }
}
# Suggested settings after the benchmark: MSI on where the device supports it; the graphics card on the best core
# (and high priority), the network adapter on the next one, USB controllers (mouse and keyboard) on the third
function Set-IrqSuggested($d) {
    $best = @($script:irqBest)
    if (!$best.Count) { return }
    $pick = switch ($d.Class) { 'Display' { $best[0] } 'Net' { $best[[Math]::Min(1, $best.Count - 1)] } default { $best[[Math]::Min(2, $best.Count - 1)] } }
    if ($d.Support -band 6) { $d.Want.Msi = $true }
    $d.Want.Policy = 4; $d.Want.Mask = ConvertTo-CpuMask @($pick)
    if ($d.Class -eq 'Display') { $d.Want.Priority = 3 }
    Update-IrqControls $d
    Set-Status ((T 'irq.suggested') -f $d.Name)
}
function Invoke-IrqApply($d) {
    $w = $d.Want
    # Storage controllers hold Windows itself: a wrong MSI setting there can stop Windows from starting
    if ($d.Class -in 'SCSIAdapter', 'HDC' -and ($w.Msi -ne ($d.Msi -eq 1) -or $w.Limit -ne $d.Limit)) {
        if ([System.Windows.MessageBox]::Show(((T 'irq.storageask') -f $d.Name), 'Akati OS Center', 'YesNo', 'Warning') -ne 'Yes') { return }
    }
    try {
        if (!(Write-Irq $d $w)) { Set-Status (T 'irq.nochange'); return }
        $d.Msi = if ($d.Support -band 6) { [int]$w.Msi } else { $d.Msi }
        $d.Limit = $w.Limit; $d.Policy = $w.Policy; $d.Mask = $w.Mask; $d.Priority = $w.Priority
        Update-IrqControls $d
        $ui.IrqUndoAll.Visibility = 'Visible'
        Set-RestartNeeded
        Set-Status ((T 'irq.applied') -f $d.Name)
    } catch { Set-Status $_.Exception.Message }
}
function Start-IrqLoad {
    if ($Screenshot) { Show-IrqDevices (& $irqWork); return }
    $ui.IrqList.Children.Clear(); [void]$ui.IrqList.Children.Add((New-Text (T 'irq.loading') 13))
    Start-Work $irqWork @() { param($r) $res = Get-LastOutput $r; if ($res -is [hashtable]) { Show-IrqDevices $res } else { Set-Status (T 'irq.failed') } } $null
}
$ui.IrqShow.Add_Click({
    if ($ui.IrqPanel.Visibility -eq 'Visible') { $ui.IrqPanel.Visibility = 'Collapsed'; $ui.IrqShowText.Text = T 'irq.show'; $ui.IrqShowText.Tag = 't:irq.show'; return }
    $ui.IrqPanel.Visibility = 'Visible'; $ui.IrqShowText.Text = T 'irq.hide'; $ui.IrqShowText.Tag = 't:irq.hide'
    if (!$script:irqLoaded) { $script:irqLoaded = $true; Start-IrqLoad }
})
$ui.IrqUndoAll.Add_Click({
    if ([System.Windows.MessageBox]::Show((T 'irq.undoall.ask'), 'Akati OS Center', 'YesNo', 'Question') -ne 'Yes') { return }
    foreach ($name in @((Get-Item $irqBackupKey -ErrorAction SilentlyContinue).Property)) { try { Restore-Irq ($name -replace '#', '\') } catch { } }
    Set-RestartNeeded; Set-Status (T 'irq.undoneall'); Start-IrqLoad
})

# The benchmark: bars per logical processor; the best ones are suggested (never CPU 0)
function Show-IrqCores([double[]]$res) {
    $ui.IrqCores.Children.Clear()
    $n = [int]($res.Count / 3)
    if ($n -lt 1) { return }
    $pauses = [double[]]$res[$n..(2 * $n - 1)]; $load = [double[]]$res[(2 * $n)..(3 * $n - 1)]
    # Ranked by the time interrupts took away (less is better)
    $free = [double[]]@($load | ForEach-Object { 100 - $_ })
    $script:irqBest = Get-BestCores $free ([bool]$script:irqHt)
    $worstLoad = [Math]::Max(1, ($load | Measure-Object -Maximum).Maximum)
    for ($i = 0; $i -lt $n; $i++) {
        $col = New-Object System.Windows.Controls.StackPanel; $col.Width = 52; $col.Margin = '0,0,6,6'
        $track = New-Object System.Windows.Controls.Border; $track.Height = 44; $track.CornerRadius = 4; $track.Width = 26
        $track.SetResourceReference([System.Windows.Controls.Border]::BackgroundProperty, 'Fill')
        $bar = New-Object System.Windows.Controls.Border; $bar.VerticalAlignment = 'Bottom'; $bar.CornerRadius = 4
        # The bar shows the interrupt load: the higher, the busier the processor is with interrupts
        $bar.Height = [Math]::Max(3, 44 * $load[$i] / $worstLoad)
        $rank = [array]::IndexOf([int[]]$script:irqBest, $i)
        $bar.SetResourceReference([System.Windows.Controls.Border]::BackgroundProperty, $(if ($rank -ge 0 -and $rank -lt 3) { 'Accent2' } else { 'Handle' }))
        $track.Child = $bar
        $name = New-Text "CPU $i" 11 'SemiBold'; $name.HorizontalAlignment = 'Center'; $name.Margin = '0,4,0,0'
        $val = New-Text ('{0:N2}%' -f $load[$i]) 10; $val.HorizontalAlignment = 'Center'; $val.Foreground = $window.FindResource('MutedBrush')
        $col.ToolTip = (T 'irq.core.tip') -f $i, ('{0:N2}' -f $load[$i]), ('{0:N0}' -f $pauses[$i])
        foreach ($x in $track, $name, $val) { [void]$col.Children.Add($x) }
        [void]$ui.IrqCores.Children.Add($col)
    }
    $ui.IrqBenchState.Tag = $null
    $ui.IrqBenchState.Text = if ($script:irqBest.Count) { (T 'irq.bench.done') -f (($script:irqBest | Select-Object -First 3 | ForEach-Object { "CPU $_" }) -join ', ') } else { T 'irq.bench.few' }
    foreach ($d in @($script:irqDevices)) { if ($d.Ctl) { Update-IrqControls $d } }
}
$ui.IrqBench.Add_Click({
    $rounds = if ($ui.IrqRounds3.IsChecked) { 3 } elseif ($ui.IrqRounds10.IsChecked) { 10 } else { 5 }
    $n = [Math]::Min(64, [Environment]::ProcessorCount); $ms = 150
    $ui.IrqBench.IsEnabled = $false
    $ui.IrqBenchState.Tag = $null
    $ui.IrqBenchState.Text = (T 'irq.bench.running') -f [int][Math]::Ceiling($n * $rounds * ($ms + 2) / 1000)
    Set-Status $ui.IrqBenchState.Text $true
    Start-Work { param($n, $rounds, $ms) , [AkatiOS.Cores]::Run($n, $rounds, $ms) } @($n, $rounds, $ms) {
        param($r)
        $ui.IrqBench.IsEnabled = $true; Set-Status (T 'ready')
        $res = Get-LastOutput $r
        if ($res -is [double[]] -or $res -is [object[]]) { Show-IrqCores ([double[]]$res) } else { $ui.IrqBenchState.Text = T 'irq.failed' }
    } $null
})
