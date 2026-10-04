param (
    [Parameter(Mandatory)][string]$App
)

# Akati OS: installs one gaming app (used during setup and by AtlasDesktop\Akati OS\Install Gaming Apps).
# Uses WinGet first (installer hashes are verified by WinGet).
# Falls back to the official direct download where one exists.

$apps = @{
    Steam     = @{ Id = 'Valve.Steam';                  Url = 'https://cdn.akamai.steamstatic.com/client/installer/SteamSetup.exe'; Args = '/S'
                   Installed = { Test-Path "${env:ProgramFiles(x86)}\Steam\steam.exe" } }
    Discord   = @{ Id = 'Discord.Discord';              Url = 'https://discord.com/api/downloads/distributions/app/installers/latest?channel=stable&platform=win&arch=x64'; Args = '-s'
                   Installed = { Test-Path "$env:LOCALAPPDATA\Discord\Update.exe" } }
    Epic      = @{ Id = 'EpicGames.EpicGamesLauncher' }
    EA        = @{ Id = 'ElectronicArts.EADesktop' }
    Ubisoft   = @{ Id = 'Ubisoft.Connect' }
    BattleNet = @{ Id = 'Blizzard.BattleNet'; Extra = @('--location', "$env:ProgramFiles\Battle.net") }
    OBS       = @{ Id = 'OBSProject.OBSStudio' }
}

if (!$apps.ContainsKey($App)) { Write-Error "Unknown app: $App"; exit 0 }
$info = $apps[$App]

function Test-Installed {
    if ($info.Installed) { return [bool](& $info.Installed) }
    if (Get-Command winget -EA 0) {
        & winget list --id $info.Id --exact --accept-source-agreements --disable-interactivity *> $null
        return $LASTEXITCODE -eq 0
    }
    return $false
}

if (Test-Installed) { Write-Output "$App is already installed."; exit 0 }

# Try WinGet
if (Get-Command winget -EA 0) {
    Write-Output "Installing $App with WinGet..."
    $wingetArgs = @('install', '--id', $info.Id, '--exact', '--silent', '--accept-package-agreements', '--accept-source-agreements', '--disable-interactivity')
    if ($info.Extra) { $wingetArgs += $info.Extra }
    $proc = Start-Process winget -ArgumentList $wingetArgs -WindowStyle Hidden -PassThru
    # Read Handle now, otherwise ExitCode is empty after the process exits (PowerShell quirk)
    $null = $proc.Handle
    $finished = $proc.WaitForExit(600000)
    if ($finished -and $proc.ExitCode -eq 0) { Write-Output "$App installed."; exit 0 }
    # Some installers make WinGet return an error even though the app was installed
    if (Test-Installed) { Write-Output "$App installed."; exit 0 }
    Write-Warning "WinGet could not install $App (exit code $($proc.ExitCode))."
}

# Fallback: official direct download
if (!$info.Url) { Write-Warning "$App skipped. Install it later from its official website."; exit 0 }

$timeouts = @("--connect-timeout", "10", "--retry", "5", "--retry-delay", "0", "--retry-all-errors")
$tempDir = Join-Path -Path $env:TEMP -ChildPath ([guid]::NewGuid().ToString())
New-Item -ItemType Directory -Path $tempDir -Force | Out-Null
$file = "$tempDir\$App-Setup.exe"

Write-Output "Downloading $App from the official site..."
& curl.exe -LSs $info.Url -o $file $timeouts
if ($? -and (Test-Path $file)) {
    $proc = Start-Process -FilePath $file -ArgumentList $info.Args -WindowStyle Hidden -PassThru
    $null = $proc.Handle
    # Max 5 minutes so a stuck installer does not block setup
    if (!$proc.WaitForExit(300000)) { Write-Warning "$App installer timed out." }
} else {
    Write-Warning "Downloading $App failed. Install it later from its official website."
}
Remove-Item -Path $tempDir -Force -Recurse -EA 0
exit 0
