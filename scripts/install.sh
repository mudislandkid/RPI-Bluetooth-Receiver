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
# Pre-Installation Checks
###############################################################################
log_info "Checking for existing installation..."

# Check if BlueALSA is already installed
BLUEALSA_INSTALLED=false
if [ -f /usr/bin/bluealsad ]; then
    BLUEALSA_INSTALLED=true
    BLUEALSA_VERSION=$(/usr/bin/bluealsad --version 2>&1 | head -n1 || echo "unknown")
    log_info "✓ BlueALSA found: $BLUEALSA_VERSION"
fi

# Check if web app is installed
WEBAPP_INSTALLED=false
if [ -d "$INSTALL_DIR/web" ]; then
    WEBAPP_INSTALLED=true
    log_info "✓ Web application found at $INSTALL_DIR"
fi

# Check if WiFi is configured
WIFI_CONFIGURED=false
if [ -f /etc/hostapd/hostapd.conf ]; then
    # Check if password has been changed from default
    if ! grep -q "wpa_passphrase=ChangeThisPassword123!" /etc/hostapd/hostapd.conf; then
        WIFI_CONFIGURED=true
        log_info "✓ WiFi AP appears to be configured with custom password"
    else
        log_warn "WiFi AP has default password"
    fi
fi

# Installation mode flags
SKIP_BLUEALSA_BUILD=false
SKIP_WIFI_PASSWORD=false
UPDATE_MODE=false

# If already installed, ask user what to do
if [ "$BLUEALSA_INSTALLED" = true ] || [ "$WEBAPP_INSTALLED" = true ]; then
    UPDATE_MODE=true
    echo ""
    log_info "Existing installation detected!"
    echo ""

    # Ask about BlueALSA rebuild
    if [ "$BLUEALSA_INSTALLED" = true ]; then
        read -p "BlueALSA is already installed. Rebuild from source? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            SKIP_BLUEALSA_BUILD=true
            log_info "→ Skipping BlueALSA rebuild"
        fi
    fi

    # Ask about WiFi password
    if [ "$WIFI_CONFIGURED" = true ]; then
        read -p "WiFi password appears to be configured. Change it? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            SKIP_WIFI_PASSWORD=true
            log_info "→ Preserving existing WiFi password"
        fi
    fi

    echo ""
    log_info "Running in UPDATE mode - will refresh configurations and services"
    echo ""
    sleep 2
fi

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
    libbluetooth-dev \
    python3-dbus \
    python3-gi

# Audio packages
apt-get install -y \
    alsa-utils \
    libasound2-dev

# USB Music Player packages
apt-get install -y \
    mpg123 \
    ffmpeg \
    exfat-fuse \
    exfatprogs \
    ntfs-3g

# WiFi AP packages
apt-get install -y \
    hostapd \
    dnsmasq

# Python packages and development libraries
apt-get install -y \
    python3-pip \
    python3-venv \
    python3-full \
    libcairo2-dev \
    libgirepository1.0-dev \
    gir1.2-glib-2.0

# Network tools
apt-get install -y \
    iptables \
    net-tools

# Build tools for BlueALSA
apt-get install -y \
    git \
    automake \
    build-essential \
    libtool \
    pkg-config \
    libsbc-dev \
    libdbus-1-dev \
    libglib2.0-dev

log_info "Packages installed successfully"

###############################################################################
# Step 2.5: Build and Install BlueALSA from Source
###############################################################################

if [ "$SKIP_BLUEALSA_BUILD" = true ]; then
    log_info "Step 2.5: Skipping BlueALSA build (already installed)"
else
    log_info "Step 2.5: Building BlueALSA from source..."

    BLUEALSA_DIR="/tmp/bluez-alsa"

    # Clone BlueALSA repository
if [ -d "$BLUEALSA_DIR" ]; then
    rm -rf "$BLUEALSA_DIR"
fi

log_info "Cloning BlueALSA repository..."
if ! git clone https://github.com/Arkq/bluez-alsa.git "$BLUEALSA_DIR"; then
    log_error "Failed to clone BlueALSA repository"
    exit 1
fi

cd "$BLUEALSA_DIR" || exit 1

# Detect system architecture for ALSA plugin directory
MULTIARCH=$(dpkg-architecture -qDEB_HOST_MULTIARCH 2>/dev/null || echo "arm-linux-gnueabihf")
ALSA_PLUGIN_DIR="/usr/lib/${MULTIARCH}/alsa-lib"

log_info "Detected architecture: $MULTIARCH"
log_info "ALSA plugin directory: $ALSA_PLUGIN_DIR"

# Build and install
log_info "Running autoreconf..."
if ! autoreconf --install --force; then
    log_error "autoreconf failed"
    exit 1
fi

mkdir -p build
cd build || exit 1

log_info "Configuring BlueALSA..."
if ! ../configure --enable-systemd --with-alsaplugindir="$ALSA_PLUGIN_DIR"; then
    log_error "Configure failed"
    exit 1
fi

