#!/usr/bin/env bats

setup() {
    . lib/autodarts_service.sh
    TEST_DIR=$(mktemp -d)
    export TEST_DIR
    HOME_DIR="$TEST_DIR/home"
    mkdir -p "$HOME_DIR/.local/bin"
    printf '#!/bin/sh\nexit 0\n' > "$HOME_DIR/.local/bin/autodarts"
    chmod +x "$HOME_DIR/.local/bin/autodarts"
    ad_systemd_running() { return 0; }
    ad_err() { echo "$*" >&2; }
    id() { echo 1234; }
    loginctl() { echo "loginctl $*" >> "$TEST_DIR/calls"; }
    systemctl() {
        echo "systemctl $*" >> "$TEST_DIR/calls"
        if [ "$1" = is-active ]; then [ "${SYSTEM_ACTIVE:-0}" = 1 ]; else return 0; fi
    }
    sudo() {
        while [ "$#" -gt 0 ]; do
            case "$1" in
                -u) shift 2 ;;
                -H) shift ;;
                *) break ;;
            esac
        done
        if [ "$1" = env ]; then
            shift
            while [[ "$1" == *=* ]]; do shift; done
            echo "user $*" >> "$TEST_DIR/calls"
            case "$*" in
                *'show autodarts.service'*) echo "${LOAD_STATE:-not-found}" ;;
                *'enable --now'* ) [ "${ENABLE_FAIL:-0}" = 0 ] ;;
                *) return 0 ;;
            esac
        else
            "$@"
        fi
    }
}

teardown() { rm -rf "$TEST_DIR"; }

@test "creates and starts a supervised user service" {
    run ad_setup_autodarts_service tester "$HOME_DIR"
    [ "$status" -eq 0 ]
    grep -Fxq 'ExecStart=%h/.local/bin/autodarts run' "$HOME_DIR/.config/systemd/user/autodarts.service"
    grep -Fxq 'Restart=always' "$HOME_DIR/.config/systemd/user/autodarts.service.d/50-autodarts-supervision.conf"
    grep -q 'loginctl enable-linger tester' "$TEST_DIR/calls"
    grep -q 'enable --now autodarts.service' "$TEST_DIR/calls"
    grep -q 'is-active --quiet autodarts.service' "$TEST_DIR/calls"
}

@test "preserves an existing user service" {
    mkdir -p "$HOME_DIR/.config/systemd/user"
    printf 'existing service\n' > "$HOME_DIR/.config/systemd/user/autodarts.service"
    LOAD_STATE=loaded
    run ad_setup_autodarts_service tester "$HOME_DIR"
    [ "$status" -eq 0 ]
    [ "$(cat "$HOME_DIR/.config/systemd/user/autodarts.service")" = 'existing service' ]
}

@test "refuses to start a second board when the system service is active" {
    SYSTEM_ACTIVE=1
    run ad_setup_autodarts_service tester "$HOME_DIR"
    [ "$status" -ne 0 ]
    [[ "$output" == *'system-wide AutoDarts service is already running'* ]]
    [ ! -e "$HOME_DIR/.config/systemd/user/autodarts.service" ]
}

@test "reports failure when service cannot be enabled" {
    ENABLE_FAIL=1
    run ad_setup_autodarts_service tester "$HOME_DIR"
    [ "$status" -ne 0 ]
}
