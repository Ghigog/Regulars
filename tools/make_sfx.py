"""Synthesises the game's sound effects and music loop. Run: python3 tools/make_sfx.py"""
import math, os, random, struct, wave

RATE = 32000
OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "sfx")
os.makedirs(OUT, exist_ok=True)
random.seed(4)

SINE = ((1, 1.0),)
MARIMBA = ((1, 1.0), (4, 0.22), (10, 0.04))
BELL = ((1, 1.0), (2.76, 0.5), (5.4, 0.25), (8.93, 0.1))
SOFT = ((1, 1.0), (2, 0.3), (3, 0.1))


def midi(m):
    return 440.0 * 2 ** ((m - 69) / 12)


def buf(dur):
    return [0.0] * int(RATE * dur)


def tone(b, start, freq, dur, vol, partials=SINE, decay=6.0, attack=0.004, bend=0.0, wrap=False):
    """Adds a decaying note. bend is the fractional pitch change per second."""
    n, i0, phase = len(b), int(start * RATE), 0.0
    for k in range(int(dur * RATE)):
        t = k / RATE
        phase += 2 * math.pi * freq * (1 + bend * t) / RATE
        env = min(1.0, t / attack) * math.exp(-decay * t)
        v = sum(a * math.sin(phase * m) for m, a in partials)
        i = i0 + k
        if wrap:
            i %= n
        elif i >= n:
            break
        b[i] += v * vol * env


def pad(b, start, freq, dur, vol, wrap=False):
    n, i0 = len(b), int(start * RATE)
    for k in range(int(dur * RATE)):
        t = k / RATE
        env = min(1.0, t / 0.5, (dur - t) / 0.5)
        i = (i0 + k) % n if wrap else i0 + k
        if i >= n:
            break
        b[i] += math.sin(2 * math.pi * freq * t) * vol * env


def noise(b, start, dur, vol, colour=0.5, decay=0.0, wrap=False):
    """High-passed noise burst. colour near 1 = hissy, near 0 = dull."""
    n, i0, low = len(b), int(start * RATE), 0.0
    for k in range(int(dur * RATE)):
        t = k / RATE
        x = random.uniform(-1, 1)
        low += (1 - colour) * (x - low)
        env = min(1.0, t / 0.003) * math.exp(-decay * t) * min(1.0, (dur - t) / 0.01)
        i = (i0 + k) % n if wrap else i0 + k
        if i >= n:
            break
        b[i] += (x - low) * vol * env


def reverb(b, amount=0.25):
    out = b + [0.0] * int(RATE * 0.25)
    for delay, gain in ((0.029, 0.5), (0.047, 0.4), (0.071, 0.3), (0.113, 0.2), (0.171, 0.12)):
        d = int(delay * RATE)
        for i in range(len(b)):
            out[i + d] += b[i] * gain * amount
    return out


def save(name, b, peak=0.8):
    top = max(1e-9, max(abs(s) for s in b))
    fade = int(RATE * 0.004)
    with wave.open(os.path.join(OUT, name + ".wav"), "w") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        frames = []
        for i, s in enumerate(b):
            edge = min(1.0, (len(b) - i) / fade) if name not in LOOPS else 1.0
            frames.append(struct.pack("<h", int(s / top * peak * edge * 32767)))
        w.writeframes(b"".join(frames))


LOOPS = {"sizzle", "music"}

# ---------------------------------------------------------------- effects

b = buf(0.16)
tone(b, 0, 420, 0.14, 1.0, SOFT, decay=22, bend=5.0)
noise(b, 0, 0.02, 0.3, 0.8, decay=150)
save("pickup", b, 0.6)

b = buf(0.18)
tone(b, 0, 190, 0.16, 1.0, SOFT, decay=24, bend=-2.5)
noise(b, 0, 0.03, 0.5, 0.3, decay=120)
save("putdown", b, 0.6)

