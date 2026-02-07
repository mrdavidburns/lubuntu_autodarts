#!/bin/bash

# Define paths
THEME_DIR="/usr/share/plymouth/themes/autodarts"
REPO_DIR="$(dirname "$0")"

echo "Installing Plymouth Theme..."

# 1. Setup Theme Directory and Files
if [ -f "$REPO_DIR/images/autodarts_logo.png" ]; then
    sudo mkdir -p "$THEME_DIR"
    sudo cp "$REPO_DIR/images/autodarts_logo.png" "$THEME_DIR/"
    
    # Check for and copy the watermark image if it exists
    if [ -f "$REPO_DIR/plymouth_theme/images/powered_by_autodarts.png" ]; then
        sudo cp "$REPO_DIR/plymouth_theme/images/powered_by_autodarts.png" "$THEME_DIR/"
        HAS_WATERMARK=1
    else
        echo "Warning: powered_by_autodarts.png not found. Theme will be logo-only."
        HAS_WATERMARK=0
    fi
    
    # Install .plymouth file
    sudo cp "$REPO_DIR/plymouth_theme/autodarts.plymouth" "$THEME_DIR/"

    # Install .script file
    sudo cp "$REPO_DIR/plymouth_theme/autodarts.script" "$THEME_DIR/"

    # Install spinner images
    if [ -d "$REPO_DIR/plymouth_theme/spinner" ]; then
        sudo cp -r "$REPO_DIR/plymouth_theme/spinner" "$THEME_DIR/"
    else
        echo "Warning: spinner/ directory not found in plymouth_theme."
    fi

    if [ "$HAS_WATERMARK" -eq 0 ]; then
        # Remove watermark lines if watermark image is missing
        sudo sed -i '/watermark/d' "$THEME_DIR/autodarts.script"
    fi

    # Install and Select Theme
    if command -v update-alternatives &> /dev/null; then
        sudo update-alternatives --install /usr/share/plymouth/themes/default.plymouth default.plymouth "$THEME_DIR/autodarts.plymouth" 100
        sudo update-alternatives --set default.plymouth "$THEME_DIR/autodarts.plymouth"
    fi
else
    echo "Warning: autodarts_logo.png not found, skipping Plymouth theme installation."
    exit 1
fi

# 2. Configure GRUB for seamless transition
echo "Configuring GRUB for graphical boot..."

GRUB_CFG="/etc/default/grub"

if [ -f "$GRUB_CFG" ]; then
    # Backup
    sudo cp "$GRUB_CFG" "$GRUB_CFG.bak.$(date +%F_%H-%M-%S)"

    # Set Resolution (prefer 1920x1080, fallback to auto)
    # This prevents resolution switching black screens
    if grep -q "GRUB_GFXMODE=" "$GRUB_CFG"; then
        sudo sed -i 's/^GRUB_GFXMODE=.*/GRUB_GFXMODE=1920x1080,auto/' "$GRUB_CFG"
    else
        echo "GRUB_GFXMODE=1920x1080,auto" | sudo tee -a "$GRUB_CFG"
    fi

    # Keep the payload (kernel) in the same mode to avoid flicker
    if grep -q "GRUB_GFXPAYLOAD_LINUX=" "$GRUB_CFG"; then
        sudo sed -i 's/^GRUB_GFXPAYLOAD_LINUX=.*/GRUB_GFXPAYLOAD_LINUX=keep/' "$GRUB_CFG"
    else
        echo "GRUB_GFXPAYLOAD_LINUX=keep" | sudo tee -a "$GRUB_CFG"
    fi

    # Ensure quiet and splash are in the default command line
    # This robustly adds 'quiet splash' if they are missing and removes duplicates.
    if grep -q "GRUB_CMDLINE_LINUX_DEFAULT=" "$GRUB_CFG"; then
        # Extract the current value, remove existing 'quiet' or 'splash', and then add them back.
        sudo sed -i 's/GRUB_CMDLINE_LINUX_DEFAULT="\(.*\)"/GRUB_CMDLINE_LINUX_DEFAULT="\1"/' "$GRUB_CFG" # Remove any quotes to simplify processing
        current_cmdline=$(grep "GRUB_CMDLINE_LINUX_DEFAULT=" "$GRUB_CFG" | cut -d'"' -f2)
        
        # Remove existing 'quiet' and 'splash' to avoid duplicates
        current_cmdline_cleaned=$(echo "$current_cmdline" | sed -E 's/\b(quiet|splash)\b//g' | xargs)
        
        # Add 'quiet splash' to the beginning of the cleaned command line
        new_cmdline="quiet splash $current_cmdline_cleaned"
        
        # Update the GRUB_CMDLINE_LINUX_DEFAULT line
        sudo sed -i "s|^GRUB_CMDLINE_LINUX_DEFAULT=.*|GRUB_CMDLINE_LINUX_DEFAULT=\"$(echo $new_cmdline | xargs)\"|" "$GRUB_CFG"
    else
        # If the line doesn't exist, add it
        echo "GRUB_CMDLINE_LINUX_DEFAULT=\"quiet splash\"" | sudo tee -a "$GRUB_CFG"
    fi
    
    echo "Updating GRUB..."
    sudo update-grub
else
    echo "Warning: $GRUB_CFG not found. Skipping GRUB configuration."
fi

# 3. Configure Initramfs Modules for Early KMS
echo "Configuring Initramfs for early graphics..."
MODULES_FILE="/etc/initramfs-tools/modules"

if [ -f "$MODULES_FILE" ]; then
    # Add common graphics drivers if not present to ensure they load early
    # This can significantly reduce the black screen time before Plymouth starts
    
    # Helper function to add module if missing
    add_module() {
        if ! grep -q "^$1" "$MODULES_FILE"; then
            echo "$1" | sudo tee -a "$MODULES_FILE"
        fi
    }

    # Add standard DRM modules
    add_module "intel_agp"
    add_module "i915"      # Intel
    add_module "amdgpu"    # AMD
    add_module "nouveau"   # Nvidia open source
    add_module "drm_kms_helper"
    add_module "drm"

    echo "Updating initramfs (this may take a moment)..."
    sudo update-initramfs -u
else
    echo "Warning: $MODULES_FILE not found. Skipping Initramfs module configuration."
fi

echo "Plymouth theme setup complete."
