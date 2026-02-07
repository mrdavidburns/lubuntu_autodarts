#!/bin/bash

# Ensure the autostart directory exists
mkdir -p ~/.config/autostart

# Create the .desktop file
cat <<EOF > ~/.config/autostart/google-chrome-fullscreen.desktop
[Desktop Entry]
Type=Application
Name=Google Chrome Fullscreen
Exec=google-chrome-stable --start-fullscreen
Terminal=false
StartupNotify=false
EOF
