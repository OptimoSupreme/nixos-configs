# osse — the boat chartplotter

A small x86 computer that boots straight into full-screen Android 16
(Waydroid, running the WayDroid-ATV build with Play services) so the Navionics
Boating app can drive a fixed-mount touchscreen at the helm — the cartography
subscription on hardware we control, at a fraction of the cost of a
commercial MFD.

This is the NixOS port of [helm](https://github.com/OptimoSupreme/Helm), the
Fedora bootc image that did the same job: the kiosk scripts came over as they
were, the Containerfile became `default.nix`, and the parts that were Fedora
or bootc plumbing (SELinux policy, tmpfiles for the kiosk user, the ISO
build) became the NixOS option for the same thing or went away. The software
keeps its helm name (the `helm-kiosk` service and friends,
`/etc/helm/weston.ini`); osse is the machine.

Status: an initial build. It evaluates and is meant to be complete, but no
box has booted it yet — helm's kiosk was only ever hardware-validated on one
two-GPU lab box, and everything shaped by that box was deliberately left
behind (see "Hardware profile"). Expect to iterate on the first real
hardware.

## What the box does

- **Boots to the chart.** weston (kiosk-shell) runs as `justin` under seatd
  and autolaunches the Waydroid session, with supervision: retrying
  `show-full-ui`, and a 7-minute watchdog that recycles a wedged Android boot
  instead of sitting on a black panel.
- **Android baked in.** The system/vendor images are pinned in `default.nix`
  and land in the nix store; `/etc/waydroid-extra/images` points at them
  (`helm-manifest.json` there records the build), so first boot initializes
  Waydroid offline in seconds — a console line announces first-time setup,
  then the first Android boot spends a few minutes optimizing before the UI
  appears. No downloads at sea, and `waydroid upgrade` refuses to fetch.
- **True 1080p, edge to edge.** Android composites at 1920x1080
  (`persist.waydroid.width/height`, re-enforced every boot by
  `helm-props.service` so a Waydroid data wipe can't regress it); the panel
  side is whatever mode weston picks — see "Hardware profile" if the panel
  isn't native 1080p.
- **Graceful power-button shutdown.** Power button → logind poweroff → the
  kiosk stops the Waydroid session *before* the compositor dies, then the
  container, then the OS. No sleep states exist on this box.
- **Backlight bridge.** Under Waydroid the Android brightness slider is a
  setting with no hardware behind it; `helm-backlight` maps it onto the host
  backlight (`/sys/class/backlight`, auto-detected) with a 2%-of-max floor so
  the slider can never black out the panel.
- **Admin over ssh.** `ssh justin@osse.local` (avahi), by password; root has
  no password and no ssh, and no keys live in the config (ssh.nix). helm
  kept a separate locked kiosk user; here the kiosk runs as justin, the way
  palantir's does.

Not in the box yet, as in helm: GPS plumbing from the boat's NMEA feed into
Android, and Navionics itself (installed through Play once signed in).

## Layout (this directory)

```
hosts/appliances/osse/
  default.nix                 # the box: waydroid, kiosk units, power, users, pinned Android build
  hardware-configuration.nix  # (missing until installed — see below)
  scripts/                    # the kiosk, straight from helm's assets/scripts:
    helm-session.sh           #   weston under seatd; waits for the pulse socket
    helm-waydroid.sh          #   weston's autolaunch: session + watchdog
    helm-kiosk-stop.sh        #   ExecStop: waydroid session stop before weston dies
    helm-firstboot.sh         #   one-shot waydroid init from the baked images
    helm-props.sh             #   every boot: no_presentation + 1920x1080 persist props
    helm-backlight.sh         #   Android brightness slider -> /sys/class/backlight
```

The scripts are one derivation (`helm` in `default.nix`); each unit's `path`
supplies the tools they call by bare name. `/etc/helm/weston.ini` is written
inline in `default.nix` and points weston's `[autolaunch]` at the session
script.

## The box

Not chosen yet. helm's README carried a buying warning that still applies:

> The ATV hwcomposer exports dmabufs but drops the format modifier, so
> Android's shared buffers render clean only when they are allocated on the
> **same GPU weston renders on** — cross-GPU buffers shred into slivers at
> import while Android's own screencap stays pristine. On a single-GPU box
> (either vendor) there is no cross-GPU pairing to get wrong, but the kiosk
> was only hardware-validated on an i915 + Vega M lab box — verify a
> screenshot on anything new before committing to hardware.

Buy a single-GPU box. Then, from a clone of this repo on it
(installer/README.md, with the appliance differences):

1. Install with the NixOS installer or nixos-anywhere; name the account
   `justin` — this host declares it (uid 1000, lingering) but not its
   password: users are mutable, so the one the installer set stays
   (`passwd` to change it; nothing in the repo).
2. Drop the installed machine's `hardware-configuration.nix` into this
   directory, then settle the choices in `default.nix`: kernel (latest is
   set; LTS is the other line), the GPU's extras (templates/workstations, "GPU"),
   and the panel mode (below).
3. Register `osse = mkHost ./hosts/appliances/osse;` in `flake.nix` (the line
   is there, commented), join the boat's WiFi
   (`nmcli dev wifi connect <ssid> password <psk>` — profiles live in
   `/etc/NetworkManager/system-connections`, mutable state, nothing in the
   repo), and `sudo nixos-rebuild switch --flake .#osse`. The first rebuild
   pulls the pinned Android build (~1.6 GB) into the store.
4. Reboot. `helm-firstboot` initializes Waydroid from the baked images
   (seconds), then the first Android boot takes a few minutes. Sign in to
   Play, install Navionics.

Firmware: Secure Boot off (NixOS's bootloader is unsigned); fix the boot
order so a plugged USB stick can't preempt the SSD; turn on AC power
recovery so it self-starts when the boat's power comes back.

## Updates

Nothing on the boat updates automatically — helm's rule, kept: a bad update
is worse at sea than at the dock. The fleet's daily pull
(`nixos-upgrade.service`, maintenance.nix) stays configured but its timer is
masked; palantir and gollum, at home, are the ones that switch on a Sunday
timer. Update when you choose, at the dock:

```bash
sudo systemctl start nixos-upgrade.service   # pull the repo, stage the new generation
sudo systemctl reboot                        # apply it
```

Roll back by picking the previous generation in the systemd-boot menu (hold
a key at power-on; the last 10 are kept). Package updates arrive with the
repo's weekly `flake.lock` bump; the Android build only moves when the pin
in `default.nix` is edited (the comment there says where the newest build
is listed).

## Hardware profile

helm grouped its hardware-shaped configuration so pointing the image at a
production box only touched a few files. Those files were tuned to the lab
box (a 4K eDP laptop with an Intel iGPU and a Vega M dGPU) and none of that
came over; what remains is generic, and this is what a real box changes:

| Feature | Lives in | Today | On real hardware |
| --- | --- | --- | --- |
| Display mode | `weston.ini` in `default.nix` | No `[output]` block: weston uses the panel's preferred mode | Native-1080p panel: nothing. Otherwise `cvt 1920 1080`, the real connector name (weston's log lists them), and the pixel clock bumped to htotal×vtotal×60 so the refresh is ≥ 60.000 Hz — the hwcomposer floors it to whole fps and a 59.9x mode judders. The commented block is helm's working example |
| Container GPU | — | waydroid's own pick (the first render node) | Single GPU: nothing to do. Two GPUs: helm's `helm-gpu-node.sh` (pin `drm_device` to the display GPU, cgroup-deny the other render node to the container) is in the helm repo, not here |
| Compositor start | `helm-session.sh` | weston takes the boot VGA device as soon as the unit starts | helm waited for an eDP connector so weston wouldn't grab the transient simpledrm framebuffer and crash when the real driver bound, and picked the panel's card with `--drm-device`. Here a lost race costs one `Restart=always` cycle; bring the wait back if it happens every boot |
| Backlight | `helm-backlight.sh` | Auto-detects `/sys/class/backlight` | A display with no host backlight control needs its own dimming story |
| Power button | logind, `default.nix` | Generic ACPI | Generic |
| WiFi firmware | `hardware.enableRedistributableFirmware` | Every chip family | Nothing to swap (helm carried one iwlwifi blob) |
| Console font | — | Stock | A 4K panel wants `console.font` set to a 32px face for readable TTY text |

## Verifying the panel over ssh

```bash
journalctl -u helm-firstboot -u helm-kiosk -u helm-props -u helm-backlight -u waydroid-container -f
sudo waydroid status                          # container / session state
sudo waydroid shell -- getprop sys.boot_completed
sudo waydroid logcat
# a screenshot of what the panel shows (weston --debug authorizes it);
# the png lands in the current directory
sudo -u justin env XDG_RUNTIME_DIR=/run/user/1000 WAYLAND_DISPLAY=wayland-0 weston-screenshooter
```

Android's `/data` lives in `~justin/.local/share/waydroid/data` and survives
rebuilds; `/var/lib/waydroid` holds waydroid's own config, LXC config and
generated props. Wipe both and reboot to start over from first boot
(`helm-firstboot` runs whenever `/var/lib/waydroid/waydroid.cfg` is missing).
`sudo waydroid upgrade -o` regenerates the LXC config and props from the
current waydroid.cfg without touching the images.

## What didn't come over from helm

- The SELinux gap-filler (`helm_waydroid.te`): NixOS runs no SELinux.
- bootc plumbing: the tmpfiles that created the kiosk user's home and linger
  file (a declared user with `linger = true` here), the os-release renaming,
  the `systemd-remount-fs` mask, the installer ISO and its blueprint.
- The lab box's hardware profile: the 4K → 1080p modeline, the eDP waits and
  `--drm-device` pick, the display-GPU pin and render-node cgroup deny, the
  `amdgpu.runpm=0` karg, the iwlwifi blob, the 32px console font.
- The monthly image build: a pinned Android build plus the repo's weekly
  `flake.lock` bump replace it, applied only when asked (see "Updates").
