#!/usr/bin/env python3
"""Generate original short sound effects for Fruit Slice."""
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
rng = np.random.default_rng(0x51CE)


def t_of(n: int) -> np.ndarray:
    return np.arange(n, dtype=np.float64) / SR


def fade_edges(x: np.ndarray, fade: float = 0.004) -> np.ndarray:
    f = max(1, int(fade * SR))
    if len(x) < f * 2:
        return x
    x[:f] *= np.linspace(0, 1, f)
    x[-f:] *= np.linspace(1, 0, f)
    return x


def highpass(noise: np.ndarray, amount: int = 1) -> np.ndarray:
    out = noise.copy()
    for _ in range(amount):
        out = np.diff(out, prepend=0)
    return out


def sweep_sine(f0: float, f1: float, dur: float, decay: float = 3.0,
               gain: float = 0.5) -> np.ndarray:
    n = int(dur * SR)
    t = t_of(n)
    f = f0 + (f1 - f0) * (t / max(dur, 1e-6)) ** 1.4
    phase = math.tau * np.cumsum(f) / SR
    return np.sin(phase) * np.exp(-t * decay) * gain


def make_stereo(mono: np.ndarray, pan: float = 0.0) -> np.ndarray:
    left = math.sqrt(max(0.0, 0.5 * (1 - pan)))
    right = math.sqrt(max(0.0, 0.5 * (1 + pan)))
    return np.stack([mono * left * 1.414, mono * right * 1.414], axis=1)


def to_caf(stereo: np.ndarray, name: str, peak: float = 0.9) -> None:
    m = np.max(np.abs(stereo))
    if m > 0:
        stereo = stereo / m * peak
    pcm = (np.clip(stereo, -1, 1) * 32767).astype(np.int16)
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
        print(f"Generated {out.name}")
    finally:
        path.unlink(missing_ok=True)


def slice_sfx() -> np.ndarray:
    dur = 0.24
    n = int(dur * SR)
    t = t_of(n)
    noise = rng.normal(0, 1, n)
    swoosh = highpass(noise, 1) * np.exp(-t * 18) * 0.55
    tone = sweep_sine(2100, 4200, dur, 11, 0.35)
    air = np.sin(math.tau * 950 * t) * np.exp(-t * 14) * 0.1
    mono = (swoosh + tone + air) * 0.75
    return make_stereo(fade_edges(mono), 0.1)


def bomb_sfx() -> np.ndarray:
    dur = 1.15
    n = int(dur * SR)
    t = t_of(n)
    boom = sweep_sine(120, 32, dur, 2.8, 0.9)
    body = np.sin(math.tau * 48 * t) * np.exp(-t * 3.5) * 0.45
    noise = highpass(rng.normal(0, 1, n), 1) * np.exp(-t * 7) * 0.5
    crack = rng.normal(0, 1, int(0.06 * SR)) * np.exp(-np.linspace(0, 14, int(0.06 * SR))) * 0.35
    mono = boom + body + noise
    mono[:len(crack)] += crack
    return make_stereo(fade_edges(mono), 0.0)


def life_lost_sfx() -> np.ndarray:
    dur = 0.75
    n = int(dur * SR)
    mono = np.zeros(n)
    for i, freq in enumerate([392.0, 329.63, 261.63]):
        start = int(i * 0.14 * SR)
        seg_n = n - start
        tt = t_of(seg_n)
        seg = (np.sin(math.tau * freq * tt) + 0.3 * np.sin(math.tau * freq * 2 * tt))
        seg *= np.exp(-tt * 3.2) * 0.25
        mono[start:] += seg[:seg_n]
    thud = sweep_sine(130, 60, 0.45, 7, 0.3)
    mono[:len(thud)] += thud
    return make_stereo(fade_edges(mono), -0.2)


