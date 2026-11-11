#!/bin/bash
# NAPLAN-UPDATER-SCRIPT  (marker checked by the LaunchDaemon wrapper - do not remove)
#
# Installs or updates the NAP Locked Down Browser on macOS.
#
# Run once, manually ("just install/update the latest"):
#   curl -fsSL "https://raw.githubusercontent.com/MacsInSpace/NAPLAN_Installer_Updater/main/MacOS/bin/InstallNaplan.sh" | sudo bash
#
# With options:
#   curl -fsSL ".../MacOS/bin/InstallNaplan.sh" | sudo bash -s -- --force
#
# Options:
#   --scheduled            Used by the LaunchDaemon. Checks daily in the lead-up to a
#                          test window and weekly for the rest of the year.
#   --force                Reinstall even if the installed version is already current.
#   --ignore-test-window   Allow replacing an installed browser during a test window.
#                          (Never used by the LaunchDaemon. Think twice.)
#
# Rules this script always follows:
#   * The new package is downloaded and its signature verified BEFORE the old
#     browser is touched. If the install fails, the old browser is put back.
#   * An installed browser is never replaced during a NAPLAN test window, and
#     never while the browser is running.
#   * A device with NO browser installed gets one, even during a test window.

set -u
export PATH="/usr/bin:/bin:/usr/sbin:/sbin"

