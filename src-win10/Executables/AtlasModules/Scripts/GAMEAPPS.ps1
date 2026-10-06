param (
    [Parameter(Mandatory)][string]$App,
    # Do not install now: register a scheduled task that runs this script as the signed-in user
    # at their next sign-in (used by setup for Discord). Needs admin rights.
    [switch]$AtSignIn,
    # Set by that scheduled task
    [switch]$FromTask
)

# Akati OS: installs one gaming app (used by Akati OS Center > Gaming apps).
# Uses WinGet first (installer hashes are verified by WinGet).
# Falls back to the official direct download where one exists.

# Log for troubleshooting: %LOCALAPPDATA%\AkatiOS\Logs\GAMEAPPS-<App>.log
try {
    $logDir = Join-Path $env:LOCALAPPDATA 'AkatiOS\Logs'
    New-Item -ItemType Directory -Path $logDir -Force | Out-Null
    # Not elevated (the user part of the Discord install, started by the elevated run): its own log, because
    # the elevated run keeps GAMEAPPS-<App>.log open while it waits
    $elevated = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    $logName = if ($elevated) { "GAMEAPPS-$App.log" } else { "GAMEAPPS-$App-user.log" }
    Start-Transcript -Path (Join-Path $logDir $logName) -Append | Out-Null
} catch {}

$apps = @{
    Steam     = @{ Id = 'Valve.Steam';                  Url = 'https://cdn.akamai.steamstatic.com/client/installer/SteamSetup.exe'; Args = '/S'
                   Installed = { Test-Path "${env:ProgramFiles(x86)}\Steam\steam.exe" } }
    # Discord: no silent switch and no WinGet (which installs it silently). After a silent install ("-s"), the
    # first start of Discord quits at once without moving the install to its new updater, and every later
    # start fails with "Attempt to install host that is currently running". The normal install shows a small
    # Discord window and opens Discord when it is done.
    Discord   = @{ Id = 'Discord.Discord';              Url = 'https://discord.com/api/downloads/distributions/app/installers/latest?channel=stable&platform=win&arch=x64'; NoWinget = $true
                   # Update.exe alone is not enough: an interrupted install leaves it without the app
                   Installed = { (Test-Path "$env:LOCALAPPDATA\Discord\packages\RELEASES") -and (Test-Path "$env:LOCALAPPDATA\Discord\app-*\Discord.exe") } }
    Epic      = @{ Id = 'EpicGames.EpicGamesLauncher' }
    EA        = @{ Id = 'ElectronicArts.EADesktop' }
    Ubisoft   = @{ Id = 'Ubisoft.Connect' }
    BattleNet = @{ Id = 'Blizzard.BattleNet'; Extra = @('--location', "$env:ProgramFiles\Battle.net") }
    OBS       = @{ Id = 'OBSProject.OBSStudio' }
    # Riot: WinGet only has full game packages, so the official VALORANT (Asia Pacific) installer from Riot is
    # used. It has no silent switch: its window opens, the user clicks Install, and it installs Riot Client
    # and VALORANT (League of Legends and TFT are added from Riot Client).
    Riot      = @{ Id = 'RiotGames.Valorant.AP'; Url = 'https://valorant.secure.dyn.riotcdn.net/channels/public/x/installer/current/live.live.ap.exe'; NoWinget = $true
                   Window = $true; Signer = 'Riot Games'
                   Installed = { Test-Path "$env:SystemDrive\Riot Games\Riot Client\RiotClientServices.exe" } }
    GOG       = @{ Id = 'GOG.Galaxy';             Installed = { Test-Path "${env:ProgramFiles(x86)}\GOG Galaxy\GalaxyClient.exe" } }
    Rockstar  = @{ Id = 'RockstarGames.Launcher'; Installed = { Test-Path "$env:ProgramFiles\Rockstar Games\Launcher\Launcher.exe" } }
    Afterburner = @{ Id = 'Guru3D.Afterburner';   Installed = { Test-Path "${env:ProgramFiles(x86)}\MSI Afterburner\MSIAfterburner.exe" } }
}

