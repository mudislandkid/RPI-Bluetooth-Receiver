#!/bin/bash
#
# USB Auto-mount script
# Called by udev when USB storage device is inserted
#

DEVICE=$1
MOUNT_POINT="/media/usb"

# Create mount point if it doesn't exist
mkdir -p "$MOUNT_POINT"

# Mount the device
mount "/dev/$DEVICE" "$MOUNT_POINT" -o rw,uid=1000,gid=1000

# Log the mount
logger "USB device $DEVICE mounted at $MOUNT_POINT"

exit 0
