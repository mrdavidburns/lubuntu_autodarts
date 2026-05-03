# Lubuntu AutoDarts Setup

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![CI](https://github.com/mrdavidburns/lubuntu_autodarts/actions/workflows/ci.yml/badge.svg)](https://github.com/mrdavidburns/lubuntu_autodarts/actions/workflows/ci.yml)

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
- **HDMI Audio**: Installs `pavucontrol` and routes audio to Digital Stereo (HDMI) Output by default
- **Force-installed Chrome extensions**: [Tools for Autodarts](https://chromewebstore.google.com/detail/tools-for-autodarts/oolfddhehmbpdnlmoljmllcdggmkgihh) deployed via Chrome managed policy
- **Auto-login + Watchdog**: SDDM autologin, systemd `--user` Chrome service with `Restart=always`, screen-blanking + sleep masked, popups suppressed
- **Unattended Security Upgrades**: Daily security patches with 04:00 auto-reboot window
- **Operator UX**: `autodarts-status` health command, `sound-test` HDMI verifier, big-button desktop shortcuts (Reboot, Shutdown, Restart AutoDarts, Open SUIT, Sound Test, Status), `Ctrl+Alt+Q` exit-kiosk hotkey, branded SSH MOTD
- **Self-healing**: Weekly config backup (`~/Backups`), weekly upstream `git pull` + re-run via systemd timers
- **Optional remote support**: Opt-in Tailscale enrollment (`AD_ENABLE_TAILSCALE=1 TS_AUTHKEY=...`)
- **Observability**: Prometheus textfile metrics for `node_exporter` (`autodarts_up`, `autodarts_hdmi_active`, etc.)
- **Hardening**: ufw firewall (deny-in, allow mDNS + Tailscale), sudoers lockdown, `NAutoVTs=1`, power button → poweroff, GPG-verified Chrome apt repo, pinned SUIT ref

## Installation

### One-line bootstrap

```bash
curl -fsSL https://raw.githubusercontent.com/mrdavidburns/lubuntu_autodarts/main/install.sh | bash
```

Clones the repo to `~/lubuntu_autodarts` and runs `essentials.sh`.

### Manual install

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

3. Run the setup script (it re-execs itself under sudo):
```bash
./essentials.sh
```

To point Chrome at a different host, pass `AUTODARTS_URL`:
```bash
AUTODARTS_URL=https://my.local/autodarts ./essentials.sh
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
6. **Configure HDMI Audio** - Installs `pavucontrol` + `pulseaudio-utils`, drops a per-user helper and autostart entry that selects the `output:hdmi-stereo` card profile and sets the HDMI sink as default on every login
7. **Apply Desktop Customizations**:
   - Sets AutoDarts wallpaper
   - Customizes LXQt panel with AutoDarts branding
   - Adds Chrome and QTerminal to quick launch
   - Enables panel auto-hide
8. **Install Operator Tools** — `autodarts-status`, `sound-test`, `exit-kiosk` to `/usr/local/bin`; branded MOTD
9. **Install Chrome Watchdog** — systemd `--user` service that auto-restarts Chrome on crash
10. **Install Exit Hotkey** — `Ctrl+Alt+Q` stops kiosk Chrome (LXQt globalkeyshortcuts)
11. **Apply Kiosk Hardening** — disable screen blanking + DPMS, mask sleep targets, install `unclutter` + `fwupd`, lock LXQt panel, suppress update-notifier/snap-store popups, disable Bluetooth, NTP enabled
12. **Install Desktop Shortcuts** — Restart AutoDarts, Reboot, Shutdown, Open SUIT, Sound Test, Status icons on `~/Desktop`
13. **Configure SDDM Autologin** — drops `/etc/sddm.conf.d/10-autodarts-autologin.conf`, adds user to `autologin` group
14. **Configure Unattended Upgrades** — security only, auto-reboot at 04:00
15. **Configure Weekly Backup** — Sundays 03:30 → tarball of config/SUIT into `~/Backups` (last 4 kept)
16. **Configure Repo Self-Update** — Sundays 03:00 `git pull` + rerun `essentials.sh` unattended
17. **Install GRUB Theme** — Custom bootloader menu with AUTODARTS branding
18. **Install Plymouth Theme** — Custom boot splash with AutoDarts branding (also covers the shutdown screen)
   - Automatically installs `plymouth-themes` package if needed
   - Configures theme files and animations
   - Verifies installation and theme selection
   - Optimizes initramfs for fast graphical boot
19. **Run Verification** — Prints a tick/cross summary of everything above

All output is also written to `/var/log/autodarts-setup.log` for support.

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

### HDMI Audio Only
```bash
sudo ./setup_audio_hdmi.sh
```

### SDDM Autologin Only
```bash
sudo ./setup_autologin.sh                 # use $SUDO_USER
sudo ./setup_autologin.sh autodarts-user  # explicit user
```

### Chrome Managed Policy Only (force-install extensions)
```bash
sudo ./setup_chrome_policy.sh
EXTRA_EXTENSION_IDS=abc123,def456 sudo -E ./setup_chrome_policy.sh   # add more
```

### Chrome Watchdog Only
```bash
./setup_chrome_watchdog.sh
AUTODARTS_URL=https://my.host ./setup_chrome_watchdog.sh
```

### Exit Hotkey Only
```bash
sudo ./setup_exit_hotkey.sh
```

### Kiosk Hardening Only
```bash
sudo ./setup_kiosk_hardening.sh
```

### Desktop Shortcuts Only
```bash
sudo ./setup_desktop_shortcuts.sh
```

### Unattended Upgrades Only
```bash
sudo ./setup_unattended_upgrades.sh
```

### Weekly Backup Only
```bash
sudo ./setup_backup.sh
```

### Weekly Self-Update Only
```bash
sudo ./setup_repo_autoupdate.sh
```

### Tailscale (opt-in)
```bash
AD_ENABLE_TAILSCALE=1 TS_AUTHKEY=tskey-... sudo -E ./setup_tailscale.sh
```

### Boot/Shutdown Speed Only
```bash
sudo ./setup_boot_speed.sh
# Keep GRUB menu visible:    AD_BOOT_KEEP_GRUB=1 sudo -E ./setup_boot_speed.sh
# Keep wait-online services: AD_BOOT_KEEP_WAIT_ONLINE=1 sudo -E ./setup_boot_speed.sh
# Skip zstd initramfs:       AD_BOOT_NO_ZSTD=1 sudo -E ./setup_boot_speed.sh
```
Sets `GRUB_TIMEOUT=0` + hidden menu, kernel cmdline tweaks
(`vt.global_cursor_default=0 logo.nologo udev.log_level=3 i915.fastboot=1 fbcon=nodefer`),
zstd initramfs, `DefaultTimeoutStopSec=10s`, `TimeoutStopSec=3` on
`autodarts-chrome.service`, disables `*-wait-online`, `motd-news`,
`apt-daily*.timer`. Hold Shift during POST to reach the GRUB menu when
needed.

## Operator commands

After installation:

| Command | What it does |
|---------|--------------|
| `autodarts-status` | Health summary (network, audio, Chrome, boot timing, disk) |
| `sound-test` | Pink-noise burst on the default sink to verify HDMI |
| `exit-kiosk` | Stop kiosk Chrome and return to LXQt (also bound to `Ctrl+Alt+Q`) |
| `systemctl --user restart autodarts-chrome` | Reload the kiosk Chrome session |
| `autodarts-backup` | Force a config backup now |
| `autodarts-self-update` | Force a repo pull + rerun |

## File Structure

```
.
├── essentials.sh                    # Main setup script
├── setup_chrome_autostart.sh        # Chrome fullscreen autostart config
├── install.sh                       # one-line bootstrap (curl|bash)
├── setup_grub_theme.sh              # GRUB theme installer
├── setup_plymouth_theme.sh          # Plymouth theme installer
├── setup_audio_hdmi.sh              # pavucontrol + HDMI default sink installer
├── setup_autologin.sh               # SDDM autologin for kiosk operation
├── setup_chrome_policy.sh           # Chrome managed policy + force-installed extensions
├── setup_chrome_watchdog.sh         # systemd --user kiosk Chrome service
├── setup_exit_hotkey.sh             # Ctrl+Alt+Q exit-kiosk
├── setup_kiosk_hardening.sh         # blanking/sleep/popups/panel-lock
├── setup_desktop_shortcuts.sh       # big-button operator launchers
├── setup_unattended_upgrades.sh     # security-only auto upgrades
├── setup_backup.sh                  # weekly config backup
├── setup_repo_autoupdate.sh         # weekly upstream pull + rerun
├── lib/
│   ├── common.sh                    # shared helpers (sourced)
│   ├── preflight.sh                 # pre-install checks
│   └── verify.sh                    # post-install tick/cross summary
├── bin/
│   ├── autodarts-status             # health summary
│   ├── exit-kiosk                   # stop kiosk Chrome
│   └── sound-test                   # speaker-test on default sink
├── motd/
│   └── 00-autodarts                 # branded SSH MOTD
├── setup_tailscale.sh               # opt-in remote support
├── setup_boot_speed.sh              # GRUB+initramfs+systemd shutdown tuning
├── VERSION                          # semver pin shown by autodarts-status
├── CHANGELOG.md                     # release notes
├── CONTRIBUTING.md                  # dev workflow
├── .editorconfig                    # editor consistency
├── .pre-commit-config.yaml          # local lint hooks
├── .github/
│   ├── workflows/{ci,release}.yml   # shellcheck/shfmt/ruff/bats/smoke + releases
│   ├── dependabot.yml               # weekly action bumps
│   └── ISSUE_TEMPLATE/              # bug + feature templates
├── tests/
│   ├── common.bats                  # bats unit tests for lib/
│   ├── Dockerfile.smoke             # CI container image
│   └── smoke-run.sh                 # idempotent CI smoke runner
└── docs/
    ├── README.md                    # design-log index
    ├── BOOT_BRANDING_GUIDE.md
    ├── INITRAMFS_INVESTIGATION.md
    ├── PLYMOUTH_VERIFICATION.md
    └── PR_SUMMARY.md
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

This is an **unofficial** community-contributed setup repository to simplify Lubuntu installation and configuration for dedicated AutoDarts systems. It is not officially affiliated with or endorsed by AutoDarts.

This repository provides automated setup scripts for **[AutoDarts](https://autodarts.io)**, an innovative automatic darts scoring system. AutoDarts transforms your dartboard into a smart, connected scoring system.

Visit [autodarts.io](https://autodarts.io) to learn more about the AutoDarts project.
- **[AutoDarts](https://autodarts.io)** - Automatic darts scoring system
- **[SUIT (Simple UI Toolkit)](https://github.com/IteraThor/SUIT)** by IteraThor - UI management toolkit for AutoDarts
- Plymouth theme based on script-based Plymouth themes

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.


