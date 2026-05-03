#!/bin/bash
# Part of lubuntu_autodarts - MIT License
#
# Bind Ctrl+Alt+Q to /usr/local/bin/exit-kiosk via the LXQt global-shortcuts
# config (lxqt-globalkeysrc). Lets non-technical operators escape kiosk mode
# without dropping to a TTY.

set -euo pipefail

if [ "$EUID" -ne 0 ]; then
    exec sudo -E "$0" "$@"
fi

ACTUAL_USER="${SUDO_USER:-$USER}"
ACTUAL_HOME=$(eval echo ~"$ACTUAL_USER")
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# Install the helper system-wide so it's reachable for any session.
install -m 0755 "$SCRIPT_DIR/bin/exit-kiosk" /usr/local/bin/exit-kiosk

CONF="$ACTUAL_HOME/.config/lxqt/globalkeyshortcuts.conf"
sudo -u "$ACTUAL_USER" mkdir -p "$(dirname "$CONF")"
[ -f "$CONF" ] || sudo -u "$ACTUAL_USER" touch "$CONF"

# Strip any pre-existing AutoDartsExitKiosk block so the script stays idempotent.
sudo -u "$ACTUAL_USER" sed -i '/^\[AutoDartsExitKiosk\]/,/^$/d' "$CONF"

sudo -u "$ACTUAL_USER" tee -a "$CONF" >/dev/null <<'EOF'

[AutoDartsExitKiosk]
Enabled=true
Comment=Stop kiosk Chrome and return to LXQt desktop
Exec=/usr/local/bin/exit-kiosk
Shortcut=Ctrl+Alt+Q
EOF

echo "Exit hotkey configured: Ctrl+Alt+Q → /usr/local/bin/exit-kiosk"
echo "Log out + back in for LXQt to reload globalkeyshortcuts."
