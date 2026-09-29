#!/bin/bash
# Rebuild the initramfs with whatever initramfs tool this distro uses.
set -euo pipefail

if command -v limine-mkinitcpio >/dev/null; then
    sudo limine-mkinitcpio          # CachyOS/Arch with Limine: also updates boot entries
elif command -v mkinitcpio >/dev/null; then
    sudo mkinitcpio -P
elif command -v dracut >/dev/null; then
    sudo dracut --regenerate-all --force
elif command -v update-initramfs >/dev/null; then
    sudo update-initramfs -u -k all
else
    echo "Couldn't find an initramfs tool. Rebuild your initramfs manually, or the stock" >&2
    echo "hid-msi may still be loaded at boot." >&2
fi
