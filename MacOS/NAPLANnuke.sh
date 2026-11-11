#!/bin/bash
#
# NAPLANnuke.sh - completely removes the NAP Locked Down Browser AND this
# updater (LaunchDaemon, scripts, logs) from macOS.
#
# Run this with:
#   curl -fsSL "https://raw.githubusercontent.com/MacsInSpace/NAPLAN_Installer_Updater/main/MacOS/NAPLANnuke.sh" | sudo bash

set -u
export PATH="/usr/bin:/bin:/usr/sbin:/sbin"

main() {
    local LOG_FILE="/var/log/naplan_nuke.log"
    local STATE_DIR="/Library/Application Support/NAPLANUpdater"
    local LABEL="com.naplan.installer"
    local APP="/Applications/NAP Locked down browser.app"
    local UNINSTALLER_APP="/Applications/NAP Locked down browser Uninstaller.app"

    if [ "$(id -u)" -ne 0 ]; then
        echo "This script must be run as root. Re-run it with sudo." >&2
        return 1
    fi

    say() { echo "$1" | tee -a "$LOG_FILE"; }

    say "$(date '+%Y-%m-%d %H:%M:%S') Starting NAPLAN LDB removal..."

    # --- the updater's LaunchDaemon ---------------------------------------------
    launchctl bootout "system/$LABEL" 2>/dev/null && say "Stopped LaunchDaemon $LABEL."
    local plist
    for plist in /Library/LaunchDaemons/*; do
        case "$(basename "$plist" | tr '[:upper:]' '[:lower:]')" in
            *naplan*)
                launchctl bootout system "$plist" 2>/dev/null
                rm -f "$plist" && say "Removed $plist"
                ;;
        esac
    done

    # --- the browser itself --------------------------------------------------------
    if pgrep -if "/Applications/NAP Locked down browser.app/Contents/MacOS/" >/dev/null 2>&1; then
        say "Quitting the running browser..."
        pkill -if "/Applications/NAP Locked down browser.app/Contents/MacOS/"
        sleep 2
    fi

    local path
    for path in "$APP" "$UNINSTALLER_APP" "$STATE_DIR" \
                "/usr/local/bin/naplan_update.sh" \
                "/var/log/naplan_update.log" "/var/log/naplan_update.log.old" "/var/log/naplan_update.launchd.log"; do
        if [ -e "$path" ]; then
            rm -rf "$path" && say "Deleted: $path"
        fi
    done
    # proxy.sh from older versions of this project (only if it is ours).
    if [ -f /usr/local/bin/proxy.sh ] && grep -q "scutil --proxy" /usr/local/bin/proxy.sh 2>/dev/null; then
        rm -f /usr/local/bin/proxy.sh && say "Deleted: /usr/local/bin/proxy.sh"
    fi

    # --- per-user settings and caches ---------------------------------------------------
    local home
    for home in /Users/* /var/root; do
        [ -d "$home" ] || continue
        for path in "$home/.config/NAP Locked down browser" \
                    "$home/.local/share/NAP Locked down browser" \
                    "$home/Library/Caches/NAPLAN"; do
            if [ -e "$path" ]; then
                rm -rf "$path" && say "Deleted: $path"
            fi
        done
    done

    # --- installer receipts ------------------------------------------------------------
    # Only the receipt is forgotten. Files are NOT deleted from the receipt's file
    # list, because that list includes shared folders such as /Applications.
    local pkg
    for pkg in $(pkgutil --pkgs | grep -i -E '^au\.com\.janison\.' ); do
        pkgutil --forget "$pkg" >> "$LOG_FILE" 2>&1 && say "Forgot package receipt: $pkg"
    done

    if [ -d "$APP" ]; then
        say "WARNING: $APP is still present. Manual removal may be required."
        return 1
    fi
    say "NAPLAN LDB and the updater have been removed."
    return 0
}

main "$@"
exit $?
