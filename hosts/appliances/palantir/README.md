# palantir — the retro TV

A home-built "smart TV" made of a 1980s console TV, a modern mini PC, and a
declarative NixOS config. The launcher is a static web page styled like the
90s Prevue Channel guide (bundled fan recreations of the real Amiga fonts),
with a live WeatherStar 4000+ feed in the corner; every "app" is just a URL.

Status: the real box (see below) boots straight into the kiosk showing the
launcher — streaming tiles, a Video Games tile backed by native emulators
(Dolphin for GameCube, PCSX2 for PS2) via a small localhost bridge, and the
helper extension. Output is 640x480 into an HDMI→composite adapter. The
NixOS module is deliberately deferred (see below).

## Concept

- **Hardware:** a small mini PC (x86 matters because Widevine on Linux is
  straightforward on x86 and a hassle on ARM), connected to an 80s console
  TV via an HDMI→composite adapter.
- **Software:** NixOS boots straight into Chromium in kiosk mode showing the
  launcher. The launcher is a static site; tiles for streaming services
  navigate to their web players and Local Media goes to the house Jellyfin —
  everything is a URL. The one exception is Video Games: WASM cores can't
  handle GameCube or PS2 (seconds per *frame*), so the tile is a picker page
  that asks a tiny localhost bridge (`bridge/retrotv-bridge.py`, the only
  non-static piece) to launch the **native emulator** — Dolphin or PCSX2;
  cage stacks it over the kiosk and drops back to the launcher when the game
  exits.

## Layout (this directory)

```
hosts/appliances/palantir/
  default.nix                 # the box: kiosk, bridge service, remote, power, WiFi
  hardware-configuration.nix
  site/                       # the launcher: index/games pages, tiles.js is the config
  bridge/                     # retrotv-bridge.py: localhost API that launches Dolphin/PCSX2
  extension/                  # home-key / UA-rewrite Chromium extension
```

The site is built as a derivation in `default.nix` and served by
`static-web-server` on `127.0.0.1:8787`. The software keeps its retrotv
name (the `retrotv-bridge` service, `/var/lib/retrotv`); palantir is the
machine. Site, bridge and extension live next to the box's config because
this box is their only user; if the launcher is ever published for others
they move to their own repo and come back in as a flake input.

## The box

A **Dell OptiPlex 3060 Micro** (i5-8500T, UHD 630, 8 GB, 128 GB SATA SSD)
running NixOS, installed 2026-08-31 with nixos-anywhere (1 GB ESP + one ext4
root, no swap — zram instead). It lives headless behind the TV:
`ssh justin@palantir.local` (avahi), on WiFi via a NetworkManager profile
joined once on the box ("Local config on the box", below), auto-connecting
from power-on with no interaction.

- **Deploying:** from a clone of this repo on the box,
  `sudo nixos-rebuild switch --flake .#palantir`. The fleet's daily
  auto-upgrade (modules/maintenance.nix) pulls the public repo over HTTPS,
  nothing to register — on this host applied on the spot (`switch`, not
  `boot`: nobody is around to click Restart Now) — but only once the host
  is registered in `flake.nix` (the line is there, commented). Package
  updates arrive with the repo's weekly `flake.lock` bump.
- **WiFi:** Dell DW1810 (Qualcomm QCA9377, `ath10k_pci`). It needs
  `hardware.enableRedistributableFirmware` or it's a paperweight. A moody
  card — it logs correctable PCIe errors; if it ever flakes for real, try
  `boot.kernelParams = [ "pcie_aspm=off" ]` first, then swap in an Intel
  9260/AX200-class M.2 card.
