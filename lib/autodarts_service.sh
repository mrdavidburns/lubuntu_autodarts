#!/bin/bash
# Configure a single user-owned AutoDarts board service in either install mode.
ad_systemd_running() { [ -d /run/systemd/system ]; }

ad_setup_autodarts_service() {
    local user="$1" home="$2" uid unit_dir unit_file
    uid=$(id -u "$user") || return 1
    unit_dir="$home/.config/systemd/user"
    unit_file="$unit_dir/autodarts.service"
    if [ ! -x "$home/.local/bin/autodarts" ]; then
        ad_err "AutoDarts headless command not found at $home/.local/bin/autodarts."
        return 1
    fi
    if systemctl is-active --quiet autodarts.service; then
        ad_err "A system-wide AutoDarts service is already running; stop it before enabling the user service."
        return 1
    fi
    if ! ad_systemd_running; then
        ad_err "systemd is not running; cannot enable the AutoDarts board service."
        return 1
    fi
    loginctl enable-linger "$user" || return 1
    systemctl start "user@$uid.service" || return 1
    # A unit may also be installed outside the user's configuration directory.
    local load_state
    load_state=$(sudo -u "$user" -H env XDG_RUNTIME_DIR="/run/user/$uid" \
        DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/$uid/bus" \
        systemctl --user show autodarts.service --property=LoadState --value) || return 1
    case "$load_state" in
        loaded | not-found) ;;
        *)
            ad_err "AutoDarts user service has unexpected load state: ${load_state:-unknown}."
            return 1
            ;;
    esac
    if [ ! -e "$unit_file" ] && [ ! -L "$unit_file" ] && [ "$load_state" = not-found ]; then
        sudo -u "$user" mkdir -p "$unit_dir" || return 1
        sudo -u "$user" tee "$unit_file" >/dev/null <<'UNIT' || return 1
[Unit]
Description=AutoDarts headless board
After=network.target

[Service]
Type=simple
ExecStart=%h/.local/bin/autodarts run
Restart=always
RestartSec=5

[Install]
WantedBy=default.target
UNIT
    else
        echo "Using the existing AutoDarts user service."
    fi
    sudo -u "$user" mkdir -p "$unit_dir/autodarts.service.d" || return 1
    sudo -u "$user" tee "$unit_dir/autodarts.service.d/50-autodarts-supervision.conf" >/dev/null <<'UNIT' || return 1
[Service]
Restart=always
RestartSec=5
UNIT
    sudo -u "$user" -H env XDG_RUNTIME_DIR="/run/user/$uid" \
        DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/$uid/bus" \
        systemctl --user daemon-reload || return 1
    sudo -u "$user" -H env XDG_RUNTIME_DIR="/run/user/$uid" \
        DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/$uid/bus" \
        systemctl --user enable --now autodarts.service || return 1
    sudo -u "$user" -H env XDG_RUNTIME_DIR="/run/user/$uid" \
        DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/$uid/bus" \
        systemctl --user is-active --quiet autodarts.service || {
        ad_err "AutoDarts service did not start; check journalctl --user -u autodarts.service."
        return 1
    }
}
