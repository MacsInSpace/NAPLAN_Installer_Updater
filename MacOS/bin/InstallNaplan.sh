#!/bin/bash
# Run this manually as a once off with:
# curl -sSL "https://raw.githubusercontent.com/MacsInSpace/NAPLAN_Installer_Updater/main/MacOS/bin/InstallNaplan.sh" | sudo bash

# Define variables
unset FORCE_NEW_VERSION
PKG_URL="https://www.assessform.edu.au/naplan-online/locked-down-browser"
DOWNLOAD_DIR="/tmp"
PKG_NAME="NAP_LDB.pkg"
PKG_PATH="$DOWNLOAD_DIR/$PKG_NAME"
LOG_FILE="/var/log/naplan_update.log"
PLIST_BUNDLE="NAP Locked down browser.app"
FORCE_NEW_VERSION=false
UPDATETASKTOO=false

fetch_naplan_dates() {
    local key_dates_url="https://www.nap.edu.au/naplan/key-dates"

    # Fetch the webpage content
    local raw_html=$(curl -s "$key_dates_url")

    # Get the current system year
    local system_year=$(date +"%Y")

    # Extract valid years from the page, filter out nonsense (e.g., 0000, 2049)
    local current_year=$(echo "$raw_html" | grep -Eo "[0-9]{4}" | grep "^20" | sort -u | awk -v year="$system_year" '$1 >= year' | head -1)

    # Extract the first valid test window (e.g., "12–24 March")
    local test_window=$(echo "$raw_html" | grep -Eo "[0-9]{1,2}[-–][0-9]{1,2} (January|February|March|April|May|June|July|August|September|October|November|December)" | head -1)

    # Ensure we have valid extracted data
    if [[ -z "$test_window" || -z "$current_year" ]]; then
        test_window="March 12–24"
        current_year="$system_year" # Use the current system year as a fallback
        echo "⚠️ Using fallback test window: $test_window $current_year" | tee -a "$LOG_FILE"
    fi

    # Print the final formatted test window with the correct year
    echo "$test_window $current_year"
}

# Function to determine update frequency dynamically
determine_update_frequency() {
    local naplan_dates=$(fetch_naplan_dates)
    local start_day=$(echo "$naplan_dates" | awk '{print $2}' | cut -d'-' -f1)
    local end_day=$(echo "$naplan_dates" | awk '{print $2}' | cut -d'-' -f2)
    local month=$(echo "$naplan_dates" | awk '{print $3}')
    local current_year=$(date +"%Y")

    if [[ -z "$start_day" || -z "$end_day" || -z "$month" ]]; then
        echo "monthly"  # Fallback if parsing fails
        return
    fi

    local start_date="$current_year-$month-$start_day"
    local end_date="$current_year-$month-$end_day"

    # Convert dates to timestamp
    local current_date=$(date +%s)
    local start_date_seconds=$(date -j -f "%Y-%B-%d" "$start_date" +%s 2>/dev/null)
    local end_date_seconds=$(date -j -f "%Y-%B-%d" "$end_date" +%s 2>/dev/null)

    if [[ -z "$start_date_seconds" || -z "$end_date_seconds" ]]; then
        echo "monthly"  # Fallback
    elif [[ "$current_date" -ge "$start_date_seconds" && "$current_date" -le "$end_date_seconds" ]]; then
        echo "weekly"
    else
        echo "monthly"
    fi
}

# Debug output
echo "FORCE_NEW_VERSION is set to: $FORCE_NEW_VERSION" >> $LOG_FILE

# Function to log messages
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" >> "$LOG_FILE"
}

check_internet () {
# Ensure we have internet
ping -c 1 8.8.8.8 &>/dev/null
if [ $? -ne 0 ]; then
    echo "No internet connection. Exiting." >> $LOG_FILE
    exit 1
fi
}

check_for_rosetta () {
# Determine the architecture of the macOS device
processorBrand=$(/usr/sbin/sysctl -n machdep.cpu.brand_string)
if [[ "${processorBrand}" = *"Apple"* ]]; then
 echo "Apple Processor is present." >> $LOG_FILE
 # Check if Rosetta is installed
checkRosettaStatus=$(/bin/launchctl list | /usr/bin/grep "com.apple.oahd-root-helper")
RosettaFolder="/Library/Apple/usr/share/rosetta"
if [[ -e "${RosettaFolder}" && "${checkRosettaStatus}" != "" ]]; then
 echo "Rosetta Folder exists and Rosetta Service is running." >> $LOG_FILE
else
 "Rosetta Folder does not exist or Rosetta service is not running. Installing Rosetta..." >> $LOG_FILE
 # Install Rosetta
/usr/sbin/softwareupdate --install-rosetta --agree-to-license >> $LOG_FILE
fi
else
 echo "Apple Processor is not present. Rosetta not required." >> $LOG_FILE
fi
}

