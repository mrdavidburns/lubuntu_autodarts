#!/usr/bin/env bats

setup() {
    . lib/common.sh
    . lib/mode.sh
    MODE_TEST_DIR=$(mktemp -d)
}

teardown() {
    rm -rf "$MODE_TEST_DIR"
}

@test "explicit desktop or kiosk choice overrides saved mode" {
    printf 'kiosk\n' > "$MODE_TEST_DIR/mode"
    AD_KIOSK_MODE=0 ad_select_mode "$MODE_TEST_DIR/mode"
    [ "$AD_INSTALL_MODE" = desktop ]
    printf 'desktop\n' > "$MODE_TEST_DIR/mode"
    AD_KIOSK_MODE=1 ad_select_mode "$MODE_TEST_DIR/mode"
    [ "$AD_INSTALL_MODE" = kiosk ]
}

@test "unattended runs preserve saved desktop mode and legacy kiosk default" {
    printf 'desktop\n' > "$MODE_TEST_DIR/mode"
    AD_AUTOCONFIRM=1 ad_select_mode "$MODE_TEST_DIR/mode"
    [ "$AD_INSTALL_MODE" = desktop ]
    AD_AUTOCONFIRM=1 ad_select_mode "$MODE_TEST_DIR/absent"
    [ "$AD_INSTALL_MODE" = kiosk ]
}

@test "invalid explicit or saved mode fails instead of changing behavior" {
    run env AD_KIOSK_MODE=maybe bash -c '. lib/common.sh; . lib/mode.sh; ad_select_mode "$1"' _ "$MODE_TEST_DIR/absent"
    [ "$status" -ne 0 ]
    printf 'unexpected\n' > "$MODE_TEST_DIR/mode"
    run env AD_AUTOCONFIRM=1 bash -c '. lib/common.sh; . lib/mode.sh; ad_select_mode "$1"' _ "$MODE_TEST_DIR/mode"
    [ "$status" -ne 0 ]
}

@test "desktop verification omits kiosk-only checks" {
    . lib/verify.sh
    ad_actual_home() { printf '%s\n' "$MODE_TEST_DIR"; }
    ad_actual_user() { printf 'tester\n'; }
    ad_check() { printf '%s\n' "$1" >> "$MODE_TEST_DIR/checks"; }
    AD_INSTALL_MODE=desktop ad_verify
    grep -q 'Chrome or Chromium installed' "$MODE_TEST_DIR/checks"
    grep -q 'self-update timer enabled' "$MODE_TEST_DIR/checks"
    grep -q 'Plymouth default' "$MODE_TEST_DIR/checks"
    ! grep -q 'autologin\|HDMI helper\|Chrome systemd user' "$MODE_TEST_DIR/checks"
}

@test "shared hardening masks sleep and sets firewall rules in both modes" {
    . lib/system_hardening.sh
    systemctl() { printf 'systemctl %s\n' "$*" >> "$MODE_TEST_DIR/calls"; }
    ufw() { printf 'ufw %s\n' "$*" >> "$MODE_TEST_DIR/calls"; }
    ad_ok() { :; }
    for mode in kiosk desktop; do
        : > "$MODE_TEST_DIR/calls"
        AD_INSTALL_MODE="$mode" ad_apply_sleep_and_firewall
        grep -q 'systemctl mask sleep.target suspend.target hibernate.target hybrid-sleep.target' "$MODE_TEST_DIR/calls"
        grep -q 'ufw --force reset' "$MODE_TEST_DIR/calls"
        grep -q 'ufw default deny incoming' "$MODE_TEST_DIR/calls"
        grep -q 'ufw --force enable' "$MODE_TEST_DIR/calls"
    done
}
