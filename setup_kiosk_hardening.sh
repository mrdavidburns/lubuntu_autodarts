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
ACTUAL_HOME=$(getent passwd "$ACTUAL_USER" | cut -d: -f6)

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

# 9. Power button → poweroff (no menu). Players hit it; make it work.
LOGIND_DROPIN=/etc/systemd/logind.conf.d/00-autodarts.conf
mkdir -p "$(dirname "$LOGIND_DROPIN")"
cat > "$LOGIND_DROPIN" <<'EOF'
[Login]
HandlePowerKey=poweroff
HandlePowerKeyLongPress=reboot
HandleSuspendKey=ignore
HandleHibernateKey=ignore
HandleLidSwitch=ignore
HandleLidSwitchExternalPower=ignore
HandleLidSwitchDocked=ignore
# Single VT — Ctrl+Alt+F2..F6 give nothing to escape to.
NAutoVTs=1
ReserveVT=1
EOF
systemctl restart systemd-logind || true

# 10. UFW: block all inbound, allow Tailscale + mDNS if present, allow all outbound.
if ! command -v ufw >/dev/null 2>&1; then
    apt install -y ufw
fi
ufw --force reset >/dev/null
ufw default deny incoming
ufw default allow outgoing
# mDNS for AutoDarts board discovery on LAN.
ufw allow 5353/udp comment "mDNS"
# Tailscale (only matters if it's installed; rule is harmless otherwise).
ufw allow in on tailscale0 comment "Tailscale tunnel"
ufw --force enable

# 11. Sudoers lockdown: passwordless sudo only for kiosk-relevant commands.
SUDOERS_FILE=/etc/sudoers.d/10-autodarts-kiosk
cat > "$SUDOERS_FILE" <<EOF
# Managed by lubuntu_autodarts. Do not edit by hand.
# Allows the kiosk user to run a small, kiosk-relevant set of root commands
# without a password. Does NOT grant general sudo.
Cmnd_Alias AUTODARTS_OPS = \\
    /bin/systemctl reboot, \\
    /bin/systemctl poweroff, \\
    /usr/bin/systemctl reboot, \\
    /usr/bin/systemctl poweroff, \\
    /usr/local/bin/autodarts-self-update, \\
    /usr/local/bin/autodarts-backup, \\
    /usr/local/bin/sound-test
$ACTUAL_USER ALL=(root) NOPASSWD: AUTODARTS_OPS
EOF
chmod 0440 "$SUDOERS_FILE"
visudo -cf "$SUDOERS_FILE" >/dev/null

# 12. Brightness keybinds: Fn keys + LXQt globalkeyshortcuts → xbacklight.
if ! command -v xbacklight >/dev/null 2>&1; then
    apt install -y xbacklight
fi
GKS="$ACTUAL_HOME/.config/lxqt/globalkeyshortcuts.conf"
sudo -u "$ACTUAL_USER" mkdir -p "$(dirname "$GKS")"
[ -f "$GKS" ] || sudo -u "$ACTUAL_USER" touch "$GKS"
sudo -u "$ACTUAL_USER" sed -i '/^\[AutoDartsBrightness/,/^$/d' "$GKS"
sudo -u "$ACTUAL_USER" tee -a "$GKS" >/dev/null <<'EOF'

[AutoDartsBrightnessUp]
Enabled=true
Comment=Increase screen brightness
Exec=xbacklight -inc 10
Shortcut=XF86MonBrightnessUp

[AutoDartsBrightnessDown]
Enabled=true
Comment=Decrease screen brightness
Exec=xbacklight -dec 10
Shortcut=XF86MonBrightnessDown
EOF

ad_ok() { printf '\033[32m✓\033[0m %s\n' "$*"; }
ad_ok "Power button → poweroff; long-press → reboot."
ad_ok "TTY switching restricted (NAutoVTs=1)."
ad_ok "ufw active (deny incoming, mDNS + Tailscale allowed)."
ad_ok "Sudoers lockdown installed: $SUDOERS_FILE"
ad_ok "Brightness keys bound (XF86MonBrightnessUp/Down)."

echo "Kiosk hardening complete."
