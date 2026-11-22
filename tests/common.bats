#!/usr/bin/env bats

setup() {
    cd "$BATS_TEST_DIRNAME/.."
    # shellcheck disable=SC1091
    . lib/common.sh
}

@test "ad_actual_user falls back to USER when no SUDO_USER" {
    unset SUDO_USER
    USER=test
    [ "$(ad_actual_user)" = "test" ]
}

@test "ad_actual_user uses SUDO_USER when set" {
    SUDO_USER=other
    [ "$(ad_actual_user)" = "other" ]
}

@test "ad_actual_user ignores SUDO_USER=root" {
    SUDO_USER=root
    USER=fallback
    [ "$(ad_actual_user)" = "fallback" ]
}

@test "ad_home_for resolves /etc/passwd home" {
    if ! command -v getent >/dev/null 2>&1; then
        skip "getent is available on the supported Linux systems"
    fi
    home=$(ad_home_for "root")
    [ "$home" = "/root" ] || [ "$home" = "/var/root" ]
}

@test "ad_retry succeeds on first try" {
    run ad_retry 3 true
    [ "$status" -eq 0 ]
}

@test "ad_retry fails after exhausting tries" {
    AD_RETRY_NO_SLEEP=1
    run bash -c '. lib/common.sh; ad_retry 2 false'
    [ "$status" -ne 0 ]
}

@test "ad_apt stops when the package lock is unavailable" {
    ad_wait_apt_lock() { return 1; }
    ad_retry() { shift; "$@"; }
    run ad_apt update
    [ "$status" -ne 0 ]
    [ -z "$output" ]
}

@test "waits for the apt archive lock before proceeding" {
    tmp=$(mktemp -d)
    fuser() {
        [ "$1" = /var/cache/apt/archives/lock ] || return 1
        [ ! -f "$tmp/released" ]
    }
    sleep() { touch "$tmp/released"; }
    ad_warn() { :; }
    ad_wait_apt_lock 10
    [ -f "$tmp/released" ]
    rm -rf "$tmp"
}

@test "rechecks package locks after a failed apt attempt" {
    tmp=$(mktemp -d)
    ad_wait_apt_lock() { echo checked >> "$tmp/checks"; }
    apt-get() {
        if [ ! -f "$tmp/attempted" ]; then touch "$tmp/attempted"; return 1; fi
    }
    sleep() { :; }
    ad_warn() { :; }
    ad_apt install zram-tools
    [ "$(wc -l < "$tmp/checks" | tr -d ' ')" = 2 ]
    rm -rf "$tmp"
}

@test "ad_atomic_write writes content + mode" {
    tmp=$(mktemp -d)
    ad_atomic_write "$tmp/foo" 0644 "$(id -un):$(id -gn)" <<<"hi"
    [ "$(cat "$tmp/foo")" = "hi" ]
    perms=$(stat -c '%a' "$tmp/foo" 2>/dev/null || stat -f '%A' "$tmp/foo")
    [ "$perms" = "644" ]
}

@test "ad_is_supported_distro returns 0 on ubuntu" {
    ad_os_load() { ad_os_id=ubuntu; ad_os_id_like=debian; }
    run ad_is_supported_distro
    [ "$status" -eq 0 ]
}

@test "ad_step propagates failures" {
    run ad_step "failed operation" false
    [ "$status" -ne 0 ]
    [[ "$output" == *"setup stopped"* ]]
}
