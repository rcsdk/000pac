#!/bin/bash
# Lynis Advanced Hardening Script - Applies security fixes based on Lynis audit results

set -e  # Exit on error

# Update Lynis
if command -v lynis &> /dev/null; then
    echo "Updating Lynis..."
    lynis update info
else
    echo "Lynis not found. Installing..."
    pacman -Sy --noconfirm lynis
fi

# Ensure system is fully updated
echo "Updating system packages..."
pacman -Syu --noconfirm

# Secure file permissions
echo "Setting secure file permissions..."
chmod 640 /etc/shadow
chmod 644 /etc/passwd
chmod 700 /root
chmod 600 /boot/grub/grub.cfg

# Restrict unnecessary services
echo "Disabling unnecessary services..."
for svc in avahi-daemon cups nfs-server rpcbind bluetooth ModemManager; do
    systemctl disable $svc 2>/dev/null || true
    systemctl stop $svc 2>/dev/null || true
done

# Audit and restrict DNS
echo "Securing DNS settings..."
chattr +i /etc/resolv.conf  # Prevent unauthorized modifications
echo "nameserver 1.1.1.1" > /etc/resolv.conf
iptables -A OUTPUT -p udp --dport 53 -j ACCEPT
iptables -A OUTPUT -p tcp --dport 853 -j ACCEPT
iptables -A OUTPUT -p udp --sport 53 -j ACCEPT
iptables -A OUTPUT -p tcp --sport 853 -j ACCEPT

# Harden SSH security
echo "Hardening SSH configuration..."
sed -i 's/^#PermitRootLogin.*/PermitRootLogin no/' /etc/ssh/sshd_config
sed -i 's/^#PasswordAuthentication.*/PasswordAuthentication no/' /etc/ssh/sshd_config
sed -i 's/^#X11Forwarding.*/X11Forwarding no/' /etc/ssh/sshd_config
systemctl restart sshd

# Configure firewall rules
echo "Applying firewall rules..."
iptables -P INPUT DROP
iptables -P FORWARD DROP
iptables -P OUTPUT ACCEPT
iptables -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
iptables -A INPUT -p tcp --dport 22 -j ACCEPT
iptables -A INPUT -i lo -j ACCEPT
iptables-save > /etc/iptables/iptables.rules

# Enable kernel security parameters
echo "Applying sysctl security settings..."
cat << EOF >> /etc/sysctl.d/99-hardening.conf
net.ipv4.conf.all.accept_redirects = 0
net.ipv4.conf.all.send_redirects = 0
net.ipv4.conf.all.rp_filter = 1
net.ipv6.conf.all.accept_redirects = 0
net.ipv6.conf.all.accept_ra = 0
kernel.sysrq = 0
fs.protected_symlinks = 1
fs.protected_hardlinks = 1
EOF
sysctl -p

# Ensure auditing is enabled
echo "Configuring auditing policies..."
systemctl enable auditd
systemctl restart auditd

# Detect strange systemctl services
echo "Checking for unusual systemctl services..."
systemctl list-units --type=service --all | grep running

# Detect weird mounts and overlays
echo "Checking for unexpected mounts and overlays..."
mount | grep -E 'overlay|tmpfs|nfs'

# Verify system integrity
echo "Running filesystem integrity check..."
rkhunter --check --sk

echo "Security hardening complete! Run 'lynis audit system' again to verify."
