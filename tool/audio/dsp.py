"""Core DSP helpers shared by the SFX and music generators (numpy only)."""
from __future__ import annotations

import math
import numpy as np

SR = 44100
TAU = 2.0 * np.pi

_NOTE_BASE = {'C': 0, 'D': 2, 'E': 4, 'F': 5, 'G': 7, 'A': 9, 'B': 11}


# --------------------------------------------------------------------------
# Pitch helpers
# --------------------------------------------------------------------------
def note_to_midi(name: str) -> int:
    name = name.strip()
    base = _NOTE_BASE[name[0].upper()]
    i = 1
    while i < len(name) and name[i] in '#b':
        base += 1 if name[i] == '#' else -1
        i += 1
    octave = int(name[i:])
    return 12 * (octave + 1) + base


def mtof(m):
    return 440.0 * 2.0 ** ((np.asarray(m, dtype=float) - 69.0) / 12.0)


def hz(note) -> float:
    if isinstance(note, str):
        return float(mtof(note_to_midi(note)))
    return float(note)


# --------------------------------------------------------------------------
# Basic buffers
# --------------------------------------------------------------------------
def ns(dur: float, sr: int = SR) -> int:
    return max(1, int(round(dur * sr)))


def tvec(n: int, sr: int = SR) -> np.ndarray:
    return np.arange(n) / sr


def _arr(v, n):
    if np.ndim(v) == 0:
        return np.full(n, float(v))
    v = np.asarray(v, dtype=float)
    if len(v) >= n:
        return v[:n]
    return np.concatenate([v, np.full(n - len(v), v[-1])])


def cycles(freq, n, sr=SR, phase0=0.0):
    """Phase in cycles for a (possibly time varying) frequency."""
    f = _arr(freq, n)
    ph = np.cumsum(f) / sr
    return ph - ph[0] + phase0


def sweep(f0, f1, n, curve='exp', power=1.0):
    x = np.linspace(0.0, 1.0, n) ** power
    if curve == 'exp':
        return f0 * (f1 / f0) ** x
    return f0 + (f1 - f0) * x


# --------------------------------------------------------------------------
# Oscillators
# --------------------------------------------------------------------------
def sine(freq, n, sr=SR, phase0=0.0):
    return np.sin(TAU * cycles(freq, n, sr, phase0))


def _blep(p, dt):
    y = np.zeros_like(p)
    m = p < dt
    t = p[m] / dt[m]
    y[m] = t + t - t * t - 1.0
    m = p > 1.0 - dt
    t = (p[m] - 1.0) / dt[m]
    y[m] = t * t + t + t + 1.0
    return y


def saw(freq, n, sr=SR, phase0=0.0):
    """Band limited (polyBLEP) sawtooth."""
    f = _arr(freq, n)
    p = np.mod(cycles(f, n, sr, phase0), 1.0)
    dt = np.clip(np.abs(f) / sr, 1e-9, 0.5)
    return 2.0 * p - 1.0 - _blep(p, dt)


def pulse(freq, n, sr=SR, duty=0.5, phase0=0.0):
    """Band limited pulse wave (zero DC)."""
    f = _arr(freq, n)
    c = cycles(f, n, sr, phase0)
    dt = np.clip(np.abs(f) / sr, 1e-9, 0.5)
    p1 = np.mod(c, 1.0)
    p2 = np.mod(c + duty, 1.0)
    a = 2.0 * p1 - 1.0 - _blep(p1, dt)
    b = 2.0 * p2 - 1.0 - _blep(p2, dt)
    return a - b


def square(freq, n, sr=SR, phase0=0.0):
    return pulse(freq, n, sr, 0.5, phase0)


def tri(freq, n, sr=SR, phase0=0.0):
    p = np.mod(cycles(freq, n, sr, phase0 + 0.25), 1.0)
    return 4.0 * np.abs(p - 0.5) - 1.0


def naive_pulse(freq, n, sr=SR, duty=0.5, phase0=0.0):
    p = np.mod(cycles(freq, n, sr, phase0), 1.0)
    y = np.where(p < duty, 1.0, -1.0)
    return y - (2 * duty - 1)


def noise(n, seed=0):
    return np.random.default_rng(seed).uniform(-1.0, 1.0, n)


def colored_noise(n, seed=0, slope=-3.0):
    """slope in dB/octave (-3 pink, -6 brown)."""
    w = np.random.default_rng(seed).standard_normal(n)
    W = np.fft.rfft(w)
    f = np.fft.rfftfreq(n, 1.0)
    f[0] = f[1]
    W *= f ** (slope / 6.02)
    y = np.fft.irfft(W, n)
    return y / (np.max(np.abs(y)) + 1e-12)


