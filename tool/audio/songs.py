"""The 18 background music loops. Each function returns a configured Song."""
from __future__ import annotations

import numpy as np

import instruments as I
from music import Song

SONGS = {}


def song(fn):
    SONGS[fn.__name__.replace('song_', '')] = fn
    return fn


def fill_16(S, tr, bar, pattern='....x.x.xxxxXXXX', vel=0.8):
    S.drum(tr, bar, pattern, 0.25, vel=vel)


def edm_kit(S, kick_gain=0.72):
    S.track('kick', I.Kick(f0=170, f1=50, sweep=0.04, t60=0.38, click=0.4), gain=kick_gain)
    S.track('clap', I.Clap(t60=0.22), gain=0.55, rev=0.2)
    S.track('snare', I.Snare(tone=200, t60=0.18), gain=0.4, rev=0.15)
    S.track('hat', I.Hat(t60=0.04), gain=0.3, pan=0.25)
    S.track('ohat', I.Hat(t60=0.22, seed=33), gain=0.22, pan=-0.2)
    S.track('crash', I.Cymbal(t60=1.8), gain=0.3, rev=0.2)
    S.track('riser', I.NoiseFx('riser', hi=9000), gain=0.12, rev=0.3)


def wow_fx(depth=0.0025, cycles_=6):
    def fx(x, S):
        L = x.shape[0]
        i = np.arange(L)
        amp = depth * L / (2 * np.pi * cycles_)
        pos = i + amp * np.sin(2 * np.pi * cycles_ * i / L) + 0.2 * amp * np.sin(2 * np.pi * cycles_ * 7 * i / L)
        out = np.empty_like(x)
        for c in range(x.shape[1]):
            out[:, c] = np.interp(pos, i, x[:, c], period=L)
        return out
    return fx


def tape_fx(cut=6500, sat=1.4):
    def fx(x, S):
        L = x.shape[0]
        X = np.fft.rfft(x, axis=0)
        f = np.fft.rfftfreq(L, 1 / S.sr)
        X *= (1 / np.sqrt(1 + (f / cut) ** 4))[:, None]
        y = np.fft.irfft(X, L, axis=0)
        m = np.max(np.abs(y)) + 1e-9
        return np.tanh(y / m * sat) / np.tanh(sat) * m
    return fx


# ===========================================================================
@song
def song_menu():
    S = Song('menu', 124, 16, transpose=2, rev_time=1.6, dly_beats=0.75, dly_fb=0.3)
    edm_kit(S)
    S.track('bass', I.Sub('saw', a=0.003, d=0.12, s=0.6, r=0.05, base=2.0, env=6, fdecay=0.07, maxh=40),
            gain=0.3, duck=0.55)
    S.track('sub', I.Sub('tri', a=0.005, d=0.3, s=0.9, r=0.05, base=1, env=0, maxh=5), gain=0.25, duck=0.6)
    S.track('chords', I.Sub('saw', a=0.002, d=0.16, s=0.0, r=0.12, base=1.6, env=9, fdecay=0.07, detune=0.1),
            gain=0.27, rev=0.25, dly=0.15, duck=0.4, pan=-0.1)
    S.track('pad', I.Supersaw(voices=6, detune=0.2, a=0.03, d=0.5, s=0.8, r=0.25, cutoff=3800),
            gain=0.16, rev=0.3, duck=0.7)
    S.track('arp', I.Sub('square', a=0.001, d=0.09, s=0.0, r=0.06, base=2, env=10, fdecay=0.04),
            gain=0.17, dly=0.35, rev=0.15, duck=0.3, pan=0.3)
    S.track('leadA', I.Sub('pulse', duty=0.3, a=0.003, d=0.25, s=0.55, r=0.1, base=3, env=7, fdecay=0.1,
                           vib=0.005, vib_delay=0.15), gain=0.34, rev=0.2, dly=0.18)
    S.track('leadB', I.Supersaw(voices=5, detune=0.14, a=0.006, d=0.3, s=0.85, r=0.15, cutoff=6500, vib=0.003),
            gain=0.3, rev=0.25, dly=0.2, octave=-1)
    S.track('bell', I.Bell(t60=1.2, index=2.0, ratio=3.5), gain=0.17, rev=0.3, dly=0.2, pan=0.15)
    S.track('glock', I.Glock(t60=0.8), gain=0.17, rev=0.3, pan=-0.2)

    A = S.prog('F G Em Am F G C C', 0)
    B = S.prog('Am F G C Am F Gsus4 G', 8)
    S.duck_every(1.0)
    # drums
    S.drum('kick', 0, 'x...x...x...x...', times=15)
    S.drum('kick', 15, 'x...x...x.x.x...')
    S.drum('clap', 0, '....x.......x...', times=16)
    S.drum('hat', 0, '..x...x...x...x.', times=8)
    S.drum('hat', 8, 'gxgxgxgxgxgxgxgx'.replace('g', 'o'), times=8)
    S.drum('ohat', 8, '..x...x...x...x.', times=8)
    S.drum('crash', 0, 'x')
    S.drum('crash', 8, 'x', vel=1.0)
    fill_16(S, 'snare', 7, '........x.x.xxxx')
    fill_16(S, 'snare', 15, 'x.x.x.x.xxxxXXXX')
    S.note('riser', 7 * 4, None, 4, 0.9)
    S.note('riser', 15 * 4, None, 4, 0.9)
    # bass
    S.bass('bass', A, 'R . O R . R O .', 0.5)
    S.bass('bass', B, 'R R O R R R O R', 0.5)
    S.bass('sub', A + B, 'R - - - - - - -', 0.5, lo=28)
    # harmony
    S.stab('chords', A, 'x..x..x...x..x..', 0.25, lo=60, gate=0.5)
    S.pad('pad', B, lo=57)
    S.stab('chords', B, 'x..x..x...x..x..', 0.25, lo=60, gate=0.5, vel=0.5)
    S.arp('arp', B, '0 1 2 3 1 2 3 4 2 3 4 5 3 4 5 6', 0.25, lo=67, vel=0.6)
    # melody
    melA = ('A5 - G5 A5 C6 - A5 G5 | B5 - G5 . D6 - B5 G5 | B5 - G5 B5 - E6 D6 B5 | C6 - - - A5 - E5 G5 |'
            'A5 - F5 A5 - C6 A5 F5 | G5 - D5 G5 - B5 A5 G5 | E5 G5 C6 - D6 - E6 - | - - - - . . G5 A5')
    melB = ('E6 - - D6 C6 - D6 E6 | F6 - E6 - C6 - A5 - | D6 - - C6 B5 - C6 D6 | E6 - G6 - E6 - C6 - |'
            'E6 - - D6 C6 - D6 E6 | F6 - A6 - G6 - F6 E6 | D6 - B5 - G5 - A5 B5 | D6 - - - . . . .')
    S.seq('leadA', 0, melA, 0.5, vel=0.8, octave=-1)
    S.seq('glock', 0, melA, 0.5, vel=0.5)
    S.seq(['leadB', 'bell'], 8, melB, 0.5, vel=0.85)
    S.seq('leadA', 8, melB, 0.5, vel=0.45, octave=-1)
    return S


