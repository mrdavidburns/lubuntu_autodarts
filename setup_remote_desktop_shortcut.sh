#!/bin/bash
# Create a RustDesk desktop launcher after a successful package installation.
set -euo pipefail

if [ "$EUID" -ne 0 ]; then
    exec sudo -E "$0" "$@"
fi

ACTUAL_USER="${SUDO_USER:-${USER:-$(id -un)}}"
ACTUAL_HOME=$(getent passwd "$ACTUAL_USER" | cut -d: -f6)
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck disable=SC1091
. "$SCRIPT_DIR/lib/shortcut_trust.sh"
DESKTOP="$ACTUAL_HOME/Desktop"
# Remove the launcher created by older versions of this installer.
rm -f "$DESKTOP/Chrome_Remote_Desktop.desktop"
if ! dpkg-query -W -f='${Status}' rustdesk 2>/dev/null | grep -qx 'install ok installed'; then
    echo "RustDesk is not installed; skipping desktop shortcut."
    exit 0
fi
SHORTCUT="$DESKTOP/RustDesk.desktop"
sudo -u "$ACTUAL_USER" mkdir -p "$DESKTOP"
sudo -u "$ACTUAL_USER" tee "$SHORTCUT" >/dev/null <<'ENTRY'
[Desktop Entry]
Version=1.0
Type=Application
Name=RustDesk
Comment=Remote desktop access
Exec=rustdesk
Icon=rustdesk
Terminal=false
StartupNotify=false
Categories=Network;RemoteAccess;
ENTRY
chmod +x "$SHORTCUT"
if ! ad_trust_shortcut "$ACTUAL_USER" "$SHORTCUT"; then
    echo "Warning: could not mark $SHORTCUT trusted; use 'Trust this executable' on the desktop." >&2
fi
echo "RustDesk shortcut written to $SHORTCUT."
