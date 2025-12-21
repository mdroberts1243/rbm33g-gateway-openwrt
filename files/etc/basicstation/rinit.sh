#!/bin/sh
# Basic Station radio init hook.
# For USB CoreCell, the concentrator MCU handles reset sequencing.
# Keep this script minimal and deterministic.

DEV="/dev/ttyACM0"

# Wait for device node to exist
i=0
while [ ! -c "$DEV" ] && [ $i -lt 50 ]; do
  i=$((i+1))
  sleep 0.1
done

# Ensure permissions (usually already OK as root)
[ -c "$DEV" ] || exit 1
exit 0
