"""Compose Drowned's original 72 BPM score; requires NumPy, no sample downloads.

Three phase-aligned stereo stems, 16 bars in D minor. Circular rendering keeps
pad/reverb tails continuous at the loop boundary. Run from any directory.
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


def pad(note, duration):
    t = np.arange(round(duration * RATE)) / RATE
    env = np.minimum(t / 1.4, 1) * np.minimum((duration - t) / 1.8, 1)
    f = hz(note)
    return env * (np.sin(2 * np.pi * f * t)
                  + 0.32 * np.sin(2 * np.pi * f * 1.002 * t)
                  + 0.12 * np.sin(4 * np.pi * f * t)) / 1.44


def bell(note, duration=3.2):
    t = np.arange(round(duration * RATE)) / RATE
    return np.minimum(t / 0.035, 1) * np.exp(-t * 1.5) * (
        np.sin(2 * np.pi * hz(note) * t)
        + 0.16 * np.sin(2 * np.pi * hz(note) * 2.01 * t))


def bass(note, duration):
    # Slow sub-bass pulses with audible overtones add tension under the pads.
    t = np.arange(round(duration * RATE)) / RATE
    f = hz(note)
    envelope = np.minimum(t / 0.12, 1) * np.exp(-t * 0.55)
    envelope *= np.minimum((duration - t) / 0.28, 1)
    tone = np.sin(2 * np.pi * f * t) + 0.40 * np.sin(4 * np.pi * f * t)
    tone += 0.16 * np.sin(6 * np.pi * f * t)
    return np.tanh(tone * 1.15) * envelope * (0.88 + 0.12 * np.sin(2 * np.pi * 0.7 * t))


def drum(frequency, duration, noise=0.08):
    t = np.arange(round(duration * RATE)) / RATE
    phase = 2 * np.pi * frequency * (t + 0.025 * (1 - np.exp(-t * 45)))
    return np.minimum(t / 0.003, 1) * np.exp(-t * 9) * (
        np.sin(phase) + noise * RNG.uniform(-1, 1, len(t)))


def guitar(note, duration=1.5):
    # Karplus–Strong plucked string, gently saturated for the boss room.
    size = round(RATE / hz(note) - 0.5)
    excitation = RNG.uniform(-1, 1, size)
    excitation -= excitation.mean()
    sound = np.zeros(round(duration * RATE))
    sound[:size] = excitation
    for i in range(size, len(sound)):
        sound[i] = 0.497 * (sound[i - size] + sound[i - size + 1])
    t = np.arange(len(sound)) / RATE
    return np.tanh(sound * 2.0) * np.minimum(t / 0.004, 1) * np.exp(-t * 0.7)


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    stems = {name: np.zeros((LENGTH, 2)) for name in ["cavern", "waves_drums", "boss_guitar"]}
    chords = [(50, 57, 62, 65), (46, 53, 58, 62), (48, 53, 57, 60), (48, 55, 60, 64)]
    melody = [74, 69, 65, 67, 70, 65, 62, 65, 69, 72, 69, 65, 67, 64, 67, 69]
    for bar in range(16):
        start = bar * 4 * BEAT
        chord = chords[(bar // 2) % 4]
        for voice, note in enumerate(chord):
            add(stems["cavern"], pad(note, 4 * BEAT + 2.2), start - 1.1, 0.105, (voice - 1.5) * 0.32)
        add(stems["cavern"], bell(melody[bar]), start + BEAT, 0.13, (-1 if bar % 2 else 1) * 0.45)
        add(stems["cavern"], bell(melody[bar] - 12), start + 3 * BEAT, 0.07, 0.2)
        for beat in [0, 2]:
            add(stems["cavern"], bass(chord[0] - 24, 2 * BEAT + 0.2), start + beat * BEAT, 0.20)
        for beat in range(4):
            add(stems["waves_drums"], drum(62 if beat % 2 == 0 else 104, 0.55), start + beat * BEAT,
                0.42 if beat == 0 else 0.24, -0.2 if beat % 2 else 0.15)
            if beat in (1, 3):
                add(stems["waves_drums"], drum(148, 0.28, 0.3), start + (beat + 0.5) * BEAT, 0.14, 0.4)
        # Picked arpeggio and a low string establish the guitar without drowning dialogue.
        add(stems["boss_guitar"], guitar(chord[0] - 12, 2.8), start, 0.3, -0.15)
        for pick in range(8):
            note = chord[[1, 2, 3, 2, 1, 3, 2, 1][pick]] + 12
            sound = guitar(note)
            when = start + pick * BEAT / 2
            add(stems["boss_guitar"], sound, when, 0.28, -0.35)
            add(stems["boss_guitar"], sound, when + BEAT * 0.75, 0.08, 0.65)
    # Circular delays for an underwater space, including notes across the seam.
    base = stems["cavern"]
    base += np.roll(base.copy(), round(BEAT * 1.5 * RATE), axis=0) * 0.18
    stats = {}
    for name, stem in stems.items():
        # Remove the last-to-first sample jump with a short, smooth correction.
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
