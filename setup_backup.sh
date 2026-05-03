#!/bin/bash
# Part of lubuntu_autodarts - MIT License
#
# Weekly tarball of kiosk-relevant config + SUIT into ~/Backups via a
# systemd timer. Keeps the last 4 backups.

set -euo pipefail

if [ "$EUID" -ne 0 ]; then
    exec sudo -E "$0" "$@"
fi

ACTUAL_USER="${SUDO_USER:-${USER:-$(id -un)}}"
ACTUAL_HOME=$(getent passwd "$ACTUAL_USER" | cut -d: -f6)
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck disable=SC1091
. "$SCRIPT_DIR/lib/common.sh"

BACKUP_BIN="/usr/local/bin/autodarts-backup"

ad_atomic_write "$BACKUP_BIN" 0755 root:root <<EOF
#!/bin/bash
# Weekly kiosk config backup. Created by setup_backup.sh.
set -euo pipefail
USER_HOME="$ACTUAL_HOME"
DEST="\$USER_HOME/Backups"
mkdir -p "\$DEST"
TS=\$(date +%Y%m%d-%H%M%S)
ARCHIVE="\$DEST/autodarts-config-\$TS.tar.gz"

tar --warning=no-file-changed -czf "\$ARCHIVE" \\
    -C "\$USER_HOME" \\
    --ignore-failed-read \\
    .config/autodarts \\
    .config/lxqt \\
    .config/autostart \\
    .config/systemd/user \\
    .local/bin \\
    SUIT 2>/dev/null || true

chown $ACTUAL_USER:$ACTUAL_USER "\$ARCHIVE"

# Retention: drop archives older than 28 days.
find "\$DEST" -maxdepth 1 -name 'autodarts-config-*.tar.gz' -type f -mtime +28 -delete

logger -t autodarts-backup "wrote \$ARCHIVE"
EOF

# Drop the legacy cron file from earlier installs.
rm -f /etc/cron.d/autodarts-backup

ad_atomic_write /etc/systemd/system/autodarts-backup.service 0644 root:root <<EOF
[Unit]
Description=AutoDarts kiosk config backup
After=network-online.target

[Service]
Type=oneshot
ExecStart=$BACKUP_BIN
Nice=10
IOSchedulingClass=idle
EOF

ad_atomic_write /etc/systemd/system/autodarts-backup.timer 0644 root:root <<'EOF'
[Unit]
Description=Weekly AutoDarts kiosk config backup
[Timer]
OnCalendar=Sun 03:30
Persistent=true
RandomizedDelaySec=15m
[Install]
WantedBy=timers.target
EOF

if [ -d /run/systemd/system ]; then
    systemctl daemon-reload
    systemctl enable --now autodarts-backup.timer
else
    echo "systemd not running (likely a container) — skip enable."
fi

ad_ok "Backup helper installed: $BACKUP_BIN"
ad_ok "Timer: autodarts-backup.timer (Sundays 03:30, ±15m jitter)."
