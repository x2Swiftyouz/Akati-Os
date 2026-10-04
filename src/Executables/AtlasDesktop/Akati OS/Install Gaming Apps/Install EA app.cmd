@echo off
set "script=%windir%\AtlasModules\Scripts\GAMEAPPS.ps1"

set "___args="%~f0" %*"
fltmc > nul 2>&1 || (
    echo Administrator privileges are required.
    powershell -c "Start-Process -Verb RunAs -FilePath 'cmd' -ArgumentList """/c $env:___args"""" 2> nul || (
        echo You must run this script as admin.
        if "%*"=="" pause
        exit /b 1
    )
    exit /b
)

if not exist "%script%" (
    echo Script not found: "%script%"
    pause
    exit /b 1
)

echo Installing EA app...
powershell -ExecutionPolicy Bypass -NoProfile -File "%script%" -App EA

echo.
echo Done. If EA app was not installed, get it from its official website.
pause > nul
exit /b 0
