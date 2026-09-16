#!/usr/bin/env python3
"""retrotv bridge: the one thing the static site can't do itself.

Serves a tiny localhost-only HTTP API for the games page:

  GET /games                -> {"games": [{"file", "name", "console"}]}
  GET /launch?file=<name>   -> starts the right emulator (409 if one is running)
  GET /status               -> {"running": true|false}
  GET /power                -> clean shutdown (same as the physical power button)
  GET /local.js             -> window.RETROTV_LOCAL = <RETROTV_LOCAL_JSON>; (404 if absent)

Games live flat in RETROTV_GAMES_DIR — no per-console subdirs. The console
is inferred from the extension, except .iso (both consoles' dump format),
which is sniffed for the GameCube/Wii disc magic words. GameCube images run
in native Dolphin, PS2 images in PCSX2 with the BIOS from RETROTV_BIOS_DIR.

Multi-disc games are the one exception to "flat": a "Name.m3u" folder
holding the disc images plus an .m3u playlist listing them (the ES-DE
convention). The playlist is the game entry — Dolphin boots .m3u files
natively and, with AutoDiscChange on, swaps to the next disc when the
game asks. A bare .m3u next to its discs in the games dir works too.

The emulator is spawned onto the cage session; cage stacks the new window
over the kiosk Chromium and drops back when it exits.

While a game runs, keyboard focus is on the emulator, so the Chromium
extension's Home key never fires. A thread here watches /dev/input directly
(the service user is in the "input" group) and stops the game on any Home
press — Home means "back to the menu" everywhere. Clicking both of the
pad's sticks in together (L3+R3) counts as Home too: the pad has no
dedicated home button, and the Analog button was tried first but toggles
the pad's own analog mode/LED as a side effect.

The same watcher handles the volume up/down/mute keys (what a TV remote
sends), everywhere — launcher, web tiles, games — since it sits under
the compositor. Volume moves the default PipeWire sink via wpctl, and a
green blocks-and-dashes OSD is painted over whatever is on screen (see
retrotv_osd.py); volume keys unmute, mute shows MUTE until unmuted.

Config via environment (set by the systemd unit):
  RETROTV_GAMES_DIR  directory of user-supplied game images
  RETROTV_BIOS_DIR   directory holding the PS2 BIOS (.bin)
  RETROTV_DOLPHIN    path to the dolphin-emu binary
  RETROTV_PCSX2      path to the pcsx2-qt binary
  RETROTV_WPCTL      wpctl binary (default: wpctl from PATH)
  RETROTV_LOCAL_JSON the box-local site config (Jellyfin, weather — README)
"""

import glob
import json
import os
import select
import socket
import struct
import subprocess
import threading
import time
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from urllib.parse import parse_qs, urlparse

from retrotv_osd import VolumeOsd

PORT = 8788
GAMES_DIR = os.environ.get("RETROTV_GAMES_DIR", "/var/lib/retrotv/games")
BIOS_DIR = os.environ.get("RETROTV_BIOS_DIR", "/var/lib/retrotv/bios")
DOLPHIN = os.environ.get("RETROTV_DOLPHIN", "dolphin-emu")
PCSX2 = os.environ.get("RETROTV_PCSX2", "pcsx2-qt")
WPCTL = os.environ.get("RETROTV_WPCTL", "wpctl")
LOCAL_JSON = os.environ.get("RETROTV_LOCAL_JSON", "/var/lib/retrotv/local.json")
SINK = "@DEFAULT_AUDIO_SINK@"

GC_EXTS = {".gcm", ".rvz", ".gcz", ".wbfs", ".ciso", ".wia", ".dol", ".elf"}
PS2_EXTS = {".chd", ".cso", ".zso"}

PCSX2_INI = os.path.expanduser("~/.config/PCSX2/inis/PCSX2.ini")
DOLPHIN_PAD_INI = os.path.expanduser("~/.config/dolphin-emu/GCPadNew.ini")

