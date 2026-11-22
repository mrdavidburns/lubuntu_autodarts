#!/bin/bash
# Part of lubuntu_autodarts - MIT License
#
# Apply Winmau AutoDarts desktop branding for LXQt:
#   - Install desktop wallpaper and start-menu favicon
#   - Configure LXQt panel main-menu icon/text and pcmanfm-qt wallpaper
#   - Ensure wallpaper applies both in-session and at next LXQt login
#   - Update LXQt quick-launch pins

set -euo pipefail

if [ "$EUID" -ne 0 ]; then
    exec sudo -E "$0" "$@"
fi

ACTUAL_USER="${SUDO_USER:-${USER:-$(id -un)}}"
ACTUAL_HOME=$(getent passwd "$ACTUAL_USER" | cut -d: -f6)
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck disable=SC1091
. "$SCRIPT_DIR/lib/common.sh"
ad_repair_user_paths "$ACTUAL_USER"

WALLPAPER="winmau-autodarts-wallpaper-04-navy-spotlight-landscape.png"
ICON="autodarts-favicon.png"
USER_BIN="$ACTUAL_HOME/.local/bin"
AUTOSTART="$ACTUAL_HOME/.config/autostart"

DESKTOP=$(ad_desktop "$ACTUAL_USER")
if [ "$DESKTOP" = labwc ] && command -v pcmanfm >/dev/null 2>&1 && command -v wf-panel-pi >/dev/null 2>&1; then
    sudo -u "$ACTUAL_USER" mkdir -p "$ACTUAL_HOME/Pictures" "$ACTUAL_HOME/.local/share/icons" "$USER_BIN" "$AUTOSTART"
    sudo -u "$ACTUAL_USER" install -m 0644 "$SCRIPT_DIR/images/$WALLPAPER" "$ACTUAL_HOME/Pictures/$WALLPAPER"
    sudo -u "$ACTUAL_USER" install -m 0644 "$SCRIPT_DIR/images/$ICON" "$ACTUAL_HOME/.local/share/icons/$ICON"
    sudo -u "$ACTUAL_USER" -H python3 "$SCRIPT_DIR/configure_raspberry_desktop.py"
    # Apply once from inside the user's next graphical session, when PCManFM
    # can contact its running desktop instance. Do not override later choices.
    sudo -u "$ACTUAL_USER" tee "$USER_BIN/autodarts-pi-wallpaper" >/dev/null <<'WALLPAPER_SCRIPT'
#!/bin/sh
tries=0
while [ "$tries" -lt 30 ]; do
    if pgrep -u "$(id -u)" -x pcmanfm >/dev/null 2>&1; then
        if pcmanfm --set-wallpaper="$HOME/Pictures/winmau-autodarts-wallpaper-04-navy-spotlight-landscape.png" --wallpaper-mode=stretch; then
            rm -f "$HOME/.config/autostart/autodarts-pi-wallpaper.desktop"
            exit 0
        fi
    fi
    tries=$((tries + 1))
    sleep 1
done
exit 1
WALLPAPER_SCRIPT
    chmod 0755 "$USER_BIN/autodarts-pi-wallpaper"
    sudo -u "$ACTUAL_USER" tee "$AUTOSTART/autodarts-pi-wallpaper.desktop" >/dev/null <<DESKTOP
[Desktop Entry]
Type=Application
Name=Apply Winmau AutoDarts wallpaper
Exec=$USER_BIN/autodarts-pi-wallpaper
DESKTOP
    ad_ok "Raspberry Pi wallpaper and menu icon configured; log out and back in to apply."
    ad_warn "The Raspberry Pi menu widget does not support a separate text label."
    exit 0
fi

if [ "$DESKTOP" != lxqt ]; then
    sudo -u "$ACTUAL_USER" mkdir -p "$ACTUAL_HOME/Pictures"
    sudo -u "$ACTUAL_USER" install -m 0644 "$SCRIPT_DIR/images/$WALLPAPER" "$ACTUAL_HOME/Pictures/$WALLPAPER"
    ad_warn "Desktop '$DESKTOP': wallpaper copied to Pictures; automatic wallpaper and menu branding are only supported on LXQt."
    exit 0
fi

if [ ! -f "$ACTUAL_HOME/.config/lxqt/panel.conf" ] \
    && [ ! -f /etc/xdg/xdg-Lubuntu/lxqt/panel.conf ] \
    && [ ! -f /etc/xdg/lubuntu/lxqt/panel.conf ] \
    && [ ! -f /etc/xdg/lxqt/panel.conf ]; then
    ad_warn "LXQt panel configuration not found; skipping LXQt desktop branding."
    exit 0
fi

