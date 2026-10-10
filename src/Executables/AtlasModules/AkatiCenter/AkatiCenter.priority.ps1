<#
.SYNOPSIS
    Akati OS Center: Tweaks > CPU time for the window in front (Win32PrioritySeparation): pick a value, measure what
    the value now does, and compare values on this PC.
    Dot-sourced by AkatiCenter.ps1 (runs in its scope: $ui, $window, T and the other parts).
#>
# ---------------------------------------------------------------------------------------------
# The value is HKLM\SYSTEM\CurrentControlSet\Control\PriorityControl\Win32PrioritySeparation (AtlasOS sets 0x26,
# the Windows default for desktops). A new value is also handed to Windows at once (NtSetSystemInformation,
# SystemPrioritySeparation), so no restart is needed. Get-PrioritySeparation (logic.ps1) explains each value.
# ---------------------------------------------------------------------------------------------
Add-Mark 'CPU time'
$w32Key = 'HKLM:\SYSTEM\CurrentControlSet\Control\PriorityControl'
$w32Default = 0x26
$w32Values = 0x26, 0x24, 0x25, 0x28, 0x29, 0x2A, 0x14, 0x15, 0x16, 0x18, 0x19, 0x1A
$w32Compare = 0x26, 0x24, 0x28, 0x2A, 0x16, 0x18

Import-Code 'Sched' @'
using System;
using System.Diagnostics;
using System.Runtime.InteropServices;
using System.Threading;
namespace AkatiOS {
    public static class Sched {
        [DllImport("ntdll.dll")] static extern int NtSetSystemInformation(int infoClass, ref int info, int length);
        [DllImport("winmm.dll")] static extern uint timeBeginPeriod(uint period);
        [DllImport("winmm.dll")] static extern uint timeEndPeriod(uint period);
        [DllImport("kernel32.dll")] static extern IntPtr GetCurrentThread();
        [DllImport("kernel32.dll")] static extern UIntPtr SetThreadAffinityMask(IntPtr thread, UIntPtr mask);
        [DllImport("kernel32.dll")] static extern bool GetThreadTimes(IntPtr thread, out long created, out long exited, out long kernel, out long user);
        // Hands the value to Windows now (SystemPrioritySeparation = 39); 0 = done
        public static int Apply(int value) { return NtSetSystemInformation(39, ref value, 4); }
        // On one processor, while a busy background program runs there too: the share of the processor this thread
        // gets while it is busy (%), then the median delay when it wakes up from a 2 ms sleep (microseconds).
        public static double[] Measure(int cpu, int ms) {
            IntPtr thread = GetCurrentThread();
            Thread.BeginThreadAffinity();
            UIntPtr old = SetThreadAffinityMask(thread, new UIntPtr(1UL << cpu));
            timeBeginPeriod(1);
            try {
                Thread.Sleep(5);
                long c, e, k0, u0, k1, u1;
                GetThreadTimes(thread, out c, out e, out k0, out u0);
                Stopwatch watch = Stopwatch.StartNew();
                double x = 1.0001;
                while (watch.ElapsedMilliseconds < ms) { for (int i = 0; i < 1000; i++) x = x * 1.0000001 + 0.0000001; }
                GetThreadTimes(thread, out c, out e, out k1, out u1);
                double wall = watch.Elapsed.TotalMilliseconds * 10000.0;
                double share = Math.Min(100.0, 100.0 * ((k1 - k0) + (u1 - u0)) / Math.Max(1.0, wall));
                double[] delays = new double[40];
                for (int i = 0; i < delays.Length; i++) {
                    long t = Stopwatch.GetTimestamp();
                    Thread.Sleep(2);
                    delays[i] = Math.Max(0.0, (Stopwatch.GetTimestamp() - t) * 1000000.0 / Stopwatch.Frequency - 2000.0);
                }
                Array.Sort(delays);
                if (x < 0) share += 0;
                return new double[] { share, delays[delays.Length / 2] };
            } finally {
                timeEndPeriod(1);
                SetThreadAffinityMask(thread, old);
                Thread.EndThreadAffinity();
            }
        }
    }
}
'@

