# Lubuntu AutoDarts Setup

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

Automated setup scripts for configuring a Lubuntu installation as a dedicated AutoDarts system with custom branding and boot experience.

## Purpose

This repository provides a complete setup solution for turning a fresh Lubuntu installation into a dedicated AutoDarts machine. It automates the installation of AutoDarts, configures the desktop environment with AutoDarts branding, and creates a seamless boot-to-game experience.

## Features

- **AutoDarts Installation**: Automatically installs the latest AutoDarts software
- **Google Chrome Auto-launch**: Configures Chrome to start in fullscreen mode on boot
- **SUIT Toolkit**: Installs the Simple UI Toolkit for easy AutoDarts management and system configuration
- **Complete Boot Branding**: AUTODARTS branding throughout the entire boot process
  - **GRUB Theme**: Custom bootloader menu with AUTODARTS logo and branding
  - **Plymouth Boot Theme**: Animated boot splash screen with AUTODARTS logo and spinner
  - **Optimized Transitions**: Seamless graphical boot from GRUB through Plymouth to desktop
- **Desktop Customization**: 
  - AutoDarts wallpaper
  - Custom panel icon and branding
  - Quick launch shortcuts for Chrome and QTerminal
  - Auto-hiding taskbar
- **System Tools**: Installs fastfetch and btop for system monitoring

## Installation

### Prerequisites

- Fresh Lubuntu installation (tested on Lubuntu 22.04+)
- Internet connection
- Sudo privileges

### Quick Setup

1. Clone this repository:
```bash
git clone https://github.com/mrdavidburns/lubuntu_autodarts.git
cd lubuntu_autodarts
```

2. Make the main script executable:
```bash
chmod +x essentials.sh
```

3. Run the setup script:
```bash
./essentials.sh
```

4. Reboot your system to see the new Plymouth boot theme:
```bash
sudo reboot
```

### What Gets Installed

The setup script will:

1. **Install Google Chrome** - Downloads and installs the latest stable version
2. **Install AutoDarts** - Uses the official AutoDarts installer
3. **Configure Autostart** - Sets Chrome to launch fullscreen on login (user-specific, no sudo required)
4. **Install System Tools** - Adds fastfetch and btop for system monitoring
5. **Install SUIT** - Installs the Simple UI Toolkit for managing AutoDarts and system settings
6. **Apply Desktop Customizations**:
   - Sets AutoDarts wallpaper
   - Customizes LXQt panel with AutoDarts branding
   - Adds Chrome and QTerminal to quick launch
   - Enables panel auto-hide
7. **Install GRUB Theme** - Custom bootloader menu with AUTODARTS branding
8. **Install Plymouth Theme** - Custom boot splash with AutoDarts branding
   - Automatically installs `plymouth-themes` package if needed
   - Configures theme files and animations
   - Verifies installation and theme selection
   - Optimizes initramfs for fast graphical boot

## Manual Component Setup

If you want to run individual components separately:

### Chrome Autostart Only
```bash
./setup_chrome_autostart.sh
```

### GRUB Theme Only
```bash
sudo ./setup_grub_theme.sh
```

### Plymouth Theme Only
```bash
sudo ./setup_plymouth_theme.sh
```

### Quick Launch Update Only
```bash
python3 update_quick_launch.py
```

## File Structure

```
.
├── essentials.sh                    # Main setup script
├── setup_chrome_autostart.sh        # Chrome fullscreen autostart config
├── setup_grub_theme.sh              # GRUB theme installer
├── setup_plymouth_theme.sh          # Plymouth theme installer
├── update_quick_launch.py           # LXQt panel quick launch updater
├── images/
│   ├── autodarts_logo.png          # AutoDarts logo for panel/Plymouth/GRUB
│   └── four-darts-desktop-wallpaper.webp  # Desktop wallpaper
├── grub_theme/
│   ├── theme.txt                   # GRUB theme configuration
│   ├── autodarts_logo.png          # Logo for GRUB menu
│   ├── background.png              # GRUB background (generated)
│   ├── create_background.sh        # Background image generator
│   └── README.md                   # GRUB theme documentation
└── plymouth_theme/
    ├── autodarts.plymouth           # Plymouth theme definition
    ├── autodarts.script             # Plymouth animation script
    ├── images/
    │   └── powered_by_autodarts.png # Boot screen watermark
    └── spinner/
        └── autodarts_spinner_*.png  # Spinner animation frames
```

