#!/bin/bash

# Title: Ultimate Forensic Script with Network and Service Analysis
# Description: A battle-tested, tamper-proof script for forensic analysis, network, and service usage.

# Configuration
LOG_DIR="/var/log/forensic_scan"
REPORT_DIR="$LOG_DIR/reports"
LOCK_FILE="/etc/forensic_scan.lock"
UPLOAD_URL="https://your-secure-endpoint.com/upload"  # Replace with your secure endpoint

# Improvement 1: Ensure script runs as root
if [[ $EUID -ne 0 ]]; then
    echo "This script must be run as root. Use sudo." >&2
    exit 1
fi

# Improvement 2: Create directories with error handling
mkdir -p "$LOG_DIR" "$REPORT_DIR" || {
    echo "Failed to create directories. Check permissions." >&2
    exit 1
}

# Function to log and display messages
log() {
    echo "$1" | tee -a "$LOG_DIR/forensic_scan.log"
}

# Function to print a separator
separator() {
    echo "------------------------------------" | tee -a "$LOG_DIR/forensic_scan.log"
}

# Improvement 3: Initialize log file
echo "=== Ultimate Forensic Script with Network and Service Analysis ===" > "$LOG_DIR/forensic_scan.log"
echo "Report generated on: $(date)" >> "$LOG_DIR/forensic_scan.log"

# Improvement 4: Check for required tools
REQUIRED_TOOLS=("curl" "sha256sum" "lsmod" "dmesg" "ss" "stat" "journalctl" "lsof" "iptables" "netstat" "nmap")
for tool in "${REQUIRED_TOOLS[@]}"; do
    if ! command -v "$tool" &> /dev/null; then
        log "ERROR: $tool is not installed. Please install it and try again."
        exit 1
    fi
done

# 1. Bootloader Integrity Check
log "1. Checking Bootloader Integrity..."
separator
if [[ -f /boot/grub/grub.cfg ]]; then
    BOOTLOADER_CHECKSUM=$(sha256sum /boot/grub/grub.cfg | awk '{print $1}')
    log "Bootloader checksum: $BOOTLOADER_CHECKSUM"
    log "Compare this checksum to a known-good value to detect tampering."
else
    log "GRUB configuration not found. Check your bootloader."
fi
separator
echo "Press Enter to continue..."
read

# 2. Kernel Module Verification
log "2. Verifying Kernel Modules..."
separator
log "Listing loaded kernel modules:"
lsmod | tee -a "$LOG_DIR/forensic_scan.log"
log "Checking kernel logs for errors or warnings:"
dmesg | grep -i -E 'error|warning|malware' | tee -a "$LOG_DIR/forensic_scan.log"
separator
log "Explanation: Look for unauthorized or suspicious kernel modules."
separator
echo "Press Enter to continue..."
read

# 3. Network Connections Analysis
log "3. Analyzing Network Connections..."
separator
log "Listing active network connections:"
ss -tulnp | tee -a "$LOG_DIR/forensic_scan.log"
log "Explanation: Identify unexpected or suspicious connections."
separator
echo "Press Enter to continue..."
read

# 4. Critical File Permissions Check
log "4. Checking Critical File Permissions..."
separator
declare -A SECURE_FILES=(
    ["/etc/passwd"]="644"
    ["/etc/shadow"]="600"
    ["/etc/sudoers"]="440"
)
for file in "${!SECURE_FILES[@]}"; do
    if [[ -f "$file" ]]; then
        PERMISSIONS=$(stat -c "%A %U %G" "$file")
        log "Permissions for $file: $PERMISSIONS"
        if [[ "$PERMISSIONS" != *"${SECURE_FILES[$file]}"* ]]; then
            log "WARNING: $file has incorrect permissions!"
        fi
    else
        log "File $file not found. Skipping."
    fi
done
separator
log "Explanation: Ensure critical files have secure permissions."
separator
echo "Press Enter to continue..."
read

# 5. System Log Analysis
log "5. Analyzing System Logs..."
separator
log "Checking system logs for errors or warnings:"
journalctl -p 3 -xb | tee -a "$LOG_DIR/forensic_scan.log"
separator
log "Explanation: Identify anomalies in system logs."
separator
echo "Press Enter to continue..."
read

# 6. Network and Service Analysis
log "6. Network and Service Analysis..."
separator

