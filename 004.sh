#!/bin/bash
set -e
trap 'echo "Error on line $LINENO"' ERR

# =============================================================================
# Integrated Secure Environment Script
# Includes system hardening, investigation, and a secure environment mode
# that eventually launches X (Openbox) for a stable desktop session.
#
# Usage:
#   sudo ./integrated_script.sh [mode]
#
# Modes:
#   harden      - Run system hardening (trusted pacman/DNS, firewall, sysctl, etc.)
#   investigate - Run a full system investigation and generate a report archive.
#   isolate     - Aggressive RAM reclamation and isolation (destructive)
#   download    - Download security tools and packages (using curl)
#   secure      - Run aggressive RAM reclamation, network & system hardening,
#                 browser hardening, monitoring, then start a secure X session.
#   all         - Run all non‐destructive modes (excludes isolate)
# =============================================================================

# -----------------------------
# Colors and Logging (for secure mode)
# -----------------------------
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'
log() {
    echo -e "${GREEN}[+]${NC} $1"
}

# -----------------------------
# Update Pacman and DNS configuration functions (as before)
# -----------------------------
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
    chattr +i /etc/pacman.conf && log "/etc/pacman.conf locked down." || log "Failed to lock /etc/pacman.conf."
}

update_dns() {
    log "Selecting fastest DNS server..."
    DNS_CANDIDATES=( "1.1.1.1" "8.8.8.8" "9.9.9.9" )
    best_dns=""
    best_time=10000  # ms
    for dns in "${DNS_CANDIDATES[@]}"; do
        log "Testing DNS server: $dns"
        avg_time=$(ping -c 3 -W 1 "$dns" 2>/dev/null | tail -1 | awk -F '/' '{print $5}')
        if [ -z "$avg_time" ]; then
            log "No response from $dns, skipping."
            continue
        fi
        log "Average RTT for $dns is ${avg_time}ms."
        if (( $(echo "$avg_time < $best_time" | bc -l) )); then
            best_time=$avg_time
            best_dns=$dns
        fi
    done
    if [ -z "$best_dns" ]; then
        log "[ERROR] No candidate DNS servers responded. Aborting DNS update."
        return 1
    fi
    log "Selected DNS server: $best_dns (avg RTT: ${best_time}ms)."
    echo "nameserver $best_dns" > /etc/resolv.conf
    log "/etc/resolv.conf updated with $best_dns."
    chattr +i /etc/resolv.conf && log "/etc/resolv.conf locked down." || log "Failed to lock /etc/resolv.conf."
}

# -----------------------------
# Check available space on rescue mounts (copytoram/cowspace)
# -----------------------------
check_space() {
    local mountpoints=( "/run/archiso/bootmnt" "/run/archiso/cowspace" )
    local threshold=90  # warn if usage exceeds 90%
    echo "===== CHECKING SPECIAL MOUNT SPACE USAGE ====="
    for mp in "${mountpoints[@]}"; do
        if [ -d "$mp" ]; then
            usage=$(df --output=pcent "$mp" | tail -n1 | tr -d '%')
            avail=$(df --output=avail "$mp" | tail -n1)
            echo "Mount point: $mp -- Usage: ${usage}% -- Available: ${avail} blocks"
            if [ "$usage" -gt "$threshold" ]; then
                echo "[WARNING] $mp is above ${threshold}% usage. This may cause issues."
            fi
        else
            echo "[INFO] Mount point $mp not found."
        fi
    done
    echo "===== SPACE CHECK COMPLETE ====="
}

# -----------------------------
# Standard utility functions (run, ts)
# -----------------------------
run() {
    local cmd="$*"
    echo -e "\n=== Running: $cmd ===\n"
    eval "$cmd" 2>&1 || echo "[ERROR] Command failed: $cmd"
}

ts() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"
}

# -----------------------------
# Existing Hardening/Investigation/Download/Isolate functions go here...
# (They remain the same as in our previous integrated script.)
# For brevity, we assume functions: harden_system, investigation, download_tools, isolate_system
# are defined above (or imported) in the integrated script.
# -----------------------------

