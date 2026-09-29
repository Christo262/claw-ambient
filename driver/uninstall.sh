#!/bin/bash
# Remove the patched hid-msi and go back to your kernel's stock driver.
set -euo pipefail
KVER=$(uname -r)

sudo rm -f "/usr/lib/modules/$KVER/updates/hid-msi.ko"
sudo depmod -a "$KVER"
sudo modprobe -r hid_msi
sudo modprobe hid_msi
echo "Stock driver restored: $(modinfo -n hid_msi)"
