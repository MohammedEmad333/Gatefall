#!/usr/bin/env python3
"""Generates every sound in Gatefall, from nothing but arithmetic.

Version 3 needed a soundtrack and there was no sample library to reach for,
so the sounds are *synthesised* here and the resulting WAVs are committed as
assets. That keeps the game's audio the same kind of thing as its art —
generated from a rule you can read, tune and re-run — and it keeps the whole
set under a megabyte.

    python3 tool/make_sounds.py            # rewrites assets/audio/*.wav

Pure standard library on purpose: this has to run in CI, in a container, or
on a laptop with no numpy, or it isn't reproducible.

Design rules, so re-tuning stays coherent:
  * Everything is soft-attacked. Nothing in this game clicks or barks.
  * SFX are 22050 Hz mono; the two ambient loops are 16000 Hz mono, which is
    plenty for drones and keeps them small.
  * The palette is the palette of the game: low sine drones for the house,
    detuned fifths for the gates, bell partials for anything a companion did.
  * Loops are built so the last sample meets the first: whole numbers of
    cycles, plus an equal-power crossfade of the tail over the head.
"""

import math
import os
import random
import struct
import wave

SFX_RATE = 22050
MUSIC_RATE = 16000
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "assets", "audio")

TWO_PI = 2 * math.pi


# ---------------------------------------------------------------- primitives

def buf(seconds, rate):
    return [0.0] * int(seconds * rate)


def sine(out, freq, rate, amp=1.0, phase=0.0, start=0.0, env=None, detune=0.0):
    """Adds a sine (optionally detuned into a slow beat) into `out`."""
    i0 = int(start * rate)
    for i in range(i0, len(out)):
        t = (i - i0) / rate
        e = env(t) if env else 1.0
        if e <= 0.0:
            continue
        v = math.sin(TWO_PI * freq * t + phase)
        if detune:
            v = 0.5 * v + 0.5 * math.sin(TWO_PI * (freq + detune) * t + phase)
        out[i] += amp * e * v


def sweep(out, f0, f1, rate, amp=1.0, start=0.0, dur=None, env=None, curve=1.0):
    """Adds a frequency sweep from f0 to f1 over `dur` seconds."""
    i0 = int(start * rate)
    n = len(out) - i0 if dur is None else int(dur * rate)
    phase = 0.0
    for k in range(n):
        i = i0 + k
        if i >= len(out):
            break
        t = k / rate
        x = (k / max(1, n - 1)) ** curve
        f = f0 + (f1 - f0) * x
        phase += TWO_PI * f / rate
        e = env(t) if env else 1.0
        out[i] += amp * e * math.sin(phase)


def noise(out, rate, amp=1.0, start=0.0, dur=None, env=None, rng=None):
    rng = rng or random
    i0 = int(start * rate)
    n = len(out) - i0 if dur is None else int(dur * rate)
    for k in range(n):
        i = i0 + k
        if i >= len(out):
            break
        e = env(k / rate) if env else 1.0
        out[i] += amp * e * (rng.random() * 2.0 - 1.0)


def bell(out, freq, rate, amp=1.0, start=0.0, decay=0.6, partials=(1.0, 2.41, 4.07)):
    """A struck-metal tone: inharmonic partials, each dying faster than the last."""
    for k, p in enumerate(partials):
        a = amp / (k + 1.6)
        d = decay / (1.0 + 0.55 * k)
        sine(out, freq * p, rate, amp=a, start=start,
             env=lambda t, d=d: math.exp(-t / d) if t >= 0 else 0.0)


def chord(out, freqs, rate, amp=1.0, start=0.0, decay=0.9, spread=0.0, detune=0.6):
    for k, f in enumerate(freqs):
        s = start + spread * k
        sine(out, f, rate, amp=amp, start=s, detune=detune,
             env=lambda t, d=decay: math.exp(-t / d) * (1.0 - math.exp(-t / 0.02)))


# ------------------------------------------------------------------ envelopes

def ad(attack, decay, power=1.0):
    """Attack then exponential decay — the shape almost everything here uses."""
    def f(t):
        if t < 0:
            return 0.0
        a = 1.0 if attack <= 0 else min(1.0, t / attack)
        return (a ** power) * math.exp(-max(0.0, t - attack) / decay)
    return f


def swell(attack, hold, release):
    def f(t):
        if t < 0:
            return 0.0
        if t < attack:
            return t / attack
        if t < attack + hold:
            return 1.0
        x = (t - attack - hold) / release
        return max(0.0, 1.0 - x) ** 1.5
    return f


