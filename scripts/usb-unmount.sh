#!/bin/bash
#
# USB Auto-unmount script
# Called by udev when USB storage device is removed
#

DEVICE=$1
MOUNT_POINT="/media/usb"

# Unmount the device
umount "$MOUNT_POINT" 2>/dev/null

# Log the unmount
logger "USB device $DEVICE unmounted from $MOUNT_POINT"

exit 0