## Customization

### Changing the Wallpaper
Replace `images/four-darts-desktop-wallpaper.webp` with your own image before running the setup.

### Modifying GRUB Theme
Edit `grub_theme/theme.txt` to customize colors, layout, and text. Replace `grub_theme/background.png` with your own 1920x1080 image, or modify `grub_theme/create_background.sh` to change how the background is generated.

### Modifying Plymouth Theme
Edit `plymouth_theme/autodarts.script` to customize the boot animation, or replace images in `plymouth_theme/images/` and `plymouth_theme/spinner/`.

### Panel Configuration
The panel is configured to auto-hide by default. To change this behavior, modify the `sed` commands in `essentials.sh` around line 61.

## Boot Sequence

AUTODARTS branding appears throughout the entire boot process:

1. **GRUB Bootloader** (3-5 seconds) - AUTODARTS themed menu with logo
2. **Kernel Load** (1-2 seconds) - Graphical transition
3. **Initramfs** (2-3 seconds) - Early graphics drivers loaded (optimized for fast Plymouth start)
4. **Plymouth Boot Splash** (5-10 seconds) - Animated AUTODARTS logo with spinner
5. **Desktop** - AUTODARTS wallpaper and branded panel

Total boot time: ~15-20 seconds on modern hardware with SSD.

## Troubleshooting

### GRUB theme not showing
- Ensure you rebooted after installation
- Check theme installation: `ls -la /boot/grub/themes/autodarts/`
- Verify GRUB config: `grep GRUB_THEME /etc/default/grub`
- Regenerate GRUB: `sudo update-grub`

### Plymouth theme not showing
- Ensure you rebooted after installation
- Check current theme: `plymouth-set-default-theme` (should show "autodarts")
- List all themes: `plymouth-set-default-theme -l` (should include "autodarts")
- Verify theme files exist: `ls -la /usr/share/plymouth/themes/autodarts/`
- Check initramfs was updated: Look for "✓ Initramfs updated successfully" in setup output
- Manually update if needed: `sudo update-initramfs -u -k all`
- Test the theme without rebooting:
  ```bash
  sudo plymouthd
  sudo plymouth --show-splash
  # Wait a few seconds to see the animation
  sudo plymouth --quit
  ```
- Verify GRUB settings: `grep GRUB_CMDLINE_LINUX_DEFAULT /etc/default/grub` (should include "quiet splash")

### Chrome not auto-launching
- Check the autostart file exists: `cat ~/.config/autostart/google-chrome-fullscreen.desktop`
- Log out and log back in
- Verify Chrome is installed: `which google-chrome-stable`

**Note**: Chrome autostart is configured per-user in `~/.config/autostart/`, not system-wide. This means:
- No sudo privileges required for setup
- Configuration affects only the current user
- Easy to modify or remove without affecting other users
- Follows LXQt best practices

### Panel customizations not applied
- The script requires an existing `~/.config/lxqt/panel.conf` file
- Try logging out and back in, then re-run the script

## Requirements

- Lubuntu 22.04 or newer
- Minimum 2GB RAM
- Active internet connection during setup
- Sudo/root access

## Attribution

This repository provides automated setup scripts for **[AutoDarts](https://autodarts.io)**, an innovative automatic darts scoring system. AutoDarts transforms your dartboard into a smart, connected scoring system.

This is an **unofficial** community-contributed setup repository to simplify Lubuntu installation and configuration for dedicated AutoDarts systems. It is not officially affiliated with or endorsed by AutoDarts.

Visit [autodarts.io](https://autodarts.io) to learn more about the AutoDarts project.

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Credits

- **[AutoDarts](https://autodarts.io)** - Automatic darts scoring system
- **[SUIT (Simple UI Toolkit)](https://github.com/IteraThor/SUIT)** by IteraThor - UI management toolkit for AutoDarts
- Plymouth theme based on script-based Plymouth themes
