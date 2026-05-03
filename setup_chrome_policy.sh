#!/bin/bash
# Part of lubuntu_autodarts - MIT License
#
# Force-install Chrome extensions on this machine via Google Chrome's
# managed-policy mechanism. Default extension is "Tools for Autodarts"
# (oolfddhehmbpdnlmoljmllcdggmkgihh).
#
# Add more extensions with EXTRA_EXTENSION_IDS="<id1>,<id2>" or by editing
# the EXTENSIONS array below. Each entry is "<extension_id>;<update_url>".
#
# Reference:
#   https://chromeenterprise.google/policies/#ExtensionInstallForcelist
#   https://chromeenterprise.google/intl/en_us/policies/#ExtensionSettings

set -euo pipefail

if [ "$EUID" -ne 0 ]; then
    exec sudo -E "$0" "$@"
fi

POLICY_DIR="/etc/opt/chrome/policies/managed"
POLICY_FILE="$POLICY_DIR/autodarts.json"
UPDATE_URL="https://clients2.google.com/service/update2/crx"

# Default extensions to force-install. Format: "<id>;<update_url>".
EXTENSIONS=(
    "oolfddhehmbpdnlmoljmllcdggmkgihh;$UPDATE_URL" # Tools for Autodarts
)

# Append optional extras via env var: EXTRA_EXTENSION_IDS="abc,def"
if [ -n "${EXTRA_EXTENSION_IDS:-}" ]; then
    IFS=',' read -ra extras <<<"$EXTRA_EXTENSION_IDS"
    for id in "${extras[@]}"; do
        id=$(echo "$id" | xargs)
        [ -n "$id" ] && EXTENSIONS+=("$id;$UPDATE_URL")
    done
fi

mkdir -p "$POLICY_DIR"

# Build JSON forcelist array
forcelist=""
for entry in "${EXTENSIONS[@]}"; do
    [ -n "$forcelist" ] && forcelist+=","
    forcelist+="\"$entry\""
done

cat >"$POLICY_FILE" <<EOF
{
    "ExtensionInstallForcelist": [$forcelist],
    "ExtensionInstallSources": ["https://clients2.google.com/*", "https://chromewebstore.google.com/*"],
    "BlockExternalExtensions": false
}
EOF
chmod 644 "$POLICY_FILE"

# Chromium honors the same JSON in /etc/chromium/policies/managed/.
if [ -d /etc/chromium ] || apt-cache show chromium 2>/dev/null >/dev/null; then
    mkdir -p /etc/chromium/policies/managed
    cp "$POLICY_FILE" /etc/chromium/policies/managed/autodarts.json
fi

echo "Chrome managed policy written: $POLICY_FILE"
echo "Forced extensions:"
for entry in "${EXTENSIONS[@]}"; do
    echo "  - ${entry%%;*}"
done
echo "Restart Chrome (or reboot) for the policy to take effect."
