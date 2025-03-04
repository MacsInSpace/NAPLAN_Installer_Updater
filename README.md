Scheduled Task(Windows) or Launch Daemon(MacOS) to install, update, uninstall, or reinstall the<br>
NAPLAN Locked Down Browser (LDB) direct from the Acara assessform NAPLAN web site.<br>
https://www.assessform.edu.au/naplan-online/locked-down-browser<br><br>
* Creates a scheduled task to update/uninstall/reinstall the amazingly written software that is NAPLAN.<br>
* Checks version numbers online daily at $random time between 9 and 4.<br> 
* Uninstalls the old version and installs the new one as recommended.<br> 
* Logs locally on the device for troubleshooting.<br>
  MacOS logging - /var/log/naplan_update.log<br>
  Windows logging - C:\Windows\Temp\NaplanScheduledTask.log<br>
* Installs immediately.<br>
* Runs live from github.(but can be made to run locally instead)<br> 
* Optionally forces a reinstall for when a version is supersceeded but the version number hasn't changed.<br>
  ....Like when their cert expired<br><br> 
Happy to take pull requests, feature requests, additions, optimisations, fixes, issues.<br> 
