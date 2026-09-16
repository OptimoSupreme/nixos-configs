// Promo cards for the info panel, in the spirit of the Prevue ad box:
// rotates through the games on the shelf (from the bridge) and the newest
// additions on Jellyfin (straight from its API — the server sends
// Access-Control-Allow-Origin: *, so no proxy needed; its address and API
// key come from the box's local.json, window.RETROTV_LOCAL). Everything is
// best-effort: a dead bridge or a missing API key just means fewer cards,
// and with no cards at all the panel falls back to the control hints.
(function () {
  "use strict";

  var BRIDGE = "http://127.0.0.1:8788";
  var NET = window.RETROTV_NET;
  var JF = (window.RETROTV_LOCAL || {}).jellyfin || {};
  var tiles = window.RETROTV_TILES || [];
  var FIRST_CH = 3;             // keep in sync with launcher.js
  var ROTATE_MS = 10 * 1000;    // hard cut, like the real ad box
  var REFRESH_MS = 5 * 60 * 1000;

  var headEl = document.getElementById("promoHead");
  var artEl = document.getElementById("promoArt");
  var titleEl = document.getElementById("promoTitle");
  var subEl = document.getElementById("promoSub");
  var footEl = document.getElementById("promoFoot");

  function pad2(n) { return (n < 10 ? "0" : "") + n; }

  // the channel to advertise: the tile whose url starts with the given one
  function chFor(url) {
    if (!url) return null;
    for (var i = 0; i < tiles.length; i++) {
      if (tiles[i].url.indexOf(url) === 0) return FIRST_CH + i;
    }
    return null;
  }
  // the promo card is itself tunable: the next channel after the tiles
  var PROMO_CH = FIRST_CH + tiles.length;

  // Jellyfin's server id, needed for web-client details links; fetched
  // once (the endpoint is public)
  var serverId = "";
  function fetchServerId() {
    if (!JF.url || serverId) return;
    fetch(JF.url + "/System/Info/Public")
      .then(function (r) { return r.json(); })
      .then(function (d) { serverId = d.Id || ""; })
      .catch(function () {});
  }

  var FALLBACK = {
    head: "", art: null, sub: "", foot: "",
    title: "ARROWS SELECT\nENTER TUNES\n0–9 CHANNEL",
  };

  var gameCards = [];
  // three library slices: the newest, plus two random draws that walk the
  // whole catalog a batch at a time (fresh draw every refresh)
  var justAdded = [];
  var vaultCards = [];
  var seriesCards = [];
  var deck = [FALLBACK];
  var idx = 0;
  var current = FALLBACK;

  function rebuild() {
    var sources = [justAdded, vaultCards, seriesCards, gameCards]
      .map(function (s) { return s.slice(); });
    deck = [];
    var more = true;
    while (more) {
      more = false;
      sources.forEach(function (s) {
        if (s.length) { deck.push(s.shift()); more = true; }
      });
    }
    if (!deck.length) deck = [FALLBACK];
    idx = idx % deck.length;
    // don't sit on the fallback hints once there's something to show
    if (current === FALLBACK && deck[idx] !== FALLBACK) render(deck[idx]);
  }

  function render(card) {
    current = card;
    headEl.textContent = card.head;
    titleEl.textContent = card.title;
    subEl.textContent = card.sub;
    footEl.textContent = card.foot;
    if (card.art) {
      artEl.src = card.art;
      artEl.hidden = false;
    } else {
      artEl.hidden = true;
      artEl.removeAttribute("src");
    }
  }

  function next() {
    idx = (idx + 1) % deck.length;
    render(deck[idx]);
  }

  function fetchGames() {
    fetch(BRIDGE + "/games")
      .then(function (r) { return r.json(); })
      .then(function (d) {
        gameCards = (d.games || []).map(function (g) {
          return {
            head: "ON THE SHELF",
            art: null,
            title: g.name.toUpperCase(),
            sub: (g.console || "").toUpperCase(),
            foot: "PRESS " + pad2(PROMO_CH),
            action: { kind: "game", file: g.file },
          };
        });
        rebuild();
      })
      .catch(function () { gameCards = []; rebuild(); });
  }

  function jfCard(it, head) {
    var kind = it.Type === "Series" ? "SERIES" : "MOVIE";
    return {
      head: head,
      art: it.ImageTags && it.ImageTags.Primary
        ? JF.url + "/Items/" + it.Id + "/Images/Primary" +
          "?maxHeight=480&api_key=" + encodeURIComponent(JF.apiKey)
        : null,
      title: it.Name.toUpperCase(),
      sub: it.ProductionYear ? kind + " · " + it.ProductionYear : kind,
      foot: "PRESS " + pad2(PROMO_CH),
      action: { kind: "media", id: it.Id },
    };
  }

  // one library slice -> one card list; on any failure the slice just
  // goes empty until the next refresh
  function jfSlice(query, head, assign) {
    fetch(JF.url + "/Items?Recursive=true&Fields=ProductionYear&" + query, {
      headers: { Authorization: 'MediaBrowser Token="' + JF.apiKey + '"' },
    })
      .then(function (r) {
        if (!r.ok) throw new Error("jellyfin " + r.status);
        return r.json();
      })
      .then(function (d) {
        assign((d.Items || []).map(function (it) { return jfCard(it, head); }));
        rebuild();
      })
      .catch(function () { assign([]); rebuild(); });
  }

  function fetchMedia() {
    if (!JF.url || !JF.apiKey) return;
    // cache-buster on the random draws so every refresh is a new hand
    var rnd = "&rnd=" + Date.now();
    jfSlice("SortBy=DateCreated&SortOrder=Descending" +
            "&IncludeItemTypes=Movie,Series&Limit=8",
      "JUST ADDED", function (c) { justAdded = c; });
    jfSlice("SortBy=Random&IncludeItemTypes=Movie&Limit=8" + rnd,
      "FROM THE VAULT", function (c) { vaultCards = c; });
    jfSlice("SortBy=Random&IncludeItemTypes=Series&Limit=6" + rnd,
      "SERIES SPOTLIGHT", function (c) { seriesCards = c; });
  }

  render(FALLBACK);
  fetchGames();
  // Jellyfin needs the network, which boot doesn't wait for: the first
  // fetch fires the moment net.js sees the internet (right away if it's
  // already there), so the card deck fills in local-games-first and the
  // library follows as soon as it can — not on the next 5-minute refresh.
  NET.whenOnline(function () { fetchServerId(); fetchMedia(); });
  setInterval(next, ROTATE_MS);
  setInterval(function () {
    fetchGames(); fetchServerId(); fetchMedia();
  }, REFRESH_MS);

  // What launcher.js needs to tune CH 09: the displayed card's action —
  // a game file to hand the bridge, or a Jellyfin details URL.
  window.RETROTV_PROMO = {
    current: function () {
      var a = current.action;
      if (!a) return null;
      if (a.kind === "media") {
        return {
          kind: "media",
          url: JF.url + "/web/index.html#/details?id=" + a.id +
            (serverId ? "&serverId=" + serverId : ""),
        };
      }
      return a;
    },
  };
})();
