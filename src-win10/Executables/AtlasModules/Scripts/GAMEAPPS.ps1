param (
    [Parameter(Mandatory)][string]$App,
    # Do not install now: register a scheduled task that runs this script as the signed-in user
    # at their next sign-in (used by setup for Discord). Needs admin rights.
    [switch]$AtSignIn,
    # Set by that scheduled task
    [switch]$FromTask
)

# Akati OS: installs one gaming app (used during setup and by AtlasDesktop\Akati OS\Install Gaming Apps).
# Uses WinGet first (installer hashes are verified by WinGet).
# Falls back to the official direct download where one exists.

# Log for troubleshooting: %LOCALAPPDATA%\AkatiOS\Logs\GAMEAPPS-<App>.log
try {
    $logDir = Join-Path $env:LOCALAPPDATA 'AkatiOS\Logs'
    New-Item -ItemType Directory -Path $logDir -Force | Out-Null
    Start-Transcript -Path (Join-Path $logDir "GAMEAPPS-$App.log") -Append | Out-Null
} catch {}

$apps = @{
    Steam     = @{ Id = 'Valve.Steam';                  Url = 'https://cdn.akamai.steamstatic.com/client/installer/SteamSetup.exe'; Args = '/S'
                   Installed = { Test-Path "${env:ProgramFiles(x86)}\Steam\steam.exe" } }
    Discord   = @{ Id = 'Discord.Discord';              Url = 'https://discord.com/api/downloads/distributions/app/installers/latest?channel=stable&platform=win&arch=x64'; Args = '-s'
                   # Update.exe alone is not enough: an interrupted install leaves it without the app
                   Installed = { (Test-Path "$env:LOCALAPPDATA\Discord\packages\RELEASES") -and (Test-Path "$env:LOCALAPPDATA\Discord\app-*\Discord.exe") } }
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
if ($FromTask) { Start-Sleep -Seconds 30 }

if (Test-Installed) { Write-Output "$App is already installed."; Remove-SignInTask; exit 0 }

# Discord installs itself after its installer exits (Update.exe). This script must not exit before
# that is done: started at sign-in (RunOnce) from a hidden window, Update.exe stops when this script
# exits and leaves Discord half installed. So wait until Discord is installed and its setup has ended.
function Wait-DiscordSetup {
    if ($App -ne 'Discord') { return }
    $deadline = (Get-Date).AddMinutes(5)
    do {
        Start-Sleep -Seconds 3
        $busy = Get-Process -Name 'Update', 'DiscordSetup' -ErrorAction SilentlyContinue |
            Where-Object { $_.Name -eq 'DiscordSetup' -or $_.Path -like "$env:LOCALAPPDATA\Discord\*" -or $_.Path -like "$env:LOCALAPPDATA\SquirrelTemp\*" }
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

# Try WinGet
if (Get-Command winget -EA 0) {
    Write-Output "Installing $App with WinGet..."
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
& curl.exe -LSs $info.Url -o $file $timeouts
if ($? -and (Test-Path $file)) {
    $proc = Start-Process -FilePath $file -ArgumentList $info.Args -WindowStyle Hidden -PassThru
    $null = $proc.Handle
    # Max 5 minutes so a stuck installer does not block setup
    if (!$proc.WaitForExit(300000)) { Write-Warning "$App installer timed out." } else { Write-Output "$App installer exit code: $($proc.ExitCode)" }
    Wait-DiscordSetup
    if (Test-Installed) { Write-Output "$App installed."; Remove-SignInTask } else { Write-Warning "$App is not fully installed." }
    Stop-AutoStartedApp
} else {
    Write-Warning "Downloading $App failed. Install it later from its official website."
}
Remove-Item -Path $tempDir -Force -Recurse -EA 0
exit 0