b = buf(1.1)
tone(b, 0, midi(88), 1.1, 1.0, BELL, decay=4.5)
tone(b, 0.09, midi(93), 1.0, 0.6, BELL, decay=5)
save("ding", reverb(b, 0.4), 0.7)

b = buf(0.9)
for i, m in enumerate((72, 76, 79, 84)):
    tone(b, i * 0.07, midi(m), 0.6, 1.0, MARIMBA, decay=8)
save("serve", reverb(b, 0.35), 0.75)

b = buf(0.7)
tone(b, 0, midi(95), 0.12, 0.9, SOFT, decay=14)
tone(b, 0.075, midi(100), 0.6, 1.0, SOFT, decay=7)
tone(b, 0.075, midi(107), 0.5, 0.25, SINE, decay=9)
save("coin", reverb(b, 0.3), 0.7)

b = buf(0.9)
tone(b, 0, midi(63), 0.3, 1.0, SOFT, decay=5, bend=-0.3)
tone(b, 0.22, midi(58), 0.6, 1.0, SOFT, decay=4, bend=-0.4)
tone(b, 0.22, midi(46), 0.6, 0.6, SINE, decay=4)
save("fail", reverb(b, 0.3), 0.75)

b = buf(0.7)
noise(b, 0, 0.6, 0.6, 0.9, decay=5)
for i in range(3):
    tone(b, i * 0.15, midi(81), 0.09, 0.7, SOFT, decay=6)
save("burn", b, 0.7)

b = buf(1.3)
for i, m in enumerate((67, 72, 76, 79)):
    tone(b, i * 0.13, midi(m), 0.8, 1.0, MARIMBA, decay=5)
tone(b, 0.52, midi(84), 0.7, 0.7, BELL, decay=5)
save("day", reverb(b, 0.45), 0.75)

b = buf(0.6)
noise(b, 0, 0.55, 0.5, 0.75, decay=3)
for i in range(9):
    tone(b, random.uniform(0.02, 0.45), random.uniform(700, 1900), 0.05, 0.35, SINE, decay=40, bend=6.0)
save("wash", b, 0.6)

b = buf(0.09)
tone(b, 0, 150, 0.07, 1.0, SINE, decay=45, bend=-3.0)
noise(b, 0, 0.03, 0.5, 0.25, decay=140)
save("step", b, 0.5)

b = buf(1.2)
tone(b, 0, midi(96), 1.0, 1.0, BELL, decay=6)
tone(b, 0.16, midi(91), 1.0, 0.8, BELL, decay=6)
save("bell", reverb(b, 0.4), 0.55)

b = buf(0.5)
for i, m in enumerate((84, 88, 91)):
    tone(b, i * 0.035, midi(m), 0.35, 1.0, BELL, decay=10)
save("perfect", reverb(b, 0.4), 0.6)

# Sizzle: hiss plus random crackles, cross-faded so it loops without a click.
n, x = int(RATE * 1.6), int(RATE * 0.2)
raw = [0.0] * (n + x)
noise(raw, 0, (n + x) / RATE, 0.35, 0.85)
for _ in range(110):
    noise(raw, random.uniform(0, 1.75), random.uniform(0.004, 0.02), random.uniform(0.3, 0.9), 0.6, decay=200)
sizzle = raw[:n]
for i in range(x):
    a = i / x
    sizzle[i] = raw[i] * a + raw[n + i] * (1 - a)
save("sizzle", sizzle, 0.5)

# ---------------------------------------------------------------- music loop
# Eight bars at 100 bpm; every note wraps around the end so the loop is seamless.
BEAT = 0.6
music = buf(BEAT * 32)
CHORDS = [  # (bass note, pad notes)
    (48, (60, 64, 67, 71)), (45, (57, 60, 64, 67)), (41, (53, 57, 60, 64)), (43, (55, 59, 62, 65)),
] * 2
SCALE = [72, 74, 76, 79, 81, 84]
step_i, phrase = 2, []
for bar in range(4):
    notes = []
    for eighth in range(8):
        if random.random() < (0.2 if eighth % 2 == 0 else 0.45):
            notes.append(None)
            continue
        step_i = max(0, min(len(SCALE) - 1, step_i + random.choice((-2, -1, -1, 1, 1, 2))))
        notes.append(SCALE[step_i])
    phrase.append(notes)
