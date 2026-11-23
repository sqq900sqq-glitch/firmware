/* iOS replacement for the Android JavascriptInterface ("Android" object).
   Injected at document start by the native shell. Synchronous getters read a
   state object the native side keeps up to date; actions post messages. */
(function () {
  var S = window.__iosState || { dark: false, notif: false, version: '' };
  window.__iosState = S;
  function post(name, arg) {
    try { window.webkit.messageHandlers.bridge.postMessage({ m: name, a: arg === undefined ? null : arg }); } catch (e) {}
  }
  window.Android = {
    systemDark: function () { return !!S.dark; },
    setBarColor: function (d) { post('setBarColor', !!d); },
    notifEnabled: function () { return !!S.notif; },
    setNotifications: function (v) { S.notif = !!v; post('setNotifications', !!v); },
    requestLocation: function () { post('requestLocation'); },
    share: function (t) { post('share', String(t)); },
    setPrayerAlarms: function (j) { post('setPrayerAlarms', String(j)); },
    checkUpdate: function () { post('checkUpdate'); },
    installUpdate: function () { post('installUpdate'); },
    appVersion: function () { return S.version || ''; }
  };

  /* navigator.vibrate does not exist on iOS: route to native haptics */
  try {
    navigator.vibrate = function (p) { post('vibrate', Array.isArray(p) ? (p[0] || 0) : (p || 0)); return true; };
  } catch (e) {}

  /* Compass: native heading (CLLocationManager) delivered as deviceorientation
     events carrying webkitCompassHeading, the field qibla.html already reads. */
  window.__iosHeading = function (h) {
    var e = new Event('deviceorientation');
    try {
      Object.defineProperty(e, 'webkitCompassHeading', { value: h });
      Object.defineProperty(e, 'alpha', { value: (360 - h) % 360 });
      Object.defineProperty(e, 'beta', { value: 0 });
      Object.defineProperty(e, 'gamma', { value: 0 });
      Object.defineProperty(e, 'absolute', { value: true });
    } catch (x) {}
    window.dispatchEvent(e);
  };
  if (/qibla\.html/.test(location.pathname)) {
    post('heading', true);
    window.addEventListener('pagehide', function () { post('heading', false); });
  }

  /* Camera (Qibla AR mode): the native shell shows the camera preview behind a
     transparent web view; the page receives a blank stream so its own logic
     (srcObject / play / stop) keeps working unchanged. */
  var css = 'html.ncam,html.ncam body{background:transparent!important}' +
    'html.ncam body>*:not(#cam):not(.toast){visibility:hidden!important}' +
    'html.ncam #cam{background:transparent!important}html.ncam #cam video{opacity:0!important}';
  document.addEventListener('DOMContentLoaded', function () {
    var st = document.createElement('style'); st.textContent = css; document.head.appendChild(st);
  });
  var md = navigator.mediaDevices || {};
  try { if (!navigator.mediaDevices) Object.defineProperty(navigator, 'mediaDevices', { value: md }); } catch (e) {}
  var camWait = null;
  window.__iosCam = function (ok) { var w = camWait; camWait = null; if (w) (ok ? w.res : w.rej)(); };
  md.getUserMedia = function () {
    return new Promise(function (res, rej) {
      camWait = { res: res, rej: rej };
      post('camera', true);
    }).then(function () {
      var c = document.createElement('canvas'); c.width = 2; c.height = 2;
      var s = c.captureStream ? c.captureStream(1) : new MediaStream();
      document.documentElement.classList.add('ncam');
      s.getTracks().forEach(function (t) {
        var stop = t.stop.bind(t);
        t.stop = function () { stop(); document.documentElement.classList.remove('ncam'); post('camera', false); };
      });
      if (!s.getTracks().length) { /* keep stop hook even without tracks */
        s.getTracks = function () { return [{ stop: function () { document.documentElement.classList.remove('ncam'); post('camera', false); } }]; };
      }
      return s;
    }, function () { throw new Error('NotAllowedError'); });
  };
})();
