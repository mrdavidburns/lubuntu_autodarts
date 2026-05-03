#!/bin/bash
# Part of lubuntu_autodarts - MIT License
#
# Optional Tailscale enrollment for remote support of AutoDarts kiosks.
# Disabled by default — only runs when AD_ENABLE_TAILSCALE=1.
#
# Usage:
#   AD_ENABLE_TAILSCALE=1 TS_AUTHKEY=tskey-... ./setup_tailscale.sh
#
# Defaults applied for kiosk hardening:
#   --ssh         (Tailscale SSH; disable by setting TS_SSH=0)
#   --accept-dns=false
#   --hostname=<hostname>-autodarts

set -euo pipefail

if [ "${AD_ENABLE_TAILSCALE:-0}" != "1" ]; then
    echo "Tailscale opt-in not requested (AD_ENABLE_TAILSCALE != 1). Skipping."
    exit 0
fi

if [ "$EUID" -ne 0 ]; then
    exec sudo -E "$0" "$@"
fi

if ! command -v tailscale >/dev/null 2>&1; then
    echo "Installing Tailscale..."
    curl -fsSL https://tailscale.com/install.sh | sh
fi

systemctl enable --now tailscaled

if [ -z "${TS_AUTHKEY:-}" ]; then
    echo "TS_AUTHKEY not set — skipping 'tailscale up'."
    echo "Run manually: sudo tailscale up --ssh --accept-dns=false"
    exit 0
fi

HOSTNAME_TAG="$(hostnamectl --static 2>/dev/null || hostname)-autodarts"
SSH_FLAG="--ssh"
[ "${TS_SSH:-1}" = "0" ] && SSH_FLAG=""

tailscale up \
    --auth-key="$TS_AUTHKEY" \
    --accept-dns=false \
    --hostname="$HOSTNAME_TAG" \
    $SSH_FLAG

echo "Tailscale up. IP: $(tailscale ip -4 2>/dev/null | head -1)"