- **Firmware:** F12 = one-time boot menu, F2 = setup. Secure Boot stays off
  (NixOS's bootloader is unsigned). Boot order was fixed from Linux with
  `efibootmgr` so a plugged USB stick can't preempt the SSD. Still TODO in
  the BIOS: AC power recovery, so it self-starts after an outage.
- **Remote:** a cheap 2.4 GHz USB remote (XING WEI dongle). Volume, arrows,
  OK, back, and the mouse mode are stock keys; an hwdb block in
  default.nix rebadges the odd ones — Home becomes a real Home key
  (back to the launcher, stops a running game), the three-line menu button
  becomes mute, and the AI button becomes F13, which the extension turns
  into "jump to the games page" from anywhere in the browser.
- **Power:** the remote's power button (and the chassis button) suspends to
  S3 — a two-second "boot" at single-digit watts — and the remote wakes it
  back up (udev arms the USB wake chain). Nothing ever sleeps on its own.
  Real off: the launcher's on-screen power button, or holding the power key
  for 5 seconds.

## Configuring the menu

The menu is `site/tiles.js` — a plain array of `{ name, url }`. Channels are
numbered in order starting at CH 03. Edit it, rebuild, done. The one entry
that isn't a literal is Local Media: its URL is the Jellyfin address from
`local.json` (below), and the channel is skipped when that is absent.

**Why no `services.retrotv` NixOS module (yet):** the module's only real job
was to make the tile list configurable from Nix. With one box and one repo,
`tiles.js` *is* the config, and a module would just be indirection. The module
becomes worth writing when this is shared for strangers to import — at that
point it templates `tiles.js` into the site derivation and wires up what
`default.nix` does by hand today (cage + Chromium kiosk, static server,
bridge service, extension, Widevine, persistent profile). The old target
option shape is preserved in git history (`README.md` before this commit).

## Local config on the box

Anything that is a credential, or specific to this house, stays out of the
repo and lives on the box. It survives rebuilds; a reinstall sets it again.

- **The password** for `justin` (ssh and sudo): set on the box with
  `passwd`; users are mutable and the repo declares the account without
  one. On a nixos-anywhere reinstall the declared account arrives with no
  password, so stop before the reboot (`--phases kexec,disko,install`),
  then `ssh root@<box> nixos-enter --root /mnt -c 'passwd justin'`, then
  reboot. (Written from the docs, not yet exercised — check at the next
  reinstall.)
- **WiFi:** `nmcli dev wifi connect <ssid> password <psk>` once; the profile
  persists in `/etc/NetworkManager/system-connections`.
- **`/var/lib/retrotv/local.json`** (owner justin, mode 0600): the site's
  house-specific values. The bridge serves it as `GET /local.js`
  (`window.RETROTV_LOCAL`), which the launcher loads ahead of its own
  scripts, so a page reload picks up an edit — no rebuild, no restart.

  ```json
  {
    "jellyfin": { "url": "https://jellyfin.example", "apiKey": "…" },
    "weather":  { "lat": 41.35, "lon": -71.92 }
  }
  ```

  `jellyfin.url` is the Local Media tile and where the promo cards look;
  `jellyfin.apiKey` (Jellyfin: Dashboard → Advanced → API Keys) is only
  used by the promo cards. `weather` pins the WeatherStar feed —
  coordinates rather than a place name, because a geocoded query re-resolves
  on every load and one flaked request leaves the corner stuck on WS's
  location prompt. Anything missing degrades quietly: no Local Media
  channel, no Jellyfin promo cards, static in the weather quadrant.

## Games (native Dolphin / PCSX2 via the bridge)

The Video Games tile opens `site/games.html` — one flat alphabetical list of
everything in `/var/lib/retrotv/games`, each row tagged with its console
(GAMECUBE / PS2); no per-console sub-pages. It talks to
`bridge/retrotv-bridge.py` on `127.0.0.1:8788` (systemd unit
`retrotv-bridge`, the only non-static piece of the whole design):

- `GET /games` lists images in `/var/lib/retrotv/games` and infers the
  console from the extension: `.gcm .rvz .gcz .wbfs .ciso .wia` plus
  homebrew `.dol .elf` → GameCube; `.chd .cso .zso` → PS2. `.iso` is both
  consoles' dump format, so those are sniffed for the GameCube/Wii disc
  magic words (a PS2 disc is plain ISO9660). `GET /launch?file=` starts the
  right emulator fullscreen; `GET /status` lets the page notice the game
  exited and reset. The games dir is live: the page re-polls while idle, so
  scp'ing a file in (or deleting one) updates the list within ~5 seconds,
  no reload. `GET /power` does a clean shutdown via logind — the launcher's
  on-screen power button (next to the clock, reachable with the arrows),
  same end state as the physical power key; a polkit rule in
  `default.nix` lets the session-less bridge through.
- GameCube runs `dolphin-emu -b -e <game>`: Vulkan backend (ANV) at 2x
  internal resolution (1280x1056 — the 720p-class setting), fullscreen at
  the display size.
- PS2 runs `pcsx2-qt -batch -fullscreen` (`-batch` makes the process exit
  when emulation stops, so `/status` works the same as with Dolphin). The
  BIOS lives in `/var/lib/retrotv/bios`; on the first PS2 launch the bridge
  seeds `~justin/.config/PCSX2/inis/PCSX2.ini` — first-run wizard skipped
  (it's a dialog cage would stack over everything), BIOS folder pointed at
  the bios dir with the first `.bin` found selected, pad 1 bound to both
  the keyboard and the first SDL game controller, shutdown confirmation off
  so the Home key's SIGTERM lands unprompted. Delete the ini to re-seed;
  further tweaks go in that ini.
- The house pad is a real PS1 DualShock on a SHANWAN USB adapter
  (`2563:0526`). SDL doesn't know that id and auto-maps its triggers to
  axes the adapter never moves, so the bridge exports a corrected mapping
  via `SDL_GAMECONTROLLERCONFIG` (L2/R2 on the buttons it really sends);
  any emulator it spawns inherits the fix. Dolphin gets its own seeded
  `GCPadNew.ini` (pad 1 = the SDL controller: A=Cross, B=Square, X=Circle,
  Y=Triangle, Z=R1, L/R=L2/R2, C-stick=right stick; delete to re-seed —
  it won't overwrite the one Dolphin writes on first run). Both emulator
  seeds carry a 15% stick deadzone for the aging pots.
- The pad also drives the launcher and games pages: `site/pad.js` polls the
  Gamepad API and replays presses as the arrow/Enter/Backspace key events
  the pages already handle (d-pad or left stick to move, Cross to select,
  Circle or Triangle to go back). Tile sites (Disney etc.) are untouched.
- **Clicking both sticks in together (L3+R3) is the Home key — from
  anywhere.** Three watchers cover the three worlds: the bridge's input
  watcher stops a running game, the extension's `home.js` polls the
  Gamepad API on every browser page (tile sites included) and navigates
  to the launcher, and PS2 games still get their individual L3/R3
  presses — a game only sees the combo for the instant before it's
  stopped. (The Analog button was tried first, but it toggles the pad's
  own mode LED.)
- Both emulators run on **XWayland** (`DISPLAY=:0` + `QT_QPA_PLATFORM=xcb`;
  cage spawns Xwayland lazily, the bridge pokes the socket first). Dolphin's
  Wayland backend cannot create a GL/Vulkan surface for the render window —
  "Failed to initialize video backend" / "Failed to create Vulkan surface".
  Panic-alert dialogs are disabled at launch: cage shows only the topmost
  window, so a stray 100px warning dialog would hide the game behind a
  black screen.
- Cage stacks the emulator over the kiosk Chromium. **Home quits the game**:
  the bridge watches `/dev/input` directly (the service user is in the
  `input` group), so the key works even though the emulator holds keyboard
  focus — SIGTERM for a clean stop (~2-3s, memory-card writes land),
  SIGKILL if it hangs. Dolphin's own stop hotkey (`Esc`, or a gamepad combo
  mapped in its hotkey settings) also works.
- Test note: Swiss (homebrew loader) boots and JITs but renders black in
  Dolphin — use a real game image to see pixels.
- Add games with `scp game.rvz justin@palantir.local:/var/lib/retrotv/games/` and
  the PS2 BIOS to `/var/lib/retrotv/bios/`. ROMs and BIOSes are
  user-supplied, never in the repo. Emulator config and saves live in
  `~justin/.config/dolphin-emu` and `~justin/.config/PCSX2` (memory cards
  included) and persist across rebuilds.

## The Chromium extension (implemented)

Two small jobs a plain web page can't do for itself, loaded into the kiosk
with `--load-extension`:

1. **Home key** (`home.js`): once you're inside netflix.com the launcher is
   gone and kiosk mode has no toolbar; a content script on every page catches
   the `Home` key (capture phase, so apps can't swallow it) and navigates back
   to the launcher. (While a game is running Chromium has no focus — the
   bridge's `/dev/input` watcher covers that case, see Games above.)
2. **Per-site user agent** (`rules.json` + `ua.js`): a `declarativeNetRequest`
   rule rewrites the UA header for youtube.com to a Tizen TV UA so
   youtube.com/tv serves the leanback TV UI with "link with TV code" phone
   pairing — the phone then acts as a remote, the one mainstream service with
   real cast-like control. `ua.js` mirrors the same UA into
   `navigator.userAgent` so the leanback app's own sniffing agrees.

## CRT / display notes

- The chain: HDMI out → a MacroSilicon HDMI→composite adapter → the TV's RCA
  "Video In" if it has one, otherwise an RF modulator tuned to channel 3
  (composite is noticeably better).
- The adapter's EDID accepts anything up to 4K and scales it all down to NTSC
  480i. The box outputs **640x480@60** — square pixels at 4:3, and a 1:1
  vertical match to NTSC's 480 lines, so nothing gets rescaled vertically on
  the way to the tube. Pinned twice: `video=HDMI-A-1:640x480@60` on the
  kernel command line for the console, and wlr-randr in the cage script for
  the session (the adapter *prefers* 1280x720, so the default must not win).
- Leave ~5–8% overscan margins — console TVs eat the edges. The 4:3 layout and
  overscan live in the site's stylesheet.
- Big fonts, 2x UI scaling, no 1px lines — interlaced CRTs flicker on thin
  horizontal detail.
- No fake CRT effects (scanlines etc.) anywhere — launcher CSS and game CRT
  shaders alike stay off, because the CRT is real and supplies its own.
- Have the TV checked/recapped before first power-up if it's been sitting for
  decades.
