#!/usr/bin/env python3
"""retrotv volume OSD: the green bar an old TV painted over the picture.

An X11 override-redirect window on cage's Xwayland, typed
_NET_WM_WINDOW_TYPE_NOTIFICATION. That combination is the whole trick:
cage puts every freshly mapped surface at the top of its scene, so the
OSD lands above the kiosk Chromium and fullscreen emulators alike, and
wlroots' override_redirect_wants_focus() rules mean a NOTIFICATION
window never takes keyboard focus away from whatever is playing.

The look is period hardware, not CSS: a 5x7 block font built from
filled rectangles in the launcher clock's green (#33ff66), fully opaque
pixels on a fully transparent ARGB strip, drop-shadowed one half-block
down-right. No toolkit, no font files, no antialiasing.

python-xlib isn't thread-safe, so a single worker thread owns all X
traffic; the bridge talks to it through show() and bump_stack(). The
worker keeps its connection open between showings, which doubles as
keeping cage's lazy Xwayland warm, and quietly reconnects if cage (and
its Xwayland) restarts.

(Underscore filename: this is imported by retrotv-bridge.py, and Python
module names can't carry a hyphen.)
"""

import threading
import time

from Xlib import X, Xatom, display

GREEN = 0xFF33FF66   # ARGB, same green as the launcher clock
SHADOW = 0xFF000000

# 5x7 block font, the shapes a 90s OSD chip drew
FONT = {
    "0": ("01110", "10001", "10011", "10101", "11001", "10001", "01110"),
    "1": ("00100", "01100", "00100", "00100", "00100", "00100", "01110"),
    "2": ("01110", "10001", "00001", "00110", "01000", "10000", "11111"),
    "3": ("11111", "00010", "00100", "00010", "00001", "10001", "01110"),
    "4": ("00010", "00110", "01010", "10010", "11111", "00010", "00010"),
    "5": ("11111", "10000", "11110", "00001", "00001", "10001", "01110"),
    "6": ("00110", "01000", "10000", "11110", "10001", "10001", "01110"),
    "7": ("11111", "00001", "00010", "00100", "01000", "01000", "01000"),
    "8": ("01110", "10001", "10001", "01110", "10001", "10001", "01110"),
    "9": ("01110", "10001", "10001", "01111", "00001", "00010", "01100"),
    "V": ("10001", "10001", "10001", "10001", "10001", "01010", "00100"),
    "O": ("01110", "10001", "10001", "10001", "10001", "10001", "01110"),
    "L": ("10000", "10000", "10000", "10000", "10000", "10000", "11111"),
    "M": ("10001", "11011", "10101", "10101", "10001", "10001", "10001"),
    "U": ("10001", "10001", "10001", "10001", "10001", "10001", "01110"),
    "T": ("11111", "00100", "00100", "00100", "00100", "00100", "00100"),
    "E": ("11111", "10000", "10000", "11110", "10000", "10000", "11111"),
}

SEGMENTS = 25  # blocks-and-dashes across the screen


