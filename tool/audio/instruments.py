"""Instruments for the music sequencer.

Every instrument implements render(freq, dur, vel, sr) -> mono np.ndarray (or (n,2)
when `stereo` is True). `dur` is the gate length in seconds; the returned buffer may be
longer (release tail).
"""
from __future__ import annotations

import numpy as np

from dsp import (TAU, bp, colored_noise, cycles, drive, env_exp, env_perc, hp, karplus, lp,
                 naive_pulse, nes_noise, nes_tri, noise, ns, pulse, saw, sine, tri, tvec)


def _gate_env(n, sr, dur, a, d, s, r):
    t = tvec(n, sr)
    e = np.where(t < a, t / max(a, 1e-5), s + (1 - s) * np.exp(-(t - a) / max(d, 1e-4)))
    gi = min(n - 1, int(dur * sr))
    g = e[gi]
    e = np.where(t < dur, e, g * np.exp(-6.9 * (t - dur) / max(r, 1e-4)))
    return e


class Inst:
    stereo = False
    pitched = True

    def render(self, f, dur, vel, sr):
        raise NotImplementedError


# ---------------------------------------------------------------------------
# Additive subtractive-style synth (band limited, time-varying "filter")
# ---------------------------------------------------------------------------
class Sub(Inst):
    """Saw/square/tri harmonics shaped by a key-tracked cutoff envelope.

    cutoff multiple of f: base + env * exp(-t/decay); res adds a resonant bump.
    """

    def __init__(self, wave='saw', a=0.005, d=0.3, s=0.6, r=0.08, base=3.0, env=8.0,
                 fdecay=0.15, res=0.0, maxh=48, vib=0.0, vib_rate=5.5, vib_delay=0.2,
                 detune=0.0, drive_amt=0.0, cutoff_max=16000, slope=4, duty=0.5, glide=0.0,
                 attack_open=0.0):
        self.__dict__.update(locals())
        del self.__dict__['self']

    def render(self, f, dur, vel, sr):
        n = ns(dur + self.r, sr)
        t = tvec(n, sr)
        vib = 1.0
        if self.vib:
            vib = 1 + self.vib * np.sin(TAU * self.vib_rate * t) * np.clip((t - self.vib_delay) / 0.15, 0, 1)
        fcm = self.base + self.env * vel * np.exp(-t / self.fdecay)
        if self.attack_open:
            fcm = fcm * np.clip(t / self.attack_open, 0.25, 1.0)
        fc = np.minimum(f * fcm, self.cutoff_max)
        voices = [0.0] if not self.detune else [-self.detune, self.detune]
        y = np.zeros(n)
        D = 16
        fcd = fc[::D]
        for vi, dt in enumerate(voices):
            ff = f * 2 ** (dt / 12)
            ph = cycles(ff * vib, n, sr, phase0=0.37 * vi)
            z1 = np.exp(1j * TAU * ph)
            zk = z1.copy()
            for k in range(1, self.maxh + 1):
                fk = k * ff
                if fk > sr * 0.45:
                    break
                if k > 1:
                    zk *= z1
                if self.wave == 'saw':
                    amp = 1.0 / k
                elif self.wave == 'square':
                    if k % 2 == 0:
                        continue
                    amp = 1.0 / k
                elif self.wave == 'pulse':
                    amp = abs(np.sin(np.pi * k * self.duty)) / k
                    if amp < 1e-4:
                        continue
                elif self.wave == 'tri':
                    if k % 2 == 0:
                        continue
                    amp = 1.0 / (k * k)
                else:
                    raise ValueError(self.wave)
                x = fk / fcd
                g = 1.0 / np.sqrt(1.0 + x ** self.slope)
                if self.res:
                    g = g + self.res * np.exp(-0.5 * (np.log2(np.maximum(x, 1e-6)) / 0.18) ** 2)
                if g.max() < 1e-4:
                    break
                g = np.repeat(g * amp, D)[:n]
                y += g * zk.imag
        y /= len(voices)
        y *= _gate_env(n, sr, dur, self.a, self.d, self.s, self.r)
        if self.drive_amt:
            y = drive(y * (1 + self.drive_amt), 1 + self.drive_amt)
        return y * vel


