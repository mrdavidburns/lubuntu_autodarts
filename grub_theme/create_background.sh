#!/bin/bash

# Script to create GRUB theme background
# Creates a 1920x1080 background matching the AutoDarts splash palette.

set -euo pipefail

SCRIPT_DIR="$(dirname "$0")"
OUTPUT_FILE="$SCRIPT_DIR/background.png"

# Check if ImageMagick is installed
if ! command -v convert &>/dev/null; then
    echo "ImageMagick not found. Installing..."
    sudo apt-get update
    sudo apt-get install -y imagemagick
fi

echo "Creating GRUB background image..."

# The logo is drawn separately by theme.txt, above the boot menu.
convert -size 1920x1080 gradient:'#1b2f4f-#101a30' "$OUTPUT_FILE"

if [ -f "$OUTPUT_FILE" ]; then
    echo "GRUB background created successfully: $OUTPUT_FILE"
    echo "Image size: $(identify -format '%wx%h' "$OUTPUT_FILE")"
else
    echo "Error: Failed to create background image"
    exit 1
fi
