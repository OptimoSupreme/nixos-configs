// Launcher: Prevue-style guide grid with arrow-key navigation, Enter to
// tune, digit entry for direct channel selection. The WeatherStar quadrant
// is CH 02 (Enter goes full screen); the power button rides the info panel
// (same clean poweroff as the physical button, via the bridge's /power).
(function () {
  "use strict";

  var tiles = window.RETROTV_TILES || [];
  var COLS = 2; // channels per guide row
  // Column splits per row, cycled: staggered so the cell dividers never
  // line up vertically, like program blocks of different lengths.
  var SPLITS = [[3, 2], [2, 3], [1, 1]];
  var FIRST_CH = 3; // grid tiles; CH 02 is the weather quadrant
  var WEATHER_CH = 2;
  // The feed is pinned to coordinates from the box's local.json
  // (window.RETROTV_LOCAL.weather, README) rather than a place name: a
  // latLonQuery would re-geocode through arcgis.com on every load, and one
  // flaked request leaves the corner stuck on WS's location prompt. With
  // no coordinates the quadrant stays on static, as when it's offline.
  var WX = (window.RETROTV_LOCAL || {}).weather || {};
  var WEATHER_URL = (typeof WX.lat === "number" && typeof WX.lon === "number")
    ? "https://weatherstar.netbymatt.com/" +
      "?latLon=" + encodeURIComponent(JSON.stringify({ lat: WX.lat, lon: WX.lon })) +
      "&kiosk=true&mediaPlaying=true&scanLines=false" +
      "&latest-observations=false&hourly-graph=false&almanac=false"
    : null;
  var BRIDGE = "http://127.0.0.1:8788";
  var NET = window.RETROTV_NET;

  var grid = document.getElementById("grid");
  var hud = document.getElementById("hud");
  var noise = document.getElementById("noise");
  var noiseLabel = document.getElementById("noiseLabel");
  var stage = document.querySelector(".stage");
  var powerBtn = document.getElementById("power");
  var weatherEl = document.getElementById("weather");
  var promoEl = document.getElementById("promo");
  var weatherFrame = weatherEl.querySelector("iframe");
  if (WEATHER_URL) weatherEl.href = WEATHER_URL;

  // The feed starts when the network does: the quadrant plays static
  // (.nosignal, set in the HTML) until net.js sees the internet, then the
  // WeatherStar iframe loads. Loading it blind would burn the offline
  // error page into the frame with nothing ever retrying it.
  function weatherOn() {
    if (gamePoll || !WEATHER_URL) return; // game running: resetTune restores it after
    weatherEl.classList.remove("nosignal");
    // guarded so bfcache returns don't pointlessly reload the feed
    if (weatherFrame.getAttribute("src") !== WEATHER_URL) {
      weatherFrame.src = WEATHER_URL;
    }
  }
  NET.whenOnline(weatherOn);

  // pseudo-indices past the grid tiles
  var POWER = tiles.length;
  var WEATHER = tiles.length + 1;
  var PROMO = tiles.length + 2;
  // the promo card tunes whatever it's showing, as the channel after
  // the tiles (promo.js prints the matching PRESS NN footer)
  var PROMO_CH = FIRST_CH + tiles.length;

  var sel = parseInt(sessionStorage.getItem("retrotv.sel") || "0", 10);
  if (!(sel >= 0 && sel <= PROMO)) sel = 0;
  // where ArrowDown from the top elements lands: the tile you came from,
  // defaulting to the grid tile nearest each (weather left, panel right)
  var lastGrid = sel < POWER ? sel : (sel === WEATHER ? 0 : COLS - 1);
  var tuning = false;
  var gamePoll = null; // /status poll while a promo'd game runs
  var pendingTune = null; // navigation armed while waiting on the network

  function pad2(n) { return (n < 10 ? "0" : "") + n; }
  function chOf(i) { return FIRST_CH + i; }

  var els = tiles.map(function (t, i) {
    var a = document.createElement("a");
    a.className = "tile";
    a.href = t.url;
    a.innerHTML = '<span class="ch">' + pad2(chOf(i)) + '</span>' +
                  '<span class="name">' + t.name.toUpperCase() + "</span>";
    a.addEventListener("mouseenter", function () { select(i); });
    a.addEventListener("click", function (e) { e.preventDefault(); tune(i); });
    return a;
  });
  for (var r = 0; r * COLS < els.length; r++) {
    var rowEl = document.createElement("div");
    rowEl.className = "gridrow";
    var split = SPLITS[r % SPLITS.length];
    for (var c = 0; c < COLS && r * COLS + c < els.length; c++) {
      els[r * COLS + c].style.flexGrow = split[c];
      rowEl.appendChild(els[r * COLS + c]);
    }
    grid.appendChild(rowEl);
  }
  els.push(powerBtn);   // els[POWER]
  els.push(weatherEl);  // els[WEATHER]
  els.push(promoEl);    // els[PROMO]
  powerBtn.addEventListener("mouseenter", function () { select(POWER); });
  powerBtn.addEventListener("click", function () { powerOff(); });
  weatherEl.addEventListener("mouseenter", function () { select(WEATHER); });
  weatherEl.addEventListener("click", function (e) {
    e.preventDefault();
    tune(WEATHER);
  });
  promoEl.addEventListener("mouseenter", function () { select(PROMO); });
  promoEl.addEventListener("click", function () { tunePromo(); });

  function select(i) {
    if (i < 0 || i > PROMO || tuning) return;
    els[sel].classList.remove("sel");
    sel = i;
    els[sel].classList.add("sel");
    if (i < POWER) lastGrid = i;
    sessionStorage.setItem("retrotv.sel", String(sel));
  }

  function tune(i) {
    if (tuning) return;
    var ch, url;
    if (i === WEATHER) { if (!WEATHER_URL) return; ch = WEATHER_CH; url = WEATHER_URL; }
    else if (i >= 0 && i < tiles.length) { ch = chOf(i); url = tiles[i].url; }
    else return;
    tuning = true;
    noiseLabel.textContent = "CH " + pad2(ch);
    noise.classList.add("on");
    goWhenReady(url);
  }

  // Navigate once the destination can actually load: local pages after the
  // usual beat of static, remote ones not before the box is online — the
  // static just keeps playing and the channel comes in the moment the
  // network does (boot doesn't wait for it). Backspace/Home backs out of a
  // wait (see the key handler); navigating blind would land on Chromium's
  // error page, where not even the extension's Home key runs.
  function goWhenReady(url) {
    if (url.charAt(0) === "/" || NET.online()) {
      setTimeout(function () { window.location.href = url; }, 500);
      return;
    }
    var go = function () { window.location.href = url; };
    pendingTune = go;
    NET.whenOnline(function () {
      // still armed? (canceled waits leave their callback behind)
      if (pendingTune === go) { pendingTune = null; go(); }
    });
  }

  function powerOff() {
    if (tuning) return;
    tuning = true;
    stage.classList.add("off");
    fetch(BRIDGE + "/power")
      .then(function (r) { if (!r.ok) throw new Error("power failed"); })
      .catch(function () {
        // bridge didn't take it — un-blank instead of stranding a live box
        stage.classList.remove("off");
        tuning = false;
      });
  }

  // Tune the promo card (CH 09): whatever it's showing right now.
  // Media goes to its Jellyfin page; a game launches over the kiosk like
  // the games page does — hold the static under the emulator and poll
  // until it exits, so the launcher is clean when the picture comes back.
  function tunePromo() {
    if (tuning) return;
    var api = window.RETROTV_PROMO;
    var act = api && api.current();
    if (!act) return; // fallback card promotes nothing
    tuning = true;
    noiseLabel.textContent = "CH " + pad2(PROMO_CH);
    noise.classList.add("on");
    if (act.kind === "media") {
      goWhenReady(act.url);
      return;
    }
    // a game runs OVER this page, which stays loaded underneath — blank
    // the weather feed so its music doesn't play behind the game (media
    // tunes get this for free by navigating away)
    weatherFrame.src = "about:blank";
    fetch(BRIDGE + "/launch?file=" + encodeURIComponent(act.file))
      .then(function (r) {
        if (!r.ok) throw new Error("launch failed");
        pollGameExit();
      })
      .catch(resetTune);
  }

  function pollGameExit() {
    gamePoll = setInterval(function () {
      fetch(BRIDGE + "/status")
        .then(function (r) { return r.json(); })
        .then(function (d) { if (!d.running) resetTune(); })
        .catch(function () {});
    }, 3000);
  }

  // A game can already be running when this page comes up: input leaking
  // into a hidden page (see pad.js) can navigate it here mid-game. Hold
  // the weather feed off — its music would play behind the game — park
  // input, and wait out the exit like a promo launch does.
  function checkGameHold() {
    fetch(BRIDGE + "/status")
      .then(function (r) { return r.json(); })
      .then(function (d) {
        if (!d.running || gamePoll) return;
        tuning = true;
        weatherEl.classList.add("nosignal");
        weatherFrame.src = "about:blank";
        pollGameExit();
      })
      .catch(function () {});
  }

  function resetTune() {
    clearInterval(gamePoll);
    gamePoll = null;
    pendingTune = null;
    tuning = false;
    noise.classList.remove("on");
    stage.classList.remove("off");
    // bring the weather feed (and its music) back if a game silenced it —
    // but never load it offline (weatherOn no-ops back to static instead)
    if (NET.online()) weatherOn();
  }

  // --- digit entry, old-cable-box style (readout in the info panel) ---
  var buf = "";
  var bufTimer = null;

  function showBuf() {
    hud.textContent = "CH " + (buf + "__").slice(0, 2);
  }

  function commitBuf() {
    var n = parseInt(buf, 10);
    buf = "";
    bufTimer = null;
    hud.textContent = "";
    if (n === WEATHER_CH) {
      select(WEATHER);
      tune(WEATHER);
      return;
    }
    if (n === PROMO_CH) {
      select(PROMO);
      tunePromo();
      return;
    }
    var i = n - FIRST_CH;
    if (i >= 0 && i < tiles.length) {
      select(i);
      tune(i);
    } else {
      hud.textContent = "CH --";
      setTimeout(function () { if (!buf) hud.textContent = ""; }, 700);
    }
  }

  function pressDigit(d) {
    if (tuning) return;
    clearTimeout(bufTimer);
    buf += d;
    showBuf();
    if (buf.length >= 2) commitBuf();
    else bufTimer = setTimeout(commitBuf, 1200);
  }

  // --- keys ---
  document.addEventListener("keydown", function (e) {
    // a tune stuck waiting on the network can be backed out of: Backspace
    // is the pad's back button, and Home falls through to us here (the
    // extension only intercepts it away from the launcher)
    if (pendingTune && (e.key === "Backspace" || e.key === "Home")) {
      resetTune();
      return;
    }
    if (e.key >= "0" && e.key <= "9") { pressDigit(e.key); return; }
    var i = sel;
    switch (e.key) {
      // top of the screen is weather (left) and the panel (right, promo
      // card with the power button above it): Up from the grid's top row
      // reaches whichever is above, Down returns to the tile you left;
      // grid movement clamps inside the grid
      case "ArrowLeft":
        if (sel === POWER || sel === PROMO) i = WEATHER;
        else if (sel < POWER) i = Math.max(0, sel - 1);
        break;
      case "ArrowRight":
        if (sel === WEATHER) i = PROMO;
        else if (sel < POWER) i = Math.min(tiles.length - 1, sel + 1);
        break;
      case "ArrowUp":
        if (sel < POWER) i = sel < COLS ? (sel === 0 ? WEATHER : PROMO) : sel - COLS;
        else if (sel === PROMO) i = POWER;
        break;
      case "ArrowDown":
        if (sel < POWER) i = Math.min(sel + COLS, tiles.length - 1);
        else i = sel === POWER ? PROMO : lastGrid;
        break;
      case "Enter":
        if (sel === POWER) powerOff();
        else if (sel === PROMO) tunePromo();
        else tune(sel);
        return;
      default:
        return;
    }
    e.preventDefault();
    select(i);
  });

  // Every show — fresh load or bfcache return (extension Home key,
  // browser back): reset, then re-hold if a game is in fact running.
  window.addEventListener("pageshow", function () {
    resetTune();
    checkGameHold();
  });

  select(sel);
})();
