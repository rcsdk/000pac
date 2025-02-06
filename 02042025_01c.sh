#!/bin/bash
set -e

# =============================================================================
# Integrated System Hardening, Investigation, Isolation, and Tool Download Script
# with Fallbacks, Disk Space Checks, and Trusted Pacman/DNS Configuration
# =============================================================================
#
# Usage:
#   sudo ./integrated_script.sh [mode]
#
# Modes:
#   harden      - Run system hardening (updates, permissions, firewall, etc.)
#   investigate - Run a full system investigation and generate a report archive.
#   isolate     - Aggressive RAM reclamation and launch a minimal, isolated shell.
#   download    - Download security tools and packages.
#   all         - Run all modes (NOTE: 'isolate' is destructive!)
#
# =============================================================================

# -----------------------------------------------------------------------------
# Function: Update Pacman Configuration
# This function writes a trusted pacman.conf to /etc/pacman.conf and locks it down.
# -----------------------------------------------------------------------------
update_pacman_conf() {
    echo "===== UPDATING PACMAN CONFIGURATION ====="
    cat > /etc/pacman.conf << 'EOF'
#
# /etc/pacman.conf
#
# See the pacman.conf(5) manpage for option and repository directives
#

#
# GENERAL OPTIONS
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

#
# REPOSITORIES
#

[core]
Include     = /etc/pacman.d/mirrorlist

[extra]
Include     = /etc/pacman.d/mirrorlist

[community]
Include     = /etc/pacman.d/mirrorlist

[multilib]
Include     = /etc/pacman.d/mirrorlist

#[testing]
#Include     = /etc/pacman.d/mirrorlist

#[community-testing]
#Include     = /etc/pacman.d/mirrorlist

#[multilib-testing]
#Include     = /etc/pacman.d/mirrorlist
EOF
    echo "Pacman configuration updated."

    # Lock down the pacman config (immutable)
    chattr +i /etc/pacman.conf && echo "/etc/pacman.conf locked down." || echo "Failed to lock /etc/pacman.conf."
}

# -----------------------------------------------------------------------------
# Function: Select and Update DNS Server
# This function tests candidate DNS servers, chooses the fastest,
# writes it into /etc/resolv.conf, and locks the file.
# -----------------------------------------------------------------------------
update_dns() {
    echo "===== UPDATING DNS RESOLVER ====="
    # List of candidate DNS servers (feel free to add more)
    DNS_CANDIDATES=( "1.1.1.1" "8.8.8.8" "9.9.9.9" )

    best_dns=""
    best_time=10000  # start with a large value (in ms)

    for dns in "${DNS_CANDIDATES[@]}"; do
        # Use ping; note: if ICMP is blocked this test may fail.
        echo "Testing DNS server: $dns"
        # Send 3 pings and extract the average round-trip time (in ms)
        avg_time=$(ping -c 3 -W 1 "$dns" 2>/dev/null | tail -1 | awk -F '/' '{print $5}')
        if [ -z "$avg_time" ]; then
            echo "No response from $dns, skipping."
            continue
        fi
        echo "Average RTT for $dns is ${avg_time}ms."
        # Use awk to compare as numbers
        if (( $(echo "$avg_time < $best_time" | bc -l) )); then
            best_time=$avg_time
            best_dns=$dns
        fi
    done

    if [ -z "$best_dns" ]; then
        echo "[ERROR] No candidate DNS servers responded. Aborting DNS update."
        return 1
    fi

    echo "Selected DNS server: $best_dns (avg RTT: ${best_time}ms)."
    
    # Write selected DNS server to /etc/resolv.conf and lock it
    echo "nameserver $best_dns" > /etc/resolv.conf
    echo "/etc/resolv.conf updated with $best_dns."
    chattr +i /etc/resolv.conf && echo "/etc/resolv.conf locked down." || echo "Failed to lock /etc/resolv.conf."
}

# -----------------------------------------------------------------------------
# Function: Check available space on Archiso mounts (copytoram and cowspace)
# -----------------------------------------------------------------------------
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

# -----------------------------------------------------------------------------
# Utility: run a command and display its output (with fallback logging)
# -----------------------------------------------------------------------------
run() {
    local cmd="$*"
    echo -e "\n=== Running: $cmd ===\n"
    eval "$cmd" 2>&1 || echo "[ERROR] Command failed: $cmd"
}

# -----------------------------------------------------------------------------
# Utility: Timestamp logging (for investigation mode)
# -----------------------------------------------------------------------------
ts() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"
    [ -n "$REPORT" ] && echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" >> "$REPORT"
}

