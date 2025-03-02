# NAPLAN_Installer_Updater <BR><BR>

Install this task for Windows with NAPLANscheduledtask.ps1 below.<BR><BR>
To Install:<BR>
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12;
irm -UseBasicParsing -Uri "https://raw.githubusercontent.com/MacsInSpace/NAPLAN_Installer_Updater/refs/heads/main/Windows/NAPLANscheduledtask.ps1" | iex
<BR>
Or locally with the cmd script for BYOD:<BR>
InstallNaplanTask.cmd
<BR><BR>
<BR><BR>
InstallNaplan.ps1 - Core script that installs NAPLAN
<BR><BR>
NAPLANscheduledtask.ps1 - Installs the scheduled task to run the core script
<BR><BR>
InstallNaplanTask.cmd - Calls ^NAPLANscheduledtask.ps1^. Installs the task into task scheduler - (for manually running on BYOD)
<BR><BR>
NAPLANnuke.ps1 - Uninstalls nicely, and then aggressively using NapNuke, developed by Rolfe Hodges in Melb, via a bat script, but translated to PS.<BR>
Uninstall all old versions and those old messy uninstalls. thanks to Rolfe Hodges
