#!/bin/bash
# Part of lubuntu_autodarts - MIT License
#
# Schedule a weekly `git pull` on the repo clone via a systemd timer so
# config/script updates from upstream land automatically. Reruns
# essentials.sh in unattended mode (AD_AUTOCONFIRM=1) only when the local
# clone is behind upstream.
#
# Disable any time:
#   sudo systemctl disable --now autodarts-self-update.timer

set -euo pipefail

if [ "$EUID" -ne 0 ]; then
    exec sudo -E "$0" "$@"
fi

ACTUAL_USER="${SUDO_USER:-${USER:-$(id -un)}}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck disable=SC1091
. "$SCRIPT_DIR/lib/common.sh"

if ! sudo -u "$ACTUAL_USER" -H git -C "$SCRIPT_DIR" rev-parse --show-toplevel >/dev/null 2>&1; then
    ad_warn "No Git checkout found; skipping repository self-update."
    exit 0
fi

UPDATER="/usr/local/bin/autodarts-self-update"
LOG="/var/log/autodarts-self-update.log"
touch "$LOG"
chmod 0644 "$LOG"

ad_atomic_write "$UPDATER" 0755 root:root <<EOF
#!/bin/bash
# Pull repo + rerun essentials.sh if anything changed.
set -euo pipefail
REPO="$SCRIPT_DIR"
LOG="$LOG"
{
    echo "=== \$(date -Is) ==="
    cd "\$REPO"
    sudo -u "$ACTUAL_USER" -H git fetch --quiet origin
    LOCAL=\$(sudo -u "$ACTUAL_USER" -H git rev-parse HEAD)
    REMOTE=\$(sudo -u "$ACTUAL_USER" -H git rev-parse '@{u}')
    if [ "\$LOCAL" = "\$REMOTE" ]; then
        echo "No upstream changes."
        exit 0
    fi
    echo "Pulling \$LOCAL → \$REMOTE"
    sudo -u "$ACTUAL_USER" -H git pull --ff-only --quiet
    echo "Re-running essentials.sh unattended..."
    SUDO_USER="$ACTUAL_USER" AD_AUTOCONFIRM=1 bash ./essentials.sh
    echo "Self-update finished."
} >> "\$LOG" 2>&1
EOF

# Drop any legacy cron file from earlier installs.
rm -f /etc/cron.d/autodarts-repo-autoupdate

ad_atomic_write /etc/systemd/system/autodarts-self-update.service 0644 root:root <<EOF
[Unit]
Description=AutoDarts kiosk self-update (git pull + rerun essentials.sh)
After=network-online.target
Wants=network-online.target

[Service]
Type=oneshot
ExecStart=$UPDATER
TimeoutStartSec=30m
Nice=15
IOSchedulingClass=idle
EOF

ad_atomic_write /etc/systemd/system/autodarts-self-update.timer 0644 root:root <<'EOF'
[Unit]
Description=Weekly AutoDarts repo self-update
[Timer]
OnCalendar=Sun 03:00
Persistent=true
RandomizedDelaySec=15m
[Install]
WantedBy=timers.target
EOF

if [ -d /run/systemd/system ]; then
    systemctl daemon-reload
    systemctl enable --now autodarts-self-update.timer
else
    echo "systemd not running (likely a container) — skip enable."
fi

ad_ok "Self-update scheduled: Sundays 03:00 (±15m). Log: $LOG"
