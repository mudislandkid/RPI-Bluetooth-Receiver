#!/bin/bash
#
# Update systemd service files and restart services
# Use this script to apply service file changes without full reinstall
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

log_info "Updating systemd service files..."

# Stop services
log_info "Stopping services..."
systemctl stop bluealsa-aplay 2>/dev/null || true
systemctl stop bluealsa 2>/dev/null || true
systemctl stop bluetooth-agent 2>/dev/null || true
systemctl stop bluetooth-web 2>/dev/null || true

# Copy updated service files
log_info "Copying service files..."
cp "$PROJECT_DIR/services/bluealsa.service" /etc/systemd/system/
cp "$PROJECT_DIR/services/bluealsa-aplay.service" /etc/systemd/system/
cp "$PROJECT_DIR/services/bluetooth-agent.service" /etc/systemd/system/
cp "$PROJECT_DIR/services/bluetooth-web.service" /etc/systemd/system/

# Reload systemd daemon
log_info "Reloading systemd daemon..."
systemctl daemon-reload

# Restart services
log_info "Starting services..."
systemctl restart bluetooth
systemctl restart bluealsa
systemctl restart bluealsa-aplay
systemctl restart bluetooth-agent
systemctl restart bluetooth-web

# Check service status
log_info "Checking service status..."
echo ""
echo "Service Status:"
echo "---------------"
systemctl is-active --quiet bluealsa && echo -e "${GREEN}✓${NC} bluealsa: running" || echo -e "${RED}✗${NC} bluealsa: failed"
systemctl is-active --quiet bluealsa-aplay && echo -e "${GREEN}✓${NC} bluealsa-aplay: running" || echo -e "${RED}✗${NC} bluealsa-aplay: failed"
systemctl is-active --quiet bluetooth-agent && echo -e "${GREEN}✓${NC} bluetooth-agent: running" || echo -e "${RED}✗${NC} bluetooth-agent: failed"
systemctl is-active --quiet bluetooth-web && echo -e "${GREEN}✓${NC} bluetooth-web: running" || echo -e "${RED}✗${NC} bluetooth-web: failed"

echo ""
log_info "Service files updated and services restarted"
log_info "If any services failed, check logs with: sudo journalctl -u <service-name> -n 50"
