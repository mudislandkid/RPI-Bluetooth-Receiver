#!/bin/bash

###############################################################################
# Check Status of RPI Bluetooth Audio Receiver
###############################################################################

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo ""
echo "RPI Bluetooth Audio Receiver - Status Check"
echo "============================================"
echo ""

# Check Bluetooth service
echo "Bluetooth Service:"
if systemctl is-active --quiet bluetooth; then
    echo -e "  ${GREEN}✓${NC} bluetooth.service is running"
else
    echo -e "  ${RED}✗${NC} bluetooth.service is not running"
fi

# Check BlueALSA service
echo ""
echo "BlueALSA Services:"
if systemctl is-active --quiet bluealsa; then
    echo -e "  ${GREEN}✓${NC} bluealsa.service is running"
else
    echo -e "  ${RED}✗${NC} bluealsa.service is not running"
fi

if systemctl is-active --quiet bluealsa-aplay; then
    echo -e "  ${GREEN}✓${NC} bluealsa-aplay.service is running"
else
    echo -e "  ${RED}✗${NC} bluealsa-aplay.service is not running"
fi

# Check WiFi AP services
echo ""
echo "WiFi Access Point:"
if systemctl is-active --quiet hostapd; then
    echo -e "  ${GREEN}✓${NC} hostapd.service is running"
else
    echo -e "  ${RED}✗${NC} hostapd.service is not running"
fi

if systemctl is-active --quiet dnsmasq; then
    echo -e "  ${GREEN}✓${NC} dnsmasq.service is running"
else
    echo -e "  ${RED}✗${NC} dnsmasq.service is not running"
fi

# Check Web Interface
echo ""
echo "Web Interface:"
if systemctl is-active --quiet bluetooth-web; then
    echo -e "  ${GREEN}✓${NC} bluetooth-web.service is running"
else
    echo -e "  ${RED}✗${NC} bluetooth-web.service is not running"
fi

# Check Bluetooth Agent
echo ""
echo "Bluetooth Agent:"
if systemctl is-active --quiet bluetooth-agent; then
    echo -e "  ${GREEN}✓${NC} bluetooth-agent.service is running"
else
    echo -e "  ${RED}✗${NC} bluetooth-agent.service is not running"
fi

# Check Bluetooth adapter
echo ""
echo "Bluetooth Adapter:"
if hciconfig hci0 > /dev/null 2>&1; then
    hciconfig hci0 | grep -E "BD Address|UP RUNNING"
else
    echo -e "  ${RED}✗${NC} Bluetooth adapter not found"
fi

# Check network interfaces
echo ""
echo "Network Interfaces:"
ip addr show wlan0 2>/dev/null | grep "inet " || echo "  wlan0 not configured"

# Check connected devices
echo ""
echo "Connected Bluetooth Devices:"
connected=$(bluetoothctl devices Connected 2>/dev/null || echo "")
if [ -z "$connected" ]; then
    echo "  None"
else
    echo "$connected"
fi

echo ""
echo "============================================"
echo ""
