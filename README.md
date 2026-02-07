# Lubuntu AutoDarts Setup

Automated setup scripts for configuring a Lubuntu installation as a dedicated AutoDarts system with custom branding and boot experience.

## Purpose

This repository provides a complete setup solution for turning a fresh Lubuntu installation into a dedicated AutoDarts machine. It automates the installation of AutoDarts, configures the desktop environment with AutoDarts branding, and creates a seamless boot-to-game experience.

## Features

- **AutoDarts Installation**: Automatically installs the latest AutoDarts software
- **Google Chrome Auto-launch**: Configures Chrome to start in fullscreen mode on boot
- **Custom Plymouth Boot Theme**: Branded boot splash screen with AutoDarts logo and spinner animation
- **Desktop Customization**: 
  - AutoDarts wallpaper
  - Custom panel icon and branding
  - Quick launch shortcuts for Chrome and QTerminal
  - Auto-hiding taskbar
- **System Tools**: Installs fastfetch and btop for system monitoring
- **Optimized Boot**: Configures GRUB and initramfs for smooth graphical boot transitions

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
3. **Configure Autostart** - Sets Chrome to launch fullscreen on login
4. **Install System Tools** - Adds fastfetch and btop for system monitoring
5. **Apply Desktop Customizations**:
   - Sets AutoDarts wallpaper
   - Customizes LXQt panel with AutoDarts branding
   - Adds Chrome and QTerminal to quick launch
   - Enables panel auto-hide
6. **Install Plymouth Theme** - Custom boot splash with AutoDarts branding

## Manual Component Setup

If you want to run individual components separately:

### Chrome Autostart Only
```bash
./setup_chrome_autostart.sh
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
├── setup_plymouth_theme.sh          # Plymouth theme installer
├── update_quick_launch.py           # LXQt panel quick launch updater
├── images/
│   ├── autodarts_logo.png          # AutoDarts logo for panel/Plymouth
│   └── four-darts-desktop-wallpaper.webp  # Desktop wallpaper
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

### Modifying Plymouth Theme
Edit `plymouth_theme/autodarts.script` to customize the boot animation, or replace images in `plymouth_theme/images/` and `plymouth_theme/spinner/`.

### Panel Configuration
The panel is configured to auto-hide by default. To change this behavior, modify the `sed` commands in `essentials.sh` around line 61.

## Troubleshooting

### Plymouth theme not showing
- Ensure you rebooted after installation
- Check theme installation: `sudo plymouth-set-default-theme -l`
- Verify initramfs was updated: `sudo update-initramfs -u`

### Chrome not auto-launching
- Check the autostart file exists: `cat ~/.config/autostart/google-chrome-fullscreen.desktop`
- Log out and log back in
- Verify Chrome is installed: `which google-chrome-stable`

### Panel customizations not applied
- The script requires an existing `~/.config/lxqt/panel.conf` file
- Try logging out and back in, then re-run the script

## Requirements

- Lubuntu 22.04 or newer
- Minimum 2GB RAM
- Active internet connection during setup
- Sudo/root access

## License

This is a personal setup repository. Feel free to use and modify for your own AutoDarts installations.

## Credits

- AutoDarts: https://autodarts.io
- Plymouth theme based on script-based Plymouth themes
