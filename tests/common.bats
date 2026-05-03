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

@test "ad_atomic_write writes content + mode" {
    tmp=$(mktemp -d)
    ad_atomic_write "$tmp/foo" 0644 "$(id -un):$(id -gn)" <<<"hi"
    [ "$(cat "$tmp/foo")" = "hi" ]
    perms=$(stat -c '%a' "$tmp/foo" 2>/dev/null || stat -f '%A' "$tmp/foo")
    [ "$perms" = "644" ]
}

@test "ad_is_supported_distro returns 0 on ubuntu" {
    cat > /tmp/ad-os-release <<'EOF'
ID=ubuntu
ID_LIKE=debian
VERSION_CODENAME=noble
PRETTY_NAME="Ubuntu 24.04"
EOF
    run bash -c '. lib/common.sh; ID=ubuntu ad_is_supported_distro'
    [ "$status" -eq 0 ]
}
