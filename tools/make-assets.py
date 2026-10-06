#!/usr/bin/env python3
"""Akati OS: generates the extra wallpapers, the Akati OS cursors and the Akati OS sounds.

Everything is drawn from code (no third-party art), so it is covered by the GPL-3.0 license of this
repository. Needs numpy and Pillow. Run from the repository root:

    python3 tools/make-assets.py

Writes to src/ and src-win10/ (Executables/AtlasModules/Wallpapers and .../Other/AkatiOS).
"""
import math
import os
import struct
import wave

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

TREES = ['src', 'src-win10']


# ---------------------------------------------------------------------------------------------
# Wallpapers: soft color glows and thin arcs, like the Akati OS Dark and Light wallpapers
# ---------------------------------------------------------------------------------------------
W, H = 3840, 2160


def glow(cx, cy, r, strength=1.0, scale=4):
    """Strength of a soft round glow, computed at 1/scale and scaled up later (smooth, small PNG)."""
    w, h = W // scale, H // scale
    y, x = np.mgrid[0:h, 0:w].astype(np.float32)
    d2 = ((x - cx * w) ** 2 + (y - cy * h) ** 2) / (r * w) ** 2
    return np.exp(-d2 * 2.2) * strength


def wallpaper(name, base, glows, arcs, arc_color):
    scale = 4
    w, h = W // scale, H // scale
    img = np.ones((h, w, 3), np.float32) * np.array(base, np.float32) / 255.0
    for cx, cy, r, color, strength in glows:
        a = np.clip(glow(cx, cy, r, strength, scale), 0, 1)[..., None]
        img = img * (1 - a) + (np.array(color, np.float32) / 255.0) * a
    small = Image.fromarray((np.clip(img, 0, 1) * 255).astype(np.uint8))
    big = small.resize((W, H), Image.BICUBIC).filter(ImageFilter.GaussianBlur(6))
    # Thin concentric arcs
    layer = Image.new('RGBA', (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    cx, cy, r0, step, count, alpha = arcs
    for i in range(count):
        r = r0 + i * step
        a = int(alpha * (1 - i / (count + 2)))
        d.ellipse([cx - r, cy - r, cx + r, cy + r], outline=arc_color + (a,), width=3)
    layer = layer.filter(ImageFilter.GaussianBlur(0.8))
    out = Image.alpha_composite(big.convert('RGBA'), layer).convert('RGB')
    for tree in TREES:
        path = os.path.join(tree, 'Executables', 'AtlasModules', 'Wallpapers', name)
        out.save(path, optimize=True)
    print('wallpaper', name)


def make_wallpapers():
    wallpaper('akatios-aurora.png', (6, 10, 18),
              [(0.15, 0.85, 0.55, (14, 120, 128), 0.85), (0.85, 0.25, 0.5, (84, 40, 160), 0.8), (0.55, 0.6, 0.35, (20, 70, 120), 0.5)],
              (3000, 700, 260, 120, 11, 60), (170, 220, 230))
    wallpaper('akatios-sunset.png', (14, 6, 14),
              [(0.2, 0.9, 0.55, (200, 70, 60), 0.75), (0.8, 0.3, 0.55, (130, 30, 120), 0.85), (0.5, 0.75, 0.3, (220, 120, 60), 0.45)],
              (900, 600, 240, 115, 11, 55), (255, 200, 210))
    wallpaper('akatios-ocean.png', (4, 8, 20),
              [(0.25, 0.3, 0.6, (24, 60, 160), 0.85), (0.85, 0.85, 0.55, (10, 130, 170), 0.7), (0.6, 0.45, 0.3, (60, 40, 150), 0.5)],
              (2900, 1500, 260, 125, 12, 60), (160, 200, 255))
    wallpaper('akatios-mist.png', (244, 240, 250),
              [(0.15, 0.8, 0.55, (250, 190, 220), 0.8), (0.85, 0.3, 0.55, (190, 160, 250), 0.85), (0.55, 0.55, 0.35, (200, 225, 255), 0.6)],
              (2950, 650, 250, 120, 11, 70), (150, 120, 200))


# ---------------------------------------------------------------------------------------------
# Cursors: a white arrow with a dark outline and an Akati OS purple edge, plus busy rings.
# Each .cur holds several sizes (Windows picks one for the cursor size setting).
# ---------------------------------------------------------------------------------------------
PURPLE = (176, 124, 240)
PURPLE2 = (138, 63, 214)
SIZES = [32, 48, 64, 96, 128]
ANI_SIZES = [32, 48, 64, 96]  # animated cursors: 18 frames each, so no 128 px
SS = 8  # supersampling


def arrow_points(s):
    # Arrow in a 32 x 32 design grid, tip at (1, 1)
    pts = [(1, 1), (1, 23.5), (6.6, 18.4), (10.4, 27), (14, 25.4), (10.3, 17), (17.8, 17)]
    return [(x * s / 32, y * s / 32) for x, y in pts]


def draw_arrow(size):
    big = size * SS
    img = Image.new('RGBA', (big, big), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    pts = arrow_points(big)
    # Outline: dark, drawn wider
    w = max(2, big // 16)
    d.polygon(pts, fill=(20, 16, 28, 255))
    d.line(pts + [pts[0]], fill=(20, 16, 28, 255), width=w, joint='curve')
    # Fill: white, with a purple edge on the left side
    inner = [((x - pts[0][0]) * 0.86 + pts[0][0] + big * 0.012, (y - pts[0][1]) * 0.86 + pts[0][1] + big * 0.03) for x, y in pts]
    d.polygon(inner, fill=(250, 248, 255, 255))
    edge = [inner[0], inner[1], (inner[1][0] + big * 0.05, inner[1][1] - big * 0.05), (inner[0][0] + big * 0.05, inner[0][1] + big * 0.1)]
    d.polygon(edge, fill=PURPLE + (255,))
    return img.resize((size, size), Image.LANCZOS)


def draw_ring(size, angle, offset=(0, 0), ring_scale=1.0):
    big = size * SS
    img = Image.new('RGBA', (big, big), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    r = big * 0.36 * ring_scale
    cx, cy = big / 2 + offset[0] * big, big / 2 + offset[1] * big
    w = max(2, int(big * 0.11 * ring_scale))
    box = [cx - r, cy - r, cx + r, cy + r]
    d.ellipse([cx - r - w * 0.35, cy - r - w * 0.35, cx + r + w * 0.35, cy + r + w * 0.35], outline=(20, 16, 28, 200), width=int(w * 1.7))
    d.arc(box, 0, 360, fill=(70, 50, 100, 255), width=w)
    # Gradient arc: draw short segments from light to dark purple
    steps = 24
    for i in range(steps):
        t = i / steps
        col = tuple(int(PURPLE2[k] + (PURPLE[k] - PURPLE2[k]) * t) for k in range(3)) + (255,)
        a0 = angle + i * 270 / steps
        d.arc(box, a0, a0 + 270 / steps + 1.5, fill=col, width=w)
    return img.resize((size, size), Image.LANCZOS)


def dib_bytes(img):
    """One cursor image as a classic 32-bit DIB with an AND mask (PNG entries are not always loaded
    as cursors, DIBs always are)."""
    w, h = img.size
    px = np.asarray(img.convert('RGBA'), dtype=np.uint8)
    header = struct.pack('<IiiHHIIiiII', 40, w, h * 2, 1, 32, 0, 0, 0, 0, 0, 0)
    # Rows bottom-up, BGRA
    xor = px[::-1, :, [2, 1, 0, 3]].tobytes()
    # AND mask: 1 bit per pixel, 1 = transparent, rows padded to 4 bytes
    row_bytes = ((w + 31) // 32) * 4
    mask = bytearray()
    for y in range(h - 1, -1, -1):
        bits = np.packbits((px[y, :, 3] == 0).astype(np.uint8))
        mask += bits.tobytes() + b'\0' * (row_bytes - len(bits))
    return header + xor + bytes(mask)


def cur_bytes(images, hotspots):
    """A .cur file with one image per size."""
    entries, blobs = [], []
    offset = 6 + 16 * len(images)
    for img, (hx, hy) in zip(images, hotspots):
        data = dib_bytes(img)
        w, h = img.size
        entries.append(struct.pack('<BBBBHHII', w % 256, h % 256, 0, 0, hx, hy, len(data), offset))
        blobs.append(data)
        offset += len(data)
    return struct.pack('<HHH', 0, 2, len(images)) + b''.join(entries) + b''.join(blobs)


def ani_bytes(frames, rate_jiffies):
    """An animated cursor (RIFF ACON) from .cur files."""
    def chunk(tag, data):
        pad = b'\0' if len(data) % 2 else b''
        return tag + struct.pack('<I', len(data)) + data + pad
    anih = struct.pack('<9I', 36, len(frames), len(frames), 0, 0, 0, 0, rate_jiffies, 1)
    fram = b'fram' + b''.join(chunk(b'icon', f) for f in frames)
    body = b'ACON' + chunk(b'anih', anih) + chunk(b'LIST', fram)
    return b'RIFF' + struct.pack('<I', len(body)) + body


def make_cursors():
    arrow_imgs = [draw_arrow(s) for s in SIZES]
    arrow_hot = [(max(0, round(s / 32)), max(0, round(s / 32))) for s in SIZES]
    files = {'akatios-arrow.cur': cur_bytes(arrow_imgs, arrow_hot)}
    # Busy: ring only, hotspot in the middle
    frames = []
    for i in range(18):
        imgs = [draw_ring(s, i * 20) for s in ANI_SIZES]
        frames.append(cur_bytes(imgs, [(s // 2, s // 2) for s in ANI_SIZES]))
    files['akatios-busy.ani'] = ani_bytes(frames, 3)
    # Working in background: arrow with a small ring
    frames = []
    for i in range(18):
        imgs = []
        for s, a in zip(SIZES, arrow_imgs):
            if s not in ANI_SIZES:
                continue
            ring = draw_ring(s, i * 20, offset=(0.2, 0.22), ring_scale=0.42)
            imgs.append(Image.alpha_composite(a, ring))
        frames.append(cur_bytes(imgs, [h for s, h in zip(SIZES, arrow_hot) if s in ANI_SIZES]))
    files['akatios-working.ani'] = ani_bytes(frames, 3)
    for tree in TREES:
        folder = os.path.join(tree, 'Executables', 'AtlasModules', 'Other', 'AkatiOS', 'Cursors')
        os.makedirs(folder, exist_ok=True)
        for name, data in files.items():
            with open(os.path.join(folder, name), 'wb') as f:
                f.write(data)
    # Preview for the documentation
    prev = Image.new('RGBA', (3 * 140, 140), (24, 18, 34, 255))
    prev.alpha_composite(arrow_imgs[-1], (6, 6))
    prev.alpha_composite(draw_ring(128, 0), (146, 6))
    prev.alpha_composite(Image.alpha_composite(arrow_imgs[-1], draw_ring(128, 0, (0.2, 0.22), 0.42)), (286, 6))
    os.makedirs('docs/images', exist_ok=True)
    prev.convert('RGB').save('docs/images/akatios-cursors.png')
    print('cursors', ', '.join(files))


# ---------------------------------------------------------------------------------------------
# Sounds: soft bell tones (sine partials with an exponential decay), 44.1 kHz 16-bit stereo
# ---------------------------------------------------------------------------------------------
RATE = 44100


def note(freq, start, length, gain=0.5, decay=6.0):
    n = int(length * RATE)
    t = np.arange(n) / RATE
    env = np.exp(-t * decay) * np.minimum(1, t / 0.006)
    tone = (np.sin(2 * np.pi * freq * t) + 0.35 * np.sin(2 * np.pi * freq * 2 * t) * np.exp(-t * 4)
            + 0.12 * np.sin(2 * np.pi * freq * 3.01 * t) * np.exp(-t * 9))
    return start, tone * env * gain


def render(notes, total):
    out = np.zeros(int(total * RATE))
    for start, sig in notes:
        i = int(start * RATE)
        out[i:i + len(sig)] += sig[:len(out) - i]
    # Short fade out and a light stereo spread
    fade = int(0.03 * RATE)
    out[-fade:] *= np.linspace(1, 0, fade)
    peak = np.max(np.abs(out)) or 1
    out = out / peak * 0.6
    left = out
    right = np.concatenate([np.zeros(90), out[:-90]])
    return np.stack([left, right], axis=1)


def save_wav(path, data):
    pcm = (np.clip(data, -1, 1) * 32767).astype('<i2')
    with wave.open(path, 'wb') as w:
        w.setnchannels(2)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(pcm.tobytes())


def make_sounds():
    C5, E5, G5, A5, B5, C6, D6, E6 = 523.25, 659.25, 783.99, 880.0, 987.77, 1046.5, 1174.66, 1318.51
    G4, A4, E4 = 392.0, 440.0, 329.63
    sounds = {
        'akatios-notify.wav': render([note(E6, 0, 0.9, 0.5), note(B5, 0.09, 0.9, 0.45)], 0.9),
        'akatios-default.wav': render([note(A5, 0, 0.5, 0.5, 9)], 0.5),
        'akatios-info.wav': render([note(G5, 0, 0.7, 0.45, 7), note(D6, 0.07, 0.7, 0.35, 7)], 0.7),
        'akatios-warning.wav': render([note(A5, 0, 0.45, 0.5, 8), note(A5, 0.16, 0.6, 0.45, 8)], 0.75),
        'akatios-error.wav': render([note(E5, 0, 0.55, 0.5, 6), note(A4, 0.12, 0.8, 0.5, 5)], 0.9),
        'akatios-connect.wav': render([note(C5, 0, 0.6, 0.4, 7), note(G5, 0.08, 0.6, 0.4, 7), note(C6, 0.16, 0.8, 0.45, 6)], 0.95),
        'akatios-disconnect.wav': render([note(C6, 0, 0.6, 0.4, 7), note(G5, 0.08, 0.6, 0.4, 7), note(C5, 0.16, 0.8, 0.45, 6)], 0.95),
        'akatios-logon.wav': render([note(G4, 0, 1.6, 0.35, 2.5), note(C5, 0.12, 1.6, 0.35, 2.5), note(E5, 0.24, 1.6, 0.35, 2.5),
                                     note(G5, 0.36, 1.6, 0.35, 2.5), note(C6, 0.48, 1.6, 0.4, 2.2)], 2.1),
    }
    for tree in TREES:
        folder = os.path.join(tree, 'Executables', 'AtlasModules', 'Other', 'AkatiOS', 'Sounds')
        os.makedirs(folder, exist_ok=True)
        for name, data in sounds.items():
            save_wav(os.path.join(folder, name), data)
    print('sounds', ', '.join(sounds))


if __name__ == '__main__':
    make_wallpapers()
    make_cursors()
    make_sounds()