function Get-W32Value { $v = Get-RegValue $w32Key 'Win32PrioritySeparation'; if ($null -eq $v) { 2 } else { [int]$v } }
function Get-W32Text([int]$v) {
    $p = Get-PrioritySeparation $v
    $parts = @((T "w32.q.$($p.Quantum)"), (T $(if ($p.Fixed) { 'w32.fixed' } else { 'w32.variable' })))
    if (!$p.Fixed) { $parts += (T 'w32.turns') -f ($p.Boost + 1) }
    if ($p.Boost) { $parts += (T 'w32.boost') -f $p.Boost }
    '0x{0:X2}  ·  {1}' -f $v, ($parts -join '  ·  ')
}
function Get-W32Desc([int]$v) {
    $p = Get-PrioritySeparation $v
    $text = (T "w32.d.$($p.Quantum)") + ' ' + $(if ($p.Fixed) { T 'w32.d.fixed' } else { (T 'w32.d.variable') -f ($p.Boost + 1) })
    if ($p.Boost) { $text += ' ' + ((T 'w32.d.boost') -f $p.Boost) }
    $text
}
function Update-W32 {
    $now = Get-W32Value
    $ui.W32Now.Text = (T 'w32.now') -f (Get-W32Text $now) + $(if ($now -eq $w32Default) { '  ·  ' + (T 'w32.default') } else { '' })
    $ui.W32Desc.Text = Get-W32Desc $now
    foreach ($b in $ui.W32Values.Children) { $b.Style = $window.FindResource($(if ([int]$b.Tag -eq $now) { 'PillAccent' } else { 'Pill' })) }
}
function Set-W32([int]$v) {
    try {
        Set-ItemProperty -Path $w32Key -Name Win32PrioritySeparation -Value $v -Type DWord -Force
        [void][AkatiOS.Sched]::Apply($v)
        Update-W32
        Set-Status ((T 'w32.set') -f ('0x{0:X2}' -f $v))
    } catch { Set-Status $_.Exception.Message }
}
foreach ($v in $w32Values) {
    $b = New-Object System.Windows.Controls.Button
    $b.Style = $window.FindResource('Pill'); $b.Padding = '10,4'; $b.Margin = '0,0,6,6'; $b.FontSize = 12; $b.Tag = $v
    $b.Content = '0x{0:X2}' -f $v
    $b.Add_Click({ Set-W32 ([int]$this.Tag) })
    $b.Add_MouseEnter({ $this.ToolTip = Get-W32Text ([int]$this.Tag) })
    [void]$ui.W32Values.Children.Add($b)
    $chip = New-Object System.Windows.Controls.CheckBox
    $chip.Style = $window.FindResource('Chip'); $chip.Content = '0x{0:X2}' -f $v; $chip.Margin = '0,0,6,6'; $chip.Tag = $v; $chip.IsChecked = $v -in $w32Compare
    [void]$ui.W32Pick.Children.Add($chip)
}
Update-W32

