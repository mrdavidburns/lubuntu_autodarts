#!/bin/bash
# Part of lubuntu_autodarts - MIT License
#
# Schedule a weekly `git pull` on the repo clone so config/script updates
# from upstream land automatically. Reruns essentials.sh in unattended
# mode (AD_AUTOCONFIRM=1) only when commits actually change.
#
# Disable at any time:  rm /etc/cron.d/autodarts-repo-autoupdate

set -euo pipefail

if [ "$EUID" -ne 0 ]; then
    exec sudo -E "$0" "$@"
fi

ACTUAL_USER="${SUDO_USER:-$USER}"
ACTUAL_HOME=$(eval echo ~"$ACTUAL_USER")
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

UPDATER="/usr/local/bin/autodarts-self-update"
LOG="/var/log/autodarts-self-update.log"
touch "$LOG"
chmod 0644 "$LOG"

cat > "$UPDATER" <<EOF
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
chmod 0755 "$UPDATER"

# Weekly: Sunday 03:00 (before backup at 03:30, before reboot at 04:00).
cat > /etc/cron.d/autodarts-repo-autoupdate <<EOF
# Weekly self-update for lubuntu_autodarts. Managed by setup_repo_autoupdate.sh.
0 3 * * 0 root $UPDATER
EOF
chmod 0644 /etc/cron.d/autodarts-repo-autoupdate

echo "Self-update scheduled: Sundays 03:00 → $UPDATER (log: $LOG)."