# ---------------------------------------------------------------------------
class Supersaw(Inst):
    stereo = True

    def __init__(self, voices=6, detune=0.22, a=0.01, d=0.4, s=0.8, r=0.3, cutoff=5000,
                 key_cut=0.0, bright_env=0.0, bright_decay=0.2, octave_mix=0.0, vib=0.0):
        self.__dict__.update(locals())
        del self.__dict__['self']

    def render(self, f, dur, vel, sr):
        n = ns(dur + self.r, sr)
        rng = np.random.default_rng(int(f * 10) % 9973)
        L = np.zeros(n)
        R = np.zeros(n)
        t = tvec(n, sr)
        vib = 1 + self.vib * np.sin(TAU * 5.2 * t) if self.vib else 1.0
        for i in range(self.voices):
            d = (i - (self.voices - 1) / 2) / max(1, (self.voices - 1) / 2) * self.detune
            v = saw(f * vib * 2 ** (d / 12), n, sr, rng.uniform(0, 1))
            if i % 2 == 0:
                L += v
                R += v * 0.35
            else:
                R += v
                L += v * 0.35
        if self.octave_mix:
            o = saw(f * 2, n, sr, 0.1) * self.octave_mix
            L += o
            R += o
        cut = self.cutoff + self.key_cut * f
        y = np.stack([L, R], axis=1) / np.sqrt(self.voices)
        if self.bright_env:
            dark = lp(y, cut, sr)
            bright = lp(y, min(cut * (1 + self.bright_env), 16000), sr)
            m = np.exp(-t / self.bright_decay)[:, None]
            y = dark * (1 - m) + bright * m
        else:
            y = lp(y, cut, sr)
        e = _gate_env(n, sr, dur, self.a, self.d, self.s, self.r)
        return y * e[:, None] * vel


# ---------------------------------------------------------------------------
class FM(Inst):
    """2-operator FM (+ optional second modulator) for bells, EP, glock, bass."""

    def __init__(self, ratio=1.0, index=2.0, idecay=0.3, isus=0.2, a=0.002, t60=1.0, r=0.1,
                 ratio2=None, index2=0.0, idecay2=0.02, sustain=False, s=0.7, d=0.5,
                 tremolo=0.0, key_decay=True, fb_saw=0.0):
        self.__dict__.update(locals())
        del self.__dict__['self']

    def render(self, f, dur, vel, sr):
        t60 = self.t60
        if self.key_decay:
            t60 = t60 * np.clip((440.0 / f) ** 0.35, 0.4, 2.0)
        length = dur + self.r if self.sustain else max(dur + self.r, min(t60, 4.0))
        n = ns(length, sr)
        t = tvec(n, sr)
        I = self.index * vel * (self.isus + (1 - self.isus) * np.exp(-t / self.idecay))
        mod = I * np.sin(TAU * f * self.ratio * t)
        if self.ratio2:
            mod = mod + self.index2 * vel * np.exp(-t / self.idecay2) * np.sin(TAU * f * self.ratio2 * t)
        y = np.sin(TAU * f * t + mod)
        if self.sustain:
            e = _gate_env(n, sr, dur, self.a, self.d, self.s, self.r)
        else:
            e = np.clip(t / max(self.a, 1e-4), 0, 1) * np.exp(-6.9 * t / t60)
            e *= np.where(t < dur, 1.0, np.exp(-6.9 * (t - dur) / max(self.r, 0.01)))
        if self.tremolo:
            e = e * (1 - self.tremolo * (0.5 + 0.5 * np.sin(TAU * 4.5 * t)))
        return y * e * vel


