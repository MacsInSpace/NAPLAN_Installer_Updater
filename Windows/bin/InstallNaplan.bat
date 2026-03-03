@echo off
pushd "%~dp0"
IF EXIST '%~dpn0.ps1' (
    start /wait PowerShell.exe -NoProfile -ExecutionPolicy Bypass -Command "& '%~dpn0.ps1'" -WindowStyle hidden

) ELSE (
    start /wait PowerShell.exe -NoProfile -ExecutionPolicy Bypass -Command "irm -UseBasicParsing -Uri "https://raw.githubusercontent.com/MacsInSpace/NAPLAN_Installer_Updater/refs/heads/main/Windows/bin/InstallNaplan.ps1" | iex" -WindowStyle hidden
)
popd

exit
