from PIL import Image, ImageDraw
import math, os

BG     = (15, 15, 13)
ACCENT = (200, 240, 96)
HOLE   = (15, 15, 13)

def make_icon(out_px):
    S = out_px * 4
    img  = Image.new('RGB', (S, S), BG)
    draw = ImageDraw.Draw(img)

    cr = int(S * 0.22)
    draw.rounded_rectangle([0, 0, S - 1, S - 1], radius=cr, fill=BG)

    cx  = S / 2
    cy  = S * 0.41
    r   = S * 0.225
    tip = S * 0.815

    left_deg, right_deg = 215, 325
    pts = []
    for i in range(121):
        t   = right_deg + (left_deg + 360 - right_deg) * i / 120
        rad = math.radians(t)
        pts.append((cx + r * math.cos(rad), cy - r * math.sin(rad)))
    pts.append((cx, tip))
    draw.polygon(pts, fill=ACCENT)

    hr = r * 0.40
    draw.ellipse([cx - hr, cy - hr, cx + hr, cy + hr], fill=HOLE)

    dr = hr * 0.28
    ox, oy = cx - hr * 0.22, cy - hr * 0.22
    draw.ellipse([ox - dr, oy - dr, ox + dr, oy + dr], fill=(230, 255, 150))

    return img.resize((out_px, out_px), Image.LANCZOS)

densities = {
    'mdpi': 48, 'hdpi': 72, 'xhdpi': 96, 'xxhdpi': 144, 'xxxhdpi': 192,
}

base = os.path.join(os.path.dirname(__file__), '..', 'android', 'app', 'src', 'main', 'res')
for density, px in densities.items():
    icon = make_icon(px)
    path = os.path.join(base, f'mipmap-{density}', 'ic_launcher.png')
    icon.save(path)
    print(f'{density}: {px}x{px}')

print('Feito.')
