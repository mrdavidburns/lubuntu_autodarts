#!/bin/bash
# Trust only the launcher passed by the installer, using the user's GVFS session.
ad_trust_shortcut() {
    local user="$1" file="$2" uid runtime
    uid=$(id -u "$user") || return 1
    runtime="/run/user/$uid"
    if [ -S "$runtime/bus" ]; then
        sudo -u "$user" -H env XDG_RUNTIME_DIR="$runtime" \
            DBUS_SESSION_BUS_ADDRESS="unix:path=$runtime/bus" \
            gio set "$file" metadata::trust true
    else
        sudo -u "$user" -H dbus-run-session -- gio set "$file" metadata::trust true
    fi
}
