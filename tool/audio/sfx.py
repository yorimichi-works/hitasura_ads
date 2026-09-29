"""Procedural sound effects. Every function returns a mono float array at SR."""
from __future__ import annotations

import numpy as np

from dsp import (SR, TAU, bitcrush, bp, colored_noise, convolve, cycles, drive, env_exp,
                 env_perc, env_points, fade, hp, hz, karplus, lp, mix_at, naive_pulse,
                 nes_frames, nes_noise, nes_pulse, nes_tri, noise, ns, partials, peq,
                 place, pulse, resample, reverb_ir, saw, sfx_reverb, sine, svf, sweep,
                 tri, tvec)

REGISTRY: dict = {}


def sfx(name, level=0.0, rms_cap=-10.0):
    """Register a generator. level: dB offset of target peak (-1 dBFS + level)."""
    def deco(fn):
        REGISTRY[name] = (fn, level, rms_cap)
        return fn
    return deco


def R(seed):
    return np.random.default_rng(seed)


def ov(*arrs):
    """Sum arrays of different lengths (zero padded)."""
    n = max(len(a) for a in arrs)
    out = np.zeros(n)
    for a in arrs:
        out[:len(a)] += a
    return out


# ---------------------------------------------------------------------------
# Building blocks
# ---------------------------------------------------------------------------
def blip(freq, dur, wave='sine', t60=None, attack=0.001, duty=0.5, sr=SR):
    n = ns(dur, sr)
    if wave == 'sine':
        y = sine(freq, n, sr)
    elif wave == 'square':
        y = pulse(freq, n, sr, duty) * 0.6
    elif wave == 'saw':
        y = saw(freq, n, sr) * 0.6
    elif wave == 'tri':
        y = tri(freq, n, sr)
    else:
        raise ValueError(wave)
    e = env_perc(n, attack, t60 if t60 else dur, sr)
    return y * e


def bell(freq, dur, t60=1.0, bright=1.0, kind='glass', sr=SR):
    n = ns(dur, sr)
    if kind == 'glass':
        spec = [(1, 1.0, t60), (2.0, 0.35 * bright, t60 * 0.5), (3.0, 0.15 * bright, t60 * 0.3),
                (4.07, 0.2 * bright, t60 * 0.25), (6.2, 0.08 * bright, t60 * 0.15)]
    elif kind == 'church':
        spec = [(0.5, 0.5, t60 * 1.3), (1, 1.0, t60), (1.19, 0.45, t60 * 0.8), (1.5, 0.35, t60 * 0.6),
                (2.0, 0.5 * bright, t60 * 0.5), (2.52, 0.25 * bright, t60 * 0.35),
                (3.0, 0.2 * bright, t60 * 0.3), (4.2, 0.12 * bright, t60 * 0.2)]
    elif kind == 'glock':
        spec = [(1, 1.0, t60), (2.76, 0.4 * bright, t60 * 0.35), (5.4, 0.2 * bright, t60 * 0.15),
                (8.93, 0.1 * bright, t60 * 0.08)]
    elif kind == 'metal':
        spec = [(1, 1.0, t60), (1.58, 0.7, t60 * 0.8), (2.34, 0.6, t60 * 0.6), (3.1, 0.45, t60 * 0.5),
                (4.07, 0.35, t60 * 0.35), (5.2, 0.25, t60 * 0.25), (6.7, 0.15, t60 * 0.2)]
    else:
        raise ValueError(kind)
    y = partials(freq, n, sr, spec)
    y *= np.clip(tvec(n, sr) / 0.0015, 0, 1)
    return y


def noise_burst(dur, lo=200, hi=8000, t60=None, attack=0.001, seed=0, sr=SR):
    n = ns(dur, sr)
    y = bp(noise(n, seed), lo, hi, sr)
    return y * env_perc(n, attack, t60 if t60 else dur, sr)


def whoosh_core(dur, f0, f1, f2=None, q=1.2, seed=0, peak_at=0.5, sr=SR):
    n = ns(dur, sr)
    x = noise(n, seed)
    if f2 is None:
        fc = sweep(f0, f1, n)
    else:
        k = int(n * peak_at)
        fc = np.concatenate([sweep(f0, f1, k), sweep(f1, f2, n - k)])
    y = svf(x, fc, q, 'bp', sr)
    t = np.linspace(0, 1, n)
    env = np.sin(np.pi * np.clip(t / (2 * peak_at), 0, 0.5)) * np.where(
        t < peak_at, 1.0, np.clip(np.cos(np.pi / 2 * np.clip((t - peak_at) / (1 - peak_at), 0, 1)), 0, 1) ** 1.5)
    return y * env


def kick_tone(f0, f1, dur, t60, sr=SR, click=0.3, sweep_t=0.05):
    n = ns(dur, sr)
    t = tvec(n, sr)
    f = f1 + (f0 - f1) * np.exp(-t / sweep_t)
    y = np.sin(TAU * cycles(f, n, sr)) * env_perc(n, 0.001, t60, sr)
    if click:
        c = noise_burst(0.01, 1000, 8000, 0.008, sr=sr, seed=3)[:n]
        y[:len(c)] += click * c
    return y


def formant_voices(dur, f0s, vowels, seed=0, glide=None, sr=SR, jitter=0.03):
    """Group of shouting/singing voices through formant filters."""
    n = ns(dur, sr)
    rng = R(seed)
    out = np.zeros(n)
    groups = {}
    t = tvec(n, sr)
    for i, f0 in enumerate(f0s):
        vib = 1 + 0.02 * np.sin(TAU * rng.uniform(4, 7) * t + rng.uniform(0, 6))
        wander = 1 + jitter * np.cumsum(rng.standard_normal(n)) / np.sqrt(n) * 3
        f = f0 * vib * wander
        if glide is not None:
            f = f * glide
        start = rng.uniform(0, 0.25) * dur
        length = rng.uniform(0.45, 0.95) * dur
        e = np.clip((t - start) / 0.08, 0, 1) * np.clip((start + length - t) / (0.3 * length), 0, 1)
        v = saw(f, n, sr) * e * rng.uniform(0.5, 1.0)
        key = vowels[i % len(vowels)]
        groups[key] = groups.get(key, 0) + v
    for (f1, f2, f3), v in groups.items():
        y = (bp(v, f1 * 0.8, f1 * 1.25, sr, order=2) * 1.0 + bp(v, f2 * 0.85, f2 * 1.15, sr, order=2) * 0.6
             + bp(v, f3 * 0.9, f3 * 1.1, sr, order=2) * 0.3)
        out += y
    return out


def applause(dur, rate=250, seed=0, env=None, sr=SR):
    n = ns(dur, sr)
    rng = R(seed)
    imp = np.zeros(n)
    k = int(rate * dur)
    pos = rng.integers(0, n, k)
    np.add.at(imp, pos, rng.uniform(0.3, 1.0, k) * rng.choice([-1, 1], k))
    clap = noise(int(0.012 * sr), seed + 1) * env_exp(int(0.012 * sr), 0.012, sr)
    y = convolve(imp, clap)[:n]
    y = bp(y, 700, 5000, sr)
    if env is not None:
        y *= env
    return y


def sparkle_cloud(dur, count, fmin, fmax, seed=0, t60=0.15, density_curve=1.0, sr=SR):
    rng = R(seed)
    parts = []
    for i in range(count):
        tt = (rng.uniform(0, 1) ** density_curve) * dur * 0.85
        f = np.exp(rng.uniform(np.log(fmin), np.log(fmax)))
        amp = rng.uniform(0.3, 1.0) * (1 - 0.6 * tt / dur)
        parts.append((tt, bell(f, t60 * 2, t60, 0.5, 'glass', sr), amp))
    return mix_at(dur, parts, sr)


def brass(freq, dur, sr=SR, bright=1.0, vib=0.006, attack=0.03, release=0.08, t60=None):
    """Additive brass-like tone with an opening filter on attack."""
    n = ns(dur + release, sr)
    t = tvec(n, sr)
    vibr = 1 + vib * np.sin(TAU * 5.5 * t) * np.clip((t - 0.15) / 0.2, 0, 1)
    ph = cycles(freq * vibr, n, sr)
    cutoff = freq * (1.5 + 5 * bright * np.clip(t / attack, 0, 1) * (0.6 + 0.4 * np.exp(-t / 0.3)))
    y = np.zeros(n)
    for k in range(1, 30):
        fk = k * freq
        if fk > sr * 0.45:
            break
        g = 1.0 / np.sqrt(1 + (fk / cutoff) ** 4)
        y += g / k * np.sin(TAU * k * ph)
    e = np.clip(t / attack, 0, 1) * np.where(t < dur, 1.0, np.exp(-6.9 * (t - dur) / release))
    if t60:
        e *= env_exp(n, t60, sr)
    return y * e


