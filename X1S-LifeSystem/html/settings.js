(function () {
  'use strict';

  var STORAGE_KEY = 'x1s_cad_settings';

  var DEFAULTS = {
    masterVolume: 100,
    notificationVolume: 100,
    uiVolume: 100,
    musicVolume: 45,
    musicMuted: false,
    muteAll: false,
    notificationPosition: 'top-right'
  };

  var VALID_POSITIONS = ['top-right', 'top-left', 'bottom-right', 'bottom-left'];

  var cache = null;
  var listeners = [];

  function clampVolume(value) {
    var n = Number(value);
    if (!isFinite(n)) return DEFAULTS.masterVolume;
    return Math.max(0, Math.min(100, Math.round(n)));
  }

  function sanitize(raw) {
    var source = (raw && typeof raw === 'object') ? raw : {};
    return {
      masterVolume: clampVolume(source.masterVolume !== undefined ? source.masterVolume : DEFAULTS.masterVolume),
      notificationVolume: clampVolume(source.notificationVolume !== undefined ? source.notificationVolume : DEFAULTS.notificationVolume),
      uiVolume: clampVolume(source.uiVolume !== undefined ? source.uiVolume : DEFAULTS.uiVolume),
      musicVolume: clampVolume(source.musicVolume !== undefined ? source.musicVolume : DEFAULTS.musicVolume),
      musicMuted: source.musicMuted === true,
      muteAll: source.muteAll === true,
      notificationPosition: VALID_POSITIONS.indexOf(source.notificationPosition) !== -1 ? source.notificationPosition : DEFAULTS.notificationPosition
    };
  }

  function load() {
    if (cache) return cache;
    try {
      var raw = window.localStorage.getItem(STORAGE_KEY);
      cache = sanitize(raw ? JSON.parse(raw) : null);
    } catch (e) {
      cache = sanitize(null);
    }
    return cache;
  }

  function persist() {
    try { window.localStorage.setItem(STORAGE_KEY, JSON.stringify(cache)); } catch (e) {  }
  }

  function notifyListeners() {
    listeners.forEach(function (fn) {
      try { fn(load()); } catch (e) {  }
    });
  }

  window.X1SSettings = {
    DEFAULTS: DEFAULTS,

    get: function () {
      return Object.assign({}, load());
    },

    set: function (partial) {
      cache = sanitize(Object.assign({}, load(), partial || {}));
      persist();
      notifyListeners();
      return this.get();
    },

    restoreDefaults: function () {
      cache = sanitize(null);
      persist();
      notifyListeners();
      return this.get();
    },

    onChange: function (fn) {
      if (typeof fn === 'function') listeners.push(fn);
    },

    gain: function (channel) {
      var s = load();
      if (s.muteAll) return 0;
      if (channel === 'music' && s.musicMuted) return 0;
      var channelVolume = channel === 'ui' ? s.uiVolume : channel === 'music' ? s.musicVolume : s.notificationVolume;
      return (s.masterVolume / 100) * (channelVolume / 100);
    }
  };
})();