# ===========================================================================
@song
def song_rush():
    S = Song('rush', 150, 16, transpose=0, rev_time=1.0, dly_beats=0.5, dly_fb=0.25)
    S.track('kick', I.Kick(f0=150, f1=52, t60=0.3, click=0.5), gain=0.7)
    S.track('snare', I.Snare(tone=210, t60=0.16, snap=0.5), gain=0.45, rev=0.12)
    S.track('hat', I.Hat(t60=0.035), gain=0.26, pan=0.3)
    S.track('ohat', I.Hat(t60=0.18, seed=34), gain=0.12, pan=-0.3)
    S.track('crash', I.Cymbal(t60=1.4), gain=0.2)
    S.track('cow', I.Perc('cowbell', 560, 0.12), gain=0.2, pan=0.4)
    S.track('wood', I.Perc('wood', 1200, 0.05), gain=0.26, pan=-0.4)
    S.track('bass', I.Sub('saw', a=0.002, d=0.1, s=0.35, r=0.04, base=1.4, env=12, fdecay=0.045, res=0.7,
                          maxh=40, drive_amt=0.5), gain=0.33)
    S.track('clav', I.Pluck(t60=0.5, blend=0.25, bright=10000, pick=0.08, mute=True, tail=0.05),
            gain=0.3, pan=-0.25, dly=0.1)
    S.track('lead', I.Sub('square', a=0.002, d=0.12, s=0.55, r=0.05, base=3.5, env=6, fdecay=0.06,
                          vib=0.006, vib_delay=0.12), gain=0.34, rev=0.12, dly=0.15)
    S.track('mar', I.Marimba(t60=0.45), gain=0.3, pan=0.25, rev=0.1)
    S.track('brass', I.Sub('saw', a=0.012, d=0.15, s=0.7, r=0.06, base=2, env=6, attack_open=0.03,
                           detune=0.12), gain=0.3, rev=0.15)

    A = S.prog('Em7 A7 Em7 A7 Cmaj7 B7 Em7 B7', 0)
    B = S.prog('Am7 D7 Gmaj7 Cmaj7 F#m7b5 B7 Em7 B7', 8)
    S.drum('kick', 0, 'x.....x...x.....x.....x...x..x..', times=8)
    S.drum('snare', 0, '....x..g.g..x...', times=15)
    fill_16(S, 'snare', 15, 'x.xxx.xxXxXxXXXX')
    S.drum('hat', 0, 'xoxoxoxoxoxoxoxo', times=16)
    S.drum('ohat', 8, '..x...x...x...x.', times=8)
    S.drum('crash', 0, 'x')
    S.drum('crash', 8, 'x')
    S.drum('cow', 0, 'x..x..x...x.x...', times=8, vel=0.7)
    S.drum('wood', 8, '..x..x....x..x.x', times=8, vel=0.8)
    funk = 'R . O . R R . O . R . O 10 . 12 .'
    S.bass('bass', A + B, funk, 0.25)
    S.stab('clav', A + B, '. x . x . . x . . x . x . . x x', 0.25, lo=62, gate=0.4, vel=0.7, top=3)
    melA = ('B4 . E5 . G5 F#5 E5 . | C#5 . E5 . G5 . F#5 E5 | B4 . E5 . G5 A5 B5 . | A5 G5 E5 . C#5 . E5 . |'
            'G5 . E5 G5 B5 . A5 G5 | F#5 . D#5 F#5 A5 . G5 F#5 | E5 . B4 . E5 G5 B5 E6 | D#6 . B5 . F#5 . D#5 .')
    melB = ('E5 - - . C5 . E5 G5 | F#5 - - . D5 . F#5 A5 | B5 - A5 . G5 . F#5 . | E5 - - - . . G5 A5 |'
            'A5 - C6 - A5 . F#5 . | D#5 - F#5 - A5 . B5 . | G5 . E5 . B5 . G5 . | F#5 A5 B5 D#6 F#6 . . .')
    S.seq('lead', 0, melA, 0.5, vel=0.85, gate=0.7)
    S.seq('mar', 0, melA, 0.5, vel=0.7, octave=1)
    S.seq('lead', 8, melB, 0.5, vel=0.85, gate=0.85)
    S.seq('mar', 8, melB, 0.5, vel=0.5)
    S.stab('brass', B, 'x.......x..x....', 0.25, lo=62, gate=0.35, vel=0.8)
    return S


# ===========================================================================
@song
def song_hyper():
    S = Song('hyper', 115, 16, transpose=2, rev_time=1.8, dly_beats=0.75, dly_fb=0.35)
    edm_kit(S)
    S.track('shaker', I.Shaker(t60=0.06), gain=0.14, pan=0.35)
    S.track('bass', I.Sub('tri', a=0.004, d=0.2, s=0.8, r=0.06, base=2, env=3, maxh=15), gain=0.38, duck=0.5)
    S.track('pluck', I.Pluck(t60=0.7, blend=0.35, bright=6000, pick=0.15, tail=0.1), gain=0.38, rev=0.25,
            dly=0.2, duck=0.35)
    S.track('mar', I.Marimba(t60=0.5), gain=0.3, rev=0.2, pan=-0.2)
    S.track('fb', I.Supersaw(voices=7, detune=0.28, a=0.005, d=0.25, s=0.7, r=0.12, cutoff=5500,
                             bright_env=0.8, bright_decay=0.15, octave_mix=0.3), gain=0.27, rev=0.25, duck=0.85)
    S.track('chop', I.Choir('a', a=0.008, r=0.08, voices=2, detune=0.08, bright=1.1), gain=0.42, rev=0.25,
            dly=0.25)
    S.track('bell', I.Bell(t60=1.0, index=1.6, ratio=3.5), gain=0.12, rev=0.3, dly=0.3, pan=0.2)
    S.track('pad', I.Supersaw(voices=4, detune=0.15, a=0.3, d=1, s=1, r=0.5, cutoff=2200), gain=0.12,
            rev=0.4, duck=0.6)

    A = S.prog('Am F C G Am F C G', 0)
    B = S.prog('Am F C G Am F C G', 8)
    S.duck_every(1.0)
    S.drum('kick', 0, 'x...x...x...x...', times=7)
    S.drum('kick', 7, 'x...x...x.......')
    S.drum('clap', 0, '....x.......x...', times=7)
    S.drum('shaker', 0, 'oxxoxxoxoxxoxxox', times=16)
    S.drum('hat', 0, '..x...x...x...x.', times=8)
    S.note('riser', 7 * 4, None, 4, 1.0)
    fill_16(S, 'snare', 7, '........xxxxXXXX')
    # drop: half-time future bass
    S.drum('kick', 8, 'x.........x.....x.........x..x..', times=4)
    S.drum('snare', 8, '........x.......', times=8)
    S.drum('clap', 8, '........x.......', times=8)
    S.drum('hat', 8, 'x.x.x.x.x.x.xxx.', times=8)
    S.drum('crash', 8, 'x')
    S.drum('crash', 12, 'x', vel=0.7)
    S.note('riser', 15 * 4 + 2, None, 2, 0.8)
    S.bass('bass', A, 'R . . R . . R . R . . R . . R .', 0.25)
    S.bass('bass', B, 'R - - - - - R - - - R - - - O -', 0.25, lo=28)
    S.stab('pluck', A, 'x..x..x.x..x..x.', 0.25, lo=60, gate=0.5, strum=0.02, vel=0.65)
    S.stab('mar', A, '..x...x...x...x.', 0.25, lo=72, gate=0.5, top=2, vel=0.45)
    S.pad('pad', A, lo=55, vel=0.5)
    S.stab('fb', B, 'x..x..x...x.x...', 0.25, lo=60, gate=0.8, vel=0.8, spread=True)
    S.duck_release = 0.5
    melA = ('E5 . E5 . C5 D5 E5 . | F5 . E5 . C5 . A4 . | G5 . E5 . C5 D5 E5 . | D5 . B4 . G4 . . . |'
            'E5 . E5 . C5 D5 E5 . | F5 . E5 . C5 . A4 . | G5 . E5 . C5 D5 E5 . | D5 . E5 . G5 . A5 .')
    melB = ('A5 . A5 G5 . E5 . G5 | A5 . C6 . . A5 G5 . | G5 . G5 E5 . C5 . E5 | D5 . D5 E5 . G5 . . |'
            'A5 . A5 G5 . E5 . G5 | A5 . C6 . D6 . C6 . | E6 . D6 C6 . A5 . G5 | G5 . . . A5 . B5 .')
    S.seq('chop', 0, melA, 0.5, vel=0.8, gate=0.6)
    S.seq('mar', 0, melA, 0.5, vel=0.35, octave=1)
    S.seq('chop', 8, melB, 0.5, vel=0.9, gate=0.6)
    S.seq('bell', 8, melB, 0.5, vel=0.7)
    return S


# ===========================================================================
@song
def song_cute():
    S = Song('cute', 128, 16, transpose=5, rev_time=1.2, dly_beats=0.5, dly_fb=0.25, swing=0.25)
    S.track('kick', I.Kick(f0=140, f1=60, t60=0.25, click=0.2, drive_amt=1.0), gain=0.55)
    S.track('snap', I.Clap(t60=0.12, seed=25), gain=0.35, rev=0.2)
    S.track('shaker', I.Shaker(t60=0.05), gain=0.13, pan=0.3)
    S.track('wood', I.Perc('wood', 1500, 0.05), gain=0.22, pan=-0.35)
    S.track('toy', I.Perc('wood', 900, 0.07, seed=84), gain=0.2, pan=0.35)
    S.track('bass', I.Sub('square', a=0.002, d=0.1, s=0.35, r=0.03, base=2.2, env=3, fdecay=0.05, maxh=20),
            gain=0.25)
    S.track('uke', I.Pluck(t60=0.8, blend=0.4, bright=5000, pick=0.2, tail=0.08), gain=0.27, pan=-0.2,
            rev=0.15)
    S.track('mar', I.Marimba(t60=0.55), gain=0.45, rev=0.15)
    S.track('glock', I.Glock(t60=0.9), gain=0.25, rev=0.25, pan=0.25, dly=0.15)
    S.track('bell', I.Bell(t60=1.2, index=1.2, ratio=4.0), gain=0.1, rev=0.3)

    prog = S.prog('C Am F G C E7 Am C7 F G Em Am Dm G C C', 0)
    S.drum('kick', 0, 'x.......x.......', times=16)
    S.drum('kick', 0, '..........x.....', times=16, vel=0.5)
    S.drum('snap', 0, '....x.......x...', times=16)
    S.drum('shaker', 0, 'x.o.x.o.x.o.x.oo', times=16)
    S.drum('wood', 0, '..x...x...x...x.', times=8, vel=0.7)
    S.drum('toy', 8, 'x..x..x.x..x..x.', times=8, vel=0.6)
    S.bass('bass', prog, 'R . F . R . F .', 0.5, lo=36)
    S.stab('uke', prog, 'x.x.xx.x', 0.5, lo=60, gate=0.7, strum=0.025, vel=0.6)
    mel = ('G5 G5 E5 . G5 G5 C6 . | A5 A5 E5 . A5 G5 E5 . | F5 F5 A5 . C6 . A5 . | G5 . D5 . G5 . . . |'
           'G5 G5 E5 . G5 G5 C6 . | B5 B5 G#5 . E5 . D6 . | C6 . B5 A5 . E5 . . | G5 . E5 . C5 . Bb5 . |'
           'A5 . . C6 . A5 F5 . | B5 . . D6 . B5 G5 . | G5 . B5 . E6 . D6 . | C6 . . . A5 . . . |'
           'F5 A5 D6 . C6 . A5 . | B5 . G5 . D6 . B5 . | C6 . G5 . E5 . G5 . | C6 . . . . . . .')
    S.seq('mar', 0, mel, 0.5, vel=0.8, gate=0.8, octave=-1)
    S.seq('glock', 8, mel.split('|', 8)[-1], 0.5, vel=0.7)
    S.arp('bell', S.prog('C Am F G C E7 Am C7', 0), '0 . 2 . 4 . 2 .', 0.5, lo=84, vel=0.35)
    return S