# The house pad is a real PS1 DualShock through a SHANWAN USB adapter
# (2563:0526). SDL has no database entry for that id, and its auto-generated
# mapping puts the triggers on the adapter's GAS/BRAKE axes, which never
# move — L2/R2 arrive as plain buttons (b8/b9, verified by evdev capture).
# This is the mapping SDL generates on its own with the triggers moved to
# those buttons. Exported here so every emulator the bridge spawns inherits
# it; other pads are unaffected (the GUID only matches this adapter).
SHANWAN_MAP = (
    "0300cc0e632500002605000010010000,SHANWAN Android Gamepad,"
    "a:b0,b:b1,x:b3,y:b4,back:b10,guide:b12,start:b11,"
    "leftstick:b13,rightstick:b14,leftshoulder:b6,rightshoulder:b7,"
    "dpup:h0.1,dpdown:h0.4,dpleft:h0.8,dpright:h0.2,"
    "leftx:a0,lefty:a1,rightx:a2,righty:a3,"
    "lefttrigger:b8,righttrigger:b9,platform:Linux,")
os.environ.setdefault("SDL_GAMECONTROLLERCONFIG", SHANWAN_MAP)

lock = threading.Lock()
proc = None


def console_of(path, ext):
    if ext in GC_EXTS:
        return "GameCube"
    if ext in PS2_EXTS:
        return "PS2"
    if ext == ".m3u":
        # Multi-disc playlist: the console is whatever its first disc is.
        # Entries are relative to the playlist; nested .m3u entries are
        # ignored rather than followed.
        try:
            with open(path, encoding="utf-8", errors="replace") as f:
                for line in f:
                    line = line.strip()
                    if not line or line.startswith("#"):
                        continue
                    dext = os.path.splitext(line)[1].lower()
                    if dext == ".m3u":
                        return None
                    disc = os.path.join(os.path.dirname(path), line)
                    return console_of(disc, dext)
        except OSError:
            pass
        return None
    if ext == ".iso":
        # .iso is both consoles' dump format. GC (0x1c) and Wii (0x18) discs
        # carry magic words there; a PS2 disc is plain ISO9660 with zeros.
        try:
            with open(path, "rb") as f:
                f.seek(0x18)
                hdr = f.read(8)
            if hdr[4:8] == b"\xc2\x33\x9f\x3d" or hdr[0:4] == b"\x5d\x1c\x9e\xa3":
                return "GameCube"
        except OSError:
            pass
        return "PS2"
    return None


def list_games():
    try:
        names = sorted(os.listdir(GAMES_DIR), key=str.lower)
    except FileNotFoundError:
        return []
    games = []
    for n in names:
        path = os.path.join(GAMES_DIR, n)
        base, ext = os.path.splitext(n)
        if os.path.isdir(path):
            # Multi-disc "Name.m3u" folder: the entry is the playlist
            # inside, and "file" is its path relative to the games dir
            # (launch and the site pass it through opaquely).
            try:
                m3u = sorted((m for m in os.listdir(path)
                              if m.lower().endswith(".m3u")), key=str.lower)
            except OSError:
                continue
            if not m3u:
                continue
            rel = os.path.join(n, m3u[0])
            console = console_of(os.path.join(GAMES_DIR, rel), ".m3u")
            if console is not None:
                name = base if ext.lower() == ".m3u" else n
                games.append({"file": rel, "name": name, "console": console})
            continue
        if not os.path.isfile(path):
            continue
        console = console_of(path, ext.lower())
        if console is not None:
            games.append({"file": n, "name": base, "console": console})
    return games


def running():
    global proc
    with lock:
        if proc is not None and proc.poll() is not None:
            proc = None
        return proc is not None


