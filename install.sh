#!/bin/sh
# Install gpu-switch and console-follow system-wide. Run: sudo ./install.sh
set -e
[ "$(id -u)" = 0 ] || { echo "run with sudo"; exit 1; }
cd "$(dirname "$0")"

install -Dm755 gpu-switch              /usr/local/bin/gpu-switch
install -Dm755 console-follow          /usr/local/bin/console-follow
install -Dm644 gpu-switch.service      /etc/systemd/system/gpu-switch.service
install -Dm644 82-console-follow.rules /etc/udev/rules.d/82-console-follow.rules
install -Dm644 gpu-switch.8            /usr/local/share/man/man8/gpu-switch.8
install -Dm644 console-follow.8        /usr/local/share/man/man8/console-follow.8
install -d -m 2775 -o root -g wheel /var/lib/gpu-switch

systemctl daemon-reload
systemctl enable --now gpu-switch.service
udevadm control --reload
mandb -q 2>/dev/null || true

if grep -qs 'fbdev=0' /etc/modprobe.d/*.conf; then
    echo "NOTE: nvidia_drm fbdev=0 is set; console-follow needs fbdev=1 (see console-follow(8))."
fi
echo "Installed. Try: gpu-switch status  /  man gpu-switch  /  man console-follow"