def life_gain_sfx() -> np.ndarray:
    dur = 1.0
    n = int(dur * SR)
    mono = np.zeros(n)
    notes = [523.25, 659.25, 783.99, 1046.5]
    for i, freq in enumerate(notes):
        start = int(i * 0.1 * SR)
        tt = t_of(n - start)
        seg = (np.sin(math.tau * freq * tt) + 0.4 * np.sin(math.tau * freq * 2.01 * tt)
               + 0.2 * np.sin(math.tau * freq * 3.9 * tt))
        seg *= np.exp(-tt * 3.5) * 0.18
        mono[start:] += seg
    shimmer = highpass(rng.normal(0, 1, n), 1) * np.exp(-t_of(n) * 4) * 0.05
    return make_stereo(fade_edges(mono + shimmer), 0.15)


def combo_sfx() -> np.ndarray:
    dur = 0.45
    n = int(dur * SR)
    mono = np.zeros(n)
    for i, freq in enumerate([880.0, 1174.66, 1567.98]):
        start = int(i * 0.045 * SR)
        tt = t_of(n - start)
        seg = np.sin(math.tau * freq * tt) * np.exp(-tt * 8) * 0.22
        mono[start:] += seg
    return make_stereo(fade_edges(mono), 0.35)


def tick_sfx() -> np.ndarray:
    dur = 0.18
    n = int(dur * SR)
    t = t_of(n)
    mono = (np.sin(math.tau * 880 * t) * 0.25 + np.sin(math.tau * 1760 * t) * 0.08)
    mono *= np.exp(-t * 22)
    return make_stereo(fade_edges(mono), 0.0)


def go_sfx() -> np.ndarray:
    dur = 0.55
    n = int(dur * SR)
    mono = np.zeros(n)
    for freq in [523.25, 659.25, 1046.5]:
        mono += np.sin(math.tau * freq * t_of(n)) * np.exp(-t_of(n) * 4) * 0.16
    return make_stereo(fade_edges(mono), 0.0)


def click_sfx() -> np.ndarray:
    dur = 0.08
    n = int(dur * SR)
    t = t_of(n)
    mono = highpass(rng.normal(0, 1, n), 1) * np.exp(-t * 60) * 0.3
    mono += np.sin(math.tau * 600 * t) * np.exp(-t * 35) * 0.1
    return make_stereo(fade_edges(mono), 0.0)


def game_over_sfx() -> np.ndarray:
    dur = 1.8
    n = int(dur * SR)
    mono = np.zeros(n)
    for i, freq in enumerate([440.0, 349.23, 293.66, 220.0]):
        start = int(i * 0.18 * SR)
        tt = t_of(n - start)
        seg = (np.sin(math.tau * freq * tt) + 0.35 * np.sin(math.tau * freq * 2.01 * tt))
        seg *= np.exp(-tt * 2.2) * 0.16
        mono[start:] += seg
    gong = sweep_sine(90, 45, 1.5, 2.2, 0.25)
    mono[:len(gong)] += gong
    return make_stereo(fade_edges(mono), 0.0)


def countdown_sfx() -> np.ndarray:
    n = int(0.09 * SR)
    t = t_of(n)
    mono = highpass(rng.normal(0, 1, n), 1) * np.exp(-t * 55) * 0.18
    mono += np.sin(math.tau * 1200 * t) * np.exp(-t * 30) * 0.12
    return make_stereo(fade_edges(mono), 0.0)


def main() -> None:
    for fn, name in [
        (slice_sfx, "sfx_slice"),
        (bomb_sfx, "sfx_bomb"),
        (life_lost_sfx, "sfx_life_lost"),
        (life_gain_sfx, "sfx_life_gain"),
        (combo_sfx, "sfx_combo"),
        (tick_sfx, "sfx_tick"),
        (go_sfx, "sfx_go"),
        (click_sfx, "sfx_click"),
        (game_over_sfx, "sfx_game_over"),
        (countdown_sfx, "sfx_countdown"),
    ]:
        to_caf(fn(), name)
    print(f"SFX written to {OUT}")


if __name__ == "__main__":
    main()
