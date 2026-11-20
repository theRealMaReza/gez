#!/usr/bin/env python3
"""
Generates strictly non-musical sound effects and city ambience for Gez (Phase 16)
using pure filtered noise and percussive envelopes (zero musical tones or pads).
Outputs WAVs temporarily and encodes to Ogg Vorbis (.ogg) via `oggenc`.
"""

import math
import os
import random
import shutil
import struct
import subprocess
import tempfile
import wave

SAMPLE_RATE = 44100


def _biquad_coeffs_bp(freq: float, q: float, sr: int = SAMPLE_RATE):
    w0 = 2.0 * math.pi * freq / sr
    alpha = math.sin(w0) / (2.0 * q)
    cos_w0 = math.cos(w0)
    b0 = alpha
    b1 = 0.0
    b2 = -alpha
    a0 = 1.0 + alpha
    a1 = -2.0 * cos_w0
    a2 = 1.0 - alpha
    return (b0 / a0, b1 / a0, b2 / a0, a1 / a0, a2 / a0)


def _biquad_coeffs_lp(freq: float, q: float, sr: int = SAMPLE_RATE):
    w0 = 2.0 * math.pi * freq / sr
    alpha = math.sin(w0) / (2.0 * q)
    cos_w0 = math.cos(w0)
    b0 = (1.0 - cos_w0) * 0.5
    b1 = 1.0 - cos_w0
    b2 = (1.0 - cos_w0) * 0.5
    a0 = 1.0 + alpha
    a1 = -2.0 * cos_w0
    a2 = 1.0 - alpha
    return (b0 / a0, b1 / a0, b2 / a0, a1 / a0, a2 / a0)


def apply_biquad(samples: list[float], coeffs) -> list[float]:
    b0, b1, b2, a1, a2 = coeffs
    x1 = x2 = y1 = y2 = 0.0
    out = [0.0] * len(samples)
    for i, x0 in enumerate(samples):
        y0 = b0 * x0 + b1 * x1 + b2 * x2 - a1 * y1 - a2 * y2
        x2, x1 = x1, x0
        y2, y1 = y1, y0
        out[i] = y0
    return out


def pink_noise(length: int, rng: random.Random) -> list[float]:
    # Voss-McCartney / Paul Kellet 7-pole pink noise approximation
    b0 = b1 = b2 = b3 = b4 = b5 = b6 = 0.0
    out = [0.0] * length
    for i in range(length):
        w = rng.uniform(-1.0, 1.0)
        b0 = 0.99886 * b0 + w * 0.0555179
        b1 = 0.99332 * b1 + w * 0.0750759
        b2 = 0.96900 * b2 + w * 0.1538520
        b3 = 0.86650 * b3 + w * 0.3104856
        b4 = 0.55000 * b4 + w * 0.5329522
        b5 = -0.7616 * b5 - w * 0.0168980
        pink = b0 + b1 + b2 + b3 + b4 + b5 + b6 + w * 0.5362
        b6 = w * 0.115926
        out[i] = pink * 0.18
    return out


def normalize(samples: list[float], peak: float = 0.88) -> list[float]:
    mx = max((abs(s) for s in samples), default=0.0)
    if mx <= 1e-9:
        return samples
    scale = peak / mx
    return [s * scale for s in samples]


def make_hoofbeats(seed: int, cadence_times: list[float], duration: float = 1.35) -> list[float]:
    rng = random.Random(seed)
    n = int(duration * SAMPLE_RATE)
    buf = [0.0] * n
    bp_wood = _biquad_coeffs_bp(540.0, 2.2)
    lp_thud = _biquad_coeffs_lp(240.0, 0.9)

    for idx, t0 in enumerate(cadence_times):
        start = int(t0 * SAMPLE_RATE)
        clop_len = int(0.09 * SAMPLE_RATE)
        raw = [rng.uniform(-1.0, 1.0) for _ in range(clop_len)]
        # Shape crisp earthen impact
        shaped_hi = apply_biquad(raw, bp_wood)
        shaped_lo = apply_biquad(raw, lp_thud)
        amp = 0.82 if idx % 2 == 0 else 0.98
        for j in range(clop_len):
            pos = start + j
            if pos >= n:
                break
            t = j / SAMPLE_RATE
            env_hi = math.exp(-t / 0.014)
            env_lo = math.exp(-t / 0.024)
            buf[pos] += amp * (shaped_hi[j] * env_hi * 1.4 + shaped_lo[j] * env_lo * 1.1)

    return normalize(buf, 0.85)


def make_musket_shot(seed: int, duration: float = 0.85) -> list[float]:
    rng = random.Random(seed)
    n = int(duration * SAMPLE_RATE)
    white = [rng.uniform(-1.0, 1.0) for _ in range(n)]
    pink = pink_noise(n, rng)

    crack_bp = apply_biquad(white, _biquad_coeffs_bp(1650.0, 0.7))
    punch_lp = apply_biquad(pink, _biquad_coeffs_lp(290.0, 0.8))
    tail_lp = apply_biquad(pink, _biquad_coeffs_lp(720.0, 0.65))

    buf = [0.0] * n
    for i in range(n):
        t = i / SAMPLE_RATE
        attack = min(1.0, t / 0.0018)
        env_crack = attack * math.exp(-t / 0.022)
        env_punch = attack * math.exp(-t / 0.065)
        env_tail = attack * math.exp(-t / 0.19) * 0.32
        buf[i] = crack_bp[i] * env_crack * 1.8 + punch_lp[i] * env_punch * 1.6 + tail_lp[i] * env_tail
    return normalize(buf, 0.90)


