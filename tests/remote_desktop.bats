#!/usr/bin/env bats

setup() {
    . lib/remote_desktop.sh
    TEST_DIR=$(mktemp -d)
    export TEST_DIR
    ad_warn() { echo "$*"; }
    ad_retry() { shift; "$@"; }
    dpkg() { echo "${TEST_ARCH:-amd64}"; }
    dpkg-query() { return 1; }
    curl() { printf 'package' > "$4"; }
    ad_apt() { [ "$1" = install ] && [ -f "$2" ] && echo installed > "$TEST_DIR/result"; }
}

teardown() { rm -rf "$TEST_DIR"; }

@test "installs the host package on amd64" {
    run ad_install_remote_desktop
    [ "$status" -eq 0 ]
    [ -f "$TEST_DIR/result" ]
}

@test "skips ARM without attempting installation" {
    TEST_ARCH=arm64
    run ad_install_remote_desktop
    [ "$status" -eq 0 ]
    [[ "$output" == *"unavailable for arm64"* ]]
    [ ! -f "$TEST_DIR/result" ]
}

@test "propagates download failure" {
    curl() { return 22; }
    run ad_install_remote_desktop
    [ "$status" -eq 22 ]
    [ ! -f "$TEST_DIR/result" ]
}
