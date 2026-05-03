#!/bin/bash
# Part of lubuntu_autodarts - MIT License
#
# Replace ~/.config/autostart Chrome entry with a systemd --user service
# that auto-restarts Chrome if it dies. Pinned to graphical-session.target
# so it fires on login and rides through crashes.
#
# Override the URL with AUTODARTS_URL=https://my.host ./setup_chrome_watchdog.sh

set -euo pipefail

ACTUAL_USER="${SUDO_USER:-$USER}"
ACTUAL_HOME=$(getent passwd "$ACTUAL_USER" | cut -d: -f6)
AUTODARTS_URL="${AUTODARTS_URL:-https://play.autodarts.io/}"

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
Environment=DISPLAY=:0
ExecStartPre=/bin/sleep 5
ExecStart=/usr/bin/google-chrome-stable --start-fullscreen --app=$AUTODARTS_URL --no-first-run --disable-features=TranslateUI --disable-session-crashed-bubble --disable-infobars --noerrdialogs
Restart=always
RestartSec=5

[Install]
WantedBy=graphical-session.target
EOF

# Drop the old autostart .desktop so the two don't fight.
rm -f "$ACTUAL_HOME/.config/autostart/google-chrome-fullscreen.desktop"

# Linger lets the user unit survive logout (fine for kiosks).
loginctl enable-linger "$ACTUAL_USER" || true

# Enable for next login. Avoid running it now (no DISPLAY in setup context).
sudo -u "$ACTUAL_USER" XDG_RUNTIME_DIR="/run/user/$(id -u "$ACTUAL_USER")" \
    systemctl --user daemon-reload || true
sudo -u "$ACTUAL_USER" XDG_RUNTIME_DIR="/run/user/$(id -u "$ACTUAL_USER")" \
    systemctl --user enable autodarts-chrome.service || true

echo "Chrome watchdog installed: $UNIT"
echo "URL: $AUTODARTS_URL"
