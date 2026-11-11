# NAPLAN Installer & Updater for MacOS

This automates the **installation, updating, and uninstallation** of the **NAPLAN Locked-Down Browser (LDB)** on **MacOS**, following the same rules as the Windows version.

## Overview
- **Installs, updates, or reinstalls** the NAPLAN LDB automatically.
- **The Launch Daemon runs daily and at boot**, but only checks ACARA when it needs to:
  - **Daily checks** in the **60 days leading up to a test window**. New versions are often released at the last minute.
  - **Weekly checks** for the rest of the year.
- **An installed browser is never touched during a test window**, or while it is running.
- A Mac with **no** browser installed still gets one, even during a test window.
- The new package is **downloaded and its signature verified before** the old browser is removed. If the install fails, the old browser is put back.
- Fetches official **NAPLAN test dates** from **ACARA**:
  [NAPLAN Key Dates](https://www.nap.edu.au/naplan/key-dates) (merged with [`conf/dates.json`](../conf/dates.json))
- Downloads the NAPLAN LDB **directly from ACARA's website**:
  [Assessform NAPLAN Online](https://www.assessform.edu.au/naplan-online/locked-down-browser)
- Installs Rosetta on Apple silicon Macs if it is missing (the browser is Intel-only).
- **Logs locally for troubleshooting:** `/var/log/naplan_update.log`

## Contents

| File | Description |
|------|------------|
| [`InstallLaunchDaemon.sh`](InstallLaunchDaemon.sh) | Installs the LaunchDaemon that runs `InstallNaplan.sh` daily. |
| [`NAPLANnuke.sh`](NAPLANnuke.sh) | Removes the LaunchDaemon, the NAPLAN LDB and all associated logs and files. |
| | |
| [`bin/InstallNaplan.sh`](bin/InstallNaplan.sh) | Core script. Does all the work. Installs or updates the latest NAPLAN LDB. |
| [`conf/proxy.sh`](conf/proxy.sh) | Works out the system proxy so the updater's downloads can use it. |
| [`conf/most_naplan_restrictions.mobileconfig`](conf/most_naplan_restrictions.mobileconfig) | A profile for most (not all) of the test restrictions on MacOS. Deploy it yourself; the updater does not install it. |
| [`conf/naplan.pppc.mobileconfig`](conf/naplan.pppc.mobileconfig) | Privacy (PPPC) profile for the browser, for deployment by MDM. The updater does not install it. |
| [`conf/versions.txt`](conf/versions.txt) | Version record with checksums and signer (reference only, not used by the scripts). |

---

## Installation
Run the following command in **Terminal** to install the update daemon:

```bash
curl -fsSL "https://raw.githubusercontent.com/MacsInSpace/NAPLAN_Installer_Updater/main/MacOS/InstallLaunchDaemon.sh" | sudo bash
```

This will:
- Install the **Launch Daemon** to manage NAPLAN updates.
- Run it straight away, so the browser is installed/updated now.

### Just install/update once (no daemon)

```bash
curl -fsSL "https://raw.githubusercontent.com/MacsInSpace/NAPLAN_Installer_Updater/main/MacOS/bin/InstallNaplan.sh" | sudo bash
```

### Options (manual runs of `InstallNaplan.sh`)
Add `-s -- <option>` to the end of the command, for example:

```bash
curl -fsSL "https://raw.githubusercontent.com/MacsInSpace/NAPLAN_Installer_Updater/main/MacOS/bin/InstallNaplan.sh" | sudo bash -s -- --force
```

- `--force`: reinstall even if the version is already current. Does not override the test window rule.
- `--ignore-test-window`: allow replacing an installed browser during a test window. The daemon never does this.

## Uninstallation (Deep Clean)
To completely remove the NAPLAN LDB and all associated files, run:

```bash
curl -fsSL "https://raw.githubusercontent.com/MacsInSpace/NAPLAN_Installer_Updater/main/MacOS/NAPLANnuke.sh" | sudo bash
```

This will:
- Remove the Launch Daemon and its scripts.
- Uninstall the NAPLAN LDB from your Mac.
- Remove per-user settings, caches, logs and the installer receipt.

## What gets installed

| Item | Purpose |
|------|---------|
| `/Library/LaunchDaemons/com.naplan.installer.plist` | Runs daily at a random time in school hours, and at boot. |
| `/Library/Application Support/NAPLANUpdater/naplan_update.sh` | Small wrapper the daemon runs. Refreshes the cached installer from GitHub, then runs it. |
| `/Library/Application Support/NAPLANUpdater/InstallNaplan.sh` | Cached copy of the installer, used if GitHub is unreachable. |
| `/Library/Application Support/NAPLANUpdater/proxy.sh` | Proxy helper. |
| `/var/log/naplan_update.log` | Log of every run. |

Everything is owned by root.

## Upgrading from an earlier version of this project
Re-run the Launch Daemon install command above on each Mac. Launch daemons installed by earlier versions did not run the installer and cannot update themselves. The new install removes the old files in `/usr/local/bin`.

## Important Notes
- The package is checked for a valid Apple Developer ID signature from Janison (team ID `KU9HRE5GET`) before anything is changed.
- The daemon runs a script fetched from this repository as root. Always **read scripts** before running them on your systems, and consider forking the repo so you control what your devices run.
- This repository is **not affiliated with ACARA**.

## Features
- **Automated install & update** via a MacOS Launch Daemon.
- **Smart update frequency** (daily before testing, weekly otherwise, hands-off during testing).
- **Complete removal script available** (for clean reinstalls).
- **Refreshes itself from GitHub** (and keeps a local copy for when GitHub is unreachable).

## Acknowledgments
**Trent Boyd and Brad van Ree** (Melbourne) for going through [Profile Creator](https://github.com/ProfileCreator/ProfileCreator) and creating the mobileconfig profile to assist with most of the testing element restrictions.

## Contributing
- Looking for **optimizations, fixes, and feature requests**.
- **Pull requests welcome!**

## Have suggestions or issues?
[Open an issue](https://github.com/MacsInSpace/NAPLAN_Installer_Updater/issues) or submit a pull request!
