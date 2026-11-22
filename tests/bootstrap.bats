#!/usr/bin/env bats

setup() {
    TEST_DIR=$(mktemp -d)
    BOOTSTRAP="$PWD/install.sh"
    git init --bare -q "$TEST_DIR/remote.git"
    git clone -q "$TEST_DIR/remote.git" "$TEST_DIR/source" 2>/dev/null
    git -C "$TEST_DIR/source" config user.email test@example.com
    git -C "$TEST_DIR/source" config user.name Test
    printf '#!/bin/bash\necho setup-complete\n' > "$TEST_DIR/source/essentials.sh"
    printf 'old\n' > "$TEST_DIR/source/setup_example.sh"
    git -C "$TEST_DIR/source" add .
    git -C "$TEST_DIR/source" commit -qm initial
    git -C "$TEST_DIR/source" push -q origin HEAD
    git clone -q "$TEST_DIR/remote.git" "$TEST_DIR/target"
    chmod +x "$TEST_DIR/target/setup_example.sh"
    printf 'new\n' > "$TEST_DIR/source/setup_example.sh"
    git -C "$TEST_DIR/source" commit -qam update
    git -C "$TEST_DIR/source" push -q origin HEAD
}

teardown() { rm -rf "$TEST_DIR"; }

@test "repairs legacy permission changes and updates the checkout" {
    run env AUTODARTS_REPO_DIR="$TEST_DIR/target" bash "$BOOTSTRAP"
    [ "$status" -eq 0 ]
    [[ "$output" == *"Repaired executable permissions"* ]]
    [[ "$output" == *"setup-complete"* ]]
    [ "$(cat "$TEST_DIR/target/setup_example.sh")" = new ]
    [ ! -x "$TEST_DIR/target/setup_example.sh" ]
}

@test "preserves real edits and stops the update" {
    printf 'personal change\n' > "$TEST_DIR/target/setup_example.sh"
    run env AUTODARTS_REPO_DIR="$TEST_DIR/target" bash "$BOOTSTRAP"
    [ "$status" -ne 0 ]
    [ "$(cat "$TEST_DIR/target/setup_example.sh")" = 'personal change' ]
    [ -x "$TEST_DIR/target/setup_example.sh" ]
}