# -----------------------------------------------------------------------------
# Function: System Hardening (with fallback checks)
# -----------------------------------------------------------------------------
harden_system() {
    echo "===== SYSTEM HARDENING START ====="

    # Update trusted pacman configuration
    update_pacman_conf

    # Update trusted DNS resolver
    update_dns

    # --- Check Environment and Lynis Update ---
    echo "Checking if running in a live environment..."
    if grep -q 'archiso' /proc/cmdline; then
        echo "Live environment detected. Skipping Lynis update."
    else
        if command -v lynis &> /dev/null; then
            echo "Updating Lynis..."
            lynis update info || echo "Lynis update failed, skipping."
        else
            echo "Lynis not found. Installing..."
            pacman -Sy --noconfirm lynis || echo "Failed to install Lynis, skipping."
        fi
    fi

    # --- System Package Update ---
    echo "Updating system packages..."
    pacman -Syu --noconfirm || echo "Package update failed, continuing."

    # --- Secure File Permissions ---
    echo "Setting secure file permissions..."
    chmod 640 /etc/shadow
    chmod 644 /etc/passwd
    chmod 700 /root
    if [ -f /boot/grub/grub.cfg ]; then
        chmod 600 /boot/grub/grub.cfg
    else
        echo "/boot/grub/grub.cfg not found, skipping."
    fi

    # --- Restrict Unnecessary Services ---
    echo "Disabling unnecessary services..."
    for svc in avahi-daemon cups nfs-server rpcbind bluetooth ModemManager; do
        systemctl disable "$svc" 2>/dev/null || true
        systemctl stop "$svc" 2>/dev/null || true
    done

    # --- Secure DNS Settings (redundant with update_dns, but can reapply if needed) ---
    echo "Securing DNS settings..."
    # Already set in update_dns
    iptables -A OUTPUT -p udp --dport 53 -j ACCEPT
    iptables -A OUTPUT -p tcp --dport 853 -j ACCEPT
    iptables -A OUTPUT -p udp --sport 53 -j ACCEPT
    iptables -A OUTPUT -p tcp --sport 853 -j ACCEPT

    # --- Harden SSH Security ---
    echo "Hardening SSH configuration..."
    sed -i 's/^#PermitRootLogin.*/PermitRootLogin no/' /etc/ssh/sshd_config
    sed -i 's/^#PasswordAuthentication.*/PasswordAuthentication no/' /etc/ssh/sshd_config
    sed -i 's/^#X11Forwarding.*/X11Forwarding no/' /etc/ssh/sshd_config
    systemctl restart sshd || echo "Failed to restart SSHD, continuing."

    # --- Configure Firewall Rules ---
    echo "Applying firewall rules..."
    iptables -P INPUT DROP
    iptables -P FORWARD DROP
    iptables -P OUTPUT ACCEPT
    iptables -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
    iptables -A INPUT -p tcp --dport 22 -j ACCEPT
    iptables -A INPUT -i lo -j ACCEPT
    if ! iptables-save > /etc/iptables/iptables.rules; then
        echo "[Fallback] iptables-save failed. Falling back to listing current rules:"
        run "iptables -L -n -v"
    fi

    # --- Enable Kernel Security Parameters ---
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

    # --- Enable Auditing ---
    echo "Configuring auditing policies..."
    systemctl enable auditd
    systemctl restart auditd || echo "Failed to restart auditd, continuing."

    # --- Fallback for Systemctl Service Listing ---
    echo "Listing running services for review..."
    services=$(systemctl list-units --type=service --all 2>/dev/null)
    if [ -z "$services" ]; then
         echo "[Fallback] systemctl returned no results. Listing /etc/systemd/system contents instead:"
         ls /etc/systemd/system || echo "[ERROR] Unable to list /etc/systemd/system"
    else
         echo "$services"
    fi

    # --- Fallback for Mount Information ---
    echo "Reviewing mounts..."
    mount_output=$(mount)
    if echo "$mount_output" | grep -q "overlay"; then
         echo "[WARNING] Detected overlay mounts which may be manipulated."
         echo "Falling back to raw mount info from /proc/self/mountinfo:"
         run "cat /proc/self/mountinfo"
    else
         echo "$mount_output"
    fi

    # --- Filesystem Integrity Check ---
    echo "Running filesystem integrity check with rkhunter..."
    rkhunter --check --sk || echo "rkhunter check failed, continuing."

    echo "===== SYSTEM HARDENING COMPLETE ====="
}

