#!/usr/bin/env python3
"""
Originální hudba a zvuky pro Dune Diggers – vše syntetizované kódem
(žádné cizí nahrávky = žádné problémy s autorskými právy).

Výstup (assets/audio/):
  music_oasis.ogg    – klidné téma pro menu a lobby (Oasis Town)
  music_desert.ogg   – dobrodružné téma pro kopání v poušti
  music_storm.ogg    – napjaté téma pro písečnou bouři
  ambience_wind.ogg  – vítr v poušti (smyčka)
  sfx_pack.ogg       – všechny zvukové efekty v jednom souboru
                       (časy viz Config.SfxRegions ve hře)

Použití:  pip install numpy scipy  &&  python3 tools/audio/compose.py
Potřebuje ffmpeg (převod do .ogg).
"""
import subprocess
import tempfile
import wave
from pathlib import Path

import numpy as np
from scipy import signal

SR = 44100
ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "assets" / "audio"
rng = np.random.default_rng(2026)


# ------------------------------------------------------------------ základy
def tt(dur):
    return np.arange(int(dur * SR)) / SR


def hz(note):
    return 440.0 * 2 ** ((note - 69) / 12)


def sos(kind, freq, order=2):
    return signal.butter(order, freq, btype=kind, fs=SR, output="sos")


def filt(x, kind, freq, order=2):
    return signal.sosfilt(sos(kind, freq, order), x)


def fade(x, a=0.004, r=0.02):
    n = len(x)
    na, nr = min(int(a * SR), n), min(int(r * SR), n)
    if na:
        x[:na] *= np.linspace(0, 1, na)
    if nr:
        x[-nr:] *= np.linspace(1, 0, nr)
    return x


def noise(dur):
    return rng.standard_normal(int(dur * SR))


# ------------------------------------------------------------------ nástroje
def oud(note, dur, vel=1.0, bright=0.82):
    """Drnkací struna (aditivní syntéza, vyšší harmonické doznívají rychleji)."""
    f0 = hz(note)
    length = dur + 1.2
    t = tt(length)
    out = np.zeros_like(t)
    for h in range(1, 14):
        f = f0 * h * (1 + 0.0003 * h * h)
        if f > 15000:
            break
        amp = (1 / h**1.05) * (bright ** (h - 1)) * (1.0 if h % 2 else 0.75)
        decay = 2.2 + 0.9 * (h - 1)
        out += amp * np.sin(2 * np.pi * f * t + rng.uniform(0, 6.28)) * np.exp(-t * decay)
    pick = filt(noise(0.02), "bandpass", [1800, 5000]) * 0.08
    out[: len(pick)] += pick
    # ztlumení po konci noty (prst na struně)
    end = int(dur * SR)
    if end < len(out):
        out[end:] *= np.exp(-np.arange(len(out) - end) / SR * 14)
    return fade(out * 0.32 * vel, 0.002, 0.05)


def ney(note, dur, vel=1.0):
    """Dechová flétna s vibratem a dechem."""
    f0 = hz(note)
    t = tt(dur + 0.25)
    vib = 1 + 0.005 * np.sin(2 * np.pi * 5.2 * t) * np.clip((t - 0.25) / 0.4, 0, 1)
    phase = 2 * np.pi * np.cumsum(f0 * vib) / SR
    tone = np.sin(phase) + 0.22 * np.sin(2 * phase) + 0.07 * np.sin(3 * phase)
    breath = filt(noise(len(t) / SR), "bandpass", [f0 * 1.5, min(f0 * 5, 12000)]) * 0.05
    env = np.clip(t / 0.14, 0, 1) * np.clip((dur + 0.25 - t) / 0.25, 0, 1)
    return fade((tone + breath) * env * 0.2 * vel)


def pad(notes, dur, vel=1.0, cutoff=1400):
    """Teplý pad z rozladěných pil (aditivně), pomalý náběh."""
    t = tt(dur)
    out = np.zeros_like(t)
    for n in notes:
        for det in (-0.07, 0.0, 0.07):
            f0 = hz(n + det)
            for h in range(1, 18):
                f = f0 * h
                if f > cutoff * 2.5:
                    break
                out += (1 / h) * np.sin(2 * np.pi * f * t + rng.uniform(0, 6.28))
    out = filt(out, "lowpass", cutoff)
    att = min(1.6, dur / 3)
    env = np.clip(t / att, 0, 1) * np.clip((dur - t) / att, 0, 1)
    return out * env * 0.022 * vel