# --------------------------------------------------------------------- shaping

def lowpass(sig, rate, cutoff):
    """One-pole. Takes the fizz off noise so it reads as air, not static."""
    a = math.exp(-TWO_PI * cutoff / rate)
    y = 0.0
    for i, x in enumerate(sig):
        y = (1 - a) * x + a * y
        sig[i] = y
    return sig


def highpass(sig, rate, cutoff):
    a = math.exp(-TWO_PI * cutoff / rate)
    y = 0.0
    prev = 0.0
    for i, x in enumerate(sig):
        y = a * (y + x - prev)
        prev = x
        sig[i] = y
    return sig


def shimmer(sig, rate, delay=0.052, feedback=0.36, mix=0.34, taps=3):
    """A cheap stand-in for a hall: a few decaying, slightly spread echoes."""
    out = list(sig)
    for tap in range(1, taps + 1):
        d = int(delay * rate * tap * (1.0 + 0.13 * tap))
        g = mix * (feedback ** (tap - 1))
        for i in range(d, len(out)):
            out[i] += g * sig[i - d]
    return out


def fade_edges(sig, rate, fade_in=0.004, fade_out=0.03):
    n_in = max(1, int(fade_in * rate))
    n_out = max(1, int(fade_out * rate))
    for i in range(min(n_in, len(sig))):
        sig[i] *= i / n_in
    for i in range(min(n_out, len(sig))):
        sig[len(sig) - 1 - i] *= i / n_out
    return sig


def normalize(sig, peak=0.82):
    m = max((abs(x) for x in sig), default=0.0)
    if m <= 1e-9:
        return sig
    g = peak / m
    return [x * g for x in sig]


def soft_clip(sig):
    return [math.tanh(x) for x in sig]


