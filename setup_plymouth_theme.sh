#!/bin/bash
# Part of lubuntu_autodarts - MIT License
# See LICENSE file for details

set -euo pipefail

# Define paths
THEME_DIR="/usr/share/plymouth/themes/autodarts"
REPO_DIR="$(cd "$(dirname "$0")" && pwd)"

echo "Installing Plymouth Theme..."

# 0. Install Plymouth Base Package
echo "Checking for Plymouth installation..."
if ! command -v plymouth &> /dev/null; then
    echo "Plymouth not found. Installing plymouth-themes package..."
    sudo apt update
    sudo apt install -y plymouth-themes || {
        echo "Error: Failed to install plymouth-themes package."
        exit 1
    }
    echo "Plymouth installed successfully."
else
    echo "Plymouth is already installed."
fi

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
        echo "Registering AutoDarts theme with update-alternatives..."
        sudo update-alternatives --install /usr/share/plymouth/themes/default.plymouth default.plymouth "$THEME_DIR/autodarts.plymouth" 100
        
        echo "Setting AutoDarts as the default Plymouth theme..."
        sudo update-alternatives --set default.plymouth "$THEME_DIR/autodarts.plymouth"
        
        # Verify theme installation
        echo "Verifying theme installation..."
        if command -v plymouth-set-default-theme &> /dev/null; then
            CURRENT_THEME=$(plymouth-set-default-theme)
            if [ "$CURRENT_THEME" = "autodarts" ]; then
                echo "✓ AutoDarts theme successfully set as default."
            else
                echo "Warning: Default theme is '$CURRENT_THEME', expected 'autodarts'."
            fi
            
            # List available themes for confirmation
            echo "Available Plymouth themes:"
            plymouth-set-default-theme -l
        fi
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

    # Ensure 'quiet splash' is in GRUB_CMDLINE_LINUX_DEFAULT (deduped).
    if grep -q "^GRUB_CMDLINE_LINUX_DEFAULT=" "$GRUB_CFG"; then
        current=$(grep "^GRUB_CMDLINE_LINUX_DEFAULT=" "$GRUB_CFG" | cut -d'"' -f2)
        cleaned=$(echo "$current" | sed -E 's/\b(quiet|splash)\b//g' | tr -s ' ' | sed 's/^ //;s/ $//')
        new_cmdline=$(echo "quiet splash $cleaned" | sed 's/ $//')
        sudo sed -i "s|^GRUB_CMDLINE_LINUX_DEFAULT=.*|GRUB_CMDLINE_LINUX_DEFAULT=\"$new_cmdline\"|" "$GRUB_CFG"
    else
        echo 'GRUB_CMDLINE_LINUX_DEFAULT="quiet splash"' | sudo tee -a "$GRUB_CFG"
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

    echo "Updating initramfs for all kernels (this may take a moment)..."
    sudo update-initramfs -u -k all
    
    echo "✓ Initramfs updated successfully."
else
    echo "Warning: $MODULES_FILE not found. Skipping Initramfs module configuration."
fi

echo ""
echo "========================================="
echo "Plymouth theme setup complete."
echo "========================================="
echo ""
echo "Summary of changes:"
echo "  ✓ Plymouth base package installed/verified"
echo "  ✓ AutoDarts theme files copied to $THEME_DIR"
echo "  ✓ Theme registered and selected as default"
echo "  ✓ GRUB configured for graphical boot (quiet splash)"
echo "  ✓ Graphics drivers added to initramfs"
echo "  ✓ Initramfs updated for all kernels"
echo ""
echo "Next steps:"
echo "  1. Reboot your system to see the AutoDarts boot theme"
echo "  2. Verify theme during boot sequence (GRUB → Plymouth → Desktop)"
echo ""
echo "Troubleshooting commands:"
echo "  • Check current theme: plymouth-set-default-theme"
echo "  • List all themes: plymouth-set-default-theme -l"
echo "  • Test theme: sudo plymouthd && sudo plymouth --show-splash"
echo "              (wait a few seconds, then: sudo plymouth --quit)"
echo ""
