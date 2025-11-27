#!/usr/bin/env python3
"""
Bluetooth Manager for RPI Bluetooth Audio Receiver
Provides D-Bus interface to control BlueZ Bluetooth stack
"""

import dbus
import logging
from typing import List, Dict, Optional

logger = logging.getLogger('BluetoothManager')

SERVICE_NAME = "org.bluez"
ADAPTER_INTERFACE = "org.bluez.Adapter1"
DEVICE_INTERFACE = "org.bluez.Device1"
PROPERTIES_INTERFACE = "org.freedesktop.DBus.Properties"


class BluetoothManager:
    """Manage Bluetooth adapter and devices via D-Bus"""

    def __init__(self, adapter_name: str = "hci0"):
        """Initialize Bluetooth manager with specified adapter"""
        self.adapter_name = adapter_name
        self.adapter_path = f"/org/bluez/{adapter_name}"
        self.bus = dbus.SystemBus()

    def _get_adapter(self):
        """Get the Bluetooth adapter object"""
        try:
            adapter_obj = self.bus.get_object(SERVICE_NAME, self.adapter_path)
            return dbus.Interface(adapter_obj, ADAPTER_INTERFACE)
        except dbus.exceptions.DBusException as e:
            logger.error(f"Failed to get adapter: {e}")
            return None

    def _get_adapter_properties(self):
        """Get adapter properties"""
        try:
            adapter_obj = self.bus.get_object(SERVICE_NAME, self.adapter_path)
            props = dbus.Interface(adapter_obj, PROPERTIES_INTERFACE)
            return props.GetAll(ADAPTER_INTERFACE)
        except dbus.exceptions.DBusException as e:
            logger.error(f"Failed to get adapter properties: {e}")
            return {}

    def get_adapter_info(self) -> Dict:
        """Get Bluetooth adapter information"""
        props = self._get_adapter_properties()
        return {
            'name': str(props.get('Name', 'Unknown')),
            'address': str(props.get('Address', 'Unknown')),
            'powered': bool(props.get('Powered', False)),
            'discoverable': bool(props.get('Discoverable', False)),
            'pairable': bool(props.get('Pairable', False)),
            'discovering': bool(props.get('Discovering', False))
        }

    def set_discoverable(self, discoverable: bool, timeout: int = 0) -> bool:
        """
        Set adapter discoverable mode

        Args:
            discoverable: True to make discoverable, False to hide
            timeout: Discoverable timeout in seconds (0 = indefinite)

        Returns:
            True if successful, False otherwise
        """
        try:
            adapter_obj = self.bus.get_object(SERVICE_NAME, self.adapter_path)
            props = dbus.Interface(adapter_obj, PROPERTIES_INTERFACE)

            props.Set(ADAPTER_INTERFACE, "Discoverable", dbus.Boolean(discoverable))
            props.Set(ADAPTER_INTERFACE, "DiscoverableTimeout", dbus.UInt32(timeout))

            logger.info(f"Discoverable mode set to {discoverable}")
            return True
        except dbus.exceptions.DBusException as e:
            logger.error(f"Failed to set discoverable: {e}")
            return False

    def set_pairable(self, pairable: bool) -> bool:
        """Set adapter pairable mode"""
        try:
            adapter_obj = self.bus.get_object(SERVICE_NAME, self.adapter_path)
            props = dbus.Interface(adapter_obj, PROPERTIES_INTERFACE)
            props.Set(ADAPTER_INTERFACE, "Pairable", dbus.Boolean(pairable))
            logger.info(f"Pairable mode set to {pairable}")
            return True
        except dbus.exceptions.DBusException as e:
            logger.error(f"Failed to set pairable: {e}")
            return False

    def get_devices(self) -> List[Dict]:
        """Get list of paired and connected devices"""
        devices = []

        try:
            manager_obj = self.bus.get_object(SERVICE_NAME, "/")
            manager = dbus.Interface(manager_obj, "org.freedesktop.DBus.ObjectManager")
            objects = manager.GetManagedObjects()

            for path, interfaces in objects.items():
                if DEVICE_INTERFACE in interfaces:
                    device_props = interfaces[DEVICE_INTERFACE]

                    # Only include devices for our adapter
                    if str(path).startswith(self.adapter_path):
                        devices.append({
                            'path': str(path),
                            'address': str(device_props.get('Address', 'Unknown')),
                            'name': str(device_props.get('Name', 'Unknown')),
                            'alias': str(device_props.get('Alias', 'Unknown')),
                            'paired': bool(device_props.get('Paired', False)),
                            'connected': bool(device_props.get('Connected', False)),
                            'trusted': bool(device_props.get('Trusted', False))
                        })

            logger.info(f"Found {len(devices)} devices")
            return devices

        except dbus.exceptions.DBusException as e:
            logger.error(f"Failed to get devices: {e}")
            return []

    def remove_device(self, device_address: str) -> bool:
        """
        Remove (unpair) a device

        Args:
            device_address: Bluetooth MAC address of device to remove

        Returns:
            True if successful, False otherwise
        """
        try:
            # Convert address to object path
            device_path = f"{self.adapter_path}/dev_{device_address.replace(':', '_')}"

            adapter = self._get_adapter()
            if adapter:
                adapter.RemoveDevice(device_path)
                logger.info(f"Removed device {device_address}")
                return True
            return False

        except dbus.exceptions.DBusException as e:
            logger.error(f"Failed to remove device {device_address}: {e}")
            return False

    def trust_device(self, device_address: str) -> bool:
        """
        Trust a device for automatic reconnection

        Args:
            device_address: Bluetooth MAC address of device

        Returns:
            True if successful, False otherwise
        """
        try:
            device_path = f"{self.adapter_path}/dev_{device_address.replace(':', '_')}"
            device_obj = self.bus.get_object(SERVICE_NAME, device_path)
            props = dbus.Interface(device_obj, PROPERTIES_INTERFACE)
            props.Set(DEVICE_INTERFACE, "Trusted", dbus.Boolean(True))
            logger.info(f"Trusted device {device_address}")
            return True

        except dbus.exceptions.DBusException as e:
            logger.error(f"Failed to trust device {device_address}: {e}")
            return False

    def get_connected_device(self) -> Optional[Dict]:
        """Get currently connected device (if any)"""
        devices = self.get_devices()
        for device in devices:
            if device['connected']:
                return device
        return None

    def start_discovery(self) -> bool:
        """Start device discovery"""
        try:
            adapter = self._get_adapter()
            if adapter:
                adapter.StartDiscovery()
                logger.info("Started discovery")
                return True
            return False
        except dbus.exceptions.DBusException as e:
            logger.error(f"Failed to start discovery: {e}")
            return False

    def stop_discovery(self) -> bool:
        """Stop device discovery"""
        try:
            adapter = self._get_adapter()
            if adapter:
                adapter.StopDiscovery()
                logger.info("Stopped discovery")
                return True
            return False
        except dbus.exceptions.DBusException as e:
            logger.error(f"Failed to stop discovery: {e}")
            return False


# Example usage and testing
if __name__ == "__main__":
    logging.basicConfig(level=logging.INFO)

    manager = BluetoothManager()

    print("Adapter Info:")
    print(manager.get_adapter_info())

    print("\nDevices:")
    for device in manager.get_devices():
        print(f"  - {device['name']} ({device['address']}) - Connected: {device['connected']}")