def bass(note, dur, vel=1.0):
    f0 = hz(note)
    t = tt(dur + 0.3)
    out = np.sin(2 * np.pi * f0 * t) + 0.35 * np.sin(4 * np.pi * f0 * t) + 0.12 * np.sin(6 * np.pi * f0 * t)
    env = np.exp(-t * 1.6) * np.clip((dur + 0.3 - t) / 0.3, 0, 1)
    return fade(out * env * 0.3 * vel, 0.006, 0.05)


def bell(note, dur=2.0, vel=1.0):
    f = hz(note)
    t = tt(dur)
    index = 3.0 * np.exp(-t * 4)
    out = np.sin(2 * np.pi * f * t + index * np.sin(2 * np.pi * f * 3.5 * t))
    return fade(out * np.exp(-t * 2.5) * 0.16 * vel, 0.001, 0.1)


def doum(vel=1.0, f_start=130, f_end=58, length=0.55):
    t = tt(length)
    f = f_end + (f_start - f_end) * np.exp(-t * 22)
    body = np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-t * 7)
    click = filt(noise(length), "lowpass", 1500) * np.exp(-t * 90) * 0.4
    return fade((body + click) * 0.55 * vel, 0.001, 0.05)


def tek(vel=1.0):
    t = tt(0.14)
    n = filt(noise(0.14), "bandpass", [2500, 7500]) * np.exp(-t * 45)
    ring = np.sin(2 * np.pi * 720 * t) * np.exp(-t * 55) * 0.35
    return fade((n * 0.55 + ring) * 0.42 * vel, 0.0005, 0.02)


def ka(vel=1.0):
    return tek(0.45 * vel)


def shaker(vel=1.0):
    t = tt(0.08)
    n = filt(noise(0.08), "highpass", 6500) * np.clip(t / 0.012, 0, 1) * np.exp(-t * 40)
    return n * 0.13 * vel


def saw_brass(notes, dur, vel=1.0):
    t = tt(dur)
    out = np.zeros_like(t)
    for n in notes:
        f0 = hz(n)
        for h in range(1, 25):
            if f0 * h > 9000:
                break
            out += (1 / h) * np.sin(2 * np.pi * f0 * h * t)
    cutoff_env = 600 + 2600 * np.clip(t / 0.25, 0, 1)
    out = filt(out, "lowpass", 2400)
    env = np.clip(t / 0.06, 0, 1) * np.clip((dur - t) / 0.3, 0, 1)
    return out * env * 0.09 * vel * (cutoff_env / cutoff_env.max())


# ------------------------------------------------------------------ mix
class Track:
    def __init__(self, seconds):
        self.buf = np.zeros((int(seconds * SR) + SR * 4, 2))

    def add(self, sig, at, pan=0.0, gain=1.0):
        i = int(at * SR)
        if i >= len(self.buf):
            return
        sig = sig[: len(self.buf) - i] * gain
        left = np.cos((pan + 1) * np.pi / 4)
        right = np.sin((pan + 1) * np.pi / 4)
        self.buf[i : i + len(sig), 0] += sig * left
        self.buf[i : i + len(sig), 1] += sig * right


def reverb(stereo, seconds=1.8, mix=0.22):
    n = int(seconds * SR)
    t = np.arange(n) / SR
    wet = np.zeros_like(stereo)
    for ch in range(2):
        ir = rng.standard_normal(n) * np.exp(-t * 6.9 / seconds)
        ir = filt(ir, "lowpass", 5000)
        ir[: int(0.012 * SR)] = 0
        ir /= np.sqrt(np.sum(ir**2))
        wet[:, ch] = signal.fftconvolve(stereo[:, ch], ir)[: len(stereo)]
    return stereo * (1 - mix * 0.5) + wet * mix