# --------------------------------------------------------------------------
# Envelopes
# --------------------------------------------------------------------------
def env_exp(n, t60, sr=SR):
    return np.exp(-6.9 * tvec(n, sr) / max(t60, 1e-4))


def env_perc(n, attack=0.002, t60=0.3, sr=SR, curve=1.0):
    t = tvec(n, sr)
    a = np.clip(t / max(attack, 1e-5), 0, 1)
    d = np.exp(-6.9 * np.maximum(t - attack, 0) / max(t60, 1e-4))
    return a * d ** curve


def env_adsr(n, a, d, s, r, hold, sr=SR):
    """hold = gate length in seconds (from note on); release after it."""
    t = tvec(n, sr)
    e = np.where(t < a, t / max(a, 1e-5), s + (1 - s) * np.exp(-5.0 * (t - a) / max(d, 1e-4)))
    g = e[min(n - 1, int(hold * sr))] if hold * sr < n else e[-1]
    rel = np.exp(-6.9 * (t - hold) / max(r, 1e-4))
    e = np.where(t < hold, e, g * rel)
    return e


def env_points(n, pts, sr=SR):
    """Piecewise linear envelope from [(time, value), ...]."""
    t = tvec(n, sr)
    xs = [p[0] for p in pts]
    ys = [p[1] for p in pts]
    return np.interp(t, xs, ys)


def fade(x, sr=SR, fin=0.001, fout=0.01):
    x = np.array(x, dtype=float)
    n = len(x)
    a = min(n, int(fin * sr))
    b = min(n, int(fout * sr))
    if a > 0:
        x[:a] *= np.linspace(0, 1, a)
    if b > 0:
        x[n - b:] *= np.linspace(1, 0, b) ** 2
    return x


# --------------------------------------------------------------------------
# Filters
# --------------------------------------------------------------------------
def _gain_lp(f, fc, order):
    return 1.0 / np.sqrt(1.0 + (f / fc) ** (2 * order))


def _gain_hp(f, fc, order):
    with np.errstate(divide='ignore'):
        g = 1.0 / np.sqrt(1.0 + (fc / np.maximum(f, 1e-6)) ** (2 * order))
    return g


def fft_filter(x, gain_fn, sr=SR, circular=False):
    """Zero phase FFT filter. gain_fn(freqs_hz) -> gain. Works on (n,) or (n,c)."""
    x = np.asarray(x, dtype=float)
    n = x.shape[0]
    nfft = n if circular else int(2 ** math.ceil(math.log2(n + 2048)))
    X = np.fft.rfft(x, nfft, axis=0)
    f = np.fft.rfftfreq(nfft, 1.0 / sr)
    g = gain_fn(f)
    if x.ndim == 2:
        g = g[:, None]
    y = np.fft.irfft(X * g, nfft, axis=0)[:n]
    return y


def lp(x, fc, sr=SR, order=2, circular=False):
    return fft_filter(x, lambda f: _gain_lp(f, fc, order), sr, circular)


def hp(x, fc, sr=SR, order=2, circular=False):
    return fft_filter(x, lambda f: _gain_hp(f, fc, order), sr, circular)


def bp(x, lo, hi, sr=SR, order=2, circular=False):
    return fft_filter(x, lambda f: _gain_lp(f, hi, order) * _gain_hp(f, lo, order), sr, circular)


def peq(x, fc, q, gain_db, sr=SR, circular=False):
    """Bell EQ approximation in the log-frequency domain."""
    def g(f):
        lf = np.log2(np.maximum(f, 1.0) / fc)
        bw = 1.0 / q
        return 10 ** (gain_db / 20.0 * np.exp(-0.5 * (lf / (bw * 0.6)) ** 2))
    return fft_filter(x, g, sr, circular)


def svf(x, fc, q=0.707, mode='lp', sr=SR):
    """Time varying TPT state variable filter (python loop; use for short sfx)."""
    x = np.asarray(x, dtype=float)
    n = len(x)
    fcv = np.clip(_arr(fc, n), 10.0, sr * 0.45)
    g = np.tan(np.pi * fcv / sr)
    k = 1.0 / q
    a1 = 1.0 / (1.0 + g * (g + k))
    a2 = g * a1
    a3 = g * a2
    xs = x.tolist()
    A1 = a1.tolist()
    A2 = a2.tolist()
    A3 = a3.tolist()
    out = [0.0] * n
    ic1 = ic2 = 0.0
    if mode == 'lp':
        for i in range(n):
            v3 = xs[i] - ic2
            v1 = A1[i] * ic1 + A2[i] * v3
            v2 = ic2 + A2[i] * ic1 + A3[i] * v3
            ic1 = 2 * v1 - ic1
            ic2 = 2 * v2 - ic2
            out[i] = v2
    elif mode == 'bp':
        for i in range(n):
            v3 = xs[i] - ic2
            v1 = A1[i] * ic1 + A2[i] * v3
            v2 = ic2 + A2[i] * ic1 + A3[i] * v3
            ic1 = 2 * v1 - ic1
            ic2 = 2 * v2 - ic2
            out[i] = v1 * k
    else:  # hp
        for i in range(n):
            v3 = xs[i] - ic2
            v1 = A1[i] * ic1 + A2[i] * v3
            v2 = ic2 + A2[i] * ic1 + A3[i] * v3
            ic1 = 2 * v1 - ic1
            ic2 = 2 * v2 - ic2
            out[i] = xs[i] - k * v1 - v2
    return np.array(out)


