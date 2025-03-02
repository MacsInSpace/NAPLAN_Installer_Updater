#!/bin/bash

# Define variables
PKG_URL="https://www.assessform.edu.au/naplan-online/locked-down-browser"
DOWNLOAD_DIR="/tmp"
PKG_NAME="NAP_LDB.pkg"
PKG_PATH="$DOWNLOAD_DIR/$PKG_NAME"
LOG_FILE="/var/log/naplan_update.log"
PLIST_BUNDLE="NAP Locked down browser.app"
FORCE_NEW_VERSION=false

# Function to log messages
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOG_FILE"
}

# Ensure we have internet
ping -c 1 8.8.8.8 &>/dev/null
if [ $? -ne 0 ]; then
    log "No internet connection. Exiting."
    exit 1
fi

# Fetch the latest version from the website
LATEST_URL=$(curl -s "$PKG_URL" | grep -oE 'https://[^"]+\.pkg' | head -n 1)
if [ -z "$LATEST_URL" ]; then
    log "Failed to retrieve package URL."
    exit 1
fi
log "Url is $LATEST_URL"

LATEST_VERSION=$(echo "$LATEST_URL" | grep -oE '[0-9]+(\.[0-9]+)*')
INSTALLED_VERSION=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "/Applications/$PLIST_BUNDLE/Contents/Info.plist" 2>/dev/null)

log "Latest version: $LATEST_VERSION"
log "Installed version: $INSTALLED_VERSION"


# Compare versions
if [[ -z "$FORCE_NEW_VERSION" && "$LATEST_VERSION" == "$INSTALLED_VERSION" ]]; then
    log "Versions match, not forcing an update, No update required."
    exit 0
fi

# Download the new version
log "Downloading $LATEST_URL..."
curl -L -o "$PKG_PATH" "$LATEST_URL"
if [ $? -ne 0 ]; then
    log "Failed to download package."
    exit 1
fi

# Install the new package
log "Installing new version..."
sudo installer -pkg "$PKG_PATH" -target /
if [ $? -eq 0 ]; then
    log "Installation successful."
    rm -f "$PKG_PATH"
else
    log "Installation failed."
    exit 1
fi

exit 0