if (!$apps.ContainsKey($App)) { Write-Error "Unknown app: $App"; exit 0 }
$info = $apps[$App]

# Progress for Akati OS Center: "<stage>|<percent>" in %LOCALAPPDATA%\AkatiOS\Logs\GAMEAPPS-<App>.progress
# (stage: winget, download, install, user, finish; percent is -1 when unknown)
$progressFile = Join-Path $env:LOCALAPPDATA "AkatiOS\Logs\GAMEAPPS-$App.progress"
function Set-Progress([string]$stage, [int]$percent = -1) {
    try { [IO.File]::WriteAllText($progressFile, "$stage|$percent") } catch {}
}

# Downloads with curl.exe and reports the percentage while it runs
function Get-Download([string]$url, [string]$out, [string[]]$curlArgs) {
    $length = 0
    try {
        $head = & curl.exe -sIL $url --connect-timeout 10 2>$null
        $m = [regex]::Matches(($head -join "`n"), '(?im)^content-length:\s*(\d+)')
        if ($m.Count) { $length = [double]$m[$m.Count - 1].Groups[1].Value }
    } catch {}
    # A tiny size is the length of a redirect or error page, not of the installer: percent unknown
    if ($length -lt 100KB) { $length = 0 }
    Set-Progress download $(if ($length -gt 0) { 0 } else { -1 })
    $p = Start-Process curl.exe -ArgumentList (@('-LSs', "`"$url`"", '-o', "`"$out`"") + $curlArgs) -WindowStyle Hidden -PassThru
    $null = $p.Handle
    while (!$p.HasExited) {
        if ($length -gt 0 -and (Test-Path $out)) {
            # Get-Item shows the size NTFS keeps in the folder, which stays 0 until curl closes the file.
            # Opening the file (read only, shared with curl) gives the real size while it downloads.
            $size = 0
            try {
                $fs = [IO.File]::Open($out, 'Open', 'Read', 'ReadWrite, Delete')
                $size = $fs.Length
                $fs.Close()
            } catch {}
            # Bigger than announced: the size was wrong, show the download without a percentage
            if ($size -gt $length) { $length = 0; Set-Progress download } else { Set-Progress download ([int](100 * $size / $length)) }
        }
        Start-Sleep -Milliseconds 500
    }
    return ($p.ExitCode -eq 0 -and (Test-Path $out))
}

function Test-Installed {
    if ($info.Installed) { return [bool](& $info.Installed) }
    if (Get-Command winget -EA 0) {
        & winget list --id $info.Id --exact --source winget --accept-source-agreements --disable-interactivity *> $null
        return $LASTEXITCODE -eq 0
    }
    return $false
}

function Test-Elevated {
    ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

# Fallback only: if Discord had to be installed elevated, close the copy it starts by itself.
# Never as the user: Discord installs and updates itself after the installer exits, and stopping
# Update.exe then leaves Discord half installed (no shortcut, does not start).
function Stop-AutoStartedApp {
    if ($App -eq 'Discord' -and (Test-Elevated)) {
        Start-Sleep -Seconds 5
        Get-Process -Name 'Discord', 'Update' -ErrorAction SilentlyContinue |
            Where-Object { $_.Path -like "$env:LOCALAPPDATA\Discord\*" } | Stop-Process -Force -ErrorAction SilentlyContinue
    }
}

if ($AtSignIn) {
    # The user who is signed in on the console (setup may run this script in another context)
    $user = (Get-CimInstance -ClassName Win32_ComputerSystem -ErrorAction SilentlyContinue).UserName
    if (!$user) { $user = "$env:USERDOMAIN\$env:USERNAME" }
    $task = "AkatiOS Install $App at sign-in"
    try {
        $action = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$PSCommandPath`" -App $App -FromTask"
        $trigger = New-ScheduledTaskTrigger -AtLogOn -User $user
        $trigger.Delay = 'PT2M'
        $principal = New-ScheduledTaskPrincipal -UserId $user -LogonType Interactive -RunLevel Limited
        $settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -ExecutionTimeLimit (New-TimeSpan -Minutes 30)
        # The task must not remove itself: removing a running task stops everything it started, including
        # Discord's first update, and Discord then fails with "Attempt to install host that is currently
        # running". So Windows deletes the task when it expires after 7 days.
        try {
            $trigger.EndBoundary = (Get-Date).AddDays(7).ToString('s')
            $settings.DeleteExpiredTaskAfter = 'PT0S'
            Register-ScheduledTask -TaskName $task -Action $action -Trigger $trigger -Principal $principal -Settings $settings -Force -ErrorAction Stop | Out-Null
        } catch {
            Write-Warning "Registering the task with an expiry date failed ($($_.Exception.Message)), registering it without."
            $trigger = New-ScheduledTaskTrigger -AtLogOn -User $user
            $trigger.Delay = 'PT2M'
            $settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -ExecutionTimeLimit (New-TimeSpan -Minutes 30)
            Register-ScheduledTask -TaskName $task -Action $action -Trigger $trigger -Principal $principal -Settings $settings -Force -ErrorAction Stop | Out-Null
        }
        # The sign-in trigger alone did not always start the task, so RunOnce also starts it at the next
        # sign-in. schtasks.exe only starts the task and exits; the install itself runs in the task.
        Set-ItemProperty -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\RunOnce' -Name "AkatiOS Install $App" -Value "schtasks.exe /run /tn `"$task`"" -Force
        Write-Output "$App will be installed for $user after the next sign-in (scheduled task '$task')."
    } catch {
        Write-Warning "Could not register the scheduled task for ${App}: $($_.Exception.Message)"
    }

    # Download the installer now, during setup, so the install at sign-in takes seconds instead of minutes.
    # Users may delete it (the sign-in install removes it when done).
    if ($info.Url) {
        $cacheDir = Join-Path $env:ProgramData 'AkatiOS\Installers'
        New-Item -ItemType Directory -Path $cacheDir -Force | Out-Null
        & icacls.exe $cacheDir /grant '*S-1-5-32-545:(OI)(CI)M' *> $null
        & curl.exe -LSs $info.Url -o (Join-Path $cacheDir "$App-Setup.exe") --connect-timeout 10 --retry 3 --retry-all-errors
        if ($?) { Write-Output "Downloaded the $App installer for the sign-in install." }
        else { Write-Warning "Could not download the $App installer now, it is downloaded at sign-in instead." }
    }
    exit 0
}

# Started by the sign-in task: remember that the app was installed, so the task does nothing at later
# sign-ins and does not install it again if the user removes it. The task is not removed here (see -AtSignIn).
$doneKey = 'HKCU:\Software\AkatiOS\InstalledAtSignIn'
function Remove-SignInTask {
    if (!$FromTask -or !(Test-Installed)) { return }
    New-Item -Path $doneKey -Force -ErrorAction SilentlyContinue | Out-Null
    Set-ItemProperty -Path $doneKey -Name $App -Value 1 -Type DWord -ErrorAction SilentlyContinue
}
if ($FromTask -and (Get-ItemProperty -Path $doneKey -Name $App -ErrorAction SilentlyContinue)) { exit 0 }
# Let the sign-in finish first (programs started right at sign-in were stopped before)
if ($FromTask) { Start-Sleep -Seconds 5 }

if (Test-Installed) { Write-Output "$App is already installed."; Remove-SignInTask; exit 0 }

# Started by the sign-in task: tell the user what is happening (notification at the bottom right)
if ($FromTask) {
    try {
        Add-Type -AssemblyName System.Windows.Forms, System.Drawing
        $script:note = New-Object System.Windows.Forms.NotifyIcon
        $script:note.Icon = [System.Drawing.SystemIcons]::Information
        $script:note.Text = 'Akati OS'
        $script:note.Visible = $true
        $script:note.ShowBalloonTip(20000, 'Akati OS', "Installing $App. It opens by itself when it is ready.", 'Info')
        # Remove the tray icon when this script exits
        Register-EngineEvent -SourceIdentifier PowerShell.Exiting -Action { $script:note.Dispose() } | Out-Null
    } catch {}
}

# Discord installs itself after its installer exits (Update.exe). This script must not exit before
# that is done: started at sign-in (RunOnce) from a hidden window, Update.exe stops when this script
# exits and leaves Discord half installed. So wait until Discord is installed and its setup has ended.
function Wait-DiscordSetup {
    if ($App -ne 'Discord') { return }
    Set-Progress finish
    $deadline = (Get-Date).AddMinutes(5)
    do {
        Start-Sleep -Seconds 3
        # Discord-Setup: the installer as this script saves it; DiscordSetup: its name from discord.com
        $busy = Get-Process -Name 'Update', 'DiscordSetup', 'Discord-Setup' -ErrorAction SilentlyContinue |
            Where-Object { $_.Name -like 'Discord*Setup' -or $_.Path -like "$env:LOCALAPPDATA\Discord\*" -or $_.Path -like "$env:LOCALAPPDATA\SquirrelTemp\*" }
    } while ((!(Test-Installed) -or $busy) -and (Get-Date) -lt $deadline)
    # Give Discord a moment to create its shortcuts
    Start-Sleep -Seconds 10
}

# Discord installs per user. Installed from an elevated process (setup, Akati OS Center), the user's own
# Discord later fails with "Attempt to install host that is currently running". So when elevated, run
# this script again as the signed-in user without admin rights, through a one-time scheduled task.
if ($App -eq 'Discord' -and (Test-Elevated)) {
    $task = 'AkatiOS Install Discord'
    try {
        $action = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$PSCommandPath`" -App Discord"
        $principal = New-ScheduledTaskPrincipal -UserId "$env:USERDOMAIN\$env:USERNAME" -LogonType Interactive -RunLevel Limited
        Register-ScheduledTask -TaskName $task -Action $action -Principal $principal -Force | Out-Null
        Write-Output "Installing $App as $env:USERNAME (without admin rights)..."
        Set-Progress user
        Start-ScheduledTask -TaskName $task
        Start-Sleep -Seconds 3
        $deadline = (Get-Date).AddMinutes(10)
        while ((Get-ScheduledTask -TaskName $task).State -eq 'Running' -and (Get-Date) -lt $deadline) { Start-Sleep -Seconds 2 }
        Unregister-ScheduledTask -TaskName $task -Confirm:$false -ErrorAction SilentlyContinue
        if (Test-Installed) { Write-Output "$App installed."; exit 0 }
        Write-Warning "$App was not installed as the user, trying again as administrator."
    } catch {
        Unregister-ScheduledTask -TaskName $task -Confirm:$false -ErrorAction SilentlyContinue
        Write-Warning "Could not start the user install of ${App}: $($_.Exception.Message)"
    }
}

# A half-installed Discord (only Update.exe) cannot be repaired by its installer, so remove it first
if ($App -eq 'Discord' -and (Test-Path "$env:LOCALAPPDATA\Discord") -and !(Get-Process -Name 'Discord' -ErrorAction SilentlyContinue)) {
    Remove-Item -Path "$env:LOCALAPPDATA\Discord" -Recurse -Force -ErrorAction SilentlyContinue
}

# Runs an installer with the app's switches (hidden, silent), or without any (visible) when it has none
function Start-Installer([string]$file) {
    if ($info.Window) { Set-Progress window } else { Set-Progress install }
    if ($info.Args) { Start-Process -FilePath $file -ArgumentList $info.Args -WindowStyle Hidden -PassThru }
    else { Start-Process -FilePath $file -PassThru }
}

# Started by the sign-in task: use the installer downloaded during setup, if it is signed by Discord
$cached = Join-Path $env:ProgramData "AkatiOS\Installers\$App-Setup.exe"
if ($FromTask -and $info.Url -and (Test-Path $cached)) {
    $sig = Get-AuthenticodeSignature -FilePath $cached
    if ($sig.Status -eq 'Valid' -and $sig.SignerCertificate.Subject -like "*$App*") {
        Write-Output "Installing $App with the installer downloaded during setup..."
        $proc = Start-Installer $cached
        $null = $proc.Handle
        if ($proc.WaitForExit(300000)) { Write-Output "$App installer exit code: $($proc.ExitCode)" } else { Write-Warning "$App installer timed out." }
        Wait-DiscordSetup
    } else {
        Write-Warning "The $App installer downloaded during setup is not signed by $App ($($sig.Status)), not using it."
    }
    Remove-Item -Path $cached -Force -ErrorAction SilentlyContinue
    if (Test-Installed) { Write-Output "$App installed."; Remove-SignInTask; exit 0 }
}

# Try WinGet
if (!$info.NoWinget -and (Get-Command winget -EA 0)) {
    Write-Output "Installing $App with WinGet..."
    Set-Progress winget
    # --source winget: the apps are in the WinGet community repository, so the Microsoft Store is not needed
    $wingetArgs = @('install', '--id', $info.Id, '--exact', '--source', 'winget', '--silent', '--accept-package-agreements', '--accept-source-agreements', '--disable-interactivity')
    if ($info.Extra) { $wingetArgs += $info.Extra }
    $proc = Start-Process winget -ArgumentList $wingetArgs -WindowStyle Hidden -PassThru
    # Read Handle now, otherwise ExitCode is empty after the process exits (PowerShell quirk)
    $null = $proc.Handle
    $finished = $proc.WaitForExit(600000)
    Wait-DiscordSetup
    if ($finished -and $proc.ExitCode -eq 0) { Stop-AutoStartedApp; Write-Output "$App installed."; Remove-SignInTask; exit 0 }
    # Some installers make WinGet return an error even though the app was installed
    if (Test-Installed) { Stop-AutoStartedApp; Write-Output "$App installed."; Remove-SignInTask; exit 0 }
    Write-Warning "WinGet could not install $App (exit code $($proc.ExitCode))."
}

# Fallback: official direct download
if (!$info.Url) { Write-Warning "$App skipped. Install it later from its official website."; exit 0 }

$timeouts = @("--connect-timeout", "10", "--retry", "5", "--retry-delay", "0", "--retry-all-errors")
$tempDir = Join-Path -Path $env:TEMP -ChildPath ([guid]::NewGuid().ToString())
New-Item -ItemType Directory -Path $tempDir -Force | Out-Null
$file = "$tempDir\$App-Setup.exe"

Write-Output "Downloading $App from the official site..."
if (Get-Download $info.Url $file $timeouts) {
    # Run it only when it is signed by the app's publisher (for the apps that name one)
    if ($info.Signer) {
        $sig = Get-AuthenticodeSignature -FilePath $file
        if ($sig.Status -ne 'Valid' -or $sig.SignerCertificate.Subject -notlike "*$($info.Signer)*") {
            Write-Warning "The downloaded $App installer is not signed by $($info.Signer) ($($sig.Status)), not running it."
            Remove-Item -Path $tempDir -Force -Recurse -EA 0
            exit 0
        }
    }
    $proc = Start-Installer $file
    $null = $proc.Handle
    # Max 5 minutes so a stuck installer does not block setup (15 when the user has to click in its window)
    if (!$proc.WaitForExit($(if ($info.Window) { 900000 } else { 300000 }))) { Write-Warning "$App installer timed out." } else { Write-Output "$App installer exit code: $($proc.ExitCode)" }
    Wait-DiscordSetup
    if (Test-Installed) { Write-Output "$App installed."; Remove-SignInTask } else { Write-Warning "$App is not fully installed." }
    Stop-AutoStartedApp
} else {
    Write-Warning "Downloading $App failed. Install it later from its official website."
}
Remove-Item -Path $tempDir -Force -Recurse -EA 0
exit 0
