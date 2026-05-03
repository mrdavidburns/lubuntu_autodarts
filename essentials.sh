#!/bin/bash
# Part of lubuntu_autodarts - MIT License
# See LICENSE file for details

set -euo pipefail

# Re-exec under sudo so the whole script runs as root with $SUDO_USER set.
if [ "$EUID" -ne 0 ]; then
    exec sudo -E "$0" "$@"
fi

if [ -z "${SUDO_USER:-}" ] || [ "$SUDO_USER" = "root" ]; then
    echo "Error: run as a normal user via sudo (do not run as root directly)." >&2
    exit 1
fi

ACTUAL_USER="$SUDO_USER"
ACTUAL_HOME=$(eval echo ~"$ACTUAL_USER")

# Capture absolute script directory so it remains valid after any cd operations
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# Per-step error handling: warn and continue rather than abort the whole run.
run_step() {
    local label="$1"; shift
    echo
    echo "==> $label"
    if ! "$@"; then
        echo "Warning: step '$label' failed (continuing)." >&2
    fi
}

apt update
apt install -y curl wget software-properties-common lsb-release

# 1. Install Google Chrome (idempotent)
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
run_step "Install Google Chrome" install_chrome

# 2. Install AutoDarts (run as actual user so groups + $HOME are correct)
run_step "Install AutoDarts" \
    sudo -u "$ACTUAL_USER" bash -c 'bash <(curl -sL get.autodarts.io)'

# 3. Configure LXQt Autostart for Chrome fullscreen
run_step "Configure Chrome autostart" \
    sudo -u "$ACTUAL_USER" -H bash "$SCRIPT_DIR/setup_chrome_autostart.sh"

# 4. System tools (fastfetch, btop). Use distro fastfetch if available.
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
run_step "Install fastfetch + btop" install_system_tools

# 5. Install SUIT inside a venv to avoid PEP 668 breakage
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
            echo "Warning: SUIT requirements install failed."
    fi
    if [ -f "$suit_dir/create_launcher.py" ]; then
        sudo -u "$ACTUAL_USER" bash -c "cd '$suit_dir' && '.venv/bin/python' create_launcher.py"
    fi
}
run_step "Install SUIT" install_suit

# 6. HDMI audio (pavucontrol + per-user default-sink helper)
run_step "Configure HDMI audio" bash "$SCRIPT_DIR/setup_audio_hdmi.sh"

# 7. Desktop customization (wallpaper, panel, quick launch)
apply_desktop_customizations() {
    sudo -u "$ACTUAL_USER" mkdir -p "$ACTUAL_HOME/Pictures" "$ACTUAL_HOME/.local/share/icons"

    if [ -f "$SCRIPT_DIR/images/four-darts-desktop-wallpaper.webp" ]; then
        sudo -u "$ACTUAL_USER" cp "$SCRIPT_DIR/images/four-darts-desktop-wallpaper.webp" "$ACTUAL_HOME/Pictures/"
        sudo -u "$ACTUAL_USER" -H pcmanfm-qt \
            --set-wallpaper="$ACTUAL_HOME/Pictures/four-darts-desktop-wallpaper.webp" \
            --wallpaper-mode=stretch || \
            echo "Warning: pcmanfm-qt wallpaper set failed (no DISPLAY?)."
    else
        echo "Warning: wallpaper image missing."
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
    else
        echo "Warning: $panel_conf missing — skip panel tweaks."
    fi
}
run_step "Apply desktop customizations" apply_desktop_customizations

# 8. SDDM autologin for kiosk operation
run_step "Configure SDDM autologin" bash "$SCRIPT_DIR/setup_autologin.sh" "$ACTUAL_USER"

# 9. GRUB theme
run_step "Install GRUB theme" bash "$SCRIPT_DIR/setup_grub_theme.sh"

# 10. Plymouth theme (boot + shutdown screen)
run_step "Install Plymouth theme" bash "$SCRIPT_DIR/setup_plymouth_theme.sh"

echo
echo "Installation and configuration complete."
echo "Reboot to see boot/shutdown screens, GRUB theme, and HDMI audio routing."
