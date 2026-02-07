# AUTODARTS GRUB Theme

This directory contains the GRUB bootloader theme files for AUTODARTS branding.

## Files

- **theme.txt** - GRUB theme configuration file defining menu appearance, colors, fonts, and layout
- **autodarts_logo.png** - AUTODARTS logo (200x200 PNG) displayed in boot menu
- **background.png** - Full-screen background (1920x1080 PNG) with centered logo (generated)
- **create_background.sh** - Script to generate background.png from logo using ImageMagick

## Installation

The GRUB theme is automatically installed by running:
```bash
./setup_grub_theme.sh
```

This script:
1. Generates the background image if it doesn't exist
2. Copies theme files to `/boot/grub/themes/autodarts/`
3. Updates `/etc/default/grub` to use the AUTODARTS theme
4. Runs `update-grub` to apply changes

## Manual Installation

If you need to install manually:

1. Generate background image:
   ```bash
   cd grub_theme
   ./create_background.sh
   ```

2. Copy theme files:
   ```bash
   sudo mkdir -p /boot/grub/themes/autodarts
   sudo cp theme.txt background.png autodarts_logo.png /boot/grub/themes/autodarts/
   ```

3. Edit `/etc/default/grub` and add:
   ```
   GRUB_THEME="/boot/grub/themes/autodarts/theme.txt"
   GRUB_TERMINAL_OUTPUT=gfxterm
   ```

4. Update GRUB:
   ```bash
   sudo update-grub
   ```

## Theme Customization

Edit `theme.txt` to customize:
- **Colors**: Change `item_color`, `selected_item_color`, `fg_color`, `bg_color`
- **Layout**: Adjust `left`, `top`, `width`, `height` percentages
- **Fonts**: Modify `font` settings (requires font installation)
- **Text**: Update labels like "AUTODARTS System" and timeout message

## Requirements

- GRUB 2.x with graphical terminal support
- ImageMagick (for background generation)
- PNG image support in GRUB

## Boot Sequence

1. **BIOS/UEFI** → **GRUB (MBR Phase)** ← *This theme applies here*
2. GRUB → Kernel Load
3. Kernel → Initramfs
4. Initramfs → Plymouth ← *Plymouth theme applies here*
5. Plymouth → Desktop

The GRUB theme provides AUTODARTS branding during the bootloader menu phase, before the kernel loads.
