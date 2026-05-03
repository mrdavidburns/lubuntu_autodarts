#!/bin/bash
# Shared helpers for lubuntu_autodarts setup scripts.
# Source — do not execute directly.

# Detect target user even when re-execed under sudo.
ad_actual_user() {
    if [ -n "${SUDO_USER:-}" ] && [ "${SUDO_USER}" != "root" ]; then
        echo "$SUDO_USER"
    else
        echo "$USER"
    fi
}

ad_actual_home() {
    eval echo "~$(ad_actual_user)"
}

# Run as the actual (non-root) user, with their HOME and DISPLAY.
ad_run_as_user() {
    local user
    user=$(ad_actual_user)
    sudo -u "$user" -H "$@"
}

# Print a section header to stderr (visible even when stdout is teed).
ad_section() {
    printf '\n\033[1;36m==> %s\033[0m\n' "$*" >&2
}

ad_warn() { printf '\033[1;33mWARN:\033[0m %s\n' "$*" >&2; }
ad_ok()   { printf '\033[1;32m OK:\033[0m %s\n' "$*" >&2; }
ad_err()  { printf '\033[1;31mERR:\033[0m %s\n' "$*" >&2; }

# Run a labelled step. Failure becomes a warning, not a crash.
ad_step() {
    local label="$1"; shift
    ad_section "$label"
    if "$@"; then
        ad_ok "$label"
    else
        ad_warn "step '$label' failed (continuing)."
    fi
}
