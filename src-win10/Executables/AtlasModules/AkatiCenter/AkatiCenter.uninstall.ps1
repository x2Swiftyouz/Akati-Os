<#
.SYNOPSIS
    Akati OS Center: Uninstaller: every installed program and Store app, its own uninstaller, then the leftovers.
    Dot-sourced by AkatiCenter.ps1 (runs in its scope: $ui, $window, T and the other parts).
#>
# ---------------------------------------------------------------------------------------------
# Programs come from the Uninstall keys (as in Apps & features, without updates and system parts), Store apps from
# Get-AppxPackage (without frameworks, system and non-removable apps). After an uninstall Akati OS looks for what is
# left: folders named like the program, its Start menu shortcuts and its registry keys. Nothing is removed until the
# user presses Remove: folders and shortcuts go to the Recycle Bin, registry keys are exported to .reg files first.
# ---------------------------------------------------------------------------------------------
Add-Mark 'Uninstaller'
Add-Type -AssemblyName Microsoft.VisualBasic
$uninstBackupDir = Join-Path $env:ProgramData 'AkatiOS\Backups\Uninstaller'
# Runtimes and drivers other programs need: uninstalling them asks first
$uninstShared = 'Visual C\+\+|Redistributable|\.NET|DirectX|WebView2|Runtime|Driver|Chipset|Microsoft Edge|Windows SDK|VC_redist'
$uninstWork = {
    $items = New-Object System.Collections.ArrayList
    foreach ($root in 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall', 'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall', 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall') {
        foreach ($key in @(Get-ChildItem -Path $root -ErrorAction SilentlyContinue)) {
            $e = Get-ItemProperty -LiteralPath $key.PSPath -ErrorAction SilentlyContinue
            if (!$e.DisplayName -or $e.SystemComponent -eq 1 -or $e.ParentKeyName -or $e.ReleaseType -match 'Update|Hotfix') { continue }
            if (!$e.UninstallString -and !$e.QuietUninstallString) { continue }
            $date = $null
            if ([string]$e.InstallDate -match '^(\d{4})(\d{2})(\d{2})$') { try { $date = Get-Date -Year $Matches[1] -Month $Matches[2] -Day $Matches[3] } catch { } }
            $icon = ([string]$e.DisplayIcon -split ',')[0].Trim('"')
            [void]$items.Add(@{ Kind = 'program'; Name = [string]$e.DisplayName; Publisher = [string]$e.Publisher; Version = [string]$e.DisplayVersion
                                Size = [double]$e.EstimatedSize * 1KB; Date = $date; Icon = $icon; Key = $key.PSPath
                                Uninstall = [string]$e.UninstallString; Quiet = [string]$e.QuietUninstallString; Location = ([string]$e.InstallLocation).Trim('"') })
        }
    }
    # Two entries with the same name and version (32 and 64-bit keys): only one
    $seen = @{}
    $programs = @($items | Where-Object { $k = "$($_.Name)|$($_.Version)"; if ($seen.ContainsKey($k)) { $false } else { $seen[$k] = $true; $true } })
    $store = @(try {
        Get-AppxPackage -ErrorAction Stop | Where-Object { !$_.IsFramework -and !$_.NonRemovable -and $_.SignatureKind -ne 'System' } | ForEach-Object {
            $name = ($_.Name -replace '^[^.]+\.', '') -creplace '([a-z])([A-Z])', '$1 $2'
            $date = try { (Get-Item -LiteralPath $_.InstallLocation -ErrorAction Stop).CreationTime } catch { $null }
            @{ Kind = 'store'; Name = $name; Publisher = (($_.Publisher -split ',')[0] -replace '^CN=', ''); Version = [string]$_.Version
               Size = 0; Date = $date; Icon = $null; Package = $_.PackageFullName; Family = $_.PackageFamilyName; Location = $_.InstallLocation }
        } } catch { })
    @($programs) + @($store)
}

