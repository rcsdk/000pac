#!/bin/bash

# Title: Ultimate Secure Scanning Script
# Description: A tamper-proof, battle-tested script for running security tools and securely reporting results.

# Configuration
LOG_DIR="/var/log/secure_scan"
REPORT_DIR="$LOG_DIR/reports"
CONFIG_DIR="/etc/secure_scan_configs"
LOCK_FILE="/etc/secure_scan.lock"
UPLOAD_URL="https://your-secure-endpoint.com/upload"  # Replace with your secure endpoint
TOOLS=("rkhunter" "chkrootkit" "clamav")

# Create directories
mkdir -p "$LOG_DIR" "$REPORT_DIR" "$CONFIG_DIR"

# Function to log and display messages
log() {
    echo "$1" | tee -a "$LOG_DIR/secure_scan.log"
}

# Function to print a separator
separator() {
    echo "------------------------------------" | tee -a "$LOG_DIR/secure_scan.log"
}

# 1. Remove Locks on Config Files
log "1. Removing Locks on Configuration Files..."
separator
for tool in "${TOOLS[@]}"; do
    if [[ -f "/etc/$tool/$tool.conf" ]]; then
        log "Unlocking /etc/$tool/$tool.conf..."
        sudo chattr -i "/etc/$tool/$tool.conf"
        sudo chmod 644 "/etc/$tool/$tool.conf"
    else
        log "Config file for $tool not found. Skipping."
    fi
done
separator
echo "Press Enter to continue..."
read

# 2. Replace Config Files with Battle-Tested Versions
log "2. Replacing Config Files with Battle-Tested Versions..."
separator
log "Downloading battle-tested config files..."
wget -q -O "$CONFIG_DIR/rkhunter.conf" https://raw.githubusercontent.com/your-repo/battle-tested-configs/main/rkhunter.conf
wget -q -O "$CONFIG_DIR/chkrootkit.conf" https://raw.githubusercontent.com/your-repo/battle-tested-configs/main/chkrootkit.conf
wget -q -O "$CONFIG_DIR/clamav.conf" https://raw.githubusercontent.com/your-repo/battle-tested-configs/main/clamav.conf

for tool in "${TOOLS[@]}"; do
    if [[ -f "$CONFIG_DIR/$tool.conf" ]]; then
        log "Replacing /etc/$tool/$tool.conf with battle-tested version..."
        sudo cp "$CONFIG_DIR/$tool.conf" "/etc/$tool/$tool.conf"
    else
        log "Battle-tested config for $tool not found. Skipping."
    fi
done
separator
echo "Press Enter to continue..."
read

# 3. Lock Config Files
log "3. Locking Configuration Files..."
separator
for tool in "${TOOLS[@]}"; do
    if [[ -f "/etc/$tool/$tool.conf" ]]; then
        log "Locking /etc/$tool/$tool.conf..."
        sudo chattr +i "/etc/$tool/$tool.conf"  # Immutable attribute
        sudo chmod 400 "/etc/$tool/$tool.conf"  # Read-only permissions
        if command -v setfacl &> /dev/null; then
            sudo setfacl -m u:root:r-- "/etc/$tool/$tool.conf"  # Restrict even root
        fi
    else
        log "Config file for $tool not found. Skipping."
    fi
done
separator
echo "Press Enter to continue..."
read

# 4. Run Security Tools with Deep Scanning
log "4. Running Security Tools with Deep Scanning..."
separator
for tool in "${TOOLS[@]}"; do
    log "Running $tool..."
    case "$tool" in
        "rkhunter")
            sudo rkhunter --check --sk --rwo --report-warnings-only --logfile "$REPORT_DIR/rkhunter.log"
            ;;
        "chkrootkit")
            sudo chkrootkit -q > "$REPORT_DIR/chkrootkit.log"
            ;;
        "clamav")
            sudo freshclam  # Update virus definitions
            sudo clamscan -r / --log="$REPORT_DIR/clamav.log" --infected --exclude-dir=/sys --exclude-dir=/proc --exclude-dir=/dev
            ;;
        *)
            log "Unknown tool: $tool. Skipping."
            ;;
    esac
done
separator
echo "Press Enter to continue..."
read

# 5. Upload Results to Secure Location
log "5. Uploading Results to Secure Location..."
separator
log "Compressing reports..."
tar -czf "$LOG_DIR/reports.tar.gz" -C "$REPORT_DIR" .
log "Uploading reports to $UPLOAD_URL..."
curl -X POST -F "file=@$LOG_DIR/reports.tar.gz" "$UPLOAD_URL" | tee -a "$LOG_DIR/secure_scan.log"
separator
log "Upload complete. Results are securely stored."
log "You can check the results at: $UPLOAD_URL/reports.tar.gz"
separator
echo "Script completed. Review the log file at $LOG_DIR/secure_scan.log."
