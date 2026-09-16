// Video-game picker: one alphabetical list, each row tagged with its console.
// Talks to the retrotv bridge (bridge/retrotv-bridge.py), which lists games
// in the games dir and launches the right native emulator on the box
// (Dolphin for GameCube, PCSX2 for PS2).
// The bridge is localhost-only; when it's unreachable this page says so.
(function () {
  "use strict";

  var BRIDGE = "http://127.0.0.1:8788";
  var GAMES_DIR = "/var/lib/retrotv/games";

  var list = document.getElementById("list");
  var status = document.getElementById("status");
  var substatus = document.getElementById("substatus");
  var hud = document.getElementById("hud");
  var noise = document.getElementById("noise");
  var noiseLabel = document.getElementById("noiseLabel");

  var games = [];
  var els = [];
  var sel = 0;
  var busy = false;      // a launch is in flight or a game is running
  var pollTimer = null;

  function pad2(n) { return (n < 10 ? "0" : "") + n; }

  function showStatus(main, sub) {
    list.hidden = true;
    status.hidden = false;
    status.textContent = main;
    substatus.textContent = sub || "";
  }

  function showList() {
    status.hidden = true;
    substatus.textContent = "";
    list.hidden = false;
  }

  function render() {
    list.innerHTML = "";
    els = games.map(function (g, i) {
      var row = document.createElement("div");
      row.className = "row";
      row.innerHTML = '<span class="num">' + pad2(i + 1) + '</span>' +
                      '<span class="name">' + g.name.toUpperCase() + '</span>' +
                      '<span class="tag">' + (g.console || "").toUpperCase() + "</span>";
      row.addEventListener("mouseenter", function () { select(i); });
      row.addEventListener("click", function () { play(i); });
      list.appendChild(row);
      return row;
    });
    select(0);
    showList();
  }

  function select(i) {
    if (i < 0 || i >= games.length || busy) return;
    if (els[sel]) els[sel].classList.remove("sel");
    sel = i;
    els[sel].classList.add("sel");
    els[sel].scrollIntoView({ block: "nearest" });
  }

  var lastSig = null;

  function load() {
    showStatus("SCANNING");
    lastSig = null;
    fetchGames();
  }

  function fetchGames() {
    fetch(BRIDGE + "/games")
      .then(function (r) { return r.json(); })
      .then(function (d) {
        var gs = d.games || [];
        var sig = JSON.stringify(gs);
        if (sig === lastSig) return;
        lastSig = sig;
        var keep = games[sel] && games[sel].file;
        games = gs;
        if (!games.length) {
          els = [];
          list.innerHTML = "";
          showStatus("NO GAMES FOUND", "drop GameCube / PS2 images in " + GAMES_DIR);
          return;
        }
        render();
        for (var i = 0; i < games.length; i++) {
          if (games[i].file === keep) { select(i); break; }
        }
      })
      .catch(function () {
        lastSig = null;
        showStatus("GAME SERVICE OFFLINE", "retrotv-bridge is not answering on :8788");
      });
  }

  // The games dir is live: files scp'd in or deleted show up while idle.
  setInterval(function () { if (!busy) fetchGames(); }, 5000);

  function play(i) {
    if (busy || i < 0 || i >= games.length) return;
    busy = true;
    noiseLabel.textContent = "LOADING";
    noise.classList.add("on");
    fetch(BRIDGE + "/launch?file=" + encodeURIComponent(games[i].file))
      .then(function (r) {
        if (!r.ok) throw new Error("launch failed");
        // Dolphin comes up over the kiosk; poll until it exits, then reset.
        pollTimer = setInterval(pollStatus, 3000);
      })
      .catch(function () {
        reset();
        showStatus("LAUNCH FAILED", "check: journalctl -u retrotv-bridge");
        setTimeout(load, 4000);
      });
  }

  function pollStatus() {
    fetch(BRIDGE + "/status")
      .then(function (r) { return r.json(); })
      .then(function (d) { if (!d.running) { reset(); load(); } })
      .catch(function () {});
  }

  function reset() {
    busy = false;
    clearInterval(pollTimer);
    pollTimer = null;
    noise.classList.remove("on");
  }

  // --- clock ---
  function clock() {
    var d = new Date();
    hud.textContent = (d.getHours() % 12 || 12) + ":" + pad2(d.getMinutes()) +
      (d.getHours() < 12 ? " AM" : " PM");
  }
  clock();
  setInterval(clock, 10000);

  // --- keys ---
  document.addEventListener("keydown", function (e) {
    switch (e.key) {
      case "ArrowUp":    e.preventDefault(); select(sel - 1); break;
      case "ArrowDown":  e.preventDefault(); select(sel + 1); break;
      case "Enter":      play(sel); break;
      case "Backspace":
      case "Escape":
        // not while a game runs: a leaked in-game press must not navigate
        // this (hidden) page out from under the emulator
        if (!busy) { e.preventDefault(); window.location.href = "/"; }
        break;
    }
  });

  window.addEventListener("pageshow", function (e) {
    if (e.persisted) { reset(); load(); }
  });

  load();
})();
