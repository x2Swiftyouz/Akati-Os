<#
.SYNOPSIS
    Akati OS performance widget: a small bar on top of other windows (and of games in borderless or
    windowed mode) with CPU, RAM, GPU, the GPU temperature and the ping.
.DESCRIPTION
    Runs as the signed-in user. The icon next to the clock starts it (and again at sign-in while
    "Widget" is 1 in HKCU\Software\AkatiOS\Center). Drag it to move it; right-click for the menu.
    -Toggle   closes a running widget, or starts one when none runs.
#>
param ([switch]$Toggle)

$userKey = 'HKCU:\Software\AkatiOS\Center'
function Get-Setting([string]$name) { (Get-ItemProperty -Path $userKey -Name $name -ErrorAction SilentlyContinue).$name }
function Save-Setting([string]$name, $value) {
    if (!(Test-Path $userKey)) { New-Item -Path $userKey -Force | Out-Null }
    Set-ItemProperty -Path $userKey -Name $name -Value $value -Type DWord -Force
}

$others = @(Get-CimInstance Win32_Process -Filter "Name='powershell.exe'" -ErrorAction SilentlyContinue |
    Where-Object { $_.CommandLine -like '*AkatiWidget.ps1*' -and $_.ProcessId -ne $PID })
if ($Toggle -and $others.Count) {
    $others | ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }
    Save-Setting Widget 0
    exit 0
}
if ($others.Count) { exit 0 }
Save-Setting Widget 1

Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase

# Accent color of Akati OS Center (the light shade), for the values
$accentLight = @{ purple = '#B07CF0'; blue = '#7AA8FF'; cyan = '#5AD8E6'; green = '#6FDC9A'; pink = '#F488C6'; red = '#F58C84'; orange = '#F5B15F' }
$accent = [string](Get-Setting 'AccentLight')
if (!$accent) { $accent = $accentLight[[string](Get-Setting 'Accent')] }
if (!$accent) { $accent = '#B07CF0' }

[xml]$xaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation" xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="Akati OS widget" WindowStyle="None" AllowsTransparency="True" Background="Transparent" Topmost="True"
        ShowInTaskbar="False" ShowActivated="False" SizeToContent="WidthAndHeight" ResizeMode="NoResize"
        FontFamily="Segoe UI Variable Text, Segoe UI, Leelawadee UI" Foreground="#F5F5F7">
    <Border Background="#D81C1C1E" CornerRadius="10" BorderBrush="#33FFFFFF" BorderThickness="1" Padding="12,6">
        <StackPanel x:Name="Items" Orientation="Horizontal"/>
    </Border>
</Window>
"@
$window = [Windows.Markup.XamlReader]::Load((New-Object System.Xml.XmlNodeReader $xaml))
$items = $window.FindName('Items')
$values = @{}
foreach ($name in 'CPU', 'RAM', 'GPU', 'TEMP', 'PING') {
    $sp = New-Object System.Windows.Controls.StackPanel
    $sp.Margin = '0,0,14,0'
    $caption = New-Object System.Windows.Controls.TextBlock
    $caption.Text = $(if ($name -eq 'TEMP') { 'GPU °C' } else { $name }); $caption.FontSize = 10; $caption.Foreground = '#8E8E93'
    $value = New-Object System.Windows.Controls.TextBlock
    $value.Text = '-'; $value.FontSize = 15; $value.FontWeight = 'SemiBold'; $value.Foreground = $accent; $value.MinWidth = 38
    [void]$sp.Children.Add($caption); [void]$sp.Children.Add($value)
    [void]$items.Children.Add($sp)
    $values[$name] = @{ Panel = $sp; Text = $value }
}
$items.Children[$items.Children.Count - 1].Margin = '0'

# Position: the saved one, else the top right corner of the work area
$area = [System.Windows.SystemParameters]::WorkArea
$x = Get-Setting 'WidgetX'; $y = Get-Setting 'WidgetY'
if ($null -ne $x -and $null -ne $y -and $x -ge $area.Left - 50 -and $x -le $area.Right - 50 -and $y -ge $area.Top -and $y -le $area.Bottom - 30) {
    $window.Left = $x; $window.Top = $y
} else { $window.Left = $area.Right - 380; $window.Top = $area.Top + 12 }
$window.Add_MouseLeftButtonDown({
    $window.DragMove()
    Save-Setting WidgetX ([int]$window.Left); Save-Setting WidgetY ([int]$window.Top)
})

