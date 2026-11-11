The Online National Assessment Platform is used by Australian schools conducting NAPLAN testing (for years 3, 5, 7 and 9)

[NAPLAN info](https://www.assessform.edu.au/naplan-online)

[For minimum system requirements, go here](https://www.assessform.edu.au/naplan-online/device-requirements)

[For browser info and support, go here.](https://www.assessform.edu.au/naplan-online/locked-down-browser)

[Here for other resources](https://www.assessform.edu.au/resources/)

[VCAA Contacts](https://www.assessform.edu.au/contacts)

---

## Unofficial NAPLAN Installer & Updater

This repository provides an unofficial, cross-platform solution for **installing and updating** the **NAPLAN Locked-Down Browser (LDB)** on both **Windows** and **MacOS**.<br><br>
I (we) have no official affiliation with ACARA, Janison Software, Education Services Australia or any of the developers of the NAPLAN LDB.<br>
Just trying to help my peers save some time in rolling out the LDB to their fleet of devices in a more efficient manner.<br>
Have an idea, issue, or improvement? I'm looking for feedback, contributions, and assistance.<br><br>

[For the iOS install, go here!](https://apps.apple.com/au/app/nap-locked-down-browser/id1086807255)

Platform-specific details: [Windows](Windows/README.md) | [MacOS](MacOS/README.md)

## Overview
- **Automates installation, updating, and uninstallation** of the NAPLAN LDB.
- **A scheduled task (Windows) or LaunchDaemon (MacOS) runs daily and at startup**, but only checks ACARA when it needs to:
  - **Daily checks** in the **60 days leading up to a test window**. New versions are often released at the last minute.
  - **Weekly checks** for the rest of the year.
  - It only installs when the version on ACARA's site is **different** from the installed one.
- **An installed browser is never touched during a test window**, and never while the browser is running.
  - A device with **no** browser installed still gets one, even during a test window.
- **Downloads and verifies the new version before removing the old one.** If the download or signature check fails, nothing is changed.
- **Uninstalls the old version first**, as recommended by ACARA.
- Installs **directly from ACARA's website**:
  [Assessform NAPLAN Online](https://www.assessform.edu.au/naplan-online/locked-down-browser)
- Checks the code signature on the msi/pkg (signed by Janison). Checksum info would be nice, ACARA..
- Automatically obtains official **NAPLAN test dates** from **ACARA**:
  - [NAPLAN Key Dates](https://www.nap.edu.au/naplan/key-dates) (please dont change the format!)
  - Merged with [`conf/dates.json`](conf/dates.json) in this repo, as a backup and for test windows the page does not list.
  - If neither can be read, all of March is treated as the test window.
- **Supports forced reinstalls** (for scenarios where the version number has not changed but the installer has).
- **Logs locally for troubleshooting**:
  - **MacOS**: `/var/log/naplan_update.log`
  - **Windows**: `C:\ProgramData\Naplan\NaplanUpdater.log`
- **No third party data transmission, logging (other than locally), or server reliance (aside from this repo).**
  - The installer script is cached on the device, so the updater keeps working if GitHub is unreachable.

## How the schedule works

| When | What the scheduled task / LaunchDaemon does |
|---|---|
| More than 60 days before a test window | Checks ACARA once a week. Updates if the version is different. |
| The 60 days before a test window | Checks ACARA every day. Updates if the version is different. |
| During a test window | Leaves an installed browser alone. Installs only if no browser is installed. |
| Any time the browser is open | Leaves it alone and tries again on the next run. |

Test windows currently known are listed in [`conf/dates.json`](conf/dates.json).

## Installation Methods
### **Windows (Scheduled Task)**
Run the following command in **PowerShell (RunAs Admin)**:

```powershell
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12; Invoke-Expression (Invoke-RestMethod -UseBasicParsing -Uri "https://raw.githubusercontent.com/MacsInSpace/NAPLAN_Installer_Updater/main/Windows/bin/NAPLANscheduledtask.ps1")
```

This will:
- Set up a **scheduled task** that manages updating the NAPLAN LDB.
- Run it straight away, so the browser is installed/updated now.

### **Windows (Just install/update latest Naplan)**
Run the following command in **PowerShell (RunAs Admin)**:

```powershell
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12; Invoke-Expression (Invoke-RestMethod -UseBasicParsing -Uri "https://raw.githubusercontent.com/MacsInSpace/NAPLAN_Installer_Updater/main/Windows/bin/InstallNaplan.ps1")
```

This will:
- **Just** download/update/install to the latest NAPLAN LDB. No scheduled task is installed.

To force a reinstall of the same version:

```powershell
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12; & ([scriptblock]::Create((Invoke-RestMethod -UseBasicParsing -Uri "https://raw.githubusercontent.com/MacsInSpace/NAPLAN_Installer_Updater/main/Windows/bin/InstallNaplan.ps1"))) -Force
```

### **MacOS (Launch Daemon)**
Run the following command in **Terminal**:

```bash
curl -fsSL "https://raw.githubusercontent.com/MacsInSpace/NAPLAN_Installer_Updater/main/MacOS/InstallLaunchDaemon.sh" | sudo bash
```

This will:
- Install a **launch daemon** to manage NAPLAN LDB updates.
- Run it straight away, so the browser is installed/updated now.
- Follow the same rules as Windows.

### **MacOS (Just Install/Update NAPLAN)**
Run the following command in **Terminal**:

```bash
curl -fsSL "https://raw.githubusercontent.com/MacsInSpace/NAPLAN_Installer_Updater/main/MacOS/bin/InstallNaplan.sh" | sudo bash
```

This will:
- **Just** download/update/install to the latest NAPLAN LDB. No launch daemon is installed.

To force a reinstall of the same version:

```bash
curl -fsSL "https://raw.githubusercontent.com/MacsInSpace/NAPLAN_Installer_Updater/main/MacOS/bin/InstallNaplan.sh" | sudo bash -s -- --force
```

### Options (both platforms)

| Windows | MacOS | What it does |
|---|---|---|
| `-Force` | `--force` | Reinstall even if the installed version is already current. Does not override the test window rule. |
| `-IgnoreTestWindow` | `--ignore-test-window` | Allow replacing an installed browser during a test window. Manual runs only: the scheduled task / daemon never does this. |
| `-FallbackMsi <path>` | (none) | Windows only. An MSI (for example on a file share) to use if ACARA's site cannot be reached and no browser is installed. |

## Uninstallation
To remove **all** existing versions of the NAPLAN LDB, the scheduled task / launch daemon, and associated files and scripts:

### **Windows (Deep Clean, including the scheduled task)**
Run the following command in **PowerShell (RunAs Admin)**:
```powershell
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12; Invoke-Expression (Invoke-RestMethod -UseBasicParsing -Uri "https://raw.githubusercontent.com/MacsInSpace/NAPLAN_Installer_Updater/main/Windows/bin/NukeNAPLANScheduledTask.ps1")
```
This will:
- Remove the scheduled task, firewall rule and `C:\ProgramData\Naplan`.
- Completely remove the NAPLAN LDB, residual files and registry entries.

To deep clean the browser only and keep the scheduled task, use `NAPLANnuke.ps1` instead. The task will reinstall the browser on its next run.

### **MacOS (Deep Clean)**
Run the following command in **Terminal**:
```bash
curl -fsSL "https://raw.githubusercontent.com/MacsInSpace/NAPLAN_Installer_Updater/main/MacOS/NAPLANnuke.sh" | sudo bash
```
This will:
- Uninstall the NAPLAN LDB.
- Remove the launch daemon, its scripts, associated configurations and cached data.

## Upgrading from an earlier version of this project
- **Windows**: nothing to do. Existing scheduled tasks pick up the new installer on their next run and replace themselves with the current task.
- **MacOS**: re-run the Launch Daemon install command above on each Mac. Launch daemons installed by earlier versions did not run the installer and cannot update themselves.

## Things to be aware of
- Devices run a script fetched from this repository as SYSTEM (Windows) or root (MacOS). Read the scripts before you deploy them, and consider forking the repo so you control what your devices run.
- On Windows the old version is uninstalled before the new one is installed (after the new MSI has been downloaded and verified). If the install then fails, the script runs the deep clean and tries once more.
- On MacOS the old app is moved aside and put back if the install fails.

## Features
- **Automated install & update** (Windows: Scheduled Task, MacOS: Launch Daemon).
- **Intelligent update frequency** (daily before testing, weekly otherwise, hands-off during testing).
- **Full uninstall scripts available** (deep clean for problem scenarios).
- **Compatible with both Windows & MacOS environments.**
- **Refreshes itself from GitHub** (and keeps a local copy for when GitHub is unreachable).

## Contributing
- **Pull requests & feature requests welcome!**
- Looking for **optimizations, fixes, and additional functionality**.

## Thanks & Credits
Special thanks to **Rolfe Hodges** (Melbourne) for the **original NapNuke script**, which has been adapted to PowerShell.

**Trent Boyd and Brad van Ree** (Melbourne) for going through [Profile Creator](https://github.com/ProfileCreator/ProfileCreator) and creating a mobileconfig profile to assist with most of the testing element restrictions.

**Rohan Beckett** (Melbourne) for the volume script.

---

**Have suggestions or issues?**
[Open an issue](https://github.com/MacsInSpace/NAPLAN_Installer_Updater/issues) or submit a pull request!

---

**Note!**

Issues should be relevant **only** to the scheduled task/launchd process or specific to this installer/updater.
**Not** for the browser itself.

A reminder that I (we) have no official affiliation with ACARA, Janison Software, or Education Services Australia.
So for browser issues, see the contacts below.

---
---

## Official Contacts

Test Administration Authorities (TAAs) are responsible for the implementation and administration of the NAPLAN tests in their jurisdiction. Permission for variation of dates for testing and for use of scribes and some other accessibility adjustments must be sought from the Test Administration Authority (TAA) in your state or territory, and approval received by schools prior to the national test period.

### **State and Territory Test Administration Authorities (TAAs)**

| State/Territory | Contact Number | Email |
|-----------------|---------------|-----------------------------|
| [ACT Education Directorate](https://www.assessform.edu.au/contacts) | 02 6205 2656 | [NAPOnline@act.gov.au](mailto:NAPOnline@act.gov.au) |
| [NSW Education Standards Authority](https://www.assessform.edu.au/contacts) | 02 9367 8382 | [naplan.nsw@nesa.nsw.edu.au](mailto:naplan.nsw@nesa.nsw.edu.au) |
| [NT Department of Education](https://www.assessform.edu.au/contacts) | 08 8944 9245 | [naplanonline.doe@nt.gov.au](mailto:naplanonline.doe@nt.gov.au) |
| [Qld Curriculum and Assessment Authority](https://www.assessform.edu.au/contacts) | 1300 214 452 | [NAPLAN@QCAA.qld.edu.au](mailto:NAPLAN@QCAA.qld.edu.au) |
| [SA Department for Education](https://www.assessform.edu.au/contacts) | 1800 316 777 | [education.naplan@sa.gov.au](mailto:education.naplan@sa.gov.au) |
| [Tas Department of Education, Children and Young People](https://www.assessform.edu.au/contacts) | 03 6165 5914 | [naplan@decyp.tas.gov.au](mailto:naplan@decyp.tas.gov.au) |
| [Vic Curriculum and Assessment Authority](https://www.assessform.edu.au/contacts) | 1800 648 637 | [vcaa.naplan.help@education.vic.gov.au](mailto:vcaa.naplan.help@education.vic.gov.au) |
| [WA School Curriculum and Standards Authority](https://www.assessform.edu.au/contacts) | 08 9442 9442 | [naplan@scsa.wa.edu.au](mailto:naplan@scsa.wa.edu.au) |

### **Australian Government Department of Education**

| Department | Contact Number | Email/Link |
|-----------------|---------------|-----------------------------|
| [Australian Government Department of Education](https://www.assessform.edu.au/contacts) | 1300 566 046 | [Contact form](https://www.assessform.edu.au/contacts) |
