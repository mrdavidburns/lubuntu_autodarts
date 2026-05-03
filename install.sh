#!/bin/bash
# Part of lubuntu_autodarts - MIT License
#
# Bootstrap one-liner. Clones the repo into ~/lubuntu_autodarts and runs
# essentials.sh. Designed for:
#   curl -fsSL https://raw.githubusercontent.com/mrdavidburns/lubuntu_autodarts/main/install.sh | bash
#
# Override clone target with AUTODARTS_REPO_DIR=/path ./install.sh

set -euo pipefail

REPO_URL="${AUTODARTS_REPO_URL:-https://github.com/mrdavidburns/lubuntu_autodarts.git}"
TARGET="${AUTODARTS_REPO_DIR:-$HOME/lubuntu_autodarts}"

if ! command -v git >/dev/null 2>&1; then
    echo "Installing git..."
    sudo apt update
    sudo apt install -y git
fi

if [ -d "$TARGET/.git" ]; then
    echo "Updating existing clone at $TARGET..."
    git -C "$TARGET" pull --ff-only
else
    echo "Cloning $REPO_URL → $TARGET..."
    git clone "$REPO_URL" "$TARGET"
fi

cd "$TARGET"
chmod +x essentials.sh setup_*.sh install.sh 2>/dev/null || true

echo
echo "Repository ready at $TARGET. Launching essentials.sh..."
echo
exec ./essentials.sh "$@"
