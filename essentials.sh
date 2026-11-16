#!/bin/bash
# Part of lubuntu_autodarts - MIT License
# See LICENSE file for details
#
# One-shot kiosk setup. Re-execs under sudo, logs to /var/log/autodarts-setup.log,
# runs preflight + every step + post-install verify. Set AD_AUTOCONFIRM=1 to
# skip the confirmation prompt (used by the weekly self-update cron).

set -Eeuo pipefail

if [ "$EUID" -ne 0 ]; then
    exec sudo -E "$0" "$@"
fi

if [ -z "${SUDO_USER:-}" ] || [ "$SUDO_USER" = "root" ]; then
    echo "Error: run as a normal user via sudo (do not run as root directly)." >&2
    exit 1
fi

# Serialize against self-update cron + concurrent manual runs.
LOCK=/var/lock/autodarts-setup.lock
mkdir -p "$(dirname "$LOCK")"
exec 9>"$LOCK"
if ! flock -n 9; then
    echo "Another autodarts setup is running (lock: $LOCK). Exiting." >&2
    exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck disable=SC1091
. "$SCRIPT_DIR/lib/common.sh"
# shellcheck disable=SC1091
. "$SCRIPT_DIR/lib/preflight.sh"
# shellcheck disable=SC1091
. "$SCRIPT_DIR/lib/verify.sh"

trap 'ad_on_err $LINENO $? "$BASH_COMMAND"' ERR

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
ad_repair_user_paths "$ACTUAL_USER"
AUTODARTS_URL="${AUTODARTS_URL:-https://play.autodarts.io/}"
export AUTODARTS_URL

ad_preflight || exit 1
ad_confirm || exit 1

apt update
apt update
apt install -y curl wget lsb-release ca-certificates
if apt-cache show software-properties-common >/dev/null 2>&1; then
    apt install -y software-properties-common
fi

# 1. Google Chrome (amd64) or Chromium (non-amd64) — verified by GPG / apt.
install_chrome() {
    local arch
    arch=$(dpkg --print-architecture 2>/dev/null || echo amd64)
    if [ "$arch" != "amd64" ]; then
        if command -v chromium >/dev/null 2>&1 || command -v chromium-browser >/dev/null 2>&1; then
            echo "Chromium already installed ($arch)."
            return 0
        fi
        if apt-cache show chromium >/dev/null 2>&1; then
            ad_apt install chromium
        elif apt-cache show chromium-browser >/dev/null 2>&1; then
            ad_apt install chromium-browser
        else
            ad_err "No supported Chrome/Chromium package found for architecture '$arch'."
            return 1
        fi
        return 0
    fi
    if command -v google-chrome-stable >/dev/null 2>&1; then
        echo "google-chrome-stable already installed."
        return 0
    fi
    local key=/etc/apt/keyrings/google-chrome.gpg
    mkdir -p /etc/apt/keyrings
    if [ ! -f "$key" ]; then
        ad_retry 4 bash -o pipefail -c "curl -fsSL https://dl.google.com/linux/linux_signing_key.pub | \
            gpg --dearmor -o '$key'" || return 1
        chmod 0644 "$key"
    fi
    ad_atomic_write /etc/apt/sources.list.d/google-chrome.list 0644 root:root <<EOF
deb [arch=amd64 signed-by=$key] https://dl.google.com/linux/chrome/deb/ stable main
EOF
    ad_apt update || return 1
    ad_apt install google-chrome-stable
}
ad_step "Install Google Chrome / Chromium" install_chrome

# 2. AutoDarts (run as kiosk user)
ad_step "Install AutoDarts" \
    sudo -u "$ACTUAL_USER" -H bash -c '
        set -e
        installer=$(mktemp)
        trap '\''rm -f "$installer"'\'' EXIT
        curl -fsSL https://get.autodarts.io -o "$installer"
        bash "$installer"
    '

# 3. Chrome managed-policy + force-installed extensions
ad_step "Install Chrome managed policy" bash "$SCRIPT_DIR/setup_chrome_policy.sh"

# 4. System tools (fastfetch, btop)
install_system_tools() {
    apt install -y btop || return 1
    if apt-cache show fastfetch >/dev/null 2>&1; then
        apt install -y fastfetch
    elif [ "${ad_os_id:-}" = "ubuntu" ] && command -v add-apt-repository >/dev/null 2>&1; then
        add-apt-repository -y ppa:zhangsongcui3371/fastfetch || return 1
        apt update || return 1
        apt install -y fastfetch
    else
        ad_warn "fastfetch is not available in apt on ${ad_os_id:-this distro}; skipping."
    fi
}
ad_step "Install fastfetch + btop" install_system_tools