log_info "Compiling BlueALSA (this may take several minutes)..."
if ! make; then
    log_error "Make failed"
    exit 1
fi

log_info "Installing BlueALSA..."
if ! make install; then
    log_error "Make install failed"
    exit 1
fi

# Verify binaries were installed
if [ ! -f /usr/bin/bluealsad ]; then
    log_error "bluealsad binary not found after installation"
    log_error "Expected at: /usr/bin/bluealsad"
    exit 1
fi

if [ ! -f /usr/bin/bluealsa-aplay ]; then
    log_error "bluealsa-aplay binary not found after installation"
    log_error "Expected at: /usr/bin/bluealsa-aplay"
    exit 1
fi

    log_info "BlueALSA binaries installed successfully"
    log_info "  - bluealsad: /usr/bin/bluealsad"
    log_info "  - bluealsa-aplay: /usr/bin/bluealsa-aplay"

    # Update library cache
    ldconfig

    # Return to original directory
    cd "$PROJECT_DIR" || exit 1
fi

# Create user for bluealsa (always ensure user exists)
id -u bluealsa &>/dev/null || useradd -r -s /bin/false bluealsa

# Add bluealsa user to audio group
usermod -a -G audio bluealsa

# Create BlueALSA state directory
log_info "Creating BlueALSA state directory..."
mkdir -p /var/lib/bluealsa
chown bluealsa:bluealsa /var/lib/bluealsa
chmod 755 /var/lib/bluealsa

# Install D-Bus policy for BlueALSA
log_info "Installing D-Bus policy for BlueALSA..."
cp "$PROJECT_DIR/config/bluealsa-dbus.conf" /etc/dbus-1/system.d/
# Reload D-Bus configuration
systemctl reload dbus 2>/dev/null || systemctl restart dbus

log_info "BlueALSA configuration complete"

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

# Install udev rule to unblock Bluetooth on boot
log_info "Installing udev rule for Bluetooth..."
cp "$PROJECT_DIR/config/10-bluetooth.rules" /etc/udev/rules.d/
udevadm control --reload-rules

# Unblock Bluetooth if it's RF-killed
log_info "Checking Bluetooth rfkill status..."
if rfkill list bluetooth | grep -q "Soft blocked: yes\|Hard blocked: yes"; then
    log_warn "Bluetooth is blocked, unblocking..."
    rfkill unblock bluetooth
    sleep 1
fi

# Power on the Bluetooth adapter
log_info "Powering on Bluetooth adapter..."
hciconfig hci0 up 2>/dev/null || log_warn "Could not bring up hci0 with hciconfig"

# Wait for adapter to initialize
sleep 2

# Power on via bluetoothctl
log_info "Enabling Bluetooth power..."
bluetoothctl power on 2>/dev/null || log_warn "Could not power on via bluetoothctl"

# Verify Bluetooth is powered on
if bluetoothctl show | grep -q "Powered: yes"; then
    log_info "✓ Bluetooth adapter powered on successfully"
else
    log_warn "Bluetooth may not be fully powered on, check with: bluetoothctl show"
fi

log_info "Bluetooth configured successfully"

###############################################################################
# Step 5: Configure WiFi Access Point
###############################################################################
log_info "Step 5: Configuring WiFi Access Point..."

# Stop services if running
systemctl stop hostapd 2>/dev/null || true
systemctl stop dnsmasq 2>/dev/null || true

# Disconnect wlan0 from any existing WiFi networks
log_info "Disconnecting wlan0 from existing networks..."
if command -v nmcli &> /dev/null; then
    nmcli device disconnect wlan0 2>/dev/null || true
fi

# Configure NetworkManager to not manage wlan0 (if NetworkManager is installed)
if systemctl is-active --quiet NetworkManager; then
    log_info "Configuring NetworkManager to ignore wlan0..."
    mkdir -p /etc/NetworkManager/conf.d
    cat > /etc/NetworkManager/conf.d/unmanage-wlan0.conf <<EOF
[keyfile]
unmanaged-devices=interface-name:wlan0
EOF
    systemctl restart NetworkManager
    sleep 2
fi

# Backup original configs
[ -f /etc/hostapd/hostapd.conf ] && cp /etc/hostapd/hostapd.conf /etc/hostapd/hostapd.conf.backup
[ -f /etc/dnsmasq.conf ] && cp /etc/dnsmasq.conf /etc/dnsmasq.conf.backup

# Copy hostapd configuration
if [ "$SKIP_WIFI_PASSWORD" = true ] && [ -f /etc/hostapd/hostapd.conf.backup ]; then
    # Preserve existing WiFi password
    log_info "Preserving existing WiFi password..."
    EXISTING_PASSWORD=$(grep "^wpa_passphrase=" /etc/hostapd/hostapd.conf.backup | cut -d'=' -f2)
    cp "$PROJECT_DIR/config/hostapd.conf" /etc/hostapd/hostapd.conf
    if [ -n "$EXISTING_PASSWORD" ]; then
        sed -i "s/^wpa_passphrase=.*/wpa_passphrase=$EXISTING_PASSWORD/" /etc/hostapd/hostapd.conf
        log_info "✓ WiFi password preserved"
    fi
