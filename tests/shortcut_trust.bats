#!/usr/bin/env bats

setup() {
    . lib/shortcut_trust.sh
    TEST_DIR=$(mktemp -d)
    export TEST_DIR
    id() { echo 987654321; }
    sudo() { printf '%s\n' "$@" > "$TEST_DIR/args"; }
}

teardown() { rm -rf "$TEST_DIR"; }

@test "trusts the specific launcher with the PCManFM-Qt metadata key" {
    run ad_trust_shortcut example '/home/example/Desktop/RustDesk.desktop'
    [ "$status" -eq 0 ]
    grep -Fxq 'dbus-run-session' "$TEST_DIR/args"
    grep -Fxq '/home/example/Desktop/RustDesk.desktop' "$TEST_DIR/args"
    grep -Fxq 'metadata::trust' "$TEST_DIR/args"
    grep -Fxq 'true' "$TEST_DIR/args"
}

@test "reports a metadata write failure" {
    sudo() { return 1; }
    run ad_trust_shortcut example '/home/example/Desktop/RustDesk.desktop'
    [ "$status" -ne 0 ]
}
