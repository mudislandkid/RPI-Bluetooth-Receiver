#!/bin/bash

###############################################################################
# RPI Bluetooth Audio Receiver - Installation Script
# This script installs and configures all components for the Bluetooth receiver
###############################################################################

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    log_error "Please run as root (use sudo)"
    exit 1
fi

# Get the script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
INSTALL_DIR="/opt/bluetooth-receiver"

log_info "Starting RPI Bluetooth Audio Receiver installation..."
log_info "Project directory: $PROJECT_DIR"

###############################################################################
# Step 1: System Update
###############################################################################
log_info "Step 1: Updating system packages..."
apt-get update
apt-get upgrade -y

###############################################################################
# Step 2: Install Required Packages
###############################################################################
log_info "Step 2: Installing required packages..."

# Bluetooth packages
apt-get install -y \
    bluez \
    bluez-tools \
    bluealsa \
    libbluetooth-dev \
    python3-dbus \
    python3-gi

# Audio packages
apt-get install -y \
    alsa-utils \
    alsa-base

# WiFi AP packages
apt-get install -y \
    hostapd \
    dnsmasq

# Python packages
apt-get install -y \
    python3-pip \
    python3-venv

# Network tools
apt-get install -y \
    iptables \
    net-tools

log_info "Packages installed successfully"

###############################################################################
# Step 3: Configure Audio
###############################################################################
log_info "Step 3: Configuring audio output..."

# Set audio output to 3.5mm jack
amixer cset numid=3 1 || log_warn "Could not set audio output"

# Set default volume
amixer sset PCM 80% || log_warn "Could not set volume"

# Copy ALSA configuration
if [ -f "$PROJECT_DIR/config/asound.conf" ]; then
    cp "$PROJECT_DIR/config/asound.conf" /etc/asound.conf
    log_info "ALSA configuration installed"
fi

###############################################################################
# Step 4: Configure Bluetooth
###############################################################################
log_info "Step 4: Configuring Bluetooth..."

# Backup original config
if [ -f /etc/bluetooth/main.conf ]; then
    cp /etc/bluetooth/main.conf /etc/bluetooth/main.conf.backup
fi

# Copy Bluetooth configuration
cp "$PROJECT_DIR/config/bluetooth-main.conf" /etc/bluetooth/main.conf

# Enable Bluetooth service
systemctl enable bluetooth
systemctl start bluetooth

log_info "Bluetooth configured successfully"

###############################################################################
# Step 5: Configure WiFi Access Point
###############################################################################
log_info "Step 5: Configuring WiFi Access Point..."

# Stop services if running
systemctl stop hostapd 2>/dev/null || true
systemctl stop dnsmasq 2>/dev/null || true

# Backup original configs
[ -f /etc/hostapd/hostapd.conf ] && cp /etc/hostapd/hostapd.conf /etc/hostapd/hostapd.conf.backup
[ -f /etc/dnsmasq.conf ] && cp /etc/dnsmasq.conf /etc/dnsmasq.conf.backup
[ -f /etc/dhcpcd.conf ] && cp /etc/dhcpcd.conf /etc/dhcpcd.conf.backup

# Copy hostapd configuration
cp "$PROJECT_DIR/config/hostapd.conf" /etc/hostapd/hostapd.conf

# Update hostapd default file
echo 'DAEMON_CONF="/etc/hostapd/hostapd.conf"' > /etc/default/hostapd

# Copy dnsmasq configuration
cp "$PROJECT_DIR/config/dnsmasq.conf" /etc/dnsmasq.conf

# Configure static IP for wlan0
cat "$PROJECT_DIR/config/dhcpcd.conf.append" >> /etc/dhcpcd.conf

log_info "WiFi AP configured successfully"

###############################################################################
# Step 6: Install Web Application
###############################################################################
log_info "Step 6: Installing web application..."

# Create installation directory
mkdir -p "$INSTALL_DIR/web"

# Copy web application files
cp -r "$PROJECT_DIR/web/"* "$INSTALL_DIR/web/"

# Copy Bluetooth agent
cp "$PROJECT_DIR/web/bt_agent.py" "$INSTALL_DIR/"

# Install Python dependencies
pip3 install -r "$INSTALL_DIR/web/requirements.txt"

# Set permissions
chmod +x "$INSTALL_DIR/web/app.py"
chmod +x "$INSTALL_DIR/bt_agent.py"

log_info "Web application installed"

###############################################################################
# Step 7: Install Systemd Services
###############################################################################
log_info "Step 7: Installing systemd services..."

# Copy service files
cp "$PROJECT_DIR/services/bluealsa.service" /etc/systemd/system/
cp "$PROJECT_DIR/services/bluealsa-aplay.service" /etc/systemd/system/
cp "$PROJECT_DIR/services/bluetooth-agent.service" /etc/systemd/system/
cp "$PROJECT_DIR/services/bluetooth-web.service" /etc/systemd/system/

# Reload systemd
systemctl daemon-reload

# Enable services
systemctl enable bluealsa
systemctl enable bluealsa-aplay
systemctl enable bluetooth-agent
systemctl enable bluetooth-web
systemctl enable hostapd
systemctl enable dnsmasq

log_info "Systemd services configured"

###############################################################################
# Step 8: Configure Firewall (Optional)
###############################################################################
log_info "Step 8: Configuring firewall..."

# Allow HTTP traffic
iptables -A INPUT -p tcp --dport 80 -j ACCEPT || true

# Save iptables rules
iptables-save > /etc/iptables.rules || true

log_info "Firewall configured"

###############################################################################
# Step 9: Final Configuration
###############################################################################
log_info "Step 9: Final configuration..."

# Unmask hostapd
systemctl unmask hostapd

log_info "Configuration complete"

###############################################################################
# Installation Complete
###############################################################################
echo ""
log_info "=========================================="
log_info "Installation Complete!"
log_info "=========================================="
echo ""
log_info "IMPORTANT: Please review and update the WiFi password in:"
log_info "  /etc/hostapd/hostapd.conf"
echo ""
log_info "Current password is: ChangeThisPassword123!"
log_info "Change 'wpa_passphrase' to a strong password"
echo ""
log_info "After updating the password, reboot the system:"
log_info "  sudo reboot"
echo ""
log_info "After reboot, connect to WiFi network 'RPI-Bluetooth-Audio'"
log_info "and access the web interface at: http://192.168.4.1"
echo ""
log_info "=========================================="
