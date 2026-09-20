# shairport-sync on morgoth (native NixOS port, notes only)

No module yet. This records what the service needs from the host so the port can be
written without re-diagnosing it. The current Debian/docker deployment and its host fixes
are in `homelab/docker-compose/shairport-sync/README.md`.

What runs today: AirPlay 2 receiver named "Outdoor Speakers", `default_airplay_volume =
-20.0`, `alsa.output_device = "hw:CARD=PCH,DEV=0"` (onboard Realtek ALC892, card 0
device 0), rear green line-out jack into the outdoor amp.

**Principle for the port:** every host fix on Debian exists because of a Debian default or
a kernel fault seen on 6.12.107. Check the NixOS default and the behaviour on the real
host first, and add configuration only where a check fails. Do not carry the Debian
workarounds over blindly.

## Checklist

### 1. The service itself
- Look at `services.shairport-sync` in the nixpkgs pinned by `flake.lock`: whether the
  package is built with AirPlay 2 (nqptp + avahi + alsa), whether nqptp is a separate
  service option, how the config is passed (`arguments` vs a config file), and which user
  it runs as (needs `/dev/snd`, normally the `audio` group).
- Avahi must be running (`services.avahi`). Check whether the module enables it.
- NixOS enables the firewall by default; Debian morgoth had none. AirPlay 2 needs
  5000/tcp, 7000/tcp, 319-320/udp, 5353/udp and 6000-6009/udp. Prefer the module's
  `openFirewall`-style option if one exists.
- morgoth sits on 10.0.1.0/27 and the phones on 10.0.0.0/24. mDNS crossing between them
  is handled on OPNsense, not on the host, so nothing to configure here. Verify from the
  LAN with `avahi-browse -rt _airplay._tcp`.

### 2. Mixer and volume
Facts: the HDA driver initialises the ALC892 "Front" controls (DAC node 0x02 volume and
rear line-out pin 0x14 mute; "Front" is the front stereo pair, the front-panel jack is
"Headphone") at minimum volume and muted. shairport-sync only does software volume.
Wanted state: 100 % = 0 dB unity. There is no gain above it, so it cannot clip; loudness
is set on the amp. Do not set `volume_max_db` unless the amp input overloads.

Checks on the NixOS host, in order:
1. After boot, read the hardware: want `[0x40 0x40]` on node 0x02 and `[0x00 0x00]`
   on node 0x14.
   ```bash
   awk '/^Node 0x(02|14) /{p=1} /^Node 0x/ && !/^Node 0x(02|14) /{p=0} p && /Amp-Out vals/' /proc/asound/card0/codec#0
   ```
2. Run `amixer -c 0 sset Front 100% unmute` and read the hardware again. On Debian
   6.12.107 this changed only the kernel's cache; the codec stayed muted, even during a
   running stream. If it works on the NixOS kernel, the fix is ordinary ALSA state
   persistence. Check whether the pinned nixpkgs has an option for that (something like
   `hardware.alsa.enablePersistence`; confirm the name) before writing a oneshot.
3. Only if `amixer` still does not reach the codec: port `host/hda-unmute-lineout` from
   the homelab repo as a `systemd.services` oneshot (`After = [ "sound.target" ]`,
   `ConditionPathExists = "/dev/snd/hwC0D0"`, needs `python3`). Do not add both.

### 3. Power management
Facts: Debian's `snd_hda_intel` ran with `power_save=10`, `power_save_controller=Y`. The
codec slept 10 s after each stream and woke muted at minimum volume, and the driver's
cache replay never reached it, so every playback after an idle gap was silent.

Checks on the NixOS host:
1. `cat /sys/module/snd_hda_intel/parameters/power_save` and `power_save_controller`.
   NixOS does not set these itself as far as I know, but the kernel build default can
   differ from Debian's, and anything like powertop or TLP would change them. Read the
   value, do not assume.
2. Behaviour test regardless of the value: play something, stop, wait 15 s, confirm
   `/sys/bus/hdaudio/devices/hdaudioC0D0/power/runtime_status` went to `suspended`, then
   re-read the node 0x02/0x14 values above. If they survive the sleep, leave power
   management at its default.
3. Only if the state is lost:
   `boot.extraModprobeConfig = "options snd_hda_intel power_save=0 power_save_controller=N";`

### 4. Jack and hardware identity
Rear green Line Out is pin 0x14 (controls "Front"); the front-panel headphone jack is
pin 0x1b ("Headphone"). Jack detection confirms which jack has a plug:
```bash
sudo python3 - <<'PY'
import fcntl, array, re, os
for d in open("/proc/bus/input/devices").read().split("\n\n"):
    m = re.search(r'N: Name="(HDA Intel PCH [^"]+)"', d); h = re.search(r"H: Handlers=.*?(event\d+)", d)
    if m and h:
        fd = os.open("/dev/input/" + h.group(1), os.O_RDONLY | os.O_NONBLOCK)
        buf = array.array("B", [0] * 8); fcntl.ioctl(fd, 0x8008451b, buf, True); os.close(fd)
        print(m.group(1), "PLUGGED" if int.from_bytes(buf.tobytes(), "little") else "unplugged")
PY
```

### 5. Verification once it runs
- Phone connects and `/proc/asound/card0/pcm0p/sub0/status` shows `RUNNING` with a
  shairport-sync thread as owner.
- Hardware mixer values as in section 2 while the stream runs and again after 15 s idle.
- Test tone that bypasses shairport-sync, same format it uses (full scale, turn the amp
  down first): `speaker-test -D hw:0,0 -c 2 -r 48000 -F S32_LE -t sine -l 1`.
