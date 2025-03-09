#!/usr/bin/env bash

# Run this with:
# curl -sSL "https://raw.githubusercontent.com/MacsInSpace/NAPLAN_Installer_Updater/testing/MacOS/InstallLaunchDaemon.sh" | sudo bash

# Ensure script runs as root
if [[ $EUID -ne 0 ]]; then
    echo "This installer must be run as root. Please enter your Mac's admin password:"
    exec sudo /bin/bash "$0" "$@"
    exit 1
fi

# Define paths
SCRIPT_PATH="/usr/local/bin/naplan_update.sh"
PROXY_SCRIPT_PATH="/usr/local/bin/proxy.sh"
PLIST_PATH="/Library/LaunchDaemons/com.naplan.installer.plist"
LOG_FILE="/var/log/naplan_update.log"

# Ensure /usr/local/bin exists
if [ ! -d "/usr/local/bin" ]; then
    echo "Creating /usr/local/bin..."
    mkdir -p /usr/local/bin
    chown $(whoami) /usr/local/bin
fi

# **Remove old LaunchDaemon if it exists**
if [ -f "$PLIST_PATH" ]; then
    echo "Removing existing LaunchDaemon..."
    sudo launchctl bootout system "$PLIST_PATH" 2>/dev/null
    sudo rm -f "$PLIST_PATH"
fi

# **Write update script**
cat << 'EOF' > "$SCRIPT_PATH"
#!/bin/bash

LOG_FILE="/var/log/naplan_update.log"
INSTALL_SCRIPT_URL="https://api.github.com/repos/MacsInSpace/NAPLAN_Installer_Updater/contents/MacOS/bin/InstallNaplan.sh"
PROXY_SCRIPT_PATH="/usr/local/bin/proxy.sh"

echo "🔄 Running proxy test..."
/usr/local/bin/proxy.sh

# Ensure we have internet
ping -c 1 8.8.8.8 &>/dev/null
if [ $? -ne 0 ]; then
    echo "$(date) - No internet connection. Check your proxy settings.
    Try https://raw.githubusercontent.com/MacsInSpace/NAPLAN_Installer_Updater/refs/heads/main/MacOS/conf/proxy.sh" >> "$LOG_FILE"
    exit 1
fi

echo "$(date) - Downloading and executing InstallNaplan.sh..." >> "$LOG_FILE"

echo "✅ Proxy script executed!"
curl -sSLA "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/110.0.0.0 Safari/537.36" \
    -H "Accept-Language: en-US,en;q=0.9" \
    -H "Connection: keep-alive" \
    -H "Cache-Control: no-cache, no-store, must-revalidate" \
    -H "Pragma: no-cache" \
    -H "Expires: 0" \
    --compressed "$INSTALL_SCRIPT_URL"  | grep -o '"content": "[^"]*' | cut -d '"' -f 4 | base64 --decode | bash 2>&1 >> "$LOG_FILE"

exit 0
EOF

# Download the script and save it to /usr/local/bin
curl -sSLA "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/110.0.0.0 Safari/537.36" \
    -H "Accept-Language: en-US,en;q=0.9" \
    -H "Connection: keep-alive" \
    -H "Cache-Control: no-cache, no-store, must-revalidate" \
    -H "Pragma: no-cache" \
    -H "Expires: 0" \
    --compressed "$PROXY_SCRIPT_WEBPATH" -o "$PROXY_SCRIPT_PATH"

# Set execute permissions
chmod +x "$SCRIPT_PATH"
chmod +x "$PROXY_SCRIPT_PATH"

# Verify download
if [[ -f "$PROXY_SCRIPT_PATH" ]]; then
    echo "✅ Proxy script downloaded successfully to: $PROXY_SCRIPT_PATH"
else
    echo "❌ Failed to download proxy script!"
    exit 1
fi

echo "Installation script saved to $SCRIPT_PATH"
echo "Proxy script saved to $PROXY_SCRIPT_PATH"

# **Write new LaunchDaemon plist**
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

# Validate the plist file
plutil -lint "$PLIST_PATH"

# Set correct permissions
chown root:wheel "$PLIST_PATH"
chmod 644 "$PLIST_PATH"

# **Reinstall and reload the LaunchDaemon**
sudo launchctl bootstrap system "$PLIST_PATH"
sudo launchctl enable system/com.naplan.installer

echo "NAPLAN Update script installed and scheduled successfully."

exit 0
