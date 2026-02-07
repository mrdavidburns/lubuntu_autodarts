#!/bin/bash

# Script to create GRUB theme background
# Creates a 1920x1080 black background with centered AUTODARTS logo

SCRIPT_DIR="$(dirname "$0")"
OUTPUT_FILE="$SCRIPT_DIR/background.png"
LOGO_FILE="$SCRIPT_DIR/autodarts_logo.png"

# Check if ImageMagick is installed
if ! command -v convert &> /dev/null; then
    echo "ImageMagick not found. Installing..."
    sudo apt-get update
    sudo apt-get install -y imagemagick
fi

if [ ! -f "$LOGO_FILE" ]; then
    echo "Error: Logo file not found at $LOGO_FILE"
    exit 1
fi

echo "Creating GRUB background image..."

# Create a 1920x1080 black background with centered logo
convert -size 1920x1080 xc:black \
    "$LOGO_FILE" -gravity center -composite \
    "$OUTPUT_FILE"

if [ -f "$OUTPUT_FILE" ]; then
    echo "GRUB background created successfully: $OUTPUT_FILE"
    echo "Image size: $(identify -format '%wx%h' "$OUTPUT_FILE")"
else
    echo "Error: Failed to create background image"
    exit 1
fi
