<#
.SYNOPSIS
    Pack each playbook into dist\ (zip, password "malte") and write dist\SHA256SUMS.txt:
      src\        -> dist\AkatiOS_v<version>.apbx        (Windows 11)
      src-win10\  -> dist\AkatiOS-Win10_v<version>.apbx  (Windows 10)
    The version is read from each playbook.conf <Version>.
.EXAMPLE
    .\build.ps1
.NOTES
    Requires 7-Zip (Compress-Archive cannot set a password).
#>

$ErrorActionPreference = 'Stop'
$root     = $PSScriptRoot
$dist     = Join-Path $root 'dist'
$password = 'malte'
$variants = @(
    @{ Src = 'src';       Prefix = 'AkatiOS' },
    @{ Src = 'src-win10'; Prefix = 'AkatiOS-Win10' }
)

# Find 7-Zip
$7z = (Get-Command 7z.exe -ErrorAction SilentlyContinue).Source
if (-not $7z) {
    $7z = @("$env:ProgramFiles\7-Zip\7z.exe", "${env:ProgramFiles(x86)}\7-Zip\7z.exe") |
        Where-Object { $_ -and (Test-Path $_) } | Select-Object -First 1
}
if (-not $7z) { throw '7-Zip not found. Install it: winget install 7zip.7zip' }

New-Item -ItemType Directory -Force -Path $dist | Out-Null
Get-ChildItem -LiteralPath $dist -Filter '*.apbx' | Remove-Item -Force
$sums = Join-Path $dist 'SHA256SUMS.txt'
if (Test-Path $sums) { Remove-Item $sums -Force }
$lines = @()

function Build-Playbook([string]$srcName, [string]$prefix) {
    $src  = Join-Path $root $srcName
    $conf = Join-Path $src 'playbook.conf'
    if (-not (Test-Path $conf)) { throw "$conf not found" }

    # 1. playbook.conf must be valid XML
    try { [xml]$xml = Get-Content -LiteralPath $conf -Raw -Encoding UTF8 }
    catch { throw "$srcName\playbook.conf is not valid XML: $($_.Exception.Message)" }

    # Same checks as tools/check-playbook.py: AME Wizard refuses a RadioPage/CheckboxPage with more than 3 options
    $errors = @()
    $seen = @{}
    foreach ($tag in 'RadioPage', 'CheckboxPage', 'RadioImagePage') {
        foreach ($page in $xml.SelectNodes("//$tag")) {
            $desc = "$tag `"$($page.GetAttribute('Description'))`""
            $opts = @($page.SelectNodes('Options/*'))
            if ($opts.Count -eq 0) { $errors += "${desc}: no options" }
            if ($tag -ne 'RadioImagePage' -and $opts.Count -gt 3) { $errors += "${desc}: $($opts.Count) options, max is 3" }
            $names = @($opts | ForEach-Object { $n = $_.SelectSingleNode('Name'); if ($n) { $n.InnerText } else { '' } })
            foreach ($n in $names) {
                if (-not $n) { $errors += "${desc}: option without <Name>" }
                elseif ($seen.ContainsKey($n)) { $errors += "option name `"$n`" is used twice" }
                else { $seen[$n] = $true }
            }
            $default = $page.GetAttribute('DefaultOption')
            if ($default -and $names -notcontains $default) {
                $errors += "${desc}: DefaultOption `"$default`" is not one of its options"
            }
        }
    }
    if ($errors) { $errors | ForEach-Object { Write-Host "error: $_" -ForegroundColor Red }; throw "$srcName\playbook.conf check failed" }
    Write-Host "${srcName}\playbook.conf: OK ($($seen.Count) options)"

    # 2. Version
    $version = $xml.Playbook.Version
    if (-not $version) { throw "could not read <Version> from $srcName\playbook.conf" }

    # 3. Warn about text files that lost CRLF line endings
    $textExt = '.yml', '.conf', '.ps1', '.psm1', '.psd1', '.cmd', '.bat', '.reg', '.md', '.txt'
    $bad = Get-ChildItem -LiteralPath $src -Recurse -File |
        Where-Object { $textExt -contains $_.Extension.ToLower() } |
        Where-Object { [IO.File]::ReadAllText($_.FullName) -match '(?<!\r)\n' }
    foreach ($f in $bad) { Write-Warning "LF line endings in $($f.FullName.Substring($root.Length + 1))" }

    # 4. Pack (contents of the source folder at the archive root)
    $out = Join-Path $dist "${prefix}_v$version.apbx"
    Push-Location $src
    try {
        & $7z a -tzip -mx1 "-p$password" -y $out '.\*' | Out-Null
        if ($LASTEXITCODE -ne 0) { throw "7-Zip failed with exit code $LASTEXITCODE" }
    }
    finally { Pop-Location }

    Write-Host "built: dist\${prefix}_v$version.apbx"
    return $out
}

foreach ($v in $variants) {
    $out = Build-Playbook $v.Src $v.Prefix
    # 5. Checksum (sha256sum format)
    $hash = (Get-FileHash -LiteralPath $out -Algorithm SHA256).Hash.ToLower()
    $lines += '{0}  {1}' -f $hash, (Split-Path $out -Leaf)
}
[IO.File]::WriteAllText($sums, (($lines -join "`n") + "`n"))
Get-Content $sums
