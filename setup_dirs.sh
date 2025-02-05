
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

# Create directory structure
mkdir -p "${USB_MOUNT}/apps/cache"
mkdir -p "${USB_MOUNT}/apps/packages"
mkdir -p "${USB_MOUNT}/scripts"
mkdir -p "${USB_MOUNT}/config"

# Set permissions
chmod -R 755 "${USB_MOUNT}"
chown -R root:root "${USB_MOUNT}"

# Initialize pacman cache directory
sudo pacman -Scc --noconfirm
sudo mkdir -p /etc/pacman.d/
sudo cp /etc/pacman.conf /etc/pacman.d/

echo "Directory structure created successfully!"
