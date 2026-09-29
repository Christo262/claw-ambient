#!/bin/bash
# claw-ambient installer. Run as your normal user (not with sudo); it asks for
# your password only to install the udev permission rule.
set -euo pipefail
cd "$(dirname "$(readlink -f "$0")")"

RULE=/etc/udev/rules.d/70-claw-ambient.rules

if [[ $EUID -eq 0 ]]; then
    echo "Run this as your normal user, not root. It will ask for sudo when needed." >&2
    exit 1
fi

echo "==> Checking for an MSI Claw with the hid-msi driver"
if ! grep -qsi '0DB0:0000190[1-4]' /sys/class/hidraw/hidraw*/device/uevent; then
    echo "No MSI Claw controller found. This needs an MSI Claw and a kernel with the hid-msi driver" >&2
    echo "(CachyOS kernels have it; mainline Linux is getting it)." >&2
    exit 1
fi

echo "==> Checking dependencies"
missing=()
python3 -c 'import numpy' 2>/dev/null || missing+=(python-numpy)
python3 -c 'import gi; gi.require_version("Gst", "1.0"); from gi.repository import Gst' 2>/dev/null \
    || missing+=(python-gobject gstreamer)
command -v gst-inspect-1.0 >/dev/null && gst-inspect-1.0 pipewiresrc >/dev/null 2>&1 || missing+=(gst-plugin-pipewire)
command -v gst-inspect-1.0 >/dev/null && gst-inspect-1.0 videoscale >/dev/null 2>&1 || missing+=(gst-plugins-base)
command -v pw-dump >/dev/null || missing+=(pipewire)
if ((${#missing[@]})); then
    echo "Missing: ${missing[*]}" >&2
    if command -v pacman >/dev/null; then
        echo "Install with:  sudo pacman -S --needed ${missing[*]}" >&2
    fi
    exit 1
fi

echo "==> Installing udev rule (needs sudo)"
if ! cmp -s 70-claw-ambient.rules "$RULE"; then
    sudo install -Dm644 70-claw-ambient.rules "$RULE"
    sudo udevadm control --reload-rules
    sudo udevadm trigger --subsystem-match=hidraw
else
    echo "    already up to date"
fi

echo "==> Installing claw-ambient to ~/.local/bin"
install -Dm755 claw-ambient "$HOME/.local/bin/claw-ambient"
install -Dm644 claw-ambient.service "$HOME/.config/systemd/user/claw-ambient.service"
if [[ ! -e "$HOME/.config/claw-ambient/config" ]]; then
    install -Dm644 config.example "$HOME/.config/claw-ambient/config"
fi

echo "==> Enabling the service"
systemctl --user daemon-reload
systemctl --user enable claw-ambient.service
systemctl --user restart claw-ambient.service

cat <<'EOF'

Done! The joystick rings should now follow your screen colours.
 - On the desktop you may get a one-time "share your screen" prompt: pick your screen and allow it.
 - Settings:  ~/.config/claw-ambient/config  (then: systemctl --user restart claw-ambient)
 - Logs:      journalctl --user -u claw-ambient -f
EOF
