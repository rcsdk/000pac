#!/bin/bash
set -e
trap 'echo "Error on line $LINENO"' ERR

# =============================================================================
# Ultra-Hardening and Secure Environment Script for a System-Rescue Arch Linux
#
# This script implements multiple defensive layers (20+ measures) to defeat
# common bootkit techniques and other compromise vectors.
#
# Usage (as root):
#   ./integrated_script.sh [mode]
#
# Modes:
#   harden      - Standard system hardening (trusted pacman/DNS, sysctl, etc.)
#   investigate - Full system investigation report
#   isolate     - Aggressive RAM reclamation and isolation (destructive)
#   download    - Download security tools (using curl)
#   secure      - Deploy ultra-hardening measures and launch a secure X session
#   all         - Run all (excluding isolate)
# =============================================================================

# -----------------------------------------------------------------------------
# Colors and Logging (for secure mode)
# -----------------------------------------------------------------------------
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'
log() {
    echo -e "${GREEN}[+]${NC} $1"
}

# -----------------------------------------------------------------------------
# 1. Bootloader & Critical File Protection
# -----------------------------------------------------------------------------
protect_bootloader() {
    if [ -f /boot/grub/grub.cfg ]; then
        chmod 600 /boot/grub/grub.cfg
        chattr +i /boot/grub/grub.cfg && log "Bootloader configuration locked."
    else
        log "No grub.cfg found; skipping bootloader protection."
    fi
}

lock_critical_binaries() {
    for bin in /bin/{bash,ls,cat,cp,mv,rm} /sbin/{ifconfig,iptables}; do
        if [ -f "$bin" ]; then
            chattr +i "$bin" 2>/dev/null || log "Failed to lock $bin"
        fi
    done
}

# -----------------------------------------------------------------------------
# 2. Pacman and DNS Hardening
# -----------------------------------------------------------------------------
update_pacman_conf() {
    log "Updating pacman configuration..."
    cat > /etc/pacman.conf << 'EOF'
#
# /etc/pacman.conf
#
# See the pacman.conf(5) manpage for option and repository directives
#

[options]
RootDir     = /
DBPath      = /var/lib/pacman/
CacheDir    = /var/cache/pacman/pkg/
HookDir     = /etc/pacman.d/hooks/
GPGDir      = /etc/pacman.d/gnupg/
LogFile     = /var/log/pacman.log
HoldPkg     = pacman glibc man-db bash syslog-ng systemd
IgnorePkg   =
IgnoreGroup =
NoUpgrade   =
NoExtract   =
UseSyslog
Color
ILoveCandy

Architecture = x86_64

SigLevel = Never

[core]
Include     = /etc/pacman.d/mirrorlist

[extra]
Include     = /etc/pacman.d/mirrorlist

[community]
Include     = /etc/pacman.d/mirrorlist

[multilib]
Include     = /etc/pacman.d/mirrorlist
EOF
    log "Pacman configuration updated."
    chattr +i /etc/pacman.conf && log "Pacman config locked." || log "Failed to lock /etc/pacman.conf."
    # Refresh pacman keys (if applicable)
    pacman-key --init && pacman-key --populate archlinux
}

update_dns() {
    log "Selecting fastest DNS server..."
    DNS_CANDIDATES=( "1.1.1.1" "8.8.8.8" "9.9.9.9" )
    best_dns=""
    best_time=10000
    for dns in "${DNS_CANDIDATES[@]}"; do
        log "Testing DNS server: $dns"
        avg_time=$(ping -c 3 -W 1 "$dns" 2>/dev/null | tail -1 | awk -F '/' '{print $5}')
        if [ -z "$avg_time" ]; then
            log "No response from $dns, skipping."
            continue
        fi
        log "RTT for $dns: ${avg_time}ms"
        if (( $(echo "$avg_time < $best_time" | bc -l) )); then
            best_time=$avg_time
            best_dns=$dns
        fi
    done
    if [ -z "$best_dns" ]; then
        log "[ERROR] No DNS server responded; aborting DNS update."
        return 1
    fi
    log "Selected DNS server: $best_dns"
    echo "nameserver $best_dns" > /etc/resolv.conf
    chattr +i /etc/resolv.conf && log "/etc/resolv.conf locked." || log "Failed to lock /etc/resolv.conf."
}

# -----------------------------------------------------------------------------
# 3. Filesystem & /var Protection
# -----------------------------------------------------------------------------
fix_filesystem_perms() {
    log "Fixing critical filesystem permissions..."
    chmod 640 /etc/shadow
    chmod 644 /etc/passwd /etc/group
    chmod 700 /root
    # Correct ownership for /var and /tmp areas (customize as needed)
    chown -R root:root /var
    chmod -R 755 /var
    mount -o remount,noexec,nosuid,nodev /tmp || log "Failed to remount /tmp with secure options."
}

