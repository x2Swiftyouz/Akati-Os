<#
.SYNOPSIS
    Akati OS Center: Quick tools > Mouse test: the report rate (polling rate) of the mouse. The user moves the mouse in a box
    for 5 seconds; every report of the mouse is counted from raw input (WM_INPUT), which Windows does not merge like the
    mouse move events of a window. When raw input cannot be used, the window events are counted and the result says
    it is approximate.
    Dot-sourced by AkatiCenter.ps1 (runs in its scope: $ui, $window, T and the other parts).
#>
Add-Mark 'Mouse test'
# A hidden message-only window that receives the raw mouse input of this app (RIDEV_INPUTSINK) and keeps the time of each
# report that moved (GetMessageTime, in ms). The WPF message loop of this thread delivers its messages.
$mouseRateCode = @'
using System;
using System.Collections.Generic;
using System.Runtime.InteropServices;
namespace AkatiOS {
public static class MouseRate {
    delegate IntPtr WndProcFn(IntPtr h, uint m, IntPtr w, IntPtr l);
    [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
    struct WNDCLASSEX { public uint cbSize, style; public WndProcFn lpfnWndProc; public int cbClsExtra, cbWndExtra; public IntPtr hInstance, hIcon, hCursor, hbrBackground; public string lpszMenuName, lpszClassName; public IntPtr hIconSm; }
    [StructLayout(LayoutKind.Sequential)] struct RAWINPUTDEVICE { public ushort UsagePage, Usage; public uint Flags; public IntPtr Target; }
    [StructLayout(LayoutKind.Sequential)] struct RAWINPUTHEADER { public uint Type, Size; public IntPtr Device, wParam; }
    [StructLayout(LayoutKind.Sequential)] struct RAWMOUSE { public ushort Flags, Pad, ButtonFlags, ButtonData; public uint RawButtons; public int LastX, LastY; public uint Extra; }
    [DllImport("user32.dll", CharSet = CharSet.Unicode, SetLastError = true)] static extern ushort RegisterClassEx(ref WNDCLASSEX c);
    [DllImport("user32.dll", CharSet = CharSet.Unicode, SetLastError = true)] static extern IntPtr CreateWindowEx(uint ex, string cls, string name, uint style, int x, int y, int w, int h, IntPtr parent, IntPtr menu, IntPtr inst, IntPtr param);
    [DllImport("user32.dll")] static extern IntPtr DefWindowProc(IntPtr h, uint m, IntPtr w, IntPtr l);
    [DllImport("user32.dll", SetLastError = true)] static extern bool RegisterRawInputDevices(RAWINPUTDEVICE[] d, uint n, uint size);
    [DllImport("user32.dll")] static extern uint GetRawInputData(IntPtr raw, uint cmd, IntPtr data, ref uint size, uint header);
    [DllImport("user32.dll")] static extern int GetMessageTime();
    [DllImport("kernel32.dll", CharSet = CharSet.Unicode)] static extern IntPtr GetModuleHandle(string name);
    static readonly WndProcFn proc = Proc;
    static readonly List<double> times = new List<double>();
    static IntPtr hwnd = IntPtr.Zero;
    static bool registered, first = true;
    static int start;
    public static int Count { get { return times.Count; } }
    static bool Register(uint flags, IntPtr target) {
        RAWINPUTDEVICE[] d = new RAWINPUTDEVICE[1];
        d[0].UsagePage = 1; d[0].Usage = 2; d[0].Flags = flags; d[0].Target = target;
        return RegisterRawInputDevices(d, 1, (uint)Marshal.SizeOf(typeof(RAWINPUTDEVICE)));
    }
    public static bool Start() {
        times.Clear(); first = true;
        if (hwnd == IntPtr.Zero) {
            WNDCLASSEX c = new WNDCLASSEX();
            c.cbSize = (uint)Marshal.SizeOf(typeof(WNDCLASSEX)); c.lpfnWndProc = proc; c.hInstance = GetModuleHandle(null); c.lpszClassName = "AkatiMouseRate";
            if (RegisterClassEx(ref c) == 0 && Marshal.GetLastWin32Error() != 1410) return false;
            hwnd = CreateWindowEx(0, "AkatiMouseRate", "", 0, 0, 0, 0, 0, new IntPtr(-3), IntPtr.Zero, c.hInstance, IntPtr.Zero);
            if (hwnd == IntPtr.Zero) return false;
        }
        registered = Register(0x100, hwnd);
        return registered;
    }
    public static double[] Stop() {
        if (registered) { Register(1, IntPtr.Zero); registered = false; }
        return times.ToArray();
    }
    static IntPtr Proc(IntPtr h, uint m, IntPtr w, IntPtr l) {
        if (m == 0x00FF && registered) {
            uint hs = (uint)Marshal.SizeOf(typeof(RAWINPUTHEADER)), size = 0;
            GetRawInputData(l, 0x10000003, IntPtr.Zero, ref size, hs);
            if (size > 0) {
                IntPtr buf = Marshal.AllocHGlobal((int)size);
                try {
                    if (GetRawInputData(l, 0x10000003, buf, ref size, hs) == size) {
                        RAWINPUTHEADER head = (RAWINPUTHEADER)Marshal.PtrToStructure(buf, typeof(RAWINPUTHEADER));
                        if (head.Type == 0) {
                            RAWMOUSE mouse = (RAWMOUSE)Marshal.PtrToStructure(new IntPtr(buf.ToInt64() + hs), typeof(RAWMOUSE));
                            if (mouse.LastX != 0 || mouse.LastY != 0) {
                                int now = GetMessageTime();
                                if (first) { start = now; first = false; }
                                times.Add(unchecked((uint)(now - start)));
                            }
                        }
                    }
                } finally { Marshal.FreeHGlobal(buf); }
            }
        }
        return DefWindowProc(h, m, w, l);
    }
}
}
'@
$script:mouseRaw = $null
$script:mouseRun = $null
$script:mouseMoves = New-Object System.Collections.Generic.List[double]
$mouseTimer = New-Object System.Windows.Threading.DispatcherTimer
$mouseTimer.Interval = [TimeSpan]::FromMilliseconds(100)

function Show-MouseTest {
    if ($script:mouseRun) { Stop-MouseTest $true }
    $ui.MouseAvg.Text = '-'; $ui.MousePeak.Text = '-'; $ui.MouseNote.Text = ''; $ui.MouseBar.Value = 0
    $ui.MouseAreaText.Text = T 'mouse.ready'; $ui.MouseStart.Content = T 'mouse.start'
    $ui.MouseTest.Visibility = 'Visible'
    [void]$ui.MouseStart.Focus()
}
function Close-MouseTest {
    if ($script:mouseRun) { Stop-MouseTest $true }
    $ui.MouseTest.Visibility = 'Collapsed'
}
function Start-MouseTest {
    # The C# helper is compiled the first time (Import-Code keeps it in the cache folder)
    if ($null -eq $script:mouseRaw) {
        $script:mouseRaw = $false
        try { Import-Code 'MouseRate' $mouseRateCode; $script:mouseRaw = $true } catch { }
    }
    $raw = $false
    if ($script:mouseRaw) { try { $raw = [AkatiOS.MouseRate]::Start() } catch { $raw = $false } }
    $script:mouseMoves.Clear()
    $script:mouseRun = @{ Raw = $raw; Began = $null }
    $ui.MouseAvg.Text = '-'; $ui.MousePeak.Text = '-'; $ui.MouseNote.Text = ''; $ui.MouseBar.Value = 0
    $ui.MouseAreaText.Text = T 'mouse.wait'; $ui.MouseStart.IsEnabled = $false
    $mouseTimer.Start()
}
# The 5 seconds start with the first movement
$mouseTimer.Add_Tick({
    $run = $script:mouseRun
    if (!$run) { $mouseTimer.Stop(); return }
    $count = if ($run.Raw) { [AkatiOS.MouseRate]::Count } else { $script:mouseMoves.Count }
    if (!$run.Began) {
        if ($count -gt 0) { $run.Began = Get-Date }
        elseif ($script:mouseMoves.Count -gt 0) { $run.Began = Get-Date }
        else { return }
    }
    $sec = ((Get-Date) - $run.Began).TotalSeconds
    $ui.MouseBar.Value = [Math]::Min(100, $sec * 20)
    $ui.MouseAreaText.Text = (T 'mouse.moving') -f [Math]::Max(0, [Math]::Ceiling(5 - $sec))
    if ($sec -ge 5) { Stop-MouseTest $false }
})
$ui.MouseArea.Add_MouseMove({
    param($s, $e)
    if ($script:mouseRun) { $script:mouseMoves.Add([double]$e.Timestamp) }
})
function Stop-MouseTest([bool]$cancel) {
    $mouseTimer.Stop()
    $run = $script:mouseRun; $script:mouseRun = $null
    $times = @()
    if ($run -and $run.Raw) { try { $times = [double[]][AkatiOS.MouseRate]::Stop() } catch { $times = @() } }
    $ui.MouseStart.IsEnabled = $true; $ui.MouseStart.Content = T 'mouse.again'
    if ($cancel -or !$run) { return }
    # Raw input that gave nothing while the window saw the mouse move: the window events instead
    $approx = !$run.Raw -or ($times.Count -lt 20 -and $script:mouseMoves.Count -ge 20)
    if ($approx) { $times = [double[]]@($script:mouseMoves) }
    Show-MouseResult (Get-MouseRate $times) $approx
}
function Show-MouseResult($m, [bool]$approx) {
    $ui.MouseBar.Value = 100
    $ui.MouseAreaText.Text = T 'mouse.ready'
    if ($m.Error) { $ui.MouseAvg.Text = '-'; $ui.MousePeak.Text = '-'; $ui.MouseNote.Text = T $m.Error; return }
    $ui.MouseAvg.Text = '{0} Hz' -f $m.Avg
    $ui.MousePeak.Text = '{0} Hz' -f $m.Peak
    $note = (T "mouse.note.$(Get-MouseRateClass $m.Avg)") + ' ' + ((T 'mouse.result') -f $m.Reports)
    if ($approx) { $note = (T 'mouse.approx') + ' ' + $note }
    $ui.MouseNote.Text = $note
    Add-Log 'ToolsLog' ('{0}: {1} Hz / {2} Hz' -f (T 'qt.mousetest'), $m.Avg, $m.Peak)
}
$ui.MouseStart.Add_Click({ Start-MouseTest })
$ui.MouseClose.Add_Click({ Close-MouseTest })
