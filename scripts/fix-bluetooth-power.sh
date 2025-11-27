#!/bin/bash
#
# Fix Bluetooth rfkill blocking and power on the adapter
# Run this if Bluetooth shows "Powered: no" or "PowerState: off-blocked"
#

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

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
    log_error "This script must be run as root (use sudo)"
    exit 1
fi

# Get the script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

log_info "Fixing Bluetooth power and rfkill issues..."

# Install udev rule to unblock Bluetooth on boot
log_info "Installing udev rule for persistent Bluetooth unblock..."
if [ ! -f "$PROJECT_DIR/config/10-bluetooth.rules" ]; then
    log_error "udev rule file not found at $PROJECT_DIR/config/10-bluetooth.rules"
    exit 1
fi

cp "$PROJECT_DIR/config/10-bluetooth.rules" /etc/udev/rules.d/
udevadm control --reload-rules
log_info "✓ udev rule installed"

# Check rfkill status
log_info "Checking Bluetooth rfkill status..."
if rfkill list bluetooth | grep -q "Soft blocked: yes\|Hard blocked: yes"; then
    log_warn "Bluetooth is blocked, unblocking..."
    rfkill unblock bluetooth
    sleep 1
    log_info "✓ Bluetooth unblocked"
else
    log_info "✓ Bluetooth is not blocked"
fi

# Power on the Bluetooth adapter
log_info "Powering on Bluetooth adapter..."
hciconfig hci0 up 2>/dev/null || log_warn "Could not bring up hci0 with hciconfig"

# Wait for adapter to initialize
sleep 2

# Power on via bluetoothctl
log_info "Enabling Bluetooth power via bluetoothctl..."
bluetoothctl power on 2>/dev/null || log_warn "Could not power on via bluetoothctl"

# Restart Bluetooth services
log_info "Restarting Bluetooth services..."
systemctl restart bluetooth
sleep 2
systemctl restart bluealsa 2>/dev/null || true
systemctl restart bluealsa-aplay 2>/dev/null || true

# Verify Bluetooth is powered on
echo ""
log_info "Checking Bluetooth status..."
echo ""

if bluetoothctl show | grep -q "Powered: yes"; then
    echo -e "${GREEN}✓ Bluetooth adapter is powered on${NC}"
    bluetoothctl show | grep -E "Controller|Name|Powered|PowerState|Discoverable"
else
    echo -e "${RED}✗ Bluetooth may not be fully powered on${NC}"
    log_warn "Check status with: bluetoothctl show"
fi

echo ""

# Check service status
log_info "Checking BlueALSA services..."
echo ""

if systemctl is-active --quiet bluealsa; then
    echo -e "${GREEN}✓ bluealsa: running${NC}"
else
    echo -e "${RED}✗ bluealsa: failed${NC}"
    echo "Check logs with: sudo journalctl -u bluealsa -n 20"
fi

if systemctl is-active --quiet bluealsa-aplay; then
    echo -e "${GREEN}✓ bluealsa-aplay: running${NC}"
else
    echo -e "${RED}✗ bluealsa-aplay: failed${NC}"
    echo "Check logs with: sudo journalctl -u bluealsa-aplay -n 20"
fi

echo ""
log_info "Fix applied successfully!"
log_info "The Bluetooth adapter should now be powered on and ready for pairing."
