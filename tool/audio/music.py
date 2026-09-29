"""Tiny tracker/sequencer + mixer for seamless music loops.

Everything is rendered into a circular buffer of exactly one loop length, so note
tails, reverb and delay wrap around the loop point (render-twice equivalent).
"""
from __future__ import annotations

import math
import re

import numpy as np

from dsp import mtof, note_to_midi, reverb_ir

# ---------------------------------------------------------------------------
# Theory
# ---------------------------------------------------------------------------
QUALITIES = {
    '': [0, 4, 7], 'M': [0, 4, 7], 'm': [0, 3, 7], '5': [0, 7, 12], '7': [0, 4, 7, 10],
    'm7': [0, 3, 7, 10], 'maj7': [0, 4, 7, 11], 'M7': [0, 4, 7, 11], 'm9': [0, 3, 7, 10, 14],
    '9': [0, 4, 7, 10, 14], 'maj9': [0, 4, 7, 11, 14], 'dim': [0, 3, 6], 'dim7': [0, 3, 6, 9],
    'm7b5': [0, 3, 6, 10], 'aug': [0, 4, 8], 'sus4': [0, 5, 7], 'sus2': [0, 2, 7],
    '7sus4': [0, 5, 7, 10], '6': [0, 4, 7, 9], 'm6': [0, 3, 7, 9], 'add9': [0, 4, 7, 14],
    'madd9': [0, 3, 7, 14], '13': [0, 4, 10, 14, 21], '7b9': [0, 4, 7, 10, 13],
    '7#9': [0, 4, 7, 10, 15], '69': [0, 4, 7, 9, 14], 'maj7#11': [0, 4, 7, 11, 18],
    'mM7': [0, 3, 7, 11], '7aug': [0, 4, 8, 10],
}
_PC = {'C': 0, 'D': 2, 'E': 4, 'F': 5, 'G': 7, 'A': 9, 'B': 11}


def _pc(name):
    v = _PC[name[0]]
    for ch in name[1:]:
        v += 1 if ch == '#' else -1
    return v % 12


class Chord:
    def __init__(self, sym):
        m = re.match(r'^([A-G][#b]?)([^/]*)(?:/([A-G][#b]?))?$', sym)
        if not m:
            raise ValueError('bad chord ' + sym)
        self.sym = sym
        self.root = _pc(m.group(1))
        self.ivs = QUALITIES[m.group(2)]
        self.bass = _pc(m.group(3)) if m.group(3) else self.root

    def pcs(self):
        return [(self.root + i) % 12 for i in self.ivs]

    def voicing(self, lo=55, spread=False):
        notes = sorted({lo + ((pc - lo) % 12) for pc in self.pcs()})
        if spread and len(notes) >= 3:
            notes = [notes[0] - 12] + notes[1:]
        return notes

    def tone(self, which):
        """R root, T third, F fifth, S seventh (or octave)."""
        ivs = self.ivs
        if which == 'R':
            return 0
        if which == 'T':
            return ivs[1] if len(ivs) > 1 else 4
        if which == 'F':
            return ivs[2] if len(ivs) > 2 else 7
        if which == 'S':
            return ivs[3] if len(ivs) > 3 else 12
        raise ValueError(which)


