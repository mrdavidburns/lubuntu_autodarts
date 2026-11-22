#!/usr/bin/env bats

setup() {
    TEST_DIR=$(mktemp -d)
    export TEST_DIR
    mkdir -p "$TEST_DIR/bin" "$TEST_DIR/home/.config/autostart"
    printf '#!/bin/sh\nprintf "%%s\\n" "$*" >> "$TEST_DIR/calls"\n' > "$TEST_DIR/bin/dbus-send"
    printf '#!/bin/sh\nexit 1\n' > "$TEST_DIR/bin/pgrep"
    printf '#!/bin/sh\nexit "${PYTHON_RESULT:-0}"\n' > "$TEST_DIR/bin/python3"
    chmod +x "$TEST_DIR/bin/"*
    touch "$TEST_DIR/home/.config/autostart/autodarts-lxqt-branding.desktop"
}

teardown() { rm -rf "$TEST_DIR"; }

@test "reapplies branding while the panel is stopped and starts it again" {
    run env HOME="$TEST_DIR/home" PATH="$TEST_DIR/bin:$PATH" sh lib/apply-lxqt-branding
    [ "$status" -eq 0 ]
    grep -q 'stopModule' "$TEST_DIR/calls"
    grep -q 'startModule' "$TEST_DIR/calls"
    [ ! -e "$TEST_DIR/home/.config/autostart/autodarts-lxqt-branding.desktop" ]
}

@test "restarts panel and preserves retry when branding fails" {
    run env HOME="$TEST_DIR/home" PATH="$TEST_DIR/bin:$PATH" PYTHON_RESULT=1 sh lib/apply-lxqt-branding
    [ "$status" -ne 0 ]
    grep -q 'startModule' "$TEST_DIR/calls"
    [ -e "$TEST_DIR/home/.config/autostart/autodarts-lxqt-branding.desktop" ]
}