# -----------------------------------------------------------------------------
# Function: System Investigation (with fallback checks)
# -----------------------------------------------------------------------------
investigation() {
    echo "===== SYSTEM INVESTIGATION START ====="
    
    # Create a secure temporary directory in RAM for the report
    REPORT_DIR=$(mktemp -d)
    REPORT="${REPORT_DIR}/FULL_REPORT.txt"
    touch "$REPORT"

    ts "=== STARTING ULTIMATE LEVEL INVESTIGATION ==="
    ts "System: $(uname -a)"

    # Core System State
    ts "--- CORE SYSTEM STATE ---"
    run "free -h"
    run "cat /proc/cpuinfo"
    run "cat /proc/meminfo"
    run "swapon -s"
    run "mount"
    run "df -h"
    run "lsblk -f"
    run "blkid"

    # If mount output shows overlay mounts, use a fallback method.
    mount_output=$(mount)
    if echo "$mount_output" | grep -q "overlay"; then
         ts "[WARNING] Detected overlay mounts. Using fallback mount info from /proc/self/mountinfo."
         run "cat /proc/self/mountinfo"
    fi

    # Memory Analysis
    ts "--- MEMORY ANALYSIS ---"
    run "ps auxf"
    run "top -b -n 1"
    run "vmstat 1 5"
    run "cat /proc/slabinfo"
    run "cat /proc/vmallocinfo"

    # Storage Investigation
    ts "--- STORAGE DEEP DIVE ---"
    for dev in $(ls /dev/sd* /dev/nvme* 2>/dev/null); do
        ts "Investigating $dev"
        run "hdparm -I $dev 2>/dev/null"
        run "smartctl -a $dev 2>/dev/null"
        run "dd if=$dev of=/dev/null bs=1M count=1 2>&1"
        run "blockdev --getsize64 $dev"
    done

    # USB and PCI Analysis
    ts "--- USB/PCI ANALYSIS ---"
    run "lsusb -v"
    run "lspci -vv"
    run "dmesg | grep -i usb"
    run "dmesg | grep -i pci"
    run "cat /sys/kernel/debug/usb/devices"

    # Network State
    ts "--- NETWORK STATE ---"
    run "ip a"
    run "ip route"
    run "netstat -tupan"
    run "ss -tulpn"
    run "iptables-save"

    # Fallback for systemctl if its output seems bogus
    sysctl_out=$(systemctl list-units --type=service --all 2>/dev/null)
    if [ -z "$sysctl_out" ]; then
         ts "[WARNING] 'systemctl list-units' returned no output. Falling back to listing /etc/systemd/system:"
         run "ls /etc/systemd/system"
    else
         ts "--- SYSTEMD UNITS ---"
         echo "$sysctl_out" >> "$REPORT"
    fi

    # Kernel and Module Analysis
    ts "--- KERNEL ANALYSIS ---"
    run "lsmod"
    run "cat /proc/modules"
    run "cat /proc/sys/kernel/tainted"
    run "cat /proc/sys/kernel/modules_disabled"
    for mod in $(lsmod | awk '{print $1}' | grep -v Module); do
        run "modinfo $mod"
    done

    # Process and File Handle Investigation
    ts "--- PROCESS INVESTIGATION ---"
    run "lsof"
    run "lsof | grep DEL"
    run "lsof | grep mem"
    run "cat /proc/sys/fs/file-nr"

    # Boot and EFI Analysis
    ts "--- BOOT ANALYSIS ---"
    run "efibootmgr -v"
    run "ls -laR /boot"
    run "cat /proc/cmdline"
    run "systemctl list-units"

    # File System Analysis
    ts "--- FILESYSTEM ANALYSIS ---"
    run "find / -type f -perm -4000 -ls"
    run "find / -type f -perm -2000 -ls"
    run "find / -type f -size +10M -ls"

    # Attempt USB Operations (Write Test)
    ts "--- USB OPERATIONS ---"
    for dev in $(ls /dev/sd[a-z] 2>/dev/null); do
        ts "Testing write capabilities on $dev"
        {
            dd if=/dev/zero of="${dev}" bs=512 count=1 conv=notrunc 2>&1
            sync
            dd if="${dev}" of=/dev/null bs=512 count=1 2>&1
        } >> "$REPORT"
    done

    ts "=== INVESTIGATION COMPLETE ==="
    ts "Report size: $(wc -c < "$REPORT") bytes"

    # Package the final report
    FINAL_ARCHIVE="/tmp/system_investigation_$(date +%Y%m%d_%H%M%S).tar.gz"
    tar -czf "$FINAL_ARCHIVE" -C "$REPORT_DIR" .

    echo "Complete report available at: $FINAL_ARCHIVE"
    echo "To view: tar -xzf $FINAL_ARCHIVE && cat FULL_REPORT.txt"
    echo "===== SYSTEM INVESTIGATION END ====="
}