# ===========================================================================
@song
def song_survival():
    S = Song('survival', 90, 12, transpose=0, rev_time=3.0, rev_damp=4500, dly_beats=0.75, dly_fb=0.3)
    S.track('taiko', I.Taiko(f=58, t60=1.2), gain=0.55, rev=0.25)
    S.track('taiko2', I.Taiko(f=110, t60=0.45, seed=52), gain=0.4, rev=0.2, pan=0.3)
    S.track('rim', I.Perc('rim', 700, 0.06), gain=0.35, pan=-0.3, rev=0.2)
    S.track('timp', I.Timpani(t60=1.5), gain=0.45, rev=0.3)
    S.track('crash', I.Cymbal(t60=2.5, lo=2500), gain=0.26, rev=0.3)
    S.track('wind', I.NoiseFx('wind', 400, 3500, seed=95), gain=0.3, pan=0.0)
    S.track('strings', I.Strings(a=0.35, r=0.8, cutoff=3800), gain=0.22, rev=0.35)
    S.track('ost', I.Sub('saw', a=0.005, d=0.12, s=0.5, r=0.08, base=2.5, env=4, fdecay=0.06, detune=0.08),
            gain=0.25, rev=0.15)
    S.track('bass', I.Sub('saw', a=0.02, d=0.5, s=0.8, r=0.2, base=1.5, env=1, maxh=20), gain=0.3)
    S.track('horn', I.Sub('saw', a=0.06, d=0.5, s=0.9, r=0.25, base=2.6, env=3.5, fdecay=0.3, attack_open=0.12,
                          vib=0.004, detune=0.06), gain=0.36, rev=0.35, dly=0.1)
    S.track('choir', I.Choir('o', a=0.4, r=0.8, voices=3), gain=0.35, rev=0.45)
    S.track('ice', I.Glock(t60=1.4), gain=0.22, rev=0.5, dly=0.35, pan=0.3)

    A = S.prog('Dm Bb F C Dm Bb Gm A', 0)
    B = S.prog('Bb C Gm A', 8)
    S.drum('taiko', 0, 'x.......x.x.....', times=12)
    S.drum('taiko2', 0, '....x..x....x.xx', times=8, vel=0.7)
    S.drum('taiko2', 8, 'x.xxx.x.x.xxx.xx', times=4, vel=0.8)
    S.drum('rim', 4, '..x...x...x...x.', times=8, vel=0.6)
    S.drum('timp', 7, '............xxxx', pitch='A2', vel=0.7)
    S.drum('timp', 11, 'x...x...xxxxXXXX', pitch='A2', vel=0.8)
    S.drum('timp', 0, 'x', pitch='D2')
    S.drum('timp', 8, 'x', pitch='Bb1')
    S.drum('crash', 0, 'x')
    S.drum('crash', 8, 'x')
    S.note('wind', 0, None, 16, 0.9)
    S.note('wind', 16, None, 16, 0.7)
    S.note('wind', 32, None, 16, 1.0)
    S.pad('strings', A + B, lo=50, spread=True, vel=0.8)
    S.bass('ost', A, 'R R O R R R O R', 0.5, lo=38, vel=0.7)
    S.bass('ost', B, 'R R O R F R O R R R O R F F O F', 0.25, lo=38, vel=0.75)
    S.bass('bass', A + B, 'R - - - - - - -', 0.5, lo=26)
    mel = ('A4 - - - D5 - E5 - | F5 - - - E5 - D5 - | C5 - - - F5 - G5 - | E5 - - - - - . . |'
           'A4 - - - D5 - E5 - | F5 - - - G5 - A5 - | Bb5 - - - A5 - G5 - | A5 - - - E5 - C#5 - |'
           'D6 - - - C6 - Bb5 - | C6 - - - G5 - - - | Bb5 - A5 - G5 - F5 - | E5 - - - C#5 - E5 -')
    S.seq('horn', 0, mel, 0.5, vel=0.85, octave=-1)
    S.seq('choir', 8, mel.split('|', 8)[-1], 0.5, vel=0.7, octave=-1)
    S.arp('ice', B, '4 . 3 . 2 . 1 . 2 . 3 . 4 . 5 .', 0.25, lo=74, vel=0.5)
    S.arp('ice', S.prog('Dm Bb', 4), '. . 2 . . . 4 .', 0.5, lo=74, vel=0.4)
    return S


# ===========================================================================
@song
def song_tycoon():
    S = Song('tycoon', 118, 16, transpose=-2, swing=0.6, rev_time=1.3, dly_beats=0.75, dly_fb=0.2)
    S.track('kick', I.Kick(f0=110, f1=55, t60=0.25, click=0.1, drive_amt=1.0), gain=0.45)
    S.track('brush', I.Brush(t60=0.16), gain=0.42, rev=0.15)
    S.track('swish', I.Brush(t60=0.25, swish=True, seed=72), gain=0.12, pan=-0.2)
    S.track('ride', I.Cymbal(t60=1.0, ride=True, lo=4000), gain=0.3, pan=0.3, rev=0.1)
    S.track('hat', I.Hat(t60=0.03, seed=35), gain=0.18, pan=0.3)
    S.track('bass', I.Pluck(t60=1.2, blend=0.5, bright=1400, pick=0.2, body=0.8, tail=0.06, mute=True), gain=0.55)
    S.track('ep', I.EPiano(t60=2.0, bright=1.0), gain=0.3, rev=0.2, pan=-0.15)
    S.track('vibes', I.FM(ratio=4.0, index=0.7, idecay=0.05, isus=0.0, t60=1.6, tremolo=0.3), gain=0.35,
            rev=0.25, pan=0.15, dly=0.1)
    S.track('lead', I.EPiano(t60=1.5, bright=1.3), gain=0.22, rev=0.2)
    S.track('bell', I.Bell(t60=1.4, index=1.4, ratio=3.5), gain=0.08, rev=0.3)

    A = S.prog('Cmaj7 Am7 Dm7 G7 Cmaj7 Am7 Dm7 G7', 0)
    B = S.prog('Fmaj7 Fm7 Em7 A7 Dm7 G7 C6 G7', 8)
    S.drum('kick', 0, 'x...x...x...x...', times=16, vel=0.6)
    S.drum('brush', 0, '....x.......x...', times=16)
    S.drum('swish', 0, 'x...............', times=16, vel=0.8)
    S.drum('ride', 0, 'x.xxx.xx', 0.5, times=16)
    S.drum('hat', 0, '..x...x.', 0.5, times=16, vel=0.7)
    S.walk('bass', A + B, lo=31)
    S.stab('ep', A + B, '..x...x.', 0.5, lo=57, gate=0.6, vel=0.55)
    S.stab('ep', A + B, 'x.......', 0.5, lo=57, gate=0.4, vel=0.4)
    melA = ('E5 . G5 . B5 - A5 G5 | C6 - - . A5 . G5 E5 | F5 . A5 . C6 - B5 A5 | G5 - - - . . F5 G5 |'
            'E5 . G5 . B5 - D6 C6 | A5 - - . E5 . G5 A5 | C6 . A5 . F5 . D5 F5 | B5 - A5 - G5 - F5 D5')
    melB = ('A5 - - C6 - - E6 - | Eb6 - - C6 - - Ab5 - | G5 - - B5 - - D6 - | C#6 - - A5 - - G5 - |'
            'F5 . A5 . C6 . E6 . | D6 - B5 - G5 - F5 - | E5 - G5 - A5 - C6 - | B5 - - - . G5 A5 B5')
    S.seq('vibes', 0, melA, 0.5, vel=0.8)
    S.seq('vibes', 8, melB, 0.5, vel=0.85)
    S.seq('lead', 8, melB, 0.5, vel=0.5, octave=-1)
    S.seq('bell', 14, 'C7 . . . . . . . | . . . . . . . .', 0.5, vel=0.4)
    return S


