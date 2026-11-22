# Lubuntu AutoDarts Setup

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![CI](https://github.com/mrdavidburns/lubuntu_autodarts/actions/workflows/ci.yml/badge.svg)](https://github.com/mrdavidburns/lubuntu_autodarts/actions/workflows/ci.yml)

Automated AutoDarts setup for Debian-based desktop systems, with a choice of kiosk or desktop installation.

## Purpose

This repository provides a complete setup solution for turning a fresh Lubuntu installation into a dedicated AutoDarts machine. It automates the installation of AutoDarts, configures the desktop environment with AutoDarts branding, and creates a seamless boot-to-game experience.

## Installation modes

Choose a mode during installation, before the final confirmation:

- **Kiosk (default):** installs the apps and configures fullscreen browser startup, display-manager autologin, HDMI audio, kiosk hardening, unattended security upgrades and boot/performance tuning. Kiosk hardening also changes Bluetooth and the power button. Desktop-specific behavior varies as described below.
- **Desktop:** installs AutoDarts, Chrome or Chromium, SUIT, system and operator tools, plus weekly backup and repository self-update timers. Open AutoDarts in your browser when needed. It skips kiosk-only configuration such as fullscreen browser startup, autologin, forced browser extensions and kiosk operator shortcuts. The upstream AutoDarts installer still creates its system services.

Both modes apply desktop branding on supported desktops, install GRUB branding when GRUB is present and the Plymouth theme, mask system sleep/hibernate targets, and configure UFW. **The firewall setup resets existing UFW rules**, denies incoming traffic, permits mDNS and Tailscale, and allows outgoing traffic. Both modes can change packages and install services. Selecting desktop on a machine already configured as a kiosk **does not undo prior settings**: existing fullscreen startup, autologin, firewall rules, sleep masks, boot changes and other kiosk settings remain. Use a fresh installation for a desktop without those changes.

The choice is saved in `/etc/autodarts/install-mode` and reused by unattended weekly updates. Interactive reruns offer the saved choice as the default. Existing installations with no saved choice retain the kiosk default for unattended updates.

## Linux compatibility

| System | Status |
| --- | --- |
| Lubuntu 26.04, LXQt | User reports the upgraded installation is working; desktop shortcut trust prompts are still being investigated. |
| Lubuntu 24.04, LXQt | Kiosk installation exercised on a test VM; hardware and individual features can vary. |
| Raspberry Pi OS (Debian 13 / Trixie, arm64) | Installation was run on a Raspberry Pi 4 but did not complete; the GRUB failure has been addressed in code. Desktop integration and end-to-end operation still need hardware validation. |
| Other Ubuntu or Debian releases and derivatives | The installer accepts Debian/Ubuntu family systems, but these combinations have not been validated end to end. Package availability, display managers, architecture, and upstream AutoDarts support may limit functionality. |

The installer uses Google Chrome on amd64 and Chromium on other architectures if available. A systemd-based graphical Debian/Ubuntu installation, working network, supported browser packages, sudo access and at least 3 GB free disk space are required. The preflight check is not a guarantee that every distribution or architecture is supported by upstream components. Non-Debian distributions are not supported.

Both install modes install the pinned RustDesk 1.5.3 Debian package on amd64, arm64 and armhf, and add a desktop shortcut. Unsupported architectures or unresolvable dependencies are skipped with a warning. To enable unattended access, open RustDesk on the AutoDarts machine, set a strong permanent password under Settings → Security, and note its ID. Install RustDesk on the controlling device and connect using that ID and password. RustDesk uses its public servers by default; a self-hosted server can be configured. See the [RustDesk Linux guide](https://rustdesk.com/docs/en/client/linux/) and [unattended access guide](https://rustdesk.com/blog/rustdesk-unattended-access-setup/).

X11 is the recommended session for unattended access. RustDesk's standard Wayland support is experimental and may require local screen-sharing approval; login-screen access requires X11. Raspberry Pi Wayland and these installer changes have not been validated on hardware. RustDesk is pinned and an existing installation is left at its installed version; update RustDesk separately or update the pinned version in the installer. An upgrade removes this installer's old Chrome Remote Desktop shortcut, but leaves any existing Chrome Remote Desktop host and its settings installed.

## Desktop compatibility

The installer detects a running LXQt, labwc, or Wayfire session for the kiosk user. LXQt retains its existing desktop branding and shortcuts. On Raspberry Pi OS with labwc, PCManFM and wf-panel-pi, the wallpaper and menu icon are configured for the next graphical login. The Raspberry Pi menu widget does not support a separate text label, so the AUTODARTS menu text is available only on LXQt. Ctrl+Alt+Q is configured in labwc. Wayfire and other desktops can run the browser and desktop launchers, but automatic wallpaper, menu branding, exit hotkey, notification suppression, and brightness shortcuts are not configured. X11 screen-blanking and cursor settings do not control a native Wayland session; configure its compositor's idle settings separately. These desktop paths have not yet been validated on Raspberry Pi hardware.

The installer marks its desktop shortcuts trusted and retries at graphical login if desktop metadata was unavailable during setup. Log out and back in after installation. If an exclamation mark remains, right-click the shortcut and select **Trust this executable**; GVFS must be available for the setting to persist.

When installing over SSH or without a running graphical session, select the desktop explicitly, for example `sudo AD_DESKTOP=labwc ./essentials.sh`. Supported values are `lxqt`, `labwc`, and `wayfire`. Reboot or log out and back in after installation. Raspberry Pi firmware boot does not use GRUB, so the GRUB theme is skipped when GRUB is absent.

## Installation

### One-line bootstrap

```bash
curl -fsSL https://raw.githubusercontent.com/mrdavidburns/lubuntu_autodarts/main/install.sh | bash
```

Clones the repo to `~/lubuntu_autodarts` and runs `essentials.sh`.

For unattended setup, provide both the mode and confirmation explicitly:

```bash
curl -fsSL https://raw.githubusercontent.com/mrdavidburns/lubuntu_autodarts/main/install.sh | AD_KIOSK_MODE=0 AD_AUTOCONFIRM=1 bash
```

Use `AD_KIOSK_MODE=1` for kiosk mode or `0` for desktop mode. With `AD_AUTOCONFIRM=1` and no explicit mode, the saved mode is used; a machine with no saved mode defaults to kiosk for compatibility. For a manual checkout, run `AD_KIOSK_MODE=0 AD_AUTOCONFIRM=1 ./essentials.sh` instead. Invalid mode values stop the install.


### Manual install

### Prerequisites

- A Debian/Ubuntu-family graphical installation; see Linux compatibility above
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

A reboot is especially useful in kiosk mode for the boot theme, autologin and audio settings.

### Kiosk setup details

In kiosk mode the setup script performs the following. Desktop mode also runs the shared desktop branding, sleep, firewall, GRUB and Plymouth steps; the remaining kiosk-specific steps below run only in kiosk mode:

1. **Install Google Chrome / Chromium** - Installs `google-chrome-stable` on `amd64` or `chromium` / `chromium-browser` on non-`amd64` architectures
2. **Install AutoDarts** - Uses the official AutoDarts installer
3. **Configure Autostart** - Sets Chrome to launch fullscreen on login (user-specific, no sudo required)
4. **Install System Tools** - Adds fastfetch and btop for system monitoring
5. **Install SUIT** - Installs the Simple UI Toolkit for managing AutoDarts and system settings
6. **Configure HDMI Audio** - Installs `pavucontrol` + `pulseaudio-utils`, drops a per-user helper and autostart entry that selects the `output:hdmi-stereo` card profile and sets the HDMI sink as default on every login
7. **Apply Desktop Customizations**:
   - Sets AutoDarts wallpaper
   - Customizes LXQt panel with AutoDarts branding
   - Adds Chrome and QTerminal to quick launch
8. **Install Operator Tools** — `autodarts-status`, `sound-test`, `exit-kiosk` to `/usr/local/bin`; branded MOTD
9. **Install Chrome Watchdog** — systemd `--user` service that auto-restarts Chrome on crash
10. **Install Exit Hotkey** — `Ctrl+Alt+Q` stops kiosk Chrome on LXQt or labwc; other desktops require manual setup
11. **Apply System and Kiosk Hardening** — both modes mask sleep targets and reset/configure UFW; kiosk mode also disables screen blanking + DPMS, install `unclutter` + `fwupd`, lock LXQt panel, suppress update-notifier/snap-store popups, disable Bluetooth, NTP enabled
12. **Install Desktop Shortcuts** — Restart AutoDarts, Reboot, Shutdown, Open SUIT, Sound Test, Status icons on `~/Desktop`
13. **Configure Display Manager Autologin** — Configures SDDM, LightDM, or GDM3 autologin for the kiosk user
14. **Configure Unattended Upgrades** — security only, auto-reboot at 04:00
15. **Configure Weekly Backup** — Sundays 03:30 → tarball of config/SUIT into `~/Backups` (last 4 kept)
16. **Configure Repo Self-Update** — Sundays 03:00 `git pull` + rerun `essentials.sh` unattended
17. **Install GRUB Theme** — Custom bootloader menu with Winmau AutoDarts branding
18. **Install Plymouth Theme** — Custom boot splash with Winmau AutoDarts branding (also covers the shutdown screen)
   - Automatically installs `plymouth-themes` package if needed
   - Configures theme files and animations
   - Verifies installation and theme selection
   - Optimizes initramfs for fast graphical boot
19. **Tune Boot/Shutdown Speed** — Hides GRUB timeout, tunes kernel cmdline (including `usbcore.autosuspend=-1`), enables zstd initramfs, caps systemd stop timeouts
20. **Tune Linux Performance & Stability** — Disables USB camera autosuspend via udev, sets CPU `performance` governor, boosts `autodarts` service priority, caps `journald`, enables ZRAM swap
21. **Run Verification** — Prints a summary of selected checks

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

The watchdog setup disables legacy AutoDarts Chrome autostart entries to prevent duplicate windows after upgrading. Log out and back in for the change to take effect. The watchdog restarts Chrome when it closes; use `exit-kiosk` to stop it.
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

After installation (kiosk-specific commands require kiosk mode):

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
├── setup_autologin.sh               # SDDM / LightDM / GDM3 autologin for kiosk operation
├── setup_chrome_policy.sh           # Chrome managed policy + force-installed extensions
├── setup_chrome_watchdog.sh         # systemd --user kiosk Chrome/Chromium service
├── setup_desktop_branding.sh        # LXQt wallpaper, menu icon/text, quick-launch
├── setup_exit_hotkey.sh             # Ctrl+Alt+Q exit-kiosk
├── setup_kiosk_hardening.sh         # blanking/sleep/popups/panel-lock
├── setup_desktop_shortcuts.sh       # big-button operator launchers
├── setup_performance.sh             # USB camera power, CPU governor, ZRAM, journald
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
│   ├── desktop.bats                 # bats tests for desktop branding & distro checks
│   ├── Dockerfile.smoke             # CI container image
│   └── smoke-run.sh                 # idempotent CI smoke runner
└── docs/
    ├── README.md                    # design-log index
    ├── BOOT_BRANDING_GUIDE.md
    ├── INITRAMFS_INVESTIGATION.md
    ├── PLYMOUTH_VERIFICATION.md
    └── PR_SUMMARY.md
├── configure_desktop.py             # LXQt main-menu icon/text & pcmanfm-qt wallpaper
├── update_quick_launch.py           # LXQt panel quick launch updater
├── images/
│   ├── autodarts_logo.png           # AutoDarts logo for Plymouth
│   ├── autodarts-favicon.png        # AutoDarts favicon for LXQt start menu
│   └── winmau-autodarts-wallpaper-04-navy-spotlight-landscape.png  # Desktop wallpaper
├── grub_theme/
│   ├── theme.txt                    # GRUB theme configuration
│   ├── winmau-autodarts-logo-white.png  # Winmau AutoDarts logo for GRUB menu
│   ├── background.png               # GRUB background (generated)
│   ├── create_background.sh         # Background image generator
│   └── README.md                    # GRUB theme documentation
└── plymouth_theme/
    ├── autodarts.plymouth           # Plymouth theme definition
    ├── autodarts.script             # Plymouth animation script
    ├── images/
    │   └── winmau-autodarts-logo-white.png # Boot screen wordmark
    └── spinner/
        └── brand_spinner_*.png      # Spinner animation frames
```

## Customization

### Changing the Wallpaper
Replace `images/winmau-autodarts-wallpaper-04-navy-spotlight-landscape.png` with your own PNG before running setup. Desktop branding applies at the next LXQt login.

### Modifying GRUB Theme
Edit `grub_theme/theme.txt` to customize colors, layout, and text. Replace `grub_theme/background.png` with your own 1920x1080 image, or modify `grub_theme/create_background.sh` to change the generated background. Delete a previously generated background before regenerating it.

### Modifying Plymouth Theme
Edit `plymouth_theme/autodarts.script` to customize the boot animation, or replace images in `plymouth_theme/images/` and `plymouth_theme/spinner/`.

### Panel Configuration
LXQt menu and wallpaper configuration are managed by `configure_desktop.py`. Other desktop sessions have the limitations described above.

## Boot Sequence

On a compatible GRUB/Plymouth system in kiosk mode, branding may appear throughout the boot process:

1. **GRUB Bootloader** (3-5 seconds) - AUTODARTS themed menu with logo
2. **Kernel Load** (1-2 seconds) - Graphical transition
3. **Initramfs** (2-3 seconds) - Early graphics drivers loaded (optimized for fast Plymouth start)
4. **Plymouth Boot Splash** (5-10 seconds) - Animated AUTODARTS logo with spinner
5. **Desktop** - AUTODARTS wallpaper and branded panel

Boot time and theme availability vary by hardware and distribution.

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

### Chrome not auto-launching in kiosk mode
- Check `~/.config/autostart/autodarts-chrome-watchdog.desktop` and `~/.config/systemd/user/autodarts-chrome.service`.
- Check `systemctl --user status autodarts-chrome.service`, then log out and back in.
- Verify that Chrome or Chromium is installed. Desktop mode does not enable browser autostart.

### Panel customizations not applied
- The script requires an existing `~/.config/lxqt/panel.conf` file
- Try logging out and back in, then re-run the script

## Requirements

- See [Linux compatibility](#linux-compatibility) for tested and unvalidated systems.
- Active internet connection, a graphical session, systemd, and sudo access.
- At least 3 GB free disk space on `/`.

## Attribution

This is an **unofficial** community-contributed setup repository to simplify Lubuntu installation and configuration for dedicated AutoDarts systems. It is not officially affiliated with or endorsed by AutoDarts.

This repository provides automated setup scripts for **[AutoDarts](https://autodarts.io)**, an innovative automatic darts scoring system. AutoDarts transforms your dartboard into a smart, connected scoring system.

Visit [autodarts.io](https://autodarts.io) to learn more about the AutoDarts project.
- **[AutoDarts](https://autodarts.io)** - Automatic darts scoring system
- **[SUIT (Simple UI Toolkit)](https://github.com/IteraThor/SUIT)** by IteraThor - UI management toolkit for AutoDarts
- Plymouth theme based on script-based Plymouth themes

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.



### Branding assets

The Winmau Autodarts logo and wallpaper are sourced from the [official community assets](https://docs.autodarts.com/community-assets/). Its provider permits personal, non-commercial use; other uses are subject to Autodarts’ terms. These assets are not covered by this repository’s MIT code license.
