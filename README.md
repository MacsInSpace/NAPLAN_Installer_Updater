# NAPLAN_Installer_Updater <BR>
Update/uninstall/reinstall NAPLAN<BR>
Creates a scheduled task to update/uninstall/reinstall the amazingly written software that is NAPLAN. <BR>
Checks version numbers online daily at $random time between 9 and 4.<BR>
Optionally forces a reinstall for when a version is supersceeded but the version number doesnt change. Like when their cert expired <BR><BR>
Install this task with NAPLANscheduledtask.ps1<BR>
To Install:
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12;
irm -UseBasicParsing -Uri "https://raw.githubusercontent.com/MacsInSpace/NAPLAN_Installer_Updater/refs/heads/main/NAPLANscheduledtask.ps1" | iex
<BR><BR>

Or locally with the cmd script for BYOD.

InstallNaplanTask.cmd
