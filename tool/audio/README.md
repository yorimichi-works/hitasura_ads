# Procedural audio (SFX + BGM)

Every sound effect and music loop used by the arcade (`lib/arcade/engine/sfx.dart`,
classes `Sfx` and `Bgm`) is synthesised from code in this folder. No samples are used.

## Regenerate

Requirements: Python 3.10+ with `numpy` and `lameenc` (`pip install numpy lameenc`).

```sh
python tool/audio/synth.py              # all SFX + all BGM (a few minutes)
python tool/audio/synth.py sfx          # only sound effects
python tool/audio/synth.py sfx coin ssr # selected sound effects
python tool/audio/synth.py bgm menu     # selected music loops
```

Outputs:

- `assets/audio/sfx/<name>.mp3` - mono, 44.1 kHz, 128 kbps, peak -1 dBFS
- `assets/audio/bgm/<name>.mp3` - stereo, 44.1 kHz, 128 kbps (112 kbps for loops over 34 s),
  about -14 LUFS, true peak kept under -1 dBFS by a look-ahead limiter

The script reads the expected names from `sfx.dart` and fails if a generator is
missing, then prints a table (duration, size, peak, RMS, loudness, limiter gain
reduction) and verifies every file exists and is a valid MP3.

## Files

| file | contents |
| --- | --- |
| `synth.py` | entry point, name discovery, parallel rendering, verification |
| `dsp.py` | oscillators (polyBLEP saw/pulse), envelopes, FFT + state-variable filters, Karplus-Strong, reverb IR, NES pulse/triangle/LFSR noise |
| `sfx.py` | one function per sound effect (`@sfx('name')`), plus loudness finalisation |
| `instruments.py` | music instruments: additive subtractive synth, supersaw, FM (EP/bells), marimba, glock, KS plucks, organ, formant choir, piano, 2A03 chip voices, synthesised drums |
| `music.py` | chord theory, tracker-style sequencer, circular mixer (reverb, ping-pong delay, sidechain ducking), loudness + limiter |
| `songs.py` | the 18 compositions (`@song def song_<name>()`) |
| `audio_io.py` | MP3 encoding via lameenc, LAME/Info gapless tag, frame parser |

## Seamless loops

Each song is rendered into a circular buffer of exactly one loop length: note tails,
reverb and delay feedback that pass the loop end wrap around to the start, which is
the same as rendering the loop twice and keeping the second pass. The master limiter
is also circular, so the last sample flows straight into the first one.

MP3 encoding adds encoder delay and padding. `audio_io.py` writes a LAME `Info` tag
with the exact delay (576) and padding, so gapless-aware decoders (Chrome/Firefox
`decodeAudioData`, ExoPlayer, AVFoundation) trim it. Decoders that ignore the tag
may leave a gap of about 25 ms at the loop point.

## Writing music

Songs use a small grid notation:

```python
S = Song('menu', bpm=124, bars=16, transpose=2)
S.track('lead', I.Sub('pulse', duty=0.3, ...), gain=0.3, rev=0.2, dly=0.2)
prog = S.prog('F G Em Am F G C C', start_bar=0)      # one chord per bar, 'Gm6,A7' splits a bar
S.seq('lead', 0, 'A5 - G5 A5 C6 - A5 G5 | ...', step=0.5)  # '-' holds, '.' rests, '!' accent
S.bass('bass', prog, 'R . O R . R O .', 0.5)          # R/T/F/S chord tones, O octave, ints = semitones
S.arp('arp', prog, '0 1 2 3', 0.25, lo=67)            # indices into the voiced chord
S.stab('keys', prog, 'x..x..x.', 0.25, strum=0.02)    # chord hits
S.drum('kick', 0, 'x...x...x...x...', times=16)        # x hit, X accent, o soft, g ghost
S.duck_every(1.0)                                     # sidechain pump for tracks with duck>0
```

Everything is deterministic (fixed seeds), so regenerating produces identical audio.
