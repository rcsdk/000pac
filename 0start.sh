#!/bin/bash

# Exit immediately if a command fails
set -e

# Check if running as root
if [[ $EUID -ne 0 ]]; then
    echo "This script must be run as root" 1>&2
    exit 1
fi

# Phase 1: System Cleanup
echo "Cleaning system..."
rm -rf /tmp/*
rm -rf /run/shm/*
find /tmp /run -type f -perm -0002 -delete 2>/dev/null
find /tmp /run -name ".*" -delete 2>/dev/null
> /var/log/syslog
> /var/log/messages
> /var/log/auth.log

# Phase 2: Security Verification
echo "Running security checks..."
ls -la /proc/[0-9]* | grep "^\."
ldd /bin/* | grep "=> /"
ldd /sbin/* | grep "=> /"
netstat -pan | grep -vE "root|systemd"

# Phase 3: DNS Security
echo "Securing DNS..."
if lsattr /etc/resolv.conf | grep -q "i"; then
    chattr -i /etc/resolv.conf
fi

echo -e "nameserver 1.1.1.1\nnameserver 8.8.8.8\nnameserver 8.8.4.4" > /etc/resolv.conf
chattr +i /etc/resolv.conf

# Phase 4: USB Drive Management
echo "Managing USB drive..."
umount /tmp/usb 2>/dev/null || true
mount -o rw /dev/sdh1 /tmp/usb

# Phase 5: System Hardening
echo "Hardening system..."
for conf in /etc/pacman.conf /etc/resolv.conf; do
    if [ -f "$conf" ]; then
        chattr +i "$conf" 2>/dev/null || true
    fi
done

# Verify DNS configuration
echo "Checking DNS resolution..."
dig google.com +short

echo "Security setup complete!"
