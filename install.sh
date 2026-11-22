#!/bin/sh
# Install or update gpu-switch system-wide; console-follow is optional.
#   sudo ./install.sh                            gpu-switch; console-follow left as it is
#                                                (so a fresh install doesn't get it)
#   sudo ./install.sh --with-console-follow      gpu-switch + console-follow
#   sudo ./install.sh --without-console-follow   gpu-switch; remove console-follow
set -e
usage() { sed -n '2,6p' "$0" | sed 's/^# \{0,1\}//'; }

cf=keep
for arg in "$@"; do
    case $arg in
        --with-console-follow)    cf=install ;;
        --without-console-follow) cf=remove ;;
        -h|--help) usage; exit 0 ;;
        *) echo "unknown option: $arg"; usage; exit 2 ;;
    esac
done
[ "$(id -u)" = 0 ] || { echo "run with sudo"; exit 1; }
cd "$(dirname "$0")"

CF_BIN=/usr/local/bin/console-follow
CF_RULE=/etc/udev/rules.d/82-console-follow.rules
CF_MAN=/usr/local/share/man/man8/console-follow.8

install -Dm755 gpu-switch         /usr/local/bin/gpu-switch
install -Dm644 gpu-switch.service /etc/systemd/system/gpu-switch.service
install -Dm644 gpu-switch.8       /usr/local/share/man/man8/gpu-switch.8
install -d -m 2775 -o root -g wheel /var/lib/gpu-switch
systemctl daemon-reload
systemctl enable --now gpu-switch.service

# An existing console-follow is updated too, unless it's being removed.
[ "$cf" = keep ] && [ -x "$CF_BIN" ] && cf=install

case $cf in
    install)
        install -Dm755 console-follow          "$CF_BIN"
        install -Dm644 82-console-follow.rules "$CF_RULE"
        install -Dm644 console-follow.8        "$CF_MAN"
        udevadm control --reload
        "$CF_BIN" auto || true    # apply now, without waiting for a hotplug event
        if ! grep -qs 'nvidia_drm.*fbdev=1' /etc/modprobe.d/*.conf; then
            echo "NOTE: console-follow needs 'options nvidia_drm modeset=1 fbdev=1' in /etc/modprobe.d/ (then reboot); see console-follow(8)."
        fi
        ;;
    remove)
        if [ -x "$CF_BIN" ]; then
            # Consoles left on the NVIDIA framebuffer would keep the driver busy
            # (and "gpu-switch off" would fail), so move them home first.
            "$CF_BIN" laptop || true
        fi
        rm -f "$CF_BIN" "$CF_RULE" "$CF_MAN"
        udevadm control --reload
        ;;
esac
mandb -q 2>/dev/null || true

if [ -x "$CF_BIN" ]; then cfstate=installed; else cfstate="not installed"; fi
echo "Installed gpu-switch (console-follow: $cfstate). Try: gpu-switch status / man gpu-switch"