def master(stereo, target_rms=0.085):
    stereo = stereo - np.mean(stereo, axis=0)
    rms = np.sqrt(np.mean(stereo**2)) + 1e-9
    stereo = stereo * (target_rms / rms)
    drive = 1.4
    stereo = np.tanh(stereo * drive) / np.tanh(drive)
    peak = np.max(np.abs(stereo))
    if peak > 0.78:  # rezerva pro kódování do OGG (jinak by praskalo)
        stereo *= 0.78 / peak
    return stereo


def loopable(track, seconds):
    """Dozvuk z konce přičte na začátek → plynulá smyčka."""
    n = int(seconds * SR)
    buf = track.buf
    tail = buf[n:]
    out = buf[:n].copy()
    out[: len(tail)] += tail[: n]
    return out


def write_ogg(name, stereo, quality=5):
    OUT.mkdir(parents=True, exist_ok=True)
    pcm = (np.clip(stereo, -1, 1) * 32767).astype(np.int16)
    with tempfile.TemporaryDirectory() as tmp:
        wav = Path(tmp) / "x.wav"
        with wave.open(str(wav), "wb") as w:
            w.setnchannels(2)
            w.setsampwidth(2)
            w.setframerate(SR)
            w.writeframes(pcm.tobytes())
        target = OUT / name
        subprocess.run(
            ["ffmpeg", "-v", "error", "-y", "-i", str(wav), "-c:a", "libvorbis", "-q:a", str(quality), str(target)],
            check=True,
        )
    print(f"  {name}: {len(stereo) / SR:.1f} s, {target.stat().st_size // 1024} KB")


# ------------------------------------------------------------------ harmonie (D hidžáz)
CHORDS = {
    "D": [50, 54, 57],  # D F# A
    "Cm": [48, 51, 55],  # C Eb G
    "Gm": [43, 46, 50],  # G Bb D
    "Eb": [51, 55, 58],  # Eb G Bb
}
ROOT_NOTE = {"D": 38, "Cm": 36, "Gm": 43, "Eb": 39}


def seq(track, notes, start, beat, inst, pan=0.0, gain=1.0, octave=0):
    """notes = [(midi, beats), ...]; midi None = pauza"""
    at = start
    for note, beats in notes:
        if note is not None:
            track.add(inst(note + octave, beats * beat * 0.95), at, pan, gain)
        at += beats * beat
    return at


MELODY_A1 = [(69, 1), (70, 0.5), (69, 0.5), (67, 1), (66, 1), (67, 0.5), (66, 0.5), (63, 1), (62, 2),
             (66, 1), (67, 0.5), (69, 0.5), (70, 1), (72, 1), (70, 0.5), (69, 0.5), (67, 1), (69, 2)]
MELODY_A2 = [(69, 1), (70, 0.5), (69, 0.5), (67, 1), (66, 1), (67, 0.5), (69, 0.5), (70, 1), (72, 1), (74, 1),
             (72, 0.5), (70, 0.5), (69, 1), (67, 0.5), (66, 0.5), (67, 1), (66, 0.5), (63, 0.5), (62, 3)]
MELODY_B = [(74, 2), (72, 1), (70, 1), (69, 2), (67, 1), (69, 1), (70, 1), (69, 0.5), (67, 0.5), (66, 1), (67, 1), (69, 4),
            (74, 1), (75, 1), (74, 1), (72, 1), (70, 1), (72, 0.5), (70, 0.5), (69, 2), (67, 1), (66, 1), (63, 1), (66, 1), (62, 4)]


def drums_maqsum(track, start, beat, bars, vel=1.0, fills=True):
    e = beat / 2
    for b in range(bars):
        s = start + b * beat * 4
        track.add(doum(vel), s + 0 * e, -0.1)
        track.add(tek(vel), s + 1 * e, 0.25)
        track.add(tek(0.8 * vel), s + 3 * e, 0.25)
        track.add(doum(0.85 * vel), s + 4 * e, -0.1)
        track.add(tek(vel), s + 6 * e, 0.25)
        if fills:
            track.add(ka(vel), s + 2 * e, 0.35)
            track.add(ka(0.8 * vel), s + 5 * e, 0.35)
            track.add(ka(0.7 * vel), s + 7 * e, 0.35)
        if fills and b % 4 == 3:
            for k in range(4):
                track.add(tek(0.5 + k * 0.15), s + 6 * e + k * e / 2, 0.3)


