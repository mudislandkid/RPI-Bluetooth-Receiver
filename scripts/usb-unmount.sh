#!/bin/bash
#
# USB Auto-unmount script
# Called by udev when USB storage device is removed
#

DEVICE=$1
MOUNT_POINT="/media/usb"

# Force unmount if mounted
if mountpoint -q "$MOUNT_POINT"; then
    umount -f "$MOUNT_POINT" 2>/dev/null || umount -l "$MOUNT_POINT" 2>/dev/null
    logger "USB device $DEVICE unmounted from $MOUNT_POINT"
else
    logger "USB mount point $MOUNT_POINT was not mounted"
fi

exit 0
