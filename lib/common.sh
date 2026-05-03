#!/bin/bash
# Shared helpers for lubuntu_autodarts setup scripts.
# Source — do not execute directly.

# Detect target user even when re-execed under sudo.
ad_actual_user() {
    if [ -n "${SUDO_USER:-}" ] && [ "${SUDO_USER}" != "root" ]; then
        echo "$SUDO_USER"
    elif [ -n "${USER:-}" ]; then
        echo "$USER"
    else
        id -un
    fi
}

# Resolve a user's home from /etc/passwd; avoids `eval echo ~user`.
ad_home_for() {
    local user="$1"
    local home
    home=$(getent passwd "$user" | cut -d: -f6)
    if [ -z "$home" ]; then
        echo "ad_home_for: no passwd entry for '$user'" >&2
        return 1
    fi
    echo "$home"
}

ad_actual_home() {
    ad_home_for "$(ad_actual_user)"
}

# Run as the actual (non-root) user, with their HOME and DISPLAY.
ad_run_as_user() {
    local user
    user=$(ad_actual_user)
    sudo -u "$user" -H "$@"
}

# Logging — tagged with autodarts so journalctl -t autodarts works.
ad_log() {
    local level="$1"
    shift
    local msg="$*"
    if command -v logger >/dev/null 2>&1; then
        logger -t autodarts -p "user.$level" -- "$msg" || true
    fi
    case "$level" in
        err) printf '\033[1;31mERR:\033[0m %s\n' "$msg" >&2 ;;
        warning) printf '\033[1;33mWARN:\033[0m %s\n' "$msg" >&2 ;;
        notice) printf '\033[1;32m OK:\033[0m %s\n' "$msg" >&2 ;;
        info) printf '\033[1;36m==>\033[0m %s\n' "$msg" >&2 ;;
        *) printf '%s\n' "$msg" >&2 ;;
    esac
}
ad_section() { ad_log info "$*"; }
ad_ok() { ad_log notice "$*"; }
ad_warn() { ad_log warning "$*"; }
ad_err() { ad_log err "$*"; }

# Run a labelled step. Failure becomes a warning, not a crash.
ad_step() {
    local label="$1"
    shift
    ad_section "$label"
    if "$@"; then
        ad_ok "$label"
    else
        ad_warn "step '$label' failed (continuing)."
        return 1
    fi
}

# Atomic file write to a privileged path. Reads stdin into a temp file
# in the destination directory, then renames into place. Crash-safe.
# Usage: echo "..." | ad_atomic_write /etc/foo.conf 0644 root:root
ad_atomic_write() {
    local dest="$1"
    local mode="${2:-0644}"
    local owner="${3:-root:root}"
    local dir tmp
    dir=$(dirname "$dest")
    mkdir -p "$dir"
    tmp=$(mktemp "$dir/.autodarts.XXXXXX")
    cat >"$tmp"
    chmod "$mode" "$tmp"
    chown "$owner" "$tmp"
    mv -f "$tmp" "$dest"
}

# Retry a command with exponential backoff. Used for apt/wget/git over
# flaky kiosk wifi.
# Usage: ad_retry 5 "$@"
ad_retry() {
    local tries="${1:-5}"
    shift
    local delay=2 attempt=1
    while true; do
        if "$@"; then
            return 0
        fi
        if [ "$attempt" -ge "$tries" ]; then
            ad_err "command failed after $attempt attempts: $*"
            return 1
        fi
        ad_warn "attempt $attempt failed; retrying in ${delay}s: $*"
        sleep "$delay"
        attempt=$((attempt + 1))
        delay=$((delay * 2))
        [ "$delay" -gt 60 ] && delay=60
    done
}

# Wait for the dpkg/apt frontend lock so apt commands don't collide with
# unattended-upgrades or another setup run.
ad_wait_apt_lock() {
    local max="${1:-300}"
    local waited=0
    while fuser /var/lib/dpkg/lock-frontend >/dev/null 2>&1 \
        || fuser /var/lib/dpkg/lock >/dev/null 2>&1 \
        || fuser /var/lib/apt/lists/lock >/dev/null 2>&1; do
        if [ "$waited" -ge "$max" ]; then
            ad_err "timed out waiting for apt lock after ${max}s"
            return 1
        fi
        ad_warn "apt is locked; waiting..."
        sleep 5
        waited=$((waited + 5))
    done
    return 0
}

# Wrap apt operations: wait for lock + retry on transient failures.
ad_apt() {
    ad_wait_apt_lock
    ad_retry 4 apt-get -y "$@"
}

# Stamp file under /var/lib/autodarts to skip expensive idempotent steps.
# Usage: ad_stamp_check <stamp> <hash>; rc 0 = unchanged.
ad_stamp_dir() { echo "/var/lib/autodarts"; }
ad_stamp_check() {
    local stamp="$(ad_stamp_dir)/$1"
    local current="$2"
    [ -f "$stamp" ] && [ "$(cat "$stamp" 2>/dev/null)" = "$current" ]
}
ad_stamp_write() {
    local stamp="$(ad_stamp_dir)/$1"
    local value="$2"
    mkdir -p "$(ad_stamp_dir)"
    printf '%s\n' "$value" >"$stamp"
}

# Print failing line on bash errors. Sourced scripts opt in by:
#   set -E; trap 'ad_on_err $LINENO $? "$BASH_COMMAND"' ERR
ad_on_err() {
    local line="$1" code="$2" cmd="$3"
    ad_err "line $line: '$cmd' exited $code"
}

# Acquire an exclusive setup lock. Prevents the self-update cron from
# racing a manual install.
# Usage: ad_lock_exec "$@"  (re-execs $0 under flock)
ad_lock_exec() {
    local lock=/var/lock/autodarts-setup.lock
    if [ -z "${AD_LOCKED:-}" ]; then
        export AD_LOCKED=1
        exec flock -n "$lock" "$0" "$@"
    fi
}

# Read /etc/os-release into ad_os_id / ad_os_codename.
ad_os_load() {
    if [ -r /etc/os-release ]; then
        # shellcheck disable=SC1091
        . /etc/os-release
        ad_os_id="${ID:-unknown}"
        ad_os_id_like="${ID_LIKE:-}"
        ad_os_codename="${VERSION_CODENAME:-}"
        ad_os_pretty="${PRETTY_NAME:-unknown}"
    fi
}
ad_is_supported_distro() {
    ad_os_load
    case "$ad_os_id" in
        ubuntu | lubuntu | debian) return 0 ;;
        *)
            case "$ad_os_id_like" in
                *ubuntu* | *debian*) return 0 ;;
                *) return 1 ;;
            esac
            ;;
    esac
}
