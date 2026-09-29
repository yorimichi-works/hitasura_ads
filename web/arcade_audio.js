// Low-latency Web Audio engine for AD DEMO 151.
// Dart calls these through dart:js_interop (lib/arcade/engine/audio_web.dart).
(function () {
  const Ctx = window.AudioContext || window.webkitAudioContext;
  let ctx = null;
  let master = null;
  let sfxBus = null;
  let musicBus = null;
  const buffers = new Map(); // url -> AudioBuffer
  const loading = new Map(); // url -> Promise
  let bgm = null; // {src, gain, url}
  let bgmWanted = null;
  let bgmVolume = 0.55;
  let muted = false;
  const lastPlay = new Map();

  function ensure() {
    if (ctx) return ctx;
    if (!Ctx) return null;
    ctx = new Ctx({ latencyHint: 'interactive' });
    master = ctx.createGain();
    master.gain.value = muted ? 0 : 1;
    // Gentle limiter so stacked effects never clip harshly.
    const comp = ctx.createDynamicsCompressor();
    comp.threshold.value = -8;
    comp.knee.value = 6;
    comp.ratio.value = 8;
    comp.attack.value = 0.002;
    comp.release.value = 0.15;
    master.connect(comp);
    comp.connect(ctx.destination);
    sfxBus = ctx.createGain();
    sfxBus.gain.value = 0.9;
    sfxBus.connect(master);
    musicBus = ctx.createGain();
    musicBus.gain.value = 1;
    musicBus.connect(master);
    return ctx;
  }

  function load(url) {
    if (buffers.has(url)) return Promise.resolve(buffers.get(url));
    if (loading.has(url)) return loading.get(url);
    const c = ensure();
    if (!c) return Promise.resolve(null);
    const p = fetch(url)
      .then((r) => (r.ok ? r.arrayBuffer() : Promise.reject(new Error('HTTP ' + r.status))))
      .then((ab) => new Promise((res, rej) => c.decodeAudioData(ab, res, rej)))
      .then((buf) => {
        buffers.set(url, buf);
        loading.delete(url);
        return buf;
      })
      .catch((e) => {
        loading.delete(url);
        console.warn('[arcadeAudio] load failed', url, e);
        return null;
      });
    loading.set(url, p);
    return p;
  }

  function startBgm(url, buf, fadeIn) {
    const c = ensure();
    if (!c || !buf) return;
    const src = c.createBufferSource();
    src.buffer = buf;
    src.loop = true;
    // MP3 encoders pad the start; skip it so the loop is seamless.
    const pad = Math.min(0.05, buf.duration * 0.01);
    src.loopStart = pad;
    src.loopEnd = buf.duration;
    const g = c.createGain();
    g.gain.value = 0;
    src.connect(g);
    g.connect(musicBus);
    src.start(c.currentTime + 0.01, pad);
    g.gain.linearRampToValueAtTime(bgmVolume, c.currentTime + (fadeIn ? 0.6 : 0.05));
    bgm = { src, gain: g, url };
  }

  function stopCurrent(fade) {
    if (!bgm || !ctx) return;
    const old = bgm;
    bgm = null;
    const t = ctx.currentTime;
    old.gain.gain.cancelScheduledValues(t);
    old.gain.gain.setValueAtTime(old.gain.gain.value, t);
    old.gain.gain.linearRampToValueAtTime(0, t + fade);
    try {
      old.src.stop(t + fade + 0.05);
    } catch (_) {}
  }

  window.arcadeAudio = {
    unlock() {
      const c = ensure();
      if (c && c.state !== 'running') c.resume().catch(() => {});
      if (bgmWanted && (!bgm || bgm.url !== bgmWanted)) this.bgm(bgmWanted);
    },
    preload(urls) {
      for (const u of urls) load(u);
    },
    sfx(url, volume, rate) {
      const c = ensure();
      if (!c || muted) return;
      const now = performance.now();
      // Avoid machine-gun stacking of the very same sample.
      const last = lastPlay.get(url) || 0;
      if (now - last < 28) return;
      lastPlay.set(url, now);
      const buf = buffers.get(url);
      if (!buf) {
        load(url);
        return;
      }
      const src = c.createBufferSource();
      src.buffer = buf;
      src.playbackRate.value = rate;
      const g = c.createGain();
      g.gain.value = volume;
      src.connect(g);
      g.connect(sfxBus);
      src.start();
    },
    bgm(url) {
      bgmWanted = url;
      const c = ensure();
      if (!c) return;
      if (bgm && bgm.url === url) return;
      stopCurrent(0.35);
      load(url).then((buf) => {
        if (bgmWanted !== url || (bgm && bgm.url === url)) return;
        startBgm(url, buf, true);
      });
    },
    stopBgm(fade) {
      bgmWanted = null;
      stopCurrent(fade);
    },
    setBgmVolume(v) {
      bgmVolume = v;
      if (bgm && ctx) {
        const t = ctx.currentTime;
        bgm.gain.gain.cancelScheduledValues(t);
        bgm.gain.gain.setValueAtTime(bgm.gain.gain.value, t);
        bgm.gain.gain.linearRampToValueAtTime(v, t + 0.12);
      }
    },
    setMuted(m) {
      muted = m;
      if (master && ctx) master.gain.setValueAtTime(m ? 0 : 1, ctx.currentTime);
    },
  };

  const unlockOnce = () => window.arcadeAudio.unlock();
  window.addEventListener('pointerdown', unlockOnce, { capture: true });
  window.addEventListener('keydown', unlockOnce, { capture: true });
  window.addEventListener('touchend', unlockOnce, { capture: true });
})();
