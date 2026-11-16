#!/bin/bash
# Part of lubuntu_autodarts - MIT License
#
# Linux performance and stability tuning for AutoDarts kiosks:
#   - Disable USB autosuspend for UVC webcams
#   - Set CPU scaling governor to performance (when supported)
#   - Boost AutoDarts daemon CPU/IO priority via systemd drop-ins
#   - Cap systemd-journald disk usage to protect small SSD/eMMC storage
#   - Enable zstd ZRAM swap + tune vfs_cache_pressure

set -euo pipefail

if [ "$EUID" -ne 0 ]; then
    exec sudo -E "$0" "$@"
fi

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck disable=SC1091
. "$SCRIPT_DIR/lib/common.sh"

ad_section "Linux performance & stability tuning"

# 1. Disable USB autosuspend for UVC video cameras (interface class 0e).
ad_atomic_write /etc/udev/rules.d/99-autodarts-usb-camera.rules 0644 root:root <<'EOF'
# Keep USB webcams awake for AutoDarts camera inference.
ACTION=="add", SUBSYSTEM=="usb", ATTR{bInterfaceClass}=="0e", TEST=="../power/control", ATTR{../power/control}="on"
EOF
if [ -d /run/udev ] && command -v udevadm >/dev/null 2>&1; then
    udevadm control --reload-rules >/dev/null 2>&1 || true
    udevadm trigger --subsystem-match=usb >/dev/null 2>&1 || true
fi
ad_ok "USB camera autosuspend disabled via udev."

# 2. CPU scaling governor -> performance (best-effort; VMs/containers may not expose cpufreq).
ad_atomic_write /usr/local/sbin/autodarts-cpu-governor 0755 root:root <<'EOF'
#!/bin/sh
for gov in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor; do
    [ -w "$gov" ] || continue
    avail="$(dirname "$gov")/scaling_available_governors"
    if [ -r "$avail" ] && grep -qw performance "$avail"; then
        echo performance >"$gov" 2>/dev/null || true
    fi
done
EOF

ad_atomic_write /etc/systemd/system/autodarts-cpu-governor.service 0644 root:root <<'EOF'
[Unit]
Description=Set CPU scaling governor to performance for AutoDarts
After=multi-user.target

[Service]
Type=oneshot
ExecStart=/usr/local/sbin/autodarts-cpu-governor

[Install]
WantedBy=multi-user.target
EOF

if [ -d /run/systemd/system ]; then
    systemctl daemon-reload
    systemctl enable --now autodarts-cpu-governor.service || true
else
    /usr/local/sbin/autodarts-cpu-governor || true
fi
ad_ok "CPU governor service installed (performance when supported)."

# 3. Prioritize AutoDarts daemon over background maintenance tasks.
for dropin_dir in \
    /etc/systemd/system/autodarts.service.d \
    /etc/systemd/user/autodarts.service.d; do
    mkdir -p "$dropin_dir"
    ad_atomic_write "$dropin_dir/10-performance.conf" 0644 root:root <<'EOF'
[Service]
Nice=-5
IOSchedulingClass=best-effort
IOSchedulingPriority=2
EOF
done
if [ -d /run/systemd/system ]; then
    systemctl daemon-reload || true
fi
ad_ok "AutoDarts service priority drop-ins installed."

# 4. Cap systemd-journald disk usage.
mkdir -p /etc/systemd/journald.conf.d
ad_atomic_write /etc/systemd/journald.conf.d/autodarts.conf 0644 root:root <<'EOF'
[Journal]
SystemMaxUse=100M
RuntimeMaxUse=50M
EOF
if [ -d /run/systemd/system ]; then
    systemctl restart systemd-journald || true
fi
ad_ok "journald disk cap configured (100M)."

# 5. Kernel VM tuning + ZRAM swap (protects 4-8 GB mini-PCs without SSD thrashing).
ad_atomic_write /etc/sysctl.d/99-autodarts-performance.conf 0644 root:root <<'EOF'
vm.swappiness=10
vm.vfs_cache_pressure=50
EOF
if [ -w /proc/sys/vm/swappiness ] && command -v sysctl >/dev/null 2>&1; then
    sysctl --system >/dev/null 2>&1 || true
fi

if apt-cache show zram-tools >/dev/null 2>&1; then
    if ad_apt install zram-tools; then
        ad_atomic_write /etc/default/zramswap 0644 root:root <<'EOF'
ALGO=zstd
PERCENT=50
PRIORITY=100
EOF
        if [ -d /run/systemd/system ]; then
            systemctl enable --now zramswap.service || true
        fi
        ad_ok "ZRAM swap configured (zstd, 50% RAM)."
    else
        ad_warn "zram-tools install failed; continuing without ZRAM."
    fi
else
    ad_warn "zram-tools package not available; skipping ZRAM setup."
fi
