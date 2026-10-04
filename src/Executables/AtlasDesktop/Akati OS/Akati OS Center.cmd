@echo off
rem Opens Akati OS Center (asks for administrator rights)
set "app=%windir%\AtlasModules\AkatiCenter\AkatiCenter.ps1"
if not exist "%app%" (
    echo Akati OS Center not found: "%app%"
    pause
    exit /b 1
)
start "" powershell.exe -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File "%app%"
exit /b 0
