#!/bin/bash
# Part of lubuntu_autodarts - MIT License
# See LICENSE file for details
#
# One-shot kiosk setup. Re-execs under sudo, logs to /var/log/autodarts-setup.log,
# runs preflight + every step + post-install verify. Set AD_AUTOCONFIRM=1 to
# skip the confirmation prompt (used by the weekly self-update cron).

set -euo pipefail

if [ "$EUID" -ne 0 ]; then
    exec sudo -E "$0" "$@"
fi

if [ -z "${SUDO_USER:-}" ] || [ "$SUDO_USER" = "root" ]; then
    echo "Error: run as a normal user via sudo (do not run as root directly)." >&2
    exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck disable=SC1091
. "$SCRIPT_DIR/lib/common.sh"
# shellcheck disable=SC1091
. "$SCRIPT_DIR/lib/preflight.sh"
# shellcheck disable=SC1091
. "$SCRIPT_DIR/lib/verify.sh"

# Tee everything to the log so post-mortem is easy.
LOG=/var/log/autodarts-setup.log
mkdir -p "$(dirname "$LOG")"
touch "$LOG"
chmod 0644 "$LOG"
exec > >(tee -a "$LOG") 2>&1
echo
echo "=== AutoDarts setup run @ $(date -Is) ==="

ACTUAL_USER=$(ad_actual_user)
ACTUAL_HOME=$(ad_actual_home)
AUTODARTS_URL="${AUTODARTS_URL:-https://play.autodarts.io/}"
export AUTODARTS_URL

ad_preflight || exit 1
ad_confirm || exit 1

apt update
apt install -y curl wget software-properties-common lsb-release ca-certificates

# 1. Google Chrome (idempotent)
install_chrome() {
    if command -v google-chrome-stable >/dev/null 2>&1; then
        echo "google-chrome-stable already installed."
        return 0
    fi
    local deb
    deb=$(mktemp --suffix=.deb)
    wget -q -O "$deb" https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb
    dpkg -i "$deb" || apt --fix-broken install -y
    rm -f "$deb"
}
ad_step "Install Google Chrome" install_chrome

# 2. AutoDarts (run as kiosk user)
ad_step "Install AutoDarts" \
    sudo -u "$ACTUAL_USER" -H bash -c 'bash <(curl -sL get.autodarts.io)'

# 3. Chrome managed-policy + force-installed extensions
ad_step "Install Chrome managed policy" bash "$SCRIPT_DIR/setup_chrome_policy.sh"

# 4. System tools (fastfetch, btop)
install_system_tools() {
    apt install -y btop
    if apt-cache show fastfetch >/dev/null 2>&1; then
        apt install -y fastfetch
    else
        add-apt-repository -y ppa:zhangsongcui3371/fastfetch
        apt update
        apt install -y fastfetch
    fi
}
ad_step "Install fastfetch + btop" install_system_tools

# 5. SUIT inside its own venv
install_suit() {
    apt install -y python3-tk python3-dbus python3-pip python3-venv git libdbus-1-dev
    local suit_dir="$ACTUAL_HOME/SUIT"
    if [ -d "$suit_dir/.git" ]; then
        sudo -u "$ACTUAL_USER" git -C "$suit_dir" pull
    else
        sudo -u "$ACTUAL_USER" git clone https://github.com/IteraThor/SUIT.git "$suit_dir"
    fi
    if [ ! -d "$suit_dir/.venv" ]; then
        sudo -u "$ACTUAL_USER" python3 -m venv "$suit_dir/.venv" --system-site-packages
    fi
    if [ -f "$suit_dir/requirements.txt" ]; then
        sudo -u "$ACTUAL_USER" "$suit_dir/.venv/bin/pip" install --upgrade pip
        sudo -u "$ACTUAL_USER" "$suit_dir/.venv/bin/pip" install -r "$suit_dir/requirements.txt" || \
            ad_warn "SUIT requirements install failed."
    fi
    if [ -f "$suit_dir/create_launcher.py" ]; then
        sudo -u "$ACTUAL_USER" bash -c "cd '$suit_dir' && '.venv/bin/python' create_launcher.py"
    fi
}
ad_step "Install SUIT" install_suit

# 6. Audio
ad_step "Configure HDMI audio" bash "$SCRIPT_DIR/setup_audio_hdmi.sh"