def compose_desert():
    bpm = 104
    beat = 60 / bpm
    bar = beat * 4
    bars = 32
    length = bars * bar
    tr = Track(length)
    prog = ["D", "D", "Cm", "D", "Gm", "Eb", "Cm", "D"]

    for b in range(bars):
        chord = prog[b % 8]
        s = b * bar
        r = ROOT_NOTE[chord]
        section = b // 8
        # basa
        for at, d, n in ((0, 1.3, r), (1.5, 0.45, r), (2, 0.9, r + 7), (3, 0.9, r + 12 if section == 3 else r)):
            tr.add(bass(n, d * beat), s + at * beat, 0, 0.9)
        # pad (sekce B a A')
        if section in (1, 2):
            tr.add(pad([n + 12 for n in CHORDS[chord]], bar + 0.2, 0.9), s, 0)
        # shaker
        if section in (1, 2, 3):
            for k in range(16):
                tr.add(shaker(0.7 if k % 2 else 1.0), s + k * beat / 4, 0.5)
        # arpeggio oud v sekci B a C
        if section in (1, 3):
            notes = CHORDS[chord] + [CHORDS[chord][0] + 12]
            for k in range(8):
                n = notes[[0, 2, 1, 3, 2, 1, 3, 2][k]] + 12
                tr.add(oud(n, beat * 0.45, 0.45 if section == 1 else 0.6, 0.75), s + k * beat / 2, -0.35)
    drums_maqsum(tr, 0, beat, bars)

    # melodie
    seq(tr, MELODY_A1 + MELODY_A2, 0, beat, oud, 0.15, 1.0)
    seq(tr, MELODY_B, 8 * bar, beat, ney, 0.1, 1.0)
    seq(tr, MELODY_A1 + MELODY_A2, 16 * bar, beat, oud, 0.15, 1.0)
    seq(tr, [(n, d) for n, d in MELODY_A1 + MELODY_A2], 16 * bar, beat, ney, -0.2, 0.45, -12)
    # sekce C: zvonky jako vrchol
    for b in range(24, 32):
        for k, n in enumerate(CHORDS[prog[b % 8]]):
            tr.add(bell(n + 24, 1.6, 0.5), b * bar + k * beat * 1.33, 0.4 - k * 0.3)

    tr.buf = reverb(tr.buf, 1.9, 0.24)
    return master(loopable(tr, length))


def compose_oasis():
    bpm = 80
    beat = 60 / bpm
    bar = beat * 4
    bars = 24
    length = bars * bar
    tr = Track(length)
    prog = ["D", "D", "Gm", "Gm", "Cm", "Cm", "D", "D", "Eb", "Eb", "D", "D"]
    for b in range(bars):
        chord = prog[b % 12]
        s = b * bar
        if b % 2 == 0:
            tr.add(pad(CHORDS[chord] + [CHORDS[chord][0] + 12], bar * 2 + 0.3, 1.1, 1100), s, 0)
            tr.add(bass(ROOT_NOTE[chord], bar * 1.6, 0.7), s, 0)
        notes = CHORDS[chord] + [CHORDS[chord][0] + 12]
        for k in range(8):
            n = notes[[0, 1, 2, 3, 2, 1, 2, 1][k]] + 12
            tr.add(oud(n, beat * 0.9, 0.38, 0.7), s + k * beat / 2, -0.3 + 0.08 * (k % 4))
        if b >= 4:
            tr.add(doum(0.55, 110, 55), s, -0.1)
            tr.add(doum(0.4, 110, 55), s + 2 * beat, -0.1)
            tr.add(tek(0.35), s + 2.5 * beat, 0.3)
            tr.add(tek(0.3), s + 3.5 * beat, 0.3)
        if b % 2 == 1:
            tr.add(bell(notes[2] + 24, 2.2, 0.5), s + 1.5 * beat, 0.45)
    mel1 = [(69, 4), (70, 2), (69, 2), (67, 3), (66, 1), (67, 4), (69, 2), (72, 2), (70, 2), (69, 1), (67, 1), (66, 2), (63, 2), (62, 4)]
    mel2 = [(74, 4), (72, 2), (70, 2), (69, 3), (70, 1), (69, 4), (67, 2), (70, 2), (69, 2), (67, 1), (66, 1), (67, 2), (66, 1), (63, 1), (62, 4)]
    seq(tr, mel1, 4 * bar, beat, ney, 0.1, 1.0)
    seq(tr, mel2, 16 * bar, beat, ney, 0.1, 1.0)
    tr.buf = reverb(tr.buf, 2.6, 0.32)
    return master(loopable(tr, length), 0.075)


