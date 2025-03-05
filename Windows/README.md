# 🏫 NAPLAN Installer & Updater for Windows

This repository automates the **installation, updating, and uninstallation** of the **NAPLAN Locked-Down Browser (LDB)** on Windows systems.

## 📂 Contents

| File | Description |
|------|------------|
| [`InstallNaplanTask.cmd`](InstallNaplanTask.cmd) | Runs `NAPLANscheduledtask.ps1` for easier setup (useful for BYOD or manual installs). |
| [`NAPLANscheduledtask.ps1`](bin/NAPLANscheduledtask.ps1) | Configures a scheduled task to auto-update NAPLAN LDB. |
| [`InstallNaplan.ps1`](bin/InstallNaplan.ps1) | Installs or updates the latest NAPLAN LDB. |
| [`NAPLANnuke.ps1`](bin/NAPLANnuke.ps1) | Deep cleans old NAPLAN installations and removes residual files. |

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

---

### 🔹 **Option 2: Manual Installation (Recommended for BYOD)**
1. **Download** [`InstallNaplanTask.cmd`](InstallNaplanTask.cmd)  
2. **Right-click → Run as Administrator**  
3. This sets up the scheduled task to **auto-install or update** NAPLAN LDB.

---

## ❌ Uninstallation (Deep Clean)
If you need to **completely remove** all NAPLAN versions, including leftovers from old installers:

1. Run [`NAPLANnuke.ps1`](NAPLANnuke.ps1) in **PowerShell (Admin)**.
2. This script:
   - Removes **all NAPLAN-related files**.
   - Clears **registry entries** and **old configurations**.
   - Ensures a **clean slate** before a fresh install.
   - *Does not remove the Scheduled Task.

---

## 🔄 How Automatic Updates Work
The scheduled task checks for updates **daily**, but:
- **Increases update frequency** before testing periods (**January – March**).  
- **Reduces update frequency** outside of test windows.  
- Uses **ACARA’s official test schedule** to adjust automatically.  

### 📝 **Version Check & Smart Scheduling**
- If the latest version is **already installed**, the task **skips updating**.
- Update logic is **dynamically adjusted** based on **ACARA’s NAPLAN test dates**.

---

## 🙌 Acknowledgments
Shoutout to **Rolfe Hodges** (Melbourne) for the **original NapNuke script**, which was adapted into PowerShell.

---

## ⚠️ Important Notes
- **Administrator privileges are required** to install, update, or remove NAPLAN LDB.
- Always **verify scripts** before executing them on your system.
- This repository is **not affiliated with ACARA** but provides tools to manage NAPLAN LDB installations more effectively.

---

📌 **Need Help?**  
Open an issue on [GitHub](https://github.com/MacsInSpace/NAPLAN_Installer_Updater/issues) or submit a pull request if you have improvements! 🚀