main() {
    local REPO_BASE="${NAPLAN_REPO_BASE:-https://raw.githubusercontent.com/MacsInSpace/NAPLAN_Installer_Updater/main}"
    local LDB_PAGE="https://www.assessform.edu.au/naplan-online/locked-down-browser"
    local KEY_DATES_URL="https://www.nap.edu.au/naplan/key-dates"
    local APPS_DIR="/Applications"
    local APP="$APPS_DIR/NAP Locked down browser.app"
    local UNINSTALLER_APP="$APPS_DIR/NAP Locked down browser Uninstaller.app"
    local EXPECTED_TEAM_ID="KU9HRE5GET"          # Developer ID Installer: Janison
    local ALLOWED_HOST_RE='^https://([A-Za-z0-9-]+\.)*assessform\.edu\.au/'
    local STATE_DIR="/Library/Application Support/NAPLANUpdater"
    LOG_FILE="/var/log/naplan_update.log"
    local LEADUP_DAYS=60      # check daily this many days before a test window
    local WEEKLY_DAYS=7       # otherwise check this often
    local WINDOWS_MAX_AGE_DAYS=7
    UA="Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"

    local SCHEDULED=false FORCE=false IGNORE_WINDOW=false
    while [ $# -gt 0 ]; do
        case "$1" in
            --scheduled) SCHEDULED=true ;;
            --force) FORCE=true ;;
            --ignore-test-window) IGNORE_WINDOW=true ;;
            *) echo "Unknown option: $1" >&2; return 2 ;;
        esac
        shift
    done

    if [ "$(id -u)" -ne 0 ]; then
        echo "This script must be run as root. Re-run it with sudo." >&2
        return 1
    fi

    mkdir -p "$STATE_DIR" && chown root:wheel "$STATE_DIR" && chmod 755 "$STATE_DIR"
    rotate_log

    # --- one run at a time --------------------------------------------------
    local LOCK_DIR="$STATE_DIR/lock"
    if ! mkdir "$LOCK_DIR" 2>/dev/null; then
        # Stale lock (older than 3 hours)? Take it over.
        if [ -n "$(find "$LOCK_DIR" -maxdepth 0 -mmin +180 2>/dev/null)" ]; then
            log "Removing stale lock."
            rmdir "$LOCK_DIR" 2>/dev/null
            mkdir "$LOCK_DIR" 2>/dev/null || { log "Could not take lock. Exiting."; return 1; }
        else
            log "Another run is in progress. Exiting."
            return 0
        fi
    fi
    WORK_DIR=""
    trap 'rmdir "'"$LOCK_DIR"'" 2>/dev/null; [ -n "$WORK_DIR" ] && rm -rf "$WORK_DIR"' EXIT

    log "---- NAPLAN LDB updater starting (scheduled=$SCHEDULED force=$FORCE) ----"

    # Proxy helper (optional). Must be sourced so its exports reach curl.
    if [ -f "$STATE_DIR/proxy.sh" ]; then
        # shellcheck disable=SC1091
        . "$STATE_DIR/proxy.sh" >/dev/null 2>&1 || true
    fi

    # --- what is installed? ---------------------------------------------------
    local installed_version=""
    if [ -d "$APP" ]; then
        installed_version=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$APP/Contents/Info.plist" 2>/dev/null || true)
        [ -z "$installed_version" ] && installed_version="unknown"
    fi
    log "Installed version: ${installed_version:-none}"

    # --- test windows -----------------------------------------------------------
    local WINDOWS_FILE="$STATE_DIR/windows"
    refresh_windows "$WINDOWS_FILE" "$KEY_DATES_URL" "$REPO_BASE/conf/dates.json" "$WINDOWS_MAX_AGE_DAYS"

    local today; today=$(date +%Y%m%d)
    local in_window=false in_leadup=false s e lead
    while read -r s e; do
        [ -z "${s:-}" ] && continue
        if [ "$today" -ge "$s" ] && [ "$today" -le "$e" ]; then
            in_window=true
            log "Today is inside a test window ($s to $e)."
        fi
        lead=$(date -j -v-"${LEADUP_DAYS}"d -f "%Y%m%d" "$s" +%Y%m%d 2>/dev/null || echo "")
        if [ -n "$lead" ] && [ "$today" -ge "$lead" ] && [ "$today" -lt "$s" ]; then
            in_leadup=true
            log "Today is in the lead-up to the test window starting $s."
        fi
    done < "$WINDOWS_FILE"

    # --- rule: never replace an installed browser during a test window ----------
    if [ -n "$installed_version" ] && $in_window; then
        if $IGNORE_WINDOW && ! $SCHEDULED; then
            log "WARNING: inside a test window, but --ignore-test-window was given. Continuing."
        else
            log "Browser is installed and we are inside a test window. Not touching it."
            return 0
        fi
    fi

    # --- cadence (LaunchDaemon only) ----------------------------------------------
    local LAST_CHECK_FILE="$STATE_DIR/last_check"
    if $SCHEDULED && ! $FORCE && [ -n "$installed_version" ] && ! $in_leadup; then
        local last=0 now age_days
        [ -f "$LAST_CHECK_FILE" ] && last=$(cat "$LAST_CHECK_FILE" 2>/dev/null)
        case "$last" in ''|*[!0-9]*) last=0 ;; esac
        now=$(date +%s)
        age_days=$(( (now - last) / 86400 ))
        if [ "$last" -gt 0 ] && [ "$age_days" -ge 0 ] && [ "$age_days" -lt "$WEEKLY_DAYS" ]; then
            log "Last successful check was $age_days day(s) ago; next check is weekly outside the lead-up. Nothing to do."
            return 0
        fi
    fi

    # --- what is the latest version? --------------------------------------------------
    local page pkg_url="" latest_version=""
    page=$(fetch "$LDB_PAGE") || { log "ERROR: could not load $LDB_PAGE. Will try again next run."; return 1; }
    find_latest_pkg "$page"     # sets FOUND_URL / FOUND_VERSION
    pkg_url="$FOUND_URL"; latest_version="$FOUND_VERSION"
    if [ -z "$pkg_url" ] || [ -z "$latest_version" ]; then
        log "ERROR: no .pkg download link found on $LDB_PAGE (page layout changed?)."
        return 1
    fi
    if ! printf '%s' "$pkg_url" | grep -Eq "$ALLOWED_HOST_RE"; then
        log "ERROR: download link is not on assessform.edu.au, refusing: $pkg_url"
        return 1
    fi
    log "Latest version online: $latest_version ($pkg_url)"

    if [ "$installed_version" = "$latest_version" ] && ! $FORCE; then
        log "Already up to date."
        date +%s > "$LAST_CHECK_FILE"
        return 0
    fi

    # --- rule: never touch a running browser ----------------------------------------------
    if pgrep -if "/Applications/NAP Locked down browser.app/Contents/MacOS/" >/dev/null 2>&1; then
        log "The browser is running right now. Not touching it; will try again next run."
        return 0
    fi

    # --- download and verify BEFORE touching anything ---------------------------------------
    WORK_DIR=$(mktemp -d /private/var/tmp/naplan_update.XXXXXX) || { log "ERROR: mktemp failed."; return 1; }
    local pkg="$WORK_DIR/NAP_LDB_$latest_version.pkg"
    log "Downloading package..."
    if ! curl -fL --silent --show-error --retry 3 --retry-delay 10 --connect-timeout 30 --max-time 1800 \
            -A "$UA" -o "$pkg" "$pkg_url" 2>>"$LOG_FILE"; then
        log "ERROR: download failed. Nothing was changed."
        return 1
    fi

    local sig
    if ! sig=$(pkgutil --check-signature "$pkg" 2>&1); then
        log "ERROR: package signature is missing or invalid. Nothing was changed."
        printf '%s\n' "$sig" >> "$LOG_FILE"
        return 1
    fi
    if ! printf '%s\n' "$sig" | grep -q "signed by a developer certificate issued by Apple" ||
       ! printf '%s\n' "$sig" | grep -Eq "Developer ID Installer: .*\($EXPECTED_TEAM_ID\)"; then
        log "ERROR: package is not signed by the expected developer (team $EXPECTED_TEAM_ID). Nothing was changed."
        printf '%s\n' "$sig" >> "$LOG_FILE"
        return 1
    fi
    log "Package signature OK ($(printf '%s\n' "$sig" | grep -m1 'Developer ID Installer' | sed 's/^ *[0-9]*\. *//'))."

    # --- Rosetta (the browser is Intel-only) ---------------------------------------------------
    if [ "$(uname -m)" = "arm64" ] && ! arch -x86_64 /usr/bin/true >/dev/null 2>&1; then
        log "Installing Rosetta..."
        softwareupdate --install-rosetta --agree-to-license >>"$LOG_FILE" 2>&1 || log "WARNING: Rosetta install failed."
    fi

    # --- swap: move the old browser aside, install, restore on failure ---------------------------
    local backup="$WORK_DIR/backup"
    mkdir -p "$backup"
    local item
    for item in "$APP" "$UNINSTALLER_APP"; do
        if [ -e "$item" ]; then
            mv "$item" "$backup/" || { log "ERROR: could not move $item aside. Nothing was changed."; restore_backup "$backup" "$APPS_DIR"; return 1; }
        fi
    done

    log "Installing version $latest_version..."
    if installer -pkg "$pkg" -target / >>"$LOG_FILE" 2>&1 && [ -d "$APP" ]; then
        local new_version
        new_version=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$APP/Contents/Info.plist" 2>/dev/null || true)
        log "Installed version is now: ${new_version:-unknown}"
        # Old per-user settings from the previous version (ACARA recommend a clean install).
        local home
        for home in /Users/*; do
            [ -d "$home" ] || continue
            rm -rf "$home/.config/NAP Locked down browser" "$home/.local/share/NAP Locked down browser" 2>/dev/null
        done
        date +%s > "$LAST_CHECK_FILE"
        log "Done."
        return 0
    fi

    log "ERROR: installation failed. Putting the previous browser back."
    rm -rf "$APP" "$UNINSTALLER_APP"
    restore_backup "$backup" "$APPS_DIR"
    return 1
}

# ----------------------------------------------------------------------------------
# helpers
# ----------------------------------------------------------------------------------

log() {
    local line
    line="$(date '+%Y-%m-%d %H:%M:%S') - $1"
    echo "$line" >> "$LOG_FILE" 2>/dev/null
    # Also show it when a person is running this in Terminal.
    if [ -t 1 ]; then echo "$line"; fi
    return 0
}

rotate_log() {
    if [ -f "$LOG_FILE" ] && [ "$(stat -f%z "$LOG_FILE" 2>/dev/null || echo 0)" -gt 1048576 ]; then
        mv -f "$LOG_FILE" "$LOG_FILE.old"
    fi
}

fetch() {
    curl -fsSL --compressed --retry 3 --retry-delay 5 --connect-timeout 20 --max-time 120 -A "$UA" "$1"
}

restore_backup() {
    local backup="$1" dest="$2" item
    for item in "$backup"/*; do
        [ -e "$item" ] && mv "$item" "$dest/"
    done
    return 0
}

# Reads the LDB download page on stdin-argument, sets FOUND_URL and FOUND_VERSION
# to the highest-versioned .pkg link.
find_latest_pkg() {
    FOUND_URL=""; FOUND_VERSION=""
    local url decoded version best=""
    while IFS= read -r url; do
        [ -z "$url" ] && continue
        decoded=$(printf '%s' "$url" | sed 's/%20/ /g')
        version=$(printf '%s' "$decoded" | sed -nE 's/.*[^0-9.]([0-9]+(\.[0-9]+)+)\.pkg$/\1/p')
        [ -z "$version" ] && continue
        best=$(printf '%s\n%s\n' "$best" "$version $url" | grep -v '^$' | sort -t. -k1,1n -k2,2n -k3,3n -k4,4n | tail -1)
    done <<EOF
$(printf '%s' "$1" | grep -oE "https://[^\"'<> ]+\.pkg" | sort -u)
EOF
    if [ -n "$best" ]; then
        FOUND_VERSION="${best%% *}"
        FOUND_URL="${best#* }"
    fi
}

# HTML of the ACARA key-dates page on stdin -> lines of "YYYYMMDD YYYYMMDD".
# The page lists a year in one table cell and "10-22 March" in the next, so the
# year is carried forward from the most recent cell that contains only a year.
parse_key_dates() {
    local endash nbsp
    endash=$(printf '\342\200\223'); nbsp=$(printf '\302\240')
    LC_ALL=C tr '>' '\n' |
    LC_ALL=C sed -e 's/<.*//' -e 's/&nbsp;/ /g' -e 's/&ndash;/-/g' -e 's/&#8211;/-/g' \
                 -e "s/$endash/-/g" -e "s/$nbsp/ /g" |
    LC_ALL=C awk '
        BEGIN {
            n = split("January February March April May June July August September October November December", m, " ")
            for (i = 1; i <= n; i++) mon[m[i]] = i
        }
        {
            line = $0
            gsub(/^[ \t\r]+|[ \t\r]+$/, "", line)
            if (line ~ /^20[0-9][0-9]$/) { year = line; next }
            if (year != "" && match(line, /[0-9][0-9]?[ ]*-[ ]*[0-9][0-9]?[ ]+(January|February|March|April|May|June|July|August|September|October|November|December)/)) {
                s = substr(line, RSTART, RLENGTH)
                gsub(/[ ]*-[ ]*/, " ", s)
                split(s, p, /[ ]+/)
                if (mon[p[3]] && p[1] + 0 >= 1 && p[1] + 0 <= p[2] + 0 && p[2] + 0 <= 31)
                    printf "%04d%02d%02d %04d%02d%02d\n", year, mon[p[3]], p[1], year, mon[p[3]], p[2]
            }
        }'
}