# ===========================================================================
@song
def song_party():
    S = Song('party', 140, 16, transpose=0, swing=0.55, rev_time=1.4, dly_beats=0.5, dly_fb=0.2)
    S.track('kick', I.Kick(f0=130, f1=55, t60=0.3, click=0.3), gain=0.5)
    S.track('snare', I.Snare(tone=190, t60=0.2), gain=0.4, rev=0.15)
    S.track('ride', I.Cymbal(t60=1.0, ride=True), gain=0.27, pan=0.3)
    S.track('crash', I.Cymbal(t60=1.6), gain=0.2, rev=0.2)
    S.track('cow', I.Perc('cowbell', 620, 0.1), gain=0.2, pan=-0.35)
    S.track('wood', I.Perc('wood', 1100, 0.05), gain=0.27, pan=0.4)
    S.track('bass', I.Pluck(t60=1.0, blend=0.5, bright=1600, pick=0.2, body=0.8, tail=0.05, mute=True), gain=0.6)
    S.track('tuba', I.Sub('tri', a=0.01, d=0.2, s=0.7, r=0.05, base=3, env=2, maxh=16), gain=0.35)
    S.track('brass', I.Sub('saw', a=0.015, d=0.2, s=0.75, r=0.08, base=2.2, env=6, fdecay=0.12,
                           attack_open=0.04, vib=0.004, detune=0.1), gain=0.22, rev=0.2, pan=-0.1)
    S.track('trp', I.Sub('saw', a=0.02, d=0.25, s=0.8, r=0.08, base=2.5, env=5, fdecay=0.15, attack_open=0.05,
                         vib=0.006, vib_delay=0.12, detune=0.05), gain=0.33, rev=0.2, dly=0.1)
    S.track('sax', I.Sub('square', a=0.02, d=0.3, s=0.7, r=0.08, base=2.0, env=3, attack_open=0.05, vib=0.006),
            gain=0.18, rev=0.2, pan=0.2)
    S.track('mar', I.Marimba(t60=0.4), gain=0.3, pan=0.3)
    S.track('piano', I.Piano(t60=1.2), gain=0.35, pan=-0.25, rev=0.1)

    A = S.prog('F D7 Gm7 C7 F D7 Gm7 C7', 0)
    B = S.prog('Bb Bdim7 F D7 Gm7 C7 F C7', 8)
    S.drum('kick', 0, 'x...x...x...x...', times=16, vel=0.8)
    S.drum('snare', 0, '....x.......x..g', times=15)
    S.drum('snare', 15, 'x..xx..xX.X.XXXX')
    S.drum('ride', 0, 'x.xxx.xx', 0.5, times=16)
    S.drum('crash', 0, 'x')
    S.drum('crash', 8, 'x')
    S.drum('crash', 14, 'x', vel=0.7)
    S.drum('cow', 0, 'x.......x...x...', times=8, vel=0.6)
    S.drum('wood', 8, '..x.x...x.x.x...', times=8, vel=0.7)
    S.walk('bass', A + B, lo=29)
    S.bass('tuba', A, 'R . F .', 0.5, lo=29, vel=0.6)
    S.stab('brass', A + B, '..x...x...x..x..', 0.25, lo=60, gate=0.5, vel=0.8)
    S.stab('piano', A + B, 'x.x.x.x.', 0.5, lo=55, gate=0.5, vel=0.45)
    melA = ('C5 . F5 . A5 . C6 - | - . A5 . F#5 . D5 . | Bb4 . D5 . G5 . Bb5 - | - . G5 . E5 . C5 . |'
            'A5 A5 . A5 . C6 . A5 | F#5 . A5 . C6 . D6 . | Bb5 . A5 . G5 . F5 . | E5 . G5 . C6 . . .')
    melB = ('D6 - - . Bb5 . D6 . | D6 - - . Ab5 . F5 . | C6 - - . A5 . F5 . | F#5 . A5 . D6 . C6 . |'
            'Bb5 - - A5 G5 - F5 - | E5 - G5 - Bb5 - C6 - | A5 . C6 . F6 . . . | . . C6! . C6! . C6! .')
    S.seq('trp', 0, melA, 0.5, vel=0.85, gate=0.8)
    S.seq('mar', 0, melA, 0.5, vel=0.45, octave=1)
    S.seq('trp', 8, melB, 0.5, vel=0.9, gate=0.8)
    S.seq('sax', 8, melB, 0.5, vel=0.7, octave=-1, gate=0.8)
    return S


# ===========================================================================
@song
def song_micro():
    S = Song('micro', 160, 16, transpose=0, rev_time=0.8, dly_beats=0.75, dly_fb=0.3)
    S.track('kick', I.Kick(f0=160, f1=55, t60=0.25, click=0.5), gain=0.65)
    S.track('snare', I.Snare(tone=220, t60=0.14, snap=0.5), gain=0.4, rev=0.1)
    S.track('nhat', I.ChipNoise(period=1, decay=0.04), gain=0.12, pan=0.2)
    S.track('nsn', I.ChipNoise(period=5, decay=0.12), gain=0.14)
    S.track('bass', I.Sub('saw', a=0.002, d=0.08, s=0.3, r=0.03, base=1.5, env=10, fdecay=0.04, res=0.6,
                          drive_amt=0.6), gain=0.32)
    S.track('lead', I.ChipPulse(duty=0.5, decay=0.02, sustain=0.6, vib=0.004), gain=0.25, dly=0.15, pan=-0.1)
    S.track('lead2', I.ChipPulse(duty=0.125, decay=0.03, sustain=0.5, vib=0.004), gain=0.2, dly=0.15, pan=0.1)
    S.track('arp', I.ChipPulse(duty=0.25, decay=0.08, sustain=0.2), gain=0.12, pan=0.35, dly=0.2)
    S.track('clav', I.Pluck(t60=0.4, blend=0.25, bright=9000, mute=True, tail=0.04), gain=0.28, pan=-0.3)

    prog = S.prog('Gm7 C7 Gm7 C7 Ebmaj7 D7 Gm D7', 0) + S.prog('Gm7 C7 Gm7 C7 Ebmaj7 D7 Gm D7', 8)
    S.drum('kick', 0, 'x..x..x...x..x..', times=16)
    S.drum('snare', 0, '....x.......x..x', times=7)
    S.drum('snare', 7, '....x...x.x.xxxx')
    S.drum('snare', 8, '....x.......x..x', times=7)
    S.drum('snare', 15, 'x.x.x.x.xxxxXXXX')
    S.drum('nhat', 0, 'xxoxxxoxxxoxxxox', times=16)
    S.drum('nsn', 8, '..x...x...x...x.', times=8, vel=0.6)
    S.bass('bass', prog, 'R . O R . O . R . R O . 10 . O .', 0.25, lo=31)
    S.stab('clav', prog, '. x . . x . . x', 0.5, lo=62, gate=0.35, top=3, vel=0.6)
    mel = ('G5 . Bb5 . D6 . F6 D6 | E6 . C6 . G5 . Bb5 . | G5 . Bb5 G5 D6 . C6 Bb5 | C6 . . E6 . . G6 . |'
           'G6 . F6 . D6 . Bb5 . | A5 . F#5 . A5 . C6 . | Bb5 . D6 . G6 . D6 . | F#6 . D6 . A5 . F#5 .')
    S.seq('lead', 0, mel, 0.5, vel=0.9, gate=0.75, octave=-1)
    S.seq('lead2', 8, mel, 0.5, vel=0.9, gate=0.6)
    S.seq('lead', 8, mel, 0.5, vel=0.5, gate=0.6, octave=-1)
    S.arp('arp', prog[8:], '0 1 2 3 2 1 0 1', 0.25, lo=67, vel=0.8)
    return S


# ===========================================================================
@song
def song_chip():
    S = Song('chip', 150, 16, transpose=2, rev_time=0.6, dly_beats=0.25, dly_fb=0.2, dly_lp=6000)
    S.track('p1', I.ChipPulse(duty=0.5, decay=0.025, sustain=0.7, vib=0.005, vib_delay=0.18), gain=0.28)
    S.track('p2', I.ChipPulse(duty=0.25, decay=0.05, sustain=0.35), gain=0.15, dly=0.3, pan=0.15)
    S.track('p2b', I.ChipPulse(duty=0.125, decay=0.02, sustain=0.6), gain=0.14, pan=0.15)
    S.track('tri', I.ChipTri(), gain=0.36)
    S.track('nk', I.ChipNoise(period=10, decay=0.07, start_period=6), gain=0.35)
    S.track('ns', I.ChipNoise(period=5, decay=0.14), gain=0.25)
    S.track('nh', I.ChipNoise(period=0, decay=0.035, short=False), gain=0.16)

    A = S.prog('C F G C Am F G G', 0)
    B = S.prog('F G Em Am Dm G C G', 8)
    for tr in S.tracks.values():
        tr.humanize = 0
    S.drum('nk', 0, 'x.....x.x.......', times=15)
    S.drum('ns', 0, '....x.......x...', times=15)
    S.drum('nh', 0, 'x.x.x.x.x.x.x.x.', times=16, vel=0.8)
    S.drum('nk', 15, 'x.....x.x.x.x...')
    S.drum('ns', 15, '....x.x.xxxxxxxx')
    S.bass('tri', A + B, 'R R O R F R O R', 0.5, lo=36)
    melA = ('G5 . C6 . E6 . D6 C6 | A5 . C6 . F6 . E6 D6 | D6 . B5 . G5 . A5 B5 | C6 - - . G5 . E5 . |'
            'E5 . A5 . C6 . B5 A5 | C6 . A5 . F5 . A5 C6 | D6 - B5 - G5 - B5 - | D6 . E6 . F6 . G6 .')
    melB = ('A6 - - . G6 . F6 . | G6 - - . F6 . E6 D6 | E6 - - . D6 . B5 . | C6 - - . B5 . A5 . |'
            'D6 . F6 . A6 . F6 . | G6 . D6 . B5 . D6 . | C6 . E6 . G6 . E6 . | D6 . B5 . G5 . B5 .')
    S.seq('p1', 0, melA, 0.5, vel=1.0, gate=0.85, octave=-1)
    S.seq('p1', 8, melB, 0.5, vel=1.0, gate=0.85, octave=-1)
    S.arp('p2', A, '0 1 2 1', 0.25, lo=60, vel=0.8)
    # harmony a sixth below in B
    S.seq('p2b', 8, melB, 0.5, vel=0.7, gate=0.8, octave=-2)
    S.arp('p2', B, '0 2 1 2', 0.25, lo=55, vel=0.6)
    return S


