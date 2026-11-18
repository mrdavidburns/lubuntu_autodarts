#!/bin/bash
# Part of lubuntu_autodarts - MIT License
#
# Bootstrap one-liner. Clones the repo into ~/lubuntu_autodarts and runs
# essentials.sh. Designed for:
#   curl -fsSL https://raw.githubusercontent.com/mrdavidburns/lubuntu_autodarts/main/install.sh | bash
#
# Override clone target with AUTODARTS_REPO_DIR=/path ./install.sh

set -euo pipefail

# Keep the banner readable in redirected output and on narrow terminals.
if [ -t 1 ] && [ "${TERM:-dumb}" != dumb ] && [ -z "${NO_COLOR:-}" ]; then
    printf '\033[1;36m'
fi
cat <<'BANNER'

     /\    _   _ _____ ___  ____    _    ____ _____ ____
    /  \  | | | |_   _/ _ \|  _ \  / \  |  _ \_   _/ ___|
   / /\ \ | | | | | || | | | | | |/ _ \ | |_) || | \___ \
  / ____ \| |_| | | || |_| | |_| / ___ \|  _ < | |  ___) |
 /_/    \_\___/  |_| \___/|____/_/   \_\_| \_\|_| |____/

              YOUR AUTODARTS KIOSK SETUP
BANNER
if [ -t 1 ] && [ "${TERM:-dumb}" != dumb ] && [ -z "${NO_COLOR:-}" ]; then
    printf '\033[0m'
fi
printf '%s\n\n' '  Preparing the installer and its repository...'

REPO_URL="${AUTODARTS_REPO_URL:-https://github.com/mrdavidburns/lubuntu_autodarts.git}"
TARGET="${AUTODARTS_REPO_DIR:-$HOME/lubuntu_autodarts}"

if ! command -v git >/dev/null 2>&1; then
    echo "[Bootstrap] Installing git..."
    sudo apt update
    sudo apt install -y git
fi

if [ -d "$TARGET/.git" ]; then
    echo "[Bootstrap] Updating existing clone at $TARGET..."
    git -C "$TARGET" pull --ff-only
else
    echo "[Bootstrap] Cloning $REPO_URL → $TARGET..."
    git clone "$REPO_URL" "$TARGET"
fi

cd "$TARGET"
chmod +x essentials.sh setup_*.sh install.sh 2>/dev/null || true

echo
echo "[Bootstrap] Repository ready at $TARGET."
echo "[Bootstrap] Starting system setup..."
echo
exec ./essentials.sh "$@"