class EPiano(FM):
    def __init__(self, t60=2.2, bright=1.0, r=0.25):
        super().__init__(ratio=1.0, index=1.4 * bright, idecay=0.4, isus=0.15, a=0.002, t60=t60,
                         r=r, ratio2=14.0, index2=0.9 * bright, idecay2=0.012, tremolo=0.12)


class Bell(FM):
    def __init__(self, t60=1.6, index=2.5, ratio=3.5, r=0.4):
        super().__init__(ratio=ratio, index=index, idecay=0.25, isus=0.1, a=0.001, t60=t60, r=r,
                         key_decay=True)


class Glock(Inst):
    def __init__(self, t60=1.0, bright=1.0):
        self.t60 = t60
        self.bright = bright

    def render(self, f, dur, vel, sr):
        n = ns(max(dur, self.t60), sr)
        t = tvec(n, sr)
        y = np.zeros(n)
        for ratio, amp, tt in [(1, 1.0, 1.0), (2.76, 0.35 * self.bright, 0.3), (5.4, 0.18 * self.bright, 0.12),
                               (8.93, 0.08 * self.bright, 0.06)]:
            if ratio * f < sr * 0.45:
                y += amp * np.sin(TAU * ratio * f * t) * np.exp(-6.9 * t / (self.t60 * tt))
        y *= np.clip(t / 0.001, 0, 1)
        return y * vel


class Marimba(Inst):
    def __init__(self, t60=0.5):
        self.t60 = t60

    def render(self, f, dur, vel, sr):
        t60 = self.t60 * np.clip((400.0 / f) ** 0.5, 0.4, 2.0)
        n = ns(max(t60, dur * 0.5) + 0.05, sr)
        t = tvec(n, sr)
        y = np.sin(TAU * f * t) * np.exp(-6.9 * t / t60)
        y += 0.35 * np.sin(TAU * 4.0 * f * t) * np.exp(-6.9 * t / (t60 * 0.25)) if 4 * f < sr * 0.45 else 0
        y += 0.12 * np.sin(TAU * 9.9 * f * t) * np.exp(-6.9 * t / (t60 * 0.08)) if 9.9 * f < sr * 0.45 else 0
        y = y + 0.15 * bp(noise(n, int(f)), 1500, 6000, sr) * np.exp(-t / 0.004)
        y *= np.clip(t / 0.0015, 0, 1)
        return y * vel


class Pluck(Inst):
    """Karplus-Strong string."""

    def __init__(self, t60=1.2, blend=0.5, bright=7000, pick=0.13, body=0.0, tail=0.15, mute=False,
                 octave_layer=0.0):
        self.__dict__.update(locals())
        del self.__dict__['self']

    def render(self, f, dur, vel, sr):
        t60 = self.t60 * np.clip((330.0 / f) ** 0.3, 0.5, 1.8)
        length = min(dur + self.tail, t60) if self.mute else max(dur + self.tail, min(t60, 3.0))
        y = karplus(f, length, sr, t60=t60, blend=self.blend, bright=self.bright * (0.5 + 0.5 * vel),
                    seed=int(f * 7) % 1000, pick=self.pick)
        if self.octave_layer:
            y = y + self.octave_layer * karplus(2 * f, length, sr, t60=t60 * 0.7, blend=self.blend,
                                                bright=self.bright, seed=int(f * 3) % 1000, pick=self.pick)
        n = len(y)
        t = tvec(n, sr)
        if self.mute:
            y *= np.where(t < dur, 1.0, np.exp(-6.9 * (t - dur) / max(self.tail, 0.01)))
        if self.body:
            y = y + self.body * lp(y, 800, sr)
        y[-min(n, 200):] *= np.linspace(1, 0, min(n, 200))
        return y * vel


