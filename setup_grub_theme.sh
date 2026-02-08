#!/bin/bash
# Part of lubuntu_autodarts - MIT License
# See LICENSE file for details

# Script to install AUTODARTS GRUB theme
# Adds branded boot menu to GRUB bootloader

GRUB_THEME_DIR="/boot/grub/themes/autodarts"
REPO_DIR="$(dirname "$0")"
GRUB_CFG="/etc/default/grub"

echo "Installing AUTODARTS GRUB theme..."

# 1. Create GRUB theme directory
if [ -d "$REPO_DIR/grub_theme" ]; then
    sudo mkdir -p "$GRUB_THEME_DIR"
    
    # 2. Generate background image if needed
    if [ ! -f "$REPO_DIR/grub_theme/background.png" ]; then
        echo "Generating GRUB background image..."
        bash "$REPO_DIR/grub_theme/create_background.sh"
    fi
    
    # 3. Copy theme files
    if [ -f "$REPO_DIR/grub_theme/theme.txt" ]; then
        sudo cp "$REPO_DIR/grub_theme/theme.txt" "$GRUB_THEME_DIR/"
        echo "Copied theme.txt"
    else
        echo "Error: theme.txt not found"
        exit 1
    fi
    
    if [ -f "$REPO_DIR/grub_theme/background.png" ]; then
        sudo cp "$REPO_DIR/grub_theme/background.png" "$GRUB_THEME_DIR/"
        echo "Copied background.png"
    else
        echo "Warning: background.png not found, GRUB theme may not display correctly"
    fi
    
    if [ -f "$REPO_DIR/grub_theme/autodarts_logo.png" ]; then
        sudo cp "$REPO_DIR/grub_theme/autodarts_logo.png" "$GRUB_THEME_DIR/"
        echo "Copied autodarts_logo.png"
    else
        echo "Warning: autodarts_logo.png not found"
    fi
    
    # 4. Update GRUB configuration
    if [ -f "$GRUB_CFG" ]; then
        echo "Updating GRUB configuration..."
        
        # Backup
        sudo cp "$GRUB_CFG" "$GRUB_CFG.bak.grub-theme.$(date +%F_%H-%M-%S)"
        
        # Set GRUB theme
        if grep -q "^GRUB_THEME=" "$GRUB_CFG"; then
            sudo sed -i "s|^GRUB_THEME=.*|GRUB_THEME=\"$GRUB_THEME_DIR/theme.txt\"|" "$GRUB_CFG"
        else
            echo "GRUB_THEME=\"$GRUB_THEME_DIR/theme.txt\"" | sudo tee -a "$GRUB_CFG"
        fi
        
        # Disable terminal output (use graphical only)
        if grep -q "^GRUB_TERMINAL=" "$GRUB_CFG"; then
            sudo sed -i 's/^GRUB_TERMINAL=/#GRUB_TERMINAL=/' "$GRUB_CFG"
        fi
        
        # Ensure graphical terminal is used
        if ! grep -q "^GRUB_TERMINAL_OUTPUT=" "$GRUB_CFG"; then
            echo "GRUB_TERMINAL_OUTPUT=gfxterm" | sudo tee -a "$GRUB_CFG"
        fi
        
        echo "Updating GRUB..."
        sudo update-grub
        
        echo "GRUB theme installation complete!"
    else
        echo "Error: GRUB configuration file not found at $GRUB_CFG"
        exit 1
    fi
else
    echo "Error: grub_theme directory not found in repository"
    exit 1
fi
