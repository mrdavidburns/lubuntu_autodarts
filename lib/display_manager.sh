#!/bin/bash
# Prefer the configured display manager over other packages left after upgrades.
ad_display_manager() {
    local path="${1:-/etc/X11/default-display-manager}" selected
    if [ -r "$path" ]; then
        read -r selected <"$path" || true
        case "${selected##*/}" in
            sddm | lightdm | gdm3 | gdm)
                printf '%s\n' "${selected##*/}"
                return 0
                ;;
            ?*)
                echo unknown
                return 0
                ;;
        esac
    fi
    if command -v sddm >/dev/null 2>&1; then
        echo sddm
    elif command -v lightdm >/dev/null 2>&1; then
        echo lightdm
    elif [ -f /etc/gdm3/custom.conf ] || [ -f /etc/gdm/custom.conf ]; then
        echo gdm3
    else
        echo unknown
    fi
}

# Keep a valid previously selected X11 or Wayland session when configuring SDDM.
ad_sddm_session() {
    local conf="$1" state="$2" xdir="$3" wdir="$4" candidate file
    for file in "$conf" "$state"; do
        [ -r "$file" ] || continue
        candidate=$(awk -F= '/^[[:space:]]*Session[[:space:]]*=/ {gsub(/^[[:space:]]+|[[:space:]\r]+$/, "", $2); print $2; exit}' "$file")
        case "$candidate" in
            '' | */*) continue ;;
            *.desktop) ;;
            *) candidate="$candidate.desktop" ;;
        esac
        if [ -f "$xdir/$candidate" ] || [ -f "$wdir/$candidate" ]; then
            printf '%s\n' "$candidate"
            return 0
        fi
    done
    if [ -f "$xdir/lxqt.desktop" ]; then
        echo lxqt.desktop
        return 0
    fi
    if [ -f "$wdir/lxqt-wayland.desktop" ]; then
        echo lxqt-wayland.desktop
        return 0
    fi
    return 1
}
