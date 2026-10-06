"""App Store preview videos (iPhone 6.9"/6.5": 886x1920, 30 fps, 29.6 s).

    python tool/pv/make_pv.py ja            # one language
    python tool/pv/make_pv.py ja,en,ko
    python tool/pv/make_pv.py all
    python tool/pv/make_pv.py ja --mix-only # re-mix audio onto an existing render

Renders frames with tool/pv/pv_render_test.dart (real game/UI rendering),
mixes BGM "rush" + the sound effects the games actually played, and writes
build/pv/out/PV_<lang>.mp4 (H.264 High ~11 Mbps + AAC 256 kbps 48 kHz stereo).
Captions: tool/pv/pv_script.json. Needs `pip install imageio-ffmpeg numpy`.
"""
import json
import os
import subprocess
import sys

import imageio_ffmpeg
import numpy as np

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
FFMPEG = imageio_ffmpeg.get_ffmpeg_exe()
SR = 48000
TOTAL = 74 * 0.4  # must match pv_render_test.dart
LOOP = 64 * 0.4   # rush.mp3 = 16 bars at 150 BPM
LANGS = ['ja', 'en', 'zh', 'zh_TW', 'ko', 'es', 'fr', 'de', 'pt', 'ru', 'it',
         'hi', 'bn', 'ar', 'ur', 'fa', 'id', 'tr', 'vi', 'th']

_cache = {}


def decode(path):
    if path not in _cache:
        raw = subprocess.run([FFMPEG, '-v', 'error', '-i', path, '-f', 'f32le', '-ac', '2', '-ar', str(SR), '-'],
                             capture_output=True, check=True).stdout
        _cache[path] = np.frombuffer(raw, dtype=np.float32).reshape(-1, 2).copy()
    return _cache[path]


def tame(events):
    """Thin out the SFX so a 1.2s-per-clip montage doesn't turn into noise.

    - PV cues (grid pops, the 151 stamp) fire once each; renders made before the
      cue() fix re-fired them every frame, so drop repeats of the same name+rate.
    - Clear jingles are ~2s long but clips cut every 1.2s: only the first clear
      keeps its jingle, later ones become a short 'correct' ding, and cheers are
      quieter and spaced out.
    """
    out, seen, last = [], set(), {}
    win = {'jingle_win', 'fanfare'}
    first_clear = None
    for e in sorted(events, key=lambda e: e['t']):
        e = dict(e)
        t, name = e['t'], e['name']
        if e['vol'] <= 0:
            continue
        if 48 * .4 <= t < 58 * .4 and name in ('pop', 'stamp', 'cheer'):
            key = (name, round(float(e.get('rate', 1)), 3))
            if key in seen:
                continue
            seen.add(key)
        if name in win:
            if first_clear is None:
                first_clear = t
            if abs(t - first_clear) > .05:
                if t - last.get('correct', -9) < .3:
                    continue
                e.update(name='correct', vol=.5, rate=1)
                name = 'correct'
        elif name == 'cheer':
            if t - last.get('cheer', -9) < 1.5:
                continue
            e['vol'] *= .55
        elif name == 'levelup':
            e['vol'] *= .5
        elif name == 'correct':
            if t - last.get('correct', -9) < .3:
                continue
            e['vol'] = min(e['vol'], .5)
        last[name] = t
        out.append(e)
    return out


def mix(lang):
    n = int(TOTAL * SR)
    out = np.zeros((n, 2), np.float32)
    # BGM: loop the 16-bar track, fade the tail.
    bgm = decode(os.path.join(ROOT, 'assets/audio/bgm/rush.mp3'))[:int(LOOP * SR)]
    reps = np.concatenate([bgm] * (int(TOTAL / LOOP) + 2))[:n].copy()
    fade = int(.9 * SR)
    reps[-fade:] *= np.linspace(1, 0, fade)[:, None] ** 1.5
    out += reps * .5
    # SFX
    events = tame(json.load(open(os.path.join(ROOT, 'build/pv', lang, 'sfx.json'), encoding='utf-8')))
    for e in events:
        p = os.path.join(ROOT, 'assets/audio/sfx/%s.mp3' % e['name'])
        if not os.path.exists(p):
            continue
        s = decode(p)
        rate = float(e.get('rate', 1)) or 1
        if abs(rate - 1) > 1e-3:
            idx = np.arange(0, len(s) - 1, rate)
            s = np.stack([np.interp(idx, np.arange(len(s)), s[:, ch]) for ch in (0, 1)], 1).astype(np.float32)
        a = int(e['t'] * SR)
        if a >= n:
            continue
        b = min(n, a + len(s))
        out[a:b] += s[:b - a] * float(e['vol']) * .55
    # soft limiter + normalize to -1 dBFS peak
    out = np.tanh(out * 1.1) / np.tanh(1.1)
    peak = np.max(np.abs(out)) or 1
    out *= (10 ** (-1 / 20)) / peak
    wav = os.path.join(ROOT, 'build/pv', lang, 'audio.f32')
    out.astype(np.float32).tofile(wav)
    return wav


def render(lang):
    flutter = os.path.join(os.path.dirname(ROOT), 'flutter', 'bin', 'flutter.bat' if os.name == 'nt' else 'flutter')
    r = subprocess.run([flutter, 'test', 'tool/pv/pv_render_test.dart',
                        '--dart-define=PV_LANG=' + lang], cwd=ROOT)
    if r.returncode != 0:
        raise SystemExit('render failed: ' + lang)
    d = os.path.join(ROOT, 'build/pv', lang)
    frames = os.path.join(d, 'frames.rgba')
    subprocess.run([FFMPEG, '-y', '-v', 'error',
                    '-f', 'rawvideo', '-pix_fmt', 'rgba', '-s', '886x1920', '-r', '30', '-i', frames,
                    '-vf', 'scale=out_color_matrix=bt709:out_range=tv,format=yuv420p',
                    '-c:v', 'libx264', '-preset', 'slow', '-profile:v', 'high', '-level', '4.0',
                    '-b:v', '11M', '-maxrate', '12M', '-bufsize', '12M', '-g', '30',
                    '-colorspace', 'bt709', '-color_primaries', 'bt709', '-color_trc', 'bt709',
                    '-movflags', '+faststart', '-an', os.path.join(d, 'video.mp4')], check=True)
    os.remove(frames)


def mux(lang, raw):
    os.makedirs(os.path.join(ROOT, 'build/pv/out'), exist_ok=True)
    dst = os.path.join(ROOT, 'build/pv/out', 'PV_%s.mp4' % lang)
    subprocess.run([FFMPEG, '-y', '-v', 'error',
                    '-i', os.path.join(ROOT, 'build/pv', lang, 'video.mp4'),
                    '-f', 'f32le', '-ar', str(SR), '-ac', '2', '-i', raw,
                    '-map', '0:v', '-map', '1:a', '-c:v', 'copy',
                    '-c:a', 'aac', '-b:a', '256k', '-ar', str(SR), '-ac', '2',
                    '-t', '%.3f' % TOTAL, '-movflags', '+faststart', dst], check=True)
    os.remove(raw)
    print('wrote', dst)


def main():
    if len(sys.argv) < 2:
        print(__doc__)
        sys.exit(1)
    langs = LANGS if sys.argv[1] == 'all' else sys.argv[1].split(',')
    mix_only = '--mix-only' in sys.argv
    for lang in langs:
        if not mix_only:
            render(lang)
        mux(lang, mix(lang))


if __name__ == '__main__':
    main()
