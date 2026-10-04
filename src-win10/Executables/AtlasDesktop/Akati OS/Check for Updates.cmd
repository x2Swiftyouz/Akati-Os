@echo off
set "script=%windir%\AtlasModules\Scripts\AkatiUpdate.ps1"
if not exist "%script%" (
    echo Script not found: "%script%"
    pause
    exit /b 1
)
powershell -ExecutionPolicy Bypass -NoProfile -File "%script%"
echo.
pause
exit /b 0