# ===========================================================================
@song
def song_chiprpg():
    S = Song('chiprpg', 160, 16, transpose=0, rev_time=0.6, dly_beats=0.25, dly_fb=0.2, dly_lp=6000)
    S.track('p1', I.ChipPulse(duty=0.25, decay=0.02, sustain=0.75, vib=0.006, vib_delay=0.2), gain=0.24)
    S.track('p2', I.ChipPulse(duty=0.125, decay=0.06, sustain=0.3), gain=0.16, pan=0.2, dly=0.2)
    S.track('p1b', I.ChipPulse(duty=0.5, decay=0.03, sustain=0.5), gain=0.12, pan=-0.2)
    S.track('tri', I.ChipTri(), gain=0.36)
    S.track('nk', I.ChipNoise(period=11, decay=0.06, start_period=7), gain=0.35)
    S.track('ns', I.ChipNoise(period=6, decay=0.12), gain=0.25)
    S.track('nh', I.ChipNoise(period=1, decay=0.03), gain=0.16)
    for tr in S.tracks.values():
        tr.humanize = 0
    A = S.prog('Am F G Am Am F G E', 0)
    B = S.prog('Dm Am Bb E F G E E', 8)
    S.drum('nk', 0, 'x.......x.x.....', times=16)
    S.drum('ns', 0, '....x.......x...', times=15)
    S.drum('ns', 15, '....x.x.x.xxxxxx')
    S.drum('nh', 0, 'xxxxxxxxxxxxxxxx', times=16, vel=0.7)
    S.bass('tri', A + B, 'R O R O R O R O', 0.5, lo=33)
    mel = ('A5 - E5 A5 C6 - B5 A5 | C6 - A5 - F5 - A5 C6 | D6 - C6 - B5 - G5 B5 | A5 - - - - - E5 G5 |'
           'A5 - E5 A5 C6 - D6 E6 | F6 - E6 - C6 - A5 - | B5 - D6 - G6 - F6 - | E6 - - - G#5 - B5 - |'
           'F6 - - E6 D6 - A5 - | C6 - - B5 A5 - E5 - | D6 - - C6 Bb5 - F5 - | G#5 - B5 - E6 - D6 - |'
           'C6 - A5 - F6 - E6 - | D6 - B5 - G6 - F6 - | E6 - G#6 - B6 - G#6 - | E6 - D6 - C6 - B5 -')
    S.seq('p1', 0, mel, 0.5, vel=1.0, gate=0.9, octave=-1)
    S.seq('p1b', 8, mel.split('|', 8)[-1], 0.5, vel=0.8, gate=0.9, octave=-2)
    S.arp('p2', A + B, '0 1 2 1 0 1 2 3', 0.25, lo=57, vel=0.8)
    return S


# ===========================================================================
@song
def song_lofi():
    S = Song('lofi', 80, 8, transpose=0, swing=0.55, swing_unit=0.25, rev_time=1.6, rev_damp=3500,
             dly_beats=0.75, dly_fb=0.3, dly_lp=2500, target_lufs=-15.0)
    S.track('kick', I.Kick(f0=110, f1=48, t60=0.35, click=0.1, drive_amt=1.3), gain=0.8)
    S.track('snare', I.Snare(tone=175, t60=0.2, lo=700, hi=5500, snap=0.2), gain=0.55, rev=0.25)
    S.track('hat', I.Hat(t60=0.035, lo=6000, metal=0.2), gain=0.25, pan=0.25)
    S.track('rim', I.Perc('rim', 800, 0.05), gain=0.3, pan=-0.2)
    S.track('vinyl', I.NoiseFx('vinyl', seed=99), gain=0.35)
    S.track('bass', I.Sub('tri', a=0.01, d=0.3, s=0.7, r=0.08, base=2, env=2, maxh=12), gain=0.4)
    S.track('keys', I.EPiano(t60=3.0, bright=0.7, r=0.3), gain=0.34, rev=0.2, lpf=3200)
    S.track('gtr', I.Pluck(t60=1.4, blend=0.45, bright=3200, pick=0.2, tail=0.2), gain=1.6, rev=0.25, dly=0.25,
            pan=0.2)
    S.track('mel', I.EPiano(t60=2.0, bright=0.8, r=0.3), gain=0.22, rev=0.3, dly=0.2, lpf=4000, pan=-0.1)
    S.track('pad', I.Supersaw(voices=4, detune=0.12, a=0.8, d=1, s=1, r=1.0, cutoff=1400), gain=0.08, rev=0.4)
    S.master_fx = [wow_fx(0.0025, 6), tape_fx(6500, 1.2)]

    prog = S.prog('Dm9 G13 Cmaj9 Am9 Dm9 G13 Em7 A7b9', 0)
    S.drum('kick', 0, 'x......x..x.....', times=8)
    S.drum('snare', 0, '....x.......x..g', times=8)
    S.drum('hat', 0, 'x.xox.xox.xox.xo', times=8, vel=0.8)
    S.drum('rim', 0, '......x.......x.', times=8, vel=0.5)
    S.note('vinyl', 0, None, 32, 1.0)
    S.bass('bass', prog, 'R - - - - - . R F - - - - . O .', 0.25, lo=33)
    S.stab('keys', prog, 'x - - - - - - . . . x - . . . .', 0.25, lo=55, gate=0.95, vel=0.6, strum=0.02)
    S.pad('pad', prog, lo=60, vel=0.6)
    mel = ('. . F5 A5 C6 - - E5 | - - D5 - . . E5 F5 | G5 - - - E5 - D5 - | C5 - - - . . . . |'
           '. . A5 C6 E6 - D6 C6 | B5 - - - A5 - G5 - | G5 - - - B5 - D6 - | C#6 - - - . . . .')
    S.seq(['gtr', 'mel'], 0, mel, 0.5, vel=0.75, gate=0.95)
    return S


