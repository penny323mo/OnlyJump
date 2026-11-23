"""Render the game's original mono landing samples with the Python standard library."""

import math
import random
import struct
import wave
from pathlib import Path


RATE = 22050
AUDIO = Path(__file__).resolve().parents[1] / "audio"


def render(name, duration, modes, rustle, cutoff, decay):
    noise = random.Random(42)
    low = 0.0
    samples = []
    for frame in range(round(RATE * duration)):
        t = frame / RATE
        low += cutoff * (noise.uniform(-1, 1) - low)
        # A brushed sole followed by a short heel thud excites each surface.
        value = rustle * low * math.exp(-t / decay)
        for onset, weight in ((0, 0.65), (0.022, 0.35)):
            age = t - onset
            if age < 0:
                continue
            for hz, amplitude, tail in modes:
                value += weight * amplitude * math.exp(-age / tail) * math.sin(math.tau * hz * age)
        fade = min(1, t / 0.002, (duration - t) / 0.015)
        samples.append(value * fade)
    gain = 0.55 * 32767 / max(map(abs, samples))
    with wave.open(str(AUDIO / f"land-{name}.wav"), "wb") as out:
        out.setparams((1, 2, RATE, 0, "NONE", "not compressed"))
        out.writeframes(struct.pack(f"<{len(samples)}h", *(round(v * gain) for v in samples)))


if __name__ == "__main__":
    render("fabric", 0.19, [(112, 0.45, 0.028)], 1.3, 0.13, 0.045)
    render("wood", 0.22, [(184, 0.65, 0.047), (423, 0.43, 0.030), (918, 0.28, 0.017)], 0.65, 0.55, 0.012)
    render("metal", 0.37, [(156, 0.85, 0.040), (712, 0.34, 0.085), (1195, 0.24, 0.060), (1847, 0.15, 0.052)], 0.5, 0.84, 0.009)
