# Uninstall NAPLAN Update Scheduled Task
# Run this with 
# You may need to enable TLS for secure downloads on PS version 5ish
# [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12;
# irm -UseBasicParsing -Uri "https://raw.githubusercontent.com/MacsInSpace/NAPLAN_Installer_Updater/refs/heads/main/Windows/bin/NukeScheduledTask.ps1" | iex

Start-Transcript -Path "C:\Windows\Temp\NaplanScheduledTask.log" -Append

$TaskName = "InstallNaplan"
Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12;irm -UseBasicParsing -Uri "https://raw.githubusercontent.com/MacsInSpace/NAPLAN_Installer_Updater/refs/heads/main/Windows/bin/NAPLANnuke.ps1" | iex
Stop-Transcript