for bar, (bass, tones) in enumerate(CHORDS):
    t0 = bar * 4 * BEAT
    for m in tones:
        pad(music, t0, midi(m), 4 * BEAT + 0.4, 0.035, wrap=True)
    for beat, m in ((0, bass), (1.5, bass), (2.5, bass + 7), (3, bass)):
        tone(music, t0 + beat * BEAT, midi(m), 0.5, 0.3, SOFT, decay=5, attack=0.01, wrap=True)
    for beat in (0, 2):
        tone(music, t0 + beat * BEAT, 95, 0.2, 0.3, SINE, decay=20, bend=-2.0, wrap=True)
    for eighth in range(8):
        noise(music, t0 + eighth * BEAT / 2, 0.04, 0.05 if eighth % 2 else 0.025, 0.9, decay=70, wrap=True)
        m = phrase[bar % 4][eighth]
        if m is not None and not (bar >= 4 and eighth == 7):
            tone(music, t0 + eighth * BEAT / 2, midi(m), 0.7, 0.16, MARIMBA, decay=7, wrap=True)
save("music", music, 0.7)

# ---------------------------------------------------------------- interface props
# Added after the music so the effects above keep their random sequence.
WOOD = ((1, 1.0), (2.3, 0.4), (4.1, 0.15))

b = buf(0.6)   # roll: a wooden wheel rolling on a desk, ticking as it turns
noise(b, 0, 0.58, 0.18, 0.15, decay=1.5)
for i in range(9):
    t = 0.02 + i * 0.062
    tone(b, t, 900 + random.uniform(-80, 80), 0.03, 0.5, WOOD, decay=90)
    noise(b, t, 0.012, 0.35, 0.7, decay=300)
save("roll", b, 0.55)

b = buf(0.35)  # lift: a soft upward whoosh
noise(b, 0, 0.33, 0.6, 0.35, decay=6)
tone(b, 0, 180, 0.3, 0.4, SINE, decay=7, bend=2.5)
save("lift", b, 0.45)

b = buf(0.45)  # rattle: the calendar jiggling on its stand
for i in range(6):
    t = i * 0.065
    tone(b, t, random.uniform(320, 420), 0.05, 0.9, WOOD, decay=70)
    noise(b, t, 0.015, 0.4, 0.4, decay=220)
save("rattle", b, 0.55)

b = buf(0.4)   # page: one paper page turning over
for i in range(14):
    t = 0.04 + i * 0.016 + random.uniform(0, 0.01)
    noise(b, t, 0.05, 0.25 + 0.5 * math.sin(math.pi * i / 14), 0.85, decay=50)
noise(b, 0.26, 0.08, 0.6, 0.6, decay=40)
save("page", b, 0.55)

b = buf(0.25)  # thump: set down lightly on a desk
tone(b, 0, 110, 0.2, 1.0, SOFT, decay=22, bend=-1.5)
noise(b, 0, 0.04, 0.5, 0.2, decay=90)
save("thump", b, 0.65)

b = buf(0.45)  # rip: a paper tag torn off its string
for i in range(70):
    t = 0.02 + 0.3 * (i / 70) ** 0.8
    noise(b, t, random.uniform(0.003, 0.012), random.uniform(0.3, 1.0), 0.8, decay=300)
noise(b, 0.02, 0.33, 0.25, 0.9, decay=6)
save("rip", b, 0.6)

b = buf(1.1)   # flutter: paper fluttering in the air
for i in range(26):
    t = i * 0.04
    noise(b, t, 0.035, 0.25 + 0.2 * math.sin(i * 1.3) ** 2, 0.8, decay=60)
