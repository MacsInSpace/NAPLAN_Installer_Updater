# NAPLAN Installer & Updater for Windows

This automates the **installation, updating, and uninstallation** of the **NAPLAN Locked-Down Browser (LDB)** on Windows systems.

## Contents

| File | Description |
|------|------------|
| [`InstallNaplanTask.cmd`](InstallNaplanTask.cmd) | Runs `NAPLANscheduledtask.ps1` for easier setup (useful for BYOD or manual installs). |
| [`UninstallNaplanTask.cmd`](UninstallNaplanTask.cmd) | Runs `NukeNAPLANScheduledTask.ps1` for easier removal of both task and application (useful for BYOD or manual uninstalls). |
| | |
| [`bin/NAPLANscheduledtask.ps1`](bin/NAPLANscheduledtask.ps1) | Installs the scheduled task that keeps the NAPLAN LDB up to date. |
| [`bin/InstallNaplan.ps1`](bin/InstallNaplan.ps1) | Core script. Does all the work. Installs or updates the latest NAPLAN LDB. |
| [`bin/InstallNaplan.bat`](bin/InstallNaplan.bat) | Runs `InstallNaplan.ps1` once (the copy next to it if present, otherwise downloads it). No scheduled task. |
| [`bin/NukeNAPLANScheduledTask.ps1`](bin/NukeNAPLANScheduledTask.ps1) | Removes the scheduled task, the browser (deep clean), the firewall rule and `C:\ProgramData\Naplan`. |
| [`bin/NAPLANnuke.ps1`](bin/NAPLANnuke.ps1) | Deep cleans all known NAPLAN LDB versions and residual files. Leaves the scheduled task in place. |
| [`bin/NAPnuke.bat`](bin/NAPnuke.bat) | Rolfe's original batch deep clean, kept for reference. |
| [`conf/proxy.ps1`](conf/proxy.ps1) | Lets the SYSTEM user use the school proxy when run via the scheduled task. Applies to the updater only: machine proxy settings are not changed. |
| [`conf/versions.txt`](conf/versions.txt) | Version record with product codes and checksums (reference only, not used by the scripts). |
| [`conf/SetVol.ps1`](conf/SetVol.ps1) | Sets the volume before a test (not currently in use). |
| [`launcher/`](launcher) | Experimental desktop launcher that checks volume, battery, internet and screen resolution before starting the browser. Not installed by the updater. |

---

## Installation Instructions

### **Option 1: Automatic Installation via PowerShell**
Run the following command in an **elevated PowerShell window** (**Admin mode**):

```powershell
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12; Invoke-Expression (Invoke-RestMethod -UseBasicParsing -Uri "https://raw.githubusercontent.com/MacsInSpace/NAPLAN_Installer_Updater/main/Windows/bin/NAPLANscheduledtask.ps1")
```

This will:
- Install the **scheduled task** (`InstallNaplan`, runs as SYSTEM).
- Run it straight away, so the browser is installed/updated now.
- Add an outbound firewall rule for the browser.

---

### **Option 2: Manual Installation (Recommended for BYOD)**
1. **Download** [`InstallNaplanTask.cmd`](InstallNaplanTask.cmd)
2. **Double-click it** and accept the administrator prompt (or right-click and choose Run as Administrator).
3. This sets up the scheduled task to **auto-install or update** the NAPLAN LDB.

---

### **Option 3: Just install/update once (no scheduled task)**
Run the following command in an **elevated PowerShell window**:

```powershell
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12; Invoke-Expression (Invoke-RestMethod -UseBasicParsing -Uri "https://raw.githubusercontent.com/MacsInSpace/NAPLAN_Installer_Updater/main/Windows/bin/InstallNaplan.ps1")
```

With options (see below), for example to force a reinstall:

```powershell
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12; & ([scriptblock]::Create((Invoke-RestMethod -UseBasicParsing -Uri "https://raw.githubusercontent.com/MacsInSpace/NAPLAN_Installer_Updater/main/Windows/bin/InstallNaplan.ps1"))) -Force
```

---

## Uninstallation (Deep Clean)
If you need to **completely remove** all NAPLAN versions, including leftovers from old installers, and the scheduled task:

