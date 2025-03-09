# 🏫 NAPLAN Installer & Updater for Windows

This repository automates the **installation, updating, and uninstallation** of the **NAPLAN Locked-Down Browser (LDB)** on Windows systems.

## 📂 Contents

| File | Description |
|------|------------|
| [`InstallNaplanTask.cmd`](InstallNaplanTask.cmd) | Runs `NAPLANscheduledtask.ps1` for easier setup (useful for BYOD or manual installs). |
| [`UninstallNaplanTask.cmd`](UninstallNaplanTask.cmd) | Runs `NukeNAPLANScheduledTask.ps1` for easier removal of both task and application (useful for BYOD or manual uninstalls). |
||
| [`NAPLANscheduledtask.ps1`](bin/NAPLANscheduledtask.ps1) | Configures a scheduled task to auto-update NAPLAN LDB. |
| [`InstallNaplan.ps1`](bin/InstallNaplan.ps1) | Core script. Does all the work. Installs or updates the latest NAPLAN LDB. |
| [`NAPLANnuke.ps1`](bin/NAPLANnuke.ps1) | Deep cleans old NAPLAN installations and removes residual files. |
| [`NukeNAPLANScheduledTask.ps1`](bin/NukeNAPLANScheduledTask.ps1) | Deep cleans old NAPLAN installations and removes residual files INCLUDING scheduled task. |
| [`proxy.ps1`](bin/proxy.ps1) | Aids in attempting to allow the SYSTEM user to use a proxy when run via a scheduled task. |
| [`Versions.txt`](bin/Versions.txt) | Version record with info for future hash checks etc. (not currently in use.) |

---

## 🚀 Installation Instructions

### 🔹 **Option 1: Automatic Installation via PowerShell**
Run the following command in an **elevated PowerShell window** (**Admin mode**):

```powershell
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12; Invoke-Expression (Invoke-RestMethod -UseBasicParsing -Uri "https://raw.githubusercontent.com/MacsInSpace/NAPLAN_Installer_Updater/main/Windows/bin/NAPLANscheduledtask.ps1")
```

This will:
✅ Download and execute the **scheduled task setup**  
✅ Ensure **automatic updates** for the NAPLAN LDB
✅ Add a firewall rule

---

### 🔹 **Option 2: Manual Installation (Recommended for BYOD)**
1. **Download** [`InstallNaplanTask.cmd`](InstallNaplanTask.cmd)  
2. **Right-click → Run as Administrator**  
3. This sets up the scheduled task to **auto-install or update** NAPLAN LDB.

---

## ❌ Uninstallation (Deep Clean)
If you need to **completely remove** all NAPLAN versions, including leftovers from old installers and task:
### 🔹 **Option 1: Automatic Uninstallation via PowerShell**
Run the following command in an **elevated PowerShell window** (**Admin mode**):

```powershell
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12; Invoke-Expression (Invoke-RestMethod -UseBasicParsing -Uri "https://raw.githubusercontent.com/MacsInSpace/NAPLAN_Installer_Updater/main/Windows/bin/NukeScheduledTask.ps1")
```

This will:
   - Remove **all NAPLAN-related files**.
   - Clears **registry entries** and **old configurations**.
   - Ensures a **clean slate** before a fresh install.
   - Remove the Scheduled Task.
   - Remove the firewall rule.

---

### 🔹 **Option 2: Manual UnInstallation (Recommended for BYOD)**
1. **Download** [`UninstallNaplanTask.cmd`](UninstallNaplanTask.cmd)  
2. **Right-click → Run as Administrator**  
3. This removes the scheduled task and NAPLAN LDB.

---

## 🔄 How Automatic Updates Work
The scheduled task checks for updates **daily**, but:
- **Increases update frequency** before testing periods (**January – March**).  
- **Reduces update frequency** outside of test windows.  
- Uses **ACARA’s official test schedule** to adjust automatically.  

### 📝 **Version Check & Smart Scheduling**
- If the latest version is **already installed**, the task **skips updating**.
- Update logic is **dynamically adjusted** based on **ACARA’s NAPLAN test dates**.

### 📝 **Logging**
- Logs locally in "C:\ProgramData\Naplan\*.log".
- Nothing stored on any 3rd party servers.
- Can be made to run local only (this would mean no scheduler updates though)

---

## 🙌 Acknowledgments
Shoutout to **Rolfe Hodges** (Melbourne) for the **original NapNuke script**, which was adapted into PowerShell.

**Brad van Ree** (Melbourne) for the going through [`Profile Creator`]([bin/Versions.txt](https://github.com/ProfileCreator/ProfileCreator)) to assist with most of the testing elements

---

## ⚠️ Important Notes
- **Administrator privileges are required** to install, update, or remove NAPLAN LDB.
- Always **verify scripts** before executing them on your system.
- This repository is **not affiliated with ACARA** but provides tools to manage NAPLAN LDB installations more effectively.

---

📌 **Need Help?**  
Open an issue on [GitHub](https://github.com/MacsInSpace/NAPLAN_Installer_Updater/issues) or submit a pull request if you have improvements! 🚀

