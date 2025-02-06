

sudo timedatectl set-timezone America/Sao_Paulo
sudo localectl set-locale LANG=en_US.UTF-8

umount /
xrandr --output eDP1 --brightness 0.4

pacman -S lynis
lynis audit system
/etc/lynis/default.prf 


rm -f /var/lib/pacman/db.lck
pacman -Scc --noconfirm
pacman-key --init
pacman-key --populate archlinux
rm -rf /var/lib/pacman/sync/*
pacman -Sy --noconfirm pacman

sudo pacman -S fakeroot


sudo mount -o remount,rw /run/archiso/cowspace
sudo chattr +i /run/archiso/cowspace
sudo chattr +i /run/archiso
inotifywait -m -r -e modify,delete,create,attrib /run/archiso/cowspace


pacman -S --noconfirm --neeeded acl inotify-tools rsync curl git base-devel



echo 3 > /proc/sys/vm/drop_caches
echo 1 > /proc/sys/vm/compact_memory
sysctl -w vm.min_free_kbytes=1000000

pacman -S firefox


if lsattr /etc/resolv.conf | grep -q "i"; then
    echo "Removing immutable flag from resolv.conf..."
    chattr -i /etc/resolv.conf
fi

echo -e "nameserver 1.1.1.1\nnameserver 8.8.8.8\nnameserver 8.8.4.4" > /etc/resolv.conf
chattr +i /etc/resolv.conf
echo "DNS secured and locked."

# Update system and install packages from local repo if available
rm -f /var/lib/pacman/db.lck
sudo pacman -Syu --noconfirm --needed

for pkg in "${PACKAGES[@]}"; do
    if is_installed "$pkg"; then
        echo "$pkg is already installed. Skipping..."
    else
        echo "Downloading $pkg..."
        sudo pacman -Sw --cachedir "$LOCAL_REPO" --noconfirm --needed "$pkg"
        echo "Installing $pkg..."
        sudo pacman -U --noconfirm "$LOCAL_REPO"/*.pkg.tar.zst
    fi
done

# Enable necessary services
sudo systemctl enable --now syncthing.service

# Backup script placeholder
BACKUP_SCRIPT="/usr/local/bin/system_backup.sh"
echo "Creating backup script at $BACKUP_SCRIPT..."
cat <<EOL | sudo tee "$BACKUP_SCRIPT"
#!/bin/bash

echo "Starting system backup with Timeshift..."
sudo timeshift --create --comments "Automated Backup" --tags D
EOL

sudo chmod +x "$BACKUP_SCRIPT"

# Finish
echo "All selected applications installed successfully!"
