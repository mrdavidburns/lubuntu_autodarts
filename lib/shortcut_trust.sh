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

# Register an installer-created shortcut for a retry in the user's desktop session.
ad_register_shortcut_trust() {
    local user="$1" home="$2" file="$3" source="$4" name digest
    name=$(basename "$file" .desktop)
    digest=$(sha256sum "$file") || return 1
    sudo -u "$user" mkdir -p "$home/.config/autodarts/shortcut-trust" "$home/.config/autostart" "$home/.local/bin"
    printf '%s\n' "${digest%% *}" | sudo -u "$user" tee "$home/.config/autodarts/shortcut-trust/$name.sha256" >/dev/null
    sudo -u "$user" install -m 0755 "$source/lib/refresh-shortcut-trust" "$home/.local/bin/autodarts-trust-shortcuts"
    sudo -u "$user" tee "$home/.config/autostart/autodarts-trust-shortcuts.desktop" >/dev/null <<'ENTRY'
[Desktop Entry]
Type=Application
Name=Trust AutoDarts shortcuts
Exec=sh -c '"$HOME/.local/bin/autodarts-trust-shortcuts"'
NoDisplay=true
ENTRY
}
