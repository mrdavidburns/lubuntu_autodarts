#!/bin/bash
# Part of lubuntu_autodarts - MIT License
#
# Replace ~/.config/autostart Chrome entry with a systemd --user service
# that auto-restarts Chrome if it dies. LXQt starts the service at login,
# because it does not reliably activate systemd's graphical-session.target.
#
# Override the URL with AUTODARTS_URL=https://my.host ./setup_chrome_watchdog.sh

set -euo pipefail

ACTUAL_USER="${SUDO_USER:-${USER:-$(id -un)}}"
ACTUAL_HOME=$(getent passwd "$ACTUAL_USER" | cut -d: -f6)
AUTODARTS_URL="${AUTODARTS_URL:-https://play.autodarts.io/}"
BROWSER_BIN=$(command -v google-chrome-stable || command -v chromium || command -v chromium-browser || echo "/usr/bin/google-chrome-stable")

UNIT_DIR="$ACTUAL_HOME/.config/systemd/user"
UNIT="$UNIT_DIR/autodarts-chrome.service"

sudo -u "$ACTUAL_USER" mkdir -p "$UNIT_DIR"

sudo -u "$ACTUAL_USER" tee "$UNIT" >/dev/null <<EOF
[Unit]
Description=AutoDarts Chrome (kiosk)
PartOf=graphical-session.target
After=graphical-session.target

[Service]
Type=simple
ExecStartPre=/bin/sleep 5
ExecStart=$BROWSER_BIN --start-fullscreen --app=$AUTODARTS_URL --password-store=basic --no-first-run --disable-features=TranslateUI --disable-session-crashed-bubble --disable-infobars --noerrdialogs --disable-background-timer-throttling --disable-renderer-backgrounding
Restart=always
RestartSec=5

[Install]
WantedBy=graphical-session.target
EOF

# Disable legacy user and system autostarts before installing the watchdog.
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
sudo -u "$ACTUAL_USER" -H python3 "$SCRIPT_DIR/disable_legacy_chrome_autostart.py" "$AUTODARTS_URL"

# Import the actual graphical session environment before launching Chrome.
AUTOSTART_DIR="$ACTUAL_HOME/.config/autostart"
sudo -u "$ACTUAL_USER" mkdir -p "$AUTOSTART_DIR"
sudo -u "$ACTUAL_USER" tee "$AUTOSTART_DIR/autodarts-chrome-watchdog.desktop" >/dev/null <<'EOF'
[Desktop Entry]
Type=Application
Name=AutoDarts Chrome watchdog
Exec=/bin/sh -c "systemctl --user import-environment DISPLAY XAUTHORITY WAYLAND_DISPLAY XDG_RUNTIME_DIR XDG_SESSION_TYPE XDG_CURRENT_DESKTOP DBUS_SESSION_BUS_ADDRESS; systemctl --user start autodarts-chrome.service"
EOF

# Linger lets the user unit survive logout (fine for kiosks).
loginctl enable-linger "$ACTUAL_USER" || true

# Enable for next login. Avoid running it now (no DISPLAY in setup context).
sudo -u "$ACTUAL_USER" XDG_RUNTIME_DIR="/run/user/$(id -u "$ACTUAL_USER")" \
    systemctl --user daemon-reload || true
sudo -u "$ACTUAL_USER" XDG_RUNTIME_DIR="/run/user/$(id -u "$ACTUAL_USER")" \
    systemctl --user enable autodarts-chrome.service || true

echo "Chrome watchdog installed: $UNIT"
echo "URL: $AUTODARTS_URL"
