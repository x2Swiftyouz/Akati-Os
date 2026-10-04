<#
.SYNOPSIS
    Pack src\ into dist\AkatiOS_v<version>.apbx (zip, password "malte") and write dist\SHA256SUMS.txt.
.EXAMPLE
    .\build.ps1                 # version read from src\playbook.conf <Version>
    .\build.ps1 -Version 1.2.0  # override version
.NOTES
    Requires 7-Zip (Compress-Archive cannot set a password).
#>
param(
    [string]$Version
)

$ErrorActionPreference = 'Stop'
$root     = $PSScriptRoot
$src      = Join-Path $root 'src'
$dist     = Join-Path $root 'dist'
$password = 'malte'
$conf     = Join-Path $src 'playbook.conf'

if (-not (Test-Path $conf)) { throw "$conf not found" }

# 1. playbook.conf must be valid XML
try { [xml]$xml = Get-Content -LiteralPath $conf -Raw -Encoding UTF8 }
catch { throw "playbook.conf is not valid XML: $($_.Exception.Message)" }

# 2. Version
if (-not $Version) { $Version = $xml.Playbook.Version }
if (-not $Version) { throw 'could not read <Version> from playbook.conf' }

# 3. Warn about text files that lost CRLF line endings
$textExt = '.yml', '.conf', '.ps1', '.psm1', '.psd1', '.cmd', '.bat', '.reg', '.md', '.txt'
$bad = Get-ChildItem -LiteralPath $src -Recurse -File |
    Where-Object { $textExt -contains $_.Extension.ToLower() } |
    Where-Object { [IO.File]::ReadAllText($_.FullName) -match '(?<!\r)\n' }
foreach ($f in $bad) { Write-Warning "LF line endings in $($f.FullName.Substring($root.Length + 1))" }

# 4. Find 7-Zip
$7z = (Get-Command 7z.exe -ErrorAction SilentlyContinue).Source
if (-not $7z) {
    $7z = @("$env:ProgramFiles\7-Zip\7z.exe", "${env:ProgramFiles(x86)}\7-Zip\7z.exe") |
        Where-Object { $_ -and (Test-Path $_) } | Select-Object -First 1
}
if (-not $7z) { throw '7-Zip not found. Install it: winget install 7zip.7zip' }

# 5. Pack (contents of src\ at the archive root)
New-Item -ItemType Directory -Force -Path $dist | Out-Null
$out = Join-Path $dist "AkatiOS_v$Version.apbx"
if (Test-Path $out) { Remove-Item $out -Force }
Push-Location $src
try {
    & $7z a -tzip -mx1 "-p$password" -y $out '.\*' | Out-Null
    if ($LASTEXITCODE -ne 0) { throw "7-Zip failed with exit code $LASTEXITCODE" }
}
finally { Pop-Location }

# 6. Checksums (sha256sum format, covers every .apbx in dist\)
$lines = Get-ChildItem -LiteralPath $dist -Filter '*.apbx' | Sort-Object Name | ForEach-Object {
    '{0}  {1}' -f (Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash.ToLower(), $_.Name
}
[IO.File]::WriteAllText((Join-Path $dist 'SHA256SUMS.txt'), (($lines -join "`n") + "`n"))

Write-Host "built: dist\AkatiOS_v$Version.apbx"
Get-Content (Join-Path $dist 'SHA256SUMS.txt')
