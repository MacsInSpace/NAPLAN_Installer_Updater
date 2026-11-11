#!/bin/bash
#
# Installs a LaunchDaemon that keeps the NAP Locked Down Browser up to date.
#
# Run this with:
#   curl -fsSL "https://raw.githubusercontent.com/MacsInSpace/NAPLAN_Installer_Updater/main/MacOS/InstallLaunchDaemon.sh" | sudo bash
#
# What gets installed (everything is root-owned):
#   /Library/LaunchDaemons/com.naplan.installer.plist
#   /Library/Application Support/NAPLANUpdater/naplan_update.sh   (small wrapper the daemon runs)
#   /Library/Application Support/NAPLANUpdater/InstallNaplan.sh   (cached copy of the installer)
#   /Library/Application Support/NAPLANUpdater/proxy.sh           (proxy helper)
#   /var/log/naplan_update.log
#
# The daemon runs once a day (and at boot). Each run refreshes the cached
# installer from GitHub if it can, then runs it with --scheduled. If GitHub is
# unreachable the cached copy is used.

set -u
export PATH="/usr/bin:/bin:/usr/sbin:/sbin"

main() {
    local REPO_BASE="${NAPLAN_REPO_BASE:-https://raw.githubusercontent.com/MacsInSpace/NAPLAN_Installer_Updater/main}"
    local STATE_DIR="/Library/Application Support/NAPLANUpdater"
    local LABEL="com.naplan.installer"
    local PLIST_PATH="/Library/LaunchDaemons/$LABEL.plist"
    local WRAPPER="$STATE_DIR/naplan_update.sh"
    local INSTALLER="$STATE_DIR/InstallNaplan.sh"
    local PROXY="$STATE_DIR/proxy.sh"

    if [ "$(id -u)" -ne 0 ]; then
        echo "This installer must be run as root. Re-run it with sudo." >&2
        return 1
    fi

    mkdir -p "$STATE_DIR" || return 1
    chown root:wheel "$STATE_DIR"; chmod 755 "$STATE_DIR"

    # Use the files next to this script when run from a copy of the repo,
    # otherwise download them.
    local src_dir=""
    if [ -n "${BASH_SOURCE[0]:-}" ] && [ -f "${BASH_SOURCE[0]}" ]; then
        src_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
    fi

    get_file "bin/InstallNaplan.sh" "$INSTALLER" "$src_dir" "$REPO_BASE" || { echo "Failed to get InstallNaplan.sh" >&2; return 1; }
    if ! grep -q "NAPLAN-UPDATER-SCRIPT" "$INSTALLER" || ! bash -n "$INSTALLER"; then
        echo "Downloaded InstallNaplan.sh does not look right. Aborting." >&2
        rm -f "$INSTALLER"
        return 1
    fi
    get_file "conf/proxy.sh" "$PROXY" "$src_dir" "$REPO_BASE" || echo "Proxy helper not available; continuing without it."
    if [ -f "$PROXY" ] && ! bash -n "$PROXY"; then rm -f "$PROXY"; fi

    # --- the wrapper the daemon runs ------------------------------------------------
    cat > "$WRAPPER" <<EOF
#!/bin/bash
# Written by InstallLaunchDaemon.sh. Refreshes the cached installer, then runs it.
export PATH="/usr/bin:/bin:/usr/sbin:/sbin"
REPO_BASE="$REPO_BASE"
STATE_DIR="$STATE_DIR"
EOF
    cat >> "$WRAPPER" <<'EOF'
INSTALLER="$STATE_DIR/InstallNaplan.sh"
LOG_FILE="/var/log/naplan_update.log"

[ -f "$STATE_DIR/proxy.sh" ] && . "$STATE_DIR/proxy.sh" >/dev/null 2>&1

# At boot the network may not be up yet: try for up to five minutes.
tmp="$INSTALLER.new"
ok=false
for attempt in 1 2 3 4 5 6 7 8 9 10; do
    if curl -fsSL --connect-timeout 15 --max-time 60 -o "$tmp" "$REPO_BASE/MacOS/bin/InstallNaplan.sh" 2>/dev/null; then
        ok=true; break
    fi
    sleep 30
done

if $ok && grep -q "NAPLAN-UPDATER-SCRIPT" "$tmp" && bash -n "$tmp" 2>/dev/null; then
    chown root:wheel "$tmp"; chmod 755 "$tmp"
    mv -f "$tmp" "$INSTALLER"
else
    rm -f "$tmp"
    echo "$(date '+%Y-%m-%d %H:%M:%S') - Could not refresh the installer from GitHub; using the cached copy." >> "$LOG_FILE"
fi

[ -f "$INSTALLER" ] || exit 1
exec /bin/bash "$INSTALLER" --scheduled
EOF

    chown root:wheel "$WRAPPER" "$INSTALLER"; chmod 755 "$WRAPPER" "$INSTALLER"
    [ -f "$PROXY" ] && { chown root:wheel "$PROXY"; chmod 755 "$PROXY"; }

    # --- remove the previous daemon and files from older versions of this project ---
    launchctl bootout "system/$LABEL" 2>/dev/null
    rm -f "$PLIST_PATH"
    rm -f /usr/local/bin/naplan_update.sh
    if [ -f /usr/local/bin/proxy.sh ] && grep -q "scutil --proxy" /usr/local/bin/proxy.sh 2>/dev/null; then
        rm -f /usr/local/bin/proxy.sh
    fi

    # --- the LaunchDaemon: daily at a random school-hours time, and at boot -----------
    local hour=$(( 9 + RANDOM % 7 )) minute=$(( RANDOM % 60 ))
    cat > "$PLIST_PATH" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
  <dict>
    <key>Label</key>
    <string>$LABEL</string>
    <key>ProgramArguments</key>
    <array>
      <string>/bin/bash</string>
      <string>$WRAPPER</string>
    </array>
    <key>StartCalendarInterval</key>
    <dict>
      <key>Hour</key>
      <integer>$hour</integer>
      <key>Minute</key>
      <integer>$minute</integer>
    </dict>
    <key>RunAtLoad</key>
    <true/>
    <key>StandardOutPath</key>
    <string>/var/log/naplan_update.launchd.log</string>
    <key>StandardErrorPath</key>
    <string>/var/log/naplan_update.launchd.log</string>
  </dict>
</plist>
EOF
    chown root:wheel "$PLIST_PATH"; chmod 644 "$PLIST_PATH"
    if ! plutil -lint "$PLIST_PATH" >/dev/null; then
        echo "Generated LaunchDaemon plist is invalid. Aborting." >&2
        rm -f "$PLIST_PATH"
        return 1
    fi

    if ! launchctl bootstrap system "$PLIST_PATH"; then
        echo "Failed to load the LaunchDaemon." >&2
        return 1
    fi
    launchctl enable "system/$LABEL"

    printf 'NAPLAN updater installed. It runs daily at %02d:%02d and at boot.\n' "$hour" "$minute"
    echo "The first run has started now. Log: /var/log/naplan_update.log"
    return 0
}

# get_file <repo-relative path under MacOS/> <destination> <local source dir or ""> <repo base>
get_file() {
    local rel="$1" dest="$2" src_dir="$3" base="$4"
    if [ -n "$src_dir" ] && [ -f "$src_dir/$rel" ]; then
        cp -f "$src_dir/$rel" "$dest"
        return $?
    fi
    curl -fsSL --retry 3 --retry-delay 5 --connect-timeout 20 --max-time 120 -o "$dest.dl" "$base/MacOS/$rel" && mv -f "$dest.dl" "$dest"
}

main "$@"
exit $?
