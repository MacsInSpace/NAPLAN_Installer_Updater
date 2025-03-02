#!/bin/bash
# Run this with 
# curl -sSL "https://raw.githubusercontent.com/MacsInSpace/NAPLAN_Installer_Updater/main/MacOS/InstallLaunchDaemon.sh" | sudo bash

# Ensure script runs as root
if [[ $EUID -ne 0 ]]; then
    echo "This installer must be run as root. Please enter your Mac's admin password:"
    exec sudo /bin/bash "$0" "$@"
    exit 1
fi

# Ensure /usr/local/bin exists
if [ ! -d "/usr/local/bin" ]; then
    echo "Creating /usr/local/bin..."
    mkdir -p /usr/local/bin
    chown $(whoami) /usr/local/bin
fi

# Define script path
SCRIPT_PATH="/usr/local/bin/naplan_update.sh"

# Write update script
cat << 'EOF' > "$SCRIPT_PATH"
#!/bin/bash

LOG_FILE="/var/log/naplan_update.log"
INSTALL_SCRIPT_URL="https://api.github.com/repos/MacsInSpace/NAPLAN_Installer_Updater/contents/MacOS/InstallNaplan.sh"

# Ensure we have internet
ping -c 1 8.8.8.8 &>/dev/null
if [ $? -ne 0 ]; then
    echo "$(date) - No internet connection. Exiting." >> "$LOG_FILE"
    exit 1
fi

echo "$(date) - Downloading and executing InstallNaplan.sh..." >> "$LOG_FILE"

curl -sSLA "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/110.0.0.0 Safari/537.36" \
    -H "Accept-Language: en-US,en;q=0.9" \
    -H "Referer: $PKG_URL" \
    -H "Connection: keep-alive" \
    -H "Cache-Control: no-cache, no-store, must-revalidate" \
    -H "Pragma: no-cache" \
    -H "Expires: 0" \
    --compressed "$INSTALL_SCRIPT_URL" | bash 2>&1 >> "$LOG_FILE"
    
exit 0
EOF

# Set execute permissions
chmod +x "$SCRIPT_PATH"
echo "Installation script saved to $SCRIPT_PATH"

# Install LaunchDaemon (NOT LaunchAgent, since it's run as root)
PLIST_PATH="/Library/LaunchDaemons/com.naplan.installer.plist"
cat << EOF > "$PLIST_PATH"
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
  <dict>
    <key>Label</key>
    <string>com.naplan.installer</string>
    <key>ProgramArguments</key>
    <array>
      <string>/bin/bash</string>
      <string>$SCRIPT_PATH</string>
    </array>
    <key>StartInterval</key>
    <integer>86400</integer>
    <key>RunAtLoad</key>
    <true/>
    <key>StandardOutPath</key>
    <string>/var/log/naplan_update.log</string>
    <key>StandardErrorPath</key>
    <string>/var/log/naplan_update.log</string>
  </dict>
</plist>
EOF

plutil -lint /Library/LaunchDaemons/com.naplan.installer.plist

chown root:wheel /Library/LaunchDaemons/com.naplan.installer.plist
chmod 644 /Library/LaunchDaemons/com.naplan.installer.plist

launchctl bootout system /Library/LaunchDaemons/com.naplan.installer.plist

# reboot  # Uncomment this if previous steps don't work

sudo launchctl bootstrap system /Library/LaunchDaemons/com.naplan.installer.plist
sudo launchctl enable system/com.naplan.installer


echo "NAPLAN Update script installed and scheduled successfully."

exit 0
