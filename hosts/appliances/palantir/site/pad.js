// Gamepad → the document-level key events the launcher pages already handle
// (arrows/Enter/Backspace), so navigation code stays in one place. Loaded by
// the home and games pages only; tile sites keep their own input handling.
// The L3+R3 home combo is NOT handled here: the extension's home.js polls
// for it on every page (tiles included) and the bridge catches it inside
// emulators via evdev.
(function () {
  "use strict";

  var DEADZONE = 0.5;              // sticks are nav flicks here, not analog
  var INITIAL = 400, REPEAT = 150; // arrow auto-repeat while held (ms)

  var KEYS = {
    up: "ArrowUp", down: "ArrowDown", left: "ArrowLeft", right: "ArrowRight",
    ok: "Enter", back: "Backspace"
  };
  var ARROWS = ["up", "down", "left", "right"];
  var BUTTONS = ["ok", "back"];

  // Chromium may or may not give a pad its "standard" mapping. The raw
  // fallback is the joydev order of the house pad (PS1 DualShock on a
  // SHANWAN USB adapter): buttons 0 Cross, 1 Circle, 4 Triangle; d-pad on
  // hat axes 6/7; left stick on axes 0/1. Circle and Triangle both go
  // back — Triangle is the PlayStation-menu reflex.
  function read(gp) {
    var std = gp.mapping === "standard";
    var b = gp.buttons, a = gp.axes;
    function on(i) { return !!(b[i] && b[i].pressed); }
    var s = {};
    if (std) {
      s.up = on(12); s.down = on(13); s.left = on(14); s.right = on(15);
      s.ok = on(0); s.back = on(1) || on(3);
    } else {
      s.up = (a[7] || 0) < -0.5; s.down = (a[7] || 0) > 0.5;
      s.left = (a[6] || 0) < -0.5; s.right = (a[6] || 0) > 0.5;
      s.ok = on(0); s.back = on(1) || on(4);
    }
    var ax = a[0] || 0, ay = a[1] || 0;
    if (ax < -DEADZONE) s.left = true; else if (ax > DEADZONE) s.right = true;
    if (ay < -DEADZONE) s.up = true; else if (ay > DEADZONE) s.down = true;
    return s;
  }

  function fire(action) {
    document.dispatchEvent(new KeyboardEvent("keydown",
      { key: KEYS[action], bubbles: true, cancelable: true }));
  }

  var held = {}; // action -> timestamp of the next auto-repeat fire

  setInterval(function () {
    // While an emulator has the screen this page is unfocused but still
    // running — and Chromium's focus gating of gamepad data leaks, so
    // in-game presses would drive the invisible page around (navigate it,
    // relaunch games, restart the weather music). No focus, no input.
    if (!document.hasFocus()) { held = {}; return; }
    var gps = navigator.getGamepads ? navigator.getGamepads() : [];
    var gp = null;
    for (var i = 0; i < gps.length; i++) {
      if (gps[i]) { gp = gps[i]; break; }
    }
    if (!gp) { held = {}; return; }
    var s = read(gp);
    var now = Date.now();
    ARROWS.forEach(function (dir) {
      if (!s[dir]) { delete held[dir]; return; }
      if (!(dir in held)) { fire(dir); held[dir] = now + INITIAL; }
      else if (now >= held[dir]) { fire(dir); held[dir] = now + REPEAT; }
    });
    BUTTONS.forEach(function (btn) {
      if (!s[btn]) { delete held[btn]; return; }
      if (!(btn in held)) { fire(btn); held[btn] = Infinity; }
    });
  }, 50);
})();
