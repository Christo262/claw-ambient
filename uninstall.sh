#!/bin/bash
# Remove claw-ambient. Your settings in ~/.config/claw-ambient are kept.
set -euo pipefail

systemctl --user disable --now claw-ambient.service 2>/dev/null || true
rm -f "$HOME/.local/bin/claw-ambient" "$HOME/.config/systemd/user/claw-ambient.service"
rm -rf "$HOME/.local/state/claw-ambient"
systemctl --user daemon-reload

if [[ -e /etc/udev/rules.d/70-claw-ambient.rules ]]; then
    echo "Removing udev rule (needs sudo)"
    sudo rm -f /etc/udev/rules.d/70-claw-ambient.rules
    sudo udevadm control --reload-rules
fi

echo "claw-ambient removed. The rings keep their last colour until the controller resets"
echo "(reboot), then return to the effect saved on the controller."
echo "Settings were kept in ~/.config/claw-ambient; delete that folder if you don't want them."