### **Option 1: Automatic Uninstallation via PowerShell**
Run the following command in an **elevated PowerShell window** (**Admin mode**):

```powershell
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12; Invoke-Expression (Invoke-RestMethod -UseBasicParsing -Uri "https://raw.githubusercontent.com/MacsInSpace/NAPLAN_Installer_Updater/main/Windows/bin/NukeNAPLANScheduledTask.ps1")
```

This will:
- Remove the scheduled task.
- Remove **all NAPLAN-related files**, **registry entries** and **old configurations**.
- Remove the firewall rule.
- Remove `C:\ProgramData\Naplan`.

A genuine Safe Exam Browser install is left alone. Only the Safe Exam Browser service that old NAP browsers (2018 to 2021) installed in their own folder is removed.

---

### **Option 2: Manual Uninstallation (Recommended for BYOD)**
1. **Download** [`UninstallNaplanTask.cmd`](UninstallNaplanTask.cmd)
2. **Double-click it** and accept the administrator prompt.
3. This removes the scheduled task and the NAPLAN LDB.

---

## How Automatic Updates Work
The scheduled task runs **daily** (at a random time in school hours) and **at startup**, but only checks ACARA when it needs to:
- **Daily** in the **60 days leading up to a test window**. New versions are often released at the last minute.
- **Weekly** for the rest of the year.
- Uses **ACARA's official test schedule** (plus [`conf/dates.json`](../conf/dates.json)) to work this out.

### **Safety rules**
- If the latest version is **already installed**, nothing happens.
- An installed browser is **never touched during a test window**, or while the browser is open.
- A PC with **no** browser installed still gets one, even during a test window.
- The new MSI is **downloaded and its signature verified before** the old version is removed. If the download fails, the old version stays.
- If the install fails after the old version has been removed, the deep clean is run and the install is tried once more.

### **Options** (manual runs of `InstallNaplan.ps1`)
- `-Force`: reinstall even if the version is already current. Does not override the test window rule.
- `-IgnoreTestWindow`: allow replacing an installed browser during a test window. The scheduled task never does this.
- `-FallbackMsi \\server\share\Naplan.msi`: MSI to use if ACARA's site cannot be reached and nothing is installed.

### **What gets installed**

| Item | Purpose |
|------|---------|
| Scheduled task `InstallNaplan` | Runs as SYSTEM, daily and 5 minutes after startup. |
| `C:\ProgramData\Naplan\RunNaplanUpdate.ps1` | Small runner the task starts. Refreshes the cached installer from GitHub, then runs it. |
| `C:\ProgramData\Naplan\InstallNaplan.ps1` | Cached copy of the installer, used if GitHub is unreachable. |
| `C:\ProgramData\Naplan\proxy.ps1` | Proxy helper. |
| `C:\ProgramData\Naplan\NaplanUpdater.log` | Log of every run. |
| `C:\ProgramData\Naplan\NaplanMsiInstall.log` | Windows Installer log of the last install. |
| Firewall rule `NAPLockedDownBrowserOutbound` | Allows the browser outbound. |

`C:\ProgramData\Naplan` is restricted to SYSTEM and Administrators (read-only for other users), because the scripts in it run as SYSTEM.

### **Logging**
- Logs locally in `C:\ProgramData\Naplan\NaplanUpdater.log`.
- Nothing is stored on any 3rd party servers.

### **Upgrading from an earlier version of this project**
Nothing to do. Existing scheduled tasks pick up the new installer on their next run and replace themselves with the current task.

---

## Acknowledgments
Shoutout to **Rolfe Hodges** (Melbourne) for the **original NapNuke script**, which was adapted into PowerShell.

**Rohan Beckett** (Melbourne) for the volume script.

---

## Important Notes
- **Administrator privileges are required** to install, update, or remove the NAPLAN LDB.
- The scheduled task runs a script fetched from this repository as SYSTEM. Always **read scripts** before running them on your systems, and consider forking the repo so you control what your devices run.
- This repository is **not affiliated with ACARA** but provides tools to manage NAPLAN LDB installations more effectively.

---

**Need Help?**
Open an issue on [GitHub](https://github.com/MacsInSpace/NAPLAN_Installer_Updater/issues) or submit a pull request if you have improvements!
