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
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck disable=SC1091
. "$SCRIPT_DIR/lib/display_manager.sh"
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

DISPLAY_MANAGER=$(ad_display_manager)
if [ "$DISPLAY_MANAGER" = sddm ]; then
    # autologin group exists on Lubuntu by default; create if missing.
    if ! getent group autologin >/dev/null; then
        groupadd autologin
    fi
    usermod -aG autologin "$USERNAME"

    SESSION=$(ad_sddm_session "$CONF_FILE" /var/lib/sddm/state.conf /usr/share/xsessions /usr/share/wayland-sessions) || {
        echo "Warning: No supported LXQt session found; skipping SDDM autologin setup." >&2
        exit 0
    }

    mkdir -p "$SDDM_CONF_DIR"
    cat >"$CONF_FILE" <<EOF
[Autologin]
User=$USERNAME
Session=$SESSION

[General]
HaltCommand=/usr/bin/systemctl poweroff
RebootCommand=/usr/bin/systemctl reboot
EOF
    chmod 644 "$CONF_FILE"
    echo "SDDM autologin configured for $USERNAME ($SESSION) → $CONF_FILE"
elif [ "$DISPLAY_MANAGER" = lightdm ]; then
    if getent group autologin >/dev/null; then
        usermod -aG autologin "$USERNAME"
    fi
    mkdir -p /etc/lightdm/lightdm.conf.d
    LIGHTDM_CONF="/etc/lightdm/lightdm.conf.d/10-autodarts-autologin.conf"
    cat >"$LIGHTDM_CONF" <<EOF
[Seat:*]
autologin-user=$USERNAME
autologin-user-timeout=0
EOF
    chmod 644 "$LIGHTDM_CONF"
    echo "LightDM autologin configured for $USERNAME → $LIGHTDM_CONF"
elif [ "$DISPLAY_MANAGER" = gdm3 ] || [ "$DISPLAY_MANAGER" = gdm ]; then
    GDM_CONF="/etc/gdm3/custom.conf"
    [ -f "$GDM_CONF" ] || GDM_CONF="/etc/gdm/custom.conf"
    if grep -q '^\[daemon\]' "$GDM_CONF"; then
        sed -i '/^AutomaticLoginEnable=/d;/^AutomaticLogin=/d' "$GDM_CONF"
        sed -i "/^\[daemon\]/a AutomaticLoginEnable=True\nAutomaticLogin=$USERNAME" "$GDM_CONF"
    else
        cat >>"$GDM_CONF" <<EOF

[daemon]
AutomaticLoginEnable=True
AutomaticLogin=$USERNAME
EOF
    fi
    echo "GDM autologin configured for $USERNAME → $GDM_CONF"
else
    echo "Warning: No supported display manager (sddm/lightdm/gdm3) installed. Skipping autologin setup."
    exit 0
fi
