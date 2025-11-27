// RPI Bluetooth Audio Receiver - Frontend JavaScript

const API_BASE = '';
let currentStatus = null;
let isDiscoverable = false;
let refreshInterval = null;

// DOM Elements
const toggleDiscoverableBtn = document.getElementById('toggle-discoverable');
const refreshBtn = document.getElementById('refresh-btn');
const volumeSlider = document.getElementById('volume-slider');
const volumeValue = document.getElementById('volume-value');
const devicesList = document.getElementById('devices-list');

// USB Player Elements
const usbStatusValue = document.getElementById('usb-status-value');
const usbTrackName = document.getElementById('usb-track-name');
const usbTrackNumber = document.getElementById('usb-track-number');
const usbPlayBtn = document.getElementById('usb-play-btn');
const usbStopBtn = document.getElementById('usb-stop-btn');
const usbNextBtn = document.getElementById('usb-next-btn');
const usbPrevBtn = document.getElementById('usb-prev-btn');
const usbControls = document.getElementById('usb-controls');
const usbCurrentTrack = document.getElementById('usb-current-track');
const usbTrackInfo = document.getElementById('usb-track-info');
const usbPlayGroup = document.getElementById('usb-play-group');

// Initialize app
document.addEventListener('DOMContentLoaded', () => {
    console.log('Bluetooth Audio Receiver initialized');

    // Initial data load
    loadStatus();
    loadDevices();
    loadUSBStatus();

    // Set up event listeners
    setupEventListeners();

    // Auto-refresh every 5 seconds
    refreshInterval = setInterval(() => {
        loadStatus();
        loadDevices();
        loadUSBStatus();
    }, 5000);
});

// Event Listeners
function setupEventListeners() {
    toggleDiscoverableBtn.addEventListener('click', toggleDiscoverable);
    refreshBtn.addEventListener('click', () => {
        loadStatus();
        loadDevices();
    });

    // Volume control with debounce
    let volumeTimeout;
    volumeSlider.addEventListener('input', (e) => {
        const value = e.target.value;
        volumeValue.textContent = `${value}%`;

        clearTimeout(volumeTimeout);
        volumeTimeout = setTimeout(() => {
            setVolume(value);
        }, 300);
    });

    // USB Player controls
    usbPlayBtn.addEventListener('click', playUSB);
    usbStopBtn.addEventListener('click', stopUSB);
    usbNextBtn.addEventListener('click', nextUSBTrack);
    usbPrevBtn.addEventListener('click', prevUSBTrack);
}

// API Functions
async function loadStatus() {
    try {
        const response = await fetch(`${API_BASE}/api/status`);
        const data = await response.json();

        if (data.success) {
            currentStatus = data;
            updateStatusUI(data);
        } else {
            console.error('Failed to load status:', data.error);
        }
    } catch (error) {
        console.error('Error loading status:', error);
        showError('Failed to connect to server');
    }
}

async function loadDevices() {
    try {
        const response = await fetch(`${API_BASE}/api/devices`);
        const data = await response.json();

        if (data.success) {
            updateDevicesUI(data.devices);
        } else {
            console.error('Failed to load devices:', data.error);
        }
    } catch (error) {
        console.error('Error loading devices:', error);
    }
}

async function toggleDiscoverable() {
    const newState = !isDiscoverable;

    try {
        toggleDiscoverableBtn.disabled = true;
        toggleDiscoverableBtn.textContent = 'Please wait...';

        const response = await fetch(`${API_BASE}/api/discoverable`, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json'
            },
            body: JSON.stringify({
                discoverable: newState,
                timeout: 300  // 5 minutes
            })
        });

        const data = await response.json();

        if (data.success) {
            isDiscoverable = newState;
            updateDiscoverableButton();

            // Refresh status
            setTimeout(() => loadStatus(), 500);

            if (newState) {
                showSuccess('Device is now discoverable for 5 minutes');
            }
        } else {
            showError('Failed to change discoverable mode');
        }
    } catch (error) {
        console.error('Error toggling discoverable:', error);
        showError('Network error');
    } finally {
        toggleDiscoverableBtn.disabled = false;
    }
}

async function removeDevice(address, name) {
    if (!confirm(`Remove device "${name}"?`)) {
        return;
    }

    try {
        const response = await fetch(`${API_BASE}/api/device/${address}`, {
            method: 'DELETE'
        });

        const data = await response.json();

        if (data.success) {
            showSuccess(`Device "${name}" removed`);
            loadDevices();
        } else {
            showError('Failed to remove device');
        }
    } catch (error) {
        console.error('Error removing device:', error);
        showError('Network error');
    }
}

async function setVolume(level) {
    try {
        const response = await fetch(`${API_BASE}/api/volume`, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json'
            },
            body: JSON.stringify({ level: parseInt(level) })
        });

        const data = await response.json();

        if (!data.success) {
            console.error('Failed to set volume:', data.error);
        }
    } catch (error) {
        console.error('Error setting volume:', error);
    }
}