class VolumeOsd:
    HIDE_AFTER = 2.0

    def __init__(self):
        self._cond = threading.Condition()
        self._req = None       # latest (volume, muted) not yet drawn
        self._stack_gen = 0    # bumped when something new mapped over us
        threading.Thread(target=self._run, name="volume-osd",
                         daemon=True).start()

    def show(self, volume, muted):
        """Paint the OSD. Volume showings hide after HIDE_AFTER seconds;
        MUTE stays up until unmuted, the way the real sets did."""
        with self._cond:
            self._req = (max(0, min(100, int(volume))), bool(muted))
            self._cond.notify()

    def bump_stack(self):
        """A game was just launched; its window will map above the OSD.
        The next show() remaps instead of redrawing so cage restacks the
        OSD back on top."""
        with self._cond:
            self._stack_gen += 1

    # -- worker thread: everything below runs there ----------------------

    def _run(self):
        dpy = None
        state = None       # (win, gc_fg, gc_sh, geometry)
        shown = None       # what's currently on screen, None if hidden
        mapped_gen = None
        deadline = None
        while True:
            with self._cond:
                if self._req is None:
                    if deadline is not None:
                        timeout = max(0.0, deadline - time.monotonic())
                    elif dpy is None:
                        timeout = 15.0  # retry until cage's X is reachable
                    else:
                        timeout = None
                    self._cond.wait(timeout)
                req, self._req = self._req, None
                gen = self._stack_gen
            try:
                if dpy is None:
                    # keeps Xwayland warm too, so the first press is instant
                    dpy = display.Display()
                    state = self._make_window(dpy)
                    shown = None
                    mapped_gen = None
                win, gc_fg, gc_sh, geo = state
                if req is not None:
                    if shown is None or mapped_gen != gen:
                        if shown is not None:
                            win.unmap()
                        win.map()  # cage stacks a fresh map on top
                        mapped_gen = gen
                    self._draw(dpy, win, gc_fg, gc_sh, geo, *req)
                    shown = req
                    deadline = (None if req[1]
                                else time.monotonic() + self.HIDE_AFTER)
                elif deadline is not None and time.monotonic() >= deadline:
                    win.unmap()
                    dpy.flush()
                    shown = None
                    deadline = None
                while dpy.pending_events():
                    ev = dpy.next_event()
                    if ev.type == X.Expose and shown is not None:
                        self._draw(dpy, win, gc_fg, gc_sh, geo, *shown)
            except Exception as e:
                # cage restarted (taking Xwayland with it), or X trouble:
                # drop the connection and rebuild on the next round
                if dpy is not None:
                    print(f"osd: X connection lost ({e}); will reconnect",
                          flush=True)
                    try:
                        dpy.close()
                    except Exception:
                        pass
                dpy = None
                state = None
                shown = None
                deadline = None

    def _make_window(self, dpy):
        scr = dpy.screen()
        sw, sh = scr.width_in_pixels, scr.height_in_pixels
        visual = None
        for depth in scr.allowed_depths:
            if depth.depth == 32 and depth.visuals:
                visual = depth.visuals[0].visual_id
                break
        if visual is None:
            raise RuntimeError("no 32-bit ARGB visual")
        p = max(4, sh // 90)  # the font pixel, ~8 real pixels at 720p
        geo = (sw, sh, p)
        # Full-screen and transparent, with the bar drawn into its lower
        # part: cage renders override-redirect windows at 0,0 no matter
        # what position they ask for (their x,y never reaches its scene
        # node), so the window covers the screen and placement is ours.
        cmap = scr.root.create_colormap(visual, X.AllocNone)
        win = scr.root.create_window(
            0, 0, sw, sh, 0, 32, X.InputOutput, visual,
            background_pixel=0, border_pixel=0, colormap=cmap,
            override_redirect=1, event_mask=X.ExposureMask)
        win.change_property(
            dpy.intern_atom("_NET_WM_WINDOW_TYPE"), Xatom.ATOM, 32,
            [dpy.intern_atom("_NET_WM_WINDOW_TYPE_NOTIFICATION")])
        win.change_property(Xatom.WM_NAME, Xatom.STRING, 8, b"retrotv-osd")
        gc_fg = win.create_gc(foreground=GREEN)
        gc_sh = win.create_gc(foreground=SHADOW)
        dpy.flush()
        return win, gc_fg, gc_sh, geo

    def _draw(self, dpy, win, gc_fg, gc_sh, geo, volume, muted):
        rects = self._frame_rects(geo, volume, muted)
        s = max(2, geo[2] // 2)  # shadow offset, half a font pixel
        win.clear_area(0, 0, 0, 0)
        win.poly_fill_rectangle(
            gc_sh, [(x + s, y + s, w, h) for x, y, w, h in rects])
        win.poly_fill_rectangle(gc_fg, rects)
        dpy.flush()

    def _frame_rects(self, geo, volume, muted):
        """Everything on screen as a list of rectangles: VOL (or MUTE),
        the blocks-and-dashes bar, the 0-100 number."""
        sw, sh, p = geo
        gy = sh * 82 // 100  # the OSD row sits low, clear of the action
        rects = []

        def glyphs(text, x):
            for ch in text:
                for row, bits in enumerate(FONT[ch]):
                    for col, bit in enumerate(bits):
                        if bit == "1":
                            rects.append((x + col * p, gy + row * p, p, p))
                x += 6 * p  # 5 wide plus one blank column
            return x

        if muted:
            glyphs("MUTE", (sw - (4 * 6 * p - p)) // 2)
            return rects

        margin = sw * 7 // 100  # overscan-safe, like the launcher's 6%
        glyphs("VOL", margin)
        num = str(volume)
        num_x = sw - margin - (3 * 6 * p - p)  # 3-digit field, right edge
        glyphs(num, num_x + (3 - len(num)) * 6 * p)  # right-aligned digits

        bar_lo = margin + 24 * p
        bar_hi = num_x - 3 * p
        pitch = (bar_hi - bar_lo) // SEGMENTS
        filled = (volume * SEGMENTS + 50) // 100
        for i in range(SEGMENTS):
            x = bar_lo + i * pitch
            if i < filled:
                rects.append((x, gy + p, pitch - p, 5 * p))      # block
            else:
                rects.append((x, gy + 3 * p, pitch - p, p))      # dash
        return rects


if __name__ == "__main__":
    # dev harness: retrotv_osd.py [volume] [mute] shows one frame
    import sys
    osd = VolumeOsd()
    vol = int(sys.argv[1]) if len(sys.argv) > 1 else 50
    osd.show(vol, len(sys.argv) > 2)
    time.sleep(3)
