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
ACTUAL_HOME=$(getent passwd "$ACTUAL_USER" | cut -d: -f6)
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck disable=SC1091
. "$SCRIPT_DIR/lib/common.sh"

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
    git fetch --quiet origin
    LOCAL=\$(git rev-parse HEAD)
    REMOTE=\$(git rev-parse @{u} 2>/dev/null || echo "\$LOCAL")
    if [ "\$LOCAL" = "\$REMOTE" ]; then
        echo "No upstream changes."
        exit 0
    fi
    echo "Pulling \$LOCAL → \$REMOTE"
    git pull --ff-only --quiet
    chmod +x essentials.sh setup_*.sh install.sh bin/* 2>/dev/null || true
    echo "Re-running essentials.sh unattended..."
    AD_AUTOCONFIRM=1 ./essentials.sh
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
