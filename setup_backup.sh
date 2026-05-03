#!/bin/bash
# Part of lubuntu_autodarts - MIT License
#
# Weekly tarball of kiosk-relevant config + SUIT into ~/Backups.
# Keeps the last 4 backups; older ones get pruned automatically.

set -euo pipefail

if [ "$EUID" -ne 0 ]; then
    exec sudo -E "$0" "$@"
fi

ACTUAL_USER="${SUDO_USER:-$USER}"
ACTUAL_HOME=$(eval echo ~"$ACTUAL_USER")

BACKUP_BIN="/usr/local/bin/autodarts-backup"
cat > "$BACKUP_BIN" <<EOF
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

# Prune to last 4
ls -1t "\$DEST"/autodarts-config-*.tar.gz 2>/dev/null | tail -n +5 | xargs -r rm -f

logger -t autodarts-backup "wrote \$ARCHIVE"
EOF
chmod 0755 "$BACKUP_BIN"

# Weekly cron — Sunday 03:30, before unattended-upgrades reboot window.
cat > /etc/cron.d/autodarts-backup <<EOF
# Weekly AutoDarts kiosk config backup. Managed by lubuntu_autodarts.
30 3 * * 0 root $BACKUP_BIN
EOF
chmod 0644 /etc/cron.d/autodarts-backup

echo "Backup helper installed: $BACKUP_BIN"
echo "Schedule: Sundays 03:30 → ~/Backups (last 4 kept)."
