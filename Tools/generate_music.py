#!/usr/bin/env python3
"""Generate original looping music for Fruit Slice.

Creates menu and gameplay loops as 44.1 kHz stereo CAF files.
All sounds are synthesized from scratch with NumPy.
"""
from __future__ import annotations

import math
import subprocess
import tempfile
import wave
from pathlib import Path

import numpy as np

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "FruitNinja" / "Resources" / "Audio"
OUT.mkdir(parents=True, exist_ok=True)
SR = 44100
rng = np.random.default_rng(0xF1217A)


def seconds(n: int) -> np.ndarray:
    return np.arange(n, dtype=np.float64) / SR


def adsr(n: int, attack: float, decay: float, sustain: float, release: float) -> np.ndarray:
    a = max(1, int(attack * SR))
    d = max(1, int(decay * SR))
    r = max(1, int(release * SR))
    s = max(1, n - a - d - r)
    env = np.concatenate([
        np.linspace(0, 1, a, endpoint=False),
        np.linspace(1, sustain, d, endpoint=False),
        np.full(s, sustain),
        np.linspace(sustain, 0, r),
    ])
    if len(env) < n:
        env = np.pad(env, (0, n - len(env)))
    return env[:n]


def pluck(freq: float, dur: float, gain: float = 0.2, brightness: float = 1.0) -> np.ndarray:
    n = int(dur * SR)
    t = seconds(n)
    out = np.zeros(n)
    for harmonic, decay in [(1, 2.7), (2, 1.8), (3, 1.3), (4, 0.9), (5, 0.55)]:
        a = brightness ** (harmonic - 1) / (harmonic ** 1.1)
        phase = rng.uniform(0, math.tau)
        out += a * np.sin(math.tau * freq * harmonic * t + phase) * np.exp(-t * decay * 3.0)
    env = adsr(n, 0.002, 0.01, 0.72, min(0.2, dur * 0.4))
    out *= env
    # tiny pick transient
    click_n = min(n, int(0.015 * SR))
    out[:click_n] += rng.normal(0, 0.16, click_n) * np.exp(-np.linspace(0, 8, click_n))
    return out * gain


def pad(n: int, freqs: list[float], gain: float = 0.08) -> np.ndarray:
    t = seconds(n)
    out = np.zeros(n)
    for i, f in enumerate(freqs):
        detune = 1 + (i - len(freqs) / 2) * 0.0025
        phase = rng.uniform(0, math.tau)
        out += (np.sin(math.tau * f * detune * t + phase)
                + 0.3 * np.sin(math.tau * f * 2 * t + phase * 0.7)
                + 0.15 * np.sin(math.tau * f * 3 * t + phase * 1.3))
    env = adsr(n, 0.25, 0.4, 0.72, 0.6)
    return out * env * gain / max(1, len(freqs))


def taiko(gain: float = 0.5) -> np.ndarray:
    dur = 0.55
    n = int(dur * SR)
    t = seconds(n)
    f = 155 * np.exp(-t * 14) + 48
    phase = math.tau * np.cumsum(f) / SR
    body = np.sin(phase) * np.exp(-t * 6.5)
    skin = rng.normal(0, 0.3, n) * np.exp(-t * 35)
    return (body * 0.9 + skin * 0.35) * gain


def shaker(gain: float = 0.1, dur: float = 0.09) -> np.ndarray:
    n = int(dur * SR)
    noise = rng.normal(0, 1, n)
    high = np.diff(noise, prepend=0)
    return high * np.exp(-seconds(n) * 55) * gain * 0.55


def bass(freq: float, dur: float, gain: float = 0.2) -> np.ndarray:
    n = int(dur * SR)
    t = seconds(n)
    wave = np.sin(math.tau * freq * t) + 0.22 * np.sin(math.tau * freq * 2 * t)
    return wave * adsr(n, 0.006, 0.08, 0.6, 0.08) * gain


def bell(freq: float, dur: float, gain: float = 0.12) -> np.ndarray:
    n = int(dur * SR)
    t = seconds(n)
    out = np.zeros(n)
    for ratio, amp, decay in [(1, 1.0, 2.2), (2.01, 0.5, 3.0),
                              (3.9, 0.25, 4.5), (5.4, 0.12, 6.0)]:
        out += amp * np.sin(math.tau * freq * ratio * t) * np.exp(-t * decay)
    return out * adsr(n, 0.002, 0.02, 0.9, 0.1) * gain


def crash(gain: float = 0.18) -> np.ndarray:
    dur = 1.8
    n = int(dur * SR)
    t = seconds(n)
    noise = rng.normal(0, 1, n)
    high = noise - np.concatenate(([0], noise[:-1]))
    return high * np.exp(-t * 3.2) * gain * 0.35


def add(buf: np.ndarray, start: float, signal: np.ndarray, pan: float = 0.0,
        wrap: bool = True) -> None:
    n = len(buf)
    start_i = int(start * SR) % n
    idx = (np.arange(len(signal)) + start_i) % n if wrap else np.arange(len(signal)) + start_i
    if wrap:
        valid = np.ones(len(signal), dtype=bool)
    else:
        valid = idx < n
        idx = idx[valid]
    left = (1 - max(0.0, pan)) * 0.5 + 0.5
    right = (1 + min(0.0, pan)) * 0.5 + 0.5
    # equal-power-ish pan while keeping center at 0.5
    lg = math.sqrt(left)
    rg = math.sqrt(right)
    buf[idx, 0] += signal[valid] * lg
    buf[idx, 1] += signal[valid] * rg


