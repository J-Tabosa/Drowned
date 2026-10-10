"""Original dark 72 BPM score: sub-bass cave, heavy drums, distorted boss guitar.

No downloaded samples. Three aligned 16-bar PCM loops; requires NumPy.
"""
from pathlib import Path
import json
import wave
import numpy as np

RATE = 22050
BPM = 72
BEAT = 60 / BPM
LENGTH = round(64 * BEAT * RATE)
OUT = Path(__file__).resolve().parents[1] / "assets" / "audio" / "music"
RNG = np.random.default_rng(271828)


def hz(note):
    return 440 * 2 ** ((note - 69) / 12)


def add(stem, sound, start, gain, pan=0.0):
    indices = (round(start * RATE) + np.arange(len(sound))) % LENGTH
    stem[indices, 0] += sound * gain * np.sqrt((1 - pan) / 2)
    stem[indices, 1] += sound * gain * np.sqrt((1 + pan) / 2)


def bass(note, duration):
    t = np.arange(round(duration * RATE)) / RATE
    phase = 2 * np.pi * hz(note) * t
    tone = np.sin(phase) + 0.45 * np.sin(phase * 2) + 0.20 * np.sin(phase * 3)
    envelope = np.minimum(t / 0.07, 1) * np.minimum((duration - t) / 0.25, 1)
    return np.tanh(tone * 1.3) * envelope * np.exp(-t * 0.45)


def drone(note, duration):
    t = np.arange(round(duration * RATE)) / RATE
    envelope = np.minimum(t / 1.7, 1) * np.minimum((duration - t) / 2, 1)
    phase = 2 * np.pi * hz(note) * t
    return envelope * (np.sin(phase) + 0.3 * np.sin(phase * 1.003)) / 1.3


def kick(duration=0.65):
    t = np.arange(round(duration * RATE)) / RATE
    phase = 2 * np.pi * (48 * t + 1.8 * (1 - np.exp(-t * 35)))
    return np.minimum(t / 0.003, 1) * np.exp(-t * 8) * np.sin(phase)


def snare(duration=0.28):
    t = np.arange(round(duration * RATE)) / RATE
    noise = RNG.uniform(-1, 1, len(t))
    return np.minimum(t / 0.002, 1) * np.exp(-t * 18) * (
        noise * 0.65 + np.sin(2 * np.pi * 155 * t) * 0.30)


def rock_string(note, duration, muted=True):
    t = np.arange(round(duration * RATE)) / RATE
    phase = 2 * np.pi * hz(note) * t
    # Picked harmonics into distortion: low electric string rather than a bell.
    clean = sum(np.sin(phase * harmonic) / harmonic ** 1.15 for harmonic in range(1, 13))
    clean += 0.12 * RNG.uniform(-1, 1, len(t)) * np.exp(-t * 65)
    distorted = np.tanh(clean * 3.8)
    # Cabinet tone rolls off fizz while retaining the power-chord harmonics.
    cabinet = np.zeros_like(distorted)
    for i in range(1, len(cabinet)):
        cabinet[i] = cabinet[i - 1] + 0.32 * (distorted[i] - cabinet[i - 1])
    envelope = np.minimum(t / 0.006, 1) * np.minimum((duration - t) / 0.055, 1)
    envelope *= np.exp(-t * (7.0 if muted else 1.8))
    return cabinet * envelope


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    stems = {name: np.zeros((LENGTH, 2)) for name in ["cavern", "waves_drums", "boss_guitar"]}
    # Pedal in D with sparse minor/tritone tension; no bright melodic arpeggio.
    riff = [38, 38, None, 38, 41, 38, 36, 37]
    for bar in range(16):
        start = bar * 4 * BEAT
        root = 26 if bar % 8 < 6 else 25
        for beat in [0, 2]:
            add(stems["cavern"], bass(root, 2.2 * BEAT), start + beat * BEAT, 0.35)
        add(stems["cavern"], drone(38, 6 * BEAT), start - BEAT, 0.10, -0.25)
        add(stems["cavern"], drone(45 if bar % 4 < 3 else 44, 6 * BEAT), start - BEAT, 0.045, 0.3)
        if bar % 4 == 3:
            add(stems["cavern"], drone(51, 4 * BEAT), start, 0.025, 0.5)
        for beat in [0, 2, 2.75]:
            add(stems["waves_drums"], kick(), start + beat * BEAT, 0.48 if beat != 2.75 else 0.22)
        for beat in [1, 3]:
            add(stems["waves_drums"], snare(), start + beat * BEAT, 0.30, 0.12)
        for pick, note in enumerate(riff):
            if note is None:
                continue
            when = start + pick * BEAT / 2
            muted = pick != 4
            duration = BEAT * (0.46 if muted else 0.9)
            for string, pitch in enumerate([note, note + 7, note + 12]):
                gain = [0.19, 0.12, 0.07][string]
                add(stems["boss_guitar"], rock_string(pitch, duration, muted), when, gain, -0.4)
                add(stems["boss_guitar"], rock_string(pitch, duration, muted),
                    when + 0.012, gain * 0.8, 0.4)
    base = stems["cavern"]
    base += np.roll(base.copy(), round(BEAT * 1.5 * RATE), axis=0) * 0.12
    stats = {}
    for name, stem in stems.items():
        taper = (0.5 + 0.5 * np.cos(np.linspace(0, np.pi, 256)))[:, None]
        stem[:256] -= taper * (stem[0] - stem[-1])
        peak = float(np.abs(stem).max())
        assert peak < 0.95, (name, peak)
        pcm = np.round(stem * 32767).astype("<i2")
        with wave.open(str(OUT / f"{name}.wav"), "wb") as target:
            target.setnchannels(2)
            target.setsampwidth(2)
            target.setframerate(RATE)
            target.writeframes(pcm.tobytes())
        stats[name] = {"seconds": LENGTH / RATE, "peak": round(peak, 4),
                       "rms": round(float(np.sqrt(np.mean(stem ** 2))), 4),
                       "seam_step": round(float(np.abs(stem[0] - stem[-1]).max()), 4)}
    print(json.dumps(stats, indent=2))


if __name__ == "__main__":
    main()