class Organ(Inst):
    def __init__(self, bars=(0.6, 1.0, 0.7, 0.4, 0.5, 0.0, 0.25), a=0.01, r=0.08, leslie=0.004, click=0.2,
                 perc=0.0):
        self.__dict__.update(locals())
        del self.__dict__['self']

    def render(self, f, dur, vel, sr):
        n = ns(dur + self.r, sr)
        t = tvec(n, sr)
        ratios = [0.5, 1, 2, 3, 4, 5, 6, 8]
        vib = 1 + self.leslie * np.sin(TAU * 6.3 * t)
        ph = cycles(f * vib, n, sr)
        y = np.zeros(n)
        for ratio, amp in zip(ratios, self.bars):
            if amp and ratio * f < sr * 0.45:
                y += amp * np.sin(TAU * ratio * ph)
        if self.perc:
            y += self.perc * np.sin(TAU * 3 * ph) * np.exp(-t / 0.15)
        e = np.clip(t / self.a, 0, 1) * np.where(t < dur, 1.0, np.exp(-6.9 * (t - dur) / self.r))
        y *= e * (1 + 0.15 * np.sin(TAU * 6.3 * t + 1.0))
        if self.click:
            k = min(n, int(0.004 * sr))
            y[:k] += self.click * noise(k, int(f)) * np.linspace(1, 0, k)
        return y * vel / 2.5


class Choir(Inst):
    """Formant-shaped additive voices ('aah')."""
    stereo = True

    def __init__(self, vowel='a', a=0.25, r=0.5, voices=3, detune=0.12, bright=1.0):
        self.__dict__.update(locals())
        del self.__dict__['self']

    FORMANTS = {'a': [(800, 1.0, 80), (1150, 0.5, 90), (2900, 0.25, 120), (3900, 0.1, 130)],
                'o': [(450, 1.0, 70), (800, 0.45, 80), (2830, 0.12, 100)],
                'u': [(325, 1.0, 50), (700, 0.3, 60), (2530, 0.08, 170)],
                'e': [(400, 1.0, 60), (1600, 0.35, 80), (2700, 0.25, 120)]}

    def render(self, f, dur, vel, sr):
        n = ns(dur + self.r, sr)
        t = tvec(n, sr)
        forms = self.FORMANTS[self.vowel]
        out = np.zeros((n, 2))
        rng = np.random.default_rng(int(f))
        for v in range(self.voices):
            d = (v - (self.voices - 1) / 2) * self.detune
            vib = 1 + 0.006 * np.sin(TAU * rng.uniform(4.5, 5.8) * t + rng.uniform(0, 6))
            ph = cycles(f * 2 ** (d / 12) * vib, n, sr, rng.uniform(0, 1))
            y = np.zeros(n)
            for k in range(1, 60):
                fk = k * f
                if fk > 7000 or fk > sr * 0.45:
                    break
                g = 0.02 / k
                for (fc, amp, bw) in forms:
                    g += amp * np.exp(-0.5 * ((fk - fc) / (bw * 1.8)) ** 2)
                y += g * (self.bright ** (k / 10)) * np.sin(TAU * k * ph) / np.sqrt(k)
            pan = (v / max(1, self.voices - 1)) if self.voices > 1 else 0.5
            out[:, 0] += y * (1 - pan * 0.7)
            out[:, 1] += y * (0.3 + pan * 0.7)
        e = _gate_env(n, sr, dur, self.a, 0.5, 1.0, self.r)
        breath = bp(noise(n, int(f) + 1), 1500, 5000, sr) * 0.02
        out += breath[:, None]
        return out * e[:, None] * vel / self.voices


class Strings(Supersaw):
    def __init__(self, a=0.12, r=0.35, cutoff=3500, voices=5, detune=0.14):
        super().__init__(voices=voices, detune=detune, a=a, d=1.0, s=1.0, r=r, cutoff=cutoff, vib=0.004)


