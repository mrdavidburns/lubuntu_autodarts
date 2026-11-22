#!/usr/bin/env bats

setup() {
    TEST_DIR=$(mktemp -d)
    export TEST_DIR
    mkdir -p "$TEST_DIR/bin"
    cat > "$TEST_DIR/bin/sudo.ws" <<'SCRIPT'
#!/bin/bash
for arg in "$@"; do
    printf '%s\n' "$arg" >> "$TEST_DIR/arguments"
    case "$arg" in
        PATH=*)
            paths=${arg#PATH=}
            wrapper=${paths%%:*}/sudo
            test -x "$wrapper" || exit 9
            cat "$wrapper" > "$TEST_DIR/wrapper"
            printf '%s\n' "${paths%%:*}" > "$TEST_DIR/wrapper_dir"
            ;;
    esac
done
SCRIPT
    chmod +x "$TEST_DIR/bin/sudo.ws"
    export PATH="$TEST_DIR/bin:$PATH"
    ACTUAL_USER=tester
    eval "$(sed -n '/^install_autodarts() {/,/^}/p' essentials.sh)"
}

teardown() { rm -rf "$TEST_DIR"; }

@test "upstream nested sudo uses classic sudo and the temporary wrapper is removed" {
    run install_autodarts
    [ "$status" -eq 0 ]
    grep -Fq "$TEST_DIR/bin/sudo.ws" "$TEST_DIR/wrapper"
    grep -Fq 'https://autodarts.sh' "$TEST_DIR/arguments"
    grep -Fq 'bash "$installer" --headless' "$TEST_DIR/arguments"
    [ ! -e "$(cat "$TEST_DIR/wrapper_dir")" ]
}