# Fetch the latest version from the website
check_internet
PKG_URL=$(echo "$PKG_URL" | sed 's/%20/ /g') >> $LOG_FILE
LATEST_URL=$(curl -A "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/110.0.0.0 Safari/537.36" \
    -H "Accept-Language: en-US,en;q=0.9" \
    -H "Referer: $PKG_URL" \
    -H "Connection: keep-alive" \
    -H "Cache-Control: no-cache, no-store, must-revalidate" \
    -H "Pragma: no-cache" \
    -H "Expires: 0" \
    --compressed -s "$PKG_URL" 2>/var/log/naplan_update.log | grep -oE 'https://[^"]+\.pkg' | head -n 1) >> $LOG_FILE
    
if [ -z "$LATEST_URL" ]; then
    echo "Failed to retrieve package URL." >> $LOG_FILE
    exit 1
fi
echo "Url is $LATEST_URL" >> $LOG_FILE
LATEST_VERSION=$(echo "$LATEST_URL" | grep -oE '[0-9]+(\.[0-9]+)*')
echo "Latest version: $LATEST_VERSION" >> $LOG_FILE




INSTALLED_VERSION=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "/Applications/$PLIST_BUNDLE/Contents/Info.plist" 2>/dev/null)
echo "Installed version: $INSTALLED_VERSION" >> $LOG_FILE


# Compare versions, allowing forced updates
if [[ "$FORCE_NEW_VERSION" != "true" && "$LATEST_VERSION" == "$INSTALLED_VERSION" ]]; then
    echo "Versions match, not forcing an update. No update required." >> $LOG_FILE
    exit 0
else
    echo "Forcing update: $FORCE_NEW_VERSION"
fi




# Uninstall NAPLAN Locked Down Browser if it exists
echo "Uninstalling App" >> $LOG_FILE
rm -r "$HOME/.config/NAP Locked down browser"
rm -r "$HOME/.local/share/NAP Locked down browser"
rm -r "/Applications/NAP Locked down browser.app"
rm -r "/Applications/NAP Locked down browser Uninstaller.app"
echo "Uninstall Complete" >> $LOG_FILE





dl_naplan_ldb() {
# Download the new version
check_internet
echo "Downloading $LATEST_URL..." >> $LOG_FILE
ENCODED_URL="${LATEST_URL// /%20}"
curl -L -o "$PKG_PATH" "$ENCODED_URL" >> $LOG_FILE
if [ $? -ne 0 ]; then
    echo "Failed to download package."
    exit 1
fi
}



install_naplan_ldb() {

    if ! pkgutil --check-signature "$PKG_PATH"; then
        echo "⚠️ Invalid or missing PKG signature. Exiting." | tee -a /var/log/naplan_update.log
        exit 1
    fi

echo "✅ PKG signature is valid. Proceeding with installation..."
    check_for_rosetta
    echo "$(date): Starting NAPLAN LDB installation/update..." >> "$LOG_FILE"
    dl_naplan_ldb    
    # Install the new package
    echo "$(date): Installing NAPLAN LDB package..." >> "$LOG_FILE"
    installer -pkg "$PKG_PATH" -target / >> $LOG_FILE
    if [ $? -eq 0 ]; then
        echo "Installation successful." >> $LOG_FILE
        rm -f "$PKG_PATH"
        if [ $UPDATETASKTOO ]; then
        echo "SelfUpdating the launchd." >> $LOG_FILE
        curl -sSL "https://raw.githubusercontent.com/MacsInSpace/NAPLAN_Installer_Updater/main/MacOS/InstallLaunchDaemon.sh" | sudo bash
        fi
    else
        echo "Installation failed." >> $LOG_FILE
        exit 1
    unset FORCE_NEW_VERSION
    fi
}


# Main script execution
update_frequency=$(determine_update_frequency)

LOG_FILE="/var/log/naplan_update.log"

# Define test window (Dynamically fetched)

TODAY=$(date +"%Y-%m-%d")

# If today is within the test window, log and exit
if [[ "$TODAY" > "$start_day" && "$TODAY" < "$end_day" ]]; then
    echo "$(date) - Not running due to NAPLAN testing window." >> "$LOG_FILE"
    exit 0
fi

if [ "$update_frequency" == "weekly" ]; then
    echo "$(date): Scheduling weekly updates." >> "$LOG_FILE"
    # Add code to schedule weekly updates
    # Perform installation or update
    install_naplan_ldb
else
    echo "$(date): Scheduling monthly updates." >> "$LOG_FILE"
    # Add code to schedule monthly updates
    # Perform installation or update
    install_naplan_ldb
fi




exit 0
