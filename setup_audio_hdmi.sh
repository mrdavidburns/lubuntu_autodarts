#!/bin/bash
# Part of lubuntu_autodarts - MIT License
# See LICENSE file for details
#
# Install pavucontrol and configure PulseAudio so audio routes to
# Digital Stereo (HDMI) Output by default.
#
# Strategy:
#   - Install pavucontrol + pulseaudio-utils (system-wide, needs sudo).
#   - Drop a per-user helper at ~/.local/bin/set-hdmi-audio.sh that detects
#     the HDMI card profile + sink and sets them as default.
#   - Drop an autostart entry that runs the helper on each login so audio
#     keeps routing to HDMI even after monitor swaps or reboots.
#
# PulseAudio is per-user; running pactl as root in essentials.sh would not
# touch the AutoDarts user's session. The autostart approach is idempotent
# and survives kernel/audio-stack changes.

set -e

ACTUAL_USER=${SUDO_USER:-${USER:-$(id -un)}}
ACTUAL_HOME=$(getent passwd "$ACTUAL_USER" | cut -d: -f6)

echo "Installing pavucontrol and PulseAudio utilities..."
sudo apt update
sudo apt install -y pavucontrol pulseaudio-utils

# Per-user paths
USER_BIN="$ACTUAL_HOME/.local/bin"
AUTOSTART_DIR="$ACTUAL_HOME/.config/autostart"
HELPER="$USER_BIN/set-hdmi-audio.sh"
DESKTOP_FILE="$AUTOSTART_DIR/set-hdmi-audio.desktop"

sudo -u "$ACTUAL_USER" mkdir -p "$USER_BIN" "$AUTOSTART_DIR"

# Helper: pick an HDMI-capable card, set its profile to hdmi-stereo,
# then set the resulting HDMI sink as the default sink.
sudo -u "$ACTUAL_USER" tee "$HELPER" >/dev/null <<'EOF'
#!/bin/bash
# Set Digital Stereo (HDMI) Output as the default PulseAudio sink.
# Idempotent — safe to run on every login.

set -e

# Wait for PulseAudio to be ready (autostart can race with pulse).
for _ in $(seq 1 20); do
    if pactl info >/dev/null 2>&1; then
        break
    fi
    sleep 0.5
done

if ! pactl info >/dev/null 2>&1; then
    echo "set-hdmi-audio: PulseAudio not responding; bailing." >&2
    exit 0
fi

# Find first card that advertises an HDMI stereo output profile.
# Match plain output:hdmi-stereo first; fall back to output:hdmi-stereo-extra*.
CARD=""
PROFILE=""
while read -r idx name _; do
    profile=$(pactl list cards | awk -v c="$name" '
        $1=="Name:" && $2==c {found=1; next}
        found && /^Card #/ {found=0}
        found && /^\s*output:hdmi-stereo[^:]*:/ {
            sub(/:.*$/, "", $1); print $1; exit
        }
    ')
    if [ -n "$profile" ]; then
        CARD="$name"
        PROFILE="$profile"
        break
    fi
done < <(pactl list cards short)

if [ -z "$CARD" ]; then
    echo "set-hdmi-audio: no HDMI-capable card found." >&2
    exit 0
fi

pactl set-card-profile "$CARD" "$PROFILE" || {
    echo "set-hdmi-audio: failed to set profile $PROFILE on $CARD." >&2
    exit 0
}
echo "set-hdmi-audio: card=$CARD profile=$PROFILE"

# Find the HDMI sink that just appeared and make it default.
SINK=$(pactl list sinks short | awk '/hdmi/ {print $2; exit}')
if [ -n "$SINK" ]; then
    pactl set-default-sink "$SINK"
    # Move existing streams to the new default.
    pactl list short sink-inputs | awk '{print $1}' | while read -r input; do
        pactl move-sink-input "$input" "$SINK" 2>/dev/null || true
    done
    # Unmute and set a sane volume.
    pactl set-sink-mute "$SINK" 0 2>/dev/null || true
    pactl set-sink-volume "$SINK" 80% 2>/dev/null || true
    echo "set-hdmi-audio: default sink is now $SINK"
else
    echo "set-hdmi-audio: HDMI sink not found after profile switch." >&2
fi
EOF

sudo -u "$ACTUAL_USER" chmod +x "$HELPER"

# Autostart entry — runs once per login.
sudo -u "$ACTUAL_USER" tee "$DESKTOP_FILE" >/dev/null <<EOF
[Desktop Entry]
Type=Application
Name=AutoDarts HDMI Audio
Comment=Route audio to Digital Stereo (HDMI) Output on login
Exec=$HELPER
Terminal=false
StartupNotify=false
X-GNOME-Autostart-enabled=true
EOF

echo "pavucontrol installed; HDMI audio helper + autostart configured."
echo "Helper:   $HELPER"
echo "Autostart: $DESKTOP_FILE"
echo "Run now:  $HELPER  (or log out/in)"
