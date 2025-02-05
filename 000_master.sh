
sudo mkdir -p /mnt/usb

sudo mount /dev/sdX1 /mnt/usb

Replace X with your actual drive letter (like sdb1).

df -h | grep /mnt/usb


chmod +x /mnt/1/scripts/*.sh

/mnt/1/scripts/setup_dirs.sh
/mnt/1/scripts/pacman_config.sh
/mnt/1/scripts/security_setup.sh
/mnt/1/scripts/package_manager.sh
/mnt/1/scripts/backup.sh