// UI Update Functions
function updateStatusUI(data) {
    // Adapter status
    const adapterStatus = document.getElementById('adapter-status');
    if (data.adapter.powered) {
        adapterStatus.textContent = `${data.adapter.name} (${data.adapter.address})`;
        adapterStatus.className = 'status-value connected';
    } else {
        adapterStatus.textContent = 'Offline';
        adapterStatus.className = 'status-value disconnected';
    }

    // Discoverable status
    const discoverableStatus = document.getElementById('discoverable-status');
    isDiscoverable = data.adapter.discoverable;
    discoverableStatus.textContent = isDiscoverable ? 'Yes' : 'No';
    discoverableStatus.className = isDiscoverable ? 'status-value connected' : 'status-value';
    updateDiscoverableButton();

    // Connected device
    const connectedDevice = document.getElementById('connected-device');
    if (data.connected_device) {
        connectedDevice.textContent = data.connected_device.name;
        connectedDevice.className = 'status-value connected';
    } else {
        connectedDevice.textContent = 'None';
        connectedDevice.className = 'status-value disconnected';
    }

    // IP address
    const ipAddress = document.getElementById('ip-address');
    ipAddress.textContent = data.system.ip_address;

    // Volume
    if (data.volume !== undefined) {
        volumeSlider.value = data.volume;
        volumeValue.textContent = `${data.volume}%`;
    }
}

function updateDiscoverableButton() {
    if (isDiscoverable) {
        toggleDiscoverableBtn.textContent = 'Stop Discoverable';
        toggleDiscoverableBtn.className = 'btn btn-success';
    } else {
        toggleDiscoverableBtn.textContent = 'Make Discoverable';
        toggleDiscoverableBtn.className = 'btn btn-primary';
    }
}

function updateDevicesUI(devices) {
    if (!devices || devices.length === 0) {
        devicesList.innerHTML = '<p class="empty-state">No paired devices</p>';
        return;
    }

    devicesList.innerHTML = devices.map(device => `
        <div class="device-item ${device.connected ? 'connected' : ''}">
            <div class="device-info">
                <div class="device-name">${escapeHtml(device.name)}</div>
                <div class="device-address">${escapeHtml(device.address)}</div>
                <span class="device-status ${device.connected ? 'connected' : 'paired'}">
                    ${device.connected ? 'Connected' : 'Paired'}
                </span>
            </div>
            <div class="device-actions">
                <button class="btn btn-danger" onclick="removeDevice('${device.address}', '${escapeHtml(device.name)}')">
                    Remove
                </button>
            </div>
        </div>
    `).join('');
}

// Utility Functions
function escapeHtml(text) {
    const div = document.createElement('div');
    div.textContent = text;
    return div.innerHTML;
}

function showSuccess(message) {
    // Simple alert for now - could be replaced with toast notifications
    console.log('Success:', message);
}

function showError(message) {
    console.error('Error:', message);
    alert(`Error: ${message}`);
}

// USB Player Functions
async function loadUSBStatus() {
    try {
        const response = await fetch(`${API_BASE}/api/usb/status`);
        const data = await response.json();

        if (data.success) {
            updateUSBUI(data);
        }
    } catch (error) {
        console.error('Error loading USB status:', error);
    }
}

function updateUSBUI(data) {
    // Update USB status
    if (data.usb_mounted) {
        usbStatusValue.textContent = 'USB Detected';
        usbStatusValue.className = 'status-value connected';
        usbPlayBtn.disabled = !data.is_playing;
    } else {
        usbStatusValue.textContent = 'Not Detected';
        usbStatusValue.className = 'status-value disconnected';
        usbPlayBtn.disabled = true;
    }

    // Update playback info
    if (data.is_playing) {
        usbCurrentTrack.style.display = 'block';
        usbTrackInfo.style.display = 'block';
        usbControls.style.display = 'flex';
        usbPlayGroup.style.display = 'none';

        usbTrackName.textContent = data.current_file || 'Unknown';
        usbTrackNumber.textContent = `${data.current_index + 1} / ${data.total_tracks}`;
    } else {
        usbCurrentTrack.style.display = 'none';
        usbTrackInfo.style.display = 'none';
        usbControls.style.display = 'none';
        usbPlayGroup.style.display = 'block';
    }
}

async function playUSB() {
    try {
        const response = await fetch(`${API_BASE}/api/usb/play`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' }
        });
        const data = await response.json();

        if (data.success) {
            showSuccess('USB playback started');
            loadUSBStatus();
        } else {
            showError(data.error || 'Failed to start USB playback');
        }
    } catch (error) {
        showError('Error starting USB playback: ' + error.message);
    }
}

async function stopUSB() {
    try {
        const response = await fetch(`${API_BASE}/api/usb/stop`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' }
        });
        const data = await response.json();

        if (data.success) {
            showSuccess('USB playback stopped');
            loadUSBStatus();
        } else {
            showError(data.error || 'Failed to stop USB playback');
        }
    } catch (error) {
        showError('Error stopping USB playback: ' + error.message);
    }
}

async function nextUSBTrack() {
    try {
        const response = await fetch(`${API_BASE}/api/usb/next`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' }
        });
        const data = await response.json();

        if (data.success) {
            loadUSBStatus();
        } else {
            showError(data.error || 'Failed to skip track');
        }
    } catch (error) {
        showError('Error skipping track: ' + error.message);
    }
}

async function prevUSBTrack() {
    try {
        const response = await fetch(`${API_BASE}/api/usb/previous`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' }
        });
        const data = await response.json();

        if (data.success) {
            loadUSBStatus();
        } else {
            showError(data.error || 'Failed to go to previous track');
        }
    } catch (error) {
        showError('Error going to previous track: ' + error.message);
    }
}

// Cleanup on page unload
window.addEventListener('beforeunload', () => {
    if (refreshInterval) {
        clearInterval(refreshInterval);
    }
});
