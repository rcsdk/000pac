#!/bin/bash

# Source auto-detection function
source "$(dirname "$0")/auto_detect.sh"

# Get USB mount point
USB_MOUNT=$(detect_usb_drive)

# Exit if no drive found
if [ -z "$USB_MOUNT" ]; then
    echo "No valid USB drive detected!"
    exit 1
fi

# Create backup directory
mkdir -p "${USB_MOUNT}/backups"

# Backup configs
for dir in ~/.config ~/.*; do
    if [ -d "$dir" ]; then
        tar -czf "${USB_MOUNT}/backups/$(basename "$dir").tar.gz" "$dir"
    fi
done

echo "Backup completed successfully!"
