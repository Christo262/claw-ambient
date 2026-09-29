# claw-ambient

Screen-reactive ambient lighting for the **MSI Claw** joystick RGB rings on Linux.

The rings take on the colours of whatever is on your screen, with smooth fades, like the
ambient/sync mode you get with MSI Center's Mystic Light on Windows. It works in **Steam Game Mode**
and on the **desktop**.

- Smooth fades at up to 60 steps per second
- Works in Steam Game Mode (gamescope) and Wayland desktops (tested on KDE Plasma)
- **Doesn't wear out the controller's flash memory** (see [How it works](#how-it-works))
- Starts automatically when you log in, and recovers if Steam changes the LEDs
- Light on resources: one small Python process, ~5% of one CPU core

## Requirements

- An MSI Claw handheld (USB ID `0db0:1901`–`1904`). Developed on a Claw 8 AI+ (firmware 2.29).
- A kernel with the `hid-msi` driver: mainline Linux 7.3 or newer, or a CachyOS kernel (which
  carries it as a patch). Check with: `ls /sys/class/leds/ | grep joystick_rings`
- PipeWire, and on the desktop an `xdg-desktop-portal` backend with screen-cast support (KDE, GNOME, …)
- Python 3 with `numpy` and `gobject`, plus GStreamer with the PipeWire plugin

On Arch / CachyOS:

```bash
sudo pacman -S --needed python-numpy python-gobject gstreamer gst-plugins-base gst-plugin-pipewire
```

## Install

```bash
git clone https://github.com/Christo262/claw-ambient.git
cd claw-ambient
./install.sh
```

Run it as your normal user. It asks for your password once, to install a udev rule that gives your
user access to the controller. On the desktop you'll get a one-time **"share your screen"** prompt:
pick your screen and allow it, and it's remembered after that. Game Mode needs no prompt.

## Settings

Edit `~/.config/claw-ambient/config`, then restart it:

```bash
systemctl --user restart claw-ambient
```

| Setting        | Default | What it does                                                        |
|----------------|---------|---------------------------------------------------------------------|
| `fade_seconds` | `0.10`  | How long colour changes take to settle. Higher = smoother, slower.  |
| `saturation`   | `1.6`   | Colour punchiness. `1.0` = true colours.                            |
| `max_level`    | `1.0`   | Overall brightness cap (0–1).                                       |
| `min_level`    | `0.08`  | Dimmest the rings get on dark scenes (0–1). `0` allows fully dark.  |
| `gamma`        | `1.8`   | LED colour curve. Higher = deeper darks.                            |
| `fps`          | `30`    | Screen samples per second; also caps the capture frame rate.        |
| `led_hz`       | `60`    | LED fade steps per second.                                          |
| `keepalive`    | `1.0`   | Resend the colour this often (s) on a static screen.                |

## Usage

It runs by itself after install. To control it manually:

```bash
systemctl --user stop claw-ambient      # turn off (rings keep their last colour)
systemctl --user start claw-ambient     # turn back on
systemctl --user disable --now claw-ambient   # don't start on login
journalctl --user -u claw-ambient -f    # logs
```

## Optional: quiet driver log

The stock `hid-msi` driver logs `Got unexpected ACK from MCU, ignoring` for every colour
claw-ambient sends. That's harmless, but it's up to ~30 lines a second while gaming. The
[`driver/`](driver/) folder has the same driver with that one message downgraded to debug level
([`quiet-ack.patch`](driver/quiet-ack.patch)):

```bash
cd driver
./install.sh     # needs kernel headers; installs for the running kernel only
./uninstall.sh   # back to the stock driver
```

It only overrides the driver for the kernel you build it on, so after a kernel update the stock
driver comes back automatically. The installer also rebuilds your initramfs, because most setups
load `hid-msi` from it early in boot. `driver/hid-msi.c` is taken from CachyOS's kernel patches for
7.2. Only use it if it matches your kernel's driver version.

## How it works

**Screen capture.** In Game Mode, gamescope publishes its output as a PipeWire video node, and
claw-ambient reads it directly. On the desktop it uses the xdg-desktop-portal ScreenCast API with a
restore token, so you're only asked once. Frames are scaled to 96×54 and reduced to one colour,
weighted towards bright, saturated pixels so the rings pick up the scene's dominant colour rather
than a muddy average. The colour is then eased towards that target in perceptual space.

**Why not use the kernel LED interface?** The driver exposes the rings as an LED device
(`/sys/class/leds/msi_claw:rgb:joystick_rings`, or `go:rgb:joystick_rings` on CachyOS), but it's
designed for occasional changes:

1. Every change is followed by a `SYNC_TO_ROM` command that saves the colour to the controller's
   flash memory. Streaming colours through it would mean many flash writes per second, and flash
   has limited write endurance.
2. Changes are debounced by 50 ms, and every new write restarts the timer. So a continuous fade
   never reaches the hardware until it stops, and then it jumps.

claw-ambient writes the controller's RGB frame (`WRITE_PROFILE_DATA`, command `0x21`) straight to
its hidraw interface and **never sends `SYNC_TO_ROM`**. The controller displays the colour
immediately and saves nothing, so after a reboot the rings start on the effect saved on the
controller until claw-ambient takes over.

Protocol details come from the GPL `hid-msi` driver by Derek J. Clark, Zhouwang Huang, Denis
Benato and Valve.

## Troubleshooting

- **Rings don't react:** check `journalctl --user -u claw-ambient -e`.
  - `MSI Claw controller not found` means your kernel lacks the `hid-msi` driver.
  - `No permission to open /dev/hidrawN` means the udev rule isn't active. Re-run
    `./install.sh`, or log out and back in.
- **Desktop screen-share was denied:** delete `~/.local/state/claw-ambient/restore_token`, run
  `systemctl --user restart claw-ambient` and allow the prompt.
- **Colours flicker in Game Mode:** Steam may be setting its own LED colour. claw-ambient
  re-asserts its colour every `keepalive` seconds; lower it if you see Steam's colour flash through.

## Uninstall

```bash
./uninstall.sh
```

## Disclaimer

Not affiliated with or endorsed by MSI. "MSI", "Claw" and "Mystic Light" are trademarks of
Micro-Star International. Use at your own risk.

## License

GPL-2.0-or-later. See [LICENSE](LICENSE). `driver/hid-msi.c` keeps its original copyright
notices.
