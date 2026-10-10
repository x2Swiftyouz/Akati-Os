<#
.SYNOPSIS
    Akati OS Center: Appearance: themes, presets, accent colors, wallpapers, cursors and sounds.
    Dot-sourced by AkatiCenter.ps1 (runs in its scope: $ui, $window, T and the other parts).
#>
# ---------------------------------------------------------------------------------------------
# Appearance
# ---------------------------------------------------------------------------------------------
Add-Mark 'Appearance'
$themes = @(
    @{ Key = 'dark';      File = 'akatios-dark.theme';      Image = 'akatios-dark.png' }
    @{ Key = 'light';     File = 'akatios-light.theme';     Image = 'akatios-light.png' }
    @{ Key = 'slideshow'; File = 'akatios-slideshow.theme'; Image = 'akatios-lockscreen.png' }
)

function Update-ThemeCards {
    if (!$script:appearanceBuilt) { return }
    $current = [string](Get-RegValue 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes' 'CurrentTheme')
    foreach ($th in $themes) {
        $active = $current -like "*$($th.File)"
        if ($active) { $th.Card.SetResourceReference([System.Windows.Controls.Border]::BorderBrushProperty, 'Accent2') } else { $th.Card.BorderBrush = $window.FindResource('CardBorder') }
        $th.Button.Content = if ($active) { T 'active' } else { T 'apply' }
    }
}

# The theme cards, wallpapers and style presets are made when the page first opens (Initialize-Appearance):
# decoding their pictures made the app start about half a second slower.
function Add-ThemeCards {
    foreach ($th in $themes) {
        $card = New-Object System.Windows.Controls.Border
        $card.Style = $window.FindResource('Card'); $card.Margin = '8,0'; $card.Padding = '12'; $card.BorderThickness = 2
        $stack = New-Object System.Windows.Controls.StackPanel
        $preview = New-Object System.Windows.Controls.Border
        $preview.CornerRadius = 8; $preview.Height = 130; $preview.ClipToBounds = $true; $preview.SetResourceReference([System.Windows.Controls.Border]::BackgroundProperty, 'Fill')
        $img = New-Object System.Windows.Controls.Image
        $img.Stretch = 'UniformToFill'; $img.Source = Get-Image (Join-Path $wallpapers $th.Image) 480
        $preview.Child = $img
        $name = New-Text (T "theme.$($th.Key)") 14 'SemiBold' "t:theme.$($th.Key)"; $name.Margin = '2,12,0,0'
        $desc = New-Text '' 12; $desc.Foreground = $window.FindResource('MutedBrush'); $desc.Margin = '2,2,0,10'
        if ($th.Key -eq 'slideshow') { $desc.Tag = 't:theme.slideshow.d'; $desc.Text = T 'theme.slideshow.d' } else { $desc.Text = ' ' }
        $btn = New-Object System.Windows.Controls.Button
        $btn.Style = $window.FindResource('Secondary'); $btn.Tag = $th
        $btn.Add_Click({
            $t = $this.Tag
            $path = Join-Path $themesDir $t.File
            if (Test-Path -LiteralPath $path) { Start-Process -FilePath $path }
            Set-Status ((T 'status.theme') -f (T "theme.$($t.Key)"))
            $timer2 = New-Object System.Windows.Threading.DispatcherTimer
            $timer2.Interval = [TimeSpan]::FromSeconds(3)
            $timer2.Add_Tick({ $this.Stop(); Update-ThemeCards })
            $timer2.Start()
        })
        [void]$stack.Children.Add($preview); [void]$stack.Children.Add($name); [void]$stack.Children.Add($desc); [void]$stack.Children.Add($btn)
        $card.Child = $stack
        $th.Card = $card; $th.Button = $btn
        [void]$ui.ThemesGrid.Children.Add($card)
    }
    Update-ThemeCards
}

# Windows API: wallpaper, cursors and the "colors changed" message
Import-Code 'Native' @'
using System;
using System.Runtime.InteropServices;
namespace AkatiOS {
    public static class Native {
        [DllImport("user32.dll", CharSet = CharSet.Unicode)] public static extern bool SystemParametersInfo(int action, int param, string value, int flags);
        [DllImport("user32.dll", CharSet = CharSet.Unicode)] public static extern IntPtr SendMessageTimeout(IntPtr hWnd, int msg, IntPtr wParam, string lParam, int flags, int timeout, out IntPtr result);
        [DllImport("dwmapi.dll")] public static extern int DwmSetWindowAttribute(IntPtr hwnd, int attribute, ref int value, int size);
        [DllImport("user32.dll", CharSet = CharSet.Unicode)] public static extern IntPtr LoadCursorFromFile(string file);
    }
}
'@
function Send-SettingChange([string]$area) {
    $r = [IntPtr]::Zero
    [void][AkatiOS.Native]::SendMessageTimeout([IntPtr]0xffff, 0x1A, [IntPtr]::Zero, $area, 2, 3000, [ref]$r)
}

# Accent color: Akati OS Center, Windows (Start, taskbar, title bars) and the Akati OS Terminal colors
$accents = @(
    @{ Key = 'purple'; Base = '#8A3FD6'; Light = '#B07CF0'; G1 = '#A35CF0'; G2 = '#6C3BC8' }
    @{ Key = 'blue';   Base = '#2F6FE0'; Light = '#7AA8FF'; G1 = '#4C86F5'; G2 = '#2752C2' }
    @{ Key = 'cyan';   Base = '#0E9FB0'; Light = '#5AD8E6'; G1 = '#22B8C8'; G2 = '#0B7D99' }
    @{ Key = 'green';  Base = '#1F9D57'; Light = '#6FDC9A'; G1 = '#2DB86A'; G2 = '#178048' }
    @{ Key = 'pink';   Base = '#D13F94'; Light = '#F488C6'; G1 = '#E559A9'; G2 = '#A82E7A' }
    @{ Key = 'red';    Base = '#D6453F'; Light = '#F58C84'; G1 = '#E85A50'; G2 = '#B03530' }
    @{ Key = 'orange'; Base = '#D9771E'; Light = '#F5B15F'; G1 = '#EE9135'; G2 = '#B65F16' }
)
function ConvertTo-Color([string]$hex) { [System.Windows.Media.ColorConverter]::ConvertFromString($hex) }

# New brushes for this window. The XAML uses them as DynamicResource, so every style follows at once
# (brushes inside styles are frozen and cannot be recolored in place).
# Look picker (Appearance): Auto, Dark or Light, saved as CenterLook
$lookChoice = Get-RegValue $settingsKey 'CenterLook'
if ($lookChoice -notin 'dark', 'light', 'time') { $lookChoice = 'auto' }
$ui["Look$([Globalization.CultureInfo]::InvariantCulture.TextInfo.ToTitleCase($lookChoice))"].IsChecked = $true
foreach ($n in 'Auto', 'Dark', 'Light', 'Time') {
    $ui["Look$n"].Add_Checked({ Save-Setting CenterLook $this.Name.Substring(4).ToLowerInvariant(); Set-CenterLook (Get-LookName) })
}

# Text size: the whole window is scaled (LayoutTransform, so the layout fits the window at every size)
$zoomSteps = 90, 100, 110, 125
$script:zoom = 100
function Set-Zoom([int]$percent) {
    if ($percent -notin $zoomSteps) { $percent = 100 }
    $script:zoom = $percent
    $root = $ui.RootBorder.Child
    $root.LayoutTransform = if ($percent -eq 100) { [System.Windows.Media.Transform]::Identity } else { New-Object System.Windows.Media.ScaleTransform ($percent / 100), ($percent / 100) }
}
# The saved size first, then the clicks (Save-Setting is defined later in AkatiCenter.ps1)
$savedZoom = if ($Screenshot) { 100 } else { [int](Get-RegValue $settingsKey 'Zoom') }
if ($savedZoom -notin $zoomSteps) { $savedZoom = 100 }
$ui["Zoom$savedZoom"].IsChecked = $true
Set-Zoom $savedZoom
foreach ($z in $zoomSteps) {
    $ui["Zoom$z"].Add_Checked({ $p = [int]$this.Name.Substring(4); Set-Zoom $p; Save-Setting Zoom $p; Set-Status ((T 'status.zoom') -f $p) })
}

function Set-CenterAccent($a) {
    $res = $window.Resources
    # ::new, not New-Object: New-Object wraps the brush in a PSObject, which WPF does not accept as a brush
    $res['Accent'] = [System.Windows.Media.SolidColorBrush]::new((ConvertTo-Color $a.Base))
    $res['Accent2'] = [System.Windows.Media.SolidColorBrush]::new((ConvertTo-Color $a.Light))
    $res['AccentGradient'] = [System.Windows.Media.LinearGradientBrush]::new((ConvertTo-Color $a.G1), (ConvertTo-Color $a.G2), [System.Windows.Point]::new(0, 0), [System.Windows.Point]::new(1, 1))
}

# Windows keeps the accent as 0xAABBGGRR (and a palette of 8 shades from light to dark)
function Set-WindowsAccent($a) {
    $c = ConvertTo-Color $a.Base
    function Mix($col, [double]$t) {
        # t > 0 towards white, t < 0 towards black
        if ($t -ge 0) { [byte]($col + (255 - $col) * $t) } else { [byte]($col * (1 + $t)) }
    }
    $palette = New-Object byte[] 32
    $shades = 0.55, 0.38, 0.2, 0, -0.2, -0.38, -0.55, -0.7
    for ($i = 0; $i -lt 8; $i++) {
        $palette[$i * 4] = Mix $c.R $shades[$i]; $palette[$i * 4 + 1] = Mix $c.G $shades[$i]; $palette[$i * 4 + 2] = Mix $c.B $shades[$i]; $palette[$i * 4 + 3] = 0
    }
    $abgr = [BitConverter]::ToInt32([byte[]]@($c.R, $c.G, $c.B, 0xFF), 0)
    $dark = [BitConverter]::ToInt32([byte[]]@($palette[16], $palette[17], $palette[18], 0xFF), 0)
    $argb = [BitConverter]::ToInt32([byte[]]@($c.B, $c.G, $c.R, 0xC4), 0)
    $accentKey = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Accent'
    $dwmKey = 'HKCU:\Software\Microsoft\Windows\DWM'
    foreach ($k in $accentKey, $dwmKey) { if (!(Test-Path $k)) { New-Item -Path $k -Force | Out-Null } }
    Set-ItemProperty -Path $accentKey -Name AccentPalette -Value $palette -Type Binary
    Set-ItemProperty -Path $accentKey -Name AccentColorMenu -Value $abgr -Type DWord
    Set-ItemProperty -Path $accentKey -Name StartColorMenu -Value $dark -Type DWord
    Set-ItemProperty -Path $dwmKey -Name AccentColor -Value $abgr -Type DWord
    Set-ItemProperty -Path $dwmKey -Name ColorizationColor -Value $argb -Type DWord
    Set-ItemProperty -Path $dwmKey -Name ColorizationAfterglow -Value $argb -Type DWord
    # Use this color instead of one picked from the wallpaper
    Set-ItemProperty -Path 'HKCU:\Control Panel\Desktop' -Name AutoColorization -Value 0 -Type DWord -ErrorAction SilentlyContinue
    Send-SettingChange 'ImmersiveColorSet'
}

# The Akati OS Terminal colors are a Terminal "fragment" in ProgramData
function Set-TerminalAccent($a) {
    $fragment = Join-Path $env:ProgramData 'Microsoft\Windows Terminal\Fragments\AkatiOS\akatios.json'
    if (!(Test-Path -LiteralPath $fragment)) { return }
    $json = Get-Content -LiteralPath $fragment -Raw -Encoding UTF8 | ConvertFrom-Json
    $c = ConvertTo-Color $a.Base
    $sel = '#{0:X2}{1:X2}{2:X2}' -f [int]($c.R * 0.45), [int]($c.G * 0.45), [int]($c.B * 0.45)
    foreach ($scheme in $json.schemes) { $scheme.cursorColor = $a.Light; $scheme.selectionBackground = $sel; $scheme.purple = $a.G1; $scheme.brightPurple = $a.Light }
    # UTF-8 without BOM, like the file Windows Terminal reads
    [IO.File]::WriteAllText($fragment, ($json | ConvertTo-Json -Depth 5), (New-Object Text.UTF8Encoding $false))
}

# Center, Windows and Terminal at once; AccentLight is read by the performance widget
function Use-Accent($acc) {
    Set-CenterAccent $acc
    Save-Setting Accent $acc.Key
    Save-Setting AccentLight $acc.Light
    if ($acc.Swatch) { $acc.Swatch.IsChecked = $true }
    try { Set-WindowsAccent $acc; Set-TerminalAccent $acc; Set-Status ((T 'status.accent') -f (T "accent.$($acc.Key)")) }
    catch { Set-Status $_.Exception.Message }
}
# Accent from the wallpaper: the most colorful hue of the desktop picture, in the same shades as the others
function Get-WallpaperFile {
    $file = [string](Get-RegValue 'HKCU:\Control Panel\Desktop' 'WallPaper')
    if ($file -and (Test-Path -LiteralPath $file)) { $file } else { $null }
}
function Get-WallpaperHue {
    $file = Get-WallpaperFile
    if (!$file) { return $null }
    $bmp = New-Object System.Windows.Media.Imaging.BitmapImage
    $bmp.BeginInit(); $bmp.UriSource = [Uri]$file; $bmp.DecodePixelWidth = 48; $bmp.CacheOption = 'OnLoad'; $bmp.EndInit()
    $conv = New-Object System.Windows.Media.Imaging.FormatConvertedBitmap $bmp, ([System.Windows.Media.PixelFormats]::Bgra32), $null, 0
    $w = $conv.PixelWidth; $h = $conv.PixelHeight
    $px = New-Object byte[] ($w * $h * 4)
    $conv.CopyPixels($px, $w * 4, 0)
    # Hue histogram (10 degree bins), weighted by saturation and brightness
    $bins = New-Object double[] 36
    for ($i = 0; $i -lt $px.Length; $i += 4) {
        $b = $px[$i] / 255; $g = $px[$i + 1] / 255; $r = $px[$i + 2] / 255
        $max = [Math]::Max($r, [Math]::Max($g, $b)); $min = [Math]::Min($r, [Math]::Min($g, $b)); $d = $max - $min
        if ($d -lt 0.08) { continue }
        $hue = if ($max -eq $r) { 60 * ((($g - $b) / $d) % 6) } elseif ($max -eq $g) { 60 * (($b - $r) / $d + 2) } else { 60 * (($r - $g) / $d + 4) }
        if ($hue -lt 0) { $hue += 360 }
        $bins[[int][Math]::Floor($hue / 10) % 36] += ($d / $max) * ($d / $max) * $max
    }
    $best = -1; $score = 0
    for ($i = 0; $i -lt 36; $i++) { $s = $bins[($i + 35) % 36] * 0.5 + $bins[$i] + $bins[($i + 1) % 36] * 0.5; if ($s -gt $score) { $score = $s; $best = $i } }
    # A black, white or gray picture has no color to take
    if ($best -lt 0 -or $score -lt 2) { return $null }
    $best * 10 + 5
}
$savedAccent = Get-RegValue $settingsKey 'Accent'
foreach ($a in $accents) {
    $sw = New-Object System.Windows.Controls.RadioButton
    $sw.Style = $window.FindResource('Swatch')
    $brush = New-Object System.Windows.Media.LinearGradientBrush (ConvertTo-Color $a.G1), (ConvertTo-Color $a.G2), 45
    $sw.Background = $brush
    $sw.Tag = $a
    $sw.ToolTip = T "accent.$($a.Key)"
    $sw.IsChecked = ($a.Key -eq $savedAccent) -or (!$savedAccent -and $a.Key -eq 'purple')
    $sw.Add_Click({ Use-Accent $this.Tag })
    $a.Swatch = $sw
    [void]$ui.AccentPanel.Children.Add($sw)
    if ($a.Key -eq $savedAccent) { Set-CenterAccent $a }
}

$wallSwatch = New-Object System.Windows.Controls.RadioButton
$wallSwatch.Style = $window.FindResource('Swatch'); $wallSwatch.ToolTip = T 'accent.wallpaper'
function Update-WallSwatch {
    $file = Get-WallpaperFile
    $wallSwatch.Background = if ($file) { $b = New-Object System.Windows.Media.ImageBrush (Get-Image $file 80); $b.Stretch = 'UniformToFill'; $b } else { $window.FindResource('Fill') }
}
$wallSwatch.Add_Click({
    $hue = try { Get-WallpaperHue } catch { $null }
    if ($null -eq $hue) { Set-Status (T 'accent.nowallcolor'); $this.IsChecked = $false; return }
    Save-Setting AccentHue ([int]$hue)
    Use-Accent (New-HueAccent $hue)
})
[void]$ui.AccentPanel.Children.Add($wallSwatch)
if ($savedAccent -eq 'wallpaper' -and $null -ne (Get-RegValue $settingsKey 'AccentHue')) {
    $wallSwatch.IsChecked = $true
    Set-CenterAccent (New-HueAccent ([double](Get-RegValue $settingsKey 'AccentHue')))
}

# Wallpapers: every picture in the Akati OS wallpaper folder
function Set-Wallpaper([string]$path) {
    # SPI_SETDESKWALLPAPER, saved to the user profile and sent to all windows
    Set-ItemProperty -Path 'HKCU:\Control Panel\Desktop' -Name WallpaperStyle -Value '10'
    Set-ItemProperty -Path 'HKCU:\Control Panel\Desktop' -Name TileWallpaper -Value '0'
    [void][AkatiOS.Native]::SystemParametersInfo(0x14, 0, $path, 3)
    Update-WallSwatch
    Set-Status ((T 'status.wallpaper') -f [IO.Path]::GetFileNameWithoutExtension($path))
}
function Add-WallpaperButtons {
    # One template for all the pictures
    $template = [Windows.Markup.XamlReader]::Parse(@'
<ControlTemplate xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation" TargetType="Button">
    <Border x:Name="Bd" xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml" CornerRadius="10" BorderThickness="2" BorderBrush="Transparent" Padding="2">
        <ContentPresenter/>
    </Border>
    <ControlTemplate.Triggers>
        <Trigger Property="IsMouseOver" Value="True"><Setter TargetName="Bd" Property="BorderBrush" Value="#B07CF0"/></Trigger>
    </ControlTemplate.Triggers>
</ControlTemplate>
'@)
    foreach ($file in @(Get-ChildItem -Path (Join-Path $wallpapers '*') -Include *.png, *.jpg -File -ErrorAction SilentlyContinue | Sort-Object Name)) {
        $btn = New-Object System.Windows.Controls.Button
        $btn.Cursor = 'Hand'; $btn.Margin = '0,0,12,12'; $btn.Tag = $file.FullName; $btn.ToolTip = $file.BaseName
        $btn.Template = $template
        $frame = New-Object System.Windows.Controls.Border
        $frame.Width = 168; $frame.Height = 95; $frame.CornerRadius = 8; $frame.SetResourceReference([System.Windows.Controls.Border]::BackgroundProperty, 'Fill')
        $brush = New-Object System.Windows.Media.ImageBrush (Get-Image $file.FullName 340)
        $brush.Stretch = 'UniformToFill'
        $frame.Background = $brush
        $btn.Content = $frame
        $btn.Add_Click({ Set-Wallpaper $this.Tag })
        [void]$ui.WallPanel.Children.Add($btn)
    }
}

# Cursors: Akati OS arrow and busy cursors; the other pointers stay the Windows ones
$akatiCursors = Join-Path $modules 'Other\AkatiOS\Cursors'
$windowsCursors = [ordered]@{
    AppStarting = '%SystemRoot%\cursors\aero_working.ani'; Arrow = '%SystemRoot%\cursors\aero_arrow.cur'
    Hand = '%SystemRoot%\cursors\aero_link.cur'; Help = '%SystemRoot%\cursors\aero_helpsel.cur'; No = '%SystemRoot%\cursors\aero_unavail.cur'
    NWPen = '%SystemRoot%\cursors\aero_pen.cur'; SizeAll = '%SystemRoot%\cursors\aero_move.cur'; SizeNESW = '%SystemRoot%\cursors\aero_nesw.cur'
    SizeNS = '%SystemRoot%\cursors\aero_ns.cur'; SizeNWSE = '%SystemRoot%\cursors\aero_nwse.cur'; SizeWE = '%SystemRoot%\cursors\aero_ew.cur'
    UpArrow = '%SystemRoot%\cursors\aero_up.cur'; Wait = '%SystemRoot%\cursors\aero_busy.ani'; Crosshair = ''; IBeam = ''
}
function Set-Cursors([bool]$akati) {
    $key = 'HKCU:\Control Panel\Cursors'
    foreach ($name in $windowsCursors.Keys) { Set-ItemProperty -Path $key -Name $name -Value $windowsCursors[$name] -Type ExpandString }
    if ($akati) {
        foreach ($f in 'akatios-arrow.cur', 'akatios-busy.ani', 'akatios-working.ani') {
            if ([AkatiOS.Native]::LoadCursorFromFile((Join-Path $akatiCursors $f)) -eq [IntPtr]::Zero) { throw "Windows cannot load $f" }
        }
        Set-ItemProperty -Path $key -Name Arrow -Value (Join-Path $akatiCursors 'akatios-arrow.cur') -Type ExpandString
        Set-ItemProperty -Path $key -Name Wait -Value (Join-Path $akatiCursors 'akatios-busy.ani') -Type ExpandString
        Set-ItemProperty -Path $key -Name AppStarting -Value (Join-Path $akatiCursors 'akatios-working.ani') -Type ExpandString
    }
    Set-ItemProperty -Path $key -Name '(default)' -Value $(if ($akati) { 'Akati OS' } else { 'Windows Default' })
    # SPI_SETCURSORS reloads the cursors from the registry
    [void][AkatiOS.Native]::SystemParametersInfo(0x57, 0, $null, 3)
}
$ui.CursorAkati.Add_Click({ try { Set-Cursors $true; Set-Status (T 'status.cursor.akati') } catch { Set-Status $_.Exception.Message } })
$ui.CursorWindows.Add_Click({ try { Set-Cursors $false; Set-Status (T 'status.cursor.windows') } catch { Set-Status $_.Exception.Message } })

# Sounds: Akati OS sounds, the Windows sounds or none (AtlasOS turns sounds off)
$akatiSounds = Join-Path $modules 'Other\AkatiOS\Sounds'
$soundEvents = [ordered]@{
    '.Default'           = @('akatios-default.wav', 'Windows Background.wav')
    'SystemAsterisk'     = @('akatios-info.wav', 'Windows Background.wav')
    'SystemExclamation'  = @('akatios-warning.wav', 'Windows Background.wav')
    'SystemHand'         = @('akatios-error.wav', 'Windows Foreground.wav')
    'SystemNotification' = @('akatios-info.wav', 'Windows Background.wav')
    'Notification.Default' = @('akatios-notify.wav', 'Windows Notify System Generic.wav')
    'DeviceConnect'      = @('akatios-connect.wav', 'Windows Hardware Insert.wav')
    'DeviceDisconnect'   = @('akatios-disconnect.wav', 'Windows Hardware Remove.wav')
}
function Set-Sounds([string]$scheme) {
    $root = 'HKCU:\AppEvents\Schemes\Apps\.Default'
    foreach ($ev in $soundEvents.Keys) {
        $k = "$root\$ev\.Current"
        if (!(Test-Path -LiteralPath $k)) { New-Item -Path $k -Force | Out-Null }
        $value = switch ($scheme) {
            'akati'   { Join-Path $akatiSounds $soundEvents[$ev][0] }
            'windows' { Join-Path $windir "Media\$($soundEvents[$ev][1])" }
            default   { '' }
        }
        Set-ItemProperty -LiteralPath $k -Name '(default)' -Value $value
    }
    Set-ItemProperty -Path 'HKCU:\AppEvents\Schemes' -Name '(default)' -Value '.Current'
}
$ui.SoundAkati.Add_Click({ try { Set-Sounds 'akati'; Set-Status (T 'status.sound.akati') } catch { Set-Status $_.Exception.Message } })
$ui.SoundWindows.Add_Click({ try { Set-Sounds 'windows'; Set-Status (T 'status.sound.windows') } catch { Set-Status $_.Exception.Message } })
$ui.SoundNone.Add_Click({ try { Set-Sounds 'none'; Set-Status (T 'status.sound.none') } catch { Set-Status $_.Exception.Message } })
# Play the notification sound that is set now, so the three choices can be compared
$ui.SoundPreview.Add_Click({
    $f = [string](Get-ItemProperty -LiteralPath 'HKCU:\AppEvents\Schemes\Apps\.Default\Notification.Default\.Current' -ErrorAction SilentlyContinue).'(default)'
    $f = [Environment]::ExpandEnvironmentVariables($f)
    if ($f -and (Test-Path -LiteralPath $f)) {
        try { (New-Object System.Media.SoundPlayer $f).Play(); Set-Status ((T 'status.sound.play') -f [IO.Path]::GetFileNameWithoutExtension($f)) } catch { Set-Status $_.Exception.Message }
    } else { Set-Status (T 'status.sound.none') }
})

# Style presets: wallpaper, accent color, look of Akati OS Center, cursor and sounds in one click
$presets = @(
    @{ Key = 'neon';    Wall = 'akatios-dark.png';  Accent = 'purple'; Look = 'Dark';  Cursor = $true;  Sound = 'akati' }
    @{ Key = 'ocean';   Wall = 'akatios-ocean.png'; Accent = 'cyan';   Look = 'Dark';  Cursor = $true;  Sound = 'akati' }
    @{ Key = 'ember';   Wall = 'akatios-ember.png'; Accent = 'orange'; Look = 'Dark';  Cursor = $true;  Sound = 'akati' }
    @{ Key = 'sakura';  Wall = 'akatios-mist.png';  Accent = 'pink';   Look = 'Light'; Cursor = $true;  Sound = 'akati' }
    @{ Key = 'stealth'; Wall = 'akatios-oled.png';  Accent = 'red';    Look = 'Dark';  Cursor = $false; Sound = 'none' }
)
function Add-PresetButtons {
    foreach ($p in $presets) {
        $file = Join-Path $wallpapers $p.Wall
        if (!(Test-Path -LiteralPath $file)) { continue }
        $acc = $accents | Where-Object { $_.Key -eq $p.Accent } | Select-Object -First 1
        $btn = New-Object System.Windows.Controls.Button
        $btn.Style = $window.FindResource('Bare'); $btn.Margin = '0,0,12,12'; $btn.Padding = '0'; $btn.Tag = $p
        $stack = New-Object System.Windows.Controls.StackPanel
        $frame = New-Object System.Windows.Controls.Border
        $frame.Width = 150; $frame.Height = 84; $frame.CornerRadius = 8; $frame.BorderThickness = '0,0,0,4'
        $frame.BorderBrush = New-Object System.Windows.Media.LinearGradientBrush (ConvertTo-Color $acc.G1), (ConvertTo-Color $acc.G2), 0
        $brush = New-Object System.Windows.Media.ImageBrush (Get-Image $file 300); $brush.Stretch = 'UniformToFill'
        $frame.Background = $brush
        $name = New-Text (T "preset.$($p.Key)") 13 'SemiBold' "t:preset.$($p.Key)"; $name.Margin = '2,6,0,0'
        [void]$stack.Children.Add($frame); [void]$stack.Children.Add($name)
        $btn.Content = $stack
        $btn.Add_Click({
            $p = $this.Tag
            try {
                Set-Wallpaper (Join-Path $wallpapers $p.Wall)
                Use-Accent ($accents | Where-Object { $_.Key -eq $p.Accent } | Select-Object -First 1)
                $ui["Look$($p.Look)"].IsChecked = $true
                Set-Cursors $p.Cursor
                Set-Sounds $p.Sound
                Set-Status ((T 'status.preset') -f (T "preset.$($p.Key)"))
            } catch { Set-Status $_.Exception.Message }
        })
        [void]$ui.PresetPanel.Children.Add($btn)
    }
}

function Initialize-Appearance {
    if ($script:appearanceBuilt) { return }
    $script:appearanceBuilt = $true
    Add-ThemeCards; Update-WallSwatch; Add-WallpaperButtons; Add-PresetButtons
}
if ($Screenshot) { Initialize-Appearance }

