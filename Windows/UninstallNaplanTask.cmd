@echo off
rem Removes the updater scheduled task AND the NAP Locked Down Browser.
set branch=main

rem Check for admin rights; relaunch elevated if needed.
net session >nul 2>&1
if %errorLevel% NEQ 0 (
    echo Requesting administrator rights...
    powershell -NoProfile -Command "Start-Process -FilePath '%~f0' -Verb RunAs"
    exit /b
)

powershell -NoProfile -ExecutionPolicy Bypass -Command ^
    "[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12; irm -UseBasicParsing -Uri 'https://raw.githubusercontent.com/MacsInSpace/NAPLAN_Installer_Updater/%branch%/Windows/bin/NukeNAPLANScheduledTask.ps1' | iex"
pause
