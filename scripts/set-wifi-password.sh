#!/bin/bash

###############################################################################
# Set WiFi Password for RPI Bluetooth Audio Receiver
###############################################################################

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    log_error "Please run as root (use sudo)"
    exit 1
fi

echo ""
echo "WiFi Password Configuration"
echo "============================"
echo ""
echo "Current SSID: RPI-Bluetooth-Audio"
echo ""

# Prompt for new password
read -p "Enter new WiFi password (min 8 characters): " password

# Validate password length
if [ ${#password} -lt 8 ]; then
    log_error "Password must be at least 8 characters long"
    exit 1
fi

# Update hostapd configuration
HOSTAPD_CONF="/etc/hostapd/hostapd.conf"

if [ ! -f "$HOSTAPD_CONF" ]; then
    log_error "hostapd.conf not found. Please run install.sh first"
    exit 1
fi

# Update password in config file
sed -i "s/^wpa_passphrase=.*/wpa_passphrase=${password}/" "$HOSTAPD_CONF"

log_info "WiFi password updated successfully"
log_info "Restarting hostapd service..."

systemctl restart hostapd

echo ""
log_info "Done! New WiFi password: $password"
log_info "Please reconnect to the WiFi network with the new password"
echo ""
