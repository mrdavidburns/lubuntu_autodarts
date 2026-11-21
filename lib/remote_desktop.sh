#!/bin/bash
# Install Google's Linux host on supported architectures.
ad_install_remote_desktop() {
    local arch tmp rc=0
    arch=$(dpkg --print-architecture) || return 1
    if [ "$arch" != amd64 ]; then
        ad_warn "Chrome Remote Desktop host is unavailable for $arch; skipping."
        return 0
    fi
    if dpkg-query -W -f='${Status}' chrome-remote-desktop 2>/dev/null | grep -qx 'install ok installed'; then
        echo "Chrome Remote Desktop host already installed."
        return 0
    fi
    tmp=$(mktemp -d) || return 1
    chmod 0755 "$tmp"
    ad_retry 4 curl -fsSL https://dl.google.com/linux/direct/chrome-remote-desktop_current_amd64.deb -o "$tmp/chrome-remote-desktop.deb" || rc=$?
    if [ "$rc" -eq 0 ]; then
        ad_apt install "$tmp/chrome-remote-desktop.deb" || rc=$?
    fi
    rm -rf "$tmp"
    return "$rc"
}
