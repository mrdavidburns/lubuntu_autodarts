#!/bin/bash
# Create a launcher for Chrome Remote Desktop's web interface.
set -euo pipefail

if [ "$EUID" -ne 0 ]; then
    exec sudo -E "$0" "$@"
fi

if ! dpkg-query -W -f='${Status}' chrome-remote-desktop 2>/dev/null | grep -qx 'install ok installed'; then
    echo "Chrome Remote Desktop host is not installed; skipping desktop shortcut."
    exit 0
fi

ACTUAL_USER="${SUDO_USER:-${USER:-$(id -un)}}"
ACTUAL_HOME=$(getent passwd "$ACTUAL_USER" | cut -d: -f6)
DESKTOP="$ACTUAL_HOME/Desktop"
SHORTCUT="$DESKTOP/Chrome_Remote_Desktop.desktop"
sudo -u "$ACTUAL_USER" mkdir -p "$DESKTOP"
sudo -u "$ACTUAL_USER" tee "$SHORTCUT" >/dev/null <<'EOF'
[Desktop Entry]
Version=1.0
Type=Application
Name=Chrome Remote Desktop
Comment=Set up or access Chrome Remote Desktop
Exec=google-chrome-stable https://remotedesktop.google.com/access
Icon=network-workgroup
Terminal=false
StartupNotify=false
Categories=Network;RemoteAccess;
EOF
chmod +x "$SHORTCUT"
sudo -u "$ACTUAL_USER" gio set "$SHORTCUT" metadata::trusted true 2>/dev/null || true
echo "Chrome Remote Desktop shortcut written to $SHORTCUT."
