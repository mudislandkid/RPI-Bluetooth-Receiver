#!/bin/bash
#
# USB Auto-mount script
# Called by udev when USB storage device is inserted
#

DEVICE=$1
MOUNT_POINT="/media/usb"

# Create mount point if it doesn't exist
mkdir -p "$MOUNT_POINT"

# Check if already mounted and unmount if stale
if mountpoint -q "$MOUNT_POINT"; then
    logger "USB mount point busy, unmounting stale mount"
    umount -f "$MOUNT_POINT" 2>/dev/null || true
    sleep 1
fi

# Wait a bit for device to settle
sleep 2

# Mount the device
if mount "/dev/$DEVICE" "$MOUNT_POINT" -o rw,uid=1000,gid=1000 2>/dev/null; then
    logger "USB device $DEVICE mounted at $MOUNT_POINT"
    exit 0
else
    logger "Failed to mount USB device $DEVICE"
    exit 1
fi