def normalize(buf: np.ndarray, peak: float = 0.82) -> np.ndarray:
    m = np.max(np.abs(buf))
    if m > 0:
        buf = buf / m * peak
    # Smooth loop boundary: tiny fade to avoid a click, inaudible on rhythmic tracks.
    fade = int(0.012 * SR)
    buf[:fade] *= np.linspace(0, 1, fade)[:, None]
    buf[-fade:] *= np.linspace(1, 0, fade)[:, None]
    return np.clip(buf, -1, 1)


def to_caf(stereo: np.ndarray, name: str) -> None:
    pcm = (stereo * 32767).astype(np.int16)
    with tempfile.NamedTemporaryFile(suffix=".wav", delete=False) as tmp:
        path = Path(tmp.name)
    try:
        with wave.open(str(path), "wb") as wf:
            wf.setnchannels(2)
            wf.setsampwidth(2)
            wf.setframerate(SR)
            wf.writeframes(pcm.tobytes())
        out = OUT / f"{name}.caf"
        subprocess.run(["afconvert", "-f", "caff", "-d", "LEI16@44100",
                        str(path), str(out)], check=True)
        print(f"Generated {out} ({len(stereo) / SR:.1f}s)")
    finally:
        path.unlink(missing_ok=True)


def menu_music() -> np.ndarray:
    bpm = 76
    beat = 60 / bpm
    bars = 4
    dur = bars * 4 * beat
    n = int(dur * SR)
    buf = np.zeros((n, 2))
    # D minor / pentatonic atmosphere
    chords = [
        [146.83, 174.61, 220.00, 261.63],   # Dm
        [116.54, 146.83, 174.61, 233.08],   # Bb
        [130.81, 174.61, 220.00, 293.66],   # F
        [146.83, 196.00, 220.00, 261.63],   # Dm/A
    ]
    for bar in range(bars):
        add(buf, bar * 4 * beat, pad(int(4 * beat * SR), chords[bar], 0.11))
        add(buf, bar * 4 * beat, bass(chords[bar][0] / 2, 2.0 * beat, 0.15))
        add(buf, bar * 4 * beat + 2 * beat, bass(chords[bar][2] / 2, 1.8 * beat, 0.1))
        melody = [
            chords[bar][2], chords[bar][3], chords[bar][1] * 2,
            chords[bar][2], chords[bar][3],
        ]
        for i, freq in enumerate(melody):
            if i in (2, 3):
                continue
            start = bar * 4 * beat + i * (beat * 0.75) + 0.1
            add(buf, start, pluck(freq, 1.1, 0.16, 0.8), pan=(-0.25 if i % 2 else 0.25))
        # airy bell accents
        add(buf, bar * 4 * beat + 2.5 * beat,
            bell(chords[bar][3] * 2, 1.6, 0.08), pan=0.35)
    # distant shaker bed
    for i in range(int(bars * 8)):
        add(buf, i * beat / 2, shaker(0.035, 0.06), pan=-0.4)
    return normalize(buf, 0.62)


def game_music() -> np.ndarray:
    bpm = 118
    beat = 60 / bpm
    bars = 8
    dur = bars * 4 * beat
    n = int(dur * SR)
    buf = np.zeros((n, 2))
    roots = [110.0, 110.0, 130.81, 130.81, 146.83, 146.83, 98.0, 110.0]
    scale = [220.0, 261.63, 293.66, 329.63, 392.0, 440.0, 523.25]
    for bar in range(bars):
        b0 = bar * 4 * beat
        add(buf, b0, crash(0.14), pan=0.2)
        # taiko groove
        pattern = [0.0, 0.75, 1.5, 2.0, 2.75, 3.25]
        for idx, p in enumerate(pattern):
            add(buf, b0 + p * beat, taiko(0.34 if idx % 2 else 0.5),
                pan=(-0.15 if idx % 2 else 0.15))
        # shakers on eighths
        for eighth in range(8):
            add(buf, b0 + eighth * beat / 2,
                shaker(0.075 if eighth % 2 else 0.045), pan=0.35)
        # bass ostinato
        for p, mult in [(0, 1.0), (1.5, 1.0), (2.0, 1.5), (3.0, 1.0)]:
            add(buf, b0 + p * beat, bass(roots[bar] * mult, beat * 0.7, 0.19))
        # koto-like arpeggio
        arp = [0, 2, 4, 2, 3, 1, 4, 5]
        for eighth in range(8):
            note = scale[(arp[eighth] + bar // 2) % len(scale)]
            add(buf, b0 + eighth * beat / 2,
                pluck(note * (2 if bar >= 4 else 1), 0.55, 0.12),
                pan=(-0.45 if eighth % 2 else 0.45))
        # low pad wash every 2 bars
        if bar % 2 == 0:
            chord = [roots[bar], roots[bar] * 1.5, roots[bar] * 2, roots[bar] * 2.5]
            add(buf, b0, pad(int(8 * beat * SR), chord, 0.06))
        # sparse bells
        if bar % 2 == 1:
            add(buf, b0 + 3.5 * beat, bell(scale[(bar * 2) % len(scale)] * 2, 1.4, 0.07),
                pan=-0.2)
    # final hit and gentle fill
    return normalize(buf, 0.78)


def main() -> None:
    print("Synthesizing menu music...")
    to_caf(menu_music(), "music_menu")
    print("Synthesizing gameplay music...")
    to_caf(game_music(), "music_game")
    print(f"Music written to {OUT}")


if __name__ == "__main__":
    main()
