// Runs in the page world on youtube.com: make the JS-visible user agent match
// the header the declarativeNetRequest rule sends, so the leanback app's own
// device sniffing agrees with what the server saw.
(function () {
  "use strict";
  var UA = "Mozilla/5.0 (SMART-TV; LINUX; Tizen 6.0) AppleWebKit/537.36 (KHTML, like Gecko) 85.0.4283.93/6.0 TV Safari/537.36";
  try {
    Object.defineProperty(Navigator.prototype, "userAgent", { get: function () { return UA; } });
    Object.defineProperty(Navigator.prototype, "appVersion", { get: function () { return UA.slice(8); } });
  } catch (e) { /* already defined: fine */ }
})();