# ===========================================================================
@song
def song_casino():
    S = Song('casino', 128, 16, transpose=0, rev_time=1.5, dly_beats=0.75, dly_fb=0.3)
    edm_kit(S, kick_gain=0.8)
    S.track('shaker', I.Shaker(t60=0.05), gain=0.12, pan=0.3)
    S.track('bass', I.Sub('saw', a=0.002, d=0.1, s=0.4, r=0.04, base=1.5, env=10, fdecay=0.05, res=0.6,
                          drive_amt=0.4), gain=0.32, duck=0.3)
    S.track('gtr', I.Pluck(t60=0.4, blend=0.25, bright=9000, pick=0.1, mute=True, tail=0.03), gain=0.35,
            pan=-0.3)
    S.track('brass', I.Sub('saw', a=0.01, d=0.2, s=0.7, r=0.06, base=2.4, env=6, attack_open=0.03, detune=0.12),
            gain=0.28, rev=0.2, pan=0.1)
    S.track('lead', I.FM(ratio=2.0, index=1.6, idecay=0.2, isus=0.35, t60=1.4, r=0.1), gain=0.3, rev=0.2,
            dly=0.2)
    S.track('glock', I.Glock(t60=0.8), gain=0.22, rev=0.3, pan=0.2, dly=0.2)
    S.track('gliss', I.Bell(t60=0.8, index=1.8), gain=0.18, rev=0.35, pan=0.3)
    S.track('strings', I.Strings(a=0.08, r=0.3, cutoff=3500), gain=0.14, rev=0.3, duck=0.4)
    S.track('ep', I.EPiano(t60=1.5), gain=0.3, pan=-0.15, rev=0.15)

    A = S.prog('Am7 D9 Am7 D9 Am7 D9 Am7 D9', 0)
    B = S.prog('Fmaj7 G6 Em7 Am7 Dm7 G7 Cmaj7 E7#9', 8)
    S.duck_every(1.0, release=0.35)
    S.drum('kick', 0, 'x...x...x...x...', times=16)
    S.drum('clap', 0, '....x.......x...', times=16)
    S.drum('ohat', 0, '..x...x...x...x.', times=16)
    S.drum('hat', 0, 'x.xxx.xxx.xxx.xx', times=16, vel=0.7)
    S.drum('shaker', 8, 'xoxoxoxoxoxoxoxo', times=8)
    S.drum('crash', 0, 'x')
    S.drum('crash', 8, 'x')
    fill_16(S, 'snare', 15, '....x.x.xxxxXXXX')
    S.note('riser', 15 * 4, None, 4, 0.8)
    S.bass('bass', A + B, 'R . O . R R O . R . O . R O 10 O', 0.25)
    S.stab('gtr', A + B, '. x . x . x . x . x . x . x . x', 0.25, lo=64, gate=0.3, top=3, vel=0.55)
    S.stab('brass', A, '......x.......x.', 0.25, lo=64, gate=0.5, vel=0.8)
    S.stab('ep', A, 'x.......', 0.5, lo=57, gate=0.9, vel=0.5)
    S.pad('strings', B, lo=60, vel=0.7)
    S.stab('brass', B, 'x..x..x.........', 0.25, lo=64, gate=0.4, vel=0.75)
    for b in (3, 7, 11, 15):
        S.arp('gliss', S.prog('Am7' if b < 8 else 'E7#9', b),
              '. . . . . . . . . . . . . . . . . . . . 0 1 2 3 4 5 6 7 8 9 10 11', 0.125, lo=72, vel=0.5)
    melA = ('E5 . G5 A5 . C6 . A5 | . F#5 . A5 . E5 . D5 | E5 . G5 A5 . C6 . E6 | D6 . C6 A5 . F#5 . . |'
            'E5 . G5 A5 . C6 . A5 | . F#5 . A5 . E5 . D5 | E5 . G5 A5 . C6 D6 E6 | G6 . E6 D6 . C6 A5 .')
    melB = ('A5 - C6 - E6 - . C6 | D6 - - B5 . G5 . E5 | G5 - B5 - D6 - . B5 | C6 - - A5 . E5 . . |'
            'F5 . A5 . C6 . F6 . | F6 . D6 . B5 . G5 . | E6 - - - G6 - E6 - | G#5 . B5 . D6 . G6 .')
    S.seq('lead', 0, melA, 0.5, vel=0.85, gate=0.8)
    S.seq('glock', 4, melA.split('|', 4)[-1], 0.5, vel=0.5, octave=1)
    S.seq('lead', 8, melB, 0.5, vel=0.9, gate=0.85)
    S.seq('glock', 8, melB, 0.5, vel=0.55)
    return S


# ===========================================================================
@song
def song_spooky():
    S = Song('spooky', 100, 12, transpose=0, rev_time=2.2, rev_damp=5000, dly_beats=0.75, dly_fb=0.3)
    S.track('kick', I.Kick(f0=110, f1=50, t60=0.35, click=0.1, drive_amt=1.0), gain=0.55, rev=0.1)
    S.track('snap', I.Perc('snap', seed=86, t60=0.08), gain=0.45, rev=0.25)
    S.track('tick', I.Perc('wood', 1400, 0.04), gain=0.25, pan=0.35)
    S.track('bone', I.Perc('wood', 650, 0.06, seed=87), gain=0.28, pan=-0.35)
    S.track('pizz', I.Pluck(t60=0.35, blend=0.5, bright=2500, pick=0.3, mute=True, tail=0.1, body=0.6),
            gain=0.65)
    S.track('harp', I.Pluck(t60=1.2, blend=0.12, bright=12000, pick=0.1, octave_layer=0.4, tail=0.2), gain=0.48,
            rev=0.25, pan=0.2)
    S.track('organ', I.Organ(bars=(0.5, 1.0, 0.6, 0.0, 0.4, 0.0, 0.2), leslie=0.006), gain=0.14, rev=0.35,
            pan=-0.15)
    S.track('theremin', I.Sub('tri', a=0.08, d=0.5, s=0.9, r=0.2, base=2.5, env=1, vib=0.022, vib_rate=6.0,
                              vib_delay=0.05, maxh=10), gain=0.22, rev=0.4, dly=0.2)
    S.track('celesta', I.Glock(t60=0.9, bright=0.6), gain=0.2, rev=0.4, pan=0.3)

    A = S.prog('Dm Dm Gm A7 Dm Bb Gm6,A7 Dm', 0)
    B = S.prog('Gm Dm E7 A7', 8)
    S.drum('kick', 0, 'x.......x.......', times=12)
    S.drum('snap', 0, '....x.......x...', times=12)
    S.drum('tick', 0, '..x...x...x...x.', times=12, vel=0.6)
    S.drum('bone', 4, 'x..x..x.....x.x.', times=4, vel=0.7)
    S.drum('bone', 11, 'x.x.x.x.xxxxxxxx', vel=0.7)
    S.bass('pizz', A, 'R . F . R . F .', 0.5, lo=38)
    S.bass('pizz', B, 'R . F . O . F .', 0.5, lo=38)
    S.pad('organ', A + B, lo=57, vel=0.5)
    melA = ('D5 . F5 . A5 . G#5 A5 | . . D6 . A5 . F5 . | G5 . Bb5 . D6 . C#6 D6 | . . C#6 . A5 . E5 G5 |'
            'F5 . E5 . D5 . A4 . | Bb4 . D5 . F5 . Bb5 . | E5 . G5 . C#5 . E5 . | D5 . . . D4 . . .')
    melB = 'Bb5 - - - A5 - G5 - | A5 - - - F5 - D5 - | G#5 - - - B5 - D6 - | C#6 - - - A5 - . .'
    S.seq('harp', 0, melA, 0.5, vel=0.85, gate=0.6)
    S.seq('celesta', 4, melA.split('|', 4)[-1], 0.5, vel=0.5, octave=1)
    S.seq('theremin', 8, melB, 0.5, vel=0.8)
    S.arp('harp', B, '0 1 2 1', 0.5, lo=62, vel=0.45)
    return S


# ===========================================================================
@song
def song_sports():
    S = Song('sports', 130, 16, transpose=0, rev_time=1.8, dly_beats=0.75, dly_fb=0.25)
    S.track('kick', I.Kick(f0=130, f1=52, t60=0.35, click=0.6, drive_amt=2.0), gain=0.85)
    S.track('snare', I.Snare(tone=195, t60=0.3, snap=0.4), gain=0.5, rev=0.35)
    S.track('clap', I.Clap(t60=0.2), gain=0.4, rev=0.3)
    S.track('hat', I.Hat(t60=0.05), gain=0.25, pan=0.3)
    S.track('crash', I.Cymbal(t60=2.0), gain=0.24, rev=0.25, pan=-0.2)
    S.track('tom', I.Tom(t60=0.35), gain=0.45, rev=0.25)
    S.track('bass', I.Sub('saw', a=0.003, d=0.15, s=0.7, r=0.05, base=2.0, env=4, fdecay=0.08, drive_amt=0.8),
            gain=0.35)
    S.track('gtrL', I.Sub('saw', a=0.003, d=0.2, s=0.8, r=0.05, base=5, env=5, fdecay=0.08, detune=0.12,
                          drive_amt=3.0, maxh=40), gain=0.18, pan=-0.45)
    S.track('gtrR', I.Sub('saw', a=0.004, d=0.2, s=0.8, r=0.05, base=5, env=5, fdecay=0.08, detune=0.15,
                          drive_amt=3.0, maxh=40), gain=0.18, pan=0.45)
    S.track('lead', I.Sub('saw', a=0.02, d=0.25, s=0.85, r=0.1, base=3, env=5, fdecay=0.15, attack_open=0.04,
                          vib=0.005, detune=0.08), gain=0.4, rev=0.25, dly=0.15)
    S.track('ss', I.Supersaw(voices=5, detune=0.16, a=0.01, d=0.4, s=0.85, r=0.15, cutoff=6000), gain=0.22,
            rev=0.3, octave=-1)
    S.track('organ', I.Organ(bars=(0.3, 1.0, 0.8, 0.5, 0.5, 0.3, 0.3), perc=0.3), gain=0.14, pan=0.2, rev=0.2)

    A = S.prog('E D A E E D A B', 0)
    B = S.prog('C D E E C D B B', 8)
    PA = S.prog('E5 D5 A5 E5 E5 D5 A5 B5', 0)
    PB = S.prog('C5 D5 E5 E5 C5 D5 B5 B5', 8)
    S.drum('kick', 0, 'x.....x.x.x.....', times=16)
    S.drum('snare', 0, '....X.......X...', times=15)
    S.drum('clap', 0, '....x.......x...', times=16)
    S.drum('hat', 0, 'x.x.x.x.x.x.x.x.', times=16)
    for b in (0, 4, 8, 12):
        S.drum('crash', b, 'x')
    S.drum('tom', 7, '........x.x.x.x.', pitch='A2')
    S.drum('tom', 7, '............x.x.', pitch='E2')
    S.drum('tom', 15, 'x.x.x.x.', 0.25, pitch='A2')
    S.drum('tom', 15, '........x.x.x.x.', pitch='D2')
    S.drum('snare', 15, 'x...x.....xxXXXX')
    S.bass('bass', A + B, 'R R R R R R R R', 0.5, lo=28)
    S.stab('gtrL', PA + PB, 'x x x x x x x x', 0.5, lo=40, gate=0.45, vel=0.8)
    S.stab('gtrR', PA + PB, 'x - - - x - x -', 0.5, lo=40, gate=0.95, vel=0.8)
    S.pad('organ', B, lo=59, vel=0.6)
    melA = ('B4 - E5 - F#5 - G#5 - | A5 - - - F#5 - D5 - | E5 - C#5 - A4 - C#5 E5 | B4 - - - - - . . |'
            'B4 - E5 - F#5 - G#5 - | A5 - - - B5 - A5 - | C#6 - B5 - A5 - F#5 - | B5 - - - D#5 - F#5 -')
    melB = ('G5 - - - E5 - G5 - | A5 - - - F#5 - A5 - | B5 - - - G#5 - B5 - | E6 - - - - - . . |'
            'E6 - D6 - C6 - G5 - | F#5 - A5 - D6 - A5 - | B5 - - - A5 - F#5 - | D#5 - F#5 - B5 - - -')
    S.seq('lead', 0, melA, 0.5, vel=0.85)
    S.seq(['lead', 'ss'], 8, melB, 0.5, vel=0.9)
    return S


