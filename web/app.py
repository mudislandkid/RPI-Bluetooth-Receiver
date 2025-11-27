#!/usr/bin/env python3
"""
Flask Web Application for RPI Bluetooth Audio Receiver
Provides REST API and web interface for Bluetooth management
"""

from flask import Flask, render_template, jsonify, request
from flask_cors import CORS
import logging
import subprocess
import socket
from bluetooth_manager import BluetoothManager
import usb_player

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger('BluetoothWeb')

# Initialize Flask app
app = Flask(__name__)
CORS(app)

# Initialize Bluetooth manager
bt_manager = BluetoothManager()

# Initialize USB music player
usb_music_player = usb_player.USBMusicPlayer()


# Helper functions
def get_system_info():
    """Get system information"""
    try:
        hostname = socket.gethostname()
        ip_address = get_ip_address()
        return {
            'hostname': hostname,
            'ip_address': ip_address
        }
    except Exception as e:
        logger.error(f"Error getting system info: {e}")
        return {'hostname': 'Unknown', 'ip_address': 'Unknown'}


def get_ip_address():
    """Get wlan0 IP address"""
    try:
        result = subprocess.run(
            ['hostname', '-I'],
            capture_output=True,
            text=True,
            timeout=5
        )
        ips = result.stdout.strip().split()
        # Return the first IP (usually wlan0)
        return ips[0] if ips else '192.168.4.1'
    except Exception as e:
        logger.error(f"Error getting IP: {e}")
        return '192.168.4.1'


def get_bluealsa_control():
    """Get the BlueALSA software volume control name for connected device"""
    try:
        result = subprocess.run(
            ['amixer', 'scontrols'],
            capture_output=True,
            text=True,
            timeout=5
        )
        # Look for BlueALSA A2DP control (e.g., "Simple mixer control 'Device A2DP',0")
        for line in result.stdout.split('\n'):
            if 'A2DP' in line:
                # Extract control name between quotes
                start = line.find("'") + 1
                end = line.find("'", start)
                if start > 0 and end > 0:
                    control_name = line[start:end]
                    logger.debug(f"Found BlueALSA control: {control_name}")
                    return control_name
        return None
    except Exception as e:
        logger.error(f"Error getting BlueALSA control: {e}")
        return None


def get_volume():
    """Get current volume level"""
    # First try to get BlueALSA software volume
    bluealsa_control = get_bluealsa_control()
    if bluealsa_control:
        try:
            result = subprocess.run(
                ['amixer', 'sget', bluealsa_control],
                capture_output=True,
                text=True,
                timeout=5
            )
            if result.returncode == 0:
                # Parse volume from amixer output
                for line in result.stdout.split('\n'):
                    if 'Playback' in line and '%' in line:
                        # Extract percentage
                        start = line.find('[') + 1
                        end = line.find('%]')
                        if start > 0 and end > 0:
                            volume = int(line[start:end])
                            logger.info(f"Got volume {volume}% from BlueALSA: {bluealsa_control}")
                            return volume
        except Exception as e:
            logger.debug(f"Could not get volume from BlueALSA control: {e}")

    # Use hardware PCM control on card 0 (Headphones/3.5mm jack)
    try:
        result = subprocess.run(
            ['amixer', '-c', '0', 'sget', 'PCM'],
            capture_output=True,
            text=True,
            timeout=5
        )
        if result.returncode == 0:
            # Parse volume from amixer output
            for line in result.stdout.split('\n'):
                if 'Playback' in line and '%' in line:
                    # Extract percentage
                    start = line.find('[') + 1
                    end = line.find('%]')
                    if start > 0 and end > 0:
                        volume = int(line[start:end])
                        logger.info(f"Got volume {volume}% from card 0 PCM")
                        return volume
    except Exception as e:
        logger.error(f"Could not get volume from card 0 PCM: {e}")

    logger.warning("Could not get volume from any mixer control")
    return 50  # Default


