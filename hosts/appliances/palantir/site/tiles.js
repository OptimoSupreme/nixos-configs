// The tile list — the one file to edit to change what's on the menu.
// Channels are assigned in order starting at CH 03.
// (If a services.retrotv NixOS module ever happens, it generates this file.)
//
// Local Media is the house Jellyfin, whose address (and API key, for
// promo.js) live on the box in /var/lib/retrotv/local.json, served by the
// bridge as local.js (README). Without it the channel is simply absent and
// the ones after it move up.
window.RETROTV_TILES = [
  { name: "Local Media", url: ((window.RETROTV_LOCAL || {}).jellyfin || {}).url },
  { name: "Disney+",     url: "https://www.disneyplus.com" },
  { name: "Hulu",        url: "https://www.hulu.com" },
  { name: "Netflix",     url: "https://www.netflix.com" },
  { name: "YouTube",     url: "https://www.youtube.com/tv" },
  { name: "Video Games", url: "/games.html" },
].filter(function (t) { return !!t.url; });
