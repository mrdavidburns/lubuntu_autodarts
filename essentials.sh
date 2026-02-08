#!/bin/bash
# Part of lubuntu_autodarts - MIT License
# See LICENSE file for details

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
bash <(curl -sL get.autodarts.io)

# 3. Configure LXQt Autostart to open Chrome fullscreen
echo "Configuring LXQt Autostart..."
# Ensure the autostart directory exists
mkdir -p ~/.config/autostart

# Create the .desktop file by calling the external script
bash "$(dirname "$0")/setup_chrome_autostart.sh"

# 4. Install System Tools (fastfetch, btop)
echo "Installing fastfetch and btop..."
sudo add-apt-repository ppa:zhangsongcui3371/fastfetch -y
sudo apt update
sudo apt install -y fastfetch btop

# 5. Desktop Customization
echo "Applying desktop customizations..."

# Set Wallpaper
# Copy the wallpaper image from the script's directory to the Pictures folder
mkdir -p ~/Pictures
if [ -f "$(dirname "$0")/images/four-darts-desktop-wallpaper.webp" ]; then
    cp "$(dirname "$0")/images/four-darts-desktop-wallpaper.webp" ~/Pictures/
    # Apply the wallpaper
    pcmanfm-qt --set-wallpaper="$HOME/Pictures/four-darts-desktop-wallpaper.webp" --wallpaper-mode=stretch
else
    echo "Warning: Wallpaper file not found in images directory."
fi

# Configure LXQt Panel (Auto-hide, Icon, Text)
mkdir -p ~/.local/share/icons
if [ -f "$(dirname "$0")/images/autodarts_logo.png" ]; then
    cp "$(dirname "$0")/images/autodarts_logo.png" ~/.local/share/icons/
else
    echo "Warning: autodarts_logo.png not found in images directory."
fi

# Modifies the panel configuration
if [ -f ~/.config/lxqt/panel.conf ]; then
    # Create backup just in case
    cp ~/.config/lxqt/panel.conf ~/.config/lxqt/panel.conf.bak
    
    # Enable auto-hide
    sed -i 's/hidable=false/hidable=true/g' ~/.config/lxqt/panel.conf
    
    # Set Start Menu Icon and Text
    LOGO_PATH="$HOME/.local/share/icons/autodarts_logo.png"
    # Escape slashes for sed
    ESCAPED_LOGO_PATH=$(echo "$LOGO_PATH" | sed 's/\//\\\//g')
    
    # Update icon in [mainmenu] section
    sed -i "/^\[mainmenu\]/,/^\[/ s/^icon=.*/icon=$ESCAPED_LOGO_PATH/" ~/.config/lxqt/panel.conf
    # Update title in [mainmenu] section
    sed -i "/^\[mainmenu\]/,/^\[/ s/^title=.*/title=AutoDarts/" ~/.config/lxqt/panel.conf

    # Add Google Chrome and QTerminal to Quick Launch
    python3 "$(dirname "$0")/update_quick_launch.py"
else
    echo "Warning: LXQt panel config not found. Panel customizations not applied."
fi

# 6. Install GRUB Theme
echo "Setting up GRUB Theme for boot menu branding..."
bash "$(dirname "$0")/setup_grub_theme.sh"

# 7. Install Plymouth Theme
echo "Setting up Plymouth Theme and Boot Options..."
bash "$(dirname "$0")/setup_plymouth_theme.sh"

echo "Installation and configuration complete."
