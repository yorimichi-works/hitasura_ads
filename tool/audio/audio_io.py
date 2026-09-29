"""MP3 writing (lameenc) with a LAME/Info gapless tag, plus a tiny frame parser."""
from __future__ import annotations

import os
import struct
import time

import lameenc
import numpy as np

_BITRATES_V1_L3 = [0, 32, 40, 48, 56, 64, 80, 96, 112, 128, 160, 192, 224, 256, 320, 0]
_SR_V1 = [44100, 48000, 32000, 0]
ENCODER_DELAY = 576  # LAME's encoder delay as stored in the LAME tag


def _crc16_table():
    tab = []
    for i in range(256):
        c = i
        for _ in range(8):
            c = (c >> 1) ^ 0xA001 if c & 1 else c >> 1
        tab.append(c)
    return tab


_CRC_TAB = _crc16_table()


def _crc16(data: bytes, crc: int = 0) -> int:
    for b in data:
        crc = (crc >> 8) ^ _CRC_TAB[(crc ^ b) & 0xFF]
    return crc


def parse_frames(data: bytes):
    """Returns list of (offset, length) for MPEG-1 Layer III frames."""
    frames = []
    i = 0
    n = len(data)
    while i + 4 <= n:
        if data[i] != 0xFF or (data[i + 1] & 0xE0) != 0xE0:
            i += 1
            continue
        b1, b2 = data[i + 1], data[i + 2]
        ver = (b1 >> 3) & 3
        layer = (b1 >> 1) & 3
        if ver != 3 or layer != 1:
            i += 1
            continue
        br = _BITRATES_V1_L3[(b2 >> 4) & 15]
        sr = _SR_V1[(b2 >> 2) & 3]
        if br == 0 or sr == 0:
            i += 1
            continue
        pad = (b2 >> 1) & 1
        length = 144000 * br // sr + pad
        frames.append((i, length))
        i += length
    return frames


def _info_frame(first_header: bytes, n_frames: int, total_bytes_audio: int,
                n_samples: int, bitrate: int, channels: int, sr: int) -> bytes:
    b2 = first_header[2] & ~0x02  # no padding
    header = bytes([first_header[0], first_header[1], b2, first_header[3]])
    br = _BITRATES_V1_L3[(b2 >> 4) & 15]
    frame_len = 144000 * br // sr
    side = 17 if (first_header[3] >> 6) == 3 else 32
    frame = bytearray(frame_len)
    frame[0:4] = header
    o = 4 + side
    total_bytes = total_bytes_audio + frame_len
    frame[o:o + 4] = b'Info'
    frame[o + 4:o + 8] = struct.pack('>I', 0x0F)
    frame[o + 8:o + 12] = struct.pack('>I', n_frames)
    frame[o + 12:o + 16] = struct.pack('>I', total_bytes)
    toc = bytes(min(255, i * 256 // 100) for i in range(100))
    frame[o + 16:o + 116] = toc
    frame[o + 116:o + 120] = struct.pack('>I', 0)  # quality
    L = o + 120
    frame[L:L + 9] = b'LAME3.100'
    frame[L + 9] = 0x01  # rev 0, CBR
    frame[L + 10] = 160 if sr >= 44100 else 150  # lowpass / 100 Hz
    # peak(4) radio(2) audiophile(2) = zeros
    frame[L + 19] = 0x00  # flags + ath
    frame[L + 20] = min(255, bitrate)
    padding = n_frames * 1152 - ENCODER_DELAY - n_samples
    padding = max(0, min(4095, padding))
    v = (ENCODER_DELAY << 12) | padding
    frame[L + 21:L + 24] = bytes([(v >> 16) & 0xFF, (v >> 8) & 0xFF, v & 0xFF])
    frame[L + 24] = 0  # misc
    frame[L + 25] = 0  # mp3 gain
    frame[L + 26:L + 28] = b'\x00\x00'
    frame[L + 28:L + 32] = struct.pack('>I', total_bytes)
    frame[L + 32:L + 34] = b'\x00\x00'  # music crc (optional)
    crc = _crc16(bytes(frame[:L + 34]))
    frame[L + 34:L + 36] = struct.pack('>H', crc)
    return bytes(frame)


def write_mp3(path: str, x: np.ndarray, sr: int, bitrate: int = 128) -> dict:
    """x: float array (n,) mono or (n,2) stereo in [-1,1]."""
    x = np.asarray(x, dtype=float)
    channels = 1 if x.ndim == 1 else x.shape[1]
    pcm = np.clip(np.round(x * 32767.0), -32768, 32767).astype('<i2')
    enc = lameenc.Encoder()
    enc.set_bit_rate(bitrate)
    enc.set_in_sample_rate(sr)
    enc.set_out_sample_rate(sr)
    enc.set_channels(channels)
    enc.set_quality(2)
    data = bytes(enc.encode(pcm.tobytes())) + bytes(enc.flush())
    frames = parse_frames(data)
    if not frames:
        raise RuntimeError('lameenc produced no frames for ' + path)
    start = frames[0][0]
    audio = data[start:]
    info = _info_frame(audio[:4], len(frames), len(audio), x.shape[0], bitrate, channels, sr)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    tmp = path + '.tmp'
    with open(tmp, 'wb') as fh:
        fh.write(info)
        fh.write(audio)
    for attempt in range(20):  # the file may be briefly locked (indexer, running app)
        try:
            os.replace(tmp, path)
            break
        except PermissionError:
            if attempt == 19:
                raise
            time.sleep(0.5)
    return {
        'path': path,
        'bytes': len(info) + len(audio),
        'frames': len(frames),
        'duration': x.shape[0] / sr,
        'channels': channels,
    }


def mp3_stats(path: str) -> dict:
    with open(path, 'rb') as fh:
        data = fh.read()
    frames = parse_frames(data)
    info = data.find(b'Info', 0, 64) >= 0
    sr = _SR_V1[(data[frames[0][0] + 2] >> 2) & 3] if frames else 0
    audio_frames = len(frames) - (1 if info else 0)
    samples = audio_frames * 1152
    delay = pad = 0
    li = data.find(b'LAME3.100', 0, 400)
    if li >= 0:
        v = (data[li + 21] << 16) | (data[li + 22] << 8) | data[li + 23]
        delay, pad = v >> 12, v & 0xFFF
        samples -= delay + pad
    return {'bytes': len(data), 'frames': len(frames), 'sr': sr,
            'duration': samples / sr if sr else 0.0, 'gapless_tag': li >= 0}