def onepole_lp(x, fc, sr=SR):
    x = np.asarray(x, dtype=float)
    a = math.exp(-TAU * fc / sr)
    out = np.empty_like(x)
    y = 0.0
    b = 1 - a
    for i, v in enumerate(x.tolist()):
        y = b * v + a * y
        out[i] = y
    return out


def dc_block(x):
    return x - np.mean(x, axis=0)


# --------------------------------------------------------------------------
# Distortion / dynamics
# --------------------------------------------------------------------------
def drive(x, amount=2.0):
    return np.tanh(x * amount) / np.tanh(amount)


def bitcrush(x, bits=6):
    q = 2 ** (bits - 1)
    return np.round(x * q) / q


def normalize(x, peak=0.891):
    m = np.max(np.abs(x))
    return x * (peak / m) if m > 0 else x


def rms(x):
    return float(np.sqrt(np.mean(np.square(x)) + 1e-20))


def db(v):
    return 20 * math.log10(max(v, 1e-12))


# --------------------------------------------------------------------------
# Mixing helpers
# --------------------------------------------------------------------------
def place(buf, sig, t, sr=SR, gain=1.0):
    """Add sig into buf at time t (seconds), growing nothing (truncates)."""
    i = int(round(t * sr))
    if i >= len(buf):
        return buf
    m = min(len(sig), len(buf) - i)
    buf[i:i + m] += sig[:m] * gain
    return buf


def mix_at(total_dur, parts, sr=SR):
    """parts: list of (time_s, signal, gain)."""
    buf = np.zeros(ns(total_dur, sr))
    for p in parts:
        t, s = p[0], p[1]
        g = p[2] if len(p) > 2 else 1.0
        place(buf, s, t, sr, g)
    return buf


def reverb_ir(dur, sr=SR, seed=7, damp=5000.0, predelay=0.012, stereo=True, bright_end=1200.0):
    """Exponentially decaying filtered noise impulse response."""
    n = ns(dur, sr)
    chans = []
    for c in range(2 if stereo else 1):
        r = np.random.default_rng(seed + c * 101)
        w = r.standard_normal(n)
        t = tvec(n, sr)
        env = np.exp(-6.9 * t / dur)
        # progressively darker tail: crossfade bright -> dark
        dark = lp(w, bright_end, sr, order=1)
        bright = lp(w, damp, sr, order=1)
        mixk = np.clip(t / (dur * 0.6), 0, 1)
        v = (bright * (1 - mixk) + dark * mixk * 1.6) * env
        v[:min(n, int(0.004 * sr))] *= np.linspace(0, 1, min(n, int(0.004 * sr)))
        pd = int(predelay * sr)
        v = np.concatenate([np.zeros(pd), v])[:n]
        # a few early reflections
        for k, (dt, g) in enumerate([(0.007, 0.5), (0.013, 0.35), (0.021, 0.3), (0.029, 0.22)]):
            i = int((dt + 0.002 * c * (k % 2)) * sr)
            if i < n:
                v[i] += g * (1 if (k + c) % 2 == 0 else -1)
        chans.append(v / np.sqrt(np.sum(v ** 2)))
    return np.stack(chans, axis=1) if stereo else chans[0]


def convolve(x, ir):
    """Linear FFT convolution; x (n,) or (n,c), ir (m,) or (m,c)."""
    n = x.shape[0] + ir.shape[0] - 1
    nfft = int(2 ** math.ceil(math.log2(n)))
    X = np.fft.rfft(x, nfft, axis=0)
    H = np.fft.rfft(ir, nfft, axis=0)
    if X.ndim == 1 and H.ndim == 2:
        X = X[:, None]
    if X.ndim == 2 and H.ndim == 1:
        H = H[:, None]
    return np.fft.irfft(X * H, nfft, axis=0)[:n]