# ===========================================================================
@song
def song_synth():
    S = Song('synth', 110, 16, transpose=0, rev_time=2.4, rev_damp=5000, dly_beats=0.75, dly_fb=0.4,
             dly_lp=3000)
    S.track('kick', I.Kick(f0=150, f1=48, t60=0.4, click=0.3), gain=0.8)
    S.track('snare', I.Snare(tone=180, t60=0.25, snap=0.3), gain=0.45, rev=0.7)
    S.track('clap', I.Clap(t60=0.25), gain=0.25, rev=0.6)
    S.track('hat', I.Hat(t60=0.04), gain=0.21, pan=0.3)
    S.track('tom', I.Tom(t60=0.5, bend=0.6), gain=0.4, rev=0.5)
    S.track('crash', I.Cymbal(t60=2.2), gain=0.18, rev=0.3)
    S.track('bass', I.Sub('saw', a=0.002, d=0.1, s=0.5, r=0.04, base=1.6, env=6, fdecay=0.05, maxh=40),
            gain=0.32, duck=0.3)
    S.track('pad', I.Supersaw(voices=6, detune=0.18, a=0.25, d=1, s=1, r=0.6, cutoff=2800), gain=0.16, rev=0.4,
            duck=0.35)
    S.track('arp', I.Sub('saw', a=0.001, d=0.12, s=0.0, r=0.08, base=1.5, env=10, fdecay=0.05, detune=0.06),
            gain=0.22, dly=0.3, rev=0.2, pan=0.3)
    S.track('lead', I.Sub('saw', a=0.01, d=0.3, s=0.85, r=0.15, base=3, env=4, fdecay=0.2, vib=0.006,
                          vib_delay=0.25, detune=0.1), gain=0.3, rev=0.35, dly=0.3)
    S.track('bell', I.Bell(t60=1.4, index=2.0), gain=0.16, rev=0.4, dly=0.3, pan=-0.3)

    A = S.prog('Am F C G Am F C G', 0)
    B = S.prog('F G Am Am F G Em G', 8)
    S.duck_every(1.0, release=0.4)
    S.drum('kick', 0, 'x.......x.......', times=16)
    S.drum('kick', 8, '..........x.....', times=8, vel=0.6)
    S.drum('snare', 0, '....x.......x...', times=15)
    S.drum('clap', 0, '....x.......x...', times=16)
    S.drum('hat', 0, 'xoxoxoxoxoxoxoxo', times=16)
    S.drum('crash', 0, 'x')
    S.drum('crash', 8, 'x')
    S.drum('tom', 7, '........x.x.x.x.', pitch='G2')
    S.drum('tom', 15, 'x.x.x.x.', 0.25, pitch='A2')
    S.drum('tom', 15, '........x.x.x.x.', pitch='D2')
    S.bass('bass', A + B, 'R R O R R O R O R R O R R O R O', 0.25, lo=33)
    S.pad('pad', A + B, lo=57, vel=0.7)
    S.arp('arp', B, '0 1 2 3 4 3 2 1', 0.25, lo=64, vel=0.6)
    mel = ('E5 - - - A5 - B5 - | C6 - - - B5 - A5 - | G5 - - - E5 - G5 - | D5 - - - - - . . |'
           'E5 - - - A5 - B5 - | C6 - - - D6 - E6 - | G6 - - - E6 - C6 - | D6 - - - B5 - G5 - |'
           'A5 - C6 - F6 - E6 - | D6 - - - B5 - G5 - | C6 - E6 - A6 - G6 - | E6 - - - - - . . |'
           'A5 - C6 - F6 - E6 - | G6 - F6 - E6 - D6 - | E6 - - - B5 - G5 - | D6 - - - B5 - - -')
    S.seq('lead', 0, mel, 0.5, vel=0.85, octave=-1)
    S.seq('bell', 8, mel.split('|', 8)[-1], 0.5, vel=0.6)
    return S


# ===========================================================================
@song
def song_space():
    S = Song('space', 100, 12, transpose=0, rev_time=3.5, rev_damp=5500, dly_beats=0.75, dly_fb=0.45,
             dly_lp=4000)
    S.track('kick', I.Kick(f0=120, f1=45, t60=0.45, click=0.1), gain=0.6)
    S.track('rim', I.Perc('rim', 900, 0.05), gain=0.28, rev=0.4, pan=-0.3)
    S.track('hat', I.Hat(t60=0.03, metal=0.3), gain=0.18, pan=0.35)
    S.track('shaker', I.Shaker(t60=0.05), gain=0.15, pan=-0.35)
    S.track('sub', I.Sub('tri', a=0.05, d=0.5, s=0.9, r=0.3, base=2, env=1, maxh=8), gain=0.3)
    S.track('pad', I.Supersaw(voices=6, detune=0.2, a=0.9, d=1, s=1, r=1.2, cutoff=2200), gain=0.17, rev=0.55)
    S.track('choir', I.Choir('u', a=0.6, r=1.0, voices=3), gain=0.3, rev=0.55)
    S.track('arp', I.Sub('pulse', duty=0.3, a=0.001, d=0.1, s=0.0, r=0.08, base=2, env=8, fdecay=0.04),
            gain=0.22, dly=0.45, rev=0.3, pan=0.25)
    S.track('bell', I.Bell(t60=2.5, index=2.2), gain=0.36, rev=0.5, dly=0.35)
    S.track('riser', I.NoiseFx('riser', hi=7000), gain=0.08, rev=0.5)

    A = S.prog('Cmaj7 Cmaj7 D/C D/C Bm7 Em7 Am7 D', 0)
    B = S.prog('Cmaj7 D Em7 D', 8)
    S.drum('kick', 0, 'x.......x.......', times=12)
    S.drum('kick', 8, '......x.......x.', times=4, vel=0.5)
    S.drum('rim', 0, '....x.......x...', times=12, vel=0.7)
    S.drum('hat', 4, 'xoxoxoxoxoxoxoxo', times=8, vel=0.8)
    S.drum('shaker', 8, '..x...x...x...x.', times=4)
    S.note('riser', 7 * 4, None, 4, 0.8)
    S.note('riser', 11 * 4, None, 4, 0.8)
    S.bass('sub', A + B, 'R - - - - - - -', 0.5, lo=28)
    S.pad('pad', A + B, lo=55, vel=0.7)
    S.pad('choir', B, lo=60, vel=0.6)
    S.arp('arp', A + B, '0 1 2 3 1 2 3 4 2 3 4 5 3 4 5 6', 0.25, lo=60, vel=0.6)
    mel = ('G5 - - - B5 - - - | D6 - - - . . E6 - | F#6 - - - E6 - D6 - | A5 - - - - - . . |'
           'B5 - - - D6 - F#6 - | G6 - - - F#6 - E6 - | C6 - - - E6 - G6 - | F#6 - - - - - . . |'
           'E6 - - - D6 - B5 - | A5 - - - F#5 - A5 - | B5 - - - G5 - E5 - | F#5 - - - A5 - D6 -')
    S.seq('bell', 0, mel, 0.5, vel=0.8)
    return S


