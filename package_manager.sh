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

# Define packages
declare -A packages=(
    ["terminals"]="warp-terminal alacritty kitty"
    ["browsers"]="firefox"
    ["file_managers"]="nemo dolphin ranger"
    ["monitors"]="stacer gnome-system-monitor ksysguard bashtop"
    ["desktop_enhancements"]="plank conky variety timeshift syncthing rofi picom"
)

# Download packages
download_packages() {
    local category="$1"
    shift
    local pkgs=("$@")
    
    echo "Downloading $category..."
    for pkg in "${pkgs[@]}"; do
        echo "Downloading $pkg..."
        sudo pacman -Syw "$pkg" --cachedir "${USB_MOUNT}/apps/cache"
        sudo cp "${USB_MOUNT}/apps/cache/${pkg}-*.pkg.tar.zst" "${USB_MOUNT}/apps/packages/"
    done
}

# Install packages
install_packages() {
    local category="$1"
    shift
    local pkgs=("$@")
    
    echo "Installing $category..."
    for pkg in "${pkgs[@]}"; do
        echo "Installing $pkg..."
        sudo pacman -U "${USB_MOUNT}/apps/packages/${pkg}-*.pkg.tar.zst" --noconfirm
    done
}

# Main installation loop
for category in "${!packages[@]}"; do
    download_packages "$category" ${packages[$category]}
    install_packages "$category" ${packages[$category]}
done

# Cleanup
sudo pacman -Sc --noconfirm

echo "Package installation complete!"
