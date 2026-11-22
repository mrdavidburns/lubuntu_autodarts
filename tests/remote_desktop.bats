#!/usr/bin/env bats

setup() {
    . lib/remote_desktop.sh
    TEST_DIR=$(mktemp -d)
    export TEST_DIR
    ad_warn() { echo "$*"; }
    ad_err() { echo "$*"; }
    ad_retry() { shift; "$@"; }
    dpkg() { echo "${TEST_ARCH:-amd64}"; }
    dpkg-query() { return 1; }
    dpkg-deb() {
        case "$3" in
            Package) echo rustdesk ;;
            Architecture) echo "${TEST_PACKAGE_ARCH:-${TEST_ARCH:-amd64}}" ;;
        esac
    }
    curl() { printf '%s' "$2" > "$TEST_DIR/url"; printf 'package' > "$4"; }
    apt-get() { [ "$1" = -s ] && [ "$2" = install ] && [ -f "$3" ]; }
    ad_apt() { [ "$1" = install ] && [ -f "$2" ] && echo installed > "$TEST_DIR/result"; }
}

teardown() { rm -rf "$TEST_DIR"; }

@test "selects and installs the matching package for each supported architecture" {
    for pair in amd64:x86_64 arm64:aarch64 armhf:armv7-sciter; do
        TEST_ARCH=${pair%%:*}
        run ad_install_remote_desktop
        [ "$status" -eq 0 ]
        [ -f "$TEST_DIR/result" ]
        grep -q "rustdesk-1.5.3-${pair#*:}.deb" "$TEST_DIR/url"
        rm "$TEST_DIR/result"
    done
}

@test "skips unsupported architectures" {
    TEST_ARCH=i386
    run ad_install_remote_desktop
    [ "$status" -eq 0 ]
    [[ "$output" == *"no configured package for i386"* ]]
    [ ! -f "$TEST_DIR/result" ]
}

@test "skips an incompatible package without changing packages" {
    apt-get() { echo 'dependency cannot be satisfied'; return 100; }
    run ad_install_remote_desktop
    [ "$status" -eq 0 ]
    [[ "$output" == *"dependency cannot be satisfied"* ]]
    [[ "$output" == *"skipping RustDesk"* ]]
    [ ! -f "$TEST_DIR/result" ]
}

@test "rejects a package for the wrong architecture" {
    TEST_PACKAGE_ARCH=arm64
    run ad_install_remote_desktop
    [ "$status" -ne 0 ]
    [[ "$output" == *"unexpected identity or architecture"* ]]
    [ ! -f "$TEST_DIR/result" ]
}

@test "propagates download failure" {
    curl() { return 22; }
    run ad_install_remote_desktop
    [ "$status" -eq 22 ]
    [ ! -f "$TEST_DIR/result" ]
}
