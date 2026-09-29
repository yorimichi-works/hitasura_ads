"""Procedurally synthesise every SFX and BGM loop for the arcade and write MP3s.

Usage (from the repo root):
    python tool/audio/synth.py            # everything
    python tool/audio/synth.py sfx        # only sound effects
    python tool/audio/synth.py bgm        # only music
    python tool/audio/synth.py bgm menu boss   # selected music loops
    python tool/audio/synth.py sfx coin ssr    # selected sound effects

Outputs:
    assets/audio/sfx/<name>.mp3   mono 44.1 kHz 128 kbps
    assets/audio/bgm/<name>.mp3   stereo 44.1 kHz 128 kbps (112 kbps for loops > 34 s)
Every MP3 starts with a LAME/Info tag carrying encoder delay + padding so decoders that
support gapless playback (Chrome/Firefox/ExoPlayer/AVFoundation) trim the MP3 padding.
"""
from __future__ import annotations

import os
import re
import sys
import time
from concurrent.futures import ProcessPoolExecutor

import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)

from audio_io import mp3_stats, write_mp3  # noqa: E402

ROOT = os.path.abspath(os.path.join(HERE, '..', '..'))
SFX_DIR = os.path.join(ROOT, 'assets', 'audio', 'sfx')
BGM_DIR = os.path.join(ROOT, 'assets', 'audio', 'bgm')
DART_SFX = os.path.join(ROOT, 'lib', 'arcade', 'engine', 'sfx.dart')
SR = 44100


def dart_names():
    """Reads the names that the game expects from lib/arcade/engine/sfx.dart."""
    src = open(DART_SFX, encoding='utf-8').read()
    consts = dict(re.findall(r"static const (\w+) = '([^']+)'", src))

    def listed(cls):
        body = src[src.index('abstract final class ' + cls):]
        body = body[body.index('static const all'):]
        body = body[body.index('[') + 1:body.index('];')]
        return [consts[x.strip()] for x in body.replace('\n', ' ').split(',') if x.strip()]
    return listed('Sfx'), listed('Bgm')


# ---------------------------------------------------------------------------
def build_sfx(names=None):
    import sfx
    expected, _ = dart_names()
    missing = [n for n in expected if n not in sfx.REGISTRY]
    if missing:
        raise SystemExit('No generator for SFX: ' + ', '.join(missing))
    todo = names or expected
    report = []
    for name in todo:
        fn, level, cap = sfx.REGISTRY[name]
        x = sfx.finalize(fn(), level, cap)
        info = write_mp3(os.path.join(SFX_DIR, name + '.mp3'), x, SR, 128)
        report.append(check('sfx', name, x, info))
    return report


def _render_song(name):
    import songs
    from music import master_loop
    t0 = time.time()
    S = songs.SONGS[name]()
    raw = S.render()
    y, stats = master_loop(raw, S.sr, S.target_lufs)
    dur = y.shape[0] / S.sr
    br = 128 if dur <= 34.5 else 112
    info = write_mp3(os.path.join(BGM_DIR, name + '.mp3'), y, S.sr, br)
    info.update(stats)
    info['bpm'] = S.bpm
    info['bars'] = S.bars
    info['bitrate'] = br
    info['render_s'] = time.time() - t0
    # loop seam check: jump between last and first sample relative to typical step
    d = np.abs(np.diff(y, axis=0)).max(axis=1)
    seam = float(np.max(np.abs(y[0] - y[-1])))
    info['seam_jump'] = seam
    info['p999_step'] = float(np.percentile(d, 99.9))
    return name, info, float(np.max(np.abs(y))), float(np.sqrt(np.mean(y ** 2))), float(np.mean(np.abs(y) > 0.885))


def build_bgm(names=None, workers=None):
    import songs
    _, expected = dart_names()
    missing = [n for n in expected if n not in songs.SONGS]
    if missing:
        raise SystemExit('No composition for BGM: ' + ', '.join(missing))
    todo = names or expected
    report = []
    workers = workers or min(len(todo), max(1, (os.cpu_count() or 2) - 1), int(os.environ.get('SYNTH_WORKERS', 2)))
    results = {}
    if workers > 1:
        try:
            with ProcessPoolExecutor(max_workers=workers) as ex:
                futs = {n: ex.submit(_render_song, n) for n in todo}
                for n, fu in futs.items():
                    try:
                        results[n] = fu.result()
                    except MemoryError:
                        print('  (out of memory in worker for', n, '- retrying serially)')
        except Exception as e:  # broken pool etc.
            print('  process pool failed:', e)
    for n in todo:
        if n not in results:
            results[n] = _render_song(n)
    results = [results[n] for n in todo]
    for name, info, peak, rms, clip_frac in results:
        ok = peak > 0.1 and clip_frac < 0.002 and info['seam_jump'] < max(0.05, 3 * info['p999_step'])
        report.append({'kind': 'bgm', 'name': name, 'ok': ok, 'peak': peak, 'rms_db': 20 * np.log10(rms + 1e-12),
                       'dur': info['duration'], 'bytes': info['bytes'], 'extra': info, 'clip_frac': clip_frac})
    return report


def check(kind, name, x, info):
    peak = float(np.max(np.abs(x)))
    clip_frac = float(np.mean(np.abs(x) > 0.95))
    ok = peak > 0.1 and clip_frac < 0.001 and abs(float(np.mean(x))) < 0.01
    return {'kind': kind, 'name': name, 'ok': ok, 'peak': peak,
            'rms_db': 20 * np.log10(np.sqrt(np.mean(x ** 2)) + 1e-12), 'dur': info['duration'],
            'bytes': info['bytes'], 'clip_frac': clip_frac}


def verify_files():
    sfx_names, bgm_names = dart_names()
    problems = []
    for folder, names in ((SFX_DIR, sfx_names), (BGM_DIR, bgm_names)):
        for n in names:
            p = os.path.join(folder, n + '.mp3')
            if not os.path.exists(p):
                problems.append('missing ' + p)
                continue
            st = mp3_stats(p)
            if st['frames'] < 3 or not st['gapless_tag']:
                problems.append('bad mp3 ' + p + ' ' + str(st))
    return problems


def main(argv):
    t0 = time.time()
    what = argv[0] if argv else 'all'
    names = argv[1:] or None
    report = []
    if what in ('all', 'sfx'):
        report += build_sfx(names if what == 'sfx' else None)
        print(f'SFX done in {time.time() - t0:.1f}s')
    if what in ('all', 'bgm'):
        report += build_bgm(names if what == 'bgm' else None)
        print(f'BGM done in {time.time() - t0:.1f}s')
    bad = [r for r in report if not r['ok']]
    for r in report:
        extra = ''
        if r['kind'] == 'bgm':
            e = r['extra']
            extra = (f" lufs~{e['lufs']:.1f} gr={e['avg_gr_db']:.1f}dB seam={e['seam_jump']:.3f}"
                     f" {e['bitrate']}k {e['render_s']:.0f}s")
        print(f"{'OK ' if r['ok'] else 'BAD'} {r['kind']} {r['name']:14s} {r['dur']:6.2f}s "
              f"{r['bytes'] / 1024:7.1f}KB peak={r['peak']:.3f} rms={r['rms_db']:.1f}dB{extra}")
    problems = verify_files() if what == 'all' else []
    for p in problems:
        print('PROBLEM', p)
    print(f'Finished in {time.time() - t0:.1f}s; {len(report)} files, {len(bad)} flagged, '
          f'{len(problems)} file problems')
    return 1 if bad or problems else 0


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))