class Piano(Inst):
    """Additive piano-ish with stretched partials and per-partial decay."""

    def __init__(self, t60=2.5, bright=1.0):
        self.t60 = t60
        self.bright = bright

    def render(self, f, dur, vel, sr):
        t60 = self.t60 * np.clip((262.0 / f) ** 0.5, 0.4, 2.5)
        length = min(max(dur + 0.2, 0.3), t60)
        n = ns(length + 0.12, sr)
        t = tvec(n, sr)
        y = np.zeros(n)
        B = 0.0004
        for k in range(1, 18):
            fk = k * f * np.sqrt(1 + B * k * k)
            if fk > sr * 0.45:
                break
            amp = (1.0 / k ** (1.4 - 0.4 * vel * self.bright))
            dec = t60 / (1 + 0.35 * (k - 1))
            y += amp * np.sin(TAU * fk * t + k) * np.exp(-6.9 * t / dec)
        y += 0.2 * bp(noise(n, int(f)), 800, 4000, sr) * np.exp(-t / 0.006)
        e = np.clip(t / 0.002, 0, 1) * np.where(t < length, 1.0, np.exp(-6.9 * (t - length) / 0.12))
        return y * e * vel * 0.5


# ---------------------------------------------------------------------------
# Chip (2A03-ish)
# ---------------------------------------------------------------------------
class ChipPulse(Inst):
    def __init__(self, duty=0.5, decay=0.0, sustain=1.0, vib=0.0, vib_delay=0.15, r=0.02, arp=None,
                 slide=0.0):
        self.__dict__.update(locals())
        del self.__dict__['self']

    def render(self, f, dur, vel, sr):
        n = ns(dur + self.r, sr)
        t = tvec(n, sr)
        frames = np.floor(t * 60)
        ff = np.full(n, f)
        if self.vib:
            ff = ff * (1 + self.vib * np.sin(TAU * 6 * frames / 60) * (t > self.vib_delay))
        if self.arp:
            steps = np.array(self.arp)
            ff = ff * 2 ** (steps[(frames.astype(int)) % len(steps)] / 12)
        if self.slide:
            ff = ff * 2 ** (self.slide * np.exp(-t / 0.03) / 12)
        y = naive_pulse(ff, n, sr, self.duty)
        if self.decay:
            vol = np.maximum(self.sustain, 1 - frames * self.decay)
        else:
            vol = np.ones(n)
        vol = np.round(vol * vel * 15) / 15
        vol = np.where(t < dur, vol, 0.0)
        y = y * vol
        return lp(y, 14000, sr, order=1)


class ChipTri(Inst):
    def __init__(self, r=0.01):
        self.r = r

    def render(self, f, dur, vel, sr):
        n = ns(dur + self.r, sr)
        y = nes_tri(f, n, sr)
        t = tvec(n, sr)
        y *= np.where(t < dur, 1.0, 0.0)
        k = min(n, 60)
        y[-k:] *= np.linspace(1, 0, k)
        return y * (0.6 + 0.4 * vel)


class ChipNoise(Inst):
    pitched = False

    def __init__(self, period=2, decay=0.25, short=False, start_period=None, vol=1.0):
        self.__dict__.update(locals())
        del self.__dict__['self']

    def render(self, f, dur, vel, sr):
        n = ns(self.decay + 0.01, sr)
        t = tvec(n, sr)
        if self.start_period is not None:
            frames = np.floor(t * 60)
            pe = np.minimum(self.start_period + frames, self.period)
            y = nes_noise(n, self.period, sr, self.short, period_env=pe)
        else:
            y = nes_noise(n, self.period, sr, self.short)
        vol = np.maximum(0, 1 - np.floor(t * 60) / (self.decay * 60))
        vol = np.round(vol * 15) / 15
        return y * vol * vel * self.vol


# ---------------------------------------------------------------------------
# Drums
# ---------------------------------------------------------------------------
class Kick(Inst):
    pitched = False

    def __init__(self, f0=160, f1=48, sweep=0.045, t60=0.45, click=0.35, drive_amt=1.5, sub=0.0, tone_hp=0):
        self.__dict__.update(locals())
        del self.__dict__['self']

    def render(self, f, dur, vel, sr):
        n = ns(self.t60 + 0.02, sr)
        t = tvec(n, sr)
        freq = self.f1 + (self.f0 - self.f1) * np.exp(-t / self.sweep)
        y = np.sin(TAU * cycles(freq, n, sr)) * np.exp(-6.9 * t / self.t60)
        y *= np.clip(t / 0.0008, 0, 1)
        if self.click:
            k = int(0.006 * sr)
            y[:k] += self.click * hp(noise(k, 3), 1500, sr) * np.exp(-np.arange(k) / (0.0015 * sr))
        if self.drive_amt:
            y = drive(y * self.drive_amt, self.drive_amt)
        return y * vel


