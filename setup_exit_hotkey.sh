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

ACTUAL_USER="${SUDO_USER:-${USER:-$(id -un)}}"
ACTUAL_HOME=$(getent passwd "$ACTUAL_USER" | cut -d: -f6)
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

. "$SCRIPT_DIR/lib/common.sh"
DESKTOP=$(ad_desktop "$ACTUAL_USER")

# Install the helper system-wide so it's reachable for any session.
install -m 0755 "$SCRIPT_DIR/bin/exit-kiosk" /usr/local/bin/exit-kiosk

if [ "$DESKTOP" = labwc ]; then
    CONF="$ACTUAL_HOME/.config/labwc/rc.xml"
    sudo -u "$ACTUAL_USER" mkdir -p "$(dirname "$CONF")"
    if [ ! -f "$CONF" ]; then
        if [ -f /etc/xdg/labwc/rc.xml ]; then
            sudo -u "$ACTUAL_USER" cp /etc/xdg/labwc/rc.xml "$CONF"
        else
            echo '<labwc_config><keyboard><default /></keyboard></labwc_config>' | sudo -u "$ACTUAL_USER" tee "$CONF" >/dev/null
        fi
    fi
    sudo -u "$ACTUAL_USER" python3 "$SCRIPT_DIR/configure_labwc.py" "$CONF"
    echo "Exit hotkey configured for labwc: Ctrl+Alt+Q. Log out and back in to apply."
    exit 0
elif [ "$DESKTOP" != lxqt ]; then
    echo "WARN: Desktop '$DESKTOP' does not have a supported exit hotkey; run /usr/local/bin/exit-kiosk manually." >&2
    exit 0
fi

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
