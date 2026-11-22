#!/bin/bash
# Post-install verification summary.
# Source — do not execute directly. Requires lib/common.sh.

ad_check() {
    local label="$1"
    shift
    if "$@" >/dev/null 2>&1; then
        ad_ok "$label"
    else
        ad_warn "$label"
    fi
}

ad_verify() {
    ad_section "Post-install verification"
    local home
    home=$(ad_actual_home)
    local user
    user=$(ad_actual_user)

    ad_check "Chrome or Chromium installed" bash -c 'command -v google-chrome-stable || command -v chromium || command -v chromium-browser'
    ad_check "AutoDarts headless command installed" \
        test -x "$home/.local/bin/autodarts"
    ad_check "SUIT cloned" test -d "$home/SUIT/.git"
    ad_check "Plymouth default = autodarts" \
        bash -c 'plymouth-set-default-theme | grep -q "^autodarts$"'
    if [ -f /etc/default/grub ]; then
        ad_check "GRUB theme installed" test -d /boot/grub/themes/autodarts
    fi
    if [ "${AD_INSTALL_MODE:-kiosk}" = kiosk ]; then
        ad_check "pavucontrol installed" command -v pavucontrol
        ad_check "HDMI helper installed" \
            test -x "$home/.local/bin/set-hdmi-audio.sh"
        ad_check "Display manager autologin configured" \
            bash -c 'test -f /etc/sddm.conf.d/10-autodarts-autologin.conf || test -f /etc/lightdm/lightdm.conf.d/10-autodarts-autologin.conf || grep -qs "^AutomaticLoginEnable=True" /etc/gdm3/custom.conf /etc/gdm/custom.conf'
        ad_check "User in autologin group" \
            bash -c "id -nG '$user' | grep -qw autologin"
        ad_check "unattended-upgrades installed" \
            dpkg -s unattended-upgrades
        ad_check "Chrome systemd user unit present" \
            test -f "$home/.config/systemd/user/autodarts-chrome.service"
    fi
    ad_check "autodarts-status on PATH" command -v autodarts-status
    ad_check "backup timer enabled" \
        systemctl is-enabled autodarts-backup.timer
    ad_check "self-update timer enabled" \
        systemctl is-enabled autodarts-self-update.timer

    echo
    ad_section "Boot timing (last boot)"
    if command -v systemd-analyze >/dev/null 2>&1; then
        systemd-analyze 2>/dev/null | sed 's/^/  /' || true
    fi

    echo
    echo "Reboot to apply boot branding and system settings." >&2
    echo "Run: autodarts-status" >&2
}
