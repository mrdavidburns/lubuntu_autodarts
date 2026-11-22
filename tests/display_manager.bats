#!/usr/bin/env bats

setup() {
    . lib/display_manager.sh
    TEST_DIR=$(mktemp -d)
}

@test "preserves an existing Wayland session and rejects missing session entries" {
    mkdir -p "$TEST_DIR/x11" "$TEST_DIR/wayland"
    touch "$TEST_DIR/x11/lxqt.desktop" "$TEST_DIR/wayland/lxqt-wayland.desktop"
    printf '[Autologin]\nSession=lxqt-wayland.desktop\n' > "$TEST_DIR/config"
    run ad_sddm_session "$TEST_DIR/config" "$TEST_DIR/state" "$TEST_DIR/x11" "$TEST_DIR/wayland"
    [ "$output" = lxqt-wayland.desktop ]
    printf '[Autologin]\nSession=missing.desktop\n' > "$TEST_DIR/config"
    run ad_sddm_session "$TEST_DIR/config" "$TEST_DIR/state" "$TEST_DIR/x11" "$TEST_DIR/wayland"
    [ "$output" = lxqt.desktop ]
}

teardown() { rm -rf "$TEST_DIR"; }

@test "uses configured display manager even when another is installed" {
    printf '/usr/sbin/lightdm\n' > "$TEST_DIR/manager"
    command() { return 0; }
    run ad_display_manager "$TEST_DIR/manager"
    [ "$status" -eq 0 ]
    [ "$output" = lightdm ]
}

@test "does not silently configure a different manager when the configured one is unknown" {
    printf '/usr/sbin/example-dm\n' > "$TEST_DIR/manager"
    run ad_display_manager "$TEST_DIR/manager"
    [ "$output" = unknown ]
}
