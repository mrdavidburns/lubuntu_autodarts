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

    ad_check "Google Chrome installed" command -v google-chrome-stable
    ad_check "AutoDarts installer ran (HOME/autodarts present)" \
        test -d "$home/autodarts"
    ad_check "SUIT cloned" test -d "$home/SUIT/.git"
    ad_check "Plymouth default = autodarts" \
        bash -c 'plymouth-set-default-theme | grep -q "^autodarts$"'
    ad_check "GRUB theme installed" test -d /boot/grub/themes/autodarts
    ad_check "pavucontrol installed" command -v pavucontrol
    ad_check "HDMI helper installed" \
        test -x "$home/.local/bin/set-hdmi-audio.sh"
    ad_check "SDDM autologin configured" \
        test -f /etc/sddm.conf.d/10-autodarts-autologin.conf
    ad_check "User in autologin group" \
        bash -c "id -nG '$user' | grep -qw autologin"
    ad_check "unattended-upgrades installed" \
        dpkg -s unattended-upgrades
    ad_check "Chrome systemd user unit present" \
        test -f "$home/.config/systemd/user/autodarts-chrome.service"
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
    cat >&2 <<EOF
Reboot to apply boot themes, autologin, and audio routing.
After reboot, run:  autodarts-status
EOF
}