class Snare(Inst):
    pitched = False

    def __init__(self, tone=185, t60=0.22, noise_amt=0.8, tone_amt=0.6, lo=1200, hi=9000, snap=0.3, seed=11):
        self.__dict__.update(locals())
        del self.__dict__['self']

    def render(self, f, dur, vel, sr):
        n = ns(self.t60 + 0.02, sr)
        t = tvec(n, sr)
        tone = (np.sin(TAU * self.tone * t) + 0.5 * np.sin(TAU * self.tone * 1.63 * t)) * np.exp(-t / 0.035)
        nz = bp(noise(n, self.seed), self.lo, self.hi, sr) * np.exp(-6.9 * t / self.t60)
        snap = hp(noise(n, self.seed + 1), 3000, sr) * np.exp(-t / 0.006) * self.snap
        y = self.tone_amt * tone + self.noise_amt * nz * 1.6 + snap
        return drive(y * 1.3, 1.3) * vel


class Clap(Inst):
    pitched = False

    def __init__(self, t60=0.25, seed=21):
        self.t60 = t60
        self.seed = seed

    def render(self, f, dur, vel, sr):
        n = ns(self.t60 + 0.04, sr)
        t = tvec(n, sr)
        env = np.zeros(n)
        for i, off in enumerate([0.0, 0.009, 0.018, 0.027]):
            env += np.where(t >= off, np.exp(-(t - off) / 0.004), 0) * (0.8 if i < 3 else 1.0)
        env += np.where(t >= 0.027, np.exp(-6.9 * (t - 0.027) / self.t60), 0) * 0.6
        y = bp(noise(n, self.seed), 900, 5000, sr) * env * 1.5
        return y * vel


class Hat(Inst):
    pitched = False

    def __init__(self, t60=0.05, open_=False, lo=7000, metal=0.5, seed=31):
        self.__dict__.update(locals())
        del self.__dict__['self']

    def render(self, f, dur, vel, sr):
        n = ns(self.t60 + 0.01, sr)
        t = tvec(n, sr)
        m = sum(naive_pulse(fr, n, sr) for fr in [317, 421, 567, 709, 853, 1112]) / 6
        y = hp(noise(n, self.seed) * (1 - self.metal) + m * self.metal, self.lo, sr, order=3)
        y *= np.exp(-6.9 * t / self.t60) * np.clip(t / 0.0005, 0, 1)
        return y * vel * 4.0


class Cymbal(Inst):
    pitched = False

    def __init__(self, t60=1.8, lo=3500, ride=False, seed=41):
        self.__dict__.update(locals())
        del self.__dict__['self']

    def render(self, f, dur, vel, sr):
        n = ns(self.t60, sr)
        t = tvec(n, sr)
        m = sum(naive_pulse(fr, n, sr) for fr in [205.3, 304.4, 369.6, 522.7, 540.0, 800.0]) / 6
        if self.ride:
            y = hp(m * 0.6 + noise(n, self.seed) * 0.25, self.lo, sr) * np.exp(-6.9 * t / self.t60)
            y += 0.3 * np.sin(TAU * 3200 * t) * np.exp(-t / 0.3) * 0.2
            y *= 1 + 1.2 * np.exp(-t / 0.01)
        else:
            y = hp(m * 0.5 + noise(n, self.seed) * 0.7, self.lo, sr) * np.exp(-6.9 * t / self.t60)
            y *= 1 + 1.5 * np.exp(-t / 0.02)
        y = lp(y, 13000, sr)
        return y * vel