def supersaw(freq, dur, sr=SR, voices=7, detune=0.25, seed=0, cutoff=None):
    n = ns(dur, sr)
    rng = R(seed)
    y = np.zeros(n)
    for i in range(voices):
        d = (i - (voices - 1) / 2) / ((voices - 1) / 2) * detune if voices > 1 else 0
        y += saw(freq * 2 ** (d / 12), n, sr, rng.uniform(0, 1))
    y /= np.sqrt(voices)
    if cutoff:
        y = lp(y, cutoff, sr)
    return y


# ---------------------------------------------------------------------------
# UI
# ---------------------------------------------------------------------------
@sfx('tap', level=-3)
def s_tap():
    n = ns(0.06)
    y = sine(sweep(1900, 1100, n), n) * env_perc(n, 0.0005, 0.035)
    y[:ns(0.006)] += 0.35 * noise_burst(0.006, 2500, 9000, 0.004, seed=1)
    return y


@sfx('select', level=-2)
def s_select():
    a = blip(1318.5, 0.05, 'square', 0.05, duty=0.25) * 0.7 + blip(1318.5, 0.05, 'sine', 0.05) * 0.5
    b = blip(1975.5, 0.12, 'square', 0.1, duty=0.25) * 0.7 + blip(1975.5, 0.12, 'sine', 0.12) * 0.5
    return lp(mix_at(0.16, [(0, a), (0.045, b)]), 9000)


@sfx('back', level=-2)
def s_back():
    a = blip(1318.5, 0.05, 'square', 0.05, duty=0.25) * 0.7 + blip(1318.5, 0.05, 'sine', 0.05) * 0.5
    b = blip(880.0, 0.1, 'square', 0.09, duty=0.25) * 0.7 + blip(880.0, 0.1, 'sine', 0.1) * 0.5
    return lp(mix_at(0.15, [(0, a), (0.05, b)]), 8000)


@sfx('open', level=-2)
def s_open():
    n = ns(0.2)
    f = sweep(380, 1300, n, power=0.6)
    y = sine(f, n) * env_perc(n, 0.004, 0.18) + 0.25 * tri(f * 2, n) * env_perc(n, 0.004, 0.1)
    y += 0.3 * mix_at(0.2, [(0.07, bell(2637, 0.13, 0.12))])
    return y


@sfx('click', level=-4)
def s_click():
    n = ns(0.04)
    y = noise_burst(0.04, 2500, 7000, 0.008, seed=5)
    y += 0.6 * sine(3100, n) * env_exp(n, 0.012)
    y += 0.3 * sine(900, n) * env_exp(n, 0.02)
    return y


@sfx('whoosh')
def s_whoosh():
    return whoosh_core(0.45, 300, 2600, 500, q=1.4, seed=11, peak_at=0.45)


@sfx('swipe')
def s_swipe():
    return whoosh_core(0.25, 900, 5500, 3000, q=1.2, seed=12, peak_at=0.55)


@sfx('notify', level=-1)
def s_notify():
    a = bell(1318.5, 0.35, 0.3, 0.7, 'glock')
    b = bell(1760.0, 0.55, 0.5, 0.7, 'glock')
    return mix_at(0.6, [(0, a, 0.9), (0.13, b)])


@sfx('typing', level=-2)
def s_typing():
    rng = R(21)
    parts = []
    t = 0.0
    for i in range(6):
        seed = 30 + i
        clack = noise_burst(0.03, 1800, 6000, 0.012, seed=seed) * rng.uniform(0.6, 1.0)
        n = len(clack)
        clack += 0.5 * sine(rng.uniform(180, 260), n) * env_exp(n, 0.02)
        clack += 0.25 * sine(rng.uniform(2800, 3600), n) * env_exp(n, 0.006)
        parts.append((t, clack))
        t += rng.uniform(0.055, 0.1)
    return mix_at(t + 0.05, parts)


# ---------------------------------------------------------------------------
# Rewards
# ---------------------------------------------------------------------------
def _coin_tone(f, dur, t60):
    n = ns(dur)
    y = pulse(f, n, SR, 0.5) * 0.45 + sine(f, n) * 0.5 + 0.12 * sine(2 * f, n)
    return lp(y, 9000) * env_perc(n, 0.001, t60)


@sfx('coin')
def s_coin():
    a = _coin_tone(987.77, 0.075, 1.0) * np.linspace(1, 0.9, ns(0.075))
    b = _coin_tone(1318.5, 0.45, 0.45)
    y = mix_at(0.5, [(0, a), (0.07, b)])
    return y


@sfx('coins')
def s_coins():
    rng = R(40)
    notes = [2637, 3136, 3520, 3951, 2093, 4186]
    parts = []
    for i in range(16):
        tt = (i / 16) ** 1.2 * 0.75 + rng.uniform(-0.02, 0.02)
        f = notes[rng.integers(len(notes))] * rng.uniform(0.98, 1.02)
        tone = bell(f, 0.3, rng.uniform(0.12, 0.25), 0.9, 'metal') * 0.6 + bell(f, 0.3, 0.2, 0.3, 'glass') * 0.5
        parts.append((max(0, tt), tone, rng.uniform(0.5, 1.0) * (1 - 0.4 * i / 16)))
    y = mix_at(1.05, parts)
    return y + 0.5 * mix_at(1.05, [(0, s_coin())])


@sfx('cash')
def s_cash():
    drawer = noise_burst(0.08, 900, 4000, 0.06, seed=50) * 0.8
    thunk = kick_tone(160, 90, 0.12, 0.08, click=0) * 0.6
    ch1 = bell(2093, 1.0, 0.9, 1.0, 'metal') * 0.35 + bell(2093, 1.0, 0.9, 0.8, 'glass') * 0.5
    ch2 = bell(2637, 0.9, 0.8, 1.0, 'glass') * 0.5
    y = mix_at(1.1, [(0, drawer), (0, thunk), (0.09, ch1), (0.12, ch2)])
    return sfx_reverb(y, 0.6, 0.15)[:ns(1.1)]


@sfx('gem')
def s_gem():
    notes = [2637, 3136, 3951, 5274]
    parts = []
    for i, f in enumerate(notes):
        n = ns(0.5)
        t = tvec(n)
        fm = np.sin(TAU * f * t + 1.2 * np.exp(-t / 0.08) * np.sin(TAU * f * 2 * t))
        parts.append((i * 0.035, fm * env_perc(n, 0.001, 0.4), 0.8))
    y = mix_at(0.65, parts)
    y += 0.25 * sparkle_cloud(0.65, 10, 5000, 10000, seed=55, t60=0.08)
    return y


@sfx('pickup')
def s_pickup():
    n = ns(0.13)
    f = sweep(620, 1500, n, power=0.7)
    y = pulse(f, n, SR, 0.25) * 0.5 + sine(f, n) * 0.5
    return lp(y, 7000) * env_perc(n, 0.001, 0.13)


@sfx('powerup')
def s_powerup():
    notes = [523.25, 659.25, 783.99, 1046.5, 1318.5, 1568.0, 2093.0]
    parts = []
    for i, f in enumerate(notes):
        d = 0.09
        y = pulse(f, ns(d), SR, 0.5) * 0.4 + sine(f * 2, ns(d)) * 0.2
        parts.append((i * 0.055, lp(y, 8000) * env_perc(ns(d), 0.001, 0.12)))
    y = mix_at(0.6, parts)
    n = ns(0.6)
    y += 0.3 * sine(sweep(250, 2000, n), n) * env_points(n, [(0, 0), (0.05, 1), (0.4, 0.8), (0.6, 0)])
    return y


