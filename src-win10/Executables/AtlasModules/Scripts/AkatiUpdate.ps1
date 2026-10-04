# Akati OS update checker: compares the installed version with the latest GitHub release.
# It only reads public release information and opens the release page if you agree. Nothing is downloaded.

$repo = 'x2Swiftyouz/Akati-Os'
$key = 'HKLM:\SOFTWARE\AkatiOS'
$installed = (Get-ItemProperty -Path $key -Name Version -ErrorAction SilentlyContinue).Version
$edition = (Get-ItemProperty -Path $key -Name Edition -ErrorAction SilentlyContinue).Edition

Write-Host 'Akati OS update checker' -ForegroundColor Magenta
Write-Host ''
if (!$installed) {
    Write-Host 'Could not find the installed Akati OS version (HKLM\SOFTWARE\AkatiOS).' -ForegroundColor Yellow
    $installed = 'v0.0.0'
}
Write-Host "Installed: Akati OS $installed ($edition)"

try {
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    $release = Invoke-RestMethod -Uri "https://api.github.com/repos/$repo/releases/latest" -Headers @{ 'User-Agent' = 'AkatiOS-UpdateCheck' } -TimeoutSec 20
} catch {
    Write-Host "Could not reach GitHub: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "Check manually: https://github.com/$repo/releases"
    exit 1
}

$latest = $release.tag_name
Write-Host "Latest:    Akati OS $latest"
Write-Host ''

$isNewer = $false; $isAhead = $false
try {
    $isNewer = [version]($latest.TrimStart('v')) -gt [version]($installed.TrimStart('v'))
    $isAhead = [version]($installed.TrimStart('v')) -gt [version]($latest.TrimStart('v'))
} catch {
    $isNewer = $latest -ne $installed
}

if ($isAhead) {
    Write-Host 'Your version is newer than the latest release (test build).' -ForegroundColor Green
    exit 0
}
if (!$isNewer) {
    Write-Host 'You have the latest version.' -ForegroundColor Green
    exit 0
}

Write-Host "A new version is available: $latest" -ForegroundColor Green
Write-Host 'A new version needs a fresh Windows install with the new .apbx file. Back up your files first.'
if ($edition -eq 'Windows 10') { Write-Host 'Download the AkatiOS-Win10_*.apbx file.' } else { Write-Host 'Download the AkatiOS_*.apbx file (not Win10).' }
$open = Read-Host 'Open the release page? (Y/N)'
if ($open -match '^[Yy]') { Start-Process $release.html_url }