# 6.1 Check Listening Ports
log "6.1 Checking Listening Ports..."
log "Command: sudo ss -tuln"
sudo ss -tuln | tee -a "$LOG_DIR/forensic_scan.log"
log "Explanation: Identify open and listening ports."
separator

# 6.2 Check Active Connections
log "6.2 Checking Active Connections..."
log "Command: sudo ss -tunp"
sudo ss -tunp | tee -a "$LOG_DIR/forensic_scan.log"
log "Explanation: Identify active network connections and associated processes."
separator

# 6.3 Check Open Files (Including Network Sockets)
log "6.3 Checking Open Files and Network Sockets..."
log "Command: sudo lsof -i"
sudo lsof -i | tee -a "$LOG_DIR/forensic_scan.log"
log "Explanation: Identify open files and network sockets."
separator

# 6.4 Check Firewall Rules
log "6.4 Checking Firewall Rules..."
log "Command: sudo iptables -L -v -n"
sudo iptables -L -v -n | tee -a "$LOG_DIR/forensic_scan.log"
log "Explanation: Review current firewall rules."
separator

# 6.5 Check IPv6 Status
log "6.5 Checking IPv6 Status..."
log "Command: cat /proc/sys/net/ipv6/conf/all/disable_ipv6"
cat /proc/sys/net/ipv6/conf/all/disable_ipv6 | tee -a "$LOG_DIR/forensic_scan.log"
log "Explanation: Check if IPv6 is enabled or disabled."
separator

# 6.6 Check Running Services
log "6.6 Checking Running Services..."
log "Command: sudo systemctl list-units --type=service --state=running"
sudo systemctl list-units --type=service --state=running | tee -a "$LOG_DIR/forensic_scan.log"
log "Explanation: List all running services."
separator

# 6.7 Check DNS Configuration
log "6.7 Checking DNS Configuration..."
log "Command: cat /etc/resolv.conf"
cat /etc/resolv.conf | tee -a "$LOG_DIR/forensic_scan.log"
log "Explanation: Review DNS server configuration."
separator

# 6.8 Check UDP Traffic
log "6.8 Checking UDP Traffic..."
log "Command: sudo ss -uap"
sudo ss -uap | tee -a "$LOG_DIR/forensic_scan.log"
log "Explanation: Identify active UDP connections."
separator

# 6.9 Check HTTP Traffic
log "6.9 Checking HTTP Traffic..."
log "Command: sudo netstat -tpn | grep :80"
sudo netstat -tpn | grep :80 | tee -a "$LOG_DIR/forensic_scan.log"
log "Explanation: Identify active HTTP connections."
separator

# 6.10 Check Kernel Routing Table
log "6.10 Checking Kernel Routing Table..."
log "Command: ip route show"
ip route show | tee -a "$LOG_DIR/forensic_scan.log"
log "Explanation: Review the current routing table."
separator

# 6.11 Check Network Logs
log "6.11 Checking Network Logs..."
log "Command: sudo journalctl -u NetworkManager"
sudo journalctl -u NetworkManager | tee -a "$LOG_DIR/forensic_scan.log"
log "Explanation: Review network-related logs."
separator

# 6.12 Check for Open UDP Ports
log "6.12 Checking for Open UDP Ports..."
log "Command: sudo nmap -sU -p- localhost"
sudo nmap -sU -p- localhost | tee -a "$LOG_DIR/forensic_scan.log"
log "Explanation: Scan for open UDP ports."
separator

# 7. Secure Upload of Results
log "7. Uploading Results to Secure Location..."
separator
log "Compressing reports..."
tar -czf "$LOG_DIR/reports.tar.gz" -C "$REPORT_DIR" . || {
    log "ERROR: Failed to compress reports."
    exit 1
}
log "Uploading reports to $UPLOAD_URL..."
curl -X POST -F "file=@$LOG_DIR/reports.tar.gz" "$UPLOAD_URL" | tee -a "$LOG_DIR/forensic_scan.log" || {
    log "ERROR: Failed to upload reports."
    exit 1
}
separator
log "Upload complete. Results are securely stored."
log "You can check the results at: $UPLOAD_URL/reports.tar.gz"
separator

# Improvement 20: Final cleanup
log "8. Cleaning up..."
rm -f "$LOG_DIR/reports.tar.gz"
log "Cleanup complete."

# Final Message
log "Forensic analysis completed. Review the log file at $LOG_DIR/forensic_scan.log."#!/bin/bash

