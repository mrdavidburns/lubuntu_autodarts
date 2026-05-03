#!/bin/bash
# Part of lubuntu_autodarts - MIT License
#
# Install + configure unattended-upgrades for security-only updates.
# Reboot window: 04:00 (kiosk is unused overnight).

set -euo pipefail

if [ "$EUID" -ne 0 ]; then
    exec sudo -E "$0" "$@"
fi

apt update
apt install -y unattended-upgrades apt-listchanges

# Enable periodic upgrades
cat >/etc/apt/apt.conf.d/20auto-upgrades <<'EOF'
APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Unattended-Upgrade "1";
APT::Periodic::AutocleanInterval "7";
APT::Periodic::Download-Upgradeable-Packages "1";
EOF

# AutoDarts-specific overrides: security only, auto reboot at 04:00.
cat >/etc/apt/apt.conf.d/52autodarts-unattended <<'EOF'
// Managed by lubuntu_autodarts — overrides 50unattended-upgrades.
Unattended-Upgrade::Allowed-Origins {
    "${distro_id}:${distro_codename}-security";
    "${distro_id}ESMApps:${distro_codename}-apps-security";
    "${distro_id}ESM:${distro_codename}-infra-security";
};
Unattended-Upgrade::Remove-Unused-Kernel-Packages "true";
Unattended-Upgrade::Remove-Unused-Dependencies "true";
Unattended-Upgrade::Automatic-Reboot "true";
Unattended-Upgrade::Automatic-Reboot-WithUsers "false";
Unattended-Upgrade::Automatic-Reboot-Time "04:00";
Unattended-Upgrade::SyslogEnable "true";
EOF

systemctl enable --now unattended-upgrades
echo "unattended-upgrades configured: security only, auto-reboot 04:00."
