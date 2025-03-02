@echo off
:: Check for Admin Rights
net session >nul 2>&1
if %errorLevel% NEQ 0 (
    echo Running as Administrator...
    powershell -Command "Start-Process cmd -ArgumentList '/c %~s0' -Verb RunAs"
    exit
)

:: Install the Scheduled Task
powershell -NoProfile -ExecutionPolicy Bypass -Command ^
    "[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12; irm -UseBasicParsing -Uri 'https://gitlab.edustar.tech/TSSP/windows-client-scripts/-/raw/main/Applications/Naplan/NAPLANscheduledtask.ps1' | iex"