save("flutter", b, 0.4)

b = buf(0.3)   # rustle: a short paper rustle
for i in range(9):
    noise(b, random.uniform(0, 0.2), 0.04, random.uniform(0.3, 0.8), 0.85, decay=60)
save("rustle", b, 0.45)

b = buf(0.8)   # rope: a board running on ropes, with a creak
noise(b, 0, 0.75, 0.5, 0.3, decay=3)
for i in range(4):
    tone(b, 0.08 + i * 0.16, random.uniform(240, 300), 0.12, 0.35, WOOD, decay=18, bend=0.6)
save("rope", b, 0.5)

b = buf(0.35)  # stamp: a rubber stamp thumped onto card
tone(b, 0, 140, 0.18, 1.0, SOFT, decay=26, bend=-1.2)
noise(b, 0, 0.03, 0.8, 0.35, decay=120)
noise(b, 0.05, 0.12, 0.2, 0.6, decay=30)
save("stamp", b, 0.7)

b = buf(0.4)   # slide: a wooden tray pushed along a counter
noise(b, 0, 0.32, 0.5, 0.35, decay=7)
tone(b, 0.0, 180, 0.3, 0.3, WOOD, decay=10, bend=0.8)
tone(b, 0.27, 120, 0.12, 0.7, SOFT, decay=30, bend=-1.0)
save("slide", b, 0.5)

b = buf(0.12)  # tick: one card flicked along the tray
tone(b, 0, 620, 0.06, 0.8, WOOD, decay=60)
noise(b, 0, 0.02, 0.5, 0.8, decay=200)
save("tick", b, 0.45)

b = buf(0.22)  # tab: a paper divider flipped over
noise(b, 0, 0.06, 0.7, 0.75, decay=60)
tone(b, 0.05, 360, 0.12, 0.6, WOOD, decay=30, bend=0.5)
save("tab", b, 0.5)

b = buf(0.7)   # flip: the door card spun on its string and knocking the frame
noise(b, 0, 0.16, 0.5, 0.7, decay=14)
for i, t in enumerate([0.2, 0.34, 0.44]):
    tone(b, t, 300 - 30 * i, 0.1, 0.9 - 0.3 * i, WOOD, decay=36)
    noise(b, t, 0.02, 0.4 - 0.1 * i, 0.5, decay=150)
save("flip", b, 0.6)


# ---------------------------------------------------------------- prep (PRD 1)

b = buf(0.45)  # zoom: a prep done well, a quick rising whoosh and a sparkle
noise(b, 0, 0.3, 0.6, 0.85, decay=8)
tone(b, 0.0, 500, 0.3, 0.5, SOFT, decay=9, bend=2.5)
tone(b, 0.22, 1568, 0.2, 0.4, BELL, decay=18)
save("zoom", reverb(b, 0.25), 0.6)

b = buf(0.6)   # wobble: a prep done badly, a sagging boing
tone(b, 0, 300, 0.55, 1.0, SOFT, decay=5, bend=-0.9)
tone(b, 0.05, 220, 0.5, 0.4, SINE, decay=6, bend=-0.6)
save("wobble", b, 0.6)

b = buf(0.12)  # chop: a knife on a board
tone(b, 0, 240, 0.08, 0.9, WOOD, decay=55)
noise(b, 0, 0.03, 0.6, 0.7, decay=160)
save("chop", b, 0.55)

b = buf(0.14)  # slice: a short steel shick
noise(b, 0, 0.1, 0.8, 0.95, decay=35)
tone(b, 0, 2400, 0.08, 0.2, SINE, decay=40, bend=-0.5)
save("slice", b, 0.45)

b = buf(0.25)  # glug: a drink going into a cup
for i in range(3):
    tone(b, i * 0.07, 330 + i * 60, 0.08, 0.7, SOFT, decay=40, bend=1.5)
save("glug", b, 0.5)

print("wrote", sorted(f for f in os.listdir(OUT) if f.endswith(".wav")))
