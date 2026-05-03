#!/bin/bash
# Part of lubuntu_autodarts - MIT License
# See LICENSE file for details
#
# Configure Google Chrome to launch fullscreen on user login, pointed at
# the AutoDarts web app. Per-user autostart — no sudo required.
#
# Override the URL with AUTODARTS_URL=https://my.host ./setup_chrome_autostart.sh

set -euo pipefail

ACTUAL_HOME=$(eval echo ~"${SUDO_USER:-$USER}")
AUTODARTS_URL="${AUTODARTS_URL:-https://play.autodarts.io/}"

mkdir -p "$ACTUAL_HOME/.config/autostart"

cat > "$ACTUAL_HOME/.config/autostart/google-chrome-fullscreen.desktop" <<EOF
[Desktop Entry]
Type=Application
Name=AutoDarts (Chrome)
Comment=Launch AutoDarts in fullscreen Chrome at login
Exec=google-chrome-stable --start-fullscreen --app=$AUTODARTS_URL --no-first-run --disable-features=TranslateUI --disable-session-crashed-bubble --disable-infobars
Terminal=false
StartupNotify=false
X-GNOME-Autostart-enabled=true
EOF

echo "Chrome autostart configured: $AUTODARTS_URL"
