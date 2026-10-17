#!/usr/bin/env python3
"""
Synthesizes the placeholder sound effects for Apes vs Aliens.

Usage:   python3 make_sfx.py [output_dir]      (needs numpy, scipy and ffmpeg with libvorbis)

Every sound is a short function below. Tweak the numbers (frequencies, decay rates,
durations) and re-run to regenerate an .ogg. Replace any file with a real recording any time:
the game only cares about the file names.
"""
import os
import subprocess
import sys
import wave

import numpy as np
from scipy import signal

SR = 44100
rng = np.random.default_rng(1234)  # fixed seed: re-running gives identical files
OUT = sys.argv[1] if len(sys.argv) > 1 else "sfx_out"

# ───────────────────────── building blocks ─────────────────────────

def T(duration):
    return np.arange(int(SR * duration)) / SR

def noise(n):
    return rng.standard_normal(n)

def decay(tt, rate):
    return np.exp(-rate * tt)

def attack(tt, seconds):
    return np.minimum(1.0, tt / seconds)

def sweep(tt, f0, f1):
    """Frequency curve gliding exponentially from f0 to f1 across tt."""
    return f0 * (f1 / f0) ** (tt / tt[-1])

def sine_from_freq(freq_curve):
    return np.sin(2 * np.pi * np.cumsum(freq_curve) / SR)

def tri(freq, tt):
    return (2 / np.pi) * np.arcsin(np.sin(2 * np.pi * freq * tt))

def _filter(x, kind, fc, order=4):
    sos = signal.butter(order, fc, btype=kind, fs=SR, output="sos")
    return signal.sosfilt(sos, x)

def lowpass(x, fc):
    return _filter(x, "low", fc)

def highpass(x, fc):
    return _filter(x, "high", fc)

def bandpass(x, lo, hi):
    return _filter(x, "band", [lo, hi])

def place(out, x, start):
    """Mix x into out beginning `start` seconds in. Each note gets a short release so a
    note that is cut off while still audible doesn't click."""
    x = x.copy()
    r = min(len(x), int(SR * 0.02))
    x[-r:] *= np.linspace(1, 0, r)
    i = int(SR * start)
    n = min(len(x), len(out) - i)
    if n > 0:
        out[i:i + n] += x[:n]
    return out

def finish(x, peak=0.8, fade_ms=4):
    """Normalise to `peak` and fade the very edges so nothing clicks."""
    x = x - np.mean(x)
    n = int(SR * fade_ms / 1000)
    ramp = np.linspace(0, 1, n)
    x[:n] *= ramp
    x[-n:] *= ramp[::-1]
    return x / (np.max(np.abs(x)) + 1e-9) * peak

# ───────────────────────── the sounds ─────────────────────────

def dash():
    tt = T(0.34)
    whoosh = bandpass(noise(len(tt)), 500, 5000) * attack(tt, 0.04) * decay(tt, 9)
    body = sine_from_freq(sweep(tt, 900, 220)) * decay(tt, 10) * 0.25
    return finish(whoosh + body, 0.8)

def overcharge():
    tt = T(0.75)
    ph = 2 * np.pi * np.cumsum(sweep(tt, 160, 760)) / SR
    s = np.sin(ph) + 0.5 * np.sin(2 * ph) + 0.25 * np.sin(3 * ph)
    tremolo = 0.75 + 0.25 * np.sin(2 * np.pi * 16 * tt)
    fade_out = np.clip((tt[-1] - tt) / 0.12, 0, 1)
    return finish(s * tremolo * attack(tt, 0.03) * fade_out, 0.55)

def adrenaline():
    tt = T(0.5)
    out = np.zeros_like(tt)
    for start in (0.0, 0.17):  # heartbeat: two thumps
        local = T(0.3)
        place(out, np.sin(2 * np.pi * 58 * local) * decay(local, 16) * attack(local, 0.004), start)
    local = T(0.24)
    place(out, 0.5 * np.sin(2 * np.pi * 1400 * local) * decay(local, 11), 0.26)  # high ping
    return finish(out, 0.8)

def deploy_cover():
    tt = T(0.5)
    thunk = sine_from_freq(sweep(tt, 130, 55)) * decay(tt, 12)
    click = lowpass(noise(len(tt)), 1600) * decay(tt, 45) * 0.9
    ring = (np.sin(2 * np.pi * 520 * tt) + 0.6 * np.sin(2 * np.pi * 831 * tt)) * decay(tt, 9) * 0.18
    return finish(thunk + click + ring, 0.8)

def shockwave():
    tt = T(1.0)
    boom = sine_from_freq(sweep(tt, 95, 26)) * decay(tt, 4.2)
    rumble = lowpass(noise(len(tt)), 380) * decay(tt, 5) * 1.4
    crack = highpass(noise(len(tt)), 1500) * decay(tt, 55) * 0.6
    return finish(boom + rumble + crack, 0.88)

def grapple():
    out = np.zeros(int(SR * 0.42))
    tz = T(0.28)
    zip_ = sine_from_freq(sweep(tz, 280, 2400)) * attack(tz, 0.01) * np.clip((tz[-1] - tz) / 0.03, 0, 1)
    place(out, zip_ * 0.8, 0.0)
    tick_t = T(0.1)
    place(out, bandpass(noise(len(tick_t)), 1200, 6000) * decay(tick_t, 60) * 0.8, 0.28)
    return finish(out, 0.5)