# -----------------------------------------------------------------------------
# Function: Aggressive RAM Reclamation & System Isolation
# (This mode is destructive; no fallbacks provided.)
# -----------------------------------------------------------------------------
isolate_system() {
    echo "===== AGGRESSIVE SYSTEM ISOLATION START ====="
    echo "WARNING: This mode is highly destructive and will kill all processes!"
    echo "Press Ctrl+C to cancel within 5 seconds..."
    sleep 5

    # Reserve RAM for system survival (e.g., 2GB in MB)
    RESERVED_RAM=2048

    # Kill all non-essential processes
    echo "Killing processes..."
    killall -9 $(ps aux | grep -v PID | awk '{print $2}') || true

    # Clear memory caches
    echo "Clearing caches..."
    sync
    echo 3 > /proc/sys/vm/drop_caches

    # Disable swap
    echo "Disabling swap..."
    swapoff -a

    # Create a minimal namespace and drop privileges
    echo "Spawning a minimal isolated shell..."
    unshare -fmn bash << 'INNER'
        # Mount minimal filesystems
        mount -t proc proc /proc
        mount -t sysfs sys /sys
        mount -t tmpfs tmp /tmp

        # Restrict process environment
        export PATH="/bin:/usr/bin"
        export HOME="/tmp"

        echo "You are now in a minimal, isolated shell (restricted mode)."
        /bin/bash --restricted
INNER
    echo "===== AGGRESSIVE SYSTEM ISOLATION END ====="
}

# -----------------------------------------------------------------------------
# Function: Tool Downloads (using curl instead of yay)
# -----------------------------------------------------------------------------
download_tools() {
    echo "===== TOOL DOWNLOADS START ====="
    
    # Set the download directory
    DOWNLOAD_DIR="/var/dr/toolz"
    mkdir -p "$DOWNLOAD_DIR"

    # List of URLs for manual downloads
    URLs=(
      "https://www.ossec.net/downloads/ossec-hids-3.7.0.tar.gz"
      "https://github.com/virus-total/yara/releases/download/v4.1.0/yara-4.1.0.tar.gz"
      "https://github.com/MISP/MISP/archive/refs/heads/master.zip"
    )

    # List of pacman packages to cache (downloaded via pacman)
    pacman_packages=(
      "snort"
      "suricata"
      "clamav"
      "metasploit"
      "nmap"
      "wazuh"
      "yara"
      "zeek"
    )

    # List of AUR packages to download via curl (using AUR tarball snapshots)
    aur_packages=(
      "lynis"
      "kali-tools-top10"
      "rizin"
    )

    # Download the manual URLs
    for url in "${URLs[@]}"; do
      echo "Downloading $url..."
      curl -L -o "$DOWNLOAD_DIR/$(basename "$url")" "$url" || echo "[Fallback] Failed to download $url"
    done

    # Cache pacman packages
    for package in "${pacman_packages[@]}"; do
      echo "Caching pacman package: $package"
      pacman -Sw --cachedir="$DOWNLOAD_DIR" "$package" || echo "[Fallback] Failed to cache package: $package"
    done

    # Download AUR packages using curl
    for aur_package in "${aur_packages[@]}"; do
      echo "Downloading AUR package: $aur_package"
      curl -L -o "$DOWNLOAD_DIR/${aur_package}.tar.gz" \
           "https://aur.archlinux.org/cgit/aur.git/snapshot/${aur_package}.tar.gz" \
           || echo "[Fallback] Failed to download AUR package: $aur_package"
    done

    echo "Download complete. All tools are stored in $DOWNLOAD_DIR."
    # Optionally, trigger a minimal system deployment script if available
    if [ -x "/var/dr/toolz/minimal_deploy.sh" ]; then
        echo "Triggering minimal system deployment..."
        /var/dr/toolz/minimal_deploy.sh
    fi
    echo "===== TOOL DOWNLOADS END ====="
}

# -----------------------------------------------------------------------------
# Main: Parse Command-Line Argument and Run Appropriate Mode
# -----------------------------------------------------------------------------
print_usage() {
    echo "Usage: $0 [mode]"
    echo "Modes:"
    echo "  harden      - Run system hardening"
    echo "  investigate - Run system investigation"
    echo "  isolate     - Aggressive RAM reclamation and isolation (destructive)"
    echo "  download    - Download security tools and packages"
    echo "  all         - Run all modes (NOTE: 'isolate' is destructive)"
    exit 1
}

# Ensure the script is run as root
if [ "$EUID" -ne 0 ]; then
    echo "Please run as root."
    exit 1
fi

# Run the space check early to warn about low free space on copytoram/cowspace.
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
    all)
        harden_system
        investigation
        download_tools
        echo "About to run aggressive system isolation. Press Ctrl+C to cancel..."
        sleep 5
        isolate_system
        ;;
    *)
        print_usage
        ;;
esac

echo "Script execution completed."