def make_siege_thud(seed: int, duration: float = 1.65) -> list[float]:
    rng = random.Random(seed)
    n = int(duration * SAMPLE_RATE)
    pink = pink_noise(n, rng)
    white = [rng.uniform(-1.0, 1.0) for _ in range(n)]

    boom = apply_biquad(pink, _biquad_coeffs_lp(135.0, 0.85))
    rubble = apply_biquad(white, _biquad_coeffs_bp(480.0, 0.9))

    buf = [0.0] * n
    for i in range(n):
        t = i / SAMPLE_RATE
        attack = min(1.0, t / 0.008)
        env_boom = attack * math.exp(-t / 0.34)
        # Delayed masonry impact rattle at ~0.12s
        t_rub = max(0.0, t - 0.11)
        env_rub = (1.0 if t >= 0.11 else 0.0) * min(1.0, t_rub / 0.02) * math.exp(-t_rub / 0.28)
        buf[i] = boom[i] * env_boom * 2.2 + rubble[i] * env_rub * 0.45
    return normalize(buf, 0.88)


def make_city_ambience(seed: int, duration: float = 10.0) -> list[float]:
    """
    Seamless 10s loop of distant medieval market & street murmur:
    low-passed pink noise bed with slow organic crowd-density fluctuations
    and faint distant cart/wood clicks (zero tonal pitch or music).
    """
    rng = random.Random(seed)
    overlap = int(1.5 * SAMPLE_RATE)
    n = int(duration * SAMPLE_RATE)
    total = n + overlap

    pink = pink_noise(total, rng)
    bed_lo = apply_biquad(pink, _biquad_coeffs_lp(460.0, 0.6))
    murmur_bp = apply_biquad(pink, _biquad_coeffs_bp(920.0, 0.9))

    # Generate gentle organic swell envelope from random low-frequency noise (no periodic pitch)
    raw_mod = [rng.uniform(0.45, 1.0) for _ in range(total)]
    mod = apply_biquad(raw_mod, _biquad_coeffs_lp(1.8, 0.7))

    raw = [0.0] * total
    for i in range(total):
        m = max(0.3, min(1.3, 0.75 + mod[i] * 0.45))
        raw[i] = bed_lo[i] * 0.58 + murmur_bp[i] * 0.24 * m

    # Add occasional soft distant wooden cart / crate clacks
    clack_bp = _biquad_coeffs_bp(680.0, 1.8)
    for _ in range(28):
        pos = rng.randint(overlap, total - int(0.1 * SAMPLE_RATE))
        clen = int(0.045 * SAMPLE_RATE)
        burst = apply_biquad([rng.uniform(-1.0, 1.0) for _ in range(clen)], clack_bp)
        amp = rng.uniform(0.06, 0.14)
        for j in range(clen):
            raw[pos + j] += burst[j] * amp * math.exp(-(j / SAMPLE_RATE) / 0.011)

    # Crossfade head and tail for a seamless loop of exact length `n`
    looped = [0.0] * n
    for i in range(n):
        if i < overlap:
            alpha = i / overlap
            looped[i] = raw[i] * alpha + raw[n + i] * (1.0 - alpha)
        else:
            looped[i] = raw[i]

    return normalize(looped, 0.42)


def write_ogg(samples: list[float], out_path: str, oggenc_bin: str, quality: str = "4") -> None:
    os.makedirs(os.path.dirname(out_path), exist_ok=True)
    with tempfile.NamedTemporaryFile(suffix=".wav", delete=False) as tf:
        wav_path = tf.name
    try:
        with wave.open(wav_path, "w") as wf:
            wf.setnchannels(1)
            wf.setsampwidth(2)
            wf.setframerate(SAMPLE_RATE)
            pcm = struct.pack(
                "<" + "h" * len(samples),
                *[int(max(-32767, min(32767, s * 32767.0))) for s in samples],
            )
            wf.writeframes(pcm)
        subprocess.run(
            [oggenc_bin, "-Q", "-q", quality, wav_path, "-o", out_path],
            check=True,
        )
    finally:
        if os.path.exists(wav_path):
            os.remove(wav_path)


def main() -> None:
    oggenc_bin = shutil.which("oggenc")
    if not oggenc_bin:
        raise SystemExit("oggenc not found (install vorbis-tools)")

    repo_root = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
    out_dir = os.path.join(repo_root, "godot", "assets", "audio")
    os.makedirs(out_dir, exist_ok=True)

    outputs = {
        "hoofbeats_01.ogg": make_hoofbeats(145301, [0.04, 0.19, 0.31, 0.56, 0.71, 0.83, 1.08], 1.30),
        "hoofbeats_02.ogg": make_hoofbeats(145302, [0.04, 0.21, 0.34, 0.60, 0.77, 0.90], 1.15),
        "musket_shot_01.ogg": make_musket_shot(145303, 0.80),
        "musket_shot_02.ogg": make_musket_shot(145304, 0.85),
        "siege_thud_01.ogg": make_siege_thud(145305, 1.60),
        "ambience_city.ogg": make_city_ambience(145306, 10.0),
    }

    for fname, samples in outputs.items():
        path = os.path.join(out_dir, fname)
        write_ogg(samples, path, oggenc_bin, quality="4")
        print(f"Generated {fname} ({os.path.getsize(path)} bytes)")


if __name__ == "__main__":
    main()