def seam(sig, rate, cross=0.35):
    """Makes a loop join itself: crossfade the tail over an equal head."""
    n = int(cross * rate)
    n = min(n, len(sig) // 3)
    head = sig[:n]
    tail = sig[-n:]
    body = sig[:-n]
    for i in range(n):
        x = i / n
        # Equal power, so the drone doesn't dip in the middle of the join.
        a = math.cos(x * math.pi / 2)
        b = math.sin(x * math.pi / 2)
        body[i] = tail[i] * a + head[i] * b
    return body


def write(name, sig, rate):
    os.makedirs(OUT, exist_ok=True)
    path = os.path.join(OUT, name + ".wav")
    frames = bytearray()
    for x in sig:
        v = int(max(-1.0, min(1.0, x)) * 32767)
        frames += struct.pack("<h", v)
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(rate)
        w.writeframes(bytes(frames))
    print("%-16s %5.2fs  %6.1f KB" % (name, len(sig) / rate, len(frames) / 1024))


# ----------------------------------------------------------------- the sounds

R = SFX_RATE


def ui_tap():
    s = buf(0.10, R)
    sine(s, 720, R, amp=0.5, env=ad(0.004, 0.030))
    sine(s, 1440, R, amp=0.16, env=ad(0.002, 0.018))
    return normalize(fade_edges(s, R), 0.36)


def ui_select():
    s = buf(0.26, R)
    bell(s, 587.33, R, amp=0.5, decay=0.13)          # D5
    bell(s, 880.0, R, amp=0.45, start=0.055, decay=0.18)  # A5
    return normalize(fade_edges(shimmer(s, R, mix=0.2), R), 0.5)


def ui_back():
    s = buf(0.24, R)
    bell(s, 587.33, R, amp=0.45, decay=0.12)
    bell(s, 392.0, R, amp=0.4, start=0.05, decay=0.17)
    return normalize(fade_edges(shimmer(s, R, mix=0.18), R), 0.45)


def page():
    s = buf(0.34, R)
    n = buf(0.34, R)
    noise(n, R, amp=0.9, env=swell(0.06, 0.02, 0.22), rng=random.Random(4))
    n = lowpass(n, R, 1500)
    n = highpass(n, R, 260)
    for i, v in enumerate(n):
        s[i] += v * 1.5
    sweep(s, 300, 520, R, amp=0.12, dur=0.3, env=ad(0.05, 0.14))
    return normalize(fade_edges(s, R), 0.32)


def gate_open():
    """Entering a gate: air pulled in, then the tear itself opening low."""
    s = buf(1.9, R)
    n = buf(1.9, R)
    noise(n, R, amp=1.0, env=swell(0.75, 0.05, 0.9), rng=random.Random(11))
    n = lowpass(n, R, 900)
    n = highpass(n, R, 120)
    for i, v in enumerate(n):
        s[i] += 0.85 * v
    sweep(s, 48, 172, R, amp=0.55, dur=1.1, env=swell(0.5, 0.15, 0.5), curve=1.7)
    sine(s, 146.83, R, amp=0.22, start=0.7, detune=0.7,
         env=lambda t: (1 - math.exp(-t / 0.18)) * math.exp(-t / 0.75))
    bell(s, 1174.66, R, amp=0.22, start=0.82, decay=0.7)
    return normalize(soft_clip(fade_edges(shimmer(s, R, mix=0.4), R, 0.01, 0.14)), 0.78)


def hit():
    s = buf(0.16, R)
    n = buf(0.16, R)
    noise(n, R, amp=1.0, env=ad(0.001, 0.035), rng=random.Random(21))
    n = lowpass(n, R, 2600)
    for i, v in enumerate(n):
        s[i] += 0.6 * v
    sweep(s, 220, 90, R, amp=0.5, dur=0.1, env=ad(0.002, 0.05))
    return normalize(fade_edges(s, R, 0.002, 0.02), 0.5)


def crit():
    s = buf(0.34, R)
    n = buf(0.34, R)
    noise(n, R, amp=1.0, env=ad(0.001, 0.05), rng=random.Random(22))
    n = lowpass(n, R, 5200)
    n = highpass(n, R, 700)
    for i, v in enumerate(n):
        s[i] += 0.45 * v
    sweep(s, 340, 120, R, amp=0.45, dur=0.14, env=ad(0.002, 0.06))
    bell(s, 1318.51, R, amp=0.35, decay=0.2)
    return normalize(fade_edges(shimmer(s, R, mix=0.22), R, 0.002, 0.03), 0.68)


def ability():
    s = buf(0.55, R)
    bell(s, 523.25, R, amp=0.6, decay=0.3)
    sine(s, 261.63, R, amp=0.18, env=ad(0.012, 0.22))
    return normalize(fade_edges(shimmer(s, R, mix=0.3), R, 0.004, 0.05), 0.6)


def ultimate():
    """A cast that mattered: a fifth opening upward under a bright partial."""
    s = buf(1.5, R)
    chord(s, [110.0, 164.81, 220.0, 329.63], R, amp=0.34, decay=0.85, spread=0.035)
    sweep(s, 220, 880, R, amp=0.2, dur=0.5, env=swell(0.08, 0.08, 0.32), curve=1.6)
    bell(s, 880.0, R, amp=0.3, start=0.1, decay=0.75)
    n = buf(1.5, R)
    noise(n, R, amp=0.5, env=swell(0.12, 0.05, 0.7), rng=random.Random(31))
    n = lowpass(n, R, 3000)
    n = highpass(n, R, 500)
    for i, v in enumerate(n):
        s[i] += 0.3 * v
    return normalize(soft_clip(fade_edges(shimmer(s, R, mix=0.42), R, 0.006, 0.1)), 0.8)


def heal():
    s = buf(0.9, R)
    for k, f in enumerate([392.0, 523.25, 659.25]):
        sine(s, f, R, amp=0.3, start=0.06 * k, detune=0.5,
             env=lambda t: (1 - math.exp(-t / 0.09)) * math.exp(-t / 0.5))
    bell(s, 1046.5, R, amp=0.16, start=0.16, decay=0.45)
    return normalize(fade_edges(shimmer(s, R, mix=0.34), R, 0.01, 0.08), 0.55)


def enemy_down():
    s = buf(0.6, R)
    n = buf(0.6, R)
    noise(n, R, amp=1.0, env=ad(0.004, 0.11), rng=random.Random(41))
    n = lowpass(n, R, 1100)
    for i, v in enumerate(n):
        s[i] += 0.7 * v
    sweep(s, 180, 55, R, amp=0.55, dur=0.32, env=ad(0.005, 0.16), curve=0.7)
    return normalize(fade_edges(shimmer(s, R, mix=0.2), R, 0.003, 0.06), 0.62)


def boss_stir():
    s = buf(1.9, R)
    sine(s, 44.0, R, amp=0.6, detune=0.35, env=swell(0.35, 0.5, 0.9))
    sine(s, 66.0, R, amp=0.3, detune=0.5, env=swell(0.45, 0.4, 0.9))
    n = buf(1.9, R)
    noise(n, R, amp=1.0, env=swell(0.4, 0.4, 1.0), rng=random.Random(51))
    n = lowpass(n, R, 320)
    for i, v in enumerate(n):
        # A slow tremolo, so it breathes rather than hums.
        s[i] += 0.9 * v * (0.7 + 0.3 * math.sin(TWO_PI * 3.1 * i / R))
    return normalize(soft_clip(fade_edges(s, R, 0.02, 0.16)), 0.72)


def party_down():
    s = buf(0.75, R)
    sweep(s, 240, 70, R, amp=0.5, dur=0.4, env=ad(0.006, 0.2), curve=0.8)
    n = buf(0.75, R)
    noise(n, R, amp=1.0, env=ad(0.004, 0.09), rng=random.Random(61))
    n = lowpass(n, R, 700)
    for i, v in enumerate(n):
        s[i] += 0.5 * v
    bell(s, 196.0, R, amp=0.2, start=0.06, decay=0.4)
    return normalize(fade_edges(shimmer(s, R, mix=0.24), R, 0.004, 0.08), 0.6)


def victory():
    s = buf(2.1, R)
    # A major triad walking up into its octave — the only unambiguously
    # happy sound in the game.
    for k, f in enumerate([261.63, 329.63, 392.0, 523.25]):
        bell(s, f, R, amp=0.5, start=0.11 * k, decay=0.85)
    sine(s, 130.81, R, amp=0.2, start=0.1, detune=0.4, env=swell(0.1, 0.5, 0.9))
    return normalize(fade_edges(shimmer(s, R, mix=0.4), R, 0.006, 0.14), 0.72)


def defeat():
    s = buf(1.9, R)
    for k, f in enumerate([329.63, 261.63, 207.65]):
        bell(s, f, R, amp=0.45, start=0.16 * k, decay=0.75)
    sine(s, 103.83, R, amp=0.22, start=0.2, detune=0.6, env=swell(0.15, 0.4, 0.9))
    return normalize(fade_edges(shimmer(s, R, mix=0.34), R, 0.008, 0.16), 0.6)


def reward():
    s = buf(0.5, R)
    bell(s, 1046.5, R, amp=0.4, decay=0.16, partials=(1.0, 2.0, 3.01))
    bell(s, 1567.98, R, amp=0.34, start=0.06, decay=0.22, partials=(1.0, 2.0, 3.01))
    return normalize(fade_edges(shimmer(s, R, mix=0.24), R, 0.003, 0.05), 0.5)


def bond():
    s = buf(1.2, R)
    for k, f in enumerate([440.0, 659.25]):
        sine(s, f, R, amp=0.34, start=0.1 * k, detune=0.4,
             env=lambda t: (1 - math.exp(-t / 0.14)) * math.exp(-t / 0.6))
    bell(s, 1318.51, R, amp=0.14, start=0.24, decay=0.5)
    return normalize(fade_edges(shimmer(s, R, mix=0.38), R, 0.012, 0.1), 0.52)


def ascend():
    """A route finishing. The biggest sound in the game, and the only one
    that is allowed to take two seconds about it."""
    s = buf(2.6, R)
    chord(s, [146.83, 220.0, 293.66, 440.0, 587.33], R,
          amp=0.3, decay=1.3, spread=0.09)
    sweep(s, 293.66, 1174.66, R, amp=0.18, dur=1.1, env=swell(0.25, 0.2, 0.6), curve=1.5)
    bell(s, 1760.0, R, amp=0.2, start=0.55, decay=1.1)
    n = buf(2.6, R)
    noise(n, R, amp=0.5, env=swell(0.4, 0.3, 1.4), rng=random.Random(71))
    n = lowpass(n, R, 4000)
    n = highpass(n, R, 800)
    for i, v in enumerate(n):
        s[i] += 0.26 * v
    return normalize(soft_clip(fade_edges(shimmer(s, R, mix=0.5), R, 0.01, 0.2)), 0.8)


def gift():
    s = buf(0.8, R)
    for k, f in enumerate([523.25, 659.25, 783.99]):
        bell(s, f, R, amp=0.36, start=0.055 * k, decay=0.32)
    return normalize(fade_edges(shimmer(s, R, mix=0.3), R, 0.004, 0.07), 0.52)


def blip():
    """One character of dialogue. Has to survive being played 400 times."""
    s = buf(0.05, R)
    sine(s, 480, R, amp=0.4, env=ad(0.003, 0.012))
    return normalize(fade_edges(s, R, 0.002, 0.01), 0.16)


# ------------------------------------------------------------------ ambience

M = MUSIC_RATE


def amb_house():
    """The house at night: a warm low fifth, air, and a bell that turns up
    about as often as somebody moves upstairs."""
    seconds = 14.0
    s = buf(seconds, M)
    n = len(s)
    # Whole cycles across the loop, so the drone meets itself at the seam.
    def lock(f):
        return round(f * seconds) / seconds

    for f, a in [(65.41, 0.5), (98.0, 0.3), (196.0, 0.12), (261.63, 0.07)]:
        fl = lock(f)
        for i in range(n):
            t = i / M
            # Two slow tremolos at different rates, both loop-locked.
            lfo = 1.0 + 0.16 * math.sin(TWO_PI * lock(0.143) * t) \
                      + 0.09 * math.sin(TWO_PI * lock(0.077) * t)
            s[i] += a * lfo * math.sin(TWO_PI * fl * t)

    air = buf(seconds, M)
    noise(air, M, amp=1.0, rng=random.Random(101))
    air = lowpass(air, M, 420)
    air = highpass(air, M, 90)
    for i in range(n):
        t = i / M
        s[i] += 0.5 * air[i] * (0.55 + 0.45 * math.sin(TWO_PI * lock(0.091) * t))

    for at, f in [(2.4, 392.0), (6.1, 523.25), (10.3, 329.63)]:
        bell(s, lock(f), M, amp=0.10, start=at, decay=1.5)

    s = shimmer(s, M, delay=0.09, mix=0.3, taps=2)
    return normalize(soft_clip(seam(s, M, 0.6)), 0.5)


def amb_gate():
    """Inside a tear: the same music, gone wrong. A tritone above the drone,
    a pulse at walking pace, and no bells at all."""
    seconds = 12.0
    s = buf(seconds, M)
    n = len(s)

    def lock(f):
        return round(f * seconds) / seconds

    for f, a in [(55.0, 0.55), (82.41, 0.26), (77.78, 0.15), (110.0, 0.14)]:
        fl = lock(f)
        for i in range(n):
            t = i / M
            lfo = 1.0 + 0.2 * math.sin(TWO_PI * lock(0.25) * t)
            s[i] += a * lfo * math.sin(TWO_PI * fl * t)

    air = buf(seconds, M)
    noise(air, M, amp=1.0, rng=random.Random(202))
    air = lowpass(air, M, 700)
    air = highpass(air, M, 150)
    for i in range(n):
        t = i / M
        pulse = 0.5 + 0.5 * math.sin(TWO_PI * lock(0.5) * t) ** 4
        s[i] += 0.42 * air[i] * pulse

    # A far-off, detuned high line — the thing on the other side.
    for i in range(n):
        t = i / M
        s[i] += 0.05 * math.sin(TWO_PI * lock(659.25) * t) * \
            (0.5 + 0.5 * math.sin(TWO_PI * lock(0.166) * t))

    s = shimmer(s, M, delay=0.11, mix=0.34, taps=2)
    return normalize(soft_clip(seam(s, M, 0.55)), 0.46)


SFX = {
    "ui_tap": ui_tap,
    "ui_select": ui_select,
    "ui_back": ui_back,
    "page": page,
    "gate_open": gate_open,
    "hit": hit,
    "crit": crit,
    "ability": ability,
    "ultimate": ultimate,
    "heal": heal,
    "enemy_down": enemy_down,
    "boss_stir": boss_stir,
    "party_down": party_down,
    "victory": victory,
    "defeat": defeat,
    "reward": reward,
    "bond": bond,
    "ascend": ascend,
    "gift": gift,
    "blip": blip,
}

AMBIENCE = {
    "amb_house": amb_house,
    "amb_gate": amb_gate,
}


def main():
    total = 0
    for name, fn in SFX.items():
        sig = fn()
        write(name, sig, SFX_RATE)
        total += len(sig) * 2
    for name, fn in AMBIENCE.items():
        sig = fn()
        write(name, sig, MUSIC_RATE)
        total += len(sig) * 2
    print("-- %d files, %.0f KB total" % (len(SFX) + len(AMBIENCE), total / 1024))


if __name__ == "__main__":
    main()