def _smooth_size(n):
    for m in range(n, n + n // 400 + 64):
        k = m
        for p in (2, 3, 5, 7):
            while k % p == 0:
                k //= p
        if k == 1:
            return m
    return n


def _parse_pitch(tok):
    return note_to_midi(tok)


# ---------------------------------------------------------------------------
class Track:
    def __init__(self, name, inst, gain, pan, rev, dly, duck, hpf, lpf, octave, humanize):
        self.name = name
        self.inst = inst
        self.gain = gain
        self.pan = pan
        self.rev = rev
        self.dly = dly
        self.duck = duck
        self.hpf = hpf
        self.lpf = lpf
        self.octave = octave
        self.humanize = humanize
        self.events = []  # (beat, midi or None, dur_beats, vel)


class Song:
    def __init__(self, name, bpm, bars, sr=44100, beats=4, swing=0.0, swing_unit=0.5, transpose=0,
                 seed=1, rev_time=1.8, rev_damp=6000, dly_beats=0.75, dly_fb=0.35, dly_lp=3500,
                 target_lufs=-14.0):
        self.name = name
        self.bpm = bpm
        self.bars = bars
        self.beats = beats
        self.sr = sr
        self.spb = 60.0 / bpm
        self.total_beats = bars * beats
        # nudge the loop length (<0.2%) to a 7-smooth size so circular FFTs are fast
        self.L = _smooth_size(int(round(self.total_beats * self.spb * sr)))
        self.spb = self.L / (self.total_beats * sr)
        self.swing = swing
        self.swing_unit = swing_unit
        self.transpose = transpose
        self.rng = np.random.default_rng(seed)
        self.tracks = {}
        self.order = []
        self.rev_time = rev_time
        self.rev_damp = rev_damp
        self.dly_beats = dly_beats
        self.dly_fb = dly_fb
        self.dly_lp = dly_lp
        self.duck_beats = []
        self.duck_release = 0.45  # beats
        self.master_fx = []
        self.target_lufs = target_lufs

    # ------------------------------------------------------------------ setup
    def track(self, name, inst, gain=0.5, pan=0.0, rev=0.0, dly=0.0, duck=0.0, hpf=None, lpf=None,
              octave=0, humanize=0.003):
        tr = Track(name, inst, gain, pan, rev, dly, duck, hpf, lpf, octave, humanize)
        self.tracks[name] = tr
        self.order.append(name)
        return tr

    def prog(self, spec, start_bar=0):
        """'F G Em Am' one chord per bar; 'Gm6,A7' splits a bar."""
        out = []
        bar = start_bar
        for tok in spec.split():
            if tok == '|':
                continue
            parts = tok.split(',')
            each = self.beats / len(parts)
            for i, p in enumerate(parts):
                out.append((bar * self.beats + i * each, each, Chord(p)))
            bar += 1
        return out

    @staticmethod
    def chord_at(prog, beat):
        for b, d, c in prog:
            if b <= beat + 1e-6 < b + d:
                return c
        return prog[-1][2]

    # ------------------------------------------------------------------ events
    def note(self, tr, beat, pitch, dur, vel=0.8):
        if isinstance(pitch, str):
            pitch = _parse_pitch(pitch)
        self.tracks[tr].events.append((beat, pitch, dur, vel))

    def _tokens(self, pattern):
        p = pattern.replace('|', ' ')
        if len(p.split()) == 1 or all(len(t) == 1 for t in p.split()) and set(p) <= set('xXog.- '):
            if set(p) <= set('xXog.- '):
                return [c for c in p if c != ' ']
        return [t for t in p.split() if t]

    def _vel_mod(self, tok, vel):
        if tok == 'o':
            return tok, vel * 0.6
        if tok.endswith('!'):
            return tok[:-1], min(1.0, vel * 1.25)
        if tok.endswith('?'):
            return tok[:-1], vel * 0.5
        return tok, vel

    def seq(self, trs, bar, pattern, step=0.5, vel=0.8, gate=0.92, octave=0, times=1):
        """Melody grid. Tokens: C5, C5+E5 (chord), '-' hold, '.' rest, suffix ! accent ? soft."""
        if isinstance(trs, str):
            trs = [trs]
        if '|' in pattern:
            per_bar = int(round(self.beats / step))
            for bi, seg in enumerate(pattern.split('|')):
                if len(seg.split()) != per_bar:
                    print(f'WARNING {self.name}/{trs[0]} bar {bar + bi}: {len(seg.split())} steps: {seg.strip()}')
        toks = self._tokens(pattern)
        start = bar * self.beats
        for rep in range(times):
            base = start + rep * len(toks) * step
            i = 0
            while i < len(toks):
                tok = toks[i]
                if tok in ('.', '-'):
                    i += 1
                    continue
                j = i + 1
                while j < len(toks) and toks[j] == '-':
                    j += 1
                length = (j - i) * step
                name, v = self._vel_mod(tok, vel)
                for nm in name.split('+'):
                    m = _parse_pitch(nm) + 12 * octave
                    for tr in trs:
                        self.note(tr, base + i * step, m, length * gate if j - i == 1 else length - step * (1 - gate), v)
                i = j

    def drum(self, tr, bar, pattern, step=0.25, times=1, vel=0.9, pitch=None):
        """Drum grid: x=hit, X=accent, o=soft, g=ghost, '.'=rest."""
        toks = [c for c in pattern if c not in ' |']
        start = bar * self.beats
        vmap = {'x': 1.0, 'X': 1.2, 'o': 0.6, 'g': 0.32}
        p = None if pitch is None else (_parse_pitch(pitch) if isinstance(pitch, str) else pitch)
        for rep in range(times):
            base = start + rep * len(toks) * step
            for i, c in enumerate(toks):
                if c in vmap:
                    self.tracks[tr].events.append((base + i * step, p, step, min(1.0, vel * vmap[c])))

    def _prog_steps(self, prog, step):
        b0 = prog[0][0]
        b1 = prog[-1][0] + prog[-1][1]
        n = int(round((b1 - b0) / step))
        return [(b0 + k * step, k) for k in range(n)]

    def _grid(self, tr, prog, pattern, step, vel, gate, resolve, restart_each_chord=False):
        toks = self._tokens(pattern)
        steps = self._prog_steps(prog, step)
        # resolve holds
        items = []
        chord_start = {}
        for beat, k in steps:
            c = self.chord_at(prog, beat)
            if restart_each_chord:
                cs = [b for b, d, cc in prog if b <= beat + 1e-6 < b + d][0]
                idx = int(round((beat - cs) / step)) % len(toks)
            else:
                idx = k % len(toks)
            items.append((beat, toks[idx], c))
        i = 0
        while i < len(items):
            beat, tok, c = items[i]
            if tok in ('.', '-'):
                i += 1
                continue
            j = i + 1
            while j < len(items) and items[j][1] == '-':
                j += 1
            length = (j - i) * step
            name, v = self._vel_mod(tok, vel)
            for m in resolve(name, c):
                self.tracks[tr].events.append((beat, m, length * gate if j - i == 1 else length - step * (1 - gate), v))
            i = j

    def bass(self, tr, prog, pattern, step=0.5, lo=33, vel=0.85, gate=0.9, restart_each_chord=True):
        """Tokens: R T F S (chord tones), O (octave), integers (semitones from bass note)."""
        def resolve(name, c):
            root = lo + ((c.bass - lo) % 12)
            if name == 'O':
                return [root + 12]
            if name in 'RTFS' and len(name) == 1:
                off = c.tone(name) if name != 'R' else 0
                if name != 'R' and c.bass != c.root:
                    off = (c.root + c.tone(name) - c.bass) % 12
                return [root + off]
            return [root + int(name)]
        self._grid(tr, prog, pattern, step, vel, gate, resolve, restart_each_chord)

    def arp(self, tr, prog, pattern, step=0.25, lo=60, vel=0.7, gate=0.8, restart_each_chord=False):
        def resolve(name, c):
            notes = c.voicing(lo)
            i = int(name)
            return [notes[i % len(notes)] + 12 * (i // len(notes))]
        self._grid(tr, prog, pattern, step, vel, gate, resolve, restart_each_chord)

    def stab(self, tr, prog, pattern, step=0.25, lo=60, vel=0.7, gate=0.6, restart_each_chord=False,
             spread=False, top=None, strum=0.0, bass_note=False):
        """Chord hits. Tokens: x hit, o soft hit, '-' hold, '.' rest."""
        def resolve(name, c):
            v = c.voicing(lo, spread)
            if top:
                v = v[-top:]
            if bass_note:
                v = [lo - 12 + ((c.bass - lo) % 12)] + v
            return v
        before = len(self.tracks[tr].events)
        self._grid(tr, prog, pattern, step, vel, gate, resolve, restart_each_chord)
        if strum:
            evs = self.tracks[tr].events
            k = 0
            last = None
            for i in range(before, len(evs)):
                b, m, d, v = evs[i]
                k = k + 1 if b == last else 0
                last = b
                evs[i] = (b + k * strum, m, max(step * 0.3, d - k * strum), v)

    def pad(self, tr, prog, lo=55, vel=0.6, spread=False, legato=0.98):
        for b, d, c in prog:
            for m in c.voicing(lo, spread):
                self.tracks[tr].events.append((b, m, d * legato, vel))

    def walk(self, tr, prog, lo=31, vel=0.85, gate=0.85):
        for idx, (b, d, c) in enumerate(prog):
            nxt = prog[(idx + 1) % len(prog)][2]
            root = lo + ((c.bass - lo) % 12)
            nroot = lo + ((nxt.bass - lo) % 12)
            beats = int(round(d))
            if beats >= 4:
                tones = [root, root + c.tone('T'), root + c.tone('F'),
                         nroot + (1 if nroot < root + 7 else -1)]
                seqn = tones + [root + 12] * (beats - 4)
            elif beats == 2:
                seqn = [root, nroot + (1 if (nroot - root) % 12 > 6 else -1)]
            else:
                seqn = [root] * beats
            for k, m in enumerate(seqn):
                self.tracks[tr].events.append((b + k, m, gate, vel * (1.0 if k % 2 == 0 else 0.85)))

    def duck_every(self, beats=1.0, offset=0.0, release=0.45):
        self.duck_beats = [offset + k * beats for k in range(int(self.total_beats / beats))]
        self.duck_release = release

    # ------------------------------------------------------------------ render
    def _warp(self, beat):
        if not self.swing:
            return beat
        u = self.swing_unit
        g = math.floor(beat / (2 * u) + 1e-9)
        x = beat - g * 2 * u
        d = self.swing * u / 3
        if x < u:
            y = x * (u + d) / u
        else:
            y = (u + d) + (x - u) * (u - d) / u
        return g * 2 * u + y

    def _add_wrap(self, buf, sig, pos):
        L = buf.shape[0]
        pos %= L
        m = sig.shape[0]
        i = 0
        while i < m:
            start = (pos + i) % L
            k = min(m - i, L - start)
            buf[start:start + k] += sig[i:i + k]
            i += k

    def render(self, verbose=False):
        sr = self.sr
        L = self.L
        self.track_rms = {}
        master = np.zeros((L, 2))
        rev = np.zeros((L, 2))
        dly = np.zeros((L, 2))
        dip = np.zeros(L)
        if self.duck_beats:
            rel = int(self.duck_release * self.spb * sr)
            t = np.arange(rel) / rel
            shape = (1 - t) ** 2 * np.clip(np.arange(rel) / (0.004 * sr), 0, 1)
            for b in self.duck_beats:
                p = int(round(self._warp(b) * self.spb * sr)) % L
                i = 0
                while i < rel:
                    st = (p + i) % L
                    k = min(rel - i, L - st)
                    np.maximum(dip[st:st + k], shape[i:i + k], out=dip[st:st + k])
                    i += k
        for name in self.order:
            tr = self.tracks[name]
            if not tr.events:
                continue
            cache = {}
            buf = np.zeros((L, 2))
            ang = (tr.pan + 1) * np.pi / 4
            gl, gr = math.cos(ang) * math.sqrt(2), math.sin(ang) * math.sqrt(2)
            for beat, midi, dur, vel in tr.events:
                if midi is not None:
                    midi = midi + self.transpose + 12 * tr.octave if tr.inst.pitched else midi
                f = float(mtof(midi)) if midi is not None else 0.0
                dur_s = round(dur * self.spb, 3)
                vq = round(vel * 20) / 20
                key = (round(f, 2), dur_s, vq)
                sig = cache.get(key)
                if sig is None:
                    sig = tr.inst.render(f if f else 100.0, dur_s, vq, sr)
                    cache[key] = sig
                jit = 1 + self.rng.uniform(-0.06, 0.06) if tr.humanize else 1.0
                pos = int(round((self._warp(beat) * self.spb + self.rng.uniform(-1, 1) * tr.humanize) * sr))
                if sig.ndim == 1:
                    s2 = np.empty((len(sig), 2))
                    s2[:, 0] = sig * gl * jit
                    s2[:, 1] = sig * gr * jit
                else:
                    s2 = sig * np.array([min(1, gl), min(1, gr)]) * jit
                self._add_wrap(buf, s2, pos)
            if tr.hpf or tr.lpf:
                X = np.fft.rfft(buf, axis=0)
                f = np.fft.rfftfreq(L, 1 / sr)
                g = np.ones_like(f)
                if tr.hpf:
                    g *= 1 / np.sqrt(1 + (tr.hpf / np.maximum(f, 1e-3)) ** 4)
                if tr.lpf:
                    g *= 1 / np.sqrt(1 + (f / tr.lpf) ** 4)
                buf = np.fft.irfft(X * g[:, None], L, axis=0)
            if tr.duck and self.duck_beats:
                buf *= (1 - tr.duck * dip)[:, None]
            buf *= tr.gain
            self.track_rms[name] = float(np.sqrt(np.mean(buf ** 2)) + 1e-12)
            master += buf
            if tr.rev:
                rev += buf * tr.rev
            if tr.dly:
                dly += buf * tr.dly
            if verbose:
                print('   track', name, len(tr.events), 'events', len(cache), 'unique')
        f = np.fft.rfftfreq(L, 1 / sr)
        if np.any(rev):
            ir = reverb_ir(self.rev_time, sr, seed=len(self.name), damp=self.rev_damp)
            irp = np.zeros((L, 2))
            irp[:len(ir)] = ir[:L]
            H = np.fft.rfft(irp, axis=0)
            H *= (1 / np.sqrt(1 + (220 / np.maximum(f, 1e-3)) ** 4))[:, None]
            wet = np.fft.irfft(np.fft.rfft(rev, axis=0) * H, L, axis=0)
            master += wet
        if np.any(dly):
            D = int(round(self.dly_beats * self.spb * sr))
            z = np.exp(-2j * np.pi * np.arange(len(f)) * D / L)
            Hl = 1 / np.sqrt(1 + (f / self.dly_lp) ** 2) / np.sqrt(1 + (250 / np.maximum(f, 1e-3)) ** 2)
            fb = self.dly_fb
            m = np.fft.rfft(dly.mean(axis=1))
            den = 1 - (fb * z * Hl) ** 2
            left = np.fft.irfft(m * z * Hl / den, L)
            right = np.fft.irfft(m * fb * (z * Hl) ** 2 / den, L)
            master += np.stack([left, right], axis=1)
        # master high-pass
        X = np.fft.rfft(master, axis=0)
        X *= (1 / np.sqrt(1 + (28 / np.maximum(f, 1e-3)) ** 4))[:, None]
        master = np.fft.irfft(X, L, axis=0)
        for fx in self.master_fx:
            master = fx(master, self)
        return master


# ---------------------------------------------------------------------------
# Loudness + limiter
# ---------------------------------------------------------------------------
def lufs_approx(x, sr):
    L = x.shape[0]
    X = np.fft.rfft(x, axis=0)
    f = np.fft.rfftfreq(L, 1 / sr)
    g = 1 / np.sqrt(1 + (60 / np.maximum(f, 1e-3)) ** 2)
    g *= 1 + (10 ** (4 / 20) - 1) / (1 + (1500 / np.maximum(f, 1e-3)) ** 2)
    y = np.fft.irfft(X * g[:, None], L, axis=0)
    ms = np.mean(y ** 2, axis=0).sum()
    return -0.691 + 10 * math.log10(ms + 1e-20)


def limiter(x, ceiling=0.89, block=64, r_min=6, r_avg=5):
    L = x.shape[0]
    a = np.max(np.abs(x), axis=1)
    need = np.minimum(1.0, ceiling / np.maximum(a, 1e-9))
    nb = int(math.ceil(L / block))
    padn = nb * block - L
    needp = np.concatenate([need, need[:padn]]) if padn else need
    blk = needp.reshape(nb, block).min(axis=1)
    m = blk.copy()
    for k in range(1, r_min + 1):
        m = np.minimum(m, np.minimum(np.roll(blk, k), np.roll(blk, -k)))
    avg = m.copy()
    for k in range(1, r_avg + 1):
        avg += np.roll(m, k) + np.roll(m, -k)
    avg /= (2 * r_avg + 1)
    centers = (np.arange(nb) + 0.5) * block
    gain = np.interp(np.arange(L), centers, avg, period=nb * block)
    y = x * gain[:, None]
    # final soft safety
    k = 0.8 * ceiling
    r = ceiling - k
    ab = np.abs(y)
    over = ab > k
    y[over] = np.sign(y[over]) * (k + r * np.tanh((ab[over] - k) / r))
    return y, float(np.mean(20 * np.log10(np.maximum(gain, 1e-9))))


def master_loop(x, sr, target=-14.0, ceiling_db=-1.0):
    ceiling = 10 ** (ceiling_db / 20)
    x = x - x.mean(axis=0)
    g = 10 ** ((target - lufs_approx(x, sr)) / 20)
    y, gr = limiter(x * g, ceiling)
    for _ in range(2):
        err = target - lufs_approx(y, sr)
        if abs(err) < 0.3:
            break
        g *= 10 ** (err / 20)
        if g > 1e4:
            break
        y, gr = limiter(x * g, ceiling)
    return y, {'lufs': lufs_approx(y, sr), 'avg_gr_db': gr, 'peak': float(np.max(np.abs(y)))}