class Volume:
    """System volume on the default PipeWire sink, TV-style: 0-100 in
    STEP increments, volume keys unmute, mute is a toggle.

    Key events arrive at autorepeat rate, faster than a wpctl subprocess
    per event can run. So the tracked state is authoritative: the OSD
    paints from it immediately, while one apply thread pushes only the
    newest value to wpctl, skipping intermediates. Nothing else touches
    the sink volume, so drift can't creep in after the initial read."""

    STEP = 2

    def __init__(self, osd):
        self.osd = osd
        self.lock = threading.Lock()
        self.vol = None  # 0-100, read from the sink on first use
        self.muted = False
        self.cond = threading.Condition()
        self.dirty = False
        threading.Thread(target=self._apply_loop, name="volume-apply",
                         daemon=True).start()

    def _ensure_state(self):  # call with self.lock held
        if self.vol is not None:
            return
        try:
            out = subprocess.run([WPCTL, "get-volume", SINK], timeout=3,
                                 capture_output=True, text=True).stdout
            self.vol = max(0, min(100, round(float(out.split()[1]) * 100)))
            self.muted = "MUTED" in out
        except Exception as e:
            print(f"volume: can't read sink volume ({e}); assuming 50",
                  flush=True)
            self.vol = 50
            self.muted = False

    def bump(self, delta):
        with self.lock:
            self._ensure_state()
            self.vol = max(0, min(100, self.vol + delta))
            self.muted = False  # volume keys unmute, like a TV
            vol, muted = self.vol, self.muted
        self.osd.show(vol, muted)
        self._mark_dirty()

    def toggle_mute(self):
        with self.lock:
            self._ensure_state()
            self.muted = not self.muted
            vol, muted = self.vol, self.muted
        self.osd.show(vol, muted)
        self._mark_dirty()

    def _mark_dirty(self):
        with self.cond:
            self.dirty = True
            self.cond.notify()

    def _apply_loop(self):
        while True:
            with self.cond:
                while not self.dirty:
                    self.cond.wait()
                self.dirty = False
            with self.lock:
                vol, muted = self.vol, self.muted
            try:
                subprocess.run([WPCTL, "set-volume", SINK, f"{vol / 100:.2f}"],
                               timeout=3)
                subprocess.run([WPCTL, "set-mute", SINK, "1" if muted else "0"],
                               timeout=3)
            except Exception as e:
                print(f"volume: wpctl failed ({e})", flush=True)


def warm_xwayland():
    """cage spawns Xwayland lazily on first connection; poke the socket so
    the emulator never races a cold X server."""
    try:
        s = socket.socket(socket.AF_UNIX)
        s.settimeout(2)
        s.connect("/tmp/.X11-unix/X" + os.environ.get("DISPLAY", ":0").lstrip(":"))
        s.close()
    except OSError:
        pass


def ensure_pcsx2_config():
    """PCSX2 with no config pops its first-run wizard — a dialog cage would
    stack over everything. Seed a minimal config instead: wizard done, BIOS
    folder pointed at the shared bios dir (first .bin found is selected),
    pad 1 bound to both the keyboard and the first SDL game controller
    (repeated ini keys are alternate bindings), and no shutdown confirmation
    so the Home key's SIGTERM lands unprompted. Delete the ini to re-seed."""
    if os.path.exists(PCSX2_INI):
        return
    try:
        bios = sorted((n for n in os.listdir(BIOS_DIR)
                       if n.lower().endswith(".bin")), key=str.lower)[0]
    except (OSError, IndexError):
        bios = ""
        print(f"pcsx2: no BIOS .bin in {BIOS_DIR} - PS2 games won't boot",
              flush=True)
    os.makedirs(os.path.dirname(PCSX2_INI), exist_ok=True)
    with open(PCSX2_INI, "w") as f:
        f.write(f"""\
[UI]
SettingsVersion = 1
SetupWizardIncomplete = false
ConfirmShutdown = false
StartFullscreen = true

[Folders]
Bios = {BIOS_DIR}

[Filenames]
BIOS = {bios}

[InputSources]
SDL = true

[Pad1]
Type = DualShock2
Deadzone = 0.15
Up = Keyboard/Up
Up = SDL-0/DPadUp
Right = Keyboard/Right
Right = SDL-0/DPadRight
Down = Keyboard/Down
Down = SDL-0/DPadDown
Left = Keyboard/Left
Left = SDL-0/DPadLeft
Triangle = Keyboard/I
Triangle = SDL-0/FaceNorth
Circle = Keyboard/L
Circle = SDL-0/FaceEast
Cross = Keyboard/K
Cross = SDL-0/FaceSouth
Square = Keyboard/J
Square = SDL-0/FaceWest
Select = Keyboard/Backspace
Select = SDL-0/Back
Start = Keyboard/Return
Start = SDL-0/Start
L1 = Keyboard/Q
L1 = SDL-0/LeftShoulder
L2 = Keyboard/1
L2 = SDL-0/+LeftTrigger
R1 = Keyboard/E
R1 = SDL-0/RightShoulder
R2 = Keyboard/3
R2 = SDL-0/+RightTrigger
L3 = Keyboard/2
L3 = SDL-0/LeftStick
R3 = Keyboard/4
R3 = SDL-0/RightStick
LUp = Keyboard/W
LUp = SDL-0/-LeftY
LRight = Keyboard/D
LRight = SDL-0/+LeftX
LDown = Keyboard/S
LDown = SDL-0/+LeftY
LLeft = Keyboard/A
LLeft = SDL-0/-LeftX
RUp = Keyboard/T
RUp = SDL-0/-RightY
RRight = Keyboard/H
RRight = SDL-0/+RightX
RDown = Keyboard/G
RDown = SDL-0/+RightY
RLeft = Keyboard/F
RLeft = SDL-0/-RightX
""")
    print(f"pcsx2: seeded {PCSX2_INI} (BIOS: {bios or 'MISSING'})", flush=True)


