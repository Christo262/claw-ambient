#!/bin/bash
# OPTIONAL: build hid-msi with the quiet-ACK patch and install it for the CURRENT kernel only.
#
# Without it, the stock driver logs "Got unexpected ACK from MCU, ignoring" for every colour
# claw-ambient sends (harmless, but up to ~30 lines/s while gaming). This build only turns
# that message into a debug message; nothing else changes.
#
# After a kernel update the stock driver is used again automatically (the log messages
# return, nothing breaks). Re-run this script to rebuild for the new kernel, as long as
# driver/hid-msi.c still matches your kernel's driver.
#
# Needs: kernel headers for your running kernel, and the compiler your kernel was built with.
set -euo pipefail
cd "$(dirname "$(readlink -f "$0")")"
KVER=$(uname -r)

if [[ ! -d "/usr/lib/modules/$KVER/build" ]]; then
    echo "Kernel headers for $KVER not found (on CachyOS: sudo pacman -S $(pacman -Qqo /usr/lib/modules/$KVER/vmlinuz 2>/dev/null || echo linux)-headers)" >&2
    exit 1
fi

echo "==> Building hid-msi for $KVER"
command make -C "/usr/lib/modules/$KVER/build" M="$PWD" modules

echo "==> Installing to /usr/lib/modules/$KVER/updates/ (overrides the stock driver for this kernel)"
sudo install -Dm644 hid-msi.ko "/usr/lib/modules/$KVER/updates/hid-msi.ko"
sudo depmod -a "$KVER"

echo "==> Reloading driver (controller disconnects for a second)"
sudo modprobe -r hid_msi
sudo modprobe hid_msi

# The initramfs usually bundles hid-msi (via the keyboard hook) and loads it before the
# root filesystem, so it must be rebuilt or the stock driver keeps winning at boot.
echo "==> Rebuilding initramfs so the patched driver is used at boot"
./rebuild-initramfs.sh

echo "==> Loaded from: $(modinfo -n hid_msi)"
echo "Done."