def set_volume(level):
    """Set volume level (0-100)"""
    # First try BlueALSA software volume
    bluealsa_control = get_bluealsa_control()
    if bluealsa_control:
        try:
            result = subprocess.run(
                ['amixer', 'sset', bluealsa_control, f'{level}%'],
                capture_output=True,
                text=True,
                timeout=5
            )
            if result.returncode == 0:
                logger.info(f"Set volume to {level}% on BlueALSA: {bluealsa_control}")
                return True
        except Exception as e:
            logger.debug(f"Could not set volume on BlueALSA control: {e}")

    # Use hardware PCM control on card 0 (Headphones/3.5mm jack)
    try:
        result = subprocess.run(
            ['amixer', '-c', '0', 'sset', 'PCM', f'{level}%'],
            capture_output=True,
            text=True,
            timeout=5
        )
        if result.returncode == 0:
            logger.info(f"Set volume to {level}% on card 0 PCM")
            return True
    except Exception as e:
        logger.error(f"Could not set volume on card 0 PCM: {e}")

    return False


# Routes
@app.route('/')
def index():
    """Serve main web interface"""
    return render_template('index.html')


@app.route('/api/status', methods=['GET'])
def get_status():
    """Get system and Bluetooth status"""
    try:
        adapter_info = bt_manager.get_adapter_info()
        connected_device = bt_manager.get_connected_device()
        system_info = get_system_info()
        volume = get_volume()

        return jsonify({
            'success': True,
            'adapter': adapter_info,
            'connected_device': connected_device,
            'system': system_info,
            'volume': volume
        })
    except Exception as e:
        logger.error(f"Error getting status: {e}")
        return jsonify({'success': False, 'error': str(e)}), 500


@app.route('/api/devices', methods=['GET'])
def get_devices():
    """Get list of paired devices"""
    try:
        devices = bt_manager.get_devices()
        return jsonify({
            'success': True,
            'devices': devices
        })
    except Exception as e:
        logger.error(f"Error getting devices: {e}")
        return jsonify({'success': False, 'error': str(e)}), 500


@app.route('/api/discoverable', methods=['POST'])
def set_discoverable():
    """Toggle discoverable mode"""
    try:
        data = request.get_json() or {}
        discoverable = data.get('discoverable', True)
        timeout = data.get('timeout', 0)

        success = bt_manager.set_discoverable(discoverable, timeout)

        if success:
            return jsonify({
                'success': True,
                'discoverable': discoverable,
                'message': f"Discoverable mode {'enabled' if discoverable else 'disabled'}"
            })
        else:
            return jsonify({
                'success': False,
                'error': 'Failed to set discoverable mode'
            }), 500

    except Exception as e:
        logger.error(f"Error setting discoverable: {e}")
        return jsonify({'success': False, 'error': str(e)}), 500


@app.route('/api/device/<address>', methods=['DELETE'])
def remove_device(address):
    """Remove a paired device"""
    try:
        success = bt_manager.remove_device(address)

        if success:
            return jsonify({
                'success': True,
                'message': f'Device {address} removed'
            })
        else:
            return jsonify({
                'success': False,
                'error': 'Failed to remove device'
            }), 500

    except Exception as e:
        logger.error(f"Error removing device: {e}")
        return jsonify({'success': False, 'error': str(e)}), 500


@app.route('/api/device/<address>/trust', methods=['POST'])
def trust_device(address):
    """Trust a device for automatic reconnection"""
    try:
        success = bt_manager.trust_device(address)

        if success:
            return jsonify({
                'success': True,
                'message': f'Device {address} trusted'
            })
        else:
            return jsonify({
                'success': False,
                'error': 'Failed to trust device'
            }), 500

    except Exception as e:
        logger.error(f"Error trusting device: {e}")
        return jsonify({'success': False, 'error': str(e)}), 500


@app.route('/api/volume', methods=['GET'])
def get_volume_api():
    """Get current volume level"""
    try:
        volume = get_volume()
        return jsonify({
            'success': True,
            'volume': volume
        })
    except Exception as e:
        logger.error(f"Error getting volume: {e}")
        return jsonify({'success': False, 'error': str(e)}), 500


