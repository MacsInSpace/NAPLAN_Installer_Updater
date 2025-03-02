#!/bin/bash
# Run this with 
# curl -sSL "https://raw.githubusercontent.com/MacsInSpace/NAPLAN_Installer_Updater/main/MacOS/NAPLANscheduledtask.sh" | bash

# Ensure /usr/local/bin exists
if [ ! -d "/usr/local/bin" ]; then
    echo "Creating /usr/local/bin..."
    sudo mkdir -p /usr/local/bin
    sudo chown $(whoami) /usr/local/bin
fi

# Define script path
SCRIPT_PATH="/usr/local/bin/naplan_update.sh"

# Write update script
cat << 'EOF' > "$SCRIPT_PATH"
#!/bin/bash

LOG_FILE="/var/log/naplan_update.log"
INSTALL_SCRIPT_URL="https://raw.githubusercontent.com/MacsInSpace/NAPLAN_Installer_Updater/main/MacOS/InstallNaplan.sh"

# Ensure /usr/local/bin exists
mkdir -p /usr/local/bin

# Ensure we have internet
ping -c 1 8.8.8.8 &>/dev/null
if [ $? -ne 0 ]; then
    echo "$(date) - No internet connection. Exiting." | tee -a "$LOG_FILE"
    exit 1
fi

echo "$(date) - Downloading and executing InstallNaplan.sh..." | tee -a "$LOG_FILE"
curl -sSL "$INSTALL_SCRIPT_URL" | bash 2>&1 | tee -a "$LOG_FILE"
exit 0
EOF

# Set execute permissions
chmod +x "$SCRIPT_PATH"
echo "Installation script saved to $SCRIPT_PATH"

# Install Launch Agent
PLIST_PATH="$HOME/Library/LaunchAgents/com.naplan.updater.plist"
cat << EOF > "$PLIST_PATH"
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
  <dict>
    <key>Label</key>
    <string>com.naplan.updater</string>
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

# Load Launch Agent
launchctl load "$PLIST_PATH"

echo "NAPLAN Update script installed and scheduled."

sudo launchctl bootstrap system /Library/LaunchDaemons/com.naplan.install.plist
sudo launchctl enable system/com.naplan.install
