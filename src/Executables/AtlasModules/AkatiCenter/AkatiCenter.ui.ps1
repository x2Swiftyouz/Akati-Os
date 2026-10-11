<#
.SYNOPSIS
    Akati OS Center: shared window parts: the dialog in the theme (Show-Ask), the progress card (Show-Progress),
    the switch pulse and the optional click sound.
    Dot-sourced by AkatiCenter.ps1 (runs in its scope: $ui, $window, T and the other parts).
#>
Add-Mark 'Dialogs and progress'
# Saved choices of Appearance > Sounds and motion (both off at first)
$script:uiSounds = !$Screenshot -and (Get-RegValue $settingsKey 'UiSounds') -eq 1
$script:reduceMotion = !$Screenshot -and (Get-RegValue $settingsKey 'ReduceMotion') -eq 1
# The new animations run only when they can be seen: not in screenshot mode, not with Reduce motion
function Test-Motion { !$Screenshot -and !$script:reduceMotion }

# ---------------------------------------------------------------------------------------------
# Dialog in the theme: a dimmed window and a card, instead of the white Windows message box.
# Show-Ask waits like a message box (a nested dispatcher frame), so callers keep "if ((Show-Ask ...) -eq 'Yes')".
# Buttons: YesNo, OK or OKCancel. Icon: Question, Warning, Information or Error. Returns Yes, No, OK or Cancel.
# ---------------------------------------------------------------------------------------------
$script:askFrame = $null
$script:askResult = $null
$askIcons = @{
    Question    = @{ Glyph = [string][char]0xE9CE; Back = 'AccentSoft'; Line = 'AccentLine'; Fore = 'AccentText' }
    Information = @{ Glyph = [string][char]0xE946; Back = 'AccentSoft'; Line = 'AccentLine'; Fore = 'AccentText' }
    Warning     = @{ Glyph = [string][char]0xE7BA; Back = 'WarnSoft'; Line = 'Warn'; Fore = 'Warn' }
    Error       = @{ Glyph = [string][char]0xE783; Back = 'DangerSoft'; Line = 'Danger'; Fore = 'Danger' }
}
# What each button returns: the primary (accent) button, the second (outlined) button, and Esc
function Get-AskResults([string]$buttons) {
    switch ($buttons) {
        'OK'       { @{ Primary = 'OK'; Secondary = $null; Cancel = 'OK' } }
        'OKCancel' { @{ Primary = 'OK'; Secondary = 'Cancel'; Cancel = 'Cancel' } }
        default    { @{ Primary = 'Yes'; Secondary = 'No'; Cancel = 'No' } }
    }
}
# Fills the card and shows it (also used by the screenshot mode, which does not wait)
function Set-AskContent([string]$message, [string]$buttons = 'YesNo', [string]$icon = 'Question', [string[]]$bullets = @(), [string]$note = '', [string]$title = '') {
    $kind = if ($askIcons.ContainsKey($icon)) { $askIcons[$icon] } else { $askIcons['Question'] }
    $ui.AskIcon.Text = $kind.Glyph
    $ui.AskIconBox.SetResourceReference([System.Windows.Controls.Border]::BackgroundProperty, $kind.Back)
    $ui.AskIconBox.SetResourceReference([System.Windows.Controls.Border]::BorderBrushProperty, $kind.Line)
    $ui.AskIcon.SetResourceReference([System.Windows.Controls.TextBlock]::ForegroundProperty, $kind.Fore)
    $ui.AskTitle.Text = if ($title) { $title } else { 'Akati OS Center' }
    $ui.AskText.Text = $message
    $ui.AskList.Children.Clear()
    foreach ($b in @($bullets | Where-Object { $_ })) {
        $row = New-Object System.Windows.Controls.DockPanel; $row.Margin = '0,0,0,6'
        $dot = New-Object System.Windows.Controls.Border
        $dot.Width = 6; $dot.Height = 6; $dot.CornerRadius = 3; $dot.Margin = '0,7,10,0'; $dot.VerticalAlignment = 'Top'
        $dot.SetResourceReference([System.Windows.Controls.Border]::BackgroundProperty, $kind.Fore)
        [System.Windows.Controls.DockPanel]::SetDock($dot, 'Left')
        $text = New-Text $b 13; $text.TextWrapping = 'Wrap'
        [void]$row.Children.Add($dot); [void]$row.Children.Add($text)
        [void]$ui.AskList.Children.Add($row)
    }
    $ui.AskList.Parent.Visibility = if ($ui.AskList.Children.Count) { 'Visible' } else { 'Collapsed' }
    $ui.AskNote.Text = $note
    $ui.AskNote.Visibility = if ($note) { 'Visible' } else { 'Collapsed' }
    $results = Get-AskResults $buttons
    $script:askResults = $results
    $ui.AskPrimary.Content = T $(if ($results.Primary -eq 'Yes') { 'dlg.yes' } else { 'dlg.ok' })
    $ui.AskSecondary.Content = T $(if ($results.Secondary -eq 'No') { 'dlg.no' } else { 'dlg.cancel' })
    $ui.AskSecondary.Visibility = if ($results.Secondary) { 'Visible' } else { 'Collapsed' }
    $ui.Ask.Visibility = 'Visible'
}
function Close-Ask([string]$result) {
    if ($ui.Ask.Visibility -ne 'Visible') { return }
    $script:askResult = $result
    $ui.Ask.Visibility = 'Collapsed'
    if ($script:askFrame) { $script:askFrame.Continue = $false }
}
function Show-Ask([string]$message, [string]$buttons = 'YesNo', [string]$icon = 'Question', [string[]]$bullets = @(), [string]$note = '', [string]$title = '') {
    # Before the window is on screen (or while another dialog is open): the Windows message box, with the same text
    if ($Screenshot -or !$window.IsLoaded -or $script:askFrame) {
        $text = $message
        if (@($bullets | Where-Object { $_ }).Count) { $text += "`r`n`r`n" + (@($bullets | Where-Object { $_ } | ForEach-Object { [string][char]0x2022 + '  ' + $_ }) -join "`r`n") }
        if ($note) { $text += "`r`n`r`n" + $note }
        return [string][System.Windows.MessageBox]::Show($text, $(if ($title) { $title } else { 'Akati OS Center' }), $buttons, $icon)
    }
    $before = [System.Windows.Input.Keyboard]::FocusedElement
    Set-AskContent $message $buttons $icon $bullets $note $title
    $script:askResult = $script:askResults.Cancel
    if (Test-Motion) {
        $ease = New-Object System.Windows.Media.Animation.CubicEase; $ease.EasingMode = 'EaseOut'
        $dur = New-Object System.Windows.Duration ([TimeSpan]::FromMilliseconds(160))
        $grow = New-Object System.Windows.Media.Animation.DoubleAnimation 0.94, 1, $dur; $grow.EasingFunction = $ease
        $fade = New-Object System.Windows.Media.Animation.DoubleAnimation 0, 1, $dur
        $ui.AskScale.BeginAnimation([System.Windows.Media.ScaleTransform]::ScaleXProperty, $grow)
        $ui.AskScale.BeginAnimation([System.Windows.Media.ScaleTransform]::ScaleYProperty, $grow)
        $ui.Ask.BeginAnimation([System.Windows.UIElement]::OpacityProperty, $fade)
    }
    $ui.Ask.UpdateLayout()
    [void]$ui.AskPrimary.Focus()
    # Wait here until a button, Enter or Esc closes the card (the window keeps working, like with a message box)
    $frame = New-Object System.Windows.Threading.DispatcherFrame
    $script:askFrame = $frame
    try { [System.Windows.Threading.Dispatcher]::PushFrame($frame) }
    finally { $script:askFrame = $null; $ui.Ask.Visibility = 'Collapsed' }
    if ($before -is [System.Windows.UIElement] -and $before.IsVisible) { try { [void]$before.Focus() } catch { } }
    return $script:askResult
}
# A message with only OK
function Show-Message([string]$message, [string]$icon = 'Information', [string[]]$bullets = @(), [string]$title = '') { [void](Show-Ask $message 'OK' $icon $bullets '' $title) }
$ui.AskPrimary.Add_Click({ Close-Ask $script:askResults.Primary })
$ui.AskSecondary.Add_Click({ Close-Ask $script:askResults.Secondary })
# Keys while the card is open: Enter confirms (or presses the focused button), Esc cancels, Tab moves between the two buttons
function Invoke-AskKey($e) {
    switch ([string]$e.Key) {
        'Escape' { Close-Ask $script:askResults.Cancel }
        'Return' { if ([System.Windows.Input.Keyboard]::FocusedElement -eq $ui.AskSecondary -and $script:askResults.Secondary) { Close-Ask $script:askResults.Secondary } else { Close-Ask $script:askResults.Primary } }
        { $_ -in 'Tab', 'Left', 'Right', 'Space' } { return }
        default { }
    }
    $e.Handled = $true
}