@app.route('/api/volume', methods=['POST'])
def set_volume_api():
    """Set volume level"""
    try:
        data = request.get_json() or {}
        level = data.get('level', 50)

        # Validate level
        level = max(0, min(100, int(level)))

        success = set_volume(level)

        if success:
            return jsonify({
                'success': True,
                'volume': level,
                'message': f'Volume set to {level}%'
            })
        else:
            return jsonify({
                'success': False,
                'error': 'Failed to set volume'
            }), 500

    except Exception as e:
        logger.error(f"Error setting volume: {e}")
        return jsonify({'success': False, 'error': str(e)}), 500


@app.route('/api/restart', methods=['POST'])
def restart_services():
    """Restart Bluetooth services"""
    try:
        subprocess.run(['systemctl', 'restart', 'bluetooth'], timeout=10, check=True)
        subprocess.run(['systemctl', 'restart', 'bluealsa'], timeout=10, check=True)

        return jsonify({
            'success': True,
            'message': 'Services restarted'
        })
    except Exception as e:
        logger.error(f"Error restarting services: {e}")
        return jsonify({'success': False, 'error': str(e)}), 500


# Error handlers
###############################################################################
# USB Music Player API Endpoints
###############################################################################

@app.route('/api/usb/status', methods=['GET'])
def usb_status():
    """Get USB player status"""
    try:
        status = usb_music_player.get_status()
        return jsonify({
            'success': True,
            **status
        })
    except Exception as e:
        logger.error(f"Error getting USB status: {e}")
        return jsonify({'success': False, 'error': str(e)}), 500


@app.route('/api/usb/play', methods=['POST'])
def usb_play():
    """Start USB playback"""
    try:
        success = usb_music_player.start_playback()
        if success:
            return jsonify({
                'success': True,
                'message': 'USB playback started'
            })
        else:
            return jsonify({
                'success': False,
                'error': 'No USB drive or music files found'
            })
    except Exception as e:
        logger.error(f"Error starting USB playback: {e}")
        return jsonify({'success': False, 'error': str(e)}), 500


@app.route('/api/usb/stop', methods=['POST'])
def usb_stop():
    """Stop USB playback"""
    try:
        usb_music_player.stop_playback()
        return jsonify({
            'success': True,
            'message': 'USB playback stopped'
        })
    except Exception as e:
        logger.error(f"Error stopping USB playback: {e}")
        return jsonify({'success': False, 'error': str(e)}), 500


@app.route('/api/usb/next', methods=['POST'])
def usb_next():
    """Skip to next track"""
    try:
        success = usb_music_player.next_track()
        if success:
            return jsonify({
                'success': True,
                'message': 'Skipped to next track'
            })
        else:
            return jsonify({
                'success': False,
                'error': 'Not currently playing'
            })
    except Exception as e:
        logger.error(f"Error skipping track: {e}")
        return jsonify({'success': False, 'error': str(e)}), 500


@app.route('/api/usb/previous', methods=['POST'])
def usb_previous():
    """Go to previous track"""
    try:
        success = usb_music_player.previous_track()
        if success:
            return jsonify({
                'success': True,
                'message': 'Went to previous track'
            })
        else:
            return jsonify({
                'success': False,
                'error': 'Not currently playing'
            })
    except Exception as e:
        logger.error(f"Error going to previous track: {e}")
        return jsonify({'success': False, 'error': str(e)}), 500


###############################################################################
# Error Handlers
###############################################################################

@app.errorhandler(404)
def not_found(error):
    return jsonify({'success': False, 'error': 'Not found'}), 404


@app.errorhandler(500)
def internal_error(error):
    return jsonify({'success': False, 'error': 'Internal server error'}), 500


if __name__ == '__main__':
    logger.info("Starting Bluetooth Receiver Web Interface...")
    logger.info("Access at http://192.168.4.1 or http://rpi.local")

    # Run Flask app
    app.run(
        host='0.0.0.0',
        port=80,
        debug=False,
        threaded=True
    )
