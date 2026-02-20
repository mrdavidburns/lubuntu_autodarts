#!/bin/bash
# Part of lubuntu_autodarts - MIT License
# See LICENSE file for details

# Determine actual user and home directory (handles sudo usage)
ACTUAL_USER=${SUDO_USER:-$USER}
ACTUAL_HOME=$(eval echo ~"$ACTUAL_USER")

# Capture absolute script directory so it remains valid after any cd operations
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# Update package list and install prerequisites
sudo apt update
sudo apt install -y curl wget software-properties-common

# 1. Install Google Chrome
echo "Installing Google Chrome..."
wget https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb
# Attempt to install, fix dependencies if it fails
sudo dpkg -i google-chrome-stable_current_amd64.deb || sudo apt --fix-broken install -y
# Cleanup
rm google-chrome-stable_current_amd64.deb

# 2. Install AutoDarts
echo "Installing AutoDarts..."
# Run installer with actual user context so group memberships are assigned correctly
USER="$ACTUAL_USER" HOME="$ACTUAL_HOME" bash <(curl -sL get.autodarts.io)

# 3. Configure LXQt Autostart to open Chrome fullscreen
echo "Configuring LXQt Autostart..."
# Ensure the autostart directory exists
mkdir -p "$ACTUAL_HOME/.config/autostart"

# Create the .desktop file by calling the external script
HOME="$ACTUAL_HOME" bash "$SCRIPT_DIR/setup_chrome_autostart.sh"

# 4. Install System Tools (fastfetch, btop)
echo "Installing fastfetch and btop..."
sudo add-apt-repository ppa:zhangsongcui3371/fastfetch -y
sudo apt update
sudo apt install -y fastfetch btop

# 5. Install SUIT (Simple UI Toolkit)
echo "Installing SUIT (Simple UI Toolkit)..."

# Install system dependencies for SUIT
sudo apt install -y python3-tk python3-dbus python3-pip python3-venv git libdbus-1-dev

# Clone SUIT repository to user's home directory
SUIT_DIR="$ACTUAL_HOME/SUIT"
if [ -d "$SUIT_DIR" ]; then
    echo "SUIT directory already exists, updating..."
    sudo -u "$ACTUAL_USER" git -C "$SUIT_DIR" pull || {
        echo "Warning: Failed to update SUIT repository."
    }
else
    sudo -u "$ACTUAL_USER" git clone https://github.com/IteraThor/SUIT.git "$SUIT_DIR" || {
        echo "Warning: Failed to clone SUIT repository."
    }
fi

# Create desktop launcher if SUIT was cloned successfully
if [ -d "$SUIT_DIR" ]; then
    sudo -u "$ACTUAL_USER" bash -c 'cd "$1" && python3 create_launcher.py' -- "$SUIT_DIR" || {
        echo "Warning: Failed to create SUIT desktop launcher."
    }
    echo "SUIT installation complete. Launcher created on Desktop."
else
    echo "Warning: SUIT directory not found, skipping launcher creation."
fi

# 6. Desktop Customization
echo "Applying desktop customizations..."

# Set Wallpaper
# Copy the wallpaper image from the script's directory to the Pictures folder
mkdir -p "$ACTUAL_HOME/Pictures"
if [ -f "$SCRIPT_DIR/images/four-darts-desktop-wallpaper.webp" ]; then
    cp "$SCRIPT_DIR/images/four-darts-desktop-wallpaper.webp" "$ACTUAL_HOME/Pictures/"
    # Apply the wallpaper
    pcmanfm-qt --set-wallpaper="$ACTUAL_HOME/Pictures/four-darts-desktop-wallpaper.webp" --wallpaper-mode=stretch
else
    echo "Warning: Wallpaper file not found in images directory."
fi

# Configure LXQt Panel (Auto-hide, Icon, Text)
mkdir -p "$ACTUAL_HOME/.local/share/icons"
if [ -f "$SCRIPT_DIR/images/autodarts_logo.png" ]; then
    cp "$SCRIPT_DIR/images/autodarts_logo.png" "$ACTUAL_HOME/.local/share/icons/"
else
    echo "Warning: autodarts_logo.png not found in images directory."
fi

# Modifies the panel configuration
if [ -f "$ACTUAL_HOME/.config/lxqt/panel.conf" ]; then
    # Create backup just in case
    cp "$ACTUAL_HOME/.config/lxqt/panel.conf" "$ACTUAL_HOME/.config/lxqt/panel.conf.bak"
    
    # Enable auto-hide
    sed -i 's/hidable=false/hidable=true/g' "$ACTUAL_HOME/.config/lxqt/panel.conf"
    
    # Set Start Menu Icon and Text
    LOGO_PATH="$ACTUAL_HOME/.local/share/icons/autodarts_logo.png"
    # Escape slashes for sed
    ESCAPED_LOGO_PATH=$(echo "$LOGO_PATH" | sed 's/\//\\\//g')
    
    # Update icon in [mainmenu] section
    sed -i "/^\[mainmenu\]/,/^\[/ s/^icon=.*/icon=$ESCAPED_LOGO_PATH/" "$ACTUAL_HOME/.config/lxqt/panel.conf"
    # Update title in [mainmenu] section
    sed -i "/^\[mainmenu\]/,/^\[/ s/^title=.*/title=AutoDarts/" "$ACTUAL_HOME/.config/lxqt/panel.conf"

    # Add Google Chrome and QTerminal to Quick Launch
    # HOME is set so os.path.expanduser resolves to the actual user's config
    if [ -f "$SCRIPT_DIR/update_quick_launch.py" ]; then
        HOME="$ACTUAL_HOME" python3 "$SCRIPT_DIR/update_quick_launch.py"
    else
        echo "Warning: update_quick_launch.py not found, skipping quick launch setup."
    fi
else
    echo "Warning: LXQt panel config not found. Panel customizations not applied."
fi

# 7. Install GRUB Theme
echo "Setting up GRUB Theme for boot menu branding..."
if [ -f "$SCRIPT_DIR/setup_grub_theme.sh" ]; then
    bash "$SCRIPT_DIR/setup_grub_theme.sh"
else
    echo "Warning: setup_grub_theme.sh not found, skipping GRUB theme setup."
fi

# 8. Install Plymouth Theme
echo "Setting up Plymouth Theme and Boot Options..."
if [ -f "$SCRIPT_DIR/setup_plymouth_theme.sh" ]; then
    bash "$SCRIPT_DIR/setup_plymouth_theme.sh"
else
    echo "Warning: setup_plymouth_theme.sh not found, skipping Plymouth theme setup."
fi

echo "Installation and configuration complete."
