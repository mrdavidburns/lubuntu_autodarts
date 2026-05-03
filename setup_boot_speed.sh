#!/bin/bash
# Part of lubuntu_autodarts - MIT License
#
# Speed up the boot/shutdown screens. Tuned for kiosk hardware where:
#   - GRUB menu is never used.
#   - Only one kernel is in normal use.
#   - Shutdown should be quick; players will yank power if it dawdles.
#
# Skip pieces with env flags:
#   AD_BOOT_KEEP_GRUB=1        keep GRUB menu visible (don't hide)
#   AD_BOOT_KEEP_WAIT_ONLINE=1 keep NetworkManager-wait-online
#   AD_BOOT_NO_ZSTD=1          keep gzip initramfs (older Ubuntu compat)

set -euo pipefail

if [ "$EUID" -ne 0 ]; then
    exec sudo -E "$0" "$@"
fi

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck disable=SC1091
. "$SCRIPT_DIR/lib/common.sh"

GRUB_CFG=/etc/default/grub
INITRAMFS_CFG=/etc/initramfs-tools/initramfs.conf
LOGIND_TIMEOUTS=/etc/systemd/system.conf.d/00-autodarts-timeouts.conf

ad_section "Boot speed tuning"

# 1. GRUB — hide menu and zero timeout unless caller opts out.
[ -f "$GRUB_CFG" ] || {
    ad_warn "$GRUB_CFG missing — skipping GRUB tweaks"
    exit 0
}
cp "$GRUB_CFG" "$GRUB_CFG.bak.boot-speed.$(date +%F_%H-%M-%S)"

set_grub_kv() {
    local key="$1" value="$2"
    if grep -q "^${key}=" "$GRUB_CFG"; then
        sed -i "s|^${key}=.*|${key}=${value}|" "$GRUB_CFG"
    else
        echo "${key}=${value}" >>"$GRUB_CFG"
    fi
}

if [ "${AD_BOOT_KEEP_GRUB:-0}" != "1" ]; then
    set_grub_kv GRUB_TIMEOUT 0
    set_grub_kv GRUB_TIMEOUT_STYLE hidden
    set_grub_kv GRUB_RECORDFAIL_TIMEOUT 0
fi

# 2. Kernel cmdline — quiet boot + suppress udev/Tux/cursor flicker, fast KMS.
EXTRAS="vt.global_cursor_default=0 logo.nologo udev.log_level=3 i915.fastboot=1 fbcon=nodefer"
if grep -q '^GRUB_CMDLINE_LINUX_DEFAULT=' "$GRUB_CFG"; then
    current=$(grep '^GRUB_CMDLINE_LINUX_DEFAULT=' "$GRUB_CFG" | cut -d'"' -f2)
    cleaned=$(echo "$current" | tr ' ' '\n' | awk '!seen[$0]++' | tr '\n' ' ' | sed 's/ $//')
    # Ensure quiet + splash present, then append our extras (deduped).
    needed="quiet splash $EXTRAS"
    merged=$(echo "$cleaned $needed" | tr ' ' '\n' | awk 'NF && !seen[$0]++' | tr '\n' ' ' | sed 's/ $//')
    sed -i "s|^GRUB_CMDLINE_LINUX_DEFAULT=.*|GRUB_CMDLINE_LINUX_DEFAULT=\"$merged\"|" "$GRUB_CFG"
else
    echo "GRUB_CMDLINE_LINUX_DEFAULT=\"quiet splash $EXTRAS\"" >>"$GRUB_CFG"
fi

update-grub
ad_ok "GRUB: timeout hidden, cmdline tuned for fast graphical boot."

# 3. Initramfs — zstd compression (decompresses ~3x faster than gzip).
if [ "${AD_BOOT_NO_ZSTD:-0}" != "1" ] && [ -f "$INITRAMFS_CFG" ]; then
    if grep -q '^COMPRESS=' "$INITRAMFS_CFG"; then
        sed -i 's|^COMPRESS=.*|COMPRESS=zstd|' "$INITRAMFS_CFG"
    else
        echo 'COMPRESS=zstd' >>"$INITRAMFS_CFG"
    fi
    if grep -q '^COMPRESS_FILE_LIST=' "$INITRAMFS_CFG"; then :; fi
    # Force a rebuild so the change takes effect on next boot.
    update-initramfs -u -k all
    ad_ok "initramfs: zstd compression enabled."
fi

# 4. Systemd shutdown timeouts — kiosk should stop in <10s, not wait 90s.
mkdir -p "$(dirname "$LOGIND_TIMEOUTS")"
ad_atomic_write "$LOGIND_TIMEOUTS" 0644 root:root <<'EOF'
[Manager]
DefaultTimeoutStopSec=10s
DefaultTimeoutAbortSec=10s
DefaultDeviceTimeoutSec=10s
EOF
ad_ok "systemd: shutdown timeouts capped at 10s."

# 5. Lower the kiosk Chrome unit's stop timeout. Players don't care about
# orderly shutdown of a browser tab.
USER_UNIT_DIR=""
if [ -n "${SUDO_USER:-}" ] && [ "$SUDO_USER" != "root" ]; then
    USER_HOME=$(getent passwd "$SUDO_USER" | cut -d: -f6)
    USER_UNIT="$USER_HOME/.config/systemd/user/autodarts-chrome.service"
    if [ -f "$USER_UNIT" ]; then
        if grep -q '^TimeoutStopSec=' "$USER_UNIT"; then
            sed -i 's|^TimeoutStopSec=.*|TimeoutStopSec=3|' "$USER_UNIT"
        else
            sed -i '/^\[Service\]/a TimeoutStopSec=3' "$USER_UNIT"
        fi
        ad_ok "autodarts-chrome.service: TimeoutStopSec=3."
    fi
fi

# 6. Disable services that pad shutdown/boot for no kiosk benefit.
if [ "${AD_BOOT_KEEP_WAIT_ONLINE:-0}" != "1" ]; then
    for unit in NetworkManager-wait-online.service systemd-networkd-wait-online.service; do
        if systemctl list-unit-files | grep -q "^$unit"; then
            systemctl disable "$unit" >/dev/null 2>&1 || true
            systemctl mask "$unit" >/dev/null 2>&1 || true
            ad_ok "Disabled+masked $unit."
        fi
    done
fi

# motd-news pulls news on every login → noticeable on slow links.
if systemctl list-unit-files | grep -q '^motd-news.service'; then
    systemctl disable --now motd-news.timer motd-news.service >/dev/null 2>&1 || true
    ad_ok "Disabled motd-news."
fi

# apt-daily{,-upgrade} timers run on boot if they slipped a window.
# unattended-upgrades already handles patching at 04:00; disable the
# opportunistic boot-time fire so it doesn't compete with login.
for t in apt-daily.timer apt-daily-upgrade.timer; do
    if systemctl list-unit-files | grep -q "^$t"; then
        systemctl disable --now "$t" >/dev/null 2>&1 || true
    fi
done

systemctl daemon-reload

ad_ok "Boot speed tuning complete. Reboot to measure with: systemd-analyze"
