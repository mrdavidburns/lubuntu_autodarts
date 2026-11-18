#!/bin/bash
# Pre-flight checks for the AutoDarts kiosk install.
# Source — do not execute directly. Requires lib/common.sh.

ad_preflight() {
    local fail=0

    ad_section "Pre-flight checks"

    ad_os_load
    ad_ok "OS: ${ad_os_pretty:-unknown}"
    if ad_is_supported_distro; then
        ad_ok "Distro family: Ubuntu/Debian (.deb) — recognized; feature support varies."
    else
        ad_err "Unsupported distro '${ad_os_id:-?}'. This installer supports Ubuntu/Debian (.deb) distributions."
        fail=1
    fi

    if ad_retry 3 curl -fsSL --max-time 10 https://dl.google.com/linux/linux_signing_key.pub -o /dev/null; then
        ad_ok "Google Chrome signing key reachable."
    else
        ad_err "Cannot reach Google's Chrome signing key; check connectivity and DNS."
        fail=1
    fi

    local free_kb
    free_kb=$(df -k / | awk 'NR==2 {print $4}')
    if [ "${free_kb:-0}" -lt 3145728 ]; then
        ad_err "Less than 3 GB free on /. Found ${free_kb} KB."
        fail=1
    else
        ad_ok "Disk free on /: $((free_kb / 1024)) MB."
    fi

    if lspci 2>/dev/null | grep -Ei 'vga|3d|display' >/dev/null; then
        local gpu
        gpu=$(lspci 2>/dev/null | grep -Ei 'vga|3d|display' | head -1 | cut -d: -f3- | sed 's/^ //')
        ad_ok "GPU: $gpu"
    else
        ad_warn "GPU not detected via lspci."
    fi

    if aplay -l 2>/dev/null | grep -q '^card '; then
        ad_ok "ALSA cards present."
    else
        ad_warn "No ALSA cards detected — HDMI audio config may no-op."
    fi

    local home
    home=$(ad_actual_home)
    if [ -d "$home/autodarts" ] || systemctl list-units 2>/dev/null | grep -q autodarts; then
        ad_warn "Existing AutoDarts install detected — installer is idempotent."
    fi

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

ad_confirm() {
    if [ "${AD_AUTOCONFIRM:-0}" = "1" ]; then
        ad_ok "AD_AUTOCONFIRM=1 — skipping prompt."
        return 0
    fi
    cat >&2 <<EOF

Installation mode: $AD_INSTALL_MODE
Both modes install AutoDarts, Chrome/Chromium, SUIT, system tools,
operator commands, weekly backups and repository self-updates. Both modes
configure desktop branding where supported, install GRUB (when present)
and Plymouth branding, mask sleep/hibernate,
and reset UFW to deny incoming traffic except mDNS and Tailscale.
EOF
    if [ "$AD_INSTALL_MODE" = kiosk ]; then
        cat >&2 <<EOF

Kiosk mode also configures fullscreen browser startup, autologin, HDMI
audio, security upgrades, and kiosk hardening
(including Bluetooth and power-button settings).
Some desktop-specific features depend on the detected session.
EOF
    else
        cat >&2 <<EOF

Desktop mode leaves kiosk setup steps out. Existing kiosk configuration
is not removed. Start AutoDarts in your browser when needed.
EOF
    fi
    echo >&2
    read -r -p "Proceed? [y/N] " ans </dev/tty || ans=""
    case "$ans" in
        y | Y | yes | YES) return 0 ;;
        *)
            ad_err "Aborted by user."
            return 1
            ;;
    esac
}