sudo -u "$ACTUAL_USER" mkdir -p "$ACTUAL_HOME/Pictures" \
    "$ACTUAL_HOME/.local/share/icons" "$USER_BIN" "$AUTOSTART"
sudo -u "$ACTUAL_USER" install -m 0644 "$SCRIPT_DIR/images/$WALLPAPER" \
    "$ACTUAL_HOME/Pictures/$WALLPAPER"
sudo -u "$ACTUAL_USER" install -m 0644 "$SCRIPT_DIR/images/$ICON" \
    "$ACTUAL_HOME/.local/share/icons/$ICON"
sudo -u "$ACTUAL_USER" -H python3 "$SCRIPT_DIR/configure_desktop.py"

# The live panel can overwrite changes made while it is running. Apply them
# again once in the graphical session, while the LXQt panel module is stopped.
sudo -u "$ACTUAL_USER" mkdir -p "$ACTUAL_HOME/.local/share/autodarts"
sudo -u "$ACTUAL_USER" install -m 0644 "$SCRIPT_DIR/configure_desktop.py" "$ACTUAL_HOME/.local/share/autodarts/configure_desktop.py"
sudo -u "$ACTUAL_USER" install -m 0755 "$SCRIPT_DIR/lib/apply-lxqt-branding" "$USER_BIN/autodarts-lxqt-branding"
sudo -u "$ACTUAL_USER" tee "$AUTOSTART/autodarts-lxqt-branding.desktop" >/dev/null <<DESKTOP
[Desktop Entry]
Type=Application
Name=Apply AutoDarts panel branding
Exec=$USER_BIN/autodarts-lxqt-branding
OnlyShowIn=LXQt;
DESKTOP

# Run in the user's graphical session once pcmanfm-qt --desktop is up, then
# remove the autostart entry so later user wallpaper changes persist.
sudo -u "$ACTUAL_USER" tee "$USER_BIN/autodarts-apply-wallpaper" >/dev/null <<WALLPAPER_SCRIPT
#!/bin/sh
tries=0
while [ "\$tries" -lt 20 ]; do
    if pgrep -u "\$(id -u)" -f "pcmanfm-qt.*--desktop" >/dev/null 2>&1; then
        break
    fi
    tries=\$((tries + 1))
    sleep 0.5
done
if pgrep -u "\$(id -u)" -f "pcmanfm-qt.*--desktop" >/dev/null 2>&1 \
    && pcmanfm-qt --profile=lxqt --set-wallpaper="\$HOME/Pictures/$WALLPAPER" --wallpaper-mode=stretch; then
    rm -f "\$HOME/.config/autostart/autodarts-wallpaper.desktop"
fi
WALLPAPER_SCRIPT
chmod 0755 "$USER_BIN/autodarts-apply-wallpaper"

sudo -u "$ACTUAL_USER" tee "$AUTOSTART/autodarts-wallpaper.desktop" >/dev/null <<DESKTOP
[Desktop Entry]
Type=Application
Name=Apply Winmau Autodarts wallpaper
Exec=$USER_BIN/autodarts-apply-wallpaper
OnlyShowIn=LXQt;
DESKTOP

if [ -f "$SCRIPT_DIR/update_quick_launch.py" ]; then
    sudo -u "$ACTUAL_USER" -H python3 "$SCRIPT_DIR/update_quick_launch.py"
fi

desktop_pid=$(pgrep -u "$ACTUAL_USER" -f "pcmanfm-qt.*--desktop" | head -n1 || true)
if [ -n "$desktop_pid" ] && [ -r "/proc/$desktop_pid/environ" ]; then
    desktop_env=$(tr '\0' '\n' <"/proc/$desktop_pid/environ")
    desktop_display=$(printf '%s\n' "$desktop_env" | sed -n 's/^DISPLAY=//p' | head -n1)
    desktop_xauth=$(printf '%s\n' "$desktop_env" | sed -n 's/^XAUTHORITY=//p' | head -n1)
    desktop_runtime=$(printf '%s\n' "$desktop_env" | sed -n 's/^XDG_RUNTIME_DIR=//p' | head -n1)
    desktop_dbus=$(printf '%s\n' "$desktop_env" | sed -n 's/^DBUS_SESSION_BUS_ADDRESS=//p' | head -n1)
    sudo -u "$ACTUAL_USER" -H \
        DISPLAY="${desktop_display:-:0}" \
        ${desktop_xauth:+XAUTHORITY="$desktop_xauth"} \
        ${desktop_runtime:+XDG_RUNTIME_DIR="$desktop_runtime"} \
        ${desktop_dbus:+DBUS_SESSION_BUS_ADDRESS="$desktop_dbus"} \
        "$USER_BIN/autodarts-apply-wallpaper" || true
fi

ad_ok "Desktop branding applied (takes full effect on next LXQt login)."
