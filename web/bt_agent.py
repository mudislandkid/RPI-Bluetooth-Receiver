#!/usr/bin/env python3
"""
Bluetooth Pairing Agent for RPI Bluetooth Audio Receiver
Handles automatic pairing and authorization for incoming Bluetooth connections
"""

import dbus
import dbus.service
import dbus.mainloop.glib
from gi.repository import GLib
import logging

logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger('BTAgent')

SERVICE_NAME = "org.bluez"
AGENT_INTERFACE = "org.bluez.Agent1"
AGENT_PATH = "/org/bluez/AutoPairAgent"


class AutoPairAgent(dbus.service.Object):
    """
    Bluetooth Agent that automatically accepts all pairing requests
    """

    def __init__(self, bus, path):
        super().__init__(bus, path)
        logger.info("Bluetooth Auto-Pair Agent initialized")

    @dbus.service.method(AGENT_INTERFACE, in_signature="", out_signature="")
    def Release(self):
        """Called when agent is unregistered"""
        logger.info("Agent released")

    @dbus.service.method(AGENT_INTERFACE, in_signature="os", out_signature="")
    def AuthorizeService(self, device, uuid):
        """Authorize a service request"""
        logger.info(f"Authorizing service {uuid} for device {device}")
        return

    @dbus.service.method(AGENT_INTERFACE, in_signature="o", out_signature="s")
    def RequestPinCode(self, device):
        """Return a PIN code for pairing (not typically used for A2DP)"""
        logger.info(f"PIN code requested for {device}")
        return "0000"

    @dbus.service.method(AGENT_INTERFACE, in_signature="o", out_signature="u")
    def RequestPasskey(self, device):
        """Return a passkey for pairing (not typically used for A2DP)"""
        logger.info(f"Passkey requested for {device}")
        return dbus.UInt32(0)

    @dbus.service.method(AGENT_INTERFACE, in_signature="ouq", out_signature="")
    def DisplayPasskey(self, device, passkey, entered):
        """Display passkey (not used for auto-pairing)"""
        logger.info(f"Display passkey {passkey} for {device}")

    @dbus.service.method(AGENT_INTERFACE, in_signature="os", out_signature="")
    def DisplayPinCode(self, device, pincode):
        """Display PIN code (not used for auto-pairing)"""
        logger.info(f"Display PIN {pincode} for {device}")

    @dbus.service.method(AGENT_INTERFACE, in_signature="ou", out_signature="")
    def RequestConfirmation(self, device, passkey):
        """Auto-confirm pairing requests"""
        logger.info(f"Auto-confirming pairing for {device} with passkey {passkey}")
        return

    @dbus.service.method(AGENT_INTERFACE, in_signature="o", out_signature="")
    def RequestAuthorization(self, device):
        """Auto-authorize connection requests"""
        logger.info(f"Auto-authorizing {device}")
        return

    @dbus.service.method(AGENT_INTERFACE, in_signature="", out_signature="")
    def Cancel(self):
        """Cancel any outstanding pairing request"""
        logger.info("Pairing cancelled")


def main():
    """Main function to run the Bluetooth agent"""
    dbus.mainloop.glib.DBusGMainLoop(set_as_default=True)

    bus = dbus.SystemBus()

    # Create and register the agent
    agent = AutoPairAgent(bus, AGENT_PATH)

    try:
        obj = bus.get_object(SERVICE_NAME, "/org/bluez")
        manager = dbus.Interface(obj, "org.bluez.AgentManager1")
        manager.RegisterAgent(AGENT_PATH, "NoInputNoOutput")
        manager.RequestDefaultAgent(AGENT_PATH)
        logger.info("Agent registered and set as default")
    except Exception as e:
        logger.error(f"Failed to register agent: {e}")
        return

    # Run the main loop
    try:
        logger.info("Bluetooth Auto-Pair Agent running...")
        mainloop = GLib.MainLoop()
        mainloop.run()
    except KeyboardInterrupt:
        logger.info("Agent stopped by user")
    except Exception as e:
        logger.error(f"Agent error: {e}")
    finally:
        try:
            manager.UnregisterAgent(AGENT_PATH)
            logger.info("Agent unregistered")
        except:
            pass


if __name__ == "__main__":
    main()
