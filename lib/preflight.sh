#!/bin/bash
# Pre-flight checks for the AutoDarts kiosk install.
# Source — do not execute directly. Requires lib/common.sh.

ad_preflight() {
    local fail=0

    ad_section "Pre-flight checks"

    # OS / Lubuntu detection
    if [ -r /etc/os-release ]; then
        . /etc/os-release
        ad_ok "OS: ${PRETTY_NAME:-unknown}"
    else
        ad_warn "/etc/os-release missing — distro unknown."
    fi

    # Internet
    if curl -fsS --max-time 5 https://dl.google.com/linux/direct/ -o /dev/null; then
        ad_ok "Internet reachable."
    else
        ad_err "No internet — installer needs apt + Chrome download."
        fail=1
    fi

    # Disk free (need ~3 GB)
    local free_kb
    free_kb=$(df -k / | awk 'NR==2 {print $4}')
    if [ "${free_kb:-0}" -lt 3145728 ]; then
        ad_err "Less than 3 GB free on /. Found ${free_kb} KB."
        fail=1
    else
        ad_ok "Disk free on /: $((free_kb / 1024)) MB."
    fi

    # GPU
    if lspci 2>/dev/null | grep -Ei 'vga|3d|display' >/dev/null; then
        local gpu
        gpu=$(lspci 2>/dev/null | grep -Ei 'vga|3d|display' | head -1 | cut -d: -f3- | sed 's/^ //')
        ad_ok "GPU: $gpu"
    else
        ad_warn "GPU not detected via lspci."
    fi

    # Audio
    if aplay -l 2>/dev/null | grep -q '^card '; then
        ad_ok "ALSA cards present."
    else
        ad_warn "No ALSA cards detected — HDMI audio config may no-op."
    fi

    # Existing AutoDarts install
    if [ -d "$(ad_actual_home)/autodarts" ] || systemctl list-units 2>/dev/null | grep -q autodarts; then
        ad_warn "Existing AutoDarts install detected — installer is idempotent but will re-run steps."
    fi

    # Sudo group
    if id -nG "$(ad_actual_user)" | grep -qw sudo; then
        ad_ok "User '$(ad_actual_user)' in sudo group."
    else
        ad_err "User '$(ad_actual_user)' is not in sudo group."
        fail=1
    fi

    if [ "$fail" -ne 0 ]; then
        ad_err "Pre-flight failed. Resolve the issues above and re-run."
        return 1
    fi

    ad_ok "Pre-flight clean."
}

# Confirmation prompt with summary; supports AD_AUTOCONFIRM=1 for unattended runs.
ad_confirm() {
    if [ "${AD_AUTOCONFIRM:-0}" = "1" ]; then
        ad_ok "AD_AUTOCONFIRM=1 — skipping prompt."
        return 0
    fi
    cat >&2 <<EOF

The installer will:
  - Install Google Chrome, AutoDarts, SUIT, fastfetch, btop, pavucontrol
  - Configure Chrome to launch fullscreen at $AUTODARTS_URL on login
  - Install GRUB + Plymouth boot/shutdown themes
  - Set Digital Stereo (HDMI) Output as default audio sink
  - Configure SDDM autologin for user '$(ad_actual_user)'
  - Enable unattended security upgrades + nightly reboot window
  - Disable screen blanking / sleep / notifications during kiosk use
  - Add desktop shortcuts (Reboot, Shutdown, Sound Test, Open SUIT)
  - Install Ctrl+Alt+Q exit-kiosk hotkey
  - Schedule weekly config backup + repo self-update
  - Install autodarts-status command

EOF
    read -r -p "Proceed? [y/N] " ans </dev/tty || ans=""
    case "$ans" in
        y|Y|yes|YES) return 0 ;;
        *) ad_err "Aborted by user."; return 1 ;;
    esac
}