else
    cp "$PROJECT_DIR/config/hostapd.conf" /etc/hostapd/hostapd.conf
    log_warn "Using default WiFi password - CHANGE THIS AFTER INSTALLATION!"
fi

# Update hostapd default file
echo 'DAEMON_CONF="/etc/hostapd/hostapd.conf"' > /etc/default/hostapd

# Copy dnsmasq configuration
cp "$PROJECT_DIR/config/dnsmasq.conf" /etc/dnsmasq.conf

# Configure static IP using systemd-networkd (works on all modern systems)
log_info "Configuring static IP for wlan0..."
mkdir -p /etc/systemd/network
cat > /etc/systemd/network/10-wlan0.network <<EOF
[Match]
Name=wlan0

[Network]
Address=192.168.4.1/24
DHCPServer=no
EOF

# Enable and start systemd-networkd
systemctl enable systemd-networkd
systemctl restart systemd-networkd

# Bring down and up wlan0 to apply settings
ip link set wlan0 down 2>/dev/null || true
sleep 1
ip link set wlan0 up
sleep 2

# Manually set IP if not already set
if ! ip addr show wlan0 | grep -q "192.168.4.1"; then
    log_info "Setting static IP manually..."
    ip addr flush dev wlan0
    ip addr add 192.168.4.1/24 dev wlan0
fi

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

# Create Python virtual environment
log_info "Creating Python virtual environment..."
python3 -m venv "$INSTALL_DIR/venv"

# Install Python dependencies in virtual environment
log_info "Installing Python dependencies..."
"$INSTALL_DIR/venv/bin/pip" install --upgrade pip
"$INSTALL_DIR/venv/bin/pip" install -r "$INSTALL_DIR/web/requirements.txt"

# Set permissions
chmod +x "$INSTALL_DIR/web/app.py"
chmod +x "$INSTALL_DIR/bt_agent.py"

log_info "Web application installed"

###############################################################################
# Step 6.5: Install USB Music Player
###############################################################################
log_info "Step 6.5: Installing USB music player..."

# Install USB mount/unmount scripts
log_info "Installing USB auto-mount scripts..."
cp "$PROJECT_DIR/scripts/usb-mount.sh" /usr/local/bin/
cp "$PROJECT_DIR/scripts/usb-unmount.sh" /usr/local/bin/
chmod +x /usr/local/bin/usb-mount.sh
chmod +x /usr/local/bin/usb-unmount.sh

# Install udev rules for USB auto-mounting
log_info "Installing udev rules for USB auto-mount..."
cp "$PROJECT_DIR/config/99-usb-automount.rules" /etc/udev/rules.d/
udevadm control --reload-rules

# Copy USB player script
log_info "Installing USB player service script..."
cp "$PROJECT_DIR/web/usb_player.py" "$INSTALL_DIR/"
chmod +x "$INSTALL_DIR/usb_player.py"

# Create USB mount point
mkdir -p /media/usb
chmod 755 /media/usb

# Create state directory for USB player
mkdir -p /var/lib/bluetooth-receiver
chmod 755 /var/lib/bluetooth-receiver

# Create music directory for local playback
mkdir -p /var/music
chmod 777 /var/music  # Allow all users to add music
chown pi:pi /var/music 2>/dev/null || chown 1000:1000 /var/music

log_info "Music player installed (music directory: /var/music)"

###############################################################################
# Step 7: Install Systemd Services
###############################################################################
log_info "Step 7: Installing systemd services..."

# Copy service files
cp "$PROJECT_DIR/services/bluealsa.service" /etc/systemd/system/
cp "$PROJECT_DIR/services/bluealsa-aplay.service" /etc/systemd/system/
cp "$PROJECT_DIR/services/bluetooth-agent.service" /etc/systemd/system/
cp "$PROJECT_DIR/services/bluetooth-web.service" /etc/systemd/system/
cp "$PROJECT_DIR/services/usb-player.service" /etc/systemd/system/

# Reload systemd
systemctl daemon-reload

# Unmask hostapd (must be done before enabling)
systemctl unmask hostapd

# Enable and start services
systemctl enable bluealsa
systemctl enable bluealsa-aplay
systemctl enable bluetooth-agent
systemctl enable bluetooth-web
systemctl enable usb-player
systemctl enable hostapd
systemctl enable dnsmasq

# Restart services to apply any configuration changes
log_info "Starting services..."
systemctl restart bluetooth
systemctl restart bluealsa
systemctl restart bluealsa-aplay
systemctl restart bluetooth-agent
systemctl restart bluetooth-web
systemctl restart usb-player
systemctl restart hostapd
systemctl restart dnsmasq

log_info "Systemd services configured and started"

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
log_info "Features:"
log_info "  • Bluetooth Audio Receiver (A2DP)"
log_info "  • USB Music Player (auto-play when USB inserted)"
log_info "  • Web-based volume control and device management"
echo ""
log_info "=========================================="