def ensure_dolphin_pad_config():
    """Bind Dolphin's GC pad 1 to the first SDL game controller. Dolphin's
    stock GCPadNew.ini binds pad 1 to the keyboard; this replaces it, so on
    a box where Dolphin already ran once, delete the ini to re-seed (same
    rule as PCSX2 above). Layout: A=Cross, B=Square, X=Circle, Y=Triangle,
    Z=R1, L=L2, R=R2, C-stick=right stick; L1 and the stick clicks stay
    unbound (the bridge's input watcher uses L3+R3 as Home). Gotcha:
    Dolphin's SDL axis naming has Y+ as stick-up, opposite of raw SDL."""
    if os.path.exists(DOLPHIN_PAD_INI):
        return
    os.makedirs(os.path.dirname(DOLPHIN_PAD_INI), exist_ok=True)
    with open(DOLPHIN_PAD_INI, "w") as f:
        f.write("""\
[GCPad1]
Device = SDL/0/SHANWAN Android Gamepad
Buttons/A = `Button S`
Buttons/B = `Button W`
Buttons/X = `Button E`
Buttons/Y = `Button N`
Buttons/Z = `Shoulder R`
Buttons/Start = `Start`
Main Stick/Up = `Left Y+`
Main Stick/Down = `Left Y-`
Main Stick/Left = `Left X-`
Main Stick/Right = `Left X+`
Main Stick/Dead Zone = 15.
Main Stick/Calibration = 100.00 141.42 100.00 141.42 100.00 141.42 100.00 141.42
C-Stick/Up = `Right Y+`
C-Stick/Down = `Right Y-`
C-Stick/Left = `Right X-`
C-Stick/Right = `Right X+`
C-Stick/Dead Zone = 15.
C-Stick/Calibration = 100.00 141.42 100.00 141.42 100.00 141.42 100.00 141.42
Triggers/L = `Trigger L`
Triggers/R = `Trigger R`
D-Pad/Up = `Pad N`
D-Pad/Down = `Pad S`
D-Pad/Left = `Pad W`
D-Pad/Right = `Pad E`
Rumble/Motor = `Motor L`|`Motor R`
""")
    print(f"dolphin: seeded {DOLPHIN_PAD_INI}", flush=True)