def compose_storm():
    bpm = 126
    beat = 60 / bpm
    bar = beat * 4
    bars = 24
    length = bars * bar
    tr = Track(length)
    ost = [62, 63, 62, 60, 62, 63, 66, 63]
    for b in range(bars):
        s = b * bar
        level = 0.6 + 0.2 * (b // 8)
        for at in (0, 0.75, 1.5, 2.5, 3):
            tr.add(doum(level, 95, 42, 0.7), s + at * beat, 0)
        for k in range(16):
            tr.add(tek(0.25 + (0.25 if k % 4 == 0 else 0)), s + k * beat / 4, 0.35 if k % 2 else -0.35)
            tr.add(oud(ost[k % 8] + (12 if b >= 16 else 0), beat * 0.22, 0.5 + (0.3 if k % 4 == 0 else 0), 0.9), s + k * beat / 4, -0.25)
        for k in range(8):
            tr.add(bass(26 if k % 2 == 0 else 38, beat * 0.4, 0.8), s + k * beat / 2, 0)
        if b % 2 == 0:
            tr.add(pad([38, 45, 51 if b % 4 == 2 else 50], bar * 2 + 0.2, 1.2, 900), s, 0)
        if b % 4 == 3:
            swell = filt(noise(bar), "bandpass", [300, 3000]) * np.linspace(0, 1, int(bar * SR)) ** 2 * 0.25
            tr.add(swell, s, 0.0)
    melody = [(69, 2), (70, 2), (69, 2), (67, 2), (66, 2), (67, 2), (63, 2), (62, 2)] * 2
    seq(tr, melody, 8 * bar, beat, lambda n, d: saw_brass([n - 12, n - 5], d, 1.0), 0.1, 1.0)
    seq(tr, melody, 16 * bar, beat, lambda n, d: saw_brass([n - 12, n], d, 1.1), 0.1, 1.0)
    tr.buf = reverb(tr.buf, 1.5, 0.2)
    return master(loopable(tr, length), 0.09)


def compose_wind(seconds=60):
    n = int(seconds * SR)
    t = np.arange(n) / SR
    out = np.zeros((n, 2))
    for ch in range(2):
        white = rng.standard_normal(n)
        pink = filt(white, "lowpass", 650, 4)
        lfo = 0.55 + 0.45 * np.sin(2 * np.pi * t / 11 + ch) * np.sin(2 * np.pi * t / 4.3 + 1.7 * ch)
        gust = np.clip(np.sin(2 * np.pi * t / 17 + ch * 0.8), 0, 1) ** 3
        band = filt(white, "bandpass", [350, 1100], 2) * gust * 0.3
        out[:, ch] = filt(pink, "highpass", 80) * lfo + band
    # plynulá smyčka (prolnutí konce a začátku)
    x = int(3 * SR)
    ramp = np.linspace(0, 1, x)[:, None]
    out[:x] = out[:x] * ramp + out[-x:] * (1 - ramp)
    out = out[: n - x]
    return master(out, 0.06)


# ------------------------------------------------------------------ zvukové efekty
def sfx_pack():
    total = 13.0
    buf = np.zeros((int(total * SR), 2))

    def put(sig, at, gain=1.0, pan=0.0):
        sig = np.asarray(sig) * gain
        i = int(at * SR)
        left, right = np.cos((pan + 1) * np.pi / 4), np.sin((pan + 1) * np.pi / 4)
        buf[i : i + len(sig), 0] += sig[: len(buf) - i] * left
        buf[i : i + len(sig), 1] += sig[: len(buf) - i] * right

    def crunch(seed_shift, cutoff):
        t = tt(0.3)
        grains = filt(noise(0.3), "bandpass", [cutoff * 0.4, cutoff]) * np.exp(-t * 16)
        grains *= 1 + 0.6 * (rng.random(len(t)) > 0.92)
        thump = np.sin(2 * np.pi * (90 + 60 * np.exp(-t * 30)) * t) * np.exp(-t * 22) * 0.7
        return fade(grains * 0.5 + thump, 0.001, 0.05)

    def ping(note, dur=0.3, v=1.0):
        t = tt(dur)
        f = hz(note)
        return fade((np.sin(2 * np.pi * f * t) + 0.4 * np.sin(2 * np.pi * f * 2.76 * t)) * np.exp(-t * 9) * 0.35 * v, 0.001, 0.03)

    put(crunch(0, 3800), 0.0)
    put(crunch(1, 2600), 0.5)
    put(ping(88, 0.32), 1.0)
    put(ping(93, 0.25, 0.8), 1.07)
    for k, n in enumerate([84, 88, 91, 96, 93, 96, 100]):
        put(ping(n, 0.35, 0.8), 1.5 + k * 0.07, pan=-0.4 + k * 0.13)
    t = tt(0.1)
    put(fade(np.sin(2 * np.pi * (950 - 3500 * t) * t) * np.exp(-t * 40) * 0.5, 0.001, 0.02), 2.5)
    t = tt(0.25)
    put(fade(filt(noise(0.25), "bandpass", [800, 4000]) * np.sin(np.pi * t / 0.25) * 0.25, 0.001, 0.03), 3.0)
    for k, n in enumerate([50, 45]):
        tt_ = tt(0.16)
        sq = np.sign(np.sin(2 * np.pi * hz(n) * tt_)) * np.exp(-tt_ * 6) * 0.18
        put(fade(filt(sq, "lowpass", 2000), 0.002, 0.03), 3.5 + k * 0.17)
    t = tt(0.4)
    creak = filt(noise(0.4), "bandpass", [300, 900]) * np.exp(-t * 6) * 0.25 * (1 + np.sin(2 * np.pi * 30 * t))
    put(fade(creak), 4.0)
    for k, n in enumerate([74, 78, 81, 86, 90]):
        put(bell(n, 0.9, 0.9), 4.25 + k * 0.08, pan=-0.3 + k * 0.15)
    put(saw_brass([62, 66, 69], 0.45, 1.6), 5.5)
    put(saw_brass([64, 67, 71], 0.3, 1.6), 5.95)
    put(saw_brass([66, 69, 74], 0.75, 1.8), 6.25)
    for k, n in enumerate([86, 90, 93, 98]):
        put(bell(n, 0.8, 0.8), 6.25 + k * 0.06)
    for k in range(14):
        put(ping(62 + k * 2, 0.25, 0.7), 7.5 + k * 0.06, pan=np.sin(k) * 0.6)
    put(saw_brass([62, 69, 74, 78], 0.9, 1.4), 8.35)
    t = tt(1.0)
    whoosh = filt(noise(1.0), "bandpass", [300, 6000]) * np.sin(np.pi * t) ** 2 * 0.2
    put(whoosh, 7.6)
    t = tt(2.0)
    horn = saw_brass([38, 45], 2.0, 2.2) * np.clip(t / 0.4, 0, 1)
    put(horn, 9.5)
    put(filt(noise(2.0), "bandpass", [200, 1200]) * np.sin(np.pi * t / 2) * 0.15, 9.5)
    t = tt(0.06)
    put(filt(noise(0.06), "bandpass", [1500, 5000]) * np.exp(-t * 60) * 0.5, 12.0)
    put(ping(96, 0.6, 1.0), 12.08)
    put(ping(100, 0.55, 0.9), 12.14)
    out = buf / (np.max(np.abs(buf)) + 1e-9) * 0.75
    return out


def main():
    print("Skládám hudbu a zvuky...")
    write_ogg("music_oasis.ogg", compose_oasis())
    write_ogg("music_desert.ogg", compose_desert())
    write_ogg("music_storm.ogg", compose_storm())
    write_ogg("ambience_wind.ogg", compose_wind(), 3)
    write_ogg("sfx_pack.ogg", sfx_pack(), 6)
    print("Hotovo ->", OUT)


if __name__ == "__main__":
    main()
