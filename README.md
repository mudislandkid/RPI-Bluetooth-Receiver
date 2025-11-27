# Raspberry Pi Bluetooth Audio Receiver

Transform your Raspberry Pi 4B into a headless Bluetooth audio receiver with a web-based management interface. Stream music from iOS and Android devices to your speakers via the 3.5mm audio jack.

## Features

- **Bluetooth A2DP Audio Sink**: Accept high-quality audio streams from mobile devices
- **WiFi Access Point**: Headless management via WiFi hotspot
- **Web Interface**: User-friendly control panel accessible from any browser
- **Auto-Pairing**: Automatic device pairing with no PIN required
- **Auto-Reconnect**: Previously paired devices reconnect automatically
- **Volume Control**: Adjust volume from the web interface
- **Device Management**: View, remove, and manage paired devices
- **Boot-Ready**: All services start automatically on boot

## Hardware Requirements

- Raspberry Pi 4B (2GB+ RAM recommended)
- MicroSD card (16GB minimum, 32GB recommended)
- Power supply (5V 3A USB-C)
- 3.5mm audio cable
- Powered speakers or amplifier

## Quick Start

### 1. Prepare Raspberry Pi

1. Install Raspberry Pi OS Lite (64-bit) on your microSD card
2. Enable SSH (create empty file named `ssh` in boot partition)
3. Boot the Raspberry Pi and connect via SSH

### 2. Clone Repository

```bash
cd ~
git clone https://github.com/yourusername/rpi-bluetooth.git
cd rpi-bluetooth
```

### 3. Run Installation

```bash
sudo ./scripts/install.sh
```

The installation will:
- Update system packages
- Install required dependencies (BlueZ, BlueALSA, hostapd, dnsmasq)
- Configure Bluetooth and audio
- Set up WiFi access point
- Install web interface
- Configure systemd services

### 4. Set WiFi Password

**IMPORTANT**: Change the default WiFi password before first use!

```bash
sudo ./scripts/set-wifi-password.sh
```

Or manually edit `/etc/hostapd/hostapd.conf`:

```bash
sudo nano /etc/hostapd/hostapd.conf
# Change line: wpa_passphrase=YourNewPassword
```

### 5. Reboot

```bash
sudo reboot
```

## Usage

### Connecting to the Web Interface

1. Wait 30-60 seconds after boot for all services to start
2. On your phone/tablet, connect to WiFi network: **RPI-Bluetooth-Audio**
3. Enter the WiFi password you configured
4. Open browser and navigate to: **http://192.168.4.1**

### Pairing a Device

1. Open the web interface at http://192.168.4.1
2. Click **"Make Discoverable"** button
3. On your phone/tablet:
   - Go to Settings → Bluetooth
   - Search for devices
   - Select "RPI-Bluetooth-Audio"
   - Connect (no PIN required)
4. The device will appear in the "Paired Devices" list
5. Start playing music!

### Daily Use

Once paired, your device will automatically reconnect when in range. Simply:
1. Turn on Bluetooth on your phone/tablet
2. Start playing music
3. Audio plays through the Raspberry Pi's 3.5mm jack

## Project Structure

```
rpi-bluetooth/
├── config/                      # System configuration files
│   ├── hostapd.conf            # WiFi AP configuration
│   ├── dnsmasq.conf            # DHCP/DNS configuration
│   ├── dhcpcd.conf.append      # Static IP configuration
│   ├── bluetooth-main.conf     # Bluetooth configuration
│   └── asound.conf             # ALSA audio configuration
├── services/                    # Systemd service files
│   ├── bluealsa.service        # BlueALSA service
│   ├── bluealsa-aplay.service  # Audio playback service
│   ├── bluetooth-agent.service # Auto-pairing agent
│   └── bluetooth-web.service   # Web interface service
├── web/                         # Web application
│   ├── app.py                  # Flask application
│   ├── bluetooth_manager.py    # D-Bus Bluetooth interface
│   ├── bt_agent.py             # Bluetooth pairing agent
│   ├── requirements.txt        # Python dependencies
│   ├── static/
│   │   ├── css/style.css       # Styles
│   │   └── js/app.js           # Frontend JavaScript
│   └── templates/
│       └── index.html          # Web interface HTML
├── scripts/                     # Installation and utility scripts
│   ├── install.sh              # Main installation script
│   ├── set-wifi-password.sh    # WiFi password configuration
│   └── status.sh               # System status checker
├── prd.md                       # Product Requirements Document
└── README.md                    # This file
```

## Management Commands

### Check System Status

```bash
sudo ./scripts/status.sh
```

Shows the status of all services, network interfaces, and connected devices.

### Restart Services

```bash
sudo systemctl restart bluetooth
sudo systemctl restart bluealsa
sudo systemctl restart bluealsa-aplay
sudo systemctl restart bluetooth-web
sudo systemctl restart hostapd
```

### View Logs

```bash
# Bluetooth logs
journalctl -u bluetooth -f

# BlueALSA logs
journalctl -u bluealsa -f

# Web interface logs
journalctl -u bluetooth-web -f

# WiFi AP logs
journalctl -u hostapd -f
```

### Manage Bluetooth Devices

```bash
# List paired devices
bluetoothctl devices

# Remove a device
bluetoothctl remove [MAC_ADDRESS]

# Make discoverable manually
bluetoothctl discoverable on
```

