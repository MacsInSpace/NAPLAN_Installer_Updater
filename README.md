# NAPLAN_Installer_Updater <BR><BR>
Install/update/uninstall/reinstall NAPLAN LDB direct from the Acara/assessform/NAPLAN site.<BR>
Creates a scheduled task to update/uninstall/reinstall the amazingly written software that is NAPLAN. <BR>
Checks version numbers online daily at $random time between 9 and 4.<BR>
Installs imediately. <BR>
Runs live from gitlab. <BR>
Optionally forces a reinstall for when a version is supersceeded but the version number doesnt change. Like when their cert expired <BR>
Happy to take pull requests, fixed, issues. <BR>
Install this task with NAPLANscheduledtask.ps1<BR>
To Install:<BR>
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12;
irm -UseBasicParsing -Uri "https://raw.githubusercontent.com/MacsInSpace/NAPLAN_Installer_Updater/refs/heads/main/NAPLANscheduledtask.ps1" | iex
<BR>

Or locally with the cmd script for BYOD:<BR>
InstallNaplanTask.cmd
<BR><BR>
Uninstalls nicely, and then aggressively using NapNuke, developed by Rolfe Hodges in Melb, via a bat script, but translated to PS.
