#!/usr/bin/env bats
# Unit tests for desktop branding and performance setup scripts.

@test "configure_desktop.py configures mainmenu icon, text, and wallpaper" {
    local tmp
    tmp=$(mktemp -d)
    mkdir -p "$tmp/.config/lxqt" "$tmp/.config/pcmanfm-qt/lxqt"
    cat >"$tmp/.config/lxqt/panel.conf" <<'EOF'
[General]
__userfile__=true

[mainmenu]
type=mainmenu
icon=old.png
EOF
    cat >"$tmp/.config/pcmanfm-qt/lxqt/settings.conf" <<'EOF'
[General]
FallbackIconThemeName=Papirus

[Desktop]
Wallpaper=
WallpaperMode=color
EOF

    HOME="$tmp" python3 configure_desktop.py

    grep -q "icon=$tmp/.local/share/icons/autodarts-favicon.png" "$tmp/.config/lxqt/panel.conf"
    grep -q "ownIcon=true" "$tmp/.config/lxqt/panel.conf"
    grep -q "showText=true" "$tmp/.config/lxqt/panel.conf"
    grep -q 'text=" AUTODARTS"' "$tmp/.config/lxqt/panel.conf"
    grep -q "Wallpaper=$tmp/Pictures/winmau-autodarts-wallpaper-04-navy-spotlight-landscape.png" \
        "$tmp/.config/pcmanfm-qt/lxqt/settings.conf"
    grep -q "WallpaperMode=crop" "$tmp/.config/pcmanfm-qt/lxqt/settings.conf"
    grep -q "FallbackIconThemeName=Papirus" "$tmp/.config/pcmanfm-qt/lxqt/settings.conf"
    rm -rf "$tmp"
}

@test "configure_desktop.py creates [Desktop] section when settings.conf is absent" {
    local tmp
    tmp=$(mktemp -d)
    mkdir -p "$tmp/.config/lxqt"
    cat >"$tmp/.config/lxqt/panel.conf" <<'EOF'
[mainmenu]
type=mainmenu
EOF

    HOME="$tmp" python3 configure_desktop.py

    [ -f "$tmp/.config/pcmanfm-qt/lxqt/settings.conf" ]
    grep -q '^\[Desktop\]$' "$tmp/.config/pcmanfm-qt/lxqt/settings.conf"
    grep -q "Wallpaper=$tmp/Pictures/winmau-autodarts-wallpaper-04-navy-spotlight-landscape.png" \
        "$tmp/.config/pcmanfm-qt/lxqt/settings.conf"
    grep -q "WallpaperMode=crop" "$tmp/.config/pcmanfm-qt/lxqt/settings.conf"
    rm -rf "$tmp"
}

@test "setup_desktop_branding.sh, setup_performance.sh, and setup_grub_theme.sh pass bash -n" {
    bash -n setup_desktop_branding.sh
    bash -n setup_performance.sh
    bash -n setup_grub_theme.sh
}
