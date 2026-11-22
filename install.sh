#!/bin/sh
# Install gpu-switch system-wide. Run: sudo ~/gpu-switch/install.sh
set -e
[ "$(id -u)" = 0 ] || { echo "run with sudo"; exit 1; }
cd "$(dirname "$0")"

install -Dm755 gpu-switch          /usr/local/bin/gpu-switch
install -Dm644 gpu-switch.service  /etc/systemd/system/gpu-switch.service
install -Dm644 gpu-switch.8        /usr/local/share/man/man8/gpu-switch.8
install -d -m 2775 -o root -g wheel /var/lib/gpu-switch

systemctl daemon-reload
systemctl enable --now gpu-switch.service
mandb -q 2>/dev/null || true

echo "Installed. Try: gpu-switch status   /   man gpu-switch"
