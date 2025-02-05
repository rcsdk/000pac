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

# Create pacman configuration
echo "[options]" > /etc/pacman.conf
echo "# RootDir     = /" >> /etc/pacman.conf
echo "DBPath      = /var/lib/pacman/" >> /etc/pacman.conf
echo "CacheDir    = ${USB_MOUNT}/apps/cache" >> /etc/pacman.conf
echo "LogFile     = /var/log/pacman.log" >> /etc/pacman.conf
echo "HoldPkg     = pacman glibc" >> /etc/pacman.conf
echo "Architecture = auto" >> /etc/pacman.conf

echo "[core]" >> /etc/pacman.conf
echo "Include = /etc/pacman.d/mirrorlist" >> /etc/pacman.conf

echo "[extra]" >> /etc/pacman.conf
echo "Include = /etc/pacman.d/mirrorlist" >> /etc/pacman.conf

echo "[community]" >> /etc/pacman.conf
echo "Include = /etc/pacman.d/mirrorlist" >> /etc/pacman.conf

echo "Pacman configuration updated!"