# 7. Desktop customization
apply_desktop_customizations() {
    sudo -u "$ACTUAL_USER" mkdir -p "$ACTUAL_HOME/Pictures" "$ACTUAL_HOME/.local/share/icons"

    if [ -f "$SCRIPT_DIR/images/four-darts-desktop-wallpaper.webp" ]; then
        sudo -u "$ACTUAL_USER" cp "$SCRIPT_DIR/images/four-darts-desktop-wallpaper.webp" "$ACTUAL_HOME/Pictures/"
        sudo -u "$ACTUAL_USER" -H pcmanfm-qt \
            --set-wallpaper="$ACTUAL_HOME/Pictures/four-darts-desktop-wallpaper.webp" \
            --wallpaper-mode=stretch || \
            ad_warn "pcmanfm-qt wallpaper set failed (likely no DISPLAY at install time — wallpaper will apply on first login)."
    fi

    if [ -f "$SCRIPT_DIR/images/autodarts_logo.png" ]; then
        sudo -u "$ACTUAL_USER" cp "$SCRIPT_DIR/images/autodarts_logo.png" "$ACTUAL_HOME/.local/share/icons/"
    fi

    local panel_conf="$ACTUAL_HOME/.config/lxqt/panel.conf"
    if [ -f "$panel_conf" ]; then
        sudo -u "$ACTUAL_USER" cp "$panel_conf" "$panel_conf.bak"
        sudo -u "$ACTUAL_USER" sed -i 's/hidable=false/hidable=true/g' "$panel_conf"
        local logo_path="$ACTUAL_HOME/.local/share/icons/autodarts_logo.png"
        local escaped
        escaped=$(printf '%s' "$logo_path" | sed 's/\//\\\//g')
        sudo -u "$ACTUAL_USER" sed -i "/^\[mainmenu\]/,/^\[/ s/^icon=.*/icon=$escaped/" "$panel_conf"
        sudo -u "$ACTUAL_USER" sed -i "/^\[mainmenu\]/,/^\[/ s/^title=.*/title=AutoDarts/" "$panel_conf"
        if [ -f "$SCRIPT_DIR/update_quick_launch.py" ]; then
            sudo -u "$ACTUAL_USER" -H python3 "$SCRIPT_DIR/update_quick_launch.py"
        fi
    fi
}
ad_step "Apply desktop customizations" apply_desktop_customizations

# 8. Operator UX: status command, sound test, MOTD
install_operator_tools() {
    install -m 0755 "$SCRIPT_DIR/bin/autodarts-status" /usr/local/bin/autodarts-status
    install -m 0755 "$SCRIPT_DIR/bin/sound-test"        /usr/local/bin/sound-test
    install -m 0755 "$SCRIPT_DIR/bin/exit-kiosk"        /usr/local/bin/exit-kiosk
    install -m 0755 "$SCRIPT_DIR/motd/00-autodarts"     /etc/update-motd.d/00-autodarts
    apt install -y alsa-utils libnotify-bin
}
ad_step "Install operator tools (status, sound-test, MOTD)" install_operator_tools

# 9. Chrome watchdog (systemd --user, replaces autostart .desktop)
ad_step "Install Chrome watchdog" bash "$SCRIPT_DIR/setup_chrome_watchdog.sh"

# 10. Exit hotkey (Ctrl+Alt+Q)
ad_step "Install exit hotkey" bash "$SCRIPT_DIR/setup_exit_hotkey.sh"

# 11. Kiosk hardening (blanking, sleep, popups, panel lock, BT, fwupd, NTP)
ad_step "Apply kiosk hardening" bash "$SCRIPT_DIR/setup_kiosk_hardening.sh"

# 12. Desktop shortcuts (Reboot, Shutdown, Sound Test, Status, SUIT)
ad_step "Install desktop shortcuts" bash "$SCRIPT_DIR/setup_desktop_shortcuts.sh"

# 13. SDDM autologin
ad_step "Configure SDDM autologin" bash "$SCRIPT_DIR/setup_autologin.sh" "$ACTUAL_USER"

# 14. Unattended security upgrades + nightly reboot
ad_step "Configure unattended-upgrades" bash "$SCRIPT_DIR/setup_unattended_upgrades.sh"

# 15. Weekly config backup
ad_step "Configure weekly backup" bash "$SCRIPT_DIR/setup_backup.sh"

# 16. Weekly repo self-update
ad_step "Configure repo self-update" bash "$SCRIPT_DIR/setup_repo_autoupdate.sh"

# 17. GRUB theme
ad_step "Install GRUB theme" bash "$SCRIPT_DIR/setup_grub_theme.sh"

# 18. Plymouth theme (boot + shutdown)
ad_step "Install Plymouth theme" bash "$SCRIPT_DIR/setup_plymouth_theme.sh"

# Final verification + summary
ad_verify

echo
echo "=== Setup complete @ $(date -Is) ==="
echo "Log: $LOG"