def sfx_reverb(x, dur=0.8, mix=0.2, sr=SR, damp=6000.0):
    ir = reverb_ir(dur, sr, stereo=False, damp=damp, predelay=0.005)
    wet = convolve(x, ir)
    out = np.zeros(len(wet))
    out[:len(x)] += x
    return out + wet * mix


def resample(x, ratio):
    """Change playback speed by ratio (>1 = faster/higher)."""
    n = int(len(x) / ratio)
    idx = np.arange(n) * ratio
    return np.interp(idx, np.arange(len(x)), x)


# --------------------------------------------------------------------------
# Karplus-Strong (block vectorised) and additive helpers
# --------------------------------------------------------------------------
def karplus(freq, dur, sr=SR, t60=1.0, blend=0.5, bright=6000.0, seed=0, pick=0.0):
    """Plucked string. blend: 0.5 = classic averaging (darker when larger)."""
    n = ns(dur, sr)
    P = max(2, int(math.ceil(sr / freq)))
    true_f = sr / P
    ratio = freq / true_f
    m = int(n * ratio) + 4
    nb = m // P + 2
    decay = 0.001 ** (1.0 / (true_f * t60))
    exc = np.random.default_rng(seed).uniform(-1, 1, P)
    if bright < sr / 2:
        exc = lp(np.tile(exc, 3), bright, sr, order=1)[P:2 * P]
    if pick > 0:  # comb for pick position
        d = max(1, int(P * pick))
        exc = exc - np.roll(exc, d)
    exc -= exc.mean()
    buf = np.zeros(1 + nb * P)
    buf[1:1 + P] = exc
    for b in range(1, nb):
        s0 = 1 + (b - 1) * P
        cur = decay * ((1 - blend) * buf[s0:s0 + P] + blend * buf[s0 - 1:s0 - 1 + P])
        buf[1 + b * P:1 + (b + 1) * P] = cur
    y = buf[1:]
    idx = np.arange(n) * ratio
    return np.interp(idx, np.arange(len(y)), y)


def partials(freq, n, sr, spec, vib=None):
    """spec: list of (ratio, amp, t60). Additive inharmonic synthesis."""
    t = tvec(n, sr)
    if vib is None:
        base = freq * t
    else:
        base = cycles(freq * vib, n, sr)
    y = np.zeros(n)
    for ratio, amp, t60 in spec:
        if ratio * freq >= sr * 0.47:
            continue
        y += amp * np.sin(TAU * ratio * base + ratio) * np.exp(-6.9 * t / t60)
    return y


# --------------------------------------------------------------------------
# NES style helpers
# --------------------------------------------------------------------------
_LFSR_CACHE = {}


def lfsr_sequence(short=False):
    key = short
    if key in _LFSR_CACHE:
        return _LFSR_CACHE[key]
    reg = 1
    tap = 6 if short else 1
    length = 93 if short else 32767
    out = np.empty(length)
    for i in range(length):
        fb = (reg & 1) ^ ((reg >> tap) & 1)
        reg = (reg >> 1) | (fb << 14)
        out[i] = 1.0 if (reg & 1) else -1.0
    _LFSR_CACHE[key] = out
    return out


NES_NOISE_PERIODS = [4, 8, 16, 32, 64, 96, 128, 160, 202, 254, 380, 508, 762, 1016, 2034, 4068]


def nes_noise(n, period_idx, sr=SR, short=False, period_env=None):
    """NES noise channel; period_idx 0 (high) .. 15 (low). period_env: array of idx per sample."""
    seq = lfsr_sequence(short)
    cpu = 1789773.0
    if period_env is None:
        rate = cpu / NES_NOISE_PERIODS[period_idx]
        clocks = np.floor(np.arange(n) * rate / sr).astype(np.int64)
    else:
        pe = _arr(period_env, n)
        rates = cpu / np.array(NES_NOISE_PERIODS, dtype=float)[np.clip(pe.astype(int), 0, 15)]
        clocks = np.floor(np.cumsum(rates / sr)).astype(np.int64)
    return seq[clocks % len(seq)]


def nes_frames(values, n, sr=SR, rate=60.0):
    """Turn a per-frame list of values into a per-sample step array."""
    idx = np.minimum((np.arange(n) * rate / sr).astype(int), len(values) - 1)
    return np.asarray(values, dtype=float)[idx]


def nes_pulse(freq, n, duty=0.5, sr=SR):
    return naive_pulse(freq, n, sr, duty)


def nes_tri(freq, n, sr=SR):
    p = np.mod(cycles(freq, n, sr), 1.0)
    stepv = np.floor(p * 32)
    v = np.where(stepv < 16, 15 - stepv, stepv - 16)
    return (v / 7.5) - 1.0