## Configuration

### WiFi Access Point

Edit `/etc/hostapd/hostapd.conf`:

```ini
ssid=RPI-Bluetooth-Audio          # Change WiFi network name
wpa_passphrase=YourPassword       # Change WiFi password
channel=6                         # Change WiFi channel if needed
country_code=US                   # Change to your country code
```

After changes:
```bash
sudo systemctl restart hostapd
```

### Bluetooth Device Name

Edit `/etc/bluetooth/main.conf`:

```ini
Name = RPI-Bluetooth-Audio        # Change Bluetooth device name
```

After changes:
```bash
sudo systemctl restart bluetooth
```

### Audio Output

Force 3.5mm jack output:
```bash
sudo amixer cset numid=3 1
```

Set volume:
```bash
sudo amixer sset PCM 80%
```

### Network Configuration

Edit `/etc/dhcpcd.conf` to change the static IP (default: 192.168.4.1):

```ini
interface wlan0
    static ip_address=192.168.4.1/24
    nohook wpa_supplicant
```

## Troubleshooting

### No Audio Output

1. Check audio routing:
   ```bash
   aplay -l
   ```

2. Set output to 3.5mm jack:
   ```bash
   sudo amixer cset numid=3 1
   ```

3. Check volume level:
   ```bash
   alsamixer
   ```

4. Test audio:
   ```bash
   speaker-test -t wav -c 2
   ```

### Can't Connect to WiFi

1. Check hostapd status:
   ```bash
   sudo systemctl status hostapd
   ```

2. View hostapd logs:
   ```bash
   sudo journalctl -u hostapd -n 50
   ```

3. Restart WiFi services:
   ```bash
   sudo systemctl restart hostapd
   sudo systemctl restart dnsmasq
   ```

### Bluetooth Pairing Fails

1. Check Bluetooth service:
   ```bash
   sudo systemctl status bluetooth
   ```

2. Make adapter discoverable:
   ```bash
   bluetoothctl
   discoverable on
   pairable on
   ```

3. Restart Bluetooth services:
   ```bash
   sudo systemctl restart bluetooth
   sudo systemctl restart bluealsa
   ```

### Web Interface Not Loading

1. Check web service:
   ```bash
   sudo systemctl status bluetooth-web
   ```

2. View logs:
   ```bash
   sudo journalctl -u bluetooth-web -n 50
   ```

3. Restart web service:
   ```bash
   sudo systemctl restart bluetooth-web
   ```

4. Verify network connectivity:
   ```bash
   ip addr show wlan0
   ping 192.168.4.1
   ```

### Services Not Starting on Boot

1. Check if services are enabled:
   ```bash
   sudo systemctl is-enabled bluetooth
   sudo systemctl is-enabled bluealsa
   sudo systemctl is-enabled hostapd
   sudo systemctl is-enabled bluetooth-web
   ```

2. Enable services:
   ```bash
   sudo systemctl enable bluetooth
   sudo systemctl enable bluealsa
   sudo systemctl enable bluealsa-aplay
   sudo systemctl enable hostapd
   sudo systemctl enable dnsmasq
   sudo systemctl enable bluetooth-web
   sudo systemctl enable bluetooth-agent
   ```

## API Reference

The web interface exposes a REST API for programmatic control:

### Get Status
```
GET /api/status
```

Returns system status, adapter info, connected device, and volume.

### Get Devices
```
GET /api/devices
```

Returns list of paired devices.

### Set Discoverable
```
POST /api/discoverable
Content-Type: application/json

{
  "discoverable": true,
  "timeout": 300
}
```

### Remove Device
```
DELETE /api/device/{address}
```

### Get Volume
```
GET /api/volume
```

### Set Volume
```
POST /api/volume
Content-Type: application/json

{
  "level": 75
}
```

## Security Considerations

1. **Change Default WiFi Password**: Always change the default password before deployment
2. **Update Regularly**: Keep system packages updated
3. **Firewall**: Consider enabling ufw and allowing only necessary ports
4. **SSH Keys**: Disable password authentication for SSH
5. **Network Isolation**: The WiFi AP is isolated from your main network

## Performance

- **Audio Latency**: Typically <200ms with BlueALSA
- **Boot Time**: ~30-60 seconds for all services to start
- **Power Consumption**: ~3-5W typical usage
- **Concurrent Connections**: One active audio stream at a time

## Contributing

Contributions are welcome! Please feel free to submit issues and pull requests.

## License

MIT License - See LICENSE file for details

## Acknowledgments

- [BlueZ](http://www.bluez.org/) - Official Linux Bluetooth stack
- [BlueALSA](https://github.com/Arkq/bluez-alsa) - Bluetooth Audio ALSA Backend
- [Flask](https://flask.palletsprojects.com/) - Python web framework
- [hostapd](https://w1.fi/hostapd/) - WiFi Access Point daemon

## Support

For issues and questions:
- Check the [Troubleshooting](#troubleshooting) section
- Review [prd.md](prd.md) for detailed technical information
- Open an issue on GitHub

## Version History

- **v1.0.0** - Initial release
  - Bluetooth A2DP audio reception
  - WiFi access point
  - Web-based management interface
  - Auto-pairing and reconnection
  - Volume control
  - Device management

---

**Made with ❤️ for the Raspberry Pi community**
