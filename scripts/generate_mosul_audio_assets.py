#!/usr/bin/env python3
"""Generate small original WAV assets for the MosulGame soundscape."""

from __future__ import annotations

import math
import struct
import wave
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
AUDIO_ROOT = ROOT / "modernerKrieg" / "assets" / "mosul" / "audio"
SAMPLE_RATE = 48_000


def envelope(position: float, attack: float = 0.02, release: float = 0.05) -> float:
    if position < attack:
        return position / attack
    if position > 1.0 - release:
        return max(0.0, (1.0 - position) / release)
    return 1.0


def write_mono_wav(path: Path, duration: float, sample_at: callable[[float, float], float]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    frame_count = int(round(duration * SAMPLE_RATE))
    frames = bytearray()

    for frame in range(frame_count):
        time = frame / SAMPLE_RATE
        position = frame / max(1, frame_count - 1)
        value = max(-1.0, min(1.0, sample_at(time, position)))
        frames.extend(struct.pack("<h", int(value * 32767)))

    with wave.open(str(path), "wb") as wav:
        wav.setnchannels(1)
        wav.setsampwidth(2)
        wav.setframerate(SAMPLE_RATE)
        wav.writeframes(frames)


def tone(frequency: float, time: float, phase: float = 0.0) -> float:
    return math.sin((2.0 * math.pi * frequency * time) + phase)


def cue(path: str, duration: float, frequencies: list[float], gain: float, drop: float = 0.0) -> None:
    def sample(time: float, position: float) -> float:
        body = sum(tone(freq, time, phase=index * 0.7) for index, freq in enumerate(frequencies))
        body /= max(1, len(frequencies))
        shaped = envelope(position) * (1.0 - drop * position)
        return gain * shaped * body

    write_mono_wav(AUDIO_ROOT / path, duration, sample)


def pulse(path: str, duration: float, base: float, gain: float) -> None:
    def sample(time: float, position: float) -> float:
        sweep = base + (base * 0.22 * position)
        click = tone(sweep, time) + 0.35 * tone(sweep * 2.01, time)
        return gain * envelope(position, attack=0.008, release=0.08) * click

    write_mono_wav(AUDIO_ROOT / path, duration, sample)


def loop(path: str, duration: float, layers: list[tuple[float, float, float]]) -> None:
    def sample(time: float, position: float) -> float:
        value = 0.0
        for frequency, gain, phase in layers:
            value += gain * tone(frequency, time, phase)
        return value

    write_mono_wav(AUDIO_ROOT / path, duration, sample)


def main() -> None:
    cue("cues/ui_order_arm.wav", 0.12, [660, 990], 0.18, drop=0.2)
    cue("cues/ui_order_confirm.wav", 0.16, [523.25, 784.0], 0.16, drop=0.1)
    cue("cues/ui_invalid.wav", 0.18, [180, 120], 0.15, drop=0.55)
    pulse("cues/tactical_tick.wav", 0.10, 420, 0.10)
    pulse("cues/tactical_movement.wav", 0.28, 115, 0.13)
    cue("cues/tactical_contact.wav", 0.42, [310, 465, 930], 0.14, drop=0.35)
    cue("cues/tactical_route_blocked.wav", 0.24, [96, 144], 0.18, drop=0.65)
    pulse("cues/tactical_fire.wav", 0.36, 82, 0.22)
    cue("cues/tactical_objective.wav", 0.52, [392, 523.25, 659.25], 0.13, drop=0.05)
    cue("cues/tactical_risk.wav", 0.46, [740, 554, 370], 0.14, drop=0.15)

    loop(
        "loops/ambient_city_low.wav",
        3.0,
        [(55, 0.030, 0.0), (88, 0.020, 0.4), (176, 0.010, 1.1), (233, 0.008, 2.2)],
    )
    loop(
        "loops/ambient_city_high.wav",
        3.0,
        [(110, 0.018, 0.2), (220, 0.014, 0.9), (352, 0.012, 1.7), (704, 0.006, 2.4)],
    )
    loop(
        "loops/ambient_generator.wav",
        3.0,
        [(50, 0.032, 0.0), (100, 0.018, 0.5), (150, 0.012, 1.0), (300, 0.006, 2.0)],
    )
    loop(
        "loops/ambient_engine_distant.wav",
        3.0,
        [(38, 0.032, 0.3), (76, 0.018, 1.1), (114, 0.010, 1.9), (152, 0.007, 2.7)],
    )


if __name__ == "__main__":
    main()