# conf/dates.json on stdin (one window per line) -> lines of "YYYYMMDD YYYYMMDD".
parse_dates_json() {
    LC_ALL=C sed -nE 's/.*"start"[^"]*"([0-9]{4})-([0-9]{2})-([0-9]{2})".*"end"[^"]*"([0-9]{4})-([0-9]{2})-([0-9]{2})".*/\1\2\3 \4\5\6/p'
}

# Keeps a cached list of test windows, refreshed weekly from the ACARA key-dates
# page plus this repo's conf/dates.json. Falls back to "all of March".
refresh_windows() {
    local file="$1" kd_url="$2" json_url="$3" max_age="$4"
    if [ -s "$file" ] && [ -z "$(find "$file" -mtime +"$max_age" 2>/dev/null)" ]; then
        return 0
    fi
    local tmp="$file.tmp" this_year min max
    this_year=$(date +%Y); min=$(( this_year - 1 ))0101; max=$(( this_year + 5 ))1231
    {
        fetch "$kd_url" 2>/dev/null | parse_key_dates
        fetch "$json_url" 2>/dev/null | parse_dates_json
    } | awk -v min="$min" -v max="$max" '$1 >= min && $2 <= max && $1 <= $2' | sort -u > "$tmp"

    if [ -s "$tmp" ]; then
        mv -f "$tmp" "$file"
        log "Test windows refreshed: $(tr '\n' ';' < "$file")"
    else
        rm -f "$tmp"
        if [ -s "$file" ]; then
            log "WARNING: could not refresh test windows; using the cached list."
        else
            log "WARNING: could not load test windows; assuming all of March."
            printf '%s0301 %s0331\n%s0301 %s0331\n' "$this_year" "$this_year" "$(( this_year + 1 ))" "$(( this_year + 1 ))" > "$file"
            # Old timestamp so the next run tries the real sources again.
            touch -t "$(( this_year - 1 ))01010000" "$file"
        fi
    fi
}

# Allow tests to source this file for its functions without running anything.
if [ "${NAPLAN_UPDATER_SOURCE_ONLY:-}" != "1" ]; then
    main "$@"
    exit $?
fi