def launch(fname):
    global proc
    game = next((g for g in list_games() if g["file"] == fname), None)
    if game is None:
        return 404, "no such game"
    with lock:
        if proc is not None and proc.poll() is None:
            return 409, "a game is already running"
        warm_xwayland()
        path = os.path.join(GAMES_DIR, fname)
        if game["console"] == "PS2":
            ensure_pcsx2_config()
            # -batch: the process exits when emulation stops, so /status
            # sees the game end the same way it does with Dolphin.
            cmd = [PCSX2, "-batch", "-fullscreen", "--", path]
        else:
            ensure_dolphin_pad_config()
            # Dolphin renders via XWayland (cage spawns it lazily on :0) — its
            # Wayland backend can't create a GL/Vulkan surface for the render
            # window. Panic alert dialogs would steal cage's top-of-stack and
            # hide the game behind black, so route them to the log instead.
            # Vulkan (ANV) + 2x internal resolution (1280x1056) supersamples
            # the 480-line output; the window is fullscreen at display size.
            # AutoDiscChange: on an .m3u boot, swap to the playlist's next
            # disc when the game ejects — no UI on a kiosk box. No-op for
            # single-disc images.
            cmd = [DOLPHIN, "-b", "-e", path,
                   "-C", "Dolphin.Display.Fullscreen=True",
                   "-C", "Dolphin.Interface.UsePanicHandlers=False",
                   "-C", "Dolphin.Core.AutoDiscChange=True",
                   "-C", "Dolphin.Core.GFXBackend=Vulkan",
                   "-C", "GFX.Settings.EFBScale=2"]
        proc = subprocess.Popen(cmd, env=dict(os.environ))
        print(f"launched {game['console']}: {fname} (pid {proc.pid})", flush=True)
    osd.bump_stack()  # the game's window will map over the OSD
    return 200, "launched"


def power_off():
    """The launcher's on-screen power button: same end state as the physical
    one (logind HandlePowerKey=poweroff) — a clean full shutdown. systemctl
    routes this through logind, and the polkit rule in configuration.nix
    lets it through: this service runs outside any seat session, so the
    default policy would demand admin auth."""
    print("power button: poweroff", flush=True)
    subprocess.Popen(["systemctl", "poweroff"])


def stop_game():
    """SIGTERM the running game (SIGKILL if it lingers). Home = go home."""
    with lock:
        p = proc if proc is not None and proc.poll() is None else None
    if p is None:
        return False
    print("home key: stopping game", flush=True)
    p.terminate()

    def ensure_dead():
        try:
            p.wait(timeout=3)
        except subprocess.TimeoutExpired:
            p.kill()

    threading.Thread(target=ensure_dead, daemon=True).start()
    return True


