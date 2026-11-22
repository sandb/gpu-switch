#!/bin/sh
# Install or update gpu-switch and console-follow system-wide.
#   sudo ./install.sh                        install/update; automatic console
#                                            following left as it is (off on a new install)
#   sudo ./install.sh --with-auto-follow     also: consoles follow an external display
#   sudo ./install.sh --without-auto-follow  also: stop following (consoles back home)
set -e
usage() { sed -n '2,6p' "$0" | sed 's/^# \{0,1\}//'; }

follow=keep
for arg in "$@"; do
    case $arg in
        --with-auto-follow)    follow=on ;;
        --without-auto-follow) follow=off ;;
        -h|--help) usage; exit 0 ;;
        *) echo "unknown option: $arg"; usage; exit 2 ;;
    esac
done
[ "$(id -u)" = 0 ] || { echo "run with sudo"; exit 1; }
cd "$(dirname "$0")"

RULE=/etc/udev/rules.d/82-console-follow.rules

install -Dm755 gpu-switch         /usr/local/bin/gpu-switch
install -Dm755 console-follow     /usr/local/bin/console-follow
install -Dm644 gpu-switch.service /etc/systemd/system/gpu-switch.service
install -Dm644 gpu-switch.8       /usr/local/share/man/man8/gpu-switch.8
install -Dm644 console-follow.8   /usr/local/share/man/man8/console-follow.8
install -d -m 2775 -o root -g wheel /var/lib/gpu-switch
systemctl daemon-reload
systemctl enable --now gpu-switch.service

# The udev rule is the automatic following; an existing rule is updated too.
[ "$follow" = keep ] && [ -e "$RULE" ] && follow=on
case $follow in
    on)
        install -Dm644 82-console-follow.rules "$RULE"
        udevadm control --reload
        /usr/local/bin/console-follow auto || true   # apply now
        if ! grep -qs 'nvidia_drm.*fbdev=1' /etc/modprobe.d/*.conf; then
            echo "NOTE: for consoles on an NVIDIA GPU, set 'options nvidia_drm modeset=1 fbdev=1' in /etc/modprobe.d/ (then reboot)."
        fi
        ;;
    off)
        rm -f "$RULE"
        udevadm control --reload
        /usr/local/bin/console-follow laptop || true  # consoles back home
        ;;
esac
mandb -q 2>/dev/null || true

if [ -e "$RULE" ]; then state=on; else state=off; fi
echo "Installed gpu-switch and console-follow (automatic following: $state). See: man gpu-switch"