# ---------------------------------------------------------------------------------------------
# Progress card (bottom right): title, percentage or a moving bar, and Cancel when the job can stop.
# One job at a time: the last one shown owns the card. Hide-Progress hides it only for its owner.
# ---------------------------------------------------------------------------------------------
$script:prog = $null
# $percent: 0-100, or -1 when it is not known (the bar moves). $cancel is called as: & $cancel $data
function Show-Progress([string]$owner, [string]$title, [int]$percent = -1, [string]$detail = '', [scriptblock]$cancel = $null, $data = $null) {
    # Screenshot mode: only the sample card (jobs started there never finish, the timer does not run)
    if ($Screenshot -and !$script:progSample) { return }
    $shown = $ui.ProgCard.Visibility -eq 'Visible'
    $same = $script:prog -and $script:prog.Owner -eq $owner
    $script:prog = @{ Owner = $owner; Cancel = $cancel; Data = $data }
    if ($ui.ProgTitle.Text -ne $title) { $ui.ProgTitle.Text = $title }
    if ($ui.ProgDetail.Text -ne $detail) { $ui.ProgDetail.Text = $detail }
    $ui.ProgDetail.Visibility = if ($detail) { 'Visible' } else { 'Collapsed' }
    if ($percent -ge 0) {
        $ui.ProgBar.IsIndeterminate = $false; $ui.ProgBar.Value = [Math]::Min(100, $percent)
        $ui.ProgPercent.Text = '{0}%' -f [Math]::Min(100, $percent); $ui.ProgPercent.Visibility = 'Visible'
    } else {
        $ui.ProgBar.IsIndeterminate = $true; $ui.ProgPercent.Visibility = 'Collapsed'
    }
    $ui.ProgCancel.Visibility = if ($cancel) { 'Visible' } else { 'Collapsed' }
    if (!$same) { $ui.ProgCancel.IsEnabled = $true }
    if (!$shown) {
        $ui.ProgCard.Visibility = 'Visible'
        if (Test-Motion) {
            $ease = New-Object System.Windows.Media.Animation.CubicEase; $ease.EasingMode = 'EaseOut'
            $dur = New-Object System.Windows.Duration ([TimeSpan]::FromMilliseconds(220))
            $move = New-Object System.Windows.Media.Animation.DoubleAnimation 16, 0, $dur; $move.EasingFunction = $ease
            $ui.ProgShift.BeginAnimation([System.Windows.Media.TranslateTransform]::YProperty, $move)
            $ui.ProgCard.BeginAnimation([System.Windows.UIElement]::OpacityProperty, (New-Object System.Windows.Media.Animation.DoubleAnimation 0, 1, $dur))
        }
    }
}
function Hide-Progress([string]$owner) {
    if (!$script:prog -or ($owner -and $script:prog.Owner -ne $owner)) { return }
    $script:prog = $null
    $ui.ProgCard.Visibility = 'Collapsed'
}
$ui.ProgCancel.Add_Click({
    $p = $script:prog
    if ($p -and $p.Cancel) { $this.IsEnabled = $false; try { & $p.Cancel $p.Data } catch { Set-Status $_.Exception.Message } }
})