class Tom(Inst):
    def __init__(self, t60=0.35, bend=0.4):
        self.t60 = t60
        self.bend = bend

    def render(self, f, dur, vel, sr):
        n = ns(self.t60 + 0.02, sr)
        t = tvec(n, sr)
        freq = f * (1 + self.bend * np.exp(-t / 0.04))
        y = np.sin(TAU * cycles(freq, n, sr)) * np.exp(-6.9 * t / self.t60)
        y += 0.3 * bp(noise(n, int(f)), 200, 3000, sr) * np.exp(-t / 0.015)
        return drive(y * 1.4, 1.4) * vel


class Taiko(Inst):
    pitched = False

    def __init__(self, f=72, t60=0.9, seed=51):
        self.f = f
        self.t60 = t60
        self.seed = seed

    def render(self, f, dur, vel, sr):
        n = ns(self.t60 + 0.02, sr)
        t = tvec(n, sr)
        freq = self.f * (1 + 0.6 * np.exp(-t / 0.03))
        y = np.sin(TAU * cycles(freq, n, sr)) * np.exp(-6.9 * t / self.t60)
        y += 0.4 * np.sin(TAU * cycles(freq * 1.5, n, sr)) * np.exp(-6.9 * t / (self.t60 * 0.4))
        y += 0.6 * lp(noise(n, self.seed), 1500, sr) * np.exp(-t / 0.02)
        y *= np.clip(t / 0.001, 0, 1)
        return drive(y * 1.5, 1.5) * vel


class Shaker(Inst):
    pitched = False

    def __init__(self, t60=0.07, seed=61):
        self.t60 = t60
        self.seed = seed

    def render(self, f, dur, vel, sr):
        n = ns(self.t60 + 0.02, sr)
        t = tvec(n, sr)
        env = np.clip(t / 0.012, 0, 1) * np.exp(-6.9 * np.maximum(t - 0.012, 0) / self.t60)
        return hp(noise(n, self.seed), 5000, sr) * env * vel * 2.0


class Brush(Inst):
    pitched = False

    def __init__(self, t60=0.18, swish=False, seed=71):
        self.t60 = t60
        self.swish = swish
        self.seed = seed

    def render(self, f, dur, vel, sr):
        n = ns(self.t60 + 0.05, sr)
        t = tvec(n, sr)
        if self.swish:
            env = np.sin(np.pi * np.clip(t / (self.t60 + 0.05), 0, 1)) ** 2
        else:
            env = np.clip(t / 0.003, 0, 1) * np.exp(-6.9 * t / self.t60)
        return bp(noise(n, self.seed), 1500, 7000, sr) * env * vel


class Perc(Inst):
    """Tuned short percussion: woodblock, cowbell, rim, snap, tick."""
    pitched = False

    def __init__(self, kind='wood', f=900, t60=0.08, seed=81):
        self.kind = kind
        self.f = f
        self.t60 = t60
        self.seed = seed

    def render(self, f, dur, vel, sr):
        n = ns(self.t60 + 0.01, sr)
        t = tvec(n, sr)
        e = np.exp(-6.9 * t / self.t60) * np.clip(t / 0.0005, 0, 1)
        if self.kind == 'wood':
            y = np.sin(TAU * self.f * t) + 0.4 * np.sin(TAU * self.f * 2.6 * t) * np.exp(-t / 0.01)
        elif self.kind == 'cowbell':
            y = lp(naive_pulse(self.f, n, sr) + naive_pulse(self.f * 1.48, n, sr), 4000, sr) * 0.6
        elif self.kind == 'rim':
            y = np.sin(TAU * self.f * t) * 0.6 + hp(noise(n, self.seed), 2000, sr) * np.exp(-t / 0.004)
        elif self.kind == 'snap':
            y = bp(noise(n, self.seed), 1500, 5000, sr) * np.exp(-t / 0.01) * 2
        else:
            y = hp(noise(n, self.seed), 3000, sr)
        return y * e * vel


