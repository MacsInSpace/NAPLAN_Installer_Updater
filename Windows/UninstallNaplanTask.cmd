@echo off
:: set /p branch=Enter github branch (default - main): 

:: Default to 'main' if no input
:: if "%branch%"=="" set branch=main
set branch=main


:: Check for Admin Rights
net session >nul 2>&1
if %errorLevel% NEQ 0 (
    echo Running as Administrator...
    powershell -Command "Start-Process cmd -ArgumentList '/c %~s0' -Verb RunAs"
    exit
)

:: Install the Scheduled Task
powershell -NoProfile -ExecutionPolicy Bypass -Command ^
    "[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12; irm -UseBasicParsing -Uri 'https://raw.githubusercontent.com/MacsInSpace/NAPLAN_Installer_Updater/refs/heads/%branch%/Windows/bin/NukeNAPLANScheduledTask.ps1' | iex"
