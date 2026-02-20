#!/bin/bash
# Part of lubuntu_autodarts - MIT License
# See LICENSE file for details

# Configure Google Chrome to launch fullscreen on user login
# Uses LXQt user-specific autostart directory (~/.config/autostart/)
# This approach:
#   - Does not require sudo privileges
#   - Affects only the current user
#   - Follows LXQt best practices
#   - Is easy to modify or remove

# Determine actual user home directory (handles sudo usage)
ACTUAL_HOME=$(eval echo ~"${SUDO_USER:-$USER}")

# Ensure the autostart directory exists
mkdir -p "$ACTUAL_HOME/.config/autostart"

# Create the .desktop file
cat <<EOF > "$ACTUAL_HOME/.config/autostart/google-chrome-fullscreen.desktop"
[Desktop Entry]
Type=Application
Name=Google Chrome Fullscreen
Exec=google-chrome-stable --start-fullscreen
Terminal=false
StartupNotify=false
EOF