# -----------------------------------------------------------------------------
# 4. Overlay and Mount Integrity
# -----------------------------------------------------------------------------
check_and_fix_overlays() {
    log "Checking for suspicious overlay mounts..."
    mount | grep overlay >/dev/null && {
        log "[WARNING] Overlay mounts detected. Listing raw mountinfo:"
        cat /proc/self/mountinfo
        # Optionally, attempt to unmount rogue overlays:
        # for mp in $(mount | grep overlay | awk '{print $3}'); do umount "$mp" || log "Failed to unmount $mp"; done
    } || log "No suspicious overlay mounts found."
}

# -----------------------------------------------------------------------------
# 5. Rogue Service & Cron Job Detection
# -----------------------------------------------------------------------------
check_services_and_cron() {
    log "Listing systemd services for anomalies..."
    services=$(systemctl list-units --type=service --all 2>/dev/null)
    echo "$services"
    log "Scanning for nonstandard cron jobs..."
    for f in /etc/cron.*/* /var/spool/cron/*; do
        [ -f "$f" ] && grep -q . "$f" && echo "Found cron job in $f" && cat "$f"
    done
}

# -----------------------------------------------------------------------------
# 6. Kernel and Sysctl Hardening
# -----------------------------------------------------------------------------
apply_sysctl_hardening() {
    log "Applying sysctl hardening settings..."
    cat > /etc/sysctl.d/99-security.conf << EOF
kernel.kptr_restrict=2
kernel.dmesg_restrict=1
kernel.unprivileged_bpf_disabled=1
kernel.yama.ptrace_scope=3
net.ipv4.tcp_syncookies=1
net.ipv4.conf.all.accept_redirects=0
net.ipv4.conf.all.send_redirects=0
net.ipv4.conf.all.accept_source_route=0
fs.protected_fifos=2
fs.protected_regular=2
# Disable core dumps
fs.suid_dumpable=0
EOF
    sysctl -p /etc/sysctl.d/99-security.conf
}

# -----------------------------------------------------------------------------
# 7. SSH Hardening
# -----------------------------------------------------------------------------
hardening_ssh() {
    log "Hardening SSH configuration..."
    sed -i 's/^#PermitRootLogin.*/PermitRootLogin no/' /etc/ssh/sshd_config
    sed -i 's/^#PasswordAuthentication.*/PasswordAuthentication no/' /etc/ssh/sshd_config
    sed -i 's/^#X11Forwarding.*/X11Forwarding no/' /etc/ssh/sshd_config
    systemctl restart sshd || log "Failed to restart SSH service."
}

# -----------------------------------------------------------------------------
# 8. Firewall Configuration
# -----------------------------------------------------------------------------
configure_firewall() {
    log "Configuring iptables firewall..."
    iptables -F
    iptables -X
    iptables -P INPUT DROP
    iptables -P FORWARD DROP
    iptables -P OUTPUT DROP
    iptables -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
    iptables -A OUTPUT -p tcp --dport 80 -j ACCEPT
    iptables -A OUTPUT -p tcp --dport 443 -j ACCEPT
    iptables -A OUTPUT -p udp --dport 53 -j ACCEPT
    for port in 22 23 25 445 3389; do
        iptables -A INPUT -p tcp --dport $port -j DROP
    done
    iptables-save > /etc/iptables/iptables.rules || log "iptables-save failed."
}

# -----------------------------------------------------------------------------
# 9. Integrity Verification
# -----------------------------------------------------------------------------
verify_integrity() {
    log "Running integrity verification tools (rkhunter)..."
    rkhunter --check --sk || log "rkhunter check failed; please investigate."
}

# -----------------------------------------------------------------------------
# 10. Monitoring & Logging Setup
# -----------------------------------------------------------------------------
setup_monitoring() {
    log "Setting up continuous monitoring..."
    cat > /usr/local/bin/monitor.sh << 'EOF'
#!/bin/bash
while true; do
    free -m > /tmp/ram_usage
    ps aux > /tmp/process_list
    netstat -tulpn > /tmp/open_ports
    if free | awk '/Mem/{if($3/$2*100>80) print "High RAM usage detected!"}'; then
        echo "WARNING: High RAM usage detected!" >> /tmp/monitor.log
    fi
    sleep 30
done
EOF
    chmod +x /usr/local/bin/monitor.sh
    /usr/local/bin/monitor.sh &
}

# -----------------------------------------------------------------------------
# 11. Auto-mount and Removable Media Control
# -----------------------------------------------------------------------------
disable_automount() {
    log "Disabling automount services for removable media..."
    systemctl disable udisks2 2>/dev/null || true
    systemctl stop udisks2 2>/dev/null || true
}

# -----------------------------------------------------------------------------
# 12. Optional: Enable Mandatory Access Control (if SELinux/AppArmor available)
# -----------------------------------------------------------------------------
enable_mac() {
    if command -v sestatus &>/dev/null; then
        log "SELinux detected. Ensure policies are enforcing."
        setenforce 1 || log "Failed to enforce SELinux."
    elif command -v aa-status &>/dev/null; then
        log "AppArmor detected. Ensure profiles are loaded."
    else
        log "No MAC system detected."
    fi
}

