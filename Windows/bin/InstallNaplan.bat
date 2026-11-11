@echo off
rem Installs or updates the NAP Locked Down Browser once (no scheduled task).
rem Uses InstallNaplan.ps1 next to this file if present, otherwise downloads it.
rem Must be run as Administrator.
pushd "%~dp0"
if exist "%~dpn0.ps1" (
    PowerShell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dpn0.ps1"
) else (
    PowerShell.exe -NoProfile -ExecutionPolicy Bypass -Command "[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12; irm -UseBasicParsing -Uri 'https://raw.githubusercontent.com/MacsInSpace/NAPLAN_Installer_Updater/main/Windows/bin/InstallNaplan.ps1' | iex"
)
popd