# Title: Ultimate Forensic Script with Network and Service Analysis
# Description: A battle-tested, tamper-proof script for forensic analysis, network, and service usage.

# Configuration
LOG_DIR="/var/log/forensic_scan"
REPORT_DIR="$LOG_DIR/reports"
LOCK_FILE="/etc/forensic_scan.lock"
UPLOAD_URL="https://your-secure-endpoint.com/upload"  # Replace with your secure endpoint

# Improvement 1: Ensure script runs as root
if [[ $EUID -ne 0 ]]; then
    echo "This script must be run as root. Use sudo." >&2
    exit 1
fi

# Improvement 2: Create directories with error handling
mkdir -p "$LOG_DIR" "$REPORT_DIR" || {
    echo "Failed to create directories. Check permissions." >&2
    exit 1
}

# Function to log and display messages
log() {
    echo "$1" | tee -a "$LOG_DIR/forensic_scan.log"
}

# Function to print a separator
separator() {
    echo "------------------------------------" | tee -a "$LOG_DIR/forensic_scan.log"
}

# Improvement 3: Initialize log file
echo "=== Ultimate Forensic Script with Network and Service Analysis ===" > "$LOG_DIR/forensic_scan.log"
echo "Report generated on: $(date)" >> "$LOG_DIR/forensic_scan.log"

# Improvement 4: Check for required tools
REQUIRED_TOOLS=("curl" "sha256sum" "lsmod" "dmesg" "ss" "stat" "journalctl" "lsof" "iptables" "netstat" "nmap")
for tool in "${REQUIRED_TOOLS[@]}"; do
    if ! command -v "$tool" &> /dev/null; then
        log "ERROR: $tool is not installed. Please install it and try again."
        exit 1
    fi
done

# 1. Bootloader Integrity Check
log "1. Checking Bootloader Integrity..."
separator
if [[ -f /boot/grub/grub.cfg ]]; then
    BOOTLOADER_CHECKSUM=$(sha256sum /boot/grub/grub.cfg | awk '{print $1}')
    log "Bootloader checksum: $BOOTLOADER_CHECKSUM"
    log "Compare this checksum to a known-good value to detect tampering."
else
    log "GRUB configuration not found. Check your bootloader."
fi
separator
echo "Press Enter to continue..."
read

# 2. Kernel Module Verification
log "2. Verifying Kernel Modules..."
separator
log "Listing loaded kernel modules:"
lsmod | tee -a "$LOG_DIR/forensic_scan.log"
log "Checking kernel logs for errors or warnings:"
dmesg | grep -i -E 'error|warning|malware' | tee -a "$LOG_DIR/forensic_scan.log"
separator
log "Explanation: Look for unauthorized or suspicious kernel modules."
separator
echo "Press Enter to continue..."
read

# 3. Network Connections Analysis
log "3. Analyzing Network Connections..."
separator
log "Listing active network connections:"
ss -tulnp | tee -a "$LOG_DIR/forensic_scan.log"
log "Explanation: Identify unexpected or suspicious connections."
separator
echo "Press Enter to continue..."
read

# 4. Critical File Permissions Check
log "4. Checking Critical File Permissions..."
separator
declare -A SECURE_FILES=(
    ["/etc/passwd"]="644"
    ["/etc/shadow"]="600"
    ["/etc/sudoers"]="440"
)
for file in "${!SECURE_FILES[@]}"; do
    if [[ -f "$file" ]]; then
        PERMISSIONS=$(stat -c "%A %U %G" "$file")
        log "Permissions for $file: $PERMISSIONS"
        if [[ "$PERMISSIONS" != *"${SECURE_FILES[$file]}"* ]]; then
            log "WARNING: $file has incorrect permissions!"
        fi
    else
        log "File $file not found. Skipping."
    fi
done
separator
log "Explanation: Ensure critical files have secure permissions."
separator
echo "Press Enter to continue..."
read

# 5. System Log Analysis
log "5. Analyzing System Logs..."
separator
log "Checking system logs for errors or warnings:"
journalctl -p 3 -xb | tee -a "$LOG_DIR/forensic_scan.log"
separator
log "Explanation: Identify anomalies in system logs."
separator
echo "Press Enter to continue..."
read

# 6. Network and Service Analysis
log "6. Network and Service Analysis..."
separator

