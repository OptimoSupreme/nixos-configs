// Are we on the internet yet? Boot doesn't wait for the network (fast
// boot wins), so anything that needs the outside world asks here instead
// of finding out the hard way. Probes until the first success, then fires
// every waiting callback. One-shot by design: a mid-session dropout isn't
// boot's problem, and the pages handle their own fetch failures.
(function () {
  "use strict";

  // Probe the weather host itself: it's the main thing being gated, and
  // if this host answers, the WeatherStar iframe can load. no-cors keeps
  // it a connectivity check (opaque response = reachable); no-store so a
  // cached copy can't fake being online.
  var PROBE = "https://weatherstar.netbymatt.com/";
  var RETRY_MS = 2000;

  var online = false;
  var waiting = [];

  function probe() {
    fetch(PROBE, { method: "HEAD", mode: "no-cors", cache: "no-store" })
      .then(function () {
        online = true;
        var cbs = waiting;
        waiting = [];
        cbs.forEach(function (cb) { cb(); });
      })
      .catch(function () { setTimeout(probe, RETRY_MS); });
  }

  window.RETROTV_NET = {
    online: function () { return online; },
    // runs cb when the box first gets online; immediately if it already is
    whenOnline: function (cb) { online ? cb() : waiting.push(cb); },
  };
  probe();
})();