class Timpani(Inst):
    def __init__(self, t60=1.4):
        self.t60 = t60

    def render(self, f, dur, vel, sr):
        n = ns(self.t60, sr)
        t = tvec(n, sr)
        y = np.zeros(n)
        for ratio, amp, dec in [(1, 1.0, 1.0), (1.5, 0.5, 0.6), (1.98, 0.3, 0.4), (2.44, 0.2, 0.3)]:
            y += amp * np.sin(TAU * f * ratio * t) * np.exp(-6.9 * t / (self.t60 * dec))
        y += 0.5 * lp(noise(n, int(f)), 1200, sr) * np.exp(-t / 0.02)
        y *= np.clip(t / 0.002, 0, 1)
        return y * vel


class OrchHit(Inst):
    """Big orchestra stab: plays a chord around the given root."""
    stereo = True

    def __init__(self, intervals=(0, 7, 12, 16, 19, 24), t60=0.7):
        self.intervals = intervals
        self.t60 = t60

    def render(self, f, dur, vel, sr):
        n = ns(self.t60 + 0.1, sr)
        t = tvec(n, sr)
        out = np.zeros((n, 2))
        rng = np.random.default_rng(int(f))
        for i, iv in enumerate(self.intervals):
            ff = f * 2 ** (iv / 12)
            for d in (-0.08, 0.08):
                v = saw(ff * 2 ** (d / 12), n, sr, rng.uniform(0, 1))
                out[:, 0 if d < 0 else 1] += v
        out = lp(out, 5000, sr) / len(self.intervals)
        out += (lp(noise(n, 5), 3000, sr) * np.exp(-t / 0.03))[:, None] * 0.5
        out += (np.sin(TAU * f / 2 * t) * np.exp(-t / 0.2))[:, None] * 0.5
        e = np.clip(t / 0.003, 0, 1) * np.exp(-6.9 * t / self.t60)
        return drive(out * e[:, None] * 1.5, 1.5) * vel


class NoiseFx(Inst):
    """Riser / wind / vinyl etc. rendered per event over its duration."""
    pitched = False

    def __init__(self, kind='riser', lo=500, hi=8000, seed=91):
        self.kind = kind
        self.lo = lo
        self.hi = hi
        self.seed = seed

    def render(self, f, dur, vel, sr):
        n = ns(dur, sr)
        t = tvec(n, sr)
        x = np.linspace(0, 1, n)
        if self.kind == 'riser':
            y = hp(noise(n, self.seed), 1000, sr) * x ** 2
            y = lp(y, self.hi, sr)
        elif self.kind == 'reverse':
            y = hp(noise(n, self.seed), 3000, sr) * x ** 3
        elif self.kind == 'wind':
            w = colored_noise(n, self.seed, -3)
            y = bp(w, self.lo, self.hi, sr) * (0.6 + 0.4 * np.sin(np.pi * x)) * (0.8 + 0.2 * np.sin(TAU * 0.3 * t))
            k = min(n, int(0.3 * sr))
            y[:k] *= np.linspace(0, 1, k)
            y[-k:] *= np.linspace(1, 0, k)
        elif self.kind == 'vinyl':
            rng = np.random.default_rng(self.seed)
            imp = np.zeros(n)
            cnt = int(dur * 18)
            pos = rng.integers(0, n, cnt)
            imp[pos] = rng.uniform(-1, 1, cnt) * rng.uniform(0.2, 1.0, cnt) ** 2
            big = rng.integers(0, n, int(dur * 1.5))
            imp[big] = rng.uniform(-1, 1, len(big))
            y = hp(imp, 1500, sr) + 0.05 * bp(noise(n, self.seed + 1), 800, 6000, sr)
        elif self.kind == 'impact':
            y = lp(noise(n, self.seed), 2500, sr) * np.exp(-t / 0.25) + np.sin(TAU * 45 * t) * np.exp(-t / 0.4)
        else:
            y = noise(n, self.seed)
        return y * vel