# 5. SUIT inside its own venv. SUIT_REF pins to a specific commit/tag/branch
# so upstream surprise can't break the kiosk silently. Default: main HEAD.
install_suit() {
    apt install -y python3-tk python3-dbus python3-pip python3-venv git libdbus-1-dev || return 1
    local suit_dir="$ACTUAL_HOME/SUIT"
    local suit_ref="${SUIT_REF:-main}"
    if [ -d "$suit_dir/.git" ]; then
        sudo -u "$ACTUAL_USER" git -C "$suit_dir" fetch --quiet origin || return 1
    else
        sudo -u "$ACTUAL_USER" git clone https://github.com/IteraThor/SUIT.git "$suit_dir" || return 1
    fi
    sudo -u "$ACTUAL_USER" git -C "$suit_dir" checkout --quiet "$suit_ref" \
        || {
            ad_err "SUIT ref '$suit_ref' not found."
            return 1
        }
    if [ ! -d "$suit_dir/.venv" ]; then
        sudo -u "$ACTUAL_USER" python3 -m venv "$suit_dir/.venv" --system-site-packages || return 1
    fi
    if [ -f "$suit_dir/requirements.txt" ]; then
        sudo -u "$ACTUAL_USER" "$suit_dir/.venv/bin/pip" install --upgrade pip || return 1
        sudo -u "$ACTUAL_USER" "$suit_dir/.venv/bin/pip" install -r "$suit_dir/requirements.txt" \
            || return 1
    fi
    if [ -f "$suit_dir/create_launcher.py" ]; then
        sudo -u "$ACTUAL_USER" bash -c "cd '$suit_dir' && '.venv/bin/python' create_launcher.py"
    fi
}
ad_step "Install SUIT" install_suit

# 6. Audio
ad_step "Configure HDMI audio" bash "$SCRIPT_DIR/setup_audio_hdmi.sh"

# 7. Desktop customization
ad_step "Apply desktop customizations" bash "$SCRIPT_DIR/setup_desktop_branding.sh"

# 8. Operator UX: status command, sound test, MOTD, VERSION pin
install_operator_tools() {
    install -m 0755 "$SCRIPT_DIR/bin/autodarts-status" /usr/local/bin/autodarts-status
    install -m 0755 "$SCRIPT_DIR/bin/sound-test" /usr/local/bin/sound-test
    install -m 0755 "$SCRIPT_DIR/bin/exit-kiosk" /usr/local/bin/exit-kiosk
    install -m 0755 "$SCRIPT_DIR/motd/00-autodarts" /etc/update-motd.d/00-autodarts
    install -d -m 0755 /usr/local/share/autodarts
    install -m 0644 "$SCRIPT_DIR/VERSION" /usr/local/share/autodarts/VERSION
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

# 14b. Optional Tailscale enrollment (no-op unless AD_ENABLE_TAILSCALE=1)
ad_step "Configure Tailscale (optional)" bash "$SCRIPT_DIR/setup_tailscale.sh"

# 15. Weekly config backup
ad_step "Configure weekly backup" bash "$SCRIPT_DIR/setup_backup.sh"

# 16. Weekly repo self-update
ad_step "Configure repo self-update" bash "$SCRIPT_DIR/setup_repo_autoupdate.sh"

# 17. GRUB theme
ad_step "Install GRUB theme" bash "$SCRIPT_DIR/setup_grub_theme.sh"

# 18. Plymouth theme (boot + shutdown)
ad_step "Install Plymouth theme" bash "$SCRIPT_DIR/setup_plymouth_theme.sh"

# 19. Boot/shutdown speed tuning (must run after Plymouth so it can
# merge into the GRUB cmdline Plymouth set up).
ad_step "Tune boot/shutdown speed" bash "$SCRIPT_DIR/setup_boot_speed.sh"

# 20. Linux performance & stability tuning (USB camera power, CPU governor, ZRAM, journald)
ad_step "Tune Linux performance & stability" bash "$SCRIPT_DIR/setup_performance.sh"

# Final verification + summary
ad_verify

echo
echo "=== Setup complete @ $(date -Is) ==="
echo "Log: $LOG"