# 6.1 Check Listening Ports
log "6.1 Checking Listening Ports..."
log "Command: sudo ss -tuln"
sudo ss -tuln | tee -a "$LOG_DIR/forensic_scan.log"
log "Explanation: Identify open and listening ports."
separator

# 6.2 Check Active Connections
log "6.2 Checking Active Connections..."
log "Command: sudo ss -tunp"
sudo ss -tunp | tee -a "$LOG_DIR/forensic_scan.log"
log "Explanation: Identify active network connections and associated processes."
separator

# 6.3 Check Open Files (Including Network Sockets)
log "6.3 Checking Open Files and Network Sockets..."
log "Command: sudo lsof -i"
sudo lsof -i | tee -a "$LOG_DIR/forensic_scan.log"
log "Explanation: Identify open files and network sockets."
separator

# 6.4 Check Firewall Rules
log "6.4 Checking Firewall Rules..."
log "Command: sudo iptables -L -v -n"
sudo iptables -L -v -n | tee -a "$LOG_DIR/forensic_scan.log"
log "Explanation: Review current firewall rules."
separator

# 6.5 Check IPv6 Status
log "6.5 Checking IPv6 Status..."
log "Command: cat /proc/sys/net/ipv6/conf/all/disable_ipv6"
cat /proc/sys/net/ipv6/conf/all/disable_ipv6 | tee -a "$LOG_DIR/forensic_scan.log"
log "Explanation: Check if IPv6 is enabled or disabled."
separator

# 6.6 Check Running Services
log "6.6 Checking Running Services..."
log "Command: sudo systemctl list-units --type=service --state=running"
sudo systemctl list-units --type=service --state=running | tee -a "$LOG_DIR/forensic_scan.log"
log "Explanation: List all running services."
separator

# 6.7 Check DNS Configuration
log "6.7 Checking DNS Configuration..."
log "Command: cat /etc/resolv.conf"
cat /etc/resolv.conf | tee -a "$LOG_DIR/forensic_scan.log"
log "Explanation: Review DNS server configuration."
separator

# 6.8 Check UDP Traffic
log "6.8 Checking UDP Traffic..."
log "Command: sudo ss -uap"
sudo ss -uap | tee -a "$LOG_DIR/forensic_scan.log"
log "Explanation: Identify active UDP connections."
separator

# 6.9 Check HTTP Traffic
log "6.9 Checking HTTP Traffic..."
log "Command: sudo netstat -tpn | grep :80"
sudo netstat -tpn | grep :80 | tee -a "$LOG_DIR/forensic_scan.log"
log "Explanation: Identify active HTTP connections."
separator

# 6.10 Check Kernel Routing Table
log "6.10 Checking Kernel Routing Table..."
log "Command: ip route show"
ip route show | tee -a "$LOG_DIR/forensic_scan.log"
log "Explanation: Review the current routing table."
separator

# 6.11 Check Network Logs
log "6.11 Checking Network Logs..."
log "Command: sudo journalctl -u NetworkManager"
sudo journalctl -u NetworkManager | tee -a "$LOG_DIR/forensic_scan.log"
log "Explanation: Review network-related logs."
separator

# 6.12 Check for Open UDP Ports
log "6.12 Checking for Open UDP Ports..."
log "Command: sudo nmap -sU -p- localhost"
sudo nmap -sU -p- localhost | tee -a "$LOG_DIR/forensic_scan.log"
log "Explanation: Scan for open UDP ports."
separator

# 7. Secure Upload of Results
log "7. Uploading Results to Secure Location..."
separator
log "Compressing reports..."
tar -czf "$LOG_DIR/reports.tar.gz" -C "$REPORT_DIR" . || {
    log "ERROR: Failed to compress reports."
    exit 1
}
log "Uploading reports to $UPLOAD_URL..."
curl -X POST -F "file=@$LOG_DIR/reports.tar.gz" "$UPLOAD_URL" | tee -a "$LOG_DIR/forensic_scan.log" || {
    log "ERROR: Failed to upload reports."
    exit 1
}
separator
log "Upload complete. Results are securely stored."
log "You can check the results at: $UPLOAD_URL/reports.tar.gz"
separator

# Improvement 20: Final cleanup
log "8. Cleaning up..."
rm -f "$LOG_DIR/reports.tar.gz"
log "Cleanup complete."

# Final Message
log "Forensic analysis completed. Review the log file at $LOG_DIR/forensic_scan.log."
