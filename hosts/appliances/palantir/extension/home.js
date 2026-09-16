// Home key -> back to the launcher, from anywhere. Capture phase so app
// key handlers (Netflix, YouTube leanback, ...) can't swallow it.
// Clicking both pad sticks in together (L3+R3) does the same, polled via
// the Gamepad API here in the extension so the combo works on tile sites
// too — pad.js only loads on the launcher's own pages. In emulators the
// bridge watches evdev for the identical combo; between the three, L3+R3
// means "go home" everywhere.
(function () {
  "use strict";
  var HOME = "http://127.0.0.1:8787/";
  var GAMES = "http://127.0.0.1:8787/games.html";

  window.addEventListener("keydown", function (e) {
    if (e.key === "Home" && window.location.href !== HOME) {
      e.preventDefault();
      e.stopImmediatePropagation();
      window.location.href = HOME;
    }
    // The remote's AI button, rebadged by hwdb as F13: straight to the
    // games shelf from anywhere in the browser. Match on e.code — xkb
    // gives F13 an unhelpful keysym, but the physical code is stable.
    if (e.code === "F13" && window.location.href !== GAMES) {
      e.preventDefault();
      e.stopImmediatePropagation();
      window.location.href = GAMES;
    }
  }, true);

  // L3+R3: buttons 10/11 with Chromium's "standard" mapping, 13/14 in the
  // raw joydev order of the house pad (PS1 DualShock on a SHANWAN adapter).
  var was = false;
  setInterval(function () {
    // Unfocused = an emulator (or another window) has the screen, but
    // Chromium's focus gating of gamepad data leaks — don't let in-game
    // stick clicks navigate the invisible page. The bridge's evdev watcher
    // owns the combo inside emulators.
    if (!document.hasFocus()) { was = false; return; }
    var gps = navigator.getGamepads ? navigator.getGamepads() : [];
    var gp = null;
    for (var i = 0; i < gps.length; i++) {
      if (gps[i]) { gp = gps[i]; break; }
    }
    if (!gp) { was = false; return; }
    function on(j) { return !!(gp.buttons[j] && gp.buttons[j].pressed); }
    var combo = gp.mapping === "standard" ? on(10) && on(11)
                                          : on(13) && on(14);
    if (combo && !was && window.location.href !== HOME) {
      window.location.href = HOME;
    }
    was = combo;
  }, 100);
})();