def input_listener():
    """Watch every input device for the keys that must work everywhere:
    Home (or both pad stick clicks held together, L3+R3, the
    controller's "go home" stand-in) stops a running game; the volume
    trio drives the sink and the OSD. Runs forever; rescans every few
    seconds for hotplugged devices."""
    EV_KEY, KEY_HOME = 0x01, 102
    KEY_MUTE, KEY_VOLUMEDOWN, KEY_VOLUMEUP = 113, 114, 115
    BTN_THUMBL, BTN_THUMBR = 0x13D, 0x13E
    fmt = "llHHi"  # struct input_event
    size = struct.calcsize(fmt)
    warned = False
    devs = {}    # path -> open file, kept open across rescans
    thumbs = {}  # path -> stick clicks currently held on that device

    def drop(path):
        thumbs.pop(path, None)
        f = devs.pop(path, None)
        if f is not None:
            try:
                f.close()
            except OSError:
                pass

    while True:
        # Rescan by diffing, never close-and-reopen: reopening loses any
        # events still queued in the kernel buffer (a volume burst can
        # straddle a rescan). And rescan on a deadline, not on quiet: an
        # analog pad's axis jitter streams events nonstop, so a "rescan
        # when idle" loop would never notice a hotplugged device (e.g. a
        # remote paired after boot).
        paths = set(glob.glob("/dev/input/event*"))
        for path in list(devs):
            if path not in paths:
                drop(path)
        for path in paths - devs.keys():
            try:
                devs[path] = open(path, "rb", buffering=0)
            except OSError:
                pass
        if not devs:
            if not warned:
                print("input keys: no readable input devices "
                      "(is the service user in the input group?)", flush=True)
                warned = True
            time.sleep(10)
            continue
        by_fd = {f.fileno(): path for path, f in devs.items()}
        rescan_at = time.monotonic() + 10
        while True:
            remaining = rescan_at - time.monotonic()
            if remaining <= 0:
                break  # rescan for hotplugged devices
            ready, _, _ = select.select(list(by_fd), [], [], remaining)
            if not ready:
                break  # quiet timeout: rescan too
            for fd in ready:
                path = by_fd[fd]
                try:
                    data = devs[path].read(size * 64)
                except OSError:
                    data = None
                if not data:  # device vanished
                    drop(path)
                    del by_fd[fd]
                    continue
                for off in range(0, len(data) - size + 1, size):
                    _, _, etype, code, value = struct.unpack_from(fmt, data, off)
                    if etype != EV_KEY:
                        continue
                    if code == KEY_HOME and value == 1:
                        stop_game()
                    elif code in (KEY_VOLUMEUP, KEY_VOLUMEDOWN) \
                            and value in (1, 2):  # 2 = autorepeat, held key
                        volume.bump(Volume.STEP if code == KEY_VOLUMEUP
                                    else -Volume.STEP)
                    elif code == KEY_MUTE and value == 1:
                        volume.toggle_mute()
                    elif code in (BTN_THUMBL, BTN_THUMBR):
                        held = thumbs.setdefault(path, set())
                        if value == 1:
                            held.add(code)
                            if held == {BTN_THUMBL, BTN_THUMBR}:
                                stop_game()
                        elif value == 0:
                            held.discard(code)


def local_js():
    """The box-local site config (Jellyfin, weather — README) as a script:
    the launcher loads it with a plain <script> tag ahead of its own files,
    so a missing or broken file just leaves window.RETROTV_LOCAL unset and
    the pages fall back (no Local Media channel, no promo cards, static in
    the weather quadrant)."""
    try:
        with open(LOCAL_JSON, encoding="utf-8") as f:
            cfg = json.load(f)
    except FileNotFoundError:
        return 404, b"// no local.json on this box\n"
    except (OSError, ValueError) as e:
        print(f"{LOCAL_JSON} unreadable: {e}", flush=True)
        return 404, b"// local.json unreadable (see the bridge's journal)\n"
    return 200, ("window.RETROTV_LOCAL = " + json.dumps(cfg) + ";\n").encode()


class Handler(BaseHTTPRequestHandler):
    def send_body(self, code, ctype, body):
        self.send_response(code)
        self.send_header("Content-Type", ctype)
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def send_json(self, code, obj):
        self.send_body(code, "application/json", json.dumps(obj).encode())

    def do_GET(self):
        url = urlparse(self.path)
        if url.path == "/local.js":
            code, body = local_js()
            self.send_body(code, "application/javascript", body)
        elif url.path == "/games":
            self.send_json(200, {"games": list_games()})
        elif url.path == "/status":
            self.send_json(200, {"running": running()})
        elif url.path == "/launch":
            fname = (parse_qs(url.query).get("file") or [""])[0]
            code, msg = launch(fname)
            self.send_json(code, {"ok": code == 200, "msg": msg})
        elif url.path == "/power":
            self.send_json(200, {"ok": True, "msg": "powering off"})
            power_off()
        else:
            self.send_json(404, {"ok": False, "msg": "unknown endpoint"})

    def log_message(self, fmt, *args):
        msg = fmt % args
        # the games page polls /status every few seconds; don't fill the journal
        if "/status" not in msg:
            print(msg, flush=True)


if __name__ == "__main__":
    print(f"retrotv-bridge on 127.0.0.1:{PORT}, games in {GAMES_DIR}", flush=True)
    osd = VolumeOsd()
    volume = Volume(osd)
    threading.Thread(target=input_listener, daemon=True).start()
    ThreadingHTTPServer(("127.0.0.1", PORT), Handler).serve_forever()