@sfx('levelup')
def s_levelup():
    notes = [523.25, 659.25, 783.99, 1046.5]
    parts = []
    for i, f in enumerate(notes):
        parts.append((i * 0.07, brass(f, 0.07, bright=1.2, attack=0.01, release=0.05) * 0.6))
        parts.append((i * 0.07, bell(f * 2, 0.3, 0.25, 0.6, 'glock') * 0.3))
    chord = sum(brass(f, 0.45, bright=1.3, attack=0.01, release=0.35) for f in [1046.5, 1318.5, 1568.0]) * 0.35
    parts.append((0.3, chord))
    parts.append((0.3, bell(2093, 0.9, 0.8, 0.8, 'glock') * 0.4))
    parts.append((0.3, sparkle_cloud(0.9, 18, 3000, 9000, seed=60, t60=0.12) * 0.3))
    y = mix_at(1.2, parts)
    return sfx_reverb(y, 0.8, 0.18)[:ns(1.2)]


@sfx('correct')
def s_correct():
    a = ov(bell(1046.5, 0.25, 0.3, 0.6, 'glock'), 0.4 * blip(1046.5, 0.2, 'square', 0.15, duty=0.5))
    b = ov(bell(1318.5, 0.6, 0.55, 0.6, 'glock'), 0.4 * blip(1318.5, 0.4, 'square', 0.3, duty=0.5),
           0.5 * bell(1975.5, 0.6, 0.5, 0.5, 'glock'))
    y = mix_at(0.75, [(0, a), (0.12, b)])
    return lp(y, 9000)


@sfx('perfect')
def s_perfect():
    n = ns(0.5)
    chord = sum(supersaw(f, 0.5, voices=5, detune=0.18, seed=i) for i, f in enumerate(
        [523.25, 659.25, 783.99, 1046.5, 1318.5]))
    chord = lp(chord, 6000) * env_perc(n, 0.002, 0.35) * 0.35
    parts = [(0, chord), (0, kick_tone(180, 60, 0.2, 0.15) * 0.6),
             (0.02, bell(2093, 0.8, 0.7, 0.9, 'glock') * 0.5),
             (0.05, sparkle_cloud(0.8, 20, 3500, 10000, seed=70, t60=0.12) * 0.4)]
    y = mix_at(0.9, parts)
    return sfx_reverb(y, 0.7, 0.18)[:ns(0.9)]


@sfx('star')
def s_star():
    notes = [2637, 3951, 3136, 4699, 3520, 5274]
    parts = [(i * 0.045, bell(f, 0.3, 0.22, 0.6, 'glock'), 1 - i * 0.08) for i, f in enumerate(notes)]
    y = mix_at(0.65, parts)
    return sfx_reverb(y, 0.6, 0.25)[:ns(0.65)]


@sfx('sparkle')
def s_sparkle():
    y = sparkle_cloud(0.6, 26, 4000, 11000, seed=80, t60=0.1, density_curve=1.4)
    n = len(y)
    y += 0.12 * hp(noise(n, 81), 7000) * env_perc(n, 0.01, 0.4)
    return y


