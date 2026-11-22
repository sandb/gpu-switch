# gpu-switch

Switch the NVIDIA dGPU of an ASUS laptop fully **off or on for the next boot**, safely, through the firmware's `dgpu_disable` setting. Plus **console-follow**, which puts the Linux text consoles (TTY login) on the external display when it's connected to the NVIDIA GPU.

Written for and tested on an **ASUS ROG Zephyrus G14 GA401QM** (2021, Ryzen 9 5900HS + RTX 3060) running Arch Linux with the `nvidia-open` driver. It may work on other ASUS laptops with the same firmware attribute; see [Other laptops](#other-laptops).

## Why

On this laptop the NVIDIA GPU **never powers down by itself**: the driver reports runtime D3 (RTD3) power management as "Not supported" (AMD platform; the firmware lacks the capability). So the usual approaches don't help: the driver's dynamic power management, supergfxctl (deprecated), Cardwire (needs RTD3).

The cost is real. Idle on battery (Quiet profile, full brightness): **13.2 W with the dGPU on, 7.3 W with it off.**

The only way to really switch the dGPU off is the ASUS firmware attribute `dgpu_disable` (what Windows' Armoury Crate calls "Eco mode"). Changing it on a running system is unsafe:
- Cutting power while the NVIDIA driver is in use crashes `nvidia_drm` and can hang the shutdown. This is what happened with `asusctl armoury set dgpu_disable 1`: asusd applied the change at shutdown while the compositor still used the GPU.
- Switching on fails (firmware timeout after ≈ 20 s) while the PCIe bridge in front of the dGPU is in D3cold, which the kernel puts it in while the dGPU is off.

`gpu-switch` therefore only records the **desired** state, and applies it at shutdown, after all user sessions have ended:
- **off:** unload the NVIDIA modules first; if that fails, leave everything as it is and log a warning (the request stays pending);
- **on:** wake the PCIe bridge first, then switch;
- verify the result; one journal line per switch, warnings and errors when something fails.

The NVIDIA GPU drives the USB-C/DisplayPort outputs on this laptop (the laptop panel and HDMI are on the AMD iGPU). So the typical use is: dGPU **on** at the desk with a USB-C dock, **off** on battery.

## Usage

```
gpu-switch                 # status: current state, and the state after the next reboot
gpu-switch off             # dGPU off from the next boot on
gpu-switch on              # dGPU on from the next boot on
gpu-switch toggle --notify # flip it, and show a desktop notification (e.g. bound to a key)
```
Then reboot. No sudo needed for members of group `wheel`. Example Sway binding:
```
bindsym $mod+Shift+g exec gpu-switch toggle --notify
```
What happened at the last shutdown: `journalctl -b -1 -u gpu-switch`.

Full documentation: `man gpu-switch`, `man console-follow`.

## console-follow

The Linux text console can show a console on one framebuffer (GPU) only; it can't mirror across GPUs. On a hybrid laptop whose external outputs are wired to the NVIDIA GPU, the TTY login prompt therefore stays on the laptop screen, even when you only use the external monitor.

`console-follow` fixes that. It's run by udev whenever a framebuffer appears or a display is plugged in or out: with an NVIDIA framebuffer present **and** a display connected to the NVIDIA GPU, it moves all text consoles there; otherwise it moves them back to the laptop screen. Manual control: `console-follow laptop|external|status`; log: `journalctl -t console-follow`.

- **It doesn't need ASUS hardware or gpu-switch.** It works on any laptop where external outputs are on an NVIDIA GPU. It needs python3 and `options nvidia_drm modeset=1 fbdev=1` (without `fbdev=1` there is no NVIDIA framebuffer).
- **Optional.** It's only installed with `./install.sh --with-console-follow`. Without it, the consoles simply stay on the laptop screen, and gpu-switch works the same.
- **Standalone install** (without gpu-switch):
  ```
  sudo install -Dm755 console-follow          /usr/local/bin/console-follow
  sudo install -Dm644 82-console-follow.rules /etc/udev/rules.d/82-console-follow.rules
  sudo install -Dm644 console-follow.8        /usr/local/share/man/man8/console-follow.8
  sudo udevadm control --reload
  ```
- **Together with gpu-switch:** consoles on the NVIDIA framebuffer keep the NVIDIA driver in use, so it couldn't be unloaded. Before switching the dGPU off, `gpu-switch apply` therefore runs `console-follow laptop` and creates `/run/console-follow.hold`, which keeps the consoles on the laptop screen until the next boot. gpu-switch uses console-follow only if it's installed (`CONSOLE_FOLLOW` at the top of the script).
- The disk-unlock prompt and early boot messages always stay on the laptop screen: they come before the NVIDIA driver is loaded.

## Requirements

- Linux with the **`asus-armoury`** firmware-attributes driver: `/sys/class/firmware-attributes/asus-armoury/attributes/dgpu_disable/current_value` must exist.
- systemd, bash, python3 (for console-follow), and optionally `notify-send` (libnotify) for `--notify`.
- The NVIDIA driver (`nvidia-open` or `nvidia`). For console-follow: `options nvidia_drm modeset=1 fbdev=1` in `/etc/modprobe.d/`.
- Don't use `asusctl armoury set dgpu_disable` (or other tools that switch the dGPU) at the same time.

## Install

```
git clone https://github.com/sandb/gpu-switch.git
cd gpu-switch
sudo ./install.sh                         # gpu-switch only
sudo ./install.sh --with-console-follow   # gpu-switch + console-follow (see below)
```
This installs `/usr/local/bin/gpu-switch`, `gpu-switch.service` (enabled), the man page, and `/var/lib/gpu-switch/` (writable by group `wheel`). With `--with-console-follow` also `/usr/local/bin/console-follow`, the udev rule `82-console-follow.rules` and its man page.

- **Updating:** run `sudo ./install.sh` again. An installed console-follow is updated too; a plain `./install.sh` never adds or removes it.
- **console-follow later on or off:** `sudo ./install.sh --with-console-follow` / `--without-console-follow`. Removing it first moves the consoles back to the laptop screen.
- **Uninstall:** see the UNINSTALL section in `man gpu-switch`. Switch the dGPU **on** before uninstalling, or it stays off (also in Windows).

## Other laptops

Untested. Before trying, check:
- the firmware attribute above exists;
- `DGPU_BRIDGE` at the top of `gpu-switch` is the PCIe port your dGPU sits behind (on the GA401QM `0000:00:01.1`; find yours with `lspci -tv` or `readlink -f /sys/bus/pci/devices/<dGPU address>/..` while the dGPU is on);
- `NVIDIA_MODULES` lists the modules your driver loads.

Test both directions, with a way back (a second user session or an SSH login), and read the journal afterwards.

## Caveats

- `dgpu_disable` lives in the firmware, so **other operating systems see it too**: with the dGPU off, Windows has no NVIDIA GPU (same as Armoury Crate Eco mode). A change made in Windows is undone at the next Linux shutdown if the desired state says otherwise.
- With the dGPU off, every output wired to it (here: USB-C/DisplayPort) is dead.
- This writes a firmware setting. It works well on the tested laptop, but use it at your own risk (see LICENSE).

## License

MIT, see [LICENSE](LICENSE).
