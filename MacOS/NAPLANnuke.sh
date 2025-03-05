#!/bin/bash
# Run this with 
# curl -sSL "https://raw.githubusercontent.com/MacsInSpace/NAPLAN_Installer_Updater/main/MacOS/NAPLANnuke.sh" | sudo bash

# NAPLANnuke.sh - Completely removes NAPLAN LDB from macOS
# Run this script as root (sudo) to ensure complete removal

LOG_FILE="/var/log/naplan_nuke.log"
echo "Starting NAPLAN LDB uninstallation..." | tee -a "$LOG_FILE"

# Search for any existing NAPLAN-related LaunchDaemons
echo "Searching for NAPLAN-related LaunchDaemons..." | tee -a "$LOG_FILE"
FOUND_LAUNCHD=$(ls /Library/LaunchDaemons | grep -i naplan)

if [ -n "$FOUND_LAUNCHD" ]; then
    echo "Found LaunchDaemons related to NAPLAN:" | tee -a "$LOG_FILE"
    echo "$FOUND_LAUNCHD" | tee -a "$LOG_FILE"
    for plist in $FOUND_LAUNCHD; do
        echo "Unloading and removing: $plist" | tee -a "$LOG_FILE"
        launchctl unload "/Library/LaunchDaemons/$plist" 2>/dev/null
        rm -f "/Library/LaunchDaemons/$plist"
    done
else
    echo "No NAPLAN-related LaunchDaemons found." | tee -a "$LOG_FILE"
fi

# Specifically remove the known NAPLAN installer scheduled task
INSTALLER_LAUNCHD="/Library/LaunchDaemons/com.naplan.installer.plist"
if [ -f "$INSTALLER_LAUNCHD" ]; then
    echo "Removing scheduled task: com.naplan.installer.plist" | tee -a "$LOG_FILE"
    launchctl unload "$INSTALLER_LAUNCHD" 2>/dev/null
    rm -f "$INSTALLER_LAUNCHD"
else
    echo "No scheduled task com.naplan.installer.plist found." | tee -a "$LOG_FILE"
fi

# Kill any running NAPLAN processes
NAPLAN_PROCESS="NAP Locked Down Browser"
if pgrep -f "$NAPLAN_PROCESS" > /dev/null; then
    echo "Terminating running NAPLAN LDB processes..." | tee -a "$LOG_FILE"
    pkill -f "$NAPLAN_PROCESS"
fi

# Remove application files and related directories
NAPLAN_PATHS=(
    "/Applications/NAP Locked Down Browser.app"
    "/Applications/NAP Locked Down Browser Uninstaller.app"
    "$HOME/.config/NAP Locked Down Browser"
    "$HOME/.local/share/NAP Locked Down Browser"
    "/usr/local/bin/naplan_update.sh"
    "/var/log/naplan_update.log"
)
echo "Removing NAPLAN LDB files..." | tee -a "$LOG_FILE"
for path in "${NAPLAN_PATHS[@]}"; do
    if [ -e "$path" ]; then
        rm -rf "$path"
        echo "Deleted: $path" | tee -a "$LOG_FILE"
    fi
done

# Remove logs and cached files
echo "Cleaning up logs and cache..." | tee -a "$LOG_FILE"
rm -rf /var/log/naplan_update.log
rm -rf "$HOME/Library/Caches/NAPLAN"

# Forget previous installations
# Get a list of installed packages that match "naplan" or "ldb"
naplan_packages=$(pkgutil --pkgs | grep -iE "janison|naplan|ldb")

if [[ -z "$naplan_packages" ]]; then
    echo "No NAPLAN or LDB-related packages found." | tee -a "$LOG_FILE"
    exit 0
fi

# Forget each matching package
for pkg in $naplan_packages; do
    echo "Forgetting package: $pkg" | tee -a "$LOG_FILE"
    sudo pkgutil --forget "$pkg" >> "$LOG_FILE" 2>&1
done

echo "✅ Completed removal of NAPLAN/LDB packages." | tee -a "$LOG_FILE"

# Final confirmation
if [ ! -d "/Applications/NAP Locked Down Browser.app" ]; then
    echo "✅ NAPLAN LDB has been successfully removed from your system." | tee -a "$LOG_FILE"
else
    echo "⚠️ Some files may still remain. Manual removal may be required." | tee -a "$LOG_FILE"
fi

echo "Uninstallation complete." | tee -a "$LOG_FILE"
exit 0
