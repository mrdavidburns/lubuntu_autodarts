#!/bin/bash
# Part of lubuntu_autodarts - MIT License
#
# Kiosk hardening: disable screen blanking/sleep, suppress popups, install
# fwupd/unclutter, lock LXQt panel, verify NTP, disable Bluetooth tray.

set -euo pipefail

if [ "$EUID" -ne 0 ]; then
    exec sudo -E "$0" "$@"
fi

ACTUAL_USER="${SUDO_USER:-$USER}"
ACTUAL_HOME=$(eval echo ~"$ACTUAL_USER")

apt update
apt install -y unclutter xdotool fwupd

# 1. Block sleep/suspend/hibernate at the systemd level.
systemctl mask sleep.target suspend.target hibernate.target hybrid-sleep.target || true

# 2. NTP — Lubuntu uses systemd-timesyncd by default; ensure it's active.
if systemctl list-unit-files | grep -q '^systemd-timesyncd'; then
    timedatectl set-ntp true || true
    systemctl enable --now systemd-timesyncd || true
fi

# 3. Per-user X session tweaks: no screen blanking, no DPMS, autostart unclutter.
USER_AUTOSTART="$ACTUAL_HOME/.config/autostart"
sudo -u "$ACTUAL_USER" mkdir -p "$USER_AUTOSTART"

cat > "$USER_AUTOSTART/autodarts-xset.desktop" <<'EOF'
[Desktop Entry]
Type=Application
Name=AutoDarts X session tweaks
Comment=Disable screen blanking and DPMS
Exec=sh -c "xset s off; xset -dpms; xset s noblank"
Terminal=false
StartupNotify=false
X-GNOME-Autostart-enabled=true
EOF
chown "$ACTUAL_USER:$ACTUAL_USER" "$USER_AUTOSTART/autodarts-xset.desktop"

cat > "$USER_AUTOSTART/unclutter.desktop" <<'EOF'
[Desktop Entry]
Type=Application
Name=unclutter
Comment=Hide cursor when idle
Exec=unclutter -idle 3 -root
Terminal=false
StartupNotify=false
X-GNOME-Autostart-enabled=true
EOF
chown "$ACTUAL_USER:$ACTUAL_USER" "$USER_AUTOSTART/unclutter.desktop"

# 4. Lock LXQt panel against accidental drag/edit.
PANEL_CONF="$ACTUAL_HOME/.config/lxqt/panel.conf"
if [ -f "$PANEL_CONF" ]; then
    sudo -u "$ACTUAL_USER" sed -i '/^lockPanel=/d' "$PANEL_CONF"
    sudo -u "$ACTUAL_USER" sh -c "echo 'lockPanel=true' >> '$PANEL_CONF'"
fi

# 5. Suppress Lubuntu first-run, update notifier, snap nags.
NOTIFIER_DIR="$ACTUAL_HOME/.config/autostart"
for unit in update-notifier snap-store-popup gnome-software; do
    f="$NOTIFIER_DIR/$unit.desktop"
    if [ ! -f "$f" ]; then
        sudo -u "$ACTUAL_USER" tee "$f" >/dev/null <<EOF
[Desktop Entry]
Type=Application
Name=$unit (disabled)
Exec=true
Hidden=true
X-GNOME-Autostart-enabled=false
EOF
    fi
done

# 6. Disable update-manager system-wide popup.
if [ -f /etc/xdg/autostart/update-notifier.desktop ]; then
    sed -i 's/^X-GNOME-Autostart-enabled=.*/X-GNOME-Autostart-enabled=false/' \
        /etc/xdg/autostart/update-notifier.desktop || true
fi

# 7. Bluetooth — disable if no obvious need (can re-enable later).
if systemctl list-unit-files | grep -q '^bluetooth.service'; then
    systemctl disable --now bluetooth.service || true
fi

# 8. Notifications — DnD via LXQt notification daemon config.
NOTIFY_CONF="$ACTUAL_HOME/.config/lxqt/notifications.conf"
sudo -u "$ACTUAL_USER" mkdir -p "$(dirname "$NOTIFY_CONF")"
sudo -u "$ACTUAL_USER" tee "$NOTIFY_CONF" >/dev/null <<'EOF'
[General]
DoNotDisturb=true
EOF

echo "Kiosk hardening complete: blanking off, sleep masked, popups suppressed, panel locked."