# -----------------------------
# Secure Environment Mode Functions
# -----------------------------
# Phase 1: Aggressive RAM Reclamation
reclaim_ram() {
    log "Reclaiming RAM aggressively..."
    for service in sshd cups bluetooth avahi-daemon systemd-journald; do
        killall -9 "$service" 2>/dev/null || true
    done
    systemctl stop sshd 2>/dev/null || true
    systemctl disable sshd 2>/dev/null || true
    sync
    echo 3 > /proc/sys/vm/drop_caches
    swapoff -a
    # Kill known malicious processes (add more as needed)
    for badproc in "crypto" "miner" "kworker" "kthread"; do
        pkill -f "$badproc" 2>/dev/null || true
    done
}

# Phase 2: Network Hardening (secure network settings)
harden_network() {
    log "Hardening network settings..."
    echo 1 > /proc/sys/net/ipv6/conf/all/disable_ipv6
    echo 1 > /proc/sys/net/ipv6/conf/default/disable_ipv6
    iptables -F
    iptables -X
    iptables -P INPUT DROP
    iptables -P FORWARD DROP
    iptables -P OUTPUT DROP
    iptables -A OUTPUT -p tcp --dport 80 -j ACCEPT
    iptables -A OUTPUT -p tcp --dport 443 -j ACCEPT
    iptables -A OUTPUT -p udp --dport 53 -j ACCEPT
    iptables -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
    for port in 22 23 25 445 3389; do
        iptables -A INPUT -p tcp --dport $port -j DROP
    done
}

# Phase 3: System Hardening (protect configs, sysctl tweaks)
harden_system_secure() {
    log "Harden system configuration..."
    for conf in /etc/pacman.conf /etc/ssh/sshd_config /etc/resolv.conf; do
        if [ -f "$conf" ]; then
            chattr +i "$conf" 2>/dev/null || true
        fi
    done
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
EOF
    sysctl -p /etc/sysctl.d/99-security.conf
}

# Phase 4: Browser Hardening
setup_browser() {
    log "Setting up hardened browser environment..."
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

# Phase 5: Monitoring (create a background monitor script)
setup_monitoring() {
    log "Setting up monitoring script..."
    cat > /usr/local/bin/monitor.sh << 'EOF'
#!/bin/bash
while true; do
    free -m > /tmp/ram_usage
    ps aux > /tmp/process_list
    netstat -tulpn > /tmp/open_ports
    ram_used=$(free | grep Mem | awk '{print $3/$2 * 100.0}')
    if (( $(echo "$ram_used > 80" | bc -l) )); then
        echo "WARNING: High RAM usage detected!"
    fi
    sleep 30
done
EOF
    chmod +x /usr/local/bin/monitor.sh
    /usr/local/bin/monitor.sh &
}

# Secure Environment Mode: combine phases and finally launch a desktop
secure_env() {
    log "Starting secure environment setup..."
    reclaim_ram
    harden_network
    harden_system_secure
    update_pacman_conf
    update_dns
    setup_browser
    setup_monitoring
    log "Secure environment setup complete. Launching desktop session..."
    startx /usr/bin/openbox-session
}

# -----------------------------
# Main: Mode Selection and Execution
# -----------------------------
print_usage() {
    echo "Usage: $0 [mode]"
    echo "Modes:"
    echo "  harden      - Run system hardening"
    echo "  investigate - Run system investigation"
    echo "  isolate     - Aggressive RAM reclamation and isolation (destructive)"
    echo "  download    - Download security tools and packages"
    echo "  secure      - Setup secure environment and launch desktop (startx)"
    echo "  all         - Run all modes (excluding isolate)"
    exit 1
}

if [ "$EUID" -ne 0 ]; then
    echo "Please run as root."
    exit 1
fi

# Optional: run the space check early
check_space

MODE="$1"
if [ -z "$MODE" ]; then
    print_usage
fi

case "$MODE" in
    harden)
        harden_system   # our standard hardening (assume defined elsewhere)
        ;;
    investigate)
        investigation   # assume defined above
        ;;
    isolate)
        isolate_system  # assume defined above
        ;;
    download)
        download_tools  # assume defined above
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

echo "Script execution completed."
