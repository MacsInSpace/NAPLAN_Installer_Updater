[NAPLAN info](https://www.assessform.edu.au/naplan-online)
The Online National Assessment Platform is used by schools conducting NAPLAN testing (for years 3, 5, 7 and 9)

[For minimum system requirements, go here](https://www.assessform.edu.au/naplan-online/device-requirements)

[For browser info and support, go here.](https://www.assessform.edu.au/naplan-online/locked-down-browser)

[Here for other resources](https://www.assessform.edu.au/resources/)

[VCAA Contacts](https://www.assessform.edu.au/contacts)

---

## 📝 Unofficial NAPLAN Installer & Updater

This repository provides a cross-platform solution for **installing, updating, and managing** the **NAPLAN Locked-Down Browser (LDB)** on both **Windows** and **MacOS**.

[For the iOS install, go here!](https://apps.apple.com/au/app/nap-locked-down-browser/id1086807255)

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
- Signature and certificate validation checks on msi/pkg (Checksum info would be nice Acara..)
- 📅 **Supports forced reinstalls** (for scenarios where the version hasn’t changed but has been updated).
- 🔧 **Logs locally for troubleshooting**:
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
curl -sSL "https://raw.githubusercontent.com/MacsInSpace/NAPLAN_Installer_Updater/main/MacOS/InstallLaunchDaemon.sh" | sudo bash
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
curl -sSL "https://raw.githubusercontent.com/MacsInSpace/NAPLAN_Installer_Updater/main/MacOS/NAPLANnuke.sh" | sudo bash
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

**Note!**
Issues should be relevant **only** to the scheduled task/launchd process or specific to this installer/updater. 

**Not** for the browser itsself.

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

