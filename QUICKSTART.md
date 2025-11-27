# Quick Start Guide

Get your Raspberry Pi Bluetooth Audio Receiver running in under 10 minutes!

## Prerequisites

- Raspberry Pi 4B with Raspberry Pi OS Lite installed
- SSH access to your Pi
- Internet connection

## Installation Steps

### 1. SSH into Your Raspberry Pi

```bash
ssh pi@raspberrypi.local
```

Default password: `raspberry` (change this after setup!)

### 2. Clone the Repository

```bash
cd ~
git clone https://github.com/yourusername/rpi-bluetooth.git
cd rpi-bluetooth
```

### 3. Run the Installer

```bash
sudo ./scripts/install.sh
```

This will take 5-10 minutes. Grab a coffee! ☕

### 4. Set Your WiFi Password

**IMPORTANT**: Change the default WiFi password!

```bash
sudo ./scripts/set-wifi-password.sh
```

When prompted, enter a strong password (minimum 8 characters).

### 5. Reboot

```bash
sudo reboot
```

## Using Your Bluetooth Receiver

### Connect to Web Interface

1. **Wait 30-60 seconds** after reboot
2. On your phone, connect to WiFi: **RPI-Bluetooth-Audio**
3. Enter the password you set in step 4
4. Open browser: **http://192.168.4.1**

### Pair Your Phone

1. In the web interface, click **"Make Discoverable"**
2. On your phone:
   - Settings → Bluetooth
   - Search for devices
   - Select "RPI-Bluetooth-Audio"
   - Pair (no PIN needed)
3. Done! 🎉

### Play Music

Just start playing music on your phone - it will automatically stream to the Raspberry Pi!

### USB Music Player

Play music directly from a USB drive:

1. **Insert USB drive** with music files (MP3, FLAC, WAV, M4A, OGG, AAC)
2. Wait a few seconds for auto-detection
3. In the web interface:
   - See USB status and track info
   - Click **"Play USB Music"** to start
   - Use **Previous/Next** buttons to navigate
   - Click **"Stop"** to return to Bluetooth mode

**Features:**

- Auto-play when USB inserted (optional)
- Sequential playback with loop
- Automatically pauses Bluetooth audio
- Supports all popular audio formats

**USB Drive Requirements:**

- Supported filesystems: FAT32, exFAT, NTFS, ext4
- Music files in root directory or folders
- Supported formats: MP3, FLAC, WAV, M4A, OGG, AAC, WMA

## Troubleshooting

### Can't see the WiFi network?

```bash
ssh pi@raspberrypi.local
sudo ./scripts/status.sh
```

Check if hostapd is running. If not:
```bash
sudo systemctl restart hostapd
```

### No audio from speakers?

1. Check volume in web interface
2. Make sure speakers are powered on
3. Try testing audio:
   ```bash
   speaker-test -t wav -c 2
   ```

### Web interface not loading?

```bash
sudo systemctl status bluetooth-web
sudo systemctl restart bluetooth-web
```

### USB drive not detected?

1. Check if USB is mounted:
   ```bash
   ls -la /media/usb
   ```

2. Check USB player service:
   ```bash
   sudo systemctl status usb-player
   sudo journalctl -u usb-player -f
   ```

3. Manually mount USB:

   ```bash
   sudo mkdir -p /media/usb
   sudo mount /dev/sda1 /media/usb
   ```

4. Restart USB player service:

   ```bash
   sudo systemctl restart usb-player
   ```

## Next Steps

- Read the full [README.md](README.md) for detailed documentation
- Review [prd.md](prd.md) for technical details
- Customize settings in `/etc/hostapd/hostapd.conf`

## Need Help?

- Run `sudo ./scripts/status.sh` to check system status
- Check logs: `sudo journalctl -u bluetooth-web -f`
- Open an issue on GitHub

---

Enjoy your new Bluetooth audio receiver! 🎵
