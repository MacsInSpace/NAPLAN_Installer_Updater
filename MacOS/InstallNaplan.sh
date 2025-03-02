#!/bin/bash
# Run this manually with:
# curl -sSL "https://raw.githubusercontent.com/MacsInSpace/NAPLAN_Installer_Updater/main/MacOS/InstallNaplan.sh" | sudo bash

# Define variables
PKG_URL="https://www.assessform.edu.au/naplan-online/locked-down-browser"
DOWNLOAD_DIR="/tmp"
PKG_NAME="NAP_LDB.pkg"
PKG_PATH="$DOWNLOAD_DIR/$PKG_NAME"
#LOG_FILE="/var/log/naplan_update.log"
PLIST_BUNDLE="NAP Locked down browser.app"
#FORCE_NEW_VERSION="${FORCE_NEW_VERSION:-false}"
FORCE_NEW_VERSION="${FORCE_NEW_VERSION:-true}"

# Debug output
echo "FORCE_NEW_VERSION is set to: $FORCE_NEW_VERSION"

# Function to log messages
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" >> "$LOG_FILE"
}

# Ensure we have internet
ping -c 1 8.8.8.8 &>/dev/null
if [ $? -ne 0 ]; then
    echo "No internet connection. Exiting."
    exit 1
fi

# Determine the architecture of the macOS device
processorBrand=$(/usr/sbin/sysctl -n machdep.cpu.brand_string)
if [[ "${processorBrand}" = *"Apple"* ]]; then
 echo "Apple Processor is present."
 # Check if Rosetta is installed
checkRosettaStatus=$(/bin/launchctl list | /usr/bin/grep "com.apple.oahd-root-helper")
RosettaFolder="/Library/Apple/usr/share/rosetta"
if [[ -e "${RosettaFolder}" && "${checkRosettaStatus}" != "" ]]; then
 echo "Rosetta Folder exists and Rosetta Service is running."
else
 "Rosetta Folder does not exist or Rosetta service is not running. Installing Rosetta..."
 # Install Rosetta
/usr/sbin/softwareupdate --install-rosetta --agree-to-license
fi
else
 echo "Apple Processor is not present. Rosetta not required."
fi

# Fetch the latest version from the website
PKG_URL=$(echo "$PKG_URL" | sed 's/%20/ /g')
LATEST_URL=$(curl -A "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/110.0.0.0 Safari/537.36" \
    -H "Accept-Language: en-US,en;q=0.9" \
    -H "Referer: $PKG_URL" \
    -H "Connection: keep-alive" \
    -H "Cache-Control: no-cache, no-store, must-revalidate" \
    -H "Pragma: no-cache" \
    -H "Expires: 0" \
    --compressed -s "$PKG_URL" 2>/var/log/naplan_update.log | grep -oE 'https://[^"]+\.pkg' | head -n 1)
    
if [ -z "$LATEST_URL" ]; then
    echo "Failed to retrieve package URL."
    exit 1
fi
echo "Url is $LATEST_URL"

LATEST_VERSION=$(echo "$LATEST_URL" | grep -oE '[0-9]+(\.[0-9]+)*')
INSTALLED_VERSION=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "/Applications/$PLIST_BUNDLE/Contents/Info.plist" 2>/dev/null)

echo "Latest version: $LATEST_VERSION"
echo "Installed version: $INSTALLED_VERSION"

# Compare versions, allowing forced updates
if [[ "$FORCE_NEW_VERSION" != "true" && "$LATEST_VERSION" == "$INSTALLED_VERSION" ]]; then
    echo "Versions match, not forcing an update. No update required."
    exit 0
else
    echo "Forcing update: $FORCE_NEW_VERSION"
fi

# Uninstall NAPLAN Locked Down Browser if it exists
echo "Uninstalling App"
rm -r "$HOME/.config/NAP Locked down browser"
rm -r "$HOME/.local/share/NAP Locked down browser"
rm -r "/Applications/NAP Locked down browser.app"
rm -r "/Applications/NAP Locked down browser Uninstaller.app"
echo "Uninstall Complete"

# Download the new version
echo "Downloading $LATEST_URL..."
ENCODED_URL="${LATEST_URL// /%20}"
curl -L -o "$PKG_PATH" "$ENCODED_URL"
if [ $? -ne 0 ]; then
    echo "Failed to download package."
    exit 1
fi

# Install the new package
echo "Installing new version..."
installer -pkg "$PKG_PATH" -target /
if [ $? -eq 0 ]; then
    echo "Installation successful."
    rm -f "$PKG_PATH"
else
    echo "Installation failed."
    exit 1
fi

exit 0