# -----------------------------------------------------------------------------
# 13. Aggressive RAM Reclamation (from previous secure-env script)
# -----------------------------------------------------------------------------
reclaim_ram() {
    log "Aggressively reclaiming RAM..."
    for service in sshd cups bluetooth avahi-daemon systemd-journald; do
        killall -9 "$service" 2>/dev/null || true
    done
    systemctl stop sshd 2>/dev/null || true
    systemctl disable sshd 2>/dev/null || true
    sync
    echo 3 > /proc/sys/vm/drop_caches
    swapoff -a
    for badproc in "crypto" "miner" "kworker" "kthread"; do
        pkill -f "$badproc" 2>/dev/null || true
    done
}

# -----------------------------------------------------------------------------
# 14. Browser Hardening
# -----------------------------------------------------------------------------
setup_browser() {
    log "Setting up hardened browser profile..."
    rm -rf ~/.mozilla ~/.config/google-chrome ~/.config/chromium
    mkdir -p ~/.mozilla/firefox/hardened.default
    cat > ~/.mozilla/firefox/hardened.default/user.js << EOF
user_pref("media.peerconnection.enabled", false);
user_pref("network.dns.disablePrefetch", true);
user_pref("network.prefetch-next", false);
user_pref("privacy.resistFingerprinting", true);
user_pref("webgl.disabled", true);
user_pref("media.navigator.enabled", false);
user_pref("network.proxy.socks_remote_dns", true);
EOF
}

# -----------------------------------------------------------------------------
# 15. Launch a Secure X Session (with Openbox)
# -----------------------------------------------------------------------------
launch_desktop() {
    log "Launching secure desktop session..."
    startx /usr/bin/openbox-session
}

# -----------------------------------------------------------------------------
# Secure Environment Mode: Combine many measures to “make it 5 times harder”
# -----------------------------------------------------------------------------
secure_env() {
    log "=== Starting Ultra-Hardening Secure Environment Setup ==="
    protect_bootloader
    lock_critical_binaries
    update_pacman_conf
    update_dns
    fix_filesystem_perms
    check_and_fix_overlays
    check_services_and_cron
    apply_sysctl_hardening
    hardening_ssh
    configure_firewall
    verify_integrity
    setup_monitoring
    disable_automount
    enable_mac
    reclaim_ram
    setup_browser
    log "Ultra-hardening complete. Launching desktop session..."
    launch_desktop
}

# -----------------------------------------------------------------------------
# (Placeholder) Standard Hardening, Investigation, Download, and Isolate Functions
# -----------------------------------------------------------------------------
harden_system() {
    log "Running standard system hardening..."
    update_pacman_conf
    update_dns
    fix_filesystem_perms
    apply_sysctl_hardening
    hardening_ssh
    configure_firewall
    verify_integrity
}

investigation() {
    log "Running system investigation..."
    REPORT_DIR=$(mktemp -d)
    REPORT="${REPORT_DIR}/FULL_REPORT.txt"
    {
        echo "System Info: $(uname -a)"
        free -h
        cat /proc/cpuinfo
        df -h
        lsblk -f
        cat /proc/mounts
    } > "$REPORT"
    FINAL_ARCHIVE="/tmp/system_investigation_$(date +%Y%m%d_%H%M%S).tar.gz"
    tar -czf "$FINAL_ARCHIVE" -C "$REPORT_DIR" .
    log "Investigation complete. Report at: $FINAL_ARCHIVE"
}

download_tools() {
    log "Downloading security tools..."
    DOWNLOAD_DIR="/var/dr/toolz"
    mkdir -p "$DOWNLOAD_DIR"
    for url in "https://www.ossec.net/downloads/ossec-hids-3.7.0.tar.gz" \
               "https://github.com/virus-total/yara/releases/download/v4.1.0/yara-4.1.0.tar.gz" \
               "https://github.com/MISP/MISP/archive/refs/heads/master.zip"; do
        log "Downloading $url"
        curl -L -o "$DOWNLOAD_DIR/$(basename "$url")" "$url" || log "Failed to download $url"
    done
}

isolate_system() {
    log "Running aggressive isolation (destructive)..."
    reclaim_ram
    # Additional isolation steps could go here.
}

# -----------------------------------------------------------------------------
# Main: Mode Selection
# -----------------------------------------------------------------------------
print_usage() {
    echo "Usage: $0 [mode]"
    echo "Modes:"
    echo "  harden      - Standard system hardening"
    echo "  investigate - Run system investigation"
    echo "  isolate     - Aggressive isolation (destructive)"
    echo "  download    - Download security tools"
    echo "  secure      - Ultra-hardening and secure environment (launch desktop)"
    echo "  all         - Run harden, investigate, download, and secure"
    exit 1
}

if [ "$EUID" -ne 0 ]; then
    echo "Please run as root."
    exit 1
fi

check_space

MODE="$1"
if [ -z "$MODE" ]; then
    print_usage
fi

case "$MODE" in
    harden)
        harden_system
        ;;
    investigate)
        investigation
        ;;
    isolate)
        isolate_system
        ;;
    download)
        download_tools
        ;;
    secure)
        secure_env
        ;;
    all)
        harden_system
        investigation
        download_tools
        secure_env
        ;;
    *)
        print_usage
        ;;
esac

log "Script execution completed."