# ===========================================================================
@song
def song_boss():
    S = Song('boss', 170, 16, transpose=0, rev_time=1.8, rev_damp=5000, dly_beats=0.5, dly_fb=0.25)
    S.track('kick', I.Kick(f0=150, f1=48, t60=0.3, click=0.6, drive_amt=2.0), gain=0.7)
    S.track('snare', I.Snare(tone=200, t60=0.22, snap=0.5), gain=0.45, rev=0.3)
    S.track('hat', I.Hat(t60=0.04), gain=0.21, pan=0.3)
    S.track('crash', I.Cymbal(t60=1.8), gain=0.2, rev=0.2)
    S.track('timp', I.Timpani(t60=1.2), gain=0.4, rev=0.3)
    S.track('hit', I.OrchHit(t60=0.7), gain=0.42, rev=0.35)
    S.track('bass', I.Sub('saw', a=0.002, d=0.08, s=0.5, r=0.03, base=1.8, env=6, fdecay=0.04, res=0.5,
                          drive_amt=1.0), gain=0.32)
    S.track('str', I.Sub('saw', a=0.003, d=0.1, s=0.5, r=0.05, base=3, env=4, fdecay=0.05, detune=0.1),
            gain=0.22, pan=-0.3, rev=0.2)
    S.track('choir', I.Choir('a', a=0.15, r=0.5, voices=3), gain=0.33, rev=0.45)
    S.track('lead', I.Sub('saw', a=0.01, d=0.2, s=0.85, r=0.08, base=3, env=5, fdecay=0.12, attack_open=0.03,
                          vib=0.006, vib_delay=0.2, detune=0.1, drive_amt=0.5), gain=0.3, rev=0.25, dly=0.12)
    S.track('ss', I.Supersaw(voices=5, detune=0.18, a=0.01, d=0.3, s=0.85, r=0.12, cutoff=6000), gain=0.2,
            rev=0.3, octave=1, pan=0.2)

    A = S.prog('Em Em C D Em Em F B', 0)
    B = S.prog('Am Em C B Am Em F B', 8)
    S.drum('kick', 0, 'x...x...x...x...', times=8)
    S.drum('kick', 8, 'x.x.x.x.x.x.x.xx', times=8)
    S.drum('snare', 0, '....x.......x...', times=15)
    S.drum('snare', 15, 'x.xxx.xxXXXXXXXX')
    S.drum('hat', 0, 'x.x.x.x.x.x.x.x.', times=16)
    for b in (0, 4, 8, 12):
        S.drum('crash', b, 'x')
    for b, p in ((0, 'E2'), (4, 'E2'), (6, 'F2'), (7, 'B1'), (8, 'A1'), (12, 'A1'), (14, 'F2'), (15, 'B1')):
        S.drum('timp', b, 'x...........x.x.', pitch=p, vel=0.8)
    for b, p in ((0, 'E3'), (2, 'C3'), (3, 'D3'), (4, 'E3'), (6, 'F3'), (7, 'B2'), (8, 'A2'), (10, 'C3'),
                 (11, 'B2'), (12, 'A2'), (14, 'F3'), (15, 'B2')):
        S.drum('hit', b, 'x', pitch=p, vel=0.9)
    S.bass('bass', A + B, 'R R O R R R O R R R O R 1 R O R', 0.25, lo=28)
    S.arp('str', A + B, '0 1 0 2 0 1 0 2', 0.25, lo=64, vel=0.6)
    S.pad('choir', A + B, lo=57, vel=0.6)
    mel = ('E5 - - - B5 - - - | C6 - B5 - A5 - G5 - | E5 - - - G5 - C6 - | D6 - C6 - B5 - A5 - |'
           'B5 - - - E6 - - - | F6 - E6 - D6 - B5 - | C6 - - - A5 - F5 - | D#5 - F#5 - B5 - D#6 - |'
           'E6 - - - C6 - A5 - | B5 - - - G5 - E5 - | G5 - C6 - E6 - G6 - | F#6 - - - D#6 - B5 - |'
           'A5 - C6 - E6 - A6 - | G6 - F#6 - E6 - B5 - | C6 - - - A5 - F5 - | B5 - - - D#6 - F#6 -')
    S.seq('lead', 0, mel, 0.5, vel=0.9, octave=-1)
    S.seq('ss', 8, mel.split('|', 8)[-1], 0.5, vel=0.7, octave=-1)
    return S


# ===========================================================================
@song
def song_secret():
    S = Song('secret', 140, 16, transpose=0, rev_time=2.8, rev_damp=5000, dly_beats=0.75, dly_fb=0.25)
    S.track('kick', I.Kick(f0=140, f1=45, t60=0.4, click=0.5, drive_amt=2.0), gain=0.65)
    S.track('snare', I.Snare(tone=200, t60=0.25, snap=0.4), gain=0.42, rev=0.35)
    S.track('taiko', I.Taiko(f=60, t60=1.0), gain=0.55, rev=0.3)
    S.track('timp', I.Timpani(t60=1.4), gain=0.45, rev=0.35)
    S.track('crash', I.Cymbal(t60=2.2), gain=0.22, rev=0.3)
    S.track('hat', I.Hat(t60=0.05), gain=0.2, pan=0.3)
    S.track('hit', I.OrchHit(t60=0.9), gain=0.3, rev=0.4)
    S.track('riser', I.NoiseFx('riser', hi=9000), gain=0.12, rev=0.4)
    S.track('organ', I.Organ(bars=(0.7, 1.0, 0.8, 0.5, 0.7, 0.3, 0.5), leslie=0.003, click=0.3), gain=0.26,
            rev=0.4, pan=-0.2)
    S.track('opad', I.Organ(bars=(1.0, 1.0, 0.6, 0.3, 0.3, 0.0, 0.2), leslie=0.005, click=0.0, a=0.05, r=0.3),
            gain=0.14, rev=0.5, pan=0.2)
    S.track('pedal', I.Organ(bars=(1.0, 1.0, 0.5, 0.2, 0.0, 0.0, 0.0), a=0.03, r=0.3, click=0.0), gain=0.35)
    S.track('choir', I.Choir('a', a=0.12, r=0.6, voices=3, bright=1.1), gain=0.48, rev=0.5)
    S.track('brass', I.Sub('saw', a=0.03, d=0.3, s=0.85, r=0.15, base=2.5, env=5, fdecay=0.2, attack_open=0.06,
                           vib=0.005, detune=0.1), gain=0.28, rev=0.35)
    S.track('bass', I.Sub('saw', a=0.003, d=0.1, s=0.6, r=0.05, base=1.6, env=5, fdecay=0.05, drive_amt=0.7),
            gain=0.3)

    A = S.prog('Cm Ab Bb G Cm Ab Fm G', 0)
    B = S.prog('Ab Bb Cm Cm Fm G Cm G', 8)
    # build: A1 organ + timpani, A2 add taiko + snare march, B full band
    S.drum('timp', 0, 'x.......x.......', pitch='C2', times=4, vel=0.8)
    S.drum('timp', 4, 'x.......x...x.x.', pitch='C2', times=3, vel=0.9)
    S.drum('timp', 7, 'x.x.x.x.xxxxxxxx', pitch='G1', vel=0.9)
    S.drum('taiko', 4, 'x.....x.x.......', times=4)
    S.drum('snare', 4, '..g.x.g...g.x.gg', times=3, vel=0.7)
    S.drum('snare', 7, 'x.x.x.x.xxxxXXXX')
    S.note('riser', 7 * 4, None, 4, 1.0)
    S.drum('kick', 8, 'x.x...x.x.x...x.', times=7)
    S.drum('kick', 15, 'x.x.x.x.x.x.x.x.')
    S.drum('snare', 8, '....x.......x...', times=7)
    S.drum('snare', 15, 'x.xxx.xxXXXXXXXX')
    S.drum('hat', 8, 'x.x.x.x.x.x.x.x.', times=8)
    S.drum('taiko', 8, 'x.......x.x.....', times=8, vel=0.8)
    for b in (0, 8, 12):
        S.drum('crash', b, 'x')
    for b, p in ((8, 'Ab2'), (10, 'C3'), (12, 'F2'), (14, 'C3'), (15, 'G2')):
        S.drum('hit', b, 'x', pitch=p)
    S.drum('hit', 0, 'x', pitch='C3', vel=0.8)
    S.note('riser', 15 * 4, None, 4, 0.9)
    S.arp('organ', A + B, '3 2 1 0 1 2 3 2 3 2 1 0 1 2 3 4', 0.25, lo=60, vel=0.7)
    S.pad('opad', A + B, lo=55, vel=0.6)
    S.bass('pedal', A + B, 'R - - - - - - -', 0.5, lo=24, vel=0.8)
    S.bass('bass', B, 'R R R R R R O R', 0.5, lo=36)
    mel = ('C5 - - - G5 - - - | Ab5 - - - G5 - Eb5 - | F5 - - - D5 - Bb4 - | B4 - - - D5 - G5 - |'
           'C6 - - - Bb5 - G5 - | Ab5 - - - C6 - Eb6 - | F6 - - - Eb6 - C6 - | D6 - - - B5 - G5 - |'
           'C6 - - - Eb6 - Ab6 - | G6 - - - F6 - D6 - | Eb6 - - - G6 - C6 - | C6 - - - - - . . |'
           'C6 - Ab5 - F5 - Ab5 - | B5 - D6 - F6 - D6 - | Eb6 - D6 - C6 - G5 - | B5 - - - D6 - G6 -')
    S.seq('choir', 0, mel, 0.5, vel=0.8, octave=-1)
    S.seq('brass', 8, mel.split('|', 8)[-1], 0.5, vel=0.9, octave=-1)
    return S
