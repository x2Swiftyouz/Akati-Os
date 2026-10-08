<#
.SYNOPSIS
    Checks Akati OS Center without running it (CI, and locally with PowerShell 7 on any OS):
    - English and Thai have the same text keys, and no key is empty
    - every T 'key' in the scripts and every Tag="t:key" in the XAML exists
    - every $ui.Name used in AkatiCenter.ps1 is an x:Name in AkatiCenter.xaml
    - every gaming app of Akati OS Center can be installed by GAMEAPPS.ps1
    - src and src-win10 have the same Akati OS Center files
.EXAMPLE
    pwsh tools/test-center.ps1
#>
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$center = Join-Path $root 'src/Executables/AtlasModules/AkatiCenter'
$failures = New-Object System.Collections.Generic.List[string]
function Fail([string]$message) { $failures.Add($message); Write-Host "FAIL: $message" }

# Strings
. (Join-Path $center 'AkatiCenter.strings.ps1')
$en = $strings.en; $th = $strings.th
foreach ($k in $en.Keys) { if (!$th.ContainsKey($k)) { Fail "Thai text missing: $k" } elseif (!$th[$k]) { Fail "Thai text empty: $k" } }
foreach ($k in $th.Keys) { if (!$en.ContainsKey($k)) { Fail "English text missing: $k" } }
foreach ($k in $en.Keys) { if (!$en[$k]) { Fail "English text empty: $k" } }
# {0} placeholders must match, otherwise -f fails in one language
foreach ($k in $en.Keys) {
    if (!$th.ContainsKey($k)) { continue }
    $a = ([regex]::Matches($en[$k], '\{\d\}') | ForEach-Object { $_.Value } | Sort-Object -Unique) -join ','
    $b = ([regex]::Matches($th[$k], '\{\d\}') | ForEach-Object { $_.Value } | Sort-Object -Unique) -join ','
    if ($a -ne $b) { Fail "Placeholders differ in '$k': en '$a', th '$b'" }
}

# Keys used by the code and the window
$ps1 = Get-Content -Raw -Encoding UTF8 (Join-Path $center 'AkatiCenter.ps1')
$xaml = Get-Content -Raw -Encoding UTF8 (Join-Path $center 'AkatiCenter.xaml')
foreach ($m in [regex]::Matches($ps1, "\bT '([\w.]+)'")) { if (!$en.ContainsKey($m.Groups[1].Value)) { Fail "T '$($m.Groups[1].Value)' has no text" } }
foreach ($m in [regex]::Matches($ps1 + $xaml, '[''"]t:([\w.]+)')) {
    $key = $m.Groups[1].Value
    if ($key -match '\.$') { continue }   # built in code, for example "t:tw.$($tw.Key)"
    if (!$en.ContainsKey($key)) { Fail "Tag t:$key has no text" }
}

# Text inside a ControlTemplate is not in the logical tree, so Set-Language never translates it
foreach ($m in [regex]::Matches($xaml, '(?s)<ControlTemplate\b[^>]*>.*?</ControlTemplate>')) {
    foreach ($t in [regex]::Matches($m.Value, 'Tag="t:([\w.]+)"')) { Fail "Tag t:$($t.Groups[1].Value) is inside a ControlTemplate (not translated)" }
}

# Names of the window elements
$names = @([regex]::Matches($xaml, 'x:Name="(\w+)"') | ForEach-Object { $_.Groups[1].Value })
$used = [regex]::Matches($ps1, '\$ui\.(\w+)') | ForEach-Object { $_.Groups[1].Value } | Sort-Object -Unique
# Names inside control templates (Bd, PART_Track) repeat by design; names the code uses must be unique
$dupes = $names | Group-Object | Where-Object { $_.Count -gt 1 -and $used -contains $_.Name }
foreach ($d in $dupes) { Fail "x:Name used twice: $($d.Name)" }
foreach ($u in $used) { if ($names -notcontains $u) { Fail "`$ui.$u is not an x:Name in AkatiCenter.xaml" } }

# Gaming apps: every Key of $apps in AkatiCenter.ps1 is in the $apps table of GAMEAPPS.ps1
$gameApps = Get-Content -Raw -Encoding UTF8 (Join-Path $root 'src/Executables/AtlasModules/Scripts/GAMEAPPS.ps1')
$appKeys = [regex]::Matches($ps1, "@\{ Key = '(\w+)';\s+Cat = ") | ForEach-Object { $_.Groups[1].Value }
if (!$appKeys) { Fail 'No gaming apps found in AkatiCenter.ps1' }
foreach ($k in $appKeys) { if ($gameApps -notmatch "(?m)^\s+$k\s+= @\{") { Fail "GAMEAPPS.ps1 cannot install '$k'" } }

# Both playbooks ship the same Akati OS Center
foreach ($f in Get-ChildItem -LiteralPath $center -File) {
    $other = Join-Path $root "src-win10/Executables/AtlasModules/AkatiCenter/$($f.Name)"
    if (!(Test-Path -LiteralPath $other)) { Fail "src-win10 is missing AkatiCenter/$($f.Name)"; continue }
    if ((Get-FileHash -LiteralPath $f.FullName).Hash -ne (Get-FileHash -LiteralPath $other).Hash) { Fail "AkatiCenter/$($f.Name) differs between src and src-win10" }
}

Write-Host ("Checked {0} text keys, {1} window names, {2} gaming apps" -f $en.Count, $names.Count, @($appKeys).Count)
if ($failures.Count) { Write-Host "$($failures.Count) problem(s)"; exit 1 }
Write-Host 'All checks passed'