$widgetTexts = @{
    en = @{ open = 'Open Akati OS Center'; close = 'Close widget' }
    th = @{ open = 'เปิด Akati OS Center'; close = 'ปิดวิดเจ็ต' }
    vi = @{ open = 'Mở Akati OS Center'; close = 'Đóng tiện ích' }
    id = @{ open = 'Buka Akati OS Center'; close = 'Tutup widget' }
}
$lang = [string](Get-Setting 'Language')
if (!$widgetTexts.ContainsKey($lang)) { $lang = 'en' }
$menu = New-Object System.Windows.Controls.ContextMenu
$open = New-Object System.Windows.Controls.MenuItem
$open.Header = $widgetTexts[$lang].open
$open.Add_Click({
    $ps = Join-Path ([Environment]::GetFolderPath('Windows')) 'System32\WindowsPowerShell\v1.0\powershell.exe'
    Start-Process -FilePath $ps -ArgumentList "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$(Join-Path $PSScriptRoot 'AkatiCenter.ps1')`"" -WindowStyle Hidden
})
$close = New-Object System.Windows.Controls.MenuItem
$close.Header = $widgetTexts[$lang].close
$close.Add_Click({ Save-Setting Widget 0; $window.Close() })
[void]$menu.Items.Add($open); [void]$menu.Items.Add($close)
$window.ContextMenu = $menu

# Values are read in the background, so the widget never stutters while a game runs
$stats = [hashtable]::Synchronized(@{ Run = $true; Cpu = -1; Ram = -1; Gpu = -1; Temp = -1; Ping = -1 })
$worker = [PowerShell]::Create()
[void]$worker.AddScript({
    param($stats)
    $n = 0
    $smi = @("$env:windir\System32\nvidia-smi.exe", "$env:ProgramFiles\NVIDIA Corporation\NVSMI\nvidia-smi.exe") | Where-Object { Test-Path $_ } | Select-Object -First 1
    while ($stats.Run) {
        try { $stats.Cpu = [int](Get-CimInstance Win32_PerfFormattedData_PerfOS_Processor -Filter "Name='_Total'").PercentProcessorTime } catch { }
        try { $os = Get-CimInstance Win32_OperatingSystem; $stats.Ram = [int](100 * ($os.TotalVisibleMemorySize - $os.FreePhysicalMemory) / $os.TotalVisibleMemorySize) } catch { }
        if ($n % 2 -eq 0) {
            try {
                $sum = (Get-CimInstance Win32_PerfFormattedData_GPUPerformanceCounters_GPUEngine -ErrorAction Stop | Where-Object { $_.Name -like '*engtype_3D*' } | Measure-Object -Property UtilizationPercentage -Sum).Sum
                $stats.Gpu = [int][Math]::Min(100, [double]$sum)
            } catch { $stats.Gpu = -1 }
        }
        if ($smi -and $n % 5 -eq 0) { try { $stats.Temp = [int](@(& $smi --query-gpu=temperature.gpu --format=csv,noheader,nounits)[0]) } catch { } }
        # Ping: TCP connect to Singapore, like the Dashboard
        if ($n % 5 -eq 0) {
            $ms = -1
            try {
                $ip = [Net.Dns]::GetHostAddresses('dynamodb.ap-southeast-1.amazonaws.com') | Where-Object { $_.AddressFamily -eq 'InterNetwork' } | Select-Object -First 1
                $c = New-Object Net.Sockets.TcpClient; $sw = [Diagnostics.Stopwatch]::StartNew()
                if ($c.ConnectAsync($ip, 443).Wait(2000) -and $c.Connected) { $ms = [int]$sw.Elapsed.TotalMilliseconds }
                $c.Close()
            } catch { }
            $stats.Ping = $ms
        }
        $n++
        Start-Sleep -Milliseconds 1000
    }
}).AddArgument($stats)
$handle = $worker.BeginInvoke()

$timer = New-Object System.Windows.Threading.DispatcherTimer
$timer.Interval = [TimeSpan]::FromSeconds(1)
$timer.Add_Tick({
    $values.CPU.Text.Text = if ($stats.Cpu -ge 0) { "$($stats.Cpu)%" } else { '-' }
    $values.RAM.Text.Text = if ($stats.Ram -ge 0) { "$($stats.Ram)%" } else { '-' }
    $values.GPU.Text.Text = if ($stats.Gpu -ge 0) { "$($stats.Gpu)%" } else { '-' }
    $values.PING.Text.Text = if ($stats.Ping -ge 0) { "$($stats.Ping) ms" } else { '-' }
    # The GPU temperature shows only where the NVIDIA tool reports it
    $values.TEMP.Panel.Visibility = if ($stats.Temp -gt 0) { 'Visible' } else { 'Collapsed' }
    $values.TEMP.Text.Text = "$($stats.Temp)"
    $values.TEMP.Text.Foreground = if ($stats.Temp -ge 90) { '#FF453A' } elseif ($stats.Temp -ge 80) { '#FF9F0A' } else { $accent }
})
$timer.Start()
$window.Add_Closed({ $timer.Stop(); $stats.Run = $false })
[void]$window.ShowDialog()
$stats.Run = $false
try { $worker.EndInvoke($handle) } catch { }
$worker.Dispose()
