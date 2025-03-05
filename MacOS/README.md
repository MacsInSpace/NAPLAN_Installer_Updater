# 💻 NAPLAN Installer & Updater for MacOS

Still in testing.....
This script automates the **installation, updating, and uninstallation** of the **NAPLAN Locked-Down Browser (LDB)** on **MacOS**, following the same update logic as the Windows version.

## 🌐 Overview
- ✅ **Installs, updates, or reinstalls** NAPLAN LDB automatically.
- ⏳ **Launch Daemon runs daily** but adjusts update frequency dynamically:
  - ♻️ **Weekly updates** from **January to April** (before and during NAPLAN testing).
  - 🌞 **Monthly updates** outside of testing periods.
- 🔍 Fetches official **NAPLAN test dates** from **ACARA**:
  [NAPLAN Key Dates](https://www.nap.edu.au/naplan/key-dates)
- ✈ Downloads NAPLAN LDB **directly from ACARA's website**:
  [Assessform NAPLAN Online](https://www.assessform.edu.au/naplan-online/locked-down-browser)
- 🔧 **Logs locally for troubleshooting:** `/var/log/naplan_update.log`

## 🚀 Installation
Run the following command in **Terminal** to install the update daemon:

```bash
curl -sSL "https://raw.githubusercontent.com/MacsInSpace/NAPLAN_Installer_Updater/main/MacOS/InstallLaunchDaemon.sh" | bash
```

This will:
- Install the **Launch Daemon** to manage NAPLAN updates.
- Ensure that update frequency follows the smart scheduling system.

## ❌ Uninstallation (Deep Clean)
To completely remove NAPLAN LDB and all associated files, run:

```bash
curl -sSL "https://raw.githubusercontent.com/MacsInSpace/NAPLAN_Installer_Updater/main/MacOS/NAPLANnuke.sh" | bash
```

This will:
- Uninstall NAPLAN LDB from your Mac.
- Remove cached configurations and old files.
- Remove the LaunchD task.

## 🌟 Features
- **Automated install & update** via MacOS Launch Daemon.
- **Smart update frequency** (adapts based on testing periods).
- **Complete removal script available** (for clean reinstalls).
- **Runs directly from GitHub** (or can be modified to run locally).

## 🎨 Contributing
- Looking for **optimizations, fixes, and feature requests**.
- **Pull requests welcome!**

## 💌 Have suggestions or issues?
[Open an issue](https://github.com/MacsInSpace/NAPLAN_Installer_Updater/issues) or submit a pull request! 🚀