@sfx('magic')
def s_magic():
    scale = [0, 2, 4, 7, 9]
    parts = []
    for i in range(12):
        m = 84 + scale[i % 5] + 12 * (i // 5)
        f = 440 * 2 ** ((m - 69) / 12)
        parts.append((i * 0.045, bell(f, 0.8, 0.7, 0.6, 'glass') * (0.6 + 0.03 * i)))
    y = mix_at(1.2, parts)
    n = len(y)
    y += 0.2 * svf(noise(n, 90), sweep(2000, 9000, n), 3, 'bp') * env_points(n, [(0, 0), (0.3, 1), (1.2, 0)])
    return sfx_reverb(y, 1.0, 0.3)[:ns(1.2)]


@sfx('ding')
def s_ding():
    return bell(2093.0, 1.0, 0.9, 0.8, 'glass')


@sfx('bell')
def s_bell():
    y = bell(880.0, 2.0, 1.8, 1.0, 'church')
    y[:ns(0.01)] += noise_burst(0.01, 2000, 8000, 0.006, seed=95) * 0.3
    return sfx_reverb(y, 1.2, 0.2)[:ns(2.0)]


@sfx('combo')
def s_combo():
    f = 1046.5
    y = karplus(f, 0.35, t60=0.5, blend=0.3, bright=12000, seed=100) * 0.8
    n = len(y)
    y += 0.5 * sine(f, n) * env_perc(n, 0.001, 0.25) + 0.2 * sine(2 * f, n) * env_perc(n, 0.001, 0.1)
    return y


# ---------------------------------------------------------------------------
# Negative
# ---------------------------------------------------------------------------
@sfx('wrong')
def s_wrong():
    def tone(f, d):
        n = ns(d)
        y = pulse(f, n, SR, 0.5) + 0.6 * saw(f * 1.005, n)
        return lp(y, 2200) * env_points(n, [(0, 0), (0.005, 1), (d - 0.03, 0.9), (d, 0)])
    return mix_at(0.45, [(0, tone(233.08, 0.16)), (0.2, tone(185.0, 0.23))])


@sfx('buzzer')
def s_buzzer():
    n = ns(0.7)
    t = tvec(n)
    y = saw(110, n) + saw(116.5, n) + 0.7 * pulse(55, n, SR, 0.3)
    y = drive(y * 1.5, 3) * (0.75 + 0.25 * np.sign(np.sin(TAU * 30 * t)))
    y = peq(lp(y, 5000), 1200, 1.0, 6)
    return y * env_points(n, [(0, 0), (0.005, 1), (0.62, 1), (0.7, 0)])


@sfx('hurt')
def s_hurt():
    n = ns(0.25)
    f = sweep(480, 110, n)
    y = pulse(f, n, SR, 0.25) * env_perc(n, 0.001, 0.2)
    y += noise_burst(0.25, 300, 6000, 0.08, seed=110) * 1.2
    y = bitcrush(drive(y, 3), 5)
    return lp(y, 7000)


@sfx('oops')
def s_oops():
    n = ns(0.55)
    t = tvec(n)
    f = sweep(1500, 420, n, power=1.4) * (1 + 0.03 * np.sin(TAU * 7 * t))
    y = sine(f, n) + 0.15 * sine(2 * f, n)
    y += 0.08 * bp(noise(n, 120), 1000, 4000)
    return y * env_points(n, [(0, 0), (0.02, 1), (0.45, 0.8), (0.55, 0)])


@sfx('glass')
def s_glass():
    rng = R(130)
    parts = [(0, noise_burst(0.08, 2000, 12000, 0.06, seed=131) * 1.2)]
    for i in range(40):
        tt = rng.uniform(0, 1) ** 2.2 * 0.8
        f = rng.uniform(2500, 9500)
        parts.append((tt, bell(f, 0.25, rng.uniform(0.05, 0.2), 0.8, 'metal'), rng.uniform(0.2, 0.7) * (1 - tt)))
    y = mix_at(1.0, parts)
    return sfx_reverb(y, 0.5, 0.15)[:ns(1.0)]


@sfx('crack')
def s_crack():
    parts = [(0, noise_burst(0.03, 800, 10000, 0.02, seed=140) * 1.2),
             (0.018, noise_burst(0.02, 1500, 9000, 0.012, seed=141) * 0.6),
             (0.04, noise_burst(0.015, 2000, 9000, 0.01, seed=142) * 0.35)]
    y = mix_at(0.2, parts)
    y += 0.4 * bp(y, 1200, 2000) * 3
    return y


# ---------------------------------------------------------------------------
# Impacts
# ---------------------------------------------------------------------------
@sfx('hit')
def s_hit():
    y = mix_at(0.26, [(0, kick_tone(220, 65, 0.25, 0.16, click=0) * 1.0),
                      (0, noise_burst(0.05, 900, 5000, 0.035, seed=150) * 0.9),
                      (0, noise_burst(0.006, 3000, 12000, 0.004, seed=151) * 0.6)])
    return drive(y * 1.5, 2.0)


@sfx('hit_heavy')
def s_hit_heavy():
    y = mix_at(0.85, [(0, kick_tone(160, 38, 0.8, 0.6, click=0) * 1.0),
                      (0, lp(noise_burst(0.3, 60, 6000, 0.22, seed=160), 3000) * 1.0),
                      (0, noise_burst(0.01, 2000, 12000, 0.006, seed=161) * 0.6)])
    y = drive(y * 2.0, 2.5)
    return sfx_reverb(y, 0.7, 0.12)[:ns(0.85)]


@sfx('punch')
def s_punch():
    n = ns(0.3)
    body = kick_tone(170, 55, 0.3, 0.14, click=0)
    whump = lp(noise(n, 170), 1200) * env_perc(n, 0.002, 0.07) * 2.0
    snap = noise_burst(0.02, 1500, 7000, 0.012, seed=171) * 0.5
    y = mix_at(0.3, [(0, body), (0, whump), (0.002, snap)])
    return drive(y * 1.4, 2)


@sfx('slap')
def s_slap():
    y = mix_at(0.16, [(0, noise_burst(0.04, 1000, 12000, 0.025, seed=180)),
                      (0.004, noise_burst(0.03, 1800, 4000, 0.02, seed=181) * 0.8)])
    return y + 0.4 * peq(y, 2600, 2.0, 8)


@sfx('thud')
def s_thud():
    n = ns(0.3)
    y = kick_tone(100, 45, 0.3, 0.2, click=0) + lp(noise(n, 190), 400) * env_perc(n, 0.002, 0.06) * 2
    return lp(y, 2000)


@sfx('bounce')
def s_bounce():
    n = ns(0.22)
    f = np.concatenate([sweep(160, 380, ns(0.05)), sweep(380, 330, n - ns(0.05))])
    y = sine(f, n) + 0.3 * tri(f, n)
    return y * env_perc(n, 0.001, 0.2)


@sfx('boing')
def s_boing():
    n = ns(0.7)
    t = tvec(n)
    f = sweep(190, 320, n, power=0.5) * (1 + 0.35 * np.sin(TAU * 13 * t) * np.exp(-t / 0.3))
    y = sine(f, n) + 0.35 * tri(f * 2, n) + 0.15 * saw(f, n)
    return lp(y, 5000) * env_perc(n, 0.002, 0.65)


@sfx('squish')
def s_squish():
    n = ns(0.35)
    rng = R(200)
    am = np.interp(tvec(n), np.linspace(0, 0.35, 30), rng.uniform(0.3, 1.0, 30))
    y = svf(noise(n, 201), sweep(1400, 250, n), 4, 'bp') * am * 1.2
    y += 0.6 * sine(sweep(180, 90, n), n) * env_perc(n, 0.01, 0.2)
    return y * env_points(n, [(0, 0), (0.02, 1), (0.25, 0.6), (0.35, 0)])


@sfx('splat')
def s_splat():
    y = mix_at(0.45, [(0, lp(noise_burst(0.2, 100, 6000, 0.12, seed=210), 2500) * 1.5),
                      (0, kick_tone(140, 60, 0.15, 0.08, click=0) * 0.6),
                      (0.08, s_drip() * 0.25), (0.14, s_drip() * 0.18)])
    return y


@sfx('pop')
def s_pop():
    n = ns(0.12)
    y = sine(sweep(700, 250, n, power=0.4), n) * env_perc(n, 0.0005, 0.06)
    y[:ns(0.004)] += noise_burst(0.004, 1000, 10000, 0.003, seed=220)
    return y


@sfx('bubble')
def s_bubble():
    n = ns(0.12)
    y = sine(sweep(450, 1500, n, power=0.6), n) * env_perc(n, 0.002, 0.09)
    return y


@sfx('clang')
def s_clang():
    y = ov(bell(523.0, 1.2, 1.1, 1.0, 'metal'), 0.5 * bell(1187.0, 1.0, 0.6, 1.0, 'metal'))
    y[:ns(0.015)] += noise_burst(0.015, 2000, 12000, 0.01, seed=230) * 1.5
    return sfx_reverb(y, 0.8, 0.15)[:ns(1.2)]


def _explosion(dur, seed, size=1.0):
    n = ns(dur)
    t = tvec(n)
    white = noise(n, seed)
    brown = colored_noise(n, seed + 1, -6)
    body = svf(white * 0.5 + brown * 1.2, sweep(6000 * size, 250, n, power=0.5), 0.8, 'lp')
    body *= env_points(n, [(0, 0), (0.004, 1), (0.08 * size, 0.8), (dur, 0)]) ** 1.4
    sub = sine(sweep(70, 28, n), n) * env_perc(n, 0.002, dur * 0.7) * 1.2 * size
    crackle = np.zeros(n)
    rng = R(seed + 2)
    for i in range(int(40 * size)):
        tt = rng.uniform(0.02, dur * 0.7)
        place(crackle, noise_burst(0.01, 1000, 8000, 0.006, seed=seed + 10 + i), tt,
              gain=rng.uniform(0.1, 0.5) * np.exp(-tt / (dur * 0.4)))
    y = drive(body * 1.8 + sub + crackle, 2.5)
    return y


@sfx('explode')
def s_explode():
    return sfx_reverb(_explosion(1.8, 240, 1.0), 1.2, 0.15)[:ns(1.8)]


@sfx('explode_small')
def s_explode_small():
    return _explosion(0.6, 250, 0.55)


@sfx('crash')
def s_crash():
    rng = R(260)
    parts = [(0, kick_tone(120, 40, 0.5, 0.35, click=0)), (0, lp(noise_burst(0.4, 80, 8000, 0.3, seed=261), 4000) * 1.4)]
    for i in range(5):
        parts.append((rng.uniform(0, 0.15), bell(rng.uniform(300, 900), 0.6, 0.3, 1.0, 'metal') * 0.4))
    for i in range(25):
        tt = rng.uniform(0.05, 1.0) ** 1.5
        parts.append((tt, noise_burst(0.04, 1500, 9000, rng.uniform(0.01, 0.04), seed=270 + i),
                      rng.uniform(0.1, 0.5) * (1.1 - tt)))
    for i in range(12):
        tt = rng.uniform(0.05, 0.8)
        parts.append((tt, bell(rng.uniform(3000, 8000), 0.2, 0.1, 0.8, 'metal'), rng.uniform(0.1, 0.3)))
    y = drive(mix_at(1.3, parts) * 1.3, 2)
    return sfx_reverb(y, 0.7, 0.12)[:ns(1.3)]


# ---------------------------------------------------------------------------
# Actions
# ---------------------------------------------------------------------------
@sfx('jump')
def s_jump():
    n = ns(0.2)
    f = sweep(260, 780, n, power=0.6)
    y = pulse(f, n, SR, 0.5) * 0.35 + sine(f, n) * 0.6
    return lp(y, 6000) * env_perc(n, 0.002, 0.2)


@sfx('land')
def s_land():
    n = ns(0.16)
    y = kick_tone(130, 60, 0.16, 0.08, click=0) * 0.8 + lp(noise(n, 280), 900) * env_perc(n, 0.001, 0.04) * 1.2
    return y


@sfx('shoot')
def s_shoot():
    n = ns(0.18)
    f = sweep(1500, 180, n, power=0.5)
    y = pulse(f, n, SR, 0.5) * 0.5 * env_perc(n, 0.001, 0.16)
    y += noise_burst(0.18, 500, 8000, 0.05, seed=290) * 0.9
    return lp(drive(y, 2), 8000)


@sfx('laser')
def s_laser():
    n = ns(0.3)
    t = tvec(n)
    f = sweep(2800, 140, n, power=0.6) * (1 + 0.08 * np.sin(TAU * 45 * t))
    y = saw(f, n) * 0.5 + pulse(f * 0.5, n, SR, 0.3) * 0.3
    return lp(y, 9000) * env_perc(n, 0.001, 0.28)


@sfx('throw')
def s_throw():
    return whoosh_core(0.22, 500, 3200, 900, q=1.3, seed=300, peak_at=0.4)


@sfx('swing')
def s_swing():
    y = whoosh_core(0.32, 350, 1600, 400, q=1.6, seed=310, peak_at=0.45)
    n = len(y)
    y += 0.25 * sine(sweep(90, 160, n), n) * np.sin(np.pi * np.linspace(0, 1, n))
    return y


@sfx('slash')
def s_slash():
    w = whoosh_core(0.2, 800, 6000, 2500, q=1.2, seed=320, peak_at=0.6)
    shing = partials(1, ns(0.6), SR, [(3150, 0.6, 0.5), (4420, 0.5, 0.4), (6300, 0.4, 0.35),
                                      (7700, 0.25, 0.25), (2230, 0.3, 0.4)])
    shing *= np.clip(tvec(ns(0.6)) / 0.003, 0, 1)
    return mix_at(0.7, [(0, w), (0.1, shing * 0.35), (0.1, noise_burst(0.02, 3000, 12000, 0.012, seed=321) * 0.6)])


@sfx('arrow')
def s_arrow():
    n = ns(0.35)
    twang = karplus(150, 0.35, t60=0.3, blend=0.2, bright=8000, seed=330)
    twang = twang * 0.8 + 0.2 * sine(sweep(160, 140, n), n) * env_exp(n, 0.25)
    w = whoosh_core(0.25, 1200, 4500, 1500, q=2.0, seed=331, peak_at=0.3)
    return mix_at(0.5, [(0, twang), (0.08, w * 0.9)])


@sfx('tick', level=-4)
def s_tick():
    n = ns(0.05)
    y = noise_burst(0.05, 2500, 9000, 0.006, seed=340) + 0.6 * sine(1800, n) * env_exp(n, 0.012)
    return y


@sfx('beep', level=-2)
def s_beep():
    n = ns(0.12)
    y = sine(1046.5, n) + 0.2 * pulse(1046.5, n, SR, 0.5)
    return lp(y, 6000) * env_points(n, [(0, 0), (0.003, 1), (0.1, 1), (0.12, 0)])


@sfx('scan', level=-3)
def s_scan():
    n = ns(0.15)
    y = sine(2400, n) * 0.8 + 0.3 * pulse(2400, n, SR, 0.5)
    return lp(y, 7000) * env_points(n, [(0, 0), (0.003, 1), (0.13, 1), (0.15, 0)])


@sfx('stamp')
def s_stamp():
    n = ns(0.25)
    y = kick_tone(130, 70, 0.25, 0.12, click=0)
    y += bp(noise(n, 350), 300, 900) * env_perc(n, 0.001, 0.06) * 2.5
    y += noise_burst(0.25, 2000, 8000, 0.02, seed=351) * 0.4
    return y


@sfx('hammer')
def s_hammer():
    tink = partials(1, ns(0.35), SR, [(2150, 0.6, 0.2), (3380, 0.5, 0.15), (5700, 0.3, 0.1), (1320, 0.4, 0.18)])
    tink *= np.clip(tvec(ns(0.35)) / 0.001, 0, 1)
    y = mix_at(0.35, [(0, tink * 0.7), (0, kick_tone(200, 110, 0.15, 0.06, click=0) * 0.5),
                      (0, noise_burst(0.02, 2000, 10000, 0.01, seed=360) * 0.7)])
    return y


@sfx('chop')
def s_chop():
    n = ns(0.3)
    y = bp(noise(n, 370), 600, 2200) * env_perc(n, 0.001, 0.07) * 2
    y += 0.7 * sine(sweep(260, 140, n), n) * env_perc(n, 0.001, 0.12)
    y += 0.5 * peq(noise_burst(0.3, 400, 3000, 0.1, seed=371), 900, 4, 10) * 0.3
    return drive(y * 1.2, 1.5)


@sfx('dig')
def s_dig():
    n = ns(0.4)
    rng = R(380)
    am = np.interp(tvec(n), np.linspace(0, 0.4, 60), rng.uniform(0.2, 1.0, 60))
    scrape = bp(noise(n, 381), 900, 3500) * am * env_points(n, [(0, 0), (0.01, 1), (0.2, 0.7), (0.4, 0)])
    crumbs = mix_at(0.4, [(rng.uniform(0.05, 0.3), lp(noise_burst(0.03, 100, 3000, 0.02, seed=382 + i), 1500),
                           rng.uniform(0.2, 0.5)) for i in range(10)])
    thud = kick_tone(110, 60, 0.12, 0.06, click=0) * 0.5
    return scrape * 0.8 + crumbs + mix_at(0.4, [(0, thud)])


@sfx('step', level=-2)
def s_step():
    n = ns(0.12)
    y = lp(noise(n, 390), 1400) * env_perc(n, 0.002, 0.05) * 1.5
    y += 0.6 * sine(sweep(110, 70, n), n) * env_perc(n, 0.002, 0.05)
    return y


@sfx('chomp')
def s_chomp():
    n = ns(0.25)
    t = tvec(n)
    y = mix_at(0.25, [(0, noise_burst(0.02, 1500, 8000, 0.012, seed=400) * 0.8),
                      (0.06, noise_burst(0.02, 1500, 7000, 0.015, seed=401) * 0.5)])
    mm = sine(sweep(320, 170, n), n) * (0.5 + 0.5 * np.sin(TAU * 18 * t) ** 2) * env_perc(n, 0.005, 0.2)
    return y + 0.6 * lp(mm + 0.3 * saw(sweep(320, 170, n), n) * env_perc(n, 0.005, 0.2), 2000)


@sfx('rip')
def s_rip():
    n = ns(0.4)
    rng = R(410)
    grains = np.zeros(n)
    k = 900
    pos = np.sort(rng.integers(0, int(n * 0.9), k))
    np.add.at(grains, pos, rng.uniform(-1, 1, k))
    y = bp(convolve(grains, noise(60, 411))[:n], 1500, 7000) + 0.3 * bp(noise(n, 412), 2000, 6000)
    return y * env_points(n, [(0, 0), (0.02, 0.6), (0.3, 1), (0.36, 0.8), (0.4, 0)])


@sfx('flip', level=-2)
def s_flip():
    w = whoosh_core(0.1, 1500, 5000, 3000, q=1.0, seed=420, peak_at=0.5)
    snap = noise_burst(0.02, 2000, 9000, 0.01, seed=421)
    return mix_at(0.15, [(0, w * 0.7), (0.08, snap)])


@sfx('dice')
def s_dice():
    rng = R(430)
    parts = []
    t = 0.0
    while t < 0.7:
        f = rng.uniform(2200, 4200)
        click = partials(1, ns(0.03), SR, [(f, 1.0, 0.02), (f * 1.7, 0.5, 0.012)]) * np.clip(tvec(ns(0.03)) / 0.0005, 0, 1)
        click = ov(click, noise_burst(0.01, 2000, 9000, 0.004, seed=int(t * 1000) + 431) * 0.6)
        parts.append((t, click, (1.0 - t) * rng.uniform(0.5, 1.0)))
        t += rng.uniform(0.015, 0.05) + t * 0.08
    parts.append((0, kick_tone(300, 180, 0.08, 0.04, click=0), 0.5))
    parts.append((0.3, kick_tone(300, 180, 0.08, 0.04, click=0), 0.3))
    return mix_at(0.8, parts)


# ---------------------------------------------------------------------------
# Liquid / nature / machines
# ---------------------------------------------------------------------------
@sfx('pour')
def s_pour():
    dur = 1.1
    rng = R(440)
    parts = []
    for i in range(140):
        tt = rng.uniform(0, dur - 0.1)
        base = 350 + 500 * tt / dur
        f0 = base * rng.uniform(0.8, 1.4)
        n = ns(0.04)
        chirp = sine(sweep(f0, f0 * 1.8, n), n) * env_perc(n, 0.002, 0.035)
        parts.append((tt, chirp, rng.uniform(0.15, 0.5)))
    y = mix_at(dur, parts)
    n = len(y)
    y += 0.35 * lp(noise(n, 441), 1800) * (0.7 + 0.3 * np.sin(TAU * 9 * tvec(n)))
    return y * env_points(n, [(0, 0), (0.05, 1), (dur - 0.12, 1), (dur, 0)])


@sfx('splash')
def s_splash():
    n = ns(0.7)
    y = bp(noise(n, 450), 300, 7000) * env_perc(n, 0.004, 0.45) * 1.2
    y += lp(noise(n, 451), 600) * env_perc(n, 0.002, 0.1) * 1.2
    drops = mix_at(0.7, [(0.1 + 0.06 * i, s_bubble() * (0.3 - 0.03 * i)) for i in range(6)])
    return y + drops


@sfx('drip')
def s_drip():
    n = ns(0.15)
    y = sine(sweep(700, 1900, n, power=0.3), n) * env_perc(n, 0.001, 0.08)
    return y


@sfx('sizzle')
def s_sizzle():
    dur = 1.1
    n = ns(dur)
    rng = R(460)
    y = hp(noise(n, 461), 3000) * (0.6 + 0.4 * np.interp(tvec(n), np.linspace(0, dur, 40), rng.uniform(0, 1, 40)))
    imp = np.zeros(n)
    pos = rng.integers(0, n, 350)
    np.add.at(imp, pos, rng.uniform(-1, 1, 350))
    y = y * 0.5 + hp(convolve(imp, noise(40, 462))[:n], 2000) * 0.8
    return y * env_points(n, [(0, 0), (0.05, 1), (dur - 0.15, 1), (dur, 0)])


@sfx('fire')
def s_fire():
    dur = 0.8
    n = ns(dur)
    y = lp(colored_noise(n, 470, -4), 1500) * 2.0
    y *= env_points(n, [(0, 0), (0.12, 1), (0.4, 0.8), (dur, 0)])
    rng = R(471)
    cr = mix_at(dur, [(rng.uniform(0, 0.6), noise_burst(0.008, 1500, 9000, 0.005, seed=472 + i),
                       rng.uniform(0.1, 0.5)) for i in range(25)])
    return y + cr


@sfx('wind')
def s_wind():
    dur = 1.6
    n = ns(dur)
    t = tvec(n)
    fc = 700 + 450 * np.sin(TAU * 0.9 * t) + 300 * np.sin(TAU * 2.3 * t + 1)
    y = svf(noise(n, 480), fc, 2.5, 'bp') * 1.2
    y += 0.3 * svf(noise(n, 481), fc * 2.2, 12, 'bp')
    y += 0.25 * lp(noise(n, 482), 500)
    return y * env_points(n, [(0, 0), (0.4, 1), (1.1, 0.9), (dur, 0)])


@sfx('spray')
def s_spray():
    dur = 1.0
    n = ns(dur)
    y = hp(noise(n, 490), 1800) * 0.8 + 0.5 * bp(noise(n, 491), 4000, 7000)
    y *= 0.9 + 0.1 * np.sin(TAU * 23 * tvec(n))
    y += 0.2 * saw(118, n) * 0.5
    return y * env_points(n, [(0, 0), (0.03, 1), (dur - 0.1, 1), (dur, 0)])


@sfx('scrub')
def s_scrub():
    dur = 0.6
    n = ns(dur)
    t = tvec(n)
    am = np.abs(np.sin(TAU * 5.5 * t)) ** 0.7
    y = bp(noise(n, 500), 1800, 6000) * am
    return y * env_points(n, [(0, 0), (0.02, 1), (dur - 0.08, 1), (dur, 0)])


@sfx('engine')
def s_engine():
    dur = 1.1
    n = ns(dur)
    t = tvec(n)
    f0 = np.interp(t, [0, 0.15, 0.6, 1.1], [38, 45, 115, 80])
    ph = cycles(f0, n)
    firing = (np.mod(ph, 1.0) < 0.25).astype(float)
    y = lp(firing - firing.mean(), 900) * 2.0
    y += 0.6 * saw(f0 * 2, n) * 0.5 + 0.4 * pulse(f0, n, SR, 0.3) * 0.5
    y = drive(lp(y, 2500) * 2.0, 2.5)
    return y * env_points(n, [(0, 0), (0.03, 0.7), (0.6, 1), (dur, 0)])


@sfx('zap')
def s_zap():
    n = ns(0.35)
    rng = R(510)
    gate = (np.interp(tvec(n), np.linspace(0, 0.35, 40), rng.uniform(0, 1, 40)) > 0.35).astype(float)
    buzz = saw(120 * (1 + 0.3 * lp(noise(n, 511), 200)), n)
    y = hp(noise(n, 512), 2000) * 0.6 + buzz * 0.6
    y = drive(y * gate * 2, 2) * env_perc(n, 0.001, 0.3)
    return lp(y, 9000)


@sfx('spin')
def s_spin():
    dur = 1.0
    parts = []
    t = 0.0
    i = 0
    while t < dur - 0.03:
        f = 2600 if i % 2 else 2000
        n = ns(0.02)
        c = ov(sine(f, n) * env_exp(n, 0.01) * 0.6, noise_burst(0.02, 2000, 8000, 0.005, seed=520 + i % 7))
        parts.append((t, c, 0.8))
        t += 0.042
        i += 1
    y = mix_at(dur, parts)
    n = len(y)
    y += 0.15 * bp(noise(n, 530), 300, 1200)
    return y * env_points(n, [(0, 1), (dur - 0.05, 1), (dur, 0)])


@sfx('reel_stop')
def s_reel_stop():
    y = mix_at(0.3, [(0, kick_tone(170, 80, 0.2, 0.1, click=0) * 0.8),
                     (0, noise_burst(0.02, 1500, 8000, 0.01, seed=540) * 0.8),
                     (0.005, bell(1200, 0.25, 0.15, 1.0, 'metal') * 0.3)])
    return y


@sfx('shake')
def s_shake():
    rng = R(550)
    parts = []
    for s in range(3):
        base = s * 0.15
        for k in range(14):
            tt = base + rng.uniform(0, 0.07)
            f = rng.uniform(1800, 3800)
            n = ns(0.02)
            c = ov(sine(f, n) * env_exp(n, 0.01) * 0.5, noise_burst(0.02, 1500, 7000, 0.006, seed=551 + s * 20 + k))
            parts.append((tt, c, rng.uniform(0.3, 0.8)))
    return mix_at(0.5, parts)


@sfx('rarity_up')
def s_rarity_up():
    rise_d = 0.9
    n = ns(rise_d)
    f = sweep(180, 1500, n, power=1.6)
    r = sum(saw(f * 2 ** (d / 12), n, SR, i * 0.3) for i, d in enumerate([-0.15, 0, 0.15]))
    r = svf(r, sweep(400, 9000, n, power=1.5), 1.5, 'lp') * env_points(n, [(0, 0), (0.1, 0.5), (rise_d, 1)])
    r += 0.3 * hp(noise(n, 560), 2000) * np.linspace(0, 1, n) ** 2
    hit_n = ns(0.7)
    chord = sum(supersaw(fq, 0.7, voices=5, detune=0.2, seed=j) for j, fq in enumerate([1046.5, 1318.5, 1568.0, 2093.0]))
    chord = lp(chord, 7000) * env_perc(hit_n, 0.002, 0.5) * 0.3
    hit = ov(chord, bell(2093, 0.7, 0.6, 0.8, 'glock') * 0.5, kick_tone(160, 50, 0.4, 0.25, click=0) * 0.6)
    hit += hp(noise(hit_n, 561), 5000) * env_perc(hit_n, 0.001, 0.4) * 0.3
    y = mix_at(1.6, [(0, r * 0.5), (rise_d, hit)])
    return sfx_reverb(y, 0.9, 0.2)[:ns(1.6)]


@sfx('ssr', rms_cap=-9)
def s_ssr():
    dur = 2.8
    riser_d = 0.55
    n = ns(riser_d)
    riser = svf(noise(n, 570), sweep(800, 10000, n, power=1.5), 2, 'bp') * np.linspace(0, 1, n) ** 2
    arp = mix_at(riser_d, [(i * 0.045, bell(440 * 2 ** ((72 + [0, 4, 7][i % 3] + 12 * (i // 3) - 69) / 12),
                                               0.3, 0.25, 0.6, 'glock'), 0.4 + 0.05 * i) for i in range(12)])
    hn = ns(dur - riser_d)
    th = tvec(hn)
    chord_notes = [130.81, 196.0, 261.63, 329.63, 392.0, 523.25, 659.25, 783.99]
    pad = sum(supersaw(fq, dur - riser_d, voices=5, detune=0.22, seed=10 + j) for j, fq in enumerate(chord_notes))
    pad = lp(pad, 6500) * env_points(hn, [(0, 0), (0.005, 1), (0.4, 0.7), (dur - riser_d, 0)]) * 0.2
    brassy = sum(brass(fq, 1.2, bright=1.3, attack=0.01, release=0.8) for fq in [523.25, 659.25, 783.99])
    bells = sum(bell(fq, 2.0, 1.8, 0.8, 'glock') * 0.35 for fq in [1046.5, 1318.5, 1568.0, 2093.0])
    boom = kick_tone(120, 32, 1.2, 1.0, click=0) * 1.2
    crash = hp(noise(hn, 571), 4000) * env_perc(hn, 0.001, 1.6) * 0.35
    sparkle = sparkle_cloud(dur - riser_d, 50, 3000, 11000, seed=572, t60=0.15, density_curve=1.3) * 0.5
    shimmer = sine(2093 * (1 + 0.004 * np.sin(TAU * 6 * th)), hn) * env_points(hn, [(0, 0), (0.3, 0.2), (2.2, 0)])
    y = mix_at(dur, [(0, riser * 0.5), (0, arp * 0.6), (riser_d, pad), (riser_d, brassy * 0.25),
                     (riser_d, bells), (riser_d, boom), (riser_d, crash), (riser_d + 0.05, sparkle),
                     (riser_d, shimmer)])
    y = drive(y * 1.2, 1.3)
    return sfx_reverb(y, 1.6, 0.25)[:ns(dur)]


def _snare_hit(seed, dur=0.15, tone=190):
    n = ns(dur)
    y = bp(noise(n, seed), 1200, 9000) * env_perc(n, 0.001, dur * 0.8) * 0.9
    y += 0.5 * sine(tone, n) * env_perc(n, 0.001, 0.05)
    return y


def _crash_cym(dur, seed):
    n = ns(dur)
    t = tvec(n)
    metal = sum(pulse(f, n, SR, 0.5) for f in [205.3, 304.4, 369.6, 522.7, 540.0, 800.0]) / 6
    y = hp(metal, 5000) * 0.6 + hp(noise(n, seed), 3500) * 0.8
    return y * env_perc(n, 0.001, dur * 0.9)


@sfx('drumroll')
def s_drumroll():
    dur = 2.4
    parts = []
    t = 0.0
    i = 0
    while t < 1.6:
        vel = 0.25 + 0.75 * (t / 1.6) ** 1.5
        parts.append((t, _snare_hit(600 + i % 11, 0.09), vel * (0.8 if i % 2 else 1.0)))
        t += 0.042
        i += 1
    parts.append((1.62, _crash_cym(0.8, 610), 1.1))
    parts.append((1.62, kick_tone(150, 50, 0.4, 0.3, click=0.2), 1.0))
    parts.append((1.62, _snare_hit(611, 0.2), 1.0))
    y = mix_at(dur, parts)
    return sfx_reverb(y, 0.8, 0.15)[:ns(dur)]


@sfx('fanfare')
def s_fanfare():
    notes = [(0.0, 392.0, 0.1), (0.12, 392.0, 0.1), (0.24, 392.0, 0.1), (0.36, 523.25, 0.45),
             (0.85, 659.25, 0.18), (1.05, 783.99, 0.95)]
    parts = []
    for t0, f, d in notes:
        parts.append((t0, brass(f, d, bright=1.2, attack=0.02, release=0.12), 0.5))
        parts.append((t0, brass(f / 2, d, bright=0.8, attack=0.02, release=0.12), 0.25))
    for f in [261.63, 329.63, 392.0]:
        parts.append((1.05, brass(f, 0.95, bright=0.9, attack=0.05, release=0.2), 0.25))
    parts.append((1.05, _crash_cym(1.0, 620), 0.5))
    parts.append((0.36, kick_tone(110, 50, 0.4, 0.3, click=0), 0.6))
    parts.append((1.05, kick_tone(110, 45, 0.6, 0.5, click=0), 0.8))
    y = mix_at(2.2, parts)
    return sfx_reverb(y, 1.0, 0.2)[:ns(2.2)]


@sfx('jingle_win')
def s_jingle_win():
    st = 60 / 176 / 2  # eighth notes at 176 bpm
    mel = [(0, 'C5'), (1, 'E5'), (2, 'G5'), (3, 'C6'), (4.5, 'G5'), (5, 'C6'), (6, 'E6')]
    parts = []
    for i, (pos, nm) in enumerate(mel):
        f = hz(nm)
        d = st * (2.8 if i == len(mel) - 1 else 0.8)
        n = ns(d + 0.1)
        lead = pulse(f, n, SR, 0.25) * 0.5 * env_points(n, [(0, 0), (0.004, 1), (d, 0.8), (d + 0.1, 0)])
        parts.append((pos * st, lp(lead, 7000), 0.6))
        parts.append((pos * st, bell(f, 0.5, 0.4, 0.6, 'glock'), 0.35))
    for pos, nm in [(0, 'C3'), (2, 'G2'), (4.5, 'G2'), (6, 'C3')]:
        f = hz(nm)
        parts.append((pos * st, tri(f, ns(0.25)) * env_perc(ns(0.25), 0.002, 0.25), 0.6))
    end = 6 * st
    for f in [523.25, 659.25, 783.99]:
        parts.append((end, supersaw(f, 0.8, voices=5, detune=0.18, seed=int(f)) * env_perc(ns(0.8), 0.003, 0.7), 0.12))
    for pos in [0, 2, 4.5, 6]:
        parts.append((pos * st, kick_tone(160, 55, 0.2, 0.15, click=0.2), 0.5))
    for pos in [1, 3, 5]:
        parts.append((pos * st, _snare_hit(630 + int(pos)), 0.35))
    parts.append((end, _crash_cym(1.0, 640), 0.35))
    y = mix_at(1.9, parts)
    return sfx_reverb(y, 0.8, 0.15)[:ns(1.9)]


@sfx('jingle_lose')
def s_jingle_lose():
    seq = [(0.0, 293.66, 0.26), (0.3, 277.18, 0.26), (0.6, 261.63, 0.26), (0.9, 246.94, 0.6)]
    parts = []
    for i, (t0, f, d) in enumerate(seq):
        n = ns(d + 0.1)
        t = tvec(n)
        vib = 1 + (0.02 * np.sin(TAU * 6 * t) * np.clip((t - 0.1) / 0.1, 0, 1) if i == 3 else 0)
        wah = 0.5 - 0.5 * np.cos(TAU * np.clip(t / d, 0, 1) * (3 if i == 3 else 1))
        ph = cycles(f * vib * (1 - 0.03 * np.clip(t / d, 0, 1)), n)
        y = sum(np.sin(TAU * k * ph) / k * (1.0 / np.sqrt(1 + (k * f / (f * (1.5 + 5 * wah))) ** 4))
                for k in range(1, 24) if k * f < 18000)
        y = y * env_points(n, [(0, 0), (0.03, 1), (d, 0.9), (d + 0.1, 0)])
        parts.append((t0, y, 0.6))
    return mix_at(1.65, parts)


@sfx('count', level=-1)
def s_count():
    n = ns(0.2)
    y = sine(880, n) + 0.25 * pulse(880, n, SR, 0.5) + 0.2 * sine(1760, n)
    return lp(y, 6000) * env_points(n, [(0, 0), (0.003, 1), (0.14, 0.9), (0.2, 0)])


@sfx('go')
def s_go():
    n = ns(0.5)
    y = sum(sine(f, n) + 0.25 * pulse(f, n, SR, 0.5) for f in [1760, 1108.73, 1318.5])
    y = lp(y, 7000) * env_points(n, [(0, 0), (0.003, 1), (0.3, 0.85), (0.5, 0)])
    return y


@sfx('whistle')
def s_whistle():
    n = ns(0.55)
    t = tvec(n)
    trill = 1 + 0.03 * np.sign(np.sin(TAU * 28 * t))
    f = 2850 * trill
    y = sine(f, n) + 0.2 * sine(2 * f, n)
    y *= 0.8 + 0.2 * np.sin(TAU * 28 * t)
    y += 0.25 * bp(noise(n, 650), 2000, 5000)
    return y * env_points(n, [(0, 0), (0.02, 1), (0.47, 1), (0.55, 0)])


@sfx('cheer')
def s_cheer():
    dur = 2.1
    rng = R(660)
    n = ns(dur)
    f0s = rng.uniform(170, 420, 28)
    t = tvec(n)
    rise = 1 + 0.12 * np.clip(t / 0.4, 0, 1)
    vowels = [(750, 1300, 2600), (600, 1700, 2700), (500, 900, 2500), (400, 2000, 2800)]
    v = formant_voices(dur, f0s, vowels, seed=661, glide=rise)
    v /= np.max(np.abs(v)) + 1e-9
    cl = applause(dur, 320, seed=662)
    cl /= np.max(np.abs(cl)) + 1e-9
    wash = bp(noise(n, 663), 400, 3000)
    y = v * 0.7 + cl * 0.45 + wash * 0.08
    y *= env_points(n, [(0, 0), (0.12, 1), (1.3, 0.9), (dur, 0)])
    return sfx_reverb(y, 1.0, 0.25)[:n]


@sfx('aww')
def s_aww():
    dur = 1.6
    rng = R(670)
    n = ns(dur)
    t = tvec(n)
    glide = 2 ** (-6 / 12 * np.clip(t / dur, 0, 1) ** 1.2)
    f0s = rng.uniform(150, 300, 22)
    v = formant_voices(dur, f0s, [(570, 840, 2410), (640, 1000, 2500)], seed=671, glide=glide * 1.1, jitter=0.02)
    v /= np.max(np.abs(v)) + 1e-9
    y = v * env_points(n, [(0, 0), (0.1, 1), (0.9, 0.8), (dur, 0)])
    return sfx_reverb(y, 1.0, 0.25)[:n]


@sfx('heartbeat')
def s_heartbeat():
    lub = kick_tone(70, 40, 0.2, 0.15, click=0)
    dub = kick_tone(80, 45, 0.18, 0.12, click=0) * 0.7
    y = mix_at(0.7, [(0, lub), (0.24, dub)])
    return lp(drive(y * 1.5, 1.5), 500)


@sfx('horror')
def s_horror():
    dur = 1.6
    n = ns(dur)
    t = tvec(n)
    cluster = [130.81, 138.59, 185.0, 196.0, 277.18, 293.66, 369.99, 392.0]
    trem = 0.75 + 0.25 * np.sin(TAU * 11 * t)
    stab = sum(supersaw(f, dur, voices=3, detune=0.1, seed=i) for i, f in enumerate(cluster)) * trem
    stab = lp(stab, 5000) * env_points(n, [(0, 0), (0.005, 1), (0.2, 0.6), (dur, 0)]) * 0.25
    scr_f = sweep(1800, 3200, n) * (1 + 0.04 * np.sin(TAU * 9 * t))
    screech = (sine(scr_f, n) + 0.4 * saw(scr_f, n)) * env_points(n, [(0, 0), (0.05, 0.5), (0.5, 0.4), (dur, 0)]) * 0.3
    boom = kick_tone(90, 30, 1.2, 1.0, click=0)
    y = ov(stab, lp(screech, 7000), boom * 0.6)
    return sfx_reverb(drive(y * 1.2, 1.5), 1.5, 0.3)[:n]


@sfx('glitch')
def s_glitch():
    rng = R(690)
    src_n = ns(0.3)
    src = saw(sweep(300, 900, src_n), src_n) * 0.5 + noise(src_n, 691) * 0.3 + pulse(1200, src_n, SR, 0.3) * 0.3
    out = []
    total = 0
    while total < ns(0.42):
        L = int(rng.choice([220, 441, 882, 1323]))
        st = rng.integers(0, src_n - L)
        chunk = src[st:st + L]
        reps = rng.integers(1, 4)
        for _ in range(reps):
            c = chunk.copy()
            if rng.uniform() < 0.4:
                c = resample(c, rng.choice([0.5, 2.0]))
            if rng.uniform() < 0.5:
                c = bitcrush(c, int(rng.integers(3, 6)))
            c = fade(c, fin=0.0005, fout=0.001)
            out.append(c)
            total += len(c)
        if rng.uniform() < 0.3:
            out.append(np.zeros(int(rng.integers(100, 800))))
    return np.concatenate(out)[:ns(0.42)]


# ---------------------------------------------------------------------------
# 8-bit (NES 2A03 style)
# ---------------------------------------------------------------------------
def _vol_env(frames, start=15, decay_per_frame=1.0):
    return [max(0, round(start - i * decay_per_frame)) / 15 for i in range(frames)]


@sfx('p_jump')
def s_p_jump():
    n = ns(0.2)
    fr = 12
    freqs = [260 * (1.12 ** i) for i in range(fr)]
    f = nes_frames(freqs, n)
    v = nes_frames(_vol_env(fr, 15, 1.1), n)
    return nes_pulse(f, n, 0.25) * v


@sfx('p_coin')
def s_p_coin():
    n = ns(0.45)
    fr = 27
    freqs = [987.77] * 4 + [1318.5] * (fr - 4)
    vols = [1.0] * 4 + [max(0, 15 - i * 0.65) / 15 for i in range(fr - 4)]
    return nes_pulse(nes_frames(freqs, n), n, 0.5) * nes_frames(vols, n)


@sfx('p_shoot')
def s_p_shoot():
    n = ns(0.16)
    fr = 10
    f = nes_frames([1400 * 0.82 ** i for i in range(fr)], n)
    v = nes_frames(_vol_env(fr, 15, 1.5), n)
    y = nes_pulse(f, n, 0.125) * v * 0.7
    y += nes_noise(n, 2) * nes_frames(_vol_env(fr, 10, 2.5), n) * 0.5
    return y


@sfx('p_explode')
def s_p_explode():
    n = ns(0.75)
    fr = 45
    pe = nes_frames([min(15, 6 + i // 4) for i in range(fr)], n)
    v = nes_frames(_vol_env(fr, 15, 0.34), n)
    return nes_noise(n, 0, period_env=pe) * v


@sfx('p_hit')
def s_p_hit():
    n = ns(0.16)
    fr = 10
    y = nes_noise(n, 4) * nes_frames(_vol_env(fr, 15, 2), n) * 0.7
    y += nes_pulse(nes_frames([220 * 0.88 ** i for i in range(fr)], n), n, 0.125) * nes_frames(_vol_env(fr, 12, 1.5), n) * 0.6
    return y


@sfx('p_powerup')
def s_p_powerup():
    n = ns(0.72)
    base = [261.63, 329.63, 392.0]
    freqs = []
    for step in range(14):
        for k in range(3):
            freqs.append(base[k] * 2 ** (step / 12 * 1.0))
    freqs = freqs[:43]
    v = nes_frames([1.0 if i < 36 else (43 - i) / 7 for i in range(43)], n)
    return nes_pulse(nes_frames(freqs, n), n, 0.5) * v * 0.8


@sfx('p_select')
def s_p_select():
    n = ns(0.1)
    f = nes_frames([1046.5, 1046.5, 1568.0, 1568.0, 1568.0, 1568.0], n)
    v = nes_frames([1, 1, 1, 0.8, 0.5, 0.2], n)
    return nes_pulse(f, n, 0.125) * v


@sfx('p_die')
def s_p_die():
    n = ns(1.15)
    seq = []
    for nm, frames in [('B4', 5), ('F5', 8), ('F5', 5), ('F5', 5), ('E5', 7), ('D5', 7), ('C5', 10), ('G4', 8), ('C4', 14)]:
        seq += [hz(nm)] * frames
    vols = [1.0] * (len(seq) - 10) + [(10 - i) / 10 for i in range(10)]
    y = nes_pulse(nes_frames(seq, n), n, 0.5) * nes_frames(vols, n) * 0.6
    bass = [hz('G3')] * 20 + [hz('E3')] * 15 + [hz('C3')] * (len(seq) - 35)
    y += nes_tri(nes_frames(bass, n), n) * nes_frames(vols, n) * 0.5
    return y


# ---------------------------------------------------------------------------
def finalize(x, level_db=0.0, rms_cap_db=-10.0, sr=SR):
    x = np.asarray(x, dtype=float)
    x = np.nan_to_num(x)
    x = hp(x, 25, sr, order=2)
    x = x - np.mean(x)
    fo = 0.004 if len(x) < ns(0.08) else 0.012
    x = fade(x, sr, fin=0.0006, fout=fo)
    peak_target = 10 ** ((-1.0 + level_db) / 20)
    m = np.max(np.abs(x))
    if m <= 0:
        return x
    x = x * (peak_target / m)
    win = max(1, int(0.05 * sr))
    if len(x) > win:
        c = np.cumsum(np.concatenate([[0.0], x ** 2]))
        st = np.sqrt((c[win:] - c[:-win]) / win)
        mx = float(np.max(st))
    else:
        mx = float(np.sqrt(np.mean(x ** 2)))
    cap = 10 ** ((rms_cap_db + level_db) / 20)
    floor = 10 ** ((-17.0 + level_db) / 20)
    if mx > cap:
        x *= cap / mx
    elif mx < floor:
        # spiky sound: raise body level, soft-limit the transient peaks
        g = min(2.5, floor / mx)
        x = soft_limit(x * g, peak_target)
    return x


def soft_limit(x, ceiling=0.891, knee=0.65):
    k = knee * ceiling
    a = np.abs(x)
    over = a > k
    y = x.copy()
    r = ceiling - k
    y[over] = np.sign(x[over]) * (k + r * np.tanh((a[over] - k) / r))
    return y


def render_all(names=None):
    out = {}
    for name, (fn, level, cap) in REGISTRY.items():
        if names and name not in names:
            continue
        out[name] = finalize(fn(), level, cap)
    return out
