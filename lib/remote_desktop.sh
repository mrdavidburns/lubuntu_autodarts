#!/bin/bash
# Install the pinned official RustDesk package on supported architectures.
ad_install_remote_desktop() {
    local arch asset version=1.5.3 tmp rc=0
    arch=$(dpkg --print-architecture) || return 1
    case "$arch" in
        amd64) asset=x86_64 ;;
        arm64) asset=aarch64 ;;
        armhf) asset=armv7-sciter ;;
        *)
            ad_warn "RustDesk has no configured package for $arch; skipping."
            return 0
            ;;
    esac
    if dpkg-query -W -f='${Status}' rustdesk 2>/dev/null | grep -qx 'install ok installed'; then
        echo "RustDesk already installed."
        return 0
    fi
    tmp=$(mktemp -d) || return 1
    chmod 0755 "$tmp"
    ad_retry 4 curl -fsSL "https://github.com/rustdesk/rustdesk/releases/download/$version/rustdesk-$version-$asset.deb" -o "$tmp/rustdesk.deb" || rc=$?
    if [ "$rc" -eq 0 ]; then
        if [ "$(dpkg-deb -f "$tmp/rustdesk.deb" Package 2>/dev/null)" != rustdesk ] \
            || [ "$(dpkg-deb -f "$tmp/rustdesk.deb" Architecture 2>/dev/null)" != "$arch" ]; then
            ad_err "Downloaded RustDesk package has an unexpected identity or architecture."
            rc=1
        elif apt-get -s install "$tmp/rustdesk.deb" >"$tmp/apt-simulation.log" 2>&1; then
            ad_apt install "$tmp/rustdesk.deb" || rc=$?
        else
            cat "$tmp/apt-simulation.log"
            ad_warn "RustDesk dependencies could not be resolved; skipping RustDesk and continuing setup."
        fi
    fi
    rm -rf "$tmp"
    return "$rc"
}