# The rows are made once; filter, search and sort only hide and move them
function Show-Uninst($list) {
    $ui.UninstList.Children.Clear()
    $script:uninstItems = @($list | Where-Object { $_ -is [hashtable] })
    foreach ($it in $script:uninstItems) {
        $it.Shared = $it.Kind -eq 'program' -and $it.Name -match $uninstShared
        $right = New-Object System.Windows.Controls.StackPanel; $right.Orientation = 'Horizontal'
        if ($it.Location -and (Test-Path -LiteralPath $it.Location -PathType Container)) {
            $open = New-Object System.Windows.Controls.Button
            $open.Style = $window.FindResource('Bare'); $open.Padding = '7'; $open.Margin = '0,0,6,0'; $open.ToolTip = T 'openfolder'; $open.Tag = $it.Location
            $og = New-Text ([string][char]0xE838) 13; $og.Style = $window.FindResource('Glyph'); $open.Content = $og
            $open.Add_Click({ Start-Process explorer.exe -ArgumentList "`"$($this.Tag)`"" })
            [void]$right.Children.Add($open)
        }
        $btn = New-Object System.Windows.Controls.Button
        $btn.Style = $window.FindResource('Pill'); $btn.Padding = '12,4'; $btn.Content = T 'uninstall'; $btn.Tag = $it
        $btn.Add_Click({ Start-UninstItem $this.Tag })
        [void]$right.Children.Add($btn)
        $check = New-Object System.Windows.Controls.CheckBox
        $check.Style = $window.FindResource('Tick'); $check.Tag = $it
        $check.Add_Click({ Update-UninstBatch })
        $row = New-Row ([string][char]0xE74C) $it.Name $null $right $null $check
        $tile = New-Text (($it.Name -replace '[^\p{L}\p{N}]', '').Substring(0, [Math]::Min(2, ($it.Name -replace '[^\p{L}\p{N}]', '').Length)).ToUpperInvariant()) 11 'Bold'
        $tile.HorizontalAlignment = 'Center'; $tile.VerticalAlignment = 'Center'; $tile.Foreground = $window.FindResource('MutedBrush'); $row.Icon.Child = $tile
        $parts = @()
        if ($it.Publisher) { $parts += $it.Publisher }
        if ($it.Version) { $parts += "v$($it.Version)" }
        if ($it.Size -gt 0) { $parts += Format-Size $it.Size }
        if ($it.Date) { $parts += $it.Date.ToString('d MMM yyyy', (Get-LangCulture)) }
        if ($it.Kind -eq 'store') { $parts += T 'uninst.store' }
        $row.Sub.Text = $parts -join '  ·  '
        if ($it.Shared) {
            $badge = New-Object System.Windows.Controls.Border
            $badge.CornerRadius = 4; $badge.Padding = '5,1'; $badge.Margin = '8,0,0,0'; $badge.VerticalAlignment = 'Center'; $badge.Background = '#33FF9F0A'
            $bt = New-Text (T 'uninst.shared') 10 'SemiBold'; $bt.Foreground = '#FF9F0A'; $badge.Child = $bt; $badge.ToolTip = T 'uninst.shared.tip'
            $line = New-Object System.Windows.Controls.StackPanel; $line.Orientation = 'Horizontal'
            $panel = $row.Title.Parent; $panel.Children.Remove($row.Title)
            [void]$line.Children.Add($row.Title); [void]$line.Children.Add($badge); $panel.Children.Insert(0, $line)
        }
        $it.Row = $row; $it.Check = $check; $it.Button = $btn
        [void]$ui.UninstList.Children.Add($row.Row)
    }
    $ui.UninstShowAll.Content = '{0}  {1}' -f (T 'uninst.all'), $script:uninstItems.Count
    $ui.UninstShowPrograms.Content = '{0}  {1}' -f (T 'uninst.programs'), @($script:uninstItems | Where-Object { $_.Kind -eq 'program' }).Count
    $ui.UninstShowStore.Content = '{0}  {1}' -f (T 'uninst.storeapps'), @($script:uninstItems | Where-Object { $_.Kind -eq 'store' }).Count
    Update-UninstView
    Update-UninstBatch
    # Program icons a few at a time, so the page shows at once
    $script:uninstIconQueue = New-Object System.Collections.Queue
    foreach ($it in $script:uninstItems) { if ($it.Icon -and $it.Icon -match '\.(exe|ico|dll)$') { $script:uninstIconQueue.Enqueue($it) } }
    if (!$script:uninstIconTimer) {
        $script:uninstIconTimer = New-Object System.Windows.Threading.DispatcherTimer
        $script:uninstIconTimer.Interval = [TimeSpan]::FromMilliseconds(30)
        $script:uninstIconTimer.Add_Tick({
            for ($i = 0; $i -lt 4 -and $script:uninstIconQueue.Count; $i++) {
                $it = $script:uninstIconQueue.Dequeue()
                $img = Get-FileIcon @([Environment]::ExpandEnvironmentVariables($it.Icon))
                if ($img) { Set-RowIcon $it.Row $img }
            }
            if (!$script:uninstIconQueue.Count) { $this.Stop() }
        })
    }
    $script:uninstIconTimer.Start()
}
function Update-UninstView {
    $q = $ui.UninstSearch.Text.Trim().ToLowerInvariant()
    $kind = if ($ui.UninstShowPrograms.IsChecked) { 'program' } elseif ($ui.UninstShowStore.IsChecked) { 'store' } else { $null }
    $sorted = if ($ui.UninstSortSize.IsChecked) { @($script:uninstItems | Sort-Object { - $_.Size }, { $_.Name }) }
              elseif ($ui.UninstSortDate.IsChecked) { @($script:uninstItems | Sort-Object { if ($_.Date) { - $_.Date.Ticks } else { 0 } }, { $_.Name }) }
              else { @($script:uninstItems | Sort-Object { $_.Name }) }
    $ui.UninstList.Children.Clear()
    $shown = 0; $bytes = 0
    foreach ($it in $sorted) {
        $match = (!$kind -or $it.Kind -eq $kind) -and (!$q -or "$($it.Name) $($it.Publisher)".ToLowerInvariant().Contains($q))
        $it.Row.Row.Visibility = if ($match) { 'Visible' } else { 'Collapsed' }
        if ($match) { $shown++; $bytes += $it.Size }
        [void]$ui.UninstList.Children.Add($it.Row.Row)
    }
    Update-Separators $ui.UninstList
    $ui.UninstCount.Text = (T 'uninst.count') -f $shown, $script:uninstItems.Count, (Format-Size $bytes)
    $ui.UninstEmpty.Visibility = if ($shown) { 'Collapsed' } else { 'Visible' }
    if (!$shown) { $ui.UninstEmpty.Tag = 't:uninst.none'; $ui.UninstEmpty.Text = T 'uninst.none' }
}
function Update-UninstBatch {
    $n = @($script:uninstItems | Where-Object { $_.Check.IsChecked }).Count
    $ui.UninstBatch.Visibility = if ($n) { 'Visible' } else { 'Collapsed' }
    $ui.UninstSelectedText.Text = (T 'uninst.selected') -f $n
}
function Start-UninstLoad {
    $ui.UninstLeft.Visibility = 'Collapsed'
    if ($Screenshot) { Show-Uninst (& $uninstWork); return }
    $ui.UninstList.Children.Clear(); $ui.UninstEmpty.Visibility = 'Visible'; $ui.UninstEmpty.Tag = 't:uninst.loading'; $ui.UninstEmpty.Text = T 'uninst.loading'
    Start-Work $uninstWork @() { param($r) Show-Uninst @($r | ForEach-Object { $_ }) } $null
}

# Uninstall: the program's own uninstaller (its quiet one when wanted and known), or Remove-AppxPackage
function Get-UninstCommand($it) {
    $quiet = [bool]$ui.UninstQuiet.IsChecked
    if ($quiet -and $it.Quiet) { return $it.Quiet }
    # Windows Installer programs: MsiExec /X{code}, silent with /qn
    if ($it.Uninstall -match '(?i)msiexec(\.exe)?\s+/[ix]\s*(\{[0-9A-F-]+\})') { return "MsiExec.exe /X$($Matches[2])" + $(if ($quiet) { ' /qn /norestart' } else { '' }) }
    $it.Uninstall
}
$script:uninstQueue = New-Object System.Collections.Queue
function Start-UninstItem($it, [switch]$NoAsk) {
    if ($script:uninstBusy) { $script:uninstQueue.Enqueue($it); Set-Status ((T 'uninst.queued') -f $it.Name); return }
    if (!$NoAsk) {
        $ask = if ($it.Shared) { (T 'uninst.sharedask') -f $it.Name } else { (T 'uninstall.confirm') -f $it.Name }
        if ([System.Windows.MessageBox]::Show($ask, 'Akati OS Center', 'YesNo', $(if ($it.Shared) { 'Warning' } else { 'Question' })) -ne 'Yes') { return }
    }
    $script:uninstBusy = $true
    $it.Button.IsEnabled = $false; $it.Button.Content = T 'uninstalling'
    Set-Status ((T 'uninst.running') -f $it.Name) $true
    if ($it.Kind -eq 'store') {
        Start-Work { param($pkg) try { Remove-AppxPackage -Package $pkg -ErrorAction Stop; '' } catch { $_.Exception.Message } } @($it.Package) { param($r, $it) Complete-UninstItem $it ([string](Get-LastOutput $r)) } $it
    } else {
        # cmd.exe runs the command line exactly as Apps & features would (quotes and switches included)
        Start-Work { param($command) $p = Start-Process cmd.exe -ArgumentList "/c `"$command`"" -WindowStyle Hidden -PassThru; $p.WaitForExit(); '' } @((Get-UninstCommand $it)) { param($r, $it) Complete-UninstItem $it '' } $it
    }
}
function Complete-UninstItem($it, [string]$err) {
    $script:uninstBusy = $false
    $gone = if ($it.Kind -eq 'store') { !(Get-AppxPackage -Name '*' -ErrorAction SilentlyContinue | Where-Object { $_.PackageFullName -eq $it.Package }) } else { !(Test-Path -LiteralPath $it.Key) }
    if ($err) { Set-Status "$($it.Name): $err" }
    elseif ($gone) { Set-Status ((T 'status.uninstalled') -f $it.Name) }
    else { Set-Status ((T 'uninst.stillthere') -f $it.Name) }
    $it.Button.IsEnabled = $true; $it.Button.Content = T 'uninstall'
    # What it left behind, only when it is gone (a cancelled uninstaller leaves the program as it is)
    if ($gone) {
        $it.Row.Row.Visibility = 'Collapsed'; $it.Check.IsChecked = $false; $it.Gone = $true
        $script:uninstItems = @($script:uninstItems | Where-Object { !$_.Gone })
        Update-UninstBatch
        $left = @(Find-Leftovers $it)
        if ($left.Count) { Show-Leftovers $it $left }
    }
    if ($script:uninstQueue.Count) { Start-UninstItem ($script:uninstQueue.Dequeue()) -NoAsk } else { Update-UninstView }
}
$ui.UninstSelected.Add_Click({
    $chosen = @($script:uninstItems | Where-Object { $_.Check.IsChecked })
    if (!$chosen.Count) { return }
    $names = ($chosen | ForEach-Object { $_.Name }) -join "`n"
    if ([System.Windows.MessageBox]::Show(((T 'uninst.selectedask') -f $chosen.Count, ("`n`n" + $names)), 'Akati OS Center', 'YesNo', 'Question') -ne 'Yes') { return }
    foreach ($it in $chosen) { $it.Check.IsChecked = $false }
    Update-UninstBatch
    $first = $chosen[0]
    foreach ($it in @($chosen | Select-Object -Skip 1)) { $script:uninstQueue.Enqueue($it) }
    Start-UninstItem $first -NoAsk
})

# ---------------------------------------------------------------------------------------------
# Leftovers: only folders and keys named exactly like the program (or Publisher\program), never a top folder
# such as Program Files, never under Windows, never shared registry keys
# ---------------------------------------------------------------------------------------------
function Test-SafeLeftoverPath([string]$path) {
    if (!$path -or $path.Length -lt 8) { return $false }
    $full = try { [IO.Path]::GetFullPath($path).TrimEnd('\') } catch { return $false }
    $roots = @($windir, $env:ProgramFiles, ${env:ProgramFiles(x86)}, $env:ProgramData, $env:APPDATA, $env:LOCALAPPDATA, $env:USERPROFILE, $env:PUBLIC,
               [Environment]::GetFolderPath('CommonStartMenu'), [Environment]::GetFolderPath('StartMenu'), [Environment]::GetFolderPath('Programs'),
               [Environment]::GetFolderPath('CommonPrograms'), [Environment]::GetFolderPath('Desktop'), [Environment]::GetFolderPath('MyDocuments'),
               (Join-Path $env:LOCALAPPDATA 'Programs'), (Join-Path $env:USERPROFILE 'Downloads'), "$env:SystemDrive\") | Where-Object { $_ } | ForEach-Object { $_.TrimEnd('\') }
    if ($roots -contains $full) { return $false }
    if ($full -like "$($windir.TrimEnd('\'))\*") { return $false }
    $leaf = Split-Path $full -Leaf
    if ($leaf.Length -lt 3 -or $leaf -in 'Common Files', 'WindowsApps', 'Microsoft', 'Windows', 'Packages', 'Temp', 'Programs', 'Microsoft Shared') { return $false }
    ($full -split '\\').Count -ge 3
}
function Find-Leftovers($it) {
    $found = New-Object System.Collections.ArrayList
    $add = { param($kind, $path) if (!($found | Where-Object { $_.Path -eq $path })) { [void]$found.Add(@{ Kind = $kind; Path = $path }) } }
    if ($it.Kind -eq 'store') {
        $pkgDir = Join-Path $env:LOCALAPPDATA "Packages\$($it.Family)"
        if ($it.Family -and (Test-Path -LiteralPath $pkgDir)) { & $add 'folder' $pkgDir }
        return , @($found)
    }
    $base = Get-ProgramBaseName $it.Name
    if ($base.Length -lt 3) { return , @() }
    $names = @($base, ($base -replace '\s', '')) | Select-Object -Unique
    $publisher = (($it.Publisher -replace '[,.]?\s*(Inc|LLC|Ltd|GmbH|Corporation|Corp|Co)\.?$', '').Trim())
    # Its install folder, when it is still there
    if ($it.Location -and (Test-Path -LiteralPath $it.Location -PathType Container) -and (Test-SafeLeftoverPath $it.Location)) { & $add 'folder' ($it.Location.TrimEnd('\')) }
    foreach ($root in @($env:ProgramFiles, ${env:ProgramFiles(x86)}, $env:ProgramData, $env:APPDATA, $env:LOCALAPPDATA, (Join-Path $env:LOCALAPPDATA 'Programs')) | Where-Object { $_ }) {
        foreach ($n in $names) {
            foreach ($candidate in @((Join-Path $root $n), $(if ($publisher -and $publisher -ne $n) { Join-Path (Join-Path $root $publisher) $n }))) {
                if ($candidate -and (Test-Path -LiteralPath $candidate -PathType Container) -and (Test-SafeLeftoverPath $candidate)) { & $add 'folder' $candidate }
            }
        }
    }
    # Start menu: a folder named like it, or shortcuts starting with its name whose program is gone
    $shell = New-Object -ComObject WScript.Shell
    foreach ($menu in [Environment]::GetFolderPath('CommonPrograms'), [Environment]::GetFolderPath('Programs')) {
        foreach ($n in $names) {
            $dir = Join-Path $menu $n
            if (Test-Path -LiteralPath $dir -PathType Container) { & $add 'shortcut' $dir }
        }
        foreach ($lnk in @(Get-ChildItem -LiteralPath $menu -Filter '*.lnk' -File -ErrorAction SilentlyContinue | Where-Object { $_.BaseName -like "$base*" })) {
            $target = try { $shell.CreateShortcut($lnk.FullName).TargetPath } catch { $null }
            if (!$target -or !(Test-Path -LiteralPath $target)) { & $add 'shortcut' $lnk.FullName }
        }
    }
    # Registry keys named like it, also under its publisher; never the shared keys of Windows
    $never = 'Microsoft', 'Classes', 'Policies', 'Windows', 'WOW6432Node', 'Clients', 'RegisteredApplications', 'Intel', 'Google', 'Mozilla', 'Wow6432Node'
    foreach ($soft in 'HKCU:\Software', 'HKLM:\SOFTWARE', 'HKLM:\SOFTWARE\WOW6432Node') {
        foreach ($n in $names) {
            if ($n -in $never) { continue }
            foreach ($k in @("$soft\$n", $(if ($publisher -and $publisher -notin $never) { "$soft\$publisher\$n" }))) {
                if ($k -and (Test-Path -LiteralPath $k)) { & $add 'registry' $k }
            }
        }
    }
    # Its own uninstall entry, when the uninstaller left it behind
    if ($it.Key -and (Test-Path -LiteralPath $it.Key)) { & $add 'registry' ($it.Key -replace '^Microsoft\.PowerShell\.Core\\Registry::', '') }
    , @($found)
}
function Show-Leftovers($it, $left) {
    $ui.UninstLeftList.Children.Clear()
    $ui.UninstLeftTitle.Text = (T 'uninst.left.title') -f $it.Name, $left.Count
    foreach ($l in $left) {
        $check = New-Object System.Windows.Controls.CheckBox
        $check.Style = $window.FindResource('Tick'); $check.IsChecked = $true; $check.Tag = $l; $check.Margin = '0,3'
        $text = New-Object System.Windows.Controls.StackPanel
        [void]$text.Children.Add((New-Text (T "uninst.kind.$($l.Kind)") 12 'SemiBold'))
        $p = New-Text ($l.Path -replace '^HKEY_LOCAL_MACHINE', 'HKLM' -replace '^HKEY_CURRENT_USER', 'HKCU') 12; $p.Foreground = $window.FindResource('MutedBrush'); $p.TextTrimming = 'CharacterEllipsis'; $p.TextWrapping = 'NoWrap'
        [void]$text.Children.Add($p)
        $check.Content = $text
        [void]$ui.UninstLeftList.Children.Add($check)
    }
    $ui.UninstLeft.Visibility = 'Visible'
    $ui.UninstLeft.BringIntoView()
}
# "HKCU:\Software\X" or "HKEY_LOCAL_MACHINE\..." -> the name reg.exe takes
function ConvertTo-RegExePath([string]$path) {
    $p = $path -replace '^Microsoft\.PowerShell\.Core\\Registry::', ''
    $p = $p -replace '^HKCU:\\', 'HKCU\' -replace '^HKLM:\\', 'HKLM\' -replace '^HKEY_CURRENT_USER\\', 'HKCU\' -replace '^HKEY_LOCAL_MACHINE\\', 'HKLM\'
    $p
}
$ui.UninstLeftRemove.Add_Click({
    $chosen = @($ui.UninstLeftList.Children | Where-Object { $_.IsChecked } | ForEach-Object { $_.Tag })
    $done = 0; $failed = 0
    foreach ($l in $chosen) {
        try {
            if ($l.Kind -eq 'registry') {
                if (!(Test-Path -LiteralPath $uninstBackupDir)) { New-Item -ItemType Directory -Path $uninstBackupDir -Force | Out-Null }
                $reg = ConvertTo-RegExePath $l.Path
                $file = Join-Path $uninstBackupDir (('{0} {1}.reg' -f (Get-Date).ToString('yyyy-MM-dd HHmmss'), (Split-Path $reg -Leaf)) -replace '[\\/:*?"<>|]', '_')
                & reg.exe export $reg $file /y *> $null
                if ($LASTEXITCODE -ne 0) { throw "reg export $reg" }
                Remove-Item -LiteralPath ("Registry::$reg" -replace '^Registry::HKCU', 'Registry::HKEY_CURRENT_USER' -replace '^Registry::HKLM', 'Registry::HKEY_LOCAL_MACHINE') -Recurse -Force -ErrorAction Stop
            } elseif (Test-Path -LiteralPath $l.Path -PathType Container) {
                [Microsoft.VisualBasic.FileIO.FileSystem]::DeleteDirectory($l.Path, 'OnlyErrorDialogs', 'SendToRecycleBin')
            } elseif (Test-Path -LiteralPath $l.Path) {
                [Microsoft.VisualBasic.FileIO.FileSystem]::DeleteFile($l.Path, 'OnlyErrorDialogs', 'SendToRecycleBin')
            }
            $done++
        } catch { $failed++ }
    }
    $ui.UninstLeft.Visibility = 'Collapsed'
    Set-Status (((T 'uninst.left.done') -f $done) + $(if ($failed) { ' · ' + ((T 'uninst.left.failed') -f $failed) } else { '' }))
})
$ui.UninstLeftKeep.Add_Click({ $ui.UninstLeft.Visibility = 'Collapsed' })
$ui.UninstRefresh.Add_Click({ Start-UninstLoad })
$ui.UninstSearch.Add_TextChanged({ $ui.UninstSearchHint.Visibility = if ($this.Text) { 'Collapsed' } else { 'Visible' }; if ($script:uninstItems) { Update-UninstView } })
foreach ($n in 'UninstShowAll', 'UninstShowPrograms', 'UninstShowStore', 'UninstSortName', 'UninstSortSize', 'UninstSortDate') {
    $ui[$n].Add_Checked({ if ($script:uninstItems) { Update-UninstView } })
}
$ui.UninstQuiet.IsChecked = (Get-RegValue $settingsKey 'UninstallQuiet') -eq 1
$ui.UninstQuiet.Add_Click({ Save-Setting UninstallQuiet ([int][bool]$this.IsChecked) })
