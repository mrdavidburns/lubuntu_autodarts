#!/usr/bin/env bats
# Unit tests for desktop branding and performance setup scripts.

@test "legacy Chrome autostart migration" {
    python3 -m unittest discover -s tests -p 'test_chrome_autostart.py'
}

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
    grep -q "WallpaperMode=stretch" "$tmp/.config/pcmanfm-qt/lxqt/settings.conf"
    grep -q "PerScreenWallpaper=false" "$tmp/.config/pcmanfm-qt/lxqt/settings.conf"
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
    grep -q "WallpaperMode=stretch" "$tmp/.config/pcmanfm-qt/lxqt/settings.conf"
    rm -rf "$tmp"
}

@test "setup_desktop_branding.sh, setup_performance.sh, and setup_grub_theme.sh pass bash -n" {
    bash -n essentials.sh
    bash -n setup_autologin.sh
    bash -n setup_chrome_watchdog.sh
    bash -n setup_desktop_branding.sh
    bash -n setup_performance.sh
    bash -n setup_grub_theme.sh
}

@test "ad_is_supported_distro accepts debian, linuxmint, pop, and raspbian" {
    . lib/common.sh
    for distro in debian linuxmint pop raspbian; do
        ad_os_load() { ad_os_id="$distro"; ad_os_id_like="debian"; }
        run ad_is_supported_distro
        [ "$status" -eq 0 ]
    done
}

@test "GRUB theme skips before installing or writing when GRUB configuration is absent" {
    local tmp
    tmp=$(mktemp -d)
    mkdir -p "$tmp/bin"
    sed "s|GRUB_CFG=\"/etc/default/grub\"|GRUB_CFG=\"$tmp/missing-grub\"|" setup_grub_theme.sh > "$tmp/setup_grub_theme.sh"
    printf '#!/bin/sh\necho called >> "%s"\nexit 1\n' "$tmp/sudo-called" > "$tmp/bin/sudo"
    printf '#!/bin/sh\nexit 0\n' > "$tmp/bin/update-grub"
    chmod +x "$tmp/bin/sudo" "$tmp/bin/update-grub"
    run env PATH="$tmp/bin:$PATH" bash "$tmp/setup_grub_theme.sh"
    [ "$status" -eq 0 ]
    [[ "$output" == *"GRUB not detected; skipping GRUB theme."* ]]
    [ ! -e "$tmp/sudo-called" ]
    rm -rf "$tmp"
}

@test "configure_desktop.py brands Fancy Menu without changing other settings" {
    local tmp
    tmp=$(mktemp -d)
    mkdir -p "$tmp/.config/lxqt"
    cat > "$tmp/.config/lxqt/panel.conf" <<'PANEL'
[menu2]
type=fancymenu
menu_file=/etc/xdg/menus/lxqt-applications-compact.menu
ownIcon=false
showText=false

[clock]
type=worldclock
PANEL
    HOME="$tmp" python3 configure_desktop.py
    cp "$tmp/.config/lxqt/panel.conf" "$tmp/first"
    HOME="$tmp" python3 configure_desktop.py
    cmp "$tmp/first" "$tmp/.config/lxqt/panel.conf"
    grep -Fq "icon=$tmp/.local/share/icons/autodarts-favicon.png" "$tmp/first"
    grep -Fxq 'ownIcon=true' "$tmp/first"
    grep -Fxq 'showText=true' "$tmp/first"
    grep -Fxq 'text=" AUTODARTS"' "$tmp/first"
    grep -Fxq 'menu_file=/etc/xdg/menus/lxqt-applications-compact.menu' "$tmp/first"
    grep -Fxq 'type=worldclock' "$tmp/first"
    rm -rf "$tmp"
}
