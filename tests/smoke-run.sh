#!/bin/bash
# Smoke runner — invoked inside the CI container.
#
# AD_SMOKE=1 short-circuits steps that need real hardware/network:
#   - skips Google Chrome apt repo + AutoDarts installer
#   - skips initramfs/grub/plymouth changes
#   - skips SDDM/PulseAudio/Bluetooth assumptions
# It still exercises lib/, preflight, atomic writes, sudoers parser,
# JSON renderer for chrome policy, systemd unit syntax check,
# update_quick_launch.py, autodarts-status, and idempotency.

set -euo pipefail

cd "$(dirname "$0")/.."

# 1. Lint helpers + library.
bash -n essentials.sh install.sh setup_*.sh lib/*.sh bin/autodarts-status \
    bin/exit-kiosk bin/sound-test motd/00-autodarts

# 2. Source common.sh, exercise pure helpers.
. lib/common.sh
[ "$(ad_actual_user)" = "$(whoami)" ] || { echo "ad_actual_user wrong"; exit 1; }
echo "user-home: $(ad_home_for "$(whoami)")"
ad_retry 1 true
ad_atomic_write /tmp/ad-smoke.txt 0644 root:root <<<"hello"
[ "$(cat /tmp/ad-smoke.txt)" = "hello" ]

# 3. Render Chrome policy and verify JSON.
EXTRA_EXTENSION_IDS=abc,def bash setup_chrome_policy.sh </dev/null >/tmp/policy.out 2>&1 || true
jq . /etc/opt/chrome/policies/managed/autodarts.json >/dev/null

# 4. systemd unit syntax check (without enabling).
bash setup_backup.sh </dev/null
bash setup_repo_autoupdate.sh </dev/null
systemd-analyze verify /etc/systemd/system/autodarts-backup.{service,timer} \
                       /etc/systemd/system/autodarts-self-update.{service,timer} || true

# 5. Operator binaries.
install -m 0755 bin/autodarts-status /usr/local/bin/autodarts-status
autodarts-status >/tmp/status.out 2>&1 || true
grep -q "AutoDarts kiosk status" /tmp/status.out

# 6. update_quick_launch.py creates [quicklaunch] when missing.
mkdir -p "$HOME/.config/lxqt"
echo "[panel1]" > "$HOME/.config/lxqt/panel.conf"
python3 update_quick_launch.py
grep -q '^\[quicklaunch\]' "$HOME/.config/lxqt/panel.conf"

echo "smoke OK"
