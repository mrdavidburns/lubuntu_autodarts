#!/bin/bash
# Shared sleep and firewall settings for both installation modes.
ad_apply_sleep_and_firewall() {
    systemctl mask sleep.target suspend.target hibernate.target hybrid-sleep.target || return 1
    if ! command -v ufw >/dev/null 2>&1; then
        ad_apt install ufw || return 1
    fi
    ufw --force reset >/dev/null || return 1
    ufw default deny incoming || return 1
    ufw default allow outgoing || return 1
    ufw allow 5353/udp comment "mDNS" || return 1
    ufw allow in on tailscale0 comment "Tailscale tunnel" || return 1
    ufw --force enable || return 1
    ad_ok "Sleep targets masked; UFW enabled (deny incoming, mDNS and Tailscale allowed)."
}
