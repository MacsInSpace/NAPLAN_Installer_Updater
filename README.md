# 📝 NAPLAN Installer & Updater

This repository provides a cross-platform solution for **installing, updating, and managing** the **NAPLAN Locked-Down Browser (LDB)** on both **Windows** and **MacOS**.

## 🌐 Overview
- ✅ **Automates installation, updating, and uninstallation** of NAPLAN LDB.
- ⏳ **Scheduled task runs daily** but intelligently adjusts update frequency.
  - ♻️ **Weekly updates** from **January to April** (preparation & testing period).
  - 🌞 **Monthly updates** outside of testing windows.
- 🔍 Automatically obtains official **NAPLAN test dates** from **ACARA**:
- **Uninstalls any old version first** - as recommended by ACARA.
  [NAPLAN Key Dates](https://www.nap.edu.au/naplan/key-dates) (please dont change the format!)
- ✈ Installs **directly from ACARA's website**:  
  [Assessform NAPLAN Online](https://www.assessform.edu.au/naplan-online/locked-down-browser)
- 📅 **Supports forced reinstalls** (for scenarios where the version hasn’t changed but has been updated).
- 🔧 **Logs locally for only troubleshooting**:
  - **MacOS**: `/var/log/naplan_update.log`
  - **Windows**: `C:\Windows\Temp\NaplanScheduledTask.log`
- **No third party data trasmission, logging(other than locally), or server reliance. (aside from this repo)**
  - Can be edited to run locally with SMB backup.
- Will not update during the testing window ~~unless forced~~.

## 🌐 Installation Methods
### **Windows (Scheduled Task)**
Run the following command in **PowerShell (RunAs Admin)**:

```powershell
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12; Invoke-Expression (Invoke-RestMethod -UseBasicParsing -Uri "https://raw.githubusercontent.com/MacsInSpace/NAPLAN_Installer_Updater/main/Windows/NAPLANscheduledtask.ps1")
```

This will:
- Set up a **scheduled task** that manages NAPLAN LDB.
- Ensure **automatic updates** based on the smart scheduling system.

### **MacOS (Launch Daemon)** - (still testing)
Run the following command in **Terminal**:

```bash
curl -sSL "https://raw.githubusercontent.com/MacsInSpace/NAPLAN_Installer_Updater/main/MacOS/InstallLaunchDaemon.sh" | bash
```

This will:
- Install a **launch daemon** to manage NAPLAN LDB updates.
- Ensure updates follow the same smart scheduling logic as Windows.

## ❌ Uninstallation
To remove **all** existing versions of NAPLAN LDB:

### **Windows (Deep Clean)**
Run the following command in **PowerShell (RunAs Admin)**:
```powershell
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12; Invoke-Expression (Invoke-RestMethod -UseBasicParsing -Uri "https://raw.githubusercontent.com/MacsInSpace/NAPLAN_Installer_Updater/main/Windows/NAPLANnuke.ps1")
```
This will:
- Completely remove NAPLAN LDB.
- Delete all residual files and registry entries.

### **MacOS (Deep Clean)**
Run the following command in **Terminal**:
```bash
curl -sSL "https://raw.githubusercontent.com/MacsInSpace/NAPLAN_Installer_Updater/main/MacOS/NAPLANnuke.sh" | bash
```
This will:
- Uninstall NAPLAN LDB.
- Remove associated configurations and cached data.

## 🌟 Features
- **Automated install & update** (Windows: Scheduled Task, MacOS: Launch Daemon).
- **Intelligent update frequency** (increases before testing, reduces otherwise).
- **Full uninstall scripts available** (deep clean for problem scenarios).
- **Compatible with both Windows & MacOS environments.**
- **Runs live from GitHub** (or can be modified to run locally).

## 🎨 Contributing
- **Pull requests & feature requests welcome!**
- Looking for **optimizations, fixes, and additional functionality**.

## 🎉 Thanks & Credits
Special thanks to **Rolfe Hodges** (Melbourne) for the **original NapNuke script**, which has been adapted to powershell.

---

💌 **Have suggestions or issues?**  
[Open an issue](https://github.com/MacsInSpace/NAPLAN_Installer_Updater/issues) or submit a pull request! 🚀

