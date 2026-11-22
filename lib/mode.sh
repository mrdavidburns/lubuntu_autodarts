#!/bin/bash
# Installation mode selection. Source after lib/common.sh.

ad_select_mode() {
    local mode_file="${1:-/etc/autodarts/install-mode}" saved="" answer
    if [ -f "$mode_file" ]; then
        saved=$(cat "$mode_file")
        case "$saved" in
            kiosk | desktop) ;;
            *)
                ad_err "Invalid saved installation mode in $mode_file."
                return 1
                ;;
        esac
    fi
    if [ -n "${AD_KIOSK_MODE+x}" ]; then
        case "$AD_KIOSK_MODE" in
            1) AD_INSTALL_MODE=kiosk ;;
            0) AD_INSTALL_MODE=desktop ;;
            *)
                ad_err "AD_KIOSK_MODE must be 1 (kiosk) or 0 (desktop)."
                return 1
                ;;
        esac
    elif [ "${AD_AUTOCONFIRM:-0}" = 1 ]; then
        # Preserve the historical kiosk default for pre-existing unattended installs.
        AD_INSTALL_MODE="${saved:-kiosk}"
    else
        printf '\nChoose installation mode:\n  1) Kiosk: fullscreen browser, autologin and kiosk system settings\n  2) Desktop: apps and shared system settings without fullscreen or autologin\n' >/dev/tty
        if [ "$saved" = desktop ]; then
            printf 'Selection [2]: ' >/dev/tty
        else
            printf 'Selection [1]: ' >/dev/tty
        fi
        if ! read -r answer </dev/tty; then
            ad_err "Cannot read a mode selection; set AD_KIOSK_MODE=1 or 0."
            return 1
        fi
        case "$answer" in
            1 | kiosk | Kiosk) AD_INSTALL_MODE=kiosk ;;
            2 | desktop | Desktop) AD_INSTALL_MODE=desktop ;;
            '') AD_INSTALL_MODE="${saved:-kiosk}" ;;
            *)
                ad_err "Invalid selection: choose 1 or 2."
                return 1
                ;;
        esac
    fi
    export AD_INSTALL_MODE
    ad_ok "Installation mode: $AD_INSTALL_MODE."
    if [ "$AD_INSTALL_MODE" = desktop ]; then
        ad_warn "Desktop mode does not undo kiosk settings from an earlier installation."
    fi
    return 0
}
