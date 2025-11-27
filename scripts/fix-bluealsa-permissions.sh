#!/bin/bash
#
# Fix BlueALSA permissions and D-Bus configuration
# Run this to fix the "Permission denied" and "Couldn't acquire D-Bus name" errors
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

log_info "Fixing BlueALSA permissions and D-Bus configuration..."

# Stop bluealsa service
log_info "Stopping bluealsa service..."
systemctl stop bluealsa 2>/dev/null || true
systemctl stop bluealsa-aplay 2>/dev/null || true

# Create BlueALSA state directory with proper permissions
log_info "Creating /var/lib/bluealsa directory..."
mkdir -p /var/lib/bluealsa
chown bluealsa:bluealsa /var/lib/bluealsa
chmod 755 /var/lib/bluealsa
log_info "✓ Directory created and permissions set"

# Install D-Bus policy for BlueALSA
log_info "Installing D-Bus policy..."
if [ ! -f "$PROJECT_DIR/config/bluealsa-dbus.conf" ]; then
    log_error "D-Bus policy file not found at $PROJECT_DIR/config/bluealsa-dbus.conf"
    exit 1
fi

cp "$PROJECT_DIR/config/bluealsa-dbus.conf" /etc/dbus-1/system.d/
log_info "✓ D-Bus policy installed"

# Reload D-Bus configuration
log_info "Reloading D-Bus configuration..."
systemctl reload dbus 2>/dev/null || systemctl restart dbus
log_info "✓ D-Bus reloaded"

# Restart bluealsa services
log_info "Starting bluealsa services..."
systemctl start bluealsa
sleep 2
systemctl start bluealsa-aplay

# Check service status
echo ""
log_info "Checking service status..."
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
log_info "BlueALSA should now be running properly."