# A busy program in the background, on the same processor as the measuring thread; stopped afterwards
$w32Work = {
    param([int[]]$values, [int]$rounds, [int]$key)
    $cpu = [Math]::Min(63, [Environment]::ProcessorCount - 1)
    $regKey = 'HKLM:\SYSTEM\CurrentControlSet\Control\PriorityControl'
    $original = (Get-ItemProperty -Path $regKey -Name Win32PrioritySeparation -ErrorAction SilentlyContinue).Win32PrioritySeparation
    $mask = [long]1 -shl $cpu
    $hog = Start-Process powershell.exe -ArgumentList "-NoProfile -WindowStyle Hidden -Command `"[Diagnostics.Process]::GetCurrentProcess().ProcessorAffinity = [IntPtr]$mask; while (`$true) { }`"" -WindowStyle Hidden -PassThru
    $results = @{}
    try {
        Start-Sleep -Milliseconds 1500
        foreach ($v in $values) { $results[$v] = @{ Share = 0.0; Delay = 0.0 } }
        for ($r = 0; $r -lt $rounds; $r++) {
            foreach ($v in @($values | Sort-Object { Get-Random })) {
                if ($values.Count -gt 1) {
                    Set-ItemProperty -Path $regKey -Name Win32PrioritySeparation -Value $v -Type DWord -Force
                    [void][AkatiOS.Sched]::Apply($v)
                    Start-Sleep -Milliseconds 150
                }
                $m = [AkatiOS.Sched]::Measure($cpu, 600)
                $results[$v].Share += $m[0] / $rounds; $results[$v].Delay += $m[1] / $rounds
            }
        }
    } finally {
        if ($values.Count -gt 1 -and $null -ne $original) {
            Set-ItemProperty -Path $regKey -Name Win32PrioritySeparation -Value ([int]$original) -Type DWord -Force
            [void][AkatiOS.Sched]::Apply([int]$original)
        }
        try { Stop-Process -Id $hog.Id -Force -ErrorAction SilentlyContinue } catch { }
    }
    $results
}
$ui.W32Measure.Add_Click({
    $ui.W32Measure.IsEnabled = $false; $ui.W32Run.IsEnabled = $false
    $ui.W32MeasureText.Visibility = 'Visible'; $ui.W32MeasureText.Text = T 'w32.measuring'
    Set-Status (T 'w32.measuring') $true
    $now = Get-W32Value
    Start-Work $w32Work @([int[]]@($now), 3, 0) {
        param($r, $now)
        $ui.W32Measure.IsEnabled = $true; $ui.W32Run.IsEnabled = $true; Set-Status (T 'ready')
        $res = Get-LastOutput $r
        if ($res -isnot [hashtable] -or !$res.ContainsKey($now)) { $ui.W32MeasureText.Text = T 'w32.failed'; return }
        $ui.W32MeasureText.Text = (T 'w32.result') -f ('{0:N0}' -f $res[$now].Share), ('{0:N0}' -f $res[$now].Delay)
    } $now
})
$ui.W32Run.Add_Click({
    $values = [int[]]@($ui.W32Pick.Children | Where-Object { $_.IsChecked } | ForEach-Object { [int]$_.Tag })
    if ($values.Count -lt 2) { $ui.W32State.Text = T 'w32.pick2'; return }
    $rounds = if ($ui.W32Rounds6.IsChecked) { 6 } else { 3 }
    $ui.W32Run.IsEnabled = $false; $ui.W32Measure.IsEnabled = $false
    $ui.W32State.Text = (T 'w32.running') -f [int]($values.Count * $rounds * 1.0 + 2)
    Set-Status $ui.W32State.Text $true
    $ui.W32Results.Children.Clear()
    Start-Work $w32Work @($values, $rounds, 0) {
        param($r)
        $ui.W32Run.IsEnabled = $true; $ui.W32Measure.IsEnabled = $true; Set-Status (T 'ready'); Update-W32
        $res = Get-LastOutput $r
        if ($res -isnot [hashtable]) { $ui.W32State.Text = T 'w32.failed'; return }
        Show-W32Results $res
    } $null
})
# Best first: the bigger share of the processor, then the faster wake-up
function Show-W32Results($res) {
    $ui.W32Results.Children.Clear()
    $ranked = @($res.Keys | Sort-Object { - [Math]::Round($res[$_].Share) }, { $res[$_].Delay })
    $ui.W32State.Text = (T 'w32.best') -f ('0x{0:X2}' -f $ranked[0])
    $now = Get-W32Value
    for ($i = 0; $i -lt $ranked.Count; $i++) {
        $v = $ranked[$i]
        $use = New-Object System.Windows.Controls.Button
        $use.Style = $window.FindResource($(if ($i -eq 0) { 'PillAccent' } else { 'Pill' })); $use.Padding = '12,3'; $use.FontSize = 12; $use.Tag = $v
        $use.Content = T $(if ($v -eq $now) { 'active' } else { 'w32.use' }); $use.IsEnabled = $v -ne $now
        $use.Add_Click({ Set-W32 ([int]$this.Tag); Show-W32Results $script:w32Last })
        $row = New-Row ([string][char]$(if ($i -eq 0) { 0xE735 } else { 0xE916 })) (Get-W32Text $v) $null $use $null
        $row.Sub.Text = (T 'w32.result') -f ('{0:N0}' -f $res[$v].Share), ('{0:N0}' -f $res[$v].Delay)
        [void]$ui.W32Results.Children.Add($row.Row)
    }
    $script:w32Last = $res
    Update-Separators $ui.W32Results
}
