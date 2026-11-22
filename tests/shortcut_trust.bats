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

@test "login retry trusts only unchanged registered shortcuts" {
    mkdir -p "$TEST_DIR/home/Desktop" "$TEST_DIR/home/.config/autodarts/shortcut-trust" "$TEST_DIR/bin"
    printf 'launcher\n' > "$TEST_DIR/home/Desktop/RustDesk.desktop"
    printf 'changed\n' > "$TEST_DIR/home/Desktop/Reboot.desktop"
    printf 'old\n' | sha256sum | cut -d ' ' -f1 > "$TEST_DIR/home/.config/autodarts/shortcut-trust/Reboot.sha256"
    sha256sum "$TEST_DIR/home/Desktop/RustDesk.desktop" | cut -d ' ' -f1 > "$TEST_DIR/home/.config/autodarts/shortcut-trust/RustDesk.sha256"
    cat > "$TEST_DIR/bin/gio" <<'SCRIPT'
#!/bin/sh
printf '%s\n' "$2" >> "$TEST_DIR/trusted"
SCRIPT
    chmod +x "$TEST_DIR/bin/gio"
    run env HOME="$TEST_DIR/home" PATH="$TEST_DIR/bin:$PATH" bash lib/refresh-shortcut-trust
    [ "$status" -eq 0 ]
    grep -Fxq "$TEST_DIR/home/Desktop/RustDesk.desktop" "$TEST_DIR/trusted"
    ! grep -q Reboot "$TEST_DIR/trusted"
}
