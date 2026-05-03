#!/bin/bash
# Part of lubuntu_autodarts - MIT License
# See LICENSE file for details
#
# Configure SDDM (Lubuntu's display manager) to auto-login the kiosk user
# straight to LXQt. Without this the AutoDarts Chrome autostart never fires
# until somebody types a password.
#
# Usage: sudo ./setup_autologin.sh [username]
#   Default username = $SUDO_USER, falls back to $USER.

set -euo pipefail

USERNAME="${1:-${SUDO_USER:-${USER:-$(id -un)}}}"
SDDM_CONF_DIR="/etc/sddm.conf.d"
CONF_FILE="$SDDM_CONF_DIR/10-autodarts-autologin.conf"

if [ "$EUID" -ne 0 ]; then
    echo "Error: must run as root (use sudo)." >&2
    exit 1
fi

if ! id "$USERNAME" >/dev/null 2>&1; then
    echo "Error: user '$USERNAME' does not exist." >&2
    exit 1
fi

if ! command -v sddm >/dev/null 2>&1; then
    echo "Warning: SDDM not installed. Skipping autologin setup."
    exit 0
fi

# autologin group exists on Lubuntu by default; create if missing.
if ! getent group autologin >/dev/null; then
    groupadd autologin
fi
usermod -aG autologin "$USERNAME"

mkdir -p "$SDDM_CONF_DIR"
cat >"$CONF_FILE" <<EOF
[Autologin]
User=$USERNAME
Session=lxqt.desktop

[General]
HaltCommand=/usr/bin/systemctl poweroff
RebootCommand=/usr/bin/systemctl reboot
EOF
chmod 644 "$CONF_FILE"

echo "SDDM autologin configured for $USERNAME → $CONF_FILE"