# ---------------------------------------------------------------------------------------------
# Switches: a short pulse when one turns on; an optional soft click for switches and the sidebar
# ---------------------------------------------------------------------------------------------
# The click: 30 ms of a fading 1.6 kHz tone, made in memory (a 1.3 KB WAV, no file)
function Get-ClickPlayer {
    if ($script:clickPlayer) { return $script:clickPlayer }
    $rate = 22050; $n = [int]($rate * 0.03)
    $ms = New-Object System.IO.MemoryStream
    $w = New-Object System.IO.BinaryWriter $ms
    $ascii = [Text.Encoding]::ASCII
    $w.Write($ascii.GetBytes('RIFF')); $w.Write([int](36 + $n * 2)); $w.Write($ascii.GetBytes('WAVE'))
    $w.Write($ascii.GetBytes('fmt ')); $w.Write([int]16); $w.Write([int16]1); $w.Write([int16]1); $w.Write([int]$rate); $w.Write([int]($rate * 2)); $w.Write([int16]2); $w.Write([int16]16)
    $w.Write($ascii.GetBytes('data')); $w.Write([int]($n * 2))
    for ($i = 0; $i -lt $n; $i++) {
        $t = $i / $rate
        $w.Write([int16](6000 * [Math]::Sin(2 * [Math]::PI * 1600 * $t) * [Math]::Exp(-$t * 160)))
    }
    $w.Flush(); $ms.Position = 0
    $script:clickPlayer = New-Object System.Media.SoundPlayer $ms
    $script:clickPlayer.Load()
    return $script:clickPlayer
}
function Invoke-UiSound {
    if (!$script:uiSounds -or $Screenshot) { return }
    try { (Get-ClickPlayer).Play() } catch { }
}
function Start-SwitchPulse($toggle) {
    if (!(Test-Motion)) { return }
    $scale = $toggle.RenderTransform
    if ($scale -isnot [System.Windows.Media.ScaleTransform] -or $scale.IsFrozen) {
        $scale = New-Object System.Windows.Media.ScaleTransform
        $toggle.RenderTransformOrigin = New-Object System.Windows.Point 0.5, 0.5
        $toggle.RenderTransform = $scale
    }
    $grow = New-Object System.Windows.Media.Animation.DoubleAnimation 1, 1.12, (New-Object System.Windows.Duration ([TimeSpan]::FromMilliseconds(110)))
    $grow.AutoReverse = $true
    $grow.EasingFunction = New-Object System.Windows.Media.Animation.QuadraticEase
    $scale.BeginAnimation([System.Windows.Media.ScaleTransform]::ScaleXProperty, $grow)
    $scale.BeginAnimation([System.Windows.Media.ScaleTransform]::ScaleYProperty, $grow)
}
# One handler for the whole window: a click is made by the user (a switch set by code raises no Click)
$switchStyle = $window.FindResource('Switch')
$navStyle = $window.FindResource('Nav')
$window.AddHandler([System.Windows.Controls.Primitives.ButtonBase]::ClickEvent, [System.Windows.RoutedEventHandler]{
    param($sender, $e)
    $src = $e.OriginalSource
    if ($src -is [System.Windows.Controls.CheckBox] -and [object]::ReferenceEquals($src.Style, $switchStyle)) {
        Invoke-UiSound
        if ($src.IsChecked -eq $true) { Start-SwitchPulse $src }
    } elseif ($src -is [System.Windows.Controls.RadioButton] -and [object]::ReferenceEquals($src.Style, $navStyle)) {
        Invoke-UiSound
    }
})