def target_lock():
    out = np.zeros(int(SR * 0.55))
    for start, freq, rate in ((0.0, 1320, 14), (0.15, 1760, 9)):  # two-tone lock-on beep
        local = T(0.36)
        wave_ = np.sin(2 * np.pi * freq * local) + 0.35 * np.sign(np.sin(2 * np.pi * freq * local))
        place(out, wave_ * attack(local, 0.004) * decay(local, rate), start)
    return finish(out, 0.7)

def life_siphon():
    tt = T(0.75)
    ph = 2 * np.pi * np.cumsum(330 + 45 * np.sin(2 * np.pi * 8 * tt)) / SR  # wobbling pitch
    s = np.sin(ph) + 0.4 * np.sin(2 * ph + 0.8 * np.sin(2 * np.pi * 5 * tt))
    swell = np.sin(np.pi * tt / tt[-1]) ** 0.7 * (0.8 + 0.2 * np.sin(2 * np.pi * 11 * tt))
    return finish(s * swell, 0.5)

def ability_ready():
    tt = T(0.16)
    return finish(sine_from_freq(sweep(tt, 900, 1500)) * decay(tt, 22) * attack(tt, 0.004), 0.5)

def respawn():
    out = np.zeros(int(SR * 0.8))
    for i, freq in enumerate((523.25, 659.25, 783.99, 1046.5)):  # rising C major arpeggio
        local = T(0.6)
        note = (tri(freq, local) * 0.8 + np.sin(2 * np.pi * freq * 2 * local) * 0.15)
        place(out, note * decay(local, 5) * attack(local, 0.006), i * 0.1)
    return finish(out, 0.7)

def countdown_tick():
    tt = T(0.16)
    return finish(np.sin(2 * np.pi * 880 * tt) * decay(tt, 25) * attack(tt, 0.003), 0.6)

def countdown_go():
    tt = T(0.6)
    chord = sum(np.sin(2 * np.pi * f * tt) for f in (660, 880, 1320, 1760))
    return finish(chord * decay(tt, 4.5) * attack(tt, 0.004), 0.75)

def round_win():
    out = np.zeros(int(SR * 1.5))
    notes = (523.25, 659.25, 783.99, 1046.5)
    for i, freq in enumerate(notes):  # climbing arpeggio...
        local = T(0.7)
        place(out, tri(freq, local) * 0.7 * decay(local, 3) * attack(local, 0.008), i * 0.14)
    local = T(0.95)  # ...then a held major chord
    chord = sum(tri(f, local) for f in notes) * 0.3
    place(out, chord * decay(local, 2.2) * attack(local, 0.01), 0.56)
    return finish(out, 0.8)

def round_lose():
    out = np.zeros(int(SR * 1.5))
    for i, freq in enumerate((440.0, 349.23, 293.66, 220.0)):  # sagging A minor line
        local = T(0.8)
        note = np.sin(2 * np.pi * freq * local) + 0.6 * np.sin(2 * np.pi * freq * 1.006 * local)
        place(out, note * 0.5 * decay(local, 3) * attack(local, 0.01), i * 0.22)
    local = T(0.62)  # low minor chord
    chord = sum(np.sin(2 * np.pi * f * local) for f in (146.83, 174.61, 220.0)) * 0.35
    place(out, chord * decay(local, 2.4) * attack(local, 0.02), 0.88)
    return finish(out, 0.65)

def kill_confirm():
    out = np.zeros(int(SR * 0.32))
    first = T(0.32)
    place(out, np.sin(2 * np.pi * 1320 * first) * decay(first, 20), 0.0)
    local = T(0.25)
    ding = np.sin(2 * np.pi * 1760 * local) * decay(local, 11) + 0.4 * np.sin(2 * np.pi * 3520 * local) * decay(local, 16)
    place(out, ding, 0.07)
    return finish(out, 0.75)

def gate_open():
    tt = T(1.7)
    rumble = lowpass(noise(len(tt)), 220) * (0.6 + 0.4 * np.sin(2 * np.pi * 7 * tt))
    scrape = bandpass(noise(len(tt)), 1400, 3200) * (0.5 + 0.5 * np.sin(2 * np.pi * 23 * tt)) * 0.18
    shape = np.minimum(1, tt / 0.15) * np.clip((1.45 - tt) / 0.25, 0, 1)
    out = (rumble * 1.6 + scrape) * shape
    thump = T(0.25)
    place(out, np.sin(2 * np.pi * 60 * thump) * decay(thump, 14) * 1.2, 1.45)  # clunk as it stops
    return finish(out, 0.8)

SOUNDS = {
    "dash": dash, "overcharge": overcharge, "adrenaline": adrenaline, "cover": deploy_cover,
    "shockwave": shockwave, "grapple": grapple, "target_lock": target_lock, "siphon": life_siphon,
    "ability_ready": ability_ready, "respawn": respawn, "countdown_tick": countdown_tick,
    "countdown_go": countdown_go, "round_win": round_win, "round_lose": round_lose,
    "kill_confirm": kill_confirm, "gate_open": gate_open,
}

def write_wav(path, x):
    with wave.open(path, "wb") as f:
        f.setnchannels(1)
        f.setsampwidth(2)
        f.setframerate(SR)
        f.writeframes((np.clip(x, -1, 1) * 32767).astype("<i2").tobytes())

if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    for name, fn in SOUNDS.items():
        wav_path = os.path.join(OUT, name + ".wav")
        ogg_path = os.path.join(OUT, name + ".ogg")
        write_wav(wav_path, fn())
        subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", wav_path,
                        "-c:a", "libvorbis", "-q:a", "4", ogg_path], check=True)
        os.remove(wav_path)
        print(f"wrote {ogg_path}")
