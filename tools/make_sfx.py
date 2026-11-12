"""Synthesises the placeholder sound effects. Run: python3 tools/make_sfx.py"""
import math, os, random, struct, wave

RATE = 22050
OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "sfx")
os.makedirs(OUT, exist_ok=True)


def save(name, samples):
    with wave.open(os.path.join(OUT, name + ".wav"), "w") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(b"".join(struct.pack("<h", int(max(-1, min(1, s)) * 30000)) for s in samples))


def note(freq, dur, vol=0.5, decay=6.0, bend=0.0, shape="sine"):
    out, phase = [], 0.0
    for i in range(int(RATE * dur)):
        t = i / RATE
        phase += 2 * math.pi * (freq + bend * t) / RATE
        v = math.sin(phase)
        if shape == "square":
            v = 0.6 if v > 0 else -0.6
        elif shape == "bell":
            v = 0.7 * v + 0.3 * math.sin(phase * 2.76)
        out.append(v * vol * math.exp(-decay * t) * min(1.0, i / 60))
    return out


def seq(*parts):
    out = []
    for p in parts:
        out += p
    return out


random.seed(4)
save("pickup", note(520, 0.09, 0.4, 14, bend=2400))
save("putdown", note(300, 0.09, 0.4, 16, bend=-900))
save("ding", note(1320, 0.7, 0.5, 5, shape="bell"))
save("serve", seq(note(660, 0.11, 0.45, 9, shape="bell"), note(990, 0.35, 0.45, 6, shape="bell")))
save("coin", seq(note(1180, 0.07, 0.4, 10), note(1570, 0.3, 0.4, 8)))
save("fail", seq(note(300, 0.18, 0.45, 4, bend=-400, shape="square"), note(200, 0.4, 0.45, 5, bend=-250, shape="square")))
save("burn", seq(note(440, 0.12, 0.4, 3, shape="square"), [0.0] * 1200, note(440, 0.12, 0.4, 3, shape="square")))
save("day", seq(note(523, 0.13, 0.4, 7, shape="bell"), note(659, 0.13, 0.4, 7, shape="bell"), note(784, 0.5, 0.45, 4, shape="bell")))
save("wash", [random.uniform(-1, 1) * 0.25 * math.sin(math.pi * i / (RATE * 0.35)) for i in range(int(RATE * 0.35))])

# Sizzle: crackly filtered noise that loops cleanly.
sizzle, low = [], 0.0
for i in range(RATE):
    n = random.uniform(-1, 1)
    low += 0.35 * (n - low)
    crackle = 1.0 if random.random() < 0.004 else 0.0
    sizzle.append((n - low) * 0.22 + crackle * random.uniform(-0.5, 0.5))
save("sizzle", sizzle)
print("wrote", sorted(os.listdir(OUT)))
